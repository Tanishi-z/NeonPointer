import AppKit

/// 軌跡描画を有効にする修飾キー。
enum TrailModifier: String, CaseIterable, Identifiable {
    case option
    case control
    case shift
    case command
    case function

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .option: return "⌥"
        case .control: return "⌃"
        case .shift: return "⇧"
        case .command: return "⌘"
        case .function: return "fn"
        }
    }

    var eventFlag: NSEvent.ModifierFlags {
        switch self {
        case .option: return .option
        case .control: return .control
        case .shift: return .shift
        case .command: return .command
        case .function: return .function
        }
    }

    /// 他の修飾キーが同時に押されていても検出できるよう、包含判定にする。
    func isActive(in flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection(.deviceIndependentFlagsMask).contains(eventFlag)
    }
}
