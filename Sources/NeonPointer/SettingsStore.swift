import AppKit
import Combine
import SwiftUI

struct RGBAColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let neonCyan = RGBAColor(red: 0.20, green: 0.95, blue: 1.0, alpha: 1.0)

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(_ color: NSColor) {
        let srgb = color.usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent),
            alpha: Double(srgb.alphaComponent)
        )
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var cgColor: CGColor { nsColor.cgColor }

    /// 白に寄せた明るい色。ネオン管の芯の表現に使う。
    func lightened(by amount: Double) -> RGBAColor {
        let t = min(max(amount, 0), 1)
        return RGBAColor(
            red: red + (1 - red) * t,
            green: green + (1 - green) * t,
            blue: blue + (1 - blue) * t,
            alpha: alpha
        )
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let isEnabled = "isEnabled"
        static let shape = "shape"
        static let size = "size"
        static let opacity = "opacity"
        static let glowRadius = "glowRadius"
        static let strokeWidth = "strokeWidth"
        static let color = "color"
    }

    private enum Default {
        static let isEnabled = true
        static let shape = PointerShape.ring
        static let size: Double = 48
        static let opacity: Double = 0.75
        static let glowRadius: Double = 18
        static let strokeWidth: Double = 4
        static let color = RGBAColor.neonCyan
    }

    static let sizeRange: ClosedRange<Double> = 12...220
    static let opacityRange: ClosedRange<Double> = 0.05...1.0
    static let glowRange: ClosedRange<Double> = 0...60
    static let strokeRange: ClosedRange<Double> = 1...24

    private let defaults: UserDefaults

    /// 値が確定した後に発火する。`objectWillChange` は変更前に発火するうえ、
    /// スケジューラを挟むとイベントトラッキング中に配送が止まるため別に用意する。
    let didChange = PassthroughSubject<Void, Never>()

    @Published var isEnabled: Bool { didSet { persist(isEnabled, forKey: Key.isEnabled) } }
    @Published var shape: PointerShape { didSet { persist(shape.rawValue, forKey: Key.shape) } }
    @Published var size: Double { didSet { persist(size, forKey: Key.size) } }
    @Published var opacity: Double { didSet { persist(opacity, forKey: Key.opacity) } }
    @Published var glowRadius: Double { didSet { persist(glowRadius, forKey: Key.glowRadius) } }
    @Published var strokeWidth: Double { didSet { persist(strokeWidth, forKey: Key.strokeWidth) } }

    @Published var rgba: RGBAColor {
        didSet { persist(try? JSONEncoder().encode(rgba), forKey: Key.color) }
    }

    private func persist(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        didChange.send()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? Default.isEnabled
        shape = (defaults.string(forKey: Key.shape).flatMap(PointerShape.init(rawValue:))) ?? Default.shape
        size = defaults.object(forKey: Key.size) as? Double ?? Default.size
        opacity = defaults.object(forKey: Key.opacity) as? Double ?? Default.opacity
        glowRadius = defaults.object(forKey: Key.glowRadius) as? Double ?? Default.glowRadius
        strokeWidth = defaults.object(forKey: Key.strokeWidth) as? Double ?? Default.strokeWidth

        if let data = defaults.data(forKey: Key.color),
           let decoded = try? JSONDecoder().decode(RGBAColor.self, from: data) {
            rgba = decoded
        } else {
            rgba = Default.color
        }

        clampToValidRanges()
    }

    func resetToDefaults() {
        shape = Default.shape
        size = Default.size
        opacity = Default.opacity
        glowRadius = Default.glowRadius
        strokeWidth = Default.strokeWidth
        rgba = Default.color
    }

    private func clampToValidRanges() {
        size = size.clamped(to: Self.sizeRange)
        opacity = opacity.clamped(to: Self.opacityRange)
        glowRadius = glowRadius.clamped(to: Self.glowRange)
        strokeWidth = strokeWidth.clamped(to: Self.strokeRange)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
