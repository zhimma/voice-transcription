# 智能录音转写助手 - API 接口文档

> 版本：v1.0.0 | 基础 URL：`http://localhost:8765`

---

## 🔍 接口概览

| 接口 | 方法 | 路径 | 说明 |
|------|------|------|------|
| 健康检查 | GET | `/health` | 服务状态检查 |
| 语音识别 | POST | `/transcribe` | 音频转文字 |
| 文本摘要 | POST | `/summarize` | 生成文本摘要 |
| 模型下载 | POST | `/download_model` | 下载 Whisper 模型 |

---

## 📡 接口详情

### 1. 健康检查

检查服务运行状态。

**请求**
```http
GET /health
```

**响应**
```json
{
  "status": "ok",
  "version": "1.0.0"
}
```

**状态码**
- `200` - 服务正常

---

### 2. 语音识别

将音频文件转写为文字。

**请求**
```http
POST /transcribe
Content-Type: application/json

{
  "audio_path": "/path/to/audio.mp3",
  "model": "small",
  "language": "auto",
  "provider": "whisper"
}
```

**参数说明**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `audio_path` | string | ✅ | - | 音频文件绝对路径 |
| `model` | string | ❌ | `small` | 模型大小：tiny/base/small/medium/large |
| `language` | string | ❌ | `auto` | 语言代码：zh/en/ja/... 或 auto |
| `provider` | string | ❌ | `whisper` | 提供商：whisper/qwen |

**成功响应**
```json
{
  "text": "完整的转写文本内容...",
  "language": "zh",
  "duration": 120.5,
  "segments": [
    {
      "id": 0,
      "start": 0.0,
      "end": 5.2,
      "text": "第一段文字"
    },
    {
      "id": 1,
      "start": 5.2,
      "end": 10.8,
      "text": "第二段文字"
    }
  ]
}
```

**错误响应**
```json
{
  "error": "Audio file not found"
}
```

**状态码**
- `200` - 转写成功
- `400` - 请求参数错误
- `404` - 音频文件不存在
- `500` - 转写失败

---

### 3. 文本摘要

为长文本生成摘要。

**请求**
```http
POST /summarize
Content-Type: application/json

{
  "text": "需要摘要的长文本内容...",
  "length": "medium",
  "provider": "local"
}
```

**参数说明**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `text` | string | ✅ | - | 需要摘要的文本 |
| `length` | string | ❌ | `medium` | 摘要长度：short/medium/long |
| `provider` | string | ❌ | `local` | 提供商：local/qwen/openai |

**成功响应**
```json
{
  "summary": "生成的摘要文本...",
  "short": "简短版摘要（100字）...",
  "medium": "中等版摘要（300字）...",
  "long": "完整版摘要...",
  "key_points": [
    "要点1",
    "要点2",
    "要点3"
  ],
  "keywords": [
    "关键词1",
    "关键词2",
    "关键词3"
  ]
}
```

**错误响应**
```json
{
  "error": "Text is required"
}
```

**状态码**
- `200` - 摘要成功
- `400` - 请求参数错误
- `500` - 摘要失败

---

### 4. 模型下载

下载 Whisper 模型文件。

**请求**
```http
POST /download_model
Content-Type: application/json

{
  "model": "small"
}
```

**参数说明**

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `model` | string | ✅ | - | 模型名称：tiny/base/small/medium/large |

**成功响应**
```json
{
  "status": "downloaded",
  "path": "/home/user/.voice-transcription/models/ggml-small.bin"
}
```

**已存在响应**
```json
{
  "status": "already_exists",
  "path": "/home/user/.voice-transcription/models/ggml-small.bin"
}
```

**错误响应**
```json
{
  "error": "Download failed: ..."
}
```

**状态码**
- `200` - 下载成功或已存在
- `400` - 请求参数错误
- `500` - 下载失败

---

## 🧪 测试示例

### cURL 测试

```bash
# 健康检查
curl http://localhost:8765/health

# 语音识别
curl -X POST http://localhost:8765/transcribe \
  -H "Content-Type: application/json" \
  -d '{
    "audio_path": "/path/to/audio.mp3",
    "model": "small",
    "language": "zh"
  }'

# 文本摘要
curl -X POST http://localhost:8765/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "text": "这是一段需要摘要的长文本。文本内容包含多个要点。第一个要点是关于项目背景。第二个要点是关于技术实现。第三个要点是关于未来规划。",
    "length": "short"
  }'

# 下载模型
curl -X POST http://localhost:8765/download_model \
  -H "Content-Type: application/json" \
  -d '{"model": "small"}'
```

### Python 测试

```python
import requests

BASE_URL = "http://localhost:8765"

# 健康检查
response = requests.get(f"{BASE_URL}/health")
print(response.json())

# 语音识别
response = requests.post(
    f"{BASE_URL}/transcribe",
    json={
        "audio_path": "/path/to/audio.mp3",
        "model": "small",
        "language": "zh"
    }
)
print(response.json())
```

---

## ⚠️ 错误码说明

| 状态码 | 说明 | 常见原因 |
|--------|------|---------|
| 200 | 成功 | - |
| 400 | 请求错误 | 参数缺失、JSON 格式错误 |
| 404 | 未找到 | 接口不存在、文件不存在 |
| 500 | 服务器错误 | 内部异常、模型加载失败 |

---

## 📦 数据模型

### TranscriptionResult（转写结果）

```typescript
{
  text: string;           // 完整转写文本
  language: string;       // 检测到的语言
  duration: number;       // 音频时长（秒）
  segments: Segment[];    // 分段信息
}

interface Segment {
  id: number;            // 段落 ID
  start: number;         // 开始时间（秒）
  end: number;           // 结束时间（秒）
  text: string;          // 段落文本
}
```

### SummaryResult（摘要结果）

```typescript
{
  summary: string;        // 完整摘要
  short: string;          // 简短版（约100字）
  medium: string;         // 中等版（约300字）
  long: string;           // 完整版
  key_points: string[];   // 关键要点列表
  keywords: string[];     // 关键词列表
}
```

---

## 🔐 认证说明

当前版本 API 无需认证即可访问。如需添加认证，建议：

1. 在请求头中添加 `Authorization: Bearer <token>`
2. 或在配置文件中设置白名单 IP

---

## 📞 技术支持

- **GitLab Issues**: https://gitlab.hulumibao.com/voice-transcription/frontend/-/issues
- **文档更新**: 提交 PR 到 `docs/API.md`
