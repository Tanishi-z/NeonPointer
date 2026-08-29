import AppKit
import QuartzCore

/// ディスプレイのリフレッシュに合わせてカーソル座標をポーリングする。
/// `NSEvent.mouseLocation` を読むだけなのでアクセシビリティ権限は不要。
@MainActor
final class CursorTracker {
    private weak var hostView: NSView?
    private var displayLink: CADisplayLink?
    private var lastLocation: CGPoint?
    private let onMove: (CGPoint) -> Void

    init(hostView: NSView, onMove: @escaping (CGPoint) -> Void) {
        self.hostView = hostView
        self.onMove = onMove
    }

    var isRunning: Bool { displayLink != nil }

    func start() {
        guard displayLink == nil, let hostView else { return }
        let link = hostView.displayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastLocation = nil
        tick()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let location = NSEvent.mouseLocation
        guard location != lastLocation else { return }
        lastLocation = location
        onMove(location)
    }

    deinit {
        displayLink?.invalidate()
    }
}
