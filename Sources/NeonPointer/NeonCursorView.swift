import AppKit

struct NeonConfiguration: Equatable {
    var shape: PointerShape
    var size: CGFloat
    var opacity: CGFloat
    var glowRadius: CGFloat
    var strokeWidth: CGFloat
    var color: RGBAColor
    var trailWidth: CGFloat
    var trailGlowRadius: CGFloat
    var trailColor: RGBAColor

    init(settings: SettingsStore) {
        shape = settings.shape
        size = CGFloat(settings.size)
        opacity = CGFloat(settings.opacity)
        glowRadius = CGFloat(settings.glowRadius)
        strokeWidth = CGFloat(settings.strokeWidth)
        color = settings.rgba
        trailWidth = CGFloat(settings.trailWidth)
        trailGlowRadius = CGFloat(settings.trailGlowRadius)
        trailColor = settings.trailUsesCursorColor ? settings.rgba : settings.trailRGBA
    }

    /// 光がはみ出す分の余白。外側グローはシャドウ半径の 2 倍まで広がる。
    private var padding: CGFloat { glowRadius * 4 + strokeWidth }

    var canvasSize: CGSize {
        let side = (size + padding * 2).rounded(.up)
        return CGSize(width: side, height: side)
    }
}

/// 軌跡の 1 ストローク分のレイヤー群。カーソル本体と同じ「半径違いの影を重ねる」手法を使う。
private final class TrailStrokeLayers {
    let group = CALayer()
    let outerGlow = CAShapeLayer()
    let glow = CAShapeLayer()
    let core = CAShapeLayer()

    init() {
        group.masksToBounds = false
        group.anchorPoint = .zero
        for shapeLayer in [outerGlow, glow, core] {
            shapeLayer.masksToBounds = false
            shapeLayer.fillColor = nil
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            shapeLayer.anchorPoint = .zero
            group.addSublayer(shapeLayer)
        }
    }
}

final class NeonCursorView: NSView {
    /// カーソル位置に追従する層。ビュー自体はスクリーン全面に固定され、
    /// この層だけを `position` で動かすことで、ウィンドウをまたぐ移動を避ける。
    private let neonLayer = CALayer()
    private let outerGlowLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    private let coreLayer = CAShapeLayer()

    /// 軌跡を乗せる層。パスはグローバル座標そのままで構築し、この層を
    /// `-screenOrigin` だけ動かすことで各スクリーンのビューに正しい位置で映す。
    private let trailContainer = CALayer()
    private var trailLayers: [Int: TrailStrokeLayers] = [:]

    private var shapeLayers: [CAShapeLayer] { [outerGlowLayer, glowLayer, coreLayer] }

    var configuration: NeonConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            needsLayout = true
        }
    }

    init(configuration: NeonConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false

        trailContainer.masksToBounds = false
        trailContainer.anchorPoint = .zero
        layer?.addSublayer(trailContainer)

        neonLayer.masksToBounds = false
        neonLayer.bounds = CGRect(origin: .zero, size: configuration.canvasSize)
        layer?.addSublayer(neonLayer)
        for shapeLayer in shapeLayers {
            shapeLayer.masksToBounds = false
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            neonLayer.addSublayer(shapeLayer)
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
        neonLayer.contentsScale = scale
        shapeLayers.forEach { $0.contentsScale = scale }
        trailContainer.contentsScale = scale
        for strokeLayers in trailLayers.values {
            [strokeLayers.outerGlow, strokeLayers.glow, strokeLayers.core].forEach { $0.contentsScale = scale }
        }
        redraw()
    }

    /// カーソルのグローバル座標と、このビューが乗っているスクリーンの原点を渡して
    /// ネオン層を移動させる。ウィンドウ自体は動かさない。
    func update(cursorLocation: CGPoint, screenOrigin: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        neonLayer.position = CGPoint(
            x: cursorLocation.x - screenOrigin.x,
            y: cursorLocation.y - screenOrigin.y
        )
        // 軌跡のパスはグローバル座標のまま構築されているため、層ごと平行移動させる。
        trailContainer.position = CGPoint(x: -screenOrigin.x, y: -screenOrigin.y)
        CATransaction.commit()
    }

    /// カーソル本体の表示・非表示だけを切り替える（軌跡はこの影響を受けない）。
    func setCursorVisible(_ visible: Bool) {
        neonLayer.isHidden = !visible
    }

    /// 現在生存している軌跡ストロークを反映する。`items` に無い id のレイヤーは破棄する。
    func updateTrail(_ items: [TrailRenderItem]) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let color = configuration.trailColor
        let coreColor = color.lightened(by: 0.35)
        let width = configuration.trailWidth
        let glowRadius = configuration.trailGlowRadius

        var seenIDs = Set<Int>()
        for item in items {
            seenIDs.insert(item.id)

            let strokeLayers: TrailStrokeLayers
            if let existing = trailLayers[item.id] {
                strokeLayers = existing
            } else {
                let created = TrailStrokeLayers()
                let scale = window?.backingScaleFactor ?? 2
                [created.outerGlow, created.glow, created.core].forEach { $0.contentsScale = scale }
                trailContainer.addSublayer(created.group)
                trailLayers[item.id] = created
                strokeLayers = created
            }

            strokeLayers.group.opacity = Float(item.alpha)
            strokeLayers.outerGlow.path = item.path
            strokeLayers.glow.path = item.path
            strokeLayers.core.path = item.path

            for (shapeLayer, spread) in [(strokeLayers.outerGlow, 2.0), (strokeLayers.glow, 0.8)] {
                shapeLayer.strokeColor = color.cgColor
                shapeLayer.lineWidth = width
                shapeLayer.shadowColor = color.cgColor
                shapeLayer.shadowOpacity = 1
                shapeLayer.shadowRadius = glowRadius * spread
                shapeLayer.shadowOffset = .zero
                // shadowPath を指定すると線形状のグローが崩れる。カーソル本体と同じ理由。
                shapeLayer.shadowPath = nil
            }
            strokeLayers.core.strokeColor = coreColor.cgColor
            strokeLayers.core.lineWidth = max(1, width * 0.4)
        }

        for (id, strokeLayers) in trailLayers where !seenIDs.contains(id) {
            strokeLayers.group.removeFromSuperlayer()
            trailLayers.removeValue(forKey: id)
        }
    }

    private func redraw() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let canvasSize = configuration.canvasSize
        neonLayer.bounds = CGRect(origin: .zero, size: canvasSize)

        let side = configuration.size
        let rect = CGRect(
            x: (canvasSize.width - side) / 2,
            y: (canvasSize.height - side) / 2,
            width: side,
            height: side
        )
        let strokeWidth = configuration.strokeWidth
        let path = configuration.shape.path(in: rect, strokeWidth: strokeWidth)
        let color = configuration.color

        neonLayer.opacity = Float(configuration.opacity)
        shapeLayers.forEach { $0.frame = CGRect(origin: .zero, size: canvasSize) }

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
