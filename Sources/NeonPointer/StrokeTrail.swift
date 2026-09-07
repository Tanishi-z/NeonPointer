import CoreGraphics
import QuartzCore

/// 修飾キー描画で生まれる 1 本の線。座標はすべてグローバル座標。
struct TrailStroke {
    let id: Int
    var points: [CGPoint]
    var path: CGPath
    var bounds: CGRect
    /// フェードイン／フェードアウトの計算基準時刻。
    var anchorTime: CFTimeInterval
    /// `anchorTime` 時点でのアルファ値。復活時はここから 0.15 秒でフェードインする。
    var anchorAlpha: Double
}

/// 描画用に評価済みの 1 本分の情報。
struct TrailRenderItem {
    let id: Int
    let path: CGPath
    let alpha: Double
}

/// フェードインにかける時間。描画再開時、消えかけの線がここで元の濃さへ戻る。
private let trailFadeInDuration: CFTimeInterval = 0.15
/// 新しい点として採用する最小移動距離（グローバル座標、pt）。
private let trailMinPointDistance: CGFloat = 1.5
/// 保持するストローク数の上限。古いものから破棄する。
private let trailMaxStrokes = 200
/// これ未満のアルファは「消えた」とみなして描画・保持対象から外す。
private let trailInvisibleAlphaThreshold = 0.004

/// 描画中／消えかけ／消滅済みのストロークをすべて管理するモデル。
/// AppKit のレイヤーには一切依存しない純粋な状態計算。
struct StrokeTrail {
    private(set) var strokes: [TrailStroke] = []
    private(set) var isDrawing = false
    private var nextID = 0

    /// 描画状態の遷移を処理する。
    /// - 非描画 → 描画: 生存中の全ストロークを現在のアルファで固定し、そこから 0.15 秒フェードインさせる。新しい空ストロークを開始する。
    /// - 描画 → 非描画: 全ストロークを現在のアルファで固定し、そこから hold/fade カウントを開始する。点が 2 個未満のストロークは即破棄する。
    mutating func setDrawing(_ drawing: Bool, at now: CFTimeInterval) {
        guard drawing != isDrawing else { return }

        for index in strokes.indices {
            strokes[index].anchorAlpha = Self.alpha(of: strokes[index], isDrawing: isDrawing, at: now, hold: 0, fade: 0)
            strokes[index].anchorTime = now
        }

        isDrawing = drawing

        if drawing {
            strokes.append(
                TrailStroke(
                    id: nextID,
                    points: [],
                    path: CGMutablePath(),
                    bounds: .null,
                    anchorTime: now,
                    anchorAlpha: 1
                )
            )
            nextID += 1
            if strokes.count > trailMaxStrokes {
                strokes.removeFirst(strokes.count - trailMaxStrokes)
            }
        } else {
            strokes.removeAll { $0.points.count < 2 }
        }
    }

    /// 描画中のみ、末尾のストロークへ点を追加する。
    mutating func append(_ point: CGPoint) {
        guard isDrawing, !strokes.isEmpty else { return }
        let lastIndex = strokes.count - 1

        if let previous = strokes[lastIndex].points.last {
            let dx = point.x - previous.x
            let dy = point.y - previous.y
            guard dx * dx + dy * dy >= trailMinPointDistance * trailMinPointDistance else { return }
        }

        strokes[lastIndex].points.append(point)
        strokes[lastIndex].path = Self.smoothedPath(through: strokes[lastIndex].points)
        strokes[lastIndex].bounds = strokes[lastIndex].path.boundingBoxOfPath
    }

    /// 完全に消えたストロークを取り除く。一度消えた線は二度と戻らない。
    mutating func prune(now: CFTimeInterval, hold: Double, fade: Double) {
        guard !isDrawing else { return }
        let isDrawing = isDrawing
        strokes.removeAll { Self.alpha(of: $0, isDrawing: isDrawing, at: now, hold: hold, fade: fade) <= trailInvisibleAlphaThreshold }
    }

    mutating func clear() {
        strokes.removeAll()
        isDrawing = false
    }

    /// 現在描画可能なストロークをレンダリング用に評価する。
    func renderItems(at now: CFTimeInterval, hold: Double, fade: Double) -> [TrailRenderItem] {
        strokes.compactMap { stroke in
            guard stroke.points.count >= 2 else { return nil }
            let a = Self.alpha(of: stroke, isDrawing: isDrawing, at: now, hold: hold, fade: fade)
            guard a > trailInvisibleAlphaThreshold else { return nil }
            return TrailRenderItem(id: stroke.id, path: stroke.path, alpha: a)
        }
    }

    /// 表示中の全ストロークを内包するグローバル座標の矩形（カリング用）。
    func bounds(at now: CFTimeInterval, hold: Double, fade: Double) -> CGRect? {
        var result: CGRect?
        for stroke in strokes {
            guard stroke.points.count >= 2 else { continue }
            guard Self.alpha(of: stroke, isDrawing: isDrawing, at: now, hold: hold, fade: fade) > trailInvisibleAlphaThreshold else { continue }
            result = result.map { $0.union(stroke.bounds) } ?? stroke.bounds
        }
        return result
    }

    private static func alpha(of stroke: TrailStroke, isDrawing: Bool, at now: CFTimeInterval, hold: Double, fade: Double) -> Double {
        if isDrawing {
            let t = min(1, max(0, (now - stroke.anchorTime) / trailFadeInDuration))
            return stroke.anchorAlpha + (1 - stroke.anchorAlpha) * t
        }

        let elapsed = now - stroke.anchorTime
        if elapsed < hold { return stroke.anchorAlpha }
        guard fade > 0 else { return 0 }
        let fadeElapsed = elapsed - hold
        return stroke.anchorAlpha * max(0, 1 - fadeElapsed / fade)
    }

    /// 点列を中点通過の 2 次ベジエで滑らかにつないだパスを作る。
    private static func smoothedPath(through points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)

        switch points.count {
        case 1:
            break
        case 2:
            path.addLine(to: points[1])
        default:
            for i in 1..<(points.count - 1) {
                let mid = CGPoint(
                    x: (points[i].x + points[i + 1].x) / 2,
                    y: (points[i].y + points[i + 1].y) / 2
                )
                path.addQuadCurve(to: mid, control: points[i])
            }
            path.addLine(to: points[points.count - 1])
        }

        return path
    }
}
