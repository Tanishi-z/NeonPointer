import Foundation
import ServiceManagement

/// ログイン時の自動起動（常駐）を `SMAppService` で管理する。
/// システム設定 > ログイン項目 が唯一の正とみなし、UserDefaults には保存しない。
@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var isEnabled: Bool

    private init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// メニューが開かれるたびに呼び、システム設定側での変更を反映する。
    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // 登録/解除に失敗した場合も、以下で実際のステータスに合わせて表示を戻す。
        }
        refresh()
    }
}
