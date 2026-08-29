import CoreGraphics
import Foundation

enum PointerShape: String, CaseIterable, Identifiable {
    case circle
    case ring
    case crosshair
    case square

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .circle: return "円"
        case .ring: return "リング"
        case .crosshair: return "十字"
        case .square: return "四角"
        }
    }

    var symbolName: String {
        switch self {
        case .circle: return "circle.fill"
        case .ring: return "circle"
        case .crosshair: return "plus"
        case .square: return "square.fill"
        }
    }

    /// 線幅スライダーを有効にするかどうか。
    var usesStrokeWidth: Bool {
        switch self {
        case .circle, .square: return false
        case .ring, .crosshair: return true
        }
    }

    var isStroked: Bool { usesStrokeWidth }

    /// `rect` に内接する形状のパスを返す。線描画の場合は線幅の半分だけ内側に寄せる。
    func path(in rect: CGRect, strokeWidth: CGFloat) -> CGPath {
        let inset = isStroked ? strokeWidth / 2 : 0
        let bounds = rect.insetBy(dx: inset, dy: inset)
        guard bounds.width > 0, bounds.height > 0 else {
            return CGPath(rect: .zero, transform: nil)
        }

        switch self {
        case .circle, .ring:
            return CGPath(ellipseIn: bounds, transform: nil)
        case .square:
            let radius = min(bounds.width, bounds.height) * 0.18
            return CGPath(
                roundedRect: bounds,
                cornerWidth: radius,
                cornerHeight: radius,
                transform: nil
            )
        case .crosshair:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.minX, y: bounds.midY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.midY))
            path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
            return path
        }
    }
}
