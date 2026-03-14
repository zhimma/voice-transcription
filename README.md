# 智能录音转写助手

基于 Flutter 的跨平台桌面应用，支持本地语音识别和云端 API，多渠道自动切换。

## 功能特性

- ✅ 本地语音识别（Whisper）
- ✅ 云端 API 识别（Qwen/OpenAI）
- ✅ 多渠道自动切换
- ✅ 智能摘要生成
- ✅ 工作流可视化
- ✅ 配置文件编辑
- ✅ 模型下载管理
- ✅ 完全离线运行

## 技术栈

- **前端**: Flutter 3.x + Material Design 3
- **状态管理**: Riverpod
- **数据库**: SQLite
- **语音识别**: faster-whisper / openai-whisper
- **通信**: FFI (stdin/stdout)

## 快速开始

### 安装依赖

```bash
make deps
```

### 开发运行

```bash
make dev
```

### 构建

```bash
# 当前平台
make build

# 所有平台
make build-all
```

## 项目结构

```
lib/
├── models/          # 数据模型
├── providers/       # 状态管理
├── services/        # 业务服务
├── ffi/            # FFI 绑定
├── pages/          # 页面
├── widgets/        # 组件
└── utils/          # 工具

python/
├── server.py       # Python 服务
└── requirements.txt # Python 依赖
```

## 配置

支持 JSON/YAML 配置文件编辑：

```json
{
  "transcription": {
    "mode": "local",
    "local": {"model": "small"},
    "cloud_channels": []
  },
  "summary": {
    "channels": []
  }
}
```

## 支持平台

- macOS (Intel/Apple Silicon)
- Windows
- Linux

## 模型大小

| 模型 | 大小 | 适用场景 |
|------|------|---------|
| tiny | 39 MB | 快速预览 |
| base | 74 MB | 平衡速度 |
| small | 244 MB | 推荐 |
| medium | 769 MB | 高精度 |
| large | 1.5 GB | 最高精度 |

## 开发团队

- 后端: 后端壮壮

## License

MIT
