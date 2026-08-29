#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="NeonPointer"
BUILD_DIR="$ROOT/.build"
DIST_DIR="$ROOT/dist"

command -v xcodegen >/dev/null || { echo "xcodegen が必要です: brew install xcodegen" >&2; exit 1; }

echo "==> Xcode プロジェクトを生成"
xcodegen generate

echo "==> Release ビルド"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

PRODUCT="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"
[ -d "$PRODUCT" ] || { echo "ビルド成果物が見つかりません: $PRODUCT" >&2; exit 1; }

echo "==> dist へ配置"
mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/$APP_NAME.app"
cp -R "$PRODUCT" "$DIST_DIR/$APP_NAME.app"

# 未指定なら ad-hoc 署名。Developer ID がある場合は SIGN_IDENTITY で上書きする。
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
echo "==> 署名 (identity: $SIGN_IDENTITY)"
codesign --force --deep --sign "$SIGN_IDENTITY" "$DIST_DIR/$APP_NAME.app"

echo "完了: $DIST_DIR/$APP_NAME.app"
