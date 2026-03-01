#!/bin/bash
# ShelfDropを再起動するスクリプト
# 実行中のShelfDropを終了し、再ビルドして起動する

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/ShelfDrop.app"

echo "🔄 ShelfDrop を再起動中..."

# 実行中のShelfDropを終了
pkill -f "ShelfDrop" 2>/dev/null
sleep 0.5

# ビルド
echo "🔨 ビルド中..."
cd "$SCRIPT_DIR"
swift build 2>&1
if [ $? -ne 0 ]; then
    echo "❌ ビルドに失敗しました"
    exit 1
fi

# アプリバンドル更新
bash "$SCRIPT_DIR/build_app.sh" 2>&1

# 起動
echo "🚀 起動中..."
open "$APP_PATH"
echo "✅ ShelfDrop を起動しました！"
