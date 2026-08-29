import AppKit
import Combine

@MainActor
final class OverlayController {
    private let settings: SettingsStore
    private let view: NeonCursorView
    private let panel: OverlayPanel
    private var tracker: CursorTracker?
    private var cancellable: AnyCancellable?
    private var lastCursorLocation: CGPoint = NSEvent.mouseLocation

    init(settings: SettingsStore) {
        self.settings = settings
        view = NeonCursorView(configuration: NeonConfiguration(settings: settings))
        panel = OverlayPanel(contentView: view)
        tracker = CursorTracker(hostView: view) { [weak self] location in
            self?.move(to: location)
        }
    }

    func start() {
        cancellable = settings.didChange.sink { [weak self] in self?.applySettings() }
        applySettings()
    }

    func stop() {
        cancellable = nil
        tracker?.stop()
        panel.orderOut(nil)
    }

    private func applySettings() {
        let configuration = NeonConfiguration(settings: settings)
        let canvasSize = configuration.canvasSize

        if panel.frame.size != canvasSize {
            panel.setContentSize(canvasSize)
            view.frame = CGRect(origin: .zero, size: canvasSize)
        }
        view.configuration = configuration
        // イベントトラッキング中でも即時に反映させるため、遅延レイアウトに任せない。
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()

        if settings.isEnabled {
            if !panel.isVisible { panel.orderFrontRegardless() }
            if tracker?.isRunning == false { tracker?.start() }
        } else {
            tracker?.stop()
            panel.orderOut(nil)
        }
        reposition()
    }

    private func move(to location: CGPoint) {
        lastCursorLocation = location
        reposition()
    }

    private func reposition() {
        let size = panel.frame.size
        panel.setFrameOrigin(
            CGPoint(
                x: lastCursorLocation.x - size.width / 2,
                y: lastCursorLocation.y - size.height / 2
            )
        )
    }
}
