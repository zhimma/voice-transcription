#!/bin/bash
# macOS DMG 打包脚本
# 使用方法: ./scripts/build_macos_dmg.sh [版本号]

set -e

VERSION=${1:-"1.0.0"}
APP_NAME="智能录音转写助手"
APP_BUNDLE="voice_transcription"
BUILD_DIR="frontend/build/macos/Build/Products/Release"
OUTPUT_DIR="build_outputs"

echo "🍎 开始打包 macOS 应用..."
echo "版本: $VERSION"
echo ""

# 检查 Flutter 项目
cd frontend

# 1. 清理旧构建
echo "🧹 清理旧构建..."
flutter clean

# 2. 获取依赖
echo "📦 获取依赖..."
flutter pub get

# 3. 生成代码
echo "🔧 生成代码..."
flutter pub run build_runner build --delete-conflicting-outputs || true

# 4. 构建 Release 版本
echo "🔨 构建 Release 版本..."
flutter build macos --release

# 5. 检查构建结果
if [ ! -d "$BUILD_DIR/$APP_BUNDLE.app" ]; then
    echo "❌ 构建失败: 未找到 $APP_BUNDLE.app"
    exit 1
fi

echo "✅ 构建成功"
echo ""

# 6. 复制 Python 后端到应用包
echo "📁 复制 Python 后端..."
mkdir -p "$BUILD_DIR/$APP_BUNDLE.app/Contents/Resources/python"
cp -r ../backend/* "$BUILD_DIR/$APP_BUNDLE.app/Contents/Resources/python/"

# 7. 创建输出目录
cd ..
mkdir -p "$OUTPUT_DIR"

# 8. 检查 create-dmg 是否安装
if ! command -v create-dmg &> /dev/null; then
    echo "⚠️ create-dmg 未安装，尝试安装..."
    brew install create-dmg || {
        echo "❌ 安装失败，请手动安装: brew install create-dmg"
        # 使用简单打包方式
        echo "📦 使用 ZIP 打包..."
        cd "$BUILD_DIR"
        zip -r "../../../$OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.zip" "$APP_BUNDLE.app"
        echo "✅ ZIP 打包完成: $OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.zip"
        exit 0
    }
fi

# 9. 创建 DMG
echo "💿 创建 DMG 安装包..."
cd "$BUILD_DIR"

# 删除旧的 DMG
rm -f "../../../$OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.dmg"

# 创建 DMG
create-dmg \
    --volname "$APP_NAME" \
    --volicon "../../../assets/app_icon.icns" 2>/dev/null || true \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --text-size 12 \
    --icon "$APP_BUNDLE.app" 200 200 \
    --hide-extension "$APP_BUNDLE.app" \
    --app-drop-link 600 200 \
    --no-internet-enable \
    "../../../$OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.dmg" \
    "$APP_BUNDLE.app"

cd ../../..

# 10. 验证输出
if [ -f "$OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.dmg" ]; then
    echo ""
    echo "✅ DMG 打包成功！"
    echo ""
    echo "📦 输出文件:"
    ls -lh "$OUTPUT_DIR/${APP_BUNDLE}-macOS-${VERSION}.dmg"
    echo ""
    echo "🚀 使用方法:"
    echo "   双击 DMG 文件，将应用拖到 Applications 文件夹"
else
    echo "❌ DMG 打包失败"
    exit 1
fi
