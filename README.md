# 智能录音转写助手

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.16+-blue.svg)](https://flutter.dev)

> 基于 Flutter 的跨平台桌面应用，支持本地语音识别和云端 API，具备智能对话分析能力。

---

## ✨ 功能特性

- 🎙️ **本地语音识别** - 基于 Whisper，完全离线运行
- ☁️ **云端 API 支持** - Qwen、OpenAI 多渠道切换
- 📝 **智能摘要** - 自动生成文本摘要和关键词
- 💬 **对话分析** - 智能分析对话内容，支持情绪、质量、解决情况等多维度评估
- 🔄 **动态字段渲染** - 自动适配模型返回的任意字段结构，支持中文 key 作为标签
- 🖥️ **跨平台** - 支持 macOS、Windows、Linux
- ⚙️ **可视化配置** - JSON/YAML 配置编辑器，实时调整提示词
- 📦 **模型管理** - 应用内下载和管理模型
- ⌨️ **全局快捷键** - 支持自定义快捷键快速唤起应用

---

## 🚀 快速开始

### 环境要求
- Flutter 3.16+
- Python 3.8+
- 4GB+ RAM

### 安装与运行

```bash
# 克隆仓库
git clone https://github.com/zhimma/voice-transcription.git
cd voice-transcription

# 安装依赖
make deps

# 启动开发环境（同时启动 Python 服务和 Flutter 应用）
make dev
```

---

## 📁 项目结构

```
├── frontend/          # Flutter 前端
│   ├── lib/           # Dart 源代码
│   ├── test/          # 测试代码
│   └── pubspec.yaml   # Flutter 依赖
├── backend/           # Python 后端
│   ├── server.py      # HTTP API 服务
│   └── requirements.txt
├── docs/              # 文档
├── scripts/           # 工具脚本
├── Makefile           # 构建命令
└── README.md          # 本文件
```

---

## 🛠️ 开发命令

```bash
# 运行测试
make test

# 代码质量检查
cd frontend && flutter analyze

# 构建当前平台
make build

# 构建所有平台
make build-all

# 清理构建文件
make clean
```

---

## 🔄 动态渲染特性

本应用支持动态渲染模型返回的任意 JSON 字段，无需修改代码即可适配不同的提示词输出：

- **智能字段识别** - 自动识别中文和英文 key，转换为可读标签
- **类型自适应** - 根据数据类型（字符串、数字、布尔值、列表、对象）自动选择最佳展示方式
- **智能分组** - 对话分析结果按语义自动分组（基础信息、客户画像、情绪分析、服务质量等）
- **嵌套结构支持** - 递归渲染任意层级的嵌套对象和数组

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
