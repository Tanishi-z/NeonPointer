import AppKit
import QuartzCore

/// ディスプレイのリフレッシュに合わせてカーソル座標と修飾キーの状態をポーリングする。
/// `NSEvent.mouseLocation` / `NSEvent.modifierFlags` を読むだけなのでアクセシビリティ権限は不要。
@MainActor
final class CursorTracker {
    private weak var hostView: NSView?
    private var displayLink: CADisplayLink?
    private let onTick: (CGPoint, NSEvent.ModifierFlags) -> Void

    init(hostView: NSView, onTick: @escaping (CGPoint, NSEvent.ModifierFlags) -> Void) {
        self.hostView = hostView
        self.onTick = onTick
    }

    var isRunning: Bool { displayLink != nil }

    func start() {
        guard displayLink == nil, let hostView else { return }
        let link = hostView.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        tick()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    /// 軌跡のフェード計算を進める必要があるため、座標が変わらないフレームでも毎回呼ぶ。
    @objc private func tick() {
        onTick(NSEvent.mouseLocation, NSEvent.modifierFlags)
    }

    deinit {
        displayLink?.invalidate()
    }
}
