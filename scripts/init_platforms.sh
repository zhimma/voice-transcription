#!/bin/bash
# 初始化 Flutter 桌面平台支持
# 需要在本地安装 Flutter 后运行

echo "🖥️ 初始化 Flutter 桌面平台支持"
echo "================================"

cd frontend

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装"
    echo "请访问 https://docs.flutter.dev/get-started/install 安装 Flutter"
    exit 1
fi

# 启用桌面支持
echo "📦 启用桌面平台支持..."
flutter config --enable-macos-desktop
flutter config --enable-windows-desktop
flutter config --enable-linux-desktop

# 创建平台目录
echo ""
echo "🔨 创建平台配置文件..."

# macOS
if [ ! -d "macos" ]; then
    echo "创建 macOS 平台..."
    flutter create --platforms=macos .
fi

# Windows
if [ ! -d "windows" ]; then
    echo "创建 Windows 平台..."
    flutter create --platforms=windows .
fi

# Linux
if [ ! -d "linux" ]; then
    echo "创建 Linux 平台..."
    flutter create --platforms=linux .
fi

# 安装依赖
echo ""
echo "📦 安装依赖..."
flutter pub get

# 运行代码生成
echo ""
echo "🔧 运行代码生成..."
flutter pub run build_runner build --delete-conflicting-outputs || true

echo ""
echo "✅ 平台初始化完成！"
echo ""
echo "🚀 现在可以构建应用:"
echo "   cd frontend"
echo "   flutter build macos    # macOS"
echo "   flutter build windows  # Windows"
echo "   flutter build linux    # Linux"
