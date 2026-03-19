# 智能录音转写助手 - 构建脚本
# 支持: macOS, Windows, Linux

.PHONY: all deps build build-all clean dev test help sync-python embed-python embed-python-all build-with-python build-all-with-python prepare-python-macos prepare-python-windows prepare-python-all release-gate

# 变量
APP_NAME = voice_transcription
VERSION = 1.0.0
BUILD_DIR = build
FRONTEND_DIR = frontend
BACKEND_DIR = backend

# 检测平台
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    PLATFORM = macos
else ifeq ($(UNAME_S),Linux)
    PLATFORM = linux
else
    PLATFORM = windows
endif

# 默认目标
all: deps build

# 安装依赖
deps:
	@echo "📦 Installing dependencies..."
	@echo "Flutter dependencies..."
	cd $(FRONTEND_DIR) && flutter pub get
	@echo "Python dependencies..."
	pip3 install -r $(BACKEND_DIR)/requirements.txt || pip install -r $(BACKEND_DIR)/requirements.txt

# 启动开发环境
dev:
	@echo "🚀 Starting development environment..."
	@echo "1. Start Python backend..."
	@python3 $(BACKEND_DIR)/server.py &
	@sleep 2
	@echo "2. Start Flutter frontend..."
	cd $(FRONTEND_DIR) && flutter run -d $(PLATFORM)

# 构建当前平台
build: sync-python
	@echo "🔨 Building for $(PLATFORM)..."
	cd $(FRONTEND_DIR) && flutter build $(PLATFORM) --release
	@echo "✅ Build complete: $(FRONTEND_DIR)/build/$(PLATFORM)/"

# 构建所有平台
build-all: sync-python
	@echo "🔨 Building for all platforms..."
	cd $(FRONTEND_DIR) && flutter build macos --release
	cd $(FRONTEND_DIR) && flutter build windows --release
	cd $(FRONTEND_DIR) && flutter build linux --release
	@echo "✅ All builds complete"

# 构建当前平台并嵌入 Python 运行时
build-with-python: build embed-python

# 构建所有平台并嵌入 Python 运行时
build-all-with-python: build-all embed-python-all

# 运行测试
test:
	@echo "🧪 Running tests..."
	@echo "Flutter tests..."
	cd $(FRONTEND_DIR) && flutter test
	@echo "Python tests..."
	python3 $(BACKEND_DIR)/test_server.py

# 格式化代码
format:
	cd $(FRONTEND_DIR) && flutter format lib/

# 分析代码
analyze:
	cd $(FRONTEND_DIR) && flutter analyze

# 清理
clean:
	cd $(FRONTEND_DIR) && flutter clean
	rm -rf $(BUILD_DIR)

# Docker 构建
docker-build:
	docker-compose build

docker-up:
	docker-compose up -d

docker-down:
	docker-compose down

# 打包安装包（macOS DMG）
package-macos:
	@echo "💿 打包 macOS DMG..."
	./scripts/build_macos_dmg.sh $(VERSION)

# 打包安装包（Windows Setup）
package-windows:
	@echo "💿 打包 Windows Setup..."
	@echo "请在 Windows 环境下运行: .\scripts\build_windows_setup.bat $(VERSION)"

# 打包所有平台
package-all: package-macos
	@echo "✅ macOS 打包完成"
	@echo "⚠️ Windows 打包需要在 Windows 环境下运行"

# 帮助
help:
	@echo "智能录音转写助手 - 构建脚本"
	@echo ""
	@echo "可用命令:"
	@echo "  make deps          - 安装所有依赖"
	@echo "  make dev           - 启动开发环境（前后端）"
	@echo "  make build         - 构建当前平台"
	@echo "  make build-all     - 构建所有平台"
	@echo "  make test          - 运行所有测试"
	@echo "  make format        - 格式化 Flutter 代码"
	@echo "  make analyze       - 分析 Flutter 代码"
	@echo "  make clean         - 清理构建文件"
	@echo "  make docker-build  - 构建 Docker 镜像"
	@echo "  make docker-up     - 启动 Docker 服务"
	@echo "  make docker-down   - 停止 Docker 服务"
	@echo "  make help          - 显示帮助"
	@echo "  make build-with-python     - 构建并嵌入 Python 运行时"
	@echo "  make build-all-with-python - 构建所有平台并嵌入 Python 运行时"
	@echo "  make prepare-python-macos  - 下载并准备 macOS Python 运行时"
	@echo "  make prepare-python-windows - 下载并准备 Windows Python 运行时"
	@echo "  make prepare-python-all    - 下载并准备所有平台 Python 运行时"

# 同步 Python 服务到 Flutter assets
sync-python:
	@./scripts/sync_python_assets.sh

# 嵌入 Python 运行时（需要设置 EMBED_PYTHON_DIR）
embed-python:
	@./scripts/embed_python_runtime.sh $(PLATFORM)

# 嵌入 Python 运行时（所有平台）
embed-python-all:
	@./scripts/embed_python_runtime.sh macos
	@./scripts/embed_python_runtime.sh windows
	@./scripts/embed_python_runtime.sh linux

# 下载并准备 Python 运行时（含依赖）
prepare-python-macos:
	@./scripts/prepare_python_runtime.sh macos aarch64-apple-darwin

prepare-python-windows:
	@./scripts/prepare_python_runtime.sh windows x86_64-pc-windows-msvc

prepare-python-all:
	@./scripts/prepare_python_runtime.sh macos aarch64-apple-darwin
	@./scripts/prepare_python_runtime.sh windows x86_64-pc-windows-msvc
	@./scripts/prepare_python_runtime.sh linux x86_64-unknown-linux-gnu

release-gate:
	@./scripts/release_gate.sh
