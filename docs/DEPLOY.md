# 智能录音转写助手 - 部署文档

## 系统要求

### 最低配置
- **操作系统**: macOS 10.14+ / Windows 10+ / Ubuntu 20.04+
- **内存**: 4 GB RAM
- **存储**: 2 GB 可用空间
- **Python**: 3.8+
- **Flutter**: 3.16+

### 推荐配置
- **内存**: 8 GB RAM
- **存储**: 5 GB 可用空间（包含模型文件）
- **GPU**: 支持 CUDA 的 NVIDIA 显卡（可选，用于加速）

---

## 部署方式

### 方式一：开发环境部署

#### 1. 克隆代码

```bash
git clone https://gitlab.hulumibao.com/voice-transcription/frontend.git
cd frontend
```

#### 2. 安装 Flutter

```bash
# macOS
brew install flutter

# Windows
# 下载 Flutter SDK 并配置环境变量

# Linux
sudo snap install flutter --classic
```

#### 3. 安装依赖

```bash
make deps
```

#### 4. 运行开发版本

```bash
# 启动 Python 服务
python3 python/server.py &

# 启动 Flutter 应用
make dev
```

---

### 方式二：生产环境构建

#### 1. 构建当前平台

```bash
make build
```

构建输出目录：`build/macos/`、`build/windows/` 或 `build/linux/`

#### 2. 打包分发

##### macOS
```bash
# 创建 .app 包
cd build/macos/Build/Products/Release
zip -r VoiceTranscription-macOS.zip voice_transcription.app
```

##### Windows
```bash
# 创建安装包
cd build/windows/x64/Release
# 使用 Inno Setup 或 NSIS 创建安装程序
```

##### Linux
```bash
# 创建 AppImage 或 deb 包
cd build/linux/x64/release/bundle
tar -czvf VoiceTranscription-Linux.tar.gz .
```

---

### 方式三：Docker 部署（服务端）

#### 1. 构建 Docker 镜像

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 复制代码
COPY python/requirements.txt .
COPY python/server.py .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 暴露端口
EXPOSE 8765

# 启动服务
CMD ["python", "server.py"]
```

#### 2. 构建并运行

```bash
# 构建镜像
docker build -t voice-transcription-server .

# 运行容器
docker run -d \
  --name voice-transcription \
  -p 8765:8765 \
  -v ~/.voice-transcription/models:/root/.voice-transcription/models \
  voice-transcription-server
```

---

## 配置说明

### 配置文件位置

- **macOS**: `~/.voice-transcription/config.json`
- **Windows**: `%APPDATA%\voice-transcription\config.json`
- **Linux**: `~/.config/voice-transcription/config.json`

### 配置示例

```json
{
  "transcription": {
    "mode": "local",
    "local": {
      "model": "small",
      "language": "auto",
      "device": "cpu"
    },
    "cloud_channels": [
      {
        "name": "qwen",
        "enabled": false,
        "api_key": "",
        "api_url": "https://api.qwen.com/v1"
      }
    ]
  },
  "summary": {
    "default_length": "medium",
    "channels": [
      {
        "name": "local",
        "enabled": true
      },
      {
        "name": "qwen",
        "enabled": false,
        "api_key": ""
      }
    ]
  },
  "ui": {
    "theme": "system",
    "language": "zh-CN"
  }
}
```

---

## 模型下载

首次使用需要下载 Whisper 模型：

```bash
# 通过应用内下载
# 或手动下载
curl -L -o ~/.voice-transcription/models/ggml-small.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin
```

**模型大小参考：**
| 模型 | 大小 | 显存需求 | 适用场景 |
|------|------|---------|---------|
| tiny | 39 MB | ~1 GB | 快速预览 |
| base | 74 MB | ~1 GB | 平衡速度 |
| small | 244 MB | ~2 GB | 推荐 |
| medium | 769 MB | ~5 GB | 高精度 |
| large | 1.5 GB | ~10 GB | 最高精度 |

---

## 常见问题

### Q: 启动时提示 "Python service not found"
A: 确保 Python 3.8+ 已安装，并运行 `pip install -r python/requirements.txt`

### Q: 语音识别速度慢
A: 
- 使用更小的模型（tiny/base）
- 启用 GPU 加速（需要 CUDA）
- 使用云端 API 替代本地识别

### Q: 构建失败
A:
- 确保 Flutter SDK 版本 >= 3.16
- 运行 `flutter doctor` 检查环境
- 运行 `flutter clean && flutter pub get` 清理重建

### Q: 模型下载失败
A:
- 检查网络连接
- 使用代理或镜像源
- 手动下载模型文件到 `~/.voice-transcription/models/`

---

## 日志位置

- **应用日志**: `~/.voice-transcription/logs/app.log`
- **Python 服务日志**: `~/.voice-transcription/logs/server.log`

---

## 更新说明

### 自动更新
应用支持检查更新功能，可在设置中启用。

### 手动更新
```bash
git pull origin main
make deps
make build
```

---

## 技术支持

- **GitLab**: https://gitlab.hulumibao.com/voice-transcription/frontend
- **Issues**: https://gitlab.hulumibao.com/voice-transcription/frontend/-/issues

---

*文档版本: 1.0.0*
*更新日期: 2026-03-14*
