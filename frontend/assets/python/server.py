#!/usr/bin/env python3
"""
智能录音转写助手 - Python 服务
提供 HTTP API 供 Flutter 调用
"""

import json
import sys
import os
import base64
import mimetypes
import uuid
import shutil
import subprocess
from pathlib import Path
import logging
from logging.handlers import RotatingFileHandler
import urllib.request
import threading
from urllib.parse import urlparse, parse_qs

# 添加当前目录到路径
sys.path.insert(0, str(Path(__file__).parent))

try:
    from http.server import HTTPServer, BaseHTTPRequestHandler
except ImportError:
    print("Error: Python 3 required")
    sys.exit(1)

# 服务端口
PORT = 8765
LOGGER = None
DOWNLOAD_JOBS = {}
DOWNLOAD_LOCK = threading.Lock()
MODEL_REPOS = {
    'tiny': 'Systran/faster-whisper-tiny',
    'base': 'Systran/faster-whisper-base',
    'small': 'Systran/faster-whisper-small',
    'medium': 'Systran/faster-whisper-medium',
    'large-v3': 'Systran/faster-whisper-large-v3',
}


def _setup_logger():
    global LOGGER
    if LOGGER is not None:
        return LOGGER
    log_dir = os.environ.get('VOICE_LOG_DIR')
    if not log_dir:
        app_support = os.environ.get('VOICE_APP_SUPPORT_DIR')
        if app_support:
            log_dir = os.path.join(app_support, 'logs')
        else:
            log_dir = str(Path.home() / '.voice-transcription' / 'logs')
    os.makedirs(log_dir, exist_ok=True)
    logger = logging.getLogger('voice_transcription_server')
    logger.setLevel(logging.DEBUG)
    logger.propagate = False
    if not logger.handlers:
        stream_handler = logging.StreamHandler(sys.stdout)
        stream_handler.setLevel(logging.DEBUG)
        file_handler = RotatingFileHandler(
            os.path.join(log_dir, 'python_server.log'),
            maxBytes=20 * 1024 * 1024,
            backupCount=5,
            encoding='utf-8',
        )
        file_handler.setLevel(logging.DEBUG)
        formatter = logging.Formatter(
            '%(asctime)s %(levelname)s request_id=%(request_id)s task_id=%(task_id)s stage=%(stage)s %(message)s'
        )
        stream_handler.setFormatter(formatter)
        file_handler.setFormatter(formatter)
        logger.addHandler(stream_handler)
        logger.addHandler(file_handler)
    LOGGER = logger
    return LOGGER


class RequestHandler(BaseHTTPRequestHandler):
    def _logger(self):
        return _setup_logger()

    def _log(self, level, message, stage='server', task_id='-', **extra):
        payload = {
            'request_id': getattr(self, '_request_id', '-'),
            'task_id': task_id or '-',
            'stage': stage,
        }
        if extra:
            payload.update(extra)
        self._logger().log(level, message + (f' | extra={json.dumps(payload, ensure_ascii=False)}' if extra else ''), extra=payload)

    def log_message(self, format, *args):
        # 简化日志输出
        pass

    def _send_json(self, data, status=200, *, task_id=None, stage='server'):
        payload = dict(data)
        payload.setdefault('request_id', getattr(self, '_request_id', '-'))
        if task_id:
            payload.setdefault('task_id', task_id)
        payload.setdefault('stage', stage)
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode())

    def _send_error(self, message, status=400, *, task_id=None, stage='server', error_code='UNKNOWN_ERROR'):
        self._log(logging.ERROR, message, stage=stage, task_id=task_id or '-', error_code=error_code)
        self._send_json({'error': message, 'error_code': error_code}, status, task_id=task_id, stage=stage)

    def do_GET(self):
        """处理 GET 请求"""
        self._request_id = str(uuid.uuid4())
        parsed = urlparse(self.path)
        if parsed.path == '/health':
            self._send_json({'status': 'ok', 'version': '1.0.0'}, stage='health')
        elif parsed.path == '/models':
            self._send_json({'models': self._list_models()}, stage='models')
        elif parsed.path == '/download_status':
            model = (parse_qs(parsed.query).get('model') or [''])[0]
            if not model:
                self._send_error('model is required', stage='download_status', error_code='MODEL_REQUIRED')
                return
            with DOWNLOAD_LOCK:
                job = DOWNLOAD_JOBS.get(model) or {
                    'status': 'unknown',
                    'progress': 0,
                    'message': 'no job',
                    'source': os.environ.get('VOICE_MODEL_SOURCE') or 'modelscope',
                    'model_dir': str(self._model_target_dir(model)),
                }
            self._send_json({'model': model, **job}, stage='download_status')
        else:
            self._send_error('Not found', 404, stage='router', error_code='NOT_FOUND')

    def do_POST(self):
        """处理 POST 请求"""
        self._request_id = str(uuid.uuid4())
        try:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length).decode()
            data = json.loads(body) if body else {}
            task_id = data.get('task_id')

            if self.path == '/transcribe':
                self._handle_transcribe(data)
            elif self.path == '/summarize':
                self._handle_summarize(data)
            elif self.path == '/download_model':
                self._handle_download_model(data)
            else:
                self._send_error('Not found', 404, task_id=task_id, stage='router', error_code='NOT_FOUND')
        except json.JSONDecodeError:
            self._send_error('Invalid JSON', error_code='INVALID_JSON')
        except Exception as e:
            self._send_error(str(e), 500, error_code='UNHANDLED_EXCEPTION')

    def _handle_transcribe(self, data):
        """处理语音识别请求"""
        audio_path = data.get('audio_path')
        model = data.get('model', 'small')
        language = data.get('language', 'auto')
        provider = data.get('provider', 'whisper')
        provider_config = data.get('provider_config') or {}
        task_id = data.get('task_id')

        if not audio_path or not os.path.exists(audio_path):
            self._send_error('Audio file not found', task_id=task_id, stage='transcribe', error_code='AUDIO_NOT_FOUND')
            return

        try:
            if provider == 'whisper':
                result = self._transcribe_whisper(audio_path, model, language)
            elif provider == 'qwen':
                result = self._transcribe_qwen(audio_path, language, provider_config)
            else:
                self._send_error(
                    f'Unknown provider: {provider}, supported: whisper/qwen',
                    task_id=task_id,
                    stage='transcribe',
                    error_code='UNKNOWN_PROVIDER',
                )
                return

            self._send_json(result, task_id=task_id, stage='transcribe')
        except Exception as e:
            self._send_error(f'Transcription failed: {str(e)}', 500, task_id=task_id, stage='transcribe', error_code='TRANSCRIBE_FAILED')

    def _transcribe_whisper(self, audio_path, model, language):
        """使用 Whisper 识别"""
        download_root = self._model_root()
        model_path = self._model_target_dir(model)
        model_ref = str(model_path) if model_path.exists() else model
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            import whisper
            self._prepare_whisper_checkpoint(model, download_root)

            model_obj = whisper.load_model(model, download_root=str(download_root))
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

        model_obj = WhisperModel(
            model_ref,
            device="cpu",
            compute_type="int8",
            download_root=download_root,
        )
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

    def _transcribe_openai(self, audio_path, model, language, provider_config):
        """使用 OpenAI 识别"""
        import requests
        api_key = provider_config.get('api_key')
        api_url = provider_config.get('api_url', 'https://api.openai.com/v1')
        model_name = provider_config.get('model') or model or 'gpt-4o-mini-transcribe'
        if not api_key:
            raise Exception('OpenAI API key not configured')

        url = f"{api_url.rstrip('/')}/audio/transcriptions"
        headers = {"Authorization": f"Bearer {api_key}"}
        with open(audio_path, 'rb') as f:
            files = {"file": f}
            data = {"model": model_name, "response_format": "json"}
            if language != 'auto':
                data['language'] = language
            resp = requests.post(url, headers=headers, files=files, data=data, timeout=300)
        if resp.status_code >= 400:
            raise Exception(resp.text)
        payload = resp.json()
        text = payload.get('text', '') if isinstance(payload, dict) else ''
        return {
            'text': text,
            'language': payload.get('language', language if language != 'auto' else 'unknown') if isinstance(payload, dict) else 'unknown',
            'duration': payload.get('duration', 0) if isinstance(payload, dict) else 0,
            'segments': payload.get('segments', []) if isinstance(payload, dict) else [],
        }

    def _transcribe_qwen(self, audio_path, language, provider_config):
        """使用 Qwen 识别"""
        import requests
        api_key = provider_config.get('api_key')
        api_url = provider_config.get('api_url', 'https://dashscope.aliyuncs.com/compatible-mode/v1')
        model_name = provider_config.get('model') or 'qwen3-omni-30b-a3b-captioner'
        if not api_key:
            raise Exception('Qwen API key not configured')

        mime, _ = mimetypes.guess_type(audio_path)
        if not mime:
            mime = 'audio/wav'
        with open(audio_path, 'rb') as f:
            b64 = base64.b64encode(f.read()).decode('utf-8')
        data_url = f"data:{mime};base64,{b64}"

        url = f"{api_url.rstrip('/')}/chat/completions"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {
            "model": model_name,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_audio",
                            "input_audio": {
                                "data": data_url
                            }
                        }
                    ]
                }
            ],
        }
        resp = requests.post(url, headers=headers, json=payload, timeout=300)
        if resp.status_code >= 400:
            raise Exception(resp.text)
        payload = resp.json()
        text = self._extract_chat_completions_text(payload)
        return {
            'text': text,
            'language': language if language != 'auto' else 'unknown',
            'duration': 0,
            'segments': [],
        }

    def _handle_summarize(self, data):
        """处理摘要请求"""
        text = data.get('text')
        length = data.get('length', 'medium')
        provider = data.get('provider', 'local')
        provider_config = data.get('provider_config') or {}

        if not text:
            self._send_error('Text is required', stage='summarize', error_code='TEXT_REQUIRED')
            return

        try:
            if provider == 'local':
                result = self._summarize_local(text, length)
            elif provider == 'qwen':
                result = self._summarize_qwen(text, length, provider_config)
            else:
                self._send_error(f'Unknown provider: {provider}, supported: local/qwen', stage='summarize', error_code='UNKNOWN_PROVIDER')
                return

            self._send_json(result, stage='summarize')
        except Exception as e:
            self._send_error(f'Summarization failed: {str(e)}', 500, stage='summarize', error_code='SUMMARIZE_FAILED')

    def _summarize_local(self, text, length):
        """本地简化版摘要"""
        sentences = text.replace('。', '.').replace('？', '?').replace('！', '!').split('.')
        sentences = [s.strip() for s in sentences if len(s.strip()) > 5]

        if length == 'short':
            summary_text = '. '.join(sentences[:2]) + '.'
            key_points = sentences[:3]
        elif length == 'medium':
            summary_text = '. '.join(sentences[:5]) + '.'
            key_points = sentences[:5]
        else:
            summary_text = '. '.join(sentences[:10]) + '.'
            key_points = sentences[:8]

        words = text.split()
        word_freq = {}
        for word in words:
            if len(word) > 2:
                word_freq[word] = word_freq.get(word, 0) + 1

        keywords = sorted(word_freq.keys(), key=lambda x: word_freq[x], reverse=True)[:10]

        return {
            'summary': summary_text,
            'short': summary_text[:100] + '...',
            'medium': summary_text[:300] + '...',
            'long': summary_text,
            'key_points': key_points,
            'keywords': keywords,
        }

    def _summarize_qwen(self, text, length, provider_config):
        """使用 Qwen API 摘要"""
        import requests
        api_key = provider_config.get('api_key')
        api_url = provider_config.get('api_url', 'https://dashscope.aliyuncs.com/compatible-mode/v1')
        model_name = provider_config.get('model') or 'qwen3.5-plus'
        if 'captioner' in model_name.lower() or 'omni' in model_name.lower():
            model_name = 'qwen3.5-plus'
        if not api_key:
            raise Exception('Qwen API key not configured')

        prompt = self._summary_prompt(text, length)
        url = f"{api_url.rstrip('/')}/chat/completions"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {
            "model": model_name,
            "messages": [
                {"role": "user", "content": prompt}
            ],
        }
        resp = requests.post(url, headers=headers, json=payload, timeout=120)
        if resp.status_code >= 400:
            raise Exception(resp.text)
        data = resp.json()
        summary_text = self._extract_chat_completions_text(data)
        return self._build_summary(summary_text, length)

    def _summarize_openai(self, text, length, provider_config):
        """使用 OpenAI API 摘要"""
        import requests
        api_key = provider_config.get('api_key')
        api_url = provider_config.get('api_url', 'https://api.openai.com/v1')
        model_name = provider_config.get('model') or 'gpt-4o-mini'
        if not api_key:
            raise Exception('OpenAI API key not configured')

        prompt = self._summary_prompt(text, length)
        url = f"{api_url.rstrip('/')}/responses"
        headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
        payload = {
            "model": model_name,
            "input": prompt,
        }
        resp = requests.post(url, headers=headers, json=payload, timeout=120)
        if resp.status_code >= 400:
            raise Exception(resp.text)
        data = resp.json()
        summary_text = self._extract_openai_text(data)
        return self._build_summary(summary_text, length)

    def _handle_download_model(self, data):
        """处理模型下载请求"""
        model_name = data.get('model', 'small')
        task_id = data.get('task_id')
        source = data.get('source') or os.environ.get('VOICE_MODEL_SOURCE') or 'modelscope'

        if self._model_exists(model_name):
            self._send_json(
                {
                    'status': 'downloaded',
                    'progress': 100,
                    'model': model_name,
                    'reused': True,
                    'model_dir': str(self._model_target_dir(model_name)),
                    'source': source,
                },
                task_id=task_id,
                stage='model_download',
            )
            return

        with DOWNLOAD_LOCK:
            current = DOWNLOAD_JOBS.get(model_name)
            if current and current.get('status') == 'downloading':
                self._send_json(
                    {'model': model_name, **current},
                    task_id=task_id,
                    stage='model_download',
                )
                return
            DOWNLOAD_JOBS[model_name] = {
                'status': 'queued',
                'progress': 1,
                'message': 'queued',
                'task_id': task_id,
                'source': source,
                'model_dir': str(self._model_target_dir(model_name)),
            }

        t = threading.Thread(
            target=self._download_model_worker,
            args=(model_name, task_id, source),
            daemon=True,
        )
        t.start()
        self._send_json(
            {
                'status': 'downloading',
                'progress': 1,
                'model': model_name,
                'model_dir': str(self._model_target_dir(model_name)),
                'source': source,
            },
            task_id=task_id,
            stage='model_download',
        )

    def _download_model_worker(self, model_name, task_id, source):
        def mark(status, progress, message):
            with DOWNLOAD_LOCK:
                DOWNLOAD_JOBS[model_name] = {
                    'status': status,
                    'progress': progress,
                    'message': message,
                    'task_id': task_id,
                    'source': source,
                    'model_dir': str(self._model_target_dir(model_name)),
                }

        try:
            mark('downloading', 5, 'preparing')
            if self._model_exists(model_name):
                mark('downloaded', 100, 'reused')
                return
            if source == 'modelscope':
                mark('downloading', 15, 'downloading via ModelScope')
                self._download_via_modelscope(model_name)
                mark('verifying', 90, 'verifying files')
            else:
                try:
                    from faster_whisper import WhisperModel
                    mark('downloading', 20, 'downloading via faster_whisper')
                    WhisperModel(
                        model_name,
                        device="cpu",
                        compute_type="int8",
                        download_root=self._model_root(),
                    )
                    mark('verifying', 90, 'verifying files')
                except ImportError:
                    import whisper
                    fallback_model = model_name if model_name != 'large-v3' else 'large'
                    mark('downloading', 20, 'downloading via openai-whisper')
                    self._prepare_whisper_checkpoint(fallback_model, self._model_root())
                    mark('downloading', 80, 'loading checkpoint')
                    whisper.load_model(fallback_model, download_root=str(self._model_root()))
                    mark('verifying', 90, 'verifying files')
            mark('downloaded', 100, 'done')
        except Exception as e:
            mark('failed', 0, str(e))

    def _list_models(self):
        models = ['tiny', 'base', 'small', 'medium', 'large-v3']
        source = os.environ.get('VOICE_MODEL_SOURCE') or 'modelscope'
        results = []
        for m in models:
            status = 'missing'
            size = '--'
            try:
                model_dir = self._model_target_dir(m)
                if model_dir.exists():
                    status = 'downloaded'
                    size = self._dir_size(model_dir)
            except Exception:
                pass
            with DOWNLOAD_LOCK:
                job = DOWNLOAD_JOBS.get(m)
            results.append({
                'name': m,
                'status': status if not job else job.get('status', status),
                'size': size,
                'model_dir': str(self._model_target_dir(m)),
                'progress': 100 if status == 'downloaded' else (job.get('progress', 0) if job else 0),
                'message': (job or {}).get('message'),
                'source': (job or {}).get('source', source),
            })
        return results

    def _model_root(self):
        model_dir = os.environ.get('VOICE_MODEL_DIR')
        if not model_dir:
            app_support = os.environ.get('VOICE_APP_SUPPORT_DIR')
            if app_support:
                model_dir = os.path.join(app_support, 'models')
            else:
                model_dir = str(Path.home() / '.voice-transcription' / 'models')
        path = Path(model_dir)
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _model_target_dir(self, model_name):
        return self._model_root() / model_name

    def _download_via_modelscope(self, model_name):
        repo_id = MODEL_REPOS.get(model_name)
        if not repo_id:
            raise Exception(f'Unsupported model: {model_name}')
        target = self._model_target_dir(model_name)
        target.mkdir(parents=True, exist_ok=True)
        try:
            from modelscope import snapshot_download
        except Exception:
            self._ensure_modelscope()
            try:
                from modelscope import snapshot_download
            except Exception:
                from modelscope.hub.snapshot_download import snapshot_download

        try:
            local_path = snapshot_download(
                repo_id,
                local_dir=str(target),
                local_dir_use_symlinks=False,
            )
        except TypeError:
            local_path = snapshot_download(
                repo_id,
                cache_dir=str(self._model_root()),
            )

        if local_path:
            local_path = Path(local_path)
            if local_path != target and local_path.exists() and not any(target.iterdir()):
                for item in local_path.iterdir():
                    dest = target / item.name
                    if item.is_dir():
                        shutil.copytree(item, dest, dirs_exist_ok=True)
                    else:
                        shutil.copy2(item, dest)

    def _ensure_modelscope(self):
        try:
            import modelscope  # noqa: F401
            return
        except Exception:
            pass
        proc = subprocess.run(
            [sys.executable, '-m', 'pip', 'install', 'modelscope>=1.16.0'],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        if proc.returncode != 0:
            raise Exception(f'ModelScope install failed: {proc.stdout}')

    def _model_exists(self, model_name):
        target = self._model_target_dir(model_name)
        if target.exists() and any(target.iterdir()):
            return True
        # openai-whisper 缓存路径检测
        whisper_cache = target
        whisper_model = model_name if model_name != 'large-v3' else 'large'
        if (whisper_cache / f'{whisper_model}.pt').exists():
            return True
        return False

    def _prepare_whisper_checkpoint(self, model_name, download_root):
        url = self._resolve_whisper_model_url(model_name)
        if not url:
            return
        file_name = os.path.basename(url)
        target = Path(download_root) / file_name
        if target.exists():
            return
        with urllib.request.urlopen(url) as source, open(target, "wb") as output:
            output.write(source.read())

    def _resolve_whisper_model_url(self, model_name):
        from whisper import _MODELS

        normalized = model_name if model_name != 'large-v3' else 'large'
        official = _MODELS.get(normalized)
        if not official:
            return None
        base = os.environ.get('VOICE_WHISPER_WEIGHTS_BASE_URL', '').strip().rstrip('/')
        if not base:
            return official
        # 仅替换域名，保留原始路径和文件名
        try:
            official_path = official.split('/main/whisper/models/', 1)[1]
            return f"{base}/main/whisper/models/{official_path}"
        except Exception:
            return official

    def _dir_size(self, path):
        total = 0
        for p in Path(path).rglob('*'):
            if p.is_file():
                total += p.stat().st_size
        return f"{total/1024/1024:.1f} MB"

    def _summary_prompt(self, text, length):
        return (
            "请将以下内容总结为可读性强的中文摘要，并给出要点列表与关键词。\n"
            f"摘要长度: {length}\n内容:\n{text}"
        )

    def _build_summary(self, summary_text, length):
        return {
            'summary': summary_text,
            'short': summary_text[:100] + '...',
            'medium': summary_text[:300] + '...',
            'long': summary_text,
            'key_points': summary_text.split('。')[:5],
            'keywords': summary_text.split()[:10],
        }

    def _extract_dashscope_text(self, data):
        try:
            return data['output']['choices'][0]['message']['content'][0]['text']
        except Exception:
            return data.get('output_text', '') or data.get('text', '')

    def _extract_openai_text(self, data):
        if isinstance(data, dict):
            if 'output_text' in data:
                return data['output_text']
            output = data.get('output')
            if isinstance(output, list):
                for item in output:
                    content = item.get('content') if isinstance(item, dict) else None
                    if isinstance(content, list):
                        for c in content:
                            if isinstance(c, dict) and c.get('type') == 'output_text':
                                return c.get('text', '')
        return ''

    def _extract_chat_completions_text(self, data):
        if not isinstance(data, dict):
            return ''
        choices = data.get('choices')
        if not isinstance(choices, list) or not choices:
            return ''
        message = choices[0].get('message') if isinstance(choices[0], dict) else None
        if not isinstance(message, dict):
            return ''
        content = message.get('content')
        if isinstance(content, str):
            return content
        if isinstance(content, list):
            parts = []
            for item in content:
                if isinstance(item, dict):
                    text_val = item.get('text')
                    if isinstance(text_val, str):
                        parts.append(text_val)
            return '\n'.join(parts).strip()
        return ''


def main():
    """启动服务"""
    logger = _setup_logger()
    server = HTTPServer(('localhost', PORT), RequestHandler)
    logger.info(f"Python service started on port {PORT}", extra={'request_id': '-', 'task_id': '-', 'stage': 'boot'})
    logger.info("API endpoints ready", extra={'request_id': '-', 'task_id': '-', 'stage': 'boot'})

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down", extra={'request_id': '-', 'task_id': '-', 'stage': 'boot'})
        server.shutdown()


if __name__ == '__main__':
    main()
