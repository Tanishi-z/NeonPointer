import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = OverlayController(settings: .shared)
        controller.start()
        overlay = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlay?.stop()
    }
}
