#!/usr/bin/env python3
"""
智能录音转写助手 - Python 服务端测试
"""

import unittest
import json
import threading
import time
from http.client import HTTPConnection

# 导入被测试的模块
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

from server import RequestHandler, PORT
from http.server import HTTPServer


class TestServer(unittest.TestCase):
    """测试 HTTP 服务"""
    
    @classmethod
    def setUpClass(cls):
        """启动测试服务器"""
        cls.server = HTTPServer(('localhost', PORT + 1), RequestHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever)
        cls.server_thread.daemon = True
        cls.server_thread.start()
        time.sleep(0.5)  # 等待服务器启动
        cls.conn = HTTPConnection('localhost', PORT + 1)
    
    @classmethod
    def tearDownClass(cls):
        """关闭测试服务器"""
        cls.server.shutdown()
        cls.conn.close()
    
    def test_health_endpoint(self):
        """测试健康检查接口"""
        self.conn.request('GET', '/health')
        response = self.conn.getresponse()
        
        self.assertEqual(response.status, 200)
        
        data = json.loads(response.read().decode())
        self.assertEqual(data['status'], 'ok')
        self.assertIn('version', data)
    
    def test_404_endpoint(self):
        """测试不存在的接口"""
        self.conn.request('GET', '/notfound')
        response = self.conn.getresponse()
        
        self.assertEqual(response.status, 404)
    
    def test_transcribe_missing_audio(self):
        """测试转写接口缺少音频文件"""
        payload = json.dumps({
            'audio_path': '/nonexistent/file.mp3'
        })
        
        self.conn.request('POST', '/transcribe', body=payload, headers={
            'Content-Type': 'application/json'
        })
        response = self.conn.getresponse()
        
        self.assertEqual(response.status, 400)
        
        data = json.loads(response.read().decode())
        self.assertIn('error', data)
    
    def test_summarize_missing_text(self):
        """测试摘要接口缺少文本"""
        payload = json.dumps({})
        
        self.conn.request('POST', '/summarize', body=payload, headers={
            'Content-Type': 'application/json'
        })
        response = self.conn.getresponse()
        
        self.assertEqual(response.status, 400)
        
        data = json.loads(response.read().decode())
        self.assertIn('error', data)
    
    def test_invalid_json(self):
        """测试无效的 JSON 请求"""
        self.conn.request('POST', '/transcribe', body='invalid json', headers={
            'Content-Type': 'application/json'
        })
        response = self.conn.getresponse()
        
        self.assertEqual(response.status, 400)


class TestSummarize(unittest.TestCase):
    """测试摘要功能"""
    
    def setUp(self):
        """创建请求处理器实例"""
        self.handler = RequestHandler
    
    def test_summarize_local_short(self):
        """测试本地短摘要"""
        # 这里需要模拟请求对象进行测试
        # 实际测试需要在集成环境中运行
        pass


class TestConfig(unittest.TestCase):
    """测试配置相关"""
    
    def test_default_port(self):
        """测试默认端口"""
        self.assertEqual(PORT, 8765)


if __name__ == '__main__':
    # 运行测试
    unittest.main(verbosity=2)
