# 智能录音转写助手

[![CI/CD](https://github.com/voice-transcription/frontend/actions/workflows/build.yml/badge.svg)](https://github.com/voice-transcription/frontend/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev)

> 基于 Flutter 的跨平台桌面应用，支持本地语音识别和云端 API，多渠道自动切换。

---

## ✨ 功能特性

- 🎙️ **本地语音识别** - 基于 Whisper，完全离线运行
- ☁️ **云端 API 支持** - Qwen、OpenAI 多渠道切换
- 📝 **智能摘要** - 自动生成文本摘要和关键词
- 🖥️ **跨平台** - 支持 macOS、Windows、Linux
- ⚙️ **可视化配置** - JSON/YAML 配置编辑器
- 📦 **模型管理** - 应用内下载和管理模型

---

## 🚀 快速开始

### 环境要求
- Flutter 3.16+
- Python 3.8+
- 4GB+ RAM

### 一键安装

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
cd frontend && flutter pub get

# 2. 安装 Python 依赖
pip3 install -r backend/requirements.txt

# 3. 启动服务
python3 backend/server.py &

# 4. 启动应用
cd frontend && flutter run -d macos
```

---

## 📁 项目结构

```
├── frontend/          # Flutter 前端
├── backend/           # Python 后端
├── docs/             # 文档
│   ├── DEPLOY.md     # 部署文档
│   └── API.md        # API 文档
├── scripts/          # 工具脚本
├── .github/          # CI/CD 配置
├── docker-compose.yml
└── PROJECT.md        # 项目总览
```

---

## 🛠️ 开发

```bash
# 运行测试
make test

# 构建当前平台
make build

# 构建所有平台
make build-all

# Docker 运行
docker-compose up -d
```

---

## 📚 文档

| 文档 | 说明 |
|------|------|
| [PROJECT.md](PROJECT.md) | 项目总览文档 |
| [docs/DEPLOY.md](docs/DEPLOY.md) | 部署指南 |
| [docs/API.md](docs/API.md) | API 接口文档 |
| [CHANGELOG.md](CHANGELOG.md) | 更新日志 |

---

## 🤝 贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

---

## 📄 License

[MIT](LICENSE)

---

**团队**: 研发特工队 | **后端**: @后端壮壮
