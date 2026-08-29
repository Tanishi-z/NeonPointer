#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
APP_NAME="NeonPointer"
VOL_NAME="Neon Pointer"
DIST_DIR="$ROOT/dist"
APP="$DIST_DIR/$APP_NAME.app"
STAGING="$DIST_DIR/dmg-staging"
RAW_DMG="$DIST_DIR/$APP_NAME-raw.dmg"
DMG="$DIST_DIR/$APP_NAME.dmg"

[ -d "$APP" ] || { echo "先に scripts/build.sh を実行してください" >&2; exit 1; }

echo "==> ステージング作成"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# hdiutil create -srcfolder は一時ボリュームのマウントを伴い環境によっては失敗するため、
# マウント不要な makehybrid + convert を使う。
echo "==> ディスクイメージ作成"
rm -f "$RAW_DMG" "$DMG"
hdiutil makehybrid -hfs -hfs-volume-name "$VOL_NAME" -o "$RAW_DMG" "$STAGING" -quiet

echo "==> 圧縮"
hdiutil convert "$RAW_DMG" -format UDZO -o "$DMG" -quiet

rm -rf "$STAGING" "$RAW_DMG"
echo "完了: $DMG"
