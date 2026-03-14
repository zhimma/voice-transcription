# 智能录音转写助手 - 构建脚本
# 支持: macOS, Windows, Linux

.PHONY: all deps build build-all clean dev test help

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
build:
	@echo "🔨 Building for $(PLATFORM)..."
	cd $(FRONTEND_DIR) && flutter build $(PLATFORM) --release
	@echo "✅ Build complete: $(FRONTEND_DIR)/build/$(PLATFORM)/"

# 构建所有平台
build-all:
	@echo "🔨 Building for all platforms..."
	cd $(FRONTEND_DIR) && flutter build macos --release
	cd $(FRONTEND_DIR) && flutter build windows --release
	cd $(FRONTEND_DIR) && flutter build linux --release
	@echo "✅ All builds complete"

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
