# 智能录音转写助手 - 项目文档

> 项目状态：开发完成 ✅ | 版本：v1.0.0 | 更新时间：2026-03-14

---

## 📋 项目概览

**项目名称**：智能录音转写助手  
**项目类型**：跨平台桌面应用 + Python 后端服务  
**技术栈**：Flutter + Python + Whisper  
**仓库地址**：https://gitlab.hulumibao.com/voice-transcription/frontend

---

## 🎯 核心功能

| 功能模块 | 状态 | 说明 |
|---------|------|------|
| 本地语音识别 | ✅ | 基于 Whisper 模型，支持离线运行 |
| 云端语音识别 | ⚠️ | 支持 Qwen/OpenAI，需配置 API Key |
| 文本摘要 | ✅ | 本地简化版 + 云端智能摘要 |
| 任务管理 | ✅ | 创建、查看、删除转写任务 |
| 配置管理 | ✅ | JSON/YAML 可视化编辑 |
| 模型下载 | ✅ | 应用内下载 Whisper 模型 |
| 跨平台支持 | ✅ | macOS / Windows / Linux |

---

## 🏗️ 项目结构

```
voice-transcription/
├── frontend/              # Flutter 前端
│   ├── lib/              # Dart 源代码
│   │   ├── models/       # 数据模型
│   │   ├── pages/        # 页面
│   │   ├── providers/    # 状态管理
│   │   ├── services/     # 业务服务
│   │   └── ffi/          # FFI 通信
│   ├── test/             # 测试代码
│   ├── pubspec.yaml      # Flutter 依赖
│   └── README.md         # 前端说明
│
├── backend/              # Python 后端
│   ├── server.py         # HTTP API 服务
│   ├── requirements.txt  # Python 依赖
│   └── test_server.py    # 服务端测试
│
├── docs/                 # 文档
│   ├── DEPLOY.md         # 部署文档
│   └── API.md            # API 接口文档
│
├── scripts/              # 脚本工具
│   └── setup.sh          # 开发环境设置
│
├── .github/workflows/    # CI/CD
│   └── build.yml         # 自动构建
│
├── Dockerfile            # Docker 镜像
├── docker-compose.yml    # Docker 编排
├── Makefile             # 构建脚本
├── CHANGELOG.md         # 更新日志
└── PROJECT.md           # 本文件
```

---

## 🚀 快速开始

### 环境要求
- Flutter 3.16+
- Python 3.8+
- 4GB+ RAM
- 2GB+ 磁盘空间

### 一键设置

```bash
# 克隆仓库
git clone https://gitlab.hulumibao.com/voice-transcription/frontend.git
cd frontend

# 运行设置脚本
./scripts/setup.sh

# 启动开发环境
make dev
```

### 手动安装

```bash
# 1. 安装 Flutter 依赖
flutter pub get

# 2. 安装 Python 依赖
pip3 install -r backend/requirements.txt

# 3. 启动 Python 服务
python3 backend/server.py &

# 4. 启动 Flutter 应用
flutter run -d macos  # 或 windows/linux
```

---

## 🧪 测试

```bash
# 运行所有测试
make test

# 前端测试
flutter test

# 后端测试
python backend/test_server.py
```

---

## 📦 构建发布

```bash
# 构建当前平台
make build

# 构建所有平台
make build-all

# Docker 构建
docker-compose up -d
```

---

## ⚙️ 配置说明

### 配置文件位置
- **macOS**: `~/.voice-transcription/config.json`
- **Windows**: `%APPDATA%\voice-transcription\config.json`
- **Linux**: `~/.config/voice-transcription/config.json`

### API Key 配置

```json
{
  "transcription": {
    "cloud_channels": [
      {
        "name": "qwen",
        "enabled": true,
        "api_key": "your-api-key",
        "api_url": "https://dashscope.aliyuncs.com/api/v1"
      }
    ]
  }
}
```

---

## 📚 相关文档

| 文档 | 路径 | 说明 |
|------|------|------|
| 部署文档 | `docs/DEPLOY.md` | 详细部署指南 |
| API 文档 | `docs/API.md` | 接口说明 |
| 前端说明 | `frontend/README.md` | Flutter 前端详情 |
| 更新日志 | `CHANGELOG.md` | 版本历史 |

---

## 👥 团队成员

| 角色 | 负责人 | 职责 |
|------|--------|------|
| 后端开发 | @后端壮壮 | API 设计、服务开发 |
| 测试 | @测试安安 | 测试计划、质量保障 |
| 项目管理 | @队长乐乐 | 需求管理、进度跟踪 |

---

## 🔗 相关链接

- **GitLab 仓库**: https://gitlab.hulumibao.com/voice-transcription/frontend
- **Issues**: https://gitlab.hulumibao.com/voice-transcription/frontend/-/issues
- **CI/CD**: https://gitlab.hulumibao.com/voice-transcription/frontend/-/pipelines

---

## 📄 License

MIT License
