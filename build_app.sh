#!/bin/bash
# ShelfDrop アプリバンドル (.app) 作成スクリプト
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/debug"
APP_NAME="ShelfDrop"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 ビルド中..."
swift build

echo "📦 アプリバンドルを作成中..."

# 既存のバンドルを削除
rm -rf "$APP_BUNDLE"

# ディレクトリ構造を作成
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 実行ファイルをコピー
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"

# Info.plist をコピー
cp "$SCRIPT_DIR/Sources/ShelfDrop/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

# アプリアイコンを作成
create_app_icon() {
    local ICON_SOURCE="$SCRIPT_DIR/AppIcon.png"
    
    if [ ! -f "$ICON_SOURCE" ]; then
        echo "⚠️  AppIcon.png が見つかりません。アイコンをスキップします。"
        return
    fi
    
    local ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    
    # PNG形式に確実に変換
    local TEMP_PNG="/tmp/shelfdrop_icon_source.png"
    sips -s format png "$ICON_SOURCE" --out "$TEMP_PNG" > /dev/null 2>&1
    
    # sips でさまざまなサイズに変換
    local sizes=(16 32 128 256 512)
    for size in "${sizes[@]}"; do
        sips -z $size $size "$TEMP_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" > /dev/null 2>&1
        local size2x=$((size * 2))
        sips -z $size2x $size2x "$TEMP_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    rm -f "$TEMP_PNG"
    
    # iconutil で .icns に変換
    if iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null; then
        echo "✅ アプリアイコンを作成しました"
    else
        echo "⚠️  iconutil エラー。PNG を直接コピーします。"
        cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.png"
    fi
    
    # iconset ディレクトリを削除
    rm -rf "$ICONSET_DIR"
}

create_app_icon

# アドホック署名（AirDrop等で他のMacに送った時に破損扱いされるのを防ぐため）
echo "🔐 アプリに署名しています..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 共有用の正しいZipファイルを作成（標準のzipコマンドだと実行権限が壊れるためdittoを使用）
echo "🗜️  共有用のZipファイルを作成中..."
DITTO_ZIP="$SCRIPT_DIR/${APP_NAME}.zip"
rm -f "$DITTO_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$DITTO_ZIP"

echo ""
echo "✅ アプリバンドルの作成が完了しました!"
echo "📍 場所: $APP_BUNDLE"
echo "📦 共有用Zip: $DITTO_ZIP (AirDrop等はこのZipを送ってください)"
echo ""
echo "🚀 起動方法:"
echo "   1. Finder で ShelfDrop.app をダブルクリック"
echo "   2. またはターミナルで: open $APP_BUNDLE"
echo ""
echo "💡 アプリケーションフォルダに移動するには:"
echo "   cp -r $APP_BUNDLE /Applications/"
