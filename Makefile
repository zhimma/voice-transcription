# 智能录音转写助手 - Flutter 构建脚本
# 支持: macOS, Windows, Linux

.PHONY: all deps build build-all clean run help

# 变量
APP_NAME = voice_transcription
VERSION = 1.0.0
BUILD_DIR = build

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
	@echo "Installing Flutter dependencies..."
	flutter pub get
	@echo "Installing Python dependencies..."
	pip3 install -r python/requirements.txt || pip install -r python/requirements.txt

# 构建当前平台
build:
	@echo "Building for $(PLATFORM)..."
	flutter build $(PLATFORM) --release
	@echo "Build complete: build/$(PLATFORM)/"

# 构建所有平台
build-all:
	@echo "Building for all platforms..."
	flutter build macos --release
	flutter build windows --release
	flutter build linux --release

# 开发运行
dev:
	flutter run

# 清理
clean:
	flutter clean
	rm -rf $(BUILD_DIR)

# 运行测试
test:
	flutter test

# 代码生成 (freezed)
generate:
	flutter pub run build_runner build --delete-conflicting-outputs

# 格式化代码
format:
	flutter format lib/

# 分析代码
analyze:
	flutter analyze

# 帮助
help:
	@echo "智能录音转写助手 - 构建脚本"
	@echo ""
	@echo "可用命令:"
	@echo "  make deps       - 安装依赖"
	@echo "  make build      - 构建当前平台"
	@echo "  make build-all  - 构建所有平台"
	@echo "  make dev        - 开发运行"
	@echo "  make clean      - 清理构建文件"
	@echo "  make test       - 运行测试"
	@echo "  make generate   - 生成代码 (freezed)"
	@echo "  make format     - 格式化代码"
	@echo "  make analyze    - 分析代码"
	@echo "  make help       - 显示帮助"
