import AppKit

/// システムカーソルが表示中かどうかを返す。
/// ブラウザの全画面動画などは `CGDisplayHideCursor` ではなく、1x1 の透明な
/// カーソル画像に差し替えて隠すため、現在のカーソル画像の大きさで判定する。
/// `CGCursorIsVisible` は非推奨で SDK のヘッダから外れているため `dlsym` で引き、
/// こちらの方法で隠すアプリにも備える。シンボルが無ければ画像の判定だけを使う。
@MainActor
enum SystemCursorVisibility {
    private typealias IsVisibleFunction = @convention(c) () -> Int32

    private static let isVisibleFunction: IsVisibleFunction? = {
        guard let handle = dlopen(nil, RTLD_NOW),
              let symbol = dlsym(handle, "CGCursorIsVisible") else { return nil }
        return unsafeBitCast(symbol, to: IsVisibleFunction.self)
    }()

    static func isVisible() -> Bool {
        if let isVisibleFunction, isVisibleFunction() == 0 { return false }
        if let size = NSCursor.currentSystem?.image.size, size.width <= 1, size.height <= 1 {
            return false
        }
        return true
    }
}
