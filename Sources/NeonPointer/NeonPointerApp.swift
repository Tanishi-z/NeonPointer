import SwiftUI

@main
struct NeonPointerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra {
            SettingsView()
                .environmentObject(settings)
        } label: {
            Image(systemName: settings.isEnabled ? "cursorarrow.rays" : "cursorarrow")
        }
        .menuBarExtraStyle(.window)
    }
}
