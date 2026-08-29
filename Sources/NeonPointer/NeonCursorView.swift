import AppKit

struct NeonConfiguration: Equatable {
    var shape: PointerShape
    var size: CGFloat
    var opacity: CGFloat
    var glowRadius: CGFloat
    var strokeWidth: CGFloat
    var color: RGBAColor

    init(settings: SettingsStore) {
        shape = settings.shape
        size = CGFloat(settings.size)
        opacity = CGFloat(settings.opacity)
        glowRadius = CGFloat(settings.glowRadius)
        strokeWidth = CGFloat(settings.strokeWidth)
        color = settings.rgba
    }

    /// 光がはみ出す分の余白。外側グローはシャドウ半径の 2 倍まで広がる。
    private var padding: CGFloat { glowRadius * 4 + strokeWidth }

    var canvasSize: CGSize {
        let side = (size + padding * 2).rounded(.up)
        return CGSize(width: side, height: side)
    }
}

final class NeonCursorView: NSView {
    private let outerGlowLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    private let coreLayer = CAShapeLayer()

    private var shapeLayers: [CAShapeLayer] { [outerGlowLayer, glowLayer, coreLayer] }

    var configuration: NeonConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            needsLayout = true
        }
    }

    init(configuration: NeonConfiguration) {
        self.configuration = configuration
        super.init(frame: CGRect(origin: .zero, size: configuration.canvasSize))
        wantsLayer = true
        layer?.masksToBounds = false
        for shapeLayer in shapeLayers {
            shapeLayer.masksToBounds = false
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            layer?.addSublayer(shapeLayer)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { false }

    override func layout() {
        super.layout()
        redraw()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        layer?.contentsScale = scale
        shapeLayers.forEach { $0.contentsScale = scale }
        redraw()
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let side = configuration.size
        let rect = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        let strokeWidth = configuration.strokeWidth
        let path = configuration.shape.path(in: rect, strokeWidth: strokeWidth)
        let color = configuration.color

        layer?.frame = bounds
        layer?.opacity = Float(configuration.opacity)
        shapeLayers.forEach { $0.frame = bounds }

        // 半径違いの影を重ねて、単層では出しきれないネオン管の滲みを作る。
        for (glow, spread) in [(outerGlowLayer, 2.0), (glowLayer, 0.8)] {
            glow.path = path
            glow.shadowColor = color.cgColor
            glow.shadowOpacity = 1
            glow.shadowRadius = configuration.glowRadius * spread
            glow.shadowOffset = .zero
            // shadowPath を指定すると常に塗りつぶし形状の影になり、線形状のグローが崩れる。
            glow.shadowPath = nil
        }

        let coreColor = color.lightened(by: 0.35)

        if configuration.shape.isStroked {
            for glow in [outerGlowLayer, glowLayer] {
                glow.fillColor = nil
                glow.strokeColor = color.cgColor
                glow.lineWidth = strokeWidth
            }

            coreLayer.path = path
            coreLayer.fillColor = nil
            coreLayer.strokeColor = coreColor.cgColor
            coreLayer.lineWidth = max(1, strokeWidth * 0.4)
        } else {
            for glow in [outerGlowLayer, glowLayer] {
                glow.fillColor = color.cgColor
                glow.strokeColor = nil
                glow.lineWidth = 0
            }

            let coreInset = side * 0.22
            let corePath = configuration.shape.path(
                in: rect.insetBy(dx: coreInset, dy: coreInset),
                strokeWidth: 0
            )
            coreLayer.path = corePath
            coreLayer.fillColor = coreColor.nsColor.withAlphaComponent(0.85).cgColor
            coreLayer.strokeColor = nil
            coreLayer.lineWidth = 0
        }
    }
}
