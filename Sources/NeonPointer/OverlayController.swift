import AppKit
import Combine
import QuartzCore

@MainActor
final class OverlayController {
    /// 1 スクリーンに対応するパネル・ビュー・トラッカーの組。
    /// パネルはそのスクリーンの `frame` に固定されたまま動かない。
    private struct ScreenOverlay {
        let panel: OverlayPanel
        let view: NeonCursorView
        let tracker: CursorTracker
    }

    private let settings: SettingsStore
    private var overlays: [ScreenOverlay] = []
    private var cancellable: AnyCancellable?
    private var lastCursorLocation: CGPoint = NSEvent.mouseLocation
    private var isStarted = false
    private var trail = StrokeTrail()

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        cancellable = settings.didChange.sink { [weak self] in self?.applySettings() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        rebuildOverlays()
        applySettings()
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        cancellable = nil
        NotificationCenter.default.removeObserver(
            self,
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        tearDownOverlays()
    }

    @objc private func screenParametersDidChange() {
        rebuildOverlays()
        applySettings()
    }

    /// `NSScreen.screens` の並びに合わせてパネルを作り直す。
    /// パネルはスクリーン境界をまたいで移動しないため、モニタ間の
    /// リフレッシュレート差・スケール差・非矩形配置のデッドゾーンによる
    /// 追従の乱れが起きない。
    private func rebuildOverlays() {
        tearDownOverlays()

        overlays = NSScreen.screens.map { screen in
            let view = NeonCursorView(configuration: NeonConfiguration(settings: settings))
            let panel = OverlayPanel(contentView: view)
            panel.setFrame(screen.frame, display: false)
            view.frame = CGRect(origin: .zero, size: screen.frame.size)
            let tracker = CursorTracker(hostView: view) { [weak self] location, flags in
                self?.handleTick(location: location, flags: flags)
            }
            return ScreenOverlay(panel: panel, view: view, tracker: tracker)
        }
        trail.clear()
    }

    private func tearDownOverlays() {
        for overlay in overlays {
            overlay.tracker.stop()
            overlay.panel.orderOut(nil)
        }
        overlays = []
    }

    private func applySettings() {
        let configuration = NeonConfiguration(settings: settings)

        for overlay in overlays {
            overlay.view.configuration = configuration
            // イベントトラッキング中でも即時に反映させるため、遅延レイアウトに任せない。
            overlay.view.needsLayout = true
            overlay.view.layoutSubtreeIfNeeded()
        }

        if settings.isEnabled {
            for overlay in overlays {
                if !overlay.panel.isVisible { overlay.panel.orderFrontRegardless() }
                if !overlay.tracker.isRunning { overlay.tracker.start() }
            }
        } else {
            for overlay in overlays {
                overlay.tracker.stop()
                overlay.panel.orderOut(nil)
            }
            trail.clear()
        }
        reposition()
    }

    private func handleTick(location: CGPoint, flags: NSEvent.ModifierFlags) {
        let shouldDraw = settings.isEnabled && settings.trailEnabled && settings.trailModifier.isActive(in: flags)
        let locationChanged = location != lastCursorLocation

        // カーソルが静止していて、描画中でも軌跡が残ってもいなければ何もすることがない。
        guard shouldDraw || trail.isDrawing || !trail.strokes.isEmpty || locationChanged else {
            return
        }

        let now = CACurrentMediaTime()
        trail.setDrawing(shouldDraw, at: now)
        if shouldDraw, locationChanged {
            trail.append(location)
        }
        trail.prune(now: now, hold: settings.trailHoldDuration, fade: settings.trailFadeDuration)

        lastCursorLocation = location
        reposition()
    }

    private func reposition() {
        let configuration = NeonConfiguration(settings: settings)
        let half = CGSize(
            width: configuration.canvasSize.width / 2,
            height: configuration.canvasSize.height / 2
        )
        let cursorRect = CGRect(
            x: lastCursorLocation.x - half.width,
            y: lastCursorLocation.y - half.height,
            width: half.width * 2,
            height: half.height * 2
        )

        let now = CACurrentMediaTime()
        let renderItems = trail.renderItems(at: now, hold: settings.trailHoldDuration, fade: settings.trailFadeDuration)
        let trailPadding = configuration.trailGlowRadius * 4 + configuration.trailWidth
        let trailRect = trail.bounds(at: now, hold: settings.trailHoldDuration, fade: settings.trailFadeDuration)
            .map { $0.insetBy(dx: -trailPadding, dy: -trailPadding) }

        for overlay in overlays {
            let cursorOnScreen = overlay.panel.frame.intersects(cursorRect)
            let trailOnScreen = trailRect.map { overlay.panel.frame.intersects($0) } ?? false
            // どちらの外接矩形もそのスクリーンに掛からないなら、合成コストを避けるため隠す。
            overlay.view.isHidden = !cursorOnScreen && !trailOnScreen
            overlay.view.setCursorVisible(cursorOnScreen)
            overlay.view.update(
                cursorLocation: lastCursorLocation,
                screenOrigin: overlay.panel.frame.origin
            )
            overlay.view.updateTrail(renderItems)
        }
    }
}
