# Neon Pointer

[English](README.en.md) | 日本語

マウスカーソルの周りにネオン風の半透明シェイプを表示して、カーソル位置を見つけやすくする macOS 常駐アプリです。

紹介ページ: https://tanishi-z.github.io/NeonPointer/

- 形状: 円 / リング / 十字 / 四角
- 色・サイズ・不透明度・グロー（発光の強さ）・線幅を調整可能
- メニューバーから ON/OFF と全設定を操作
- 設定は自動保存（`UserDefaults`）
- オーバーレイはクリックを透過するので、下のアプリの操作を邪魔しません
- カーソル座標の取得に `NSEvent.mouseLocation` のみを使うため、**アクセシビリティ権限は不要**です

## 必要環境

- macOS 14 以上
- Xcode 15 以上（コマンドラインビルドに使用）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## ビルド

```sh
make build   # dist/NeonPointer.app を生成
make run     # ビルドして起動
make dmg     # dist/NeonPointer.dmg を生成
make clean   # 生成物を削除
```

`NeonPointer.xcodeproj` は `project.yml` から自動生成されます。直接編集せず `project.yml` を変更してください。

## インストール

1. [Releases](https://github.com/Tanishi-z/NeonPointer/releases/latest) から `NeonPointer.dmg` をダウンロードして開く（自分でビルドした場合は `dist/NeonPointer.dmg`）
2. `NeonPointer.app` を `Applications` にドラッグ
3. 初回のみ、アプリを **右クリック → 開く** を選んで「開く」を押す

未署名アプリのため、ダブルクリックだと「開発元を検証できません」と表示されます。それでも開けない場合は次を実行してください。

```sh
xattr -cr /Applications/NeonPointer.app
```

## 署名して配布する場合

Apple Developer Program の Developer ID を持っている場合は、署名 ID を環境変数で渡せます。

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg
```

公証（notarization）まで行う場合は、生成した dmg に対して `xcrun notarytool submit` と `xcrun stapler staple` を実行してください。

## 構成

| ファイル | 役割 |
| --- | --- |
| `Sources/NeonPointer/NeonPointerApp.swift` | エントリポイント。`MenuBarExtra` を定義 |
| `Sources/NeonPointer/AppDelegate.swift` | オーバーレイの起動・終了 |
| `Sources/NeonPointer/SettingsStore.swift` | 設定モデルと永続化 |
| `Sources/NeonPointer/PointerShape.swift` | 形状の定義と `CGPath` 生成 |
| `Sources/NeonPointer/OverlayPanel.swift` | クリック透過の全スペース表示パネル |
| `Sources/NeonPointer/NeonCursorView.swift` | `CAShapeLayer` によるネオン描画 |
| `Sources/NeonPointer/CursorTracker.swift` | `CADisplayLink` によるカーソル追従 |
| `Sources/NeonPointer/OverlayController.swift` | 設定・追従・描画の統合 |
| `Sources/NeonPointer/SettingsView.swift` | SwiftUI 設定画面 |

## ライセンス

[MIT License](LICENSE)
