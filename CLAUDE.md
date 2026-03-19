# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

智能录音转写助手 - 基于 Flutter 的跨平台桌面应用，支持本地语音识别 (Whisper) 和云端 API (Qwen/OpenAI)。

技术栈：Flutter 3.16+ + Python 3.8+，支持 macOS、Windows、Linux。

## 常用命令

```bash
# 开发环境
make dev              # 启动前后端开发环境（启动 Python 服务 + Flutter 应用）
make deps             # 安装所有依赖（Flutter + Python）

# 测试
make test             # 运行所有测试（Flutter + Python）
cd frontend && flutter test                    # 仅运行 Flutter 测试
cd frontend && flutter test test/widget_test.dart   # 运行单个测试文件
python3 backend/test_server.py                 # 仅运行 Python 测试

# 代码质量
cd frontend && flutter analyze               # 静态分析
cd frontend && flutter format lib/           # 格式化代码

# 构建
make build            # 构建当前平台（自动同步 Python 资源）
make build-all        # 构建所有平台（macOS/Windows/Linux）
make build-with-python    # 构建并嵌入 Python 运行时

# 清理
make clean            # 清理 Flutter 构建文件

# Docker
docker-compose up -d  # 启动 Docker 服务
```

## 项目架构

### 整体架构

```
┌─────────────────┐     HTTP API (port 8765)     ┌──────────────────┐
│  Flutter 前端    │ ◄──────────────────────────► │  Python 后端服务  │
│  (UI + 状态管理) │                              │  (Whisper/AI API)│
└─────────────────┘                              └──────────────────┘
         │                                                │
         ▼                                                ▼
┌─────────────────┐                              ┌──────────────────┐
│  SQLite (本地)   │                              │  模型文件存储     │
└─────────────────┘                              └──────────────────┘
```

前端与后端通过本地 HTTP API 通信，Python 服务由 Flutter 应用自动启动和管理。

### 前端架构 (frontend/lib/)

**状态管理**：使用 `flutter_riverpod` 进行状态管理

- `providers/task_provider.dart` - 任务列表和当前任务状态
- `providers/config_provider.dart` - 应用配置状态

**服务层** (`services/`):
- `task_service.dart` - 任务业务逻辑，协调转写和摘要流程
- `database_service.dart` - SQLite 数据库操作
- `config_service.dart` - 配置读写（JSON/YAML）
- `logger_service.dart` - 结构化日志记录
- `export_service.dart` - PDF/文本导出
- `app_router.dart` - GoRouter 路由配置

**模型层** (`models/`):
- `task.dart` - 任务、转写结果、摘要结果、工作流步骤
- `channel.dart` - API 渠道配置

**通信层** (`ffi/`):
- `native_service.dart` - 启动 Python 进程并通过 HTTP API 通信

**UI 层** (`pages/`, `ui/`):
- `home_page.dart` - 任务列表
- `upload_page.dart` - 新建任务/文件上传
- `task_detail_page.dart` - 任务详情和结果展示
- `settings_page.dart` - 模型和 API 配置
- `config_editor_page.dart` - JSON/YAML 配置编辑器
- `logs_page.dart` - 日志查看

### 后端架构 (backend/)

`server.py` - 单文件 HTTP 服务，主要端点：

- `POST /transcribe` - 语音识别（支持 whisper/qwen 提供者）
- `POST /summarize` - 文本摘要（支持 local/qwen 提供者）
- `POST /download_model` - 下载 Whisper 模型
- `GET /download_status` - 查询模型下载进度
- `GET /models` - 列出可用模型及其状态
- `GET /health` - 健康检查

模型默认存储在 `~/.voice-transcription/models/`，支持从 ModelScope 或 HuggingFace 下载。

### 关键流程

**任务执行流程** (`TaskService.executeTask`):
1. 创建任务记录 → 更新状态为 processing
2. 执行语音识别 (`_executeTranscription`) → 保存转写结果
3. 执行摘要生成 (`_executeSummary`) → 保存摘要结果（可选，失败不阻断）
4. 更新状态为 completed 或 failed

**Python 服务启动流程** (`NativeService.initialize`):
1. 检查是否已有健康的服务在运行
2. 按优先级查找 Python：嵌入式 → 应用包内 → 系统环境
3. 启动 Python 进程并设置环境变量
4. 健康检查通过后标记为已初始化

### 数据存储

- **数据库**: SQLite (通过 `sqflite_common_ffi` 支持桌面端)
  - 任务表、转写结果表、摘要结果表、工作流步骤表
- **配置**: JSON/YAML 文件，存储在应用支持目录
- **模型**: 文件系统，默认 `~/.voice-transcription/models/`
- **日志**: 结构化日志，存储在应用支持目录的 `logs/` 下

### 环境变量

Python 服务通过环境变量接收配置：
- `VOICE_APP_SUPPORT_DIR` - 应用支持目录
- `VOICE_LOG_DIR` - 日志目录
- `VOICE_MODEL_DIR` - 模型存储目录
- `VOICE_MODEL_SOURCE` - 模型下载源（modelscope/huggingface）
- `HF_ENDPOINT` - HuggingFace 镜像地址
- `VOICE_WHISPER_WEIGHTS_BASE_URL` - Whisper 权重镜像地址

## 目录结构

```
├── frontend/          # Flutter 前端
│   ├── lib/          # Dart 源代码
│   │   ├── models/   # 数据模型
│   │   ├── pages/    # 页面
│   │   ├── providers/# 状态管理
│   │   ├── services/ # 业务服务
│   │   └── ffi/      # Python 通信
│   ├── test/         # 测试代码
│   └── pubspec.yaml  # Flutter 依赖
├── backend/          # Python 后端
│   ├── server.py     # HTTP API 服务
│   └── requirements.txt
├── docs/             # 文档
├── scripts/          # 构建和打包脚本
└── Makefile          # 构建命令
```
