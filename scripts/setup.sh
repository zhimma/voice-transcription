#!/bin/bash
# 智能录音转写助手 - 开发环境设置脚本

set -e

echo "🎙️ 智能录音转写助手 - 开发环境设置"
echo "=================================="

# 检查 Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter 未安装"
    echo "请访问 https://docs.flutter.dev/get-started/install 安装 Flutter"
    exit 1
fi

echo "✅ Flutter 版本: $(flutter --version | head -1)"

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安装"
    exit 1
fi

echo "✅ Python 版本: $(python3 --version)"

# 安装 Flutter 依赖
echo ""
echo "📦 安装 Flutter 依赖..."
flutter pub get

# 安装 Python 依赖
echo ""
echo "📦 安装 Python 依赖..."
if [ -f "python/requirements.txt" ]; then
    pip3 install -r python/requirements.txt || pip install -r python/requirements.txt
fi

# 创建必要的目录
echo ""
echo "📁 创建项目目录..."
mkdir -p ~/.voice-transcription/models
mkdir -p ~/.voice-transcription/logs
mkdir -p logs

# 复制环境配置示例
if [ ! -f ".env" ]; then
    echo ""
    echo "📝 创建环境配置文件..."
    cp .env.example .env
    echo "请编辑 .env 文件配置你的 API Keys"
fi

echo ""
echo "✅ 设置完成！"
echo ""
echo "🚀 快速开始:"
echo "   make dev     - 启动开发服务器"
echo "   make build   - 构建生产版本"
echo "   make test    - 运行测试"
echo ""
echo "📖 更多信息请查看 README.md"
