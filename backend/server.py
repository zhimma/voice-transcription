#!/usr/bin/env python3
"""
智能录音转写助手 - Python 服务
提供 HTTP API 供 Flutter 调用
"""

import json
import sys
import os
from pathlib import Path

# 添加当前目录到路径
sys.path.insert(0, str(Path(__file__).parent))

try:
    from http.server import HTTPServer, BaseHTTPRequestHandler
except ImportError:
    print("Error: Python 3 required")
    sys.exit(1)

# 服务端口
PORT = 8765

class RequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        # 简化日志输出
        pass
    
    def _send_json(self, data, status=200):
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode())
    
    def _send_error(self, message, status=400):
        self._send_json({'error': message}, status)
    
    def do_GET(self):
        """处理 GET 请求"""
        if self.path == '/health':
            self._send_json({'status': 'ok', 'version': '1.0.0'})
        else:
            self._send_error('Not found', 404)
    
    def do_POST(self):
        """处理 POST 请求"""
        try:
            # 读取请求体
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode()
            data = json.loads(body) if body else {}
            
            # 路由
            if self.path == '/transcribe':
                self._handle_transcribe(data)
            elif self.path == '/summarize':
                self._handle_summarize(data)
            elif self.path == '/download_model':
                self._handle_download_model(data)
            else:
                self._send_error('Not found', 404)
                
        except json.JSONDecodeError:
            self._send_error('Invalid JSON')
        except Exception as e:
            self._send_error(str(e), 500)
    
    def _handle_transcribe(self, data):
        """处理语音识别请求"""
        audio_path = data.get('audio_path')
        model = data.get('model', 'small')
        language = data.get('language', 'auto')
        provider = data.get('provider', 'whisper')
        
        if not audio_path or not os.path.exists(audio_path):
            self._send_error('Audio file not found')
            return
        
        try:
            if provider == 'whisper':
                result = self._transcribe_whisper(audio_path, model, language)
            elif provider == 'qwen':
                result = self._transcribe_qwen(audio_path, language)
            else:
                self._send_error(f'Unknown provider: {provider}')
                return
            
            self._send_json(result)
        except Exception as e:
            self._send_error(f'Transcription failed: {str(e)}', 500)
    
    def _transcribe_whisper(self, audio_path, model, language):
        """使用 Whisper 识别"""
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            # 降级到标准 whisper
            import whisper
            
            model_obj = whisper.load_model(model)
            result = model_obj.transcribe(
                audio_path,
                language=language if language != 'auto' else None,
            )
            
            segments = [
                {
                    'id': seg['id'],
                    'start': seg['start'],
                    'end': seg['end'],
                    'text': seg['text'].strip(),
                }
                for seg in result['segments']
            ]
            
            return {
                'text': result['text'],
                'language': result.get('language', 'unknown'),
                'duration': segments[-1]['end'] if segments else 0,
                'segments': segments,
            }
        
        # faster-whisper
        model_obj = WhisperModel(model, device="cpu", compute_type="int8")
        segments_iter, info = model_obj.transcribe(
            audio_path,
            language=language if language != 'auto' else None,
        )
        
        segments = []
        text = ""
        for seg in segments_iter:
            segments.append({
                'id': len(segments),
                'start': seg.start,
                'end': seg.end,
                'text': seg.text.strip(),
            })
            text += seg.text + " "
        
        return {
            'text': text.strip(),
            'language': info.language if language == 'auto' else language,
            'duration': segments[-1]['end'] if segments else 0,
            'segments': segments,
        }
    
    def _transcribe_qwen(self, audio_path, language):
        """使用 Qwen 识别 (需要配置 API)"""
        # TODO: 实现 Qwen API 调用
        raise NotImplementedError("Qwen API not configured")
    
    def _handle_summarize(self, data):
        """处理摘要请求"""
        text = data.get('text')
        length = data.get('length', 'medium')
        provider = data.get('provider', 'local')
        
        if not text:
            self._send_error('Text is required')
            return
        
        try:
            if provider == 'local':
                result = self._summarize_local(text, length)
            elif provider == 'qwen':
                result = self._summarize_qwen(text, length)
            elif provider == 'openai':
                result = self._summarize_openai(text, length)
            else:
                self._send_error(f'Unknown provider: {provider}')
                return
            
            self._send_json(result)
        except Exception as e:
            self._send_error(f'Summarization failed: {str(e)}', 500)
    
    def _summarize_local(self, text, length):
        """本地简化版摘要"""
        # 简单实现：提取前 N 个句子
        sentences = text.replace('。', '.').replace('？', '?').replace('！', '!').split('.')
        sentences = [s.strip() for s in sentences if len(s.strip()) > 5]
        
        if length == 'short':
            summary_text = '. '.join(sentences[:2]) + '.'
            key_points = sentences[:3]
        elif length == 'medium':
            summary_text = '. '.join(sentences[:5]) + '.'
            key_points = sentences[:5]
        else:  # long
            summary_text = '. '.join(sentences[:10]) + '.'
            key_points = sentences[:8]
        
        # 提取关键词（简单实现）
        words = text.split()
        word_freq = {}
        for word in words:
            if len(word) > 2:
                word_freq[word] = word_freq.get(word, 0) + 1
        
        keywords = sorted(word_freq.keys(), 
                         key=lambda x: word_freq[x], 
                         reverse=True)[:10]
        
        return {
            'summary': summary_text,
            'short': summary_text[:100] + '...',
            'medium': summary_text[:300] + '...',
            'long': summary_text,
            'key_points': key_points,
            'keywords': keywords,
        }
    
    def _summarize_qwen(self, text, length):
        """使用 Qwen API 摘要"""
        # TODO: 实现 Qwen API 调用
        raise NotImplementedError("Qwen API not configured")
    
    def _summarize_openai(self, text, length):
        """使用 OpenAI API 摘要"""
        # TODO: 实现 OpenAI API 调用
        raise NotImplementedError("OpenAI API not configured")
    
    def _handle_download_model(self, data):
        """处理模型下载请求"""
        model_name = data.get('model', 'small')
        
        try:
            # 下载模型
            import urllib.request
            import ssl
            
            # 模型下载 URL (HuggingFace)
            base_url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
            model_file = f"ggml-{model_name}.bin"
            url = f"{base_url}/{model_file}"
            
            # 保存路径
            model_dir = Path.home() / '.voice-transcription' / 'models'
            model_dir.mkdir(parents=True, exist_ok=True)
            save_path = model_dir / model_file
            
            if save_path.exists():
                self._send_json({'status': 'already_exists', 'path': str(save_path)})
                return
            
            # 下载
            ssl._create_default_https_context = ssl._create_unverified_context
            urllib.request.urlretrieve(url, save_path)
            
            self._send_json({'status': 'downloaded', 'path': str(save_path)})
        except Exception as e:
            self._send_error(f'Download failed: {str(e)}', 500)

def main():
    """启动服务"""
    server = HTTPServer(('localhost', PORT), RequestHandler)
    print(f"Python service started on port {PORT}")
    print(f"API endpoints:")
    print(f"  POST http://localhost:{PORT}/transcribe")
    print(f"  POST http://localhost:{PORT}/summarize")
    print(f"  POST http://localhost:{PORT}/download_model")
    print(f"  GET  http://localhost:{PORT}/health")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.shutdown()

if __name__ == '__main__':
    main()
