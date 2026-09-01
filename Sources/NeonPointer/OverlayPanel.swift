import AppKit

final class OverlayPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: CGRect(origin: .zero, size: contentView.frame.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        animationBehavior = .none
        self.contentView = contentView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }

    // このパネルは常に `screen.frame` と同じ大きさ・原点で配置される。
    // AppKit の既定の制約（メニューバー帯を避ける等）をかけると、
    // 複数モニタが縦にずれた構成で原点が勝手に補正され、カーソル追従が飛んで見える。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
