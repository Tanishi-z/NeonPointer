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
        static let hideWhenCursorHidden = "hideWhenCursorHidden"
        static let shape = "shape"
        static let size = "size"
        static let opacity = "opacity"
        static let glowRadius = "glowRadius"
        static let strokeWidth = "strokeWidth"
        static let color = "color"
        static let trailEnabled = "trailEnabled"
        static let trailModifier = "trailModifier"
        static let trailHoldDuration = "trailHoldDuration"
        static let trailFadeDuration = "trailFadeDuration"
        static let trailWidth = "trailWidth"
        static let trailGlowRadius = "trailGlowRadius"
        static let trailUsesCursorColor = "trailUsesCursorColor"
        static let trailColor = "trailColor"
    }

    private enum Default {
        static let isEnabled = true
        static let hideWhenCursorHidden = false
        static let shape = PointerShape.ring
        static let size: Double = 48
        static let opacity: Double = 0.75
        static let glowRadius: Double = 18
        static let strokeWidth: Double = 4
        static let color = RGBAColor.neonCyan
        static let trailEnabled = true
        static let trailModifier = TrailModifier.option
        static let trailHoldDuration: Double = 2.0
        static let trailFadeDuration: Double = 1.5
        static let trailWidth: Double = 6
        static let trailGlowRadius: Double = 14
        static let trailUsesCursorColor = true
        static let trailColor = RGBAColor.neonCyan
    }

    static let sizeRange: ClosedRange<Double> = 12...220
    static let opacityRange: ClosedRange<Double> = 0.05...1.0
    static let glowRange: ClosedRange<Double> = 0...60
    static let strokeRange: ClosedRange<Double> = 1...24
    static let trailHoldRange: ClosedRange<Double> = 0.2...30
    static let trailFadeRange: ClosedRange<Double> = 0.1...10
    static let trailWidthRange: ClosedRange<Double> = 1...40
    static let trailGlowRange: ClosedRange<Double> = 0...60

    private let defaults: UserDefaults

    /// 値が確定した後に発火する。`objectWillChange` は変更前に発火するうえ、
    /// スケジューラを挟むとイベントトラッキング中に配送が止まるため別に用意する。
    let didChange = PassthroughSubject<Void, Never>()

    @Published var isEnabled: Bool { didSet { persist(isEnabled, forKey: Key.isEnabled) } }
    @Published var hideWhenCursorHidden: Bool {
        didSet { persist(hideWhenCursorHidden, forKey: Key.hideWhenCursorHidden) }
    }
    @Published var shape: PointerShape { didSet { persist(shape.rawValue, forKey: Key.shape) } }
    @Published var size: Double { didSet { persist(size, forKey: Key.size) } }
    @Published var opacity: Double { didSet { persist(opacity, forKey: Key.opacity) } }
    @Published var glowRadius: Double { didSet { persist(glowRadius, forKey: Key.glowRadius) } }
    @Published var strokeWidth: Double { didSet { persist(strokeWidth, forKey: Key.strokeWidth) } }

    @Published var rgba: RGBAColor {
        didSet { persist(try? JSONEncoder().encode(rgba), forKey: Key.color) }
    }

    @Published var trailEnabled: Bool { didSet { persist(trailEnabled, forKey: Key.trailEnabled) } }
    @Published var trailModifier: TrailModifier {
        didSet { persist(trailModifier.rawValue, forKey: Key.trailModifier) }
    }
    @Published var trailHoldDuration: Double { didSet { persist(trailHoldDuration, forKey: Key.trailHoldDuration) } }
    @Published var trailFadeDuration: Double { didSet { persist(trailFadeDuration, forKey: Key.trailFadeDuration) } }
    @Published var trailWidth: Double { didSet { persist(trailWidth, forKey: Key.trailWidth) } }
    @Published var trailGlowRadius: Double { didSet { persist(trailGlowRadius, forKey: Key.trailGlowRadius) } }
    @Published var trailUsesCursorColor: Bool {
        didSet { persist(trailUsesCursorColor, forKey: Key.trailUsesCursorColor) }
    }
    @Published var trailRGBA: RGBAColor {
        didSet { persist(try? JSONEncoder().encode(trailRGBA), forKey: Key.trailColor) }
    }

    private func persist(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
        didChange.send()
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        isEnabled = defaults.object(forKey: Key.isEnabled) as? Bool ?? Default.isEnabled
        hideWhenCursorHidden = defaults.object(forKey: Key.hideWhenCursorHidden) as? Bool
            ?? Default.hideWhenCursorHidden
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

        trailEnabled = defaults.object(forKey: Key.trailEnabled) as? Bool ?? Default.trailEnabled
        trailModifier = (defaults.string(forKey: Key.trailModifier).flatMap(TrailModifier.init(rawValue:)))
            ?? Default.trailModifier
        trailHoldDuration = defaults.object(forKey: Key.trailHoldDuration) as? Double ?? Default.trailHoldDuration
        trailFadeDuration = defaults.object(forKey: Key.trailFadeDuration) as? Double ?? Default.trailFadeDuration
        trailWidth = defaults.object(forKey: Key.trailWidth) as? Double ?? Default.trailWidth
        trailGlowRadius = defaults.object(forKey: Key.trailGlowRadius) as? Double ?? Default.trailGlowRadius
        trailUsesCursorColor = defaults.object(forKey: Key.trailUsesCursorColor) as? Bool ?? Default.trailUsesCursorColor

        if let data = defaults.data(forKey: Key.trailColor),
           let decoded = try? JSONDecoder().decode(RGBAColor.self, from: data) {
            trailRGBA = decoded
        } else {
            trailRGBA = Default.trailColor
        }

        clampToValidRanges()
    }

    func resetToDefaults() {
        hideWhenCursorHidden = Default.hideWhenCursorHidden
        shape = Default.shape
        size = Default.size
        opacity = Default.opacity
        glowRadius = Default.glowRadius
        strokeWidth = Default.strokeWidth
        rgba = Default.color
        trailEnabled = Default.trailEnabled
        trailModifier = Default.trailModifier
        trailHoldDuration = Default.trailHoldDuration
        trailFadeDuration = Default.trailFadeDuration
        trailWidth = Default.trailWidth
        trailGlowRadius = Default.trailGlowRadius
        trailUsesCursorColor = Default.trailUsesCursorColor
        trailRGBA = Default.trailColor
    }

    private func clampToValidRanges() {
        size = size.clamped(to: Self.sizeRange)
        opacity = opacity.clamped(to: Self.opacityRange)
        glowRadius = glowRadius.clamped(to: Self.glowRange)
        trailHoldDuration = trailHoldDuration.clamped(to: Self.trailHoldRange)
        trailFadeDuration = trailFadeDuration.clamped(to: Self.trailFadeRange)
        trailWidth = trailWidth.clamped(to: Self.trailWidthRange)
        trailGlowRadius = trailGlowRadius.clamped(to: Self.trailGlowRange)
        strokeWidth = strokeWidth.clamped(to: Self.strokeRange)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
