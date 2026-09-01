import AppKit
import Combine

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
            let tracker = CursorTracker(hostView: view) { [weak self] location in
                self?.move(to: location)
            }
            return ScreenOverlay(panel: panel, view: view, tracker: tracker)
        }
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
        }
        reposition()
    }

    private func move(to location: CGPoint) {
        lastCursorLocation = location
        reposition()
    }

    private func reposition() {
        let configuration = NeonConfiguration(settings: settings)
        let half = CGSize(
            width: configuration.canvasSize.width / 2,
            height: configuration.canvasSize.height / 2
        )
        let glowRect = CGRect(
            x: lastCursorLocation.x - half.width,
            y: lastCursorLocation.y - half.height,
            width: half.width * 2,
            height: half.height * 2
        )

        for overlay in overlays {
            // グローの外接矩形がそのスクリーンに掛からないなら、合成コストを避けるため隠す。
            overlay.view.isHidden = !overlay.panel.frame.intersects(glowRect)
            overlay.view.update(
                cursorLocation: lastCursorLocation,
                screenOrigin: overlay.panel.frame.origin
            )
        }
    }
}
