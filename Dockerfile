# 智能录音转写助手 - Python 服务端 Docker 镜像
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制 Python 依赖
COPY python/requirements.txt .

# 安装 Python 依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY python/server.py .

# 创建模型目录
RUN mkdir -p /root/.voice-transcription/models

# 暴露端口
EXPOSE 8765

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8765/health || exit 1

# 启动服务
CMD ["python", "server.py"]
