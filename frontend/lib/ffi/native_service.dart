import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// FFI 服务 - 调用本地 Python 服务
/// 通过 stdin/stdout 进行 JSON 通信
class NativeService {
  static Process? _pythonProcess;
  static final _responseController = StreamController<Map<String, dynamic>>.broadcast();
  static bool _isInitialized = false;
  static final _pendingRequests = <String, Completer<Map<String, dynamic>>>{};
  
  /// 初始化 Python 服务
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 获取 Python 路径
      final pythonPath = await _getPythonPath();
      final scriptPath = await _getScriptPath();
      
      print('Starting Python service...');
      print('Python: $pythonPath');
      print('Script: $scriptPath');
      
      // 启动 Python 服务
      _pythonProcess = await Process.start(
        pythonPath,
        [scriptPath],
        mode: ProcessStartMode.normal,
      );
      
      // 监听输出
      _pythonProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleOutput, onError: _handleError);
      
      _pythonProcess!.stderr
          .transform(utf8.decoder)
          .listen(_handleStderr, onError: _handleError);
      
      // 等待服务启动
      await Future.delayed(const Duration(seconds: 2));
      
      // 测试连接
      final health = await checkHealth();
      if (!health) {
        throw Exception('Python service health check failed');
      }
      
      _isInitialized = true;
      print('Python service initialized successfully');
    } catch (e) {
      print('Failed to initialize Python service: $e');
      throw Exception('Failed to initialize Python service: $e');
    }
  }
  
  /// 获取 Python 路径
  static Future<String> _getPythonPath() async {
    // 优先使用嵌入式 Python
    final appDir = await getApplicationSupportDirectory();
    final embeddedPython = Platform.isWindows
        ? '${appDir.path}/python/python.exe'
        : '${appDir.path}/python/bin/python3';
    
    if (await File(embeddedPython).exists()) {
      return embeddedPython;
    }
    
    // 使用系统 Python
    if (Platform.isWindows) {
      return 'python';
    }
    return 'python3';
  }
  
  /// 获取脚本路径
  static Future<String> _getScriptPath() async {
    final appDir = await getApplicationSupportDirectory();
    final scriptPath = '${appDir.path}/python/server.py';
    
    // 如果脚本不存在，使用相对路径（开发环境）
    if (!await File(scriptPath).exists()) {
      return 'python/server.py';
    }
    
    return scriptPath;
  }
  
  /// 处理 Python 输出
  static void _handleOutput(String line) {
    if (line.isEmpty) return;
    
    try {
      final json = jsonDecode(line);
      final requestId = json['request_id'] as String?;
      
      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        _pendingRequests[requestId]!.complete(json);
        _pendingRequests.remove(requestId);
      } else {
        _responseController.add(json);
      }
    } catch (e) {
      // 非 JSON 输出，可能是日志
      print('[Python] $line');
    }
  }
  
  /// 处理 stderr
  static void _handleStderr(String data) {
    print('[Python Error] $data');
  }
  
  /// 处理错误
  static void _handleError(Object error) {
    print('Python process error: $error');
  }
  
  /// 发送请求到 Python 服务
  static Future<Map<String, dynamic>> _sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    await initialize();
    
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();
    final request = jsonEncode({
      'request_id': requestId,
      'method': method,
      'params': params,
    });
    
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[requestId] = completer;
    
    _pythonProcess!.stdin.writeln(request);
    
    return completer.future.timeout(
      const Duration(minutes: 30),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        throw TimeoutException('Request timeout: $method');
      },
    );
  }
  
  /// 语音识别
  static Future<Map<String, dynamic>> transcribe({
    required String audioPath,
    required String model,
    String language = 'auto',
    String provider = 'whisper',
  }) async {
    return await _sendRequest('transcribe', {
      'audio_path': audioPath,
      'model': model,
      'language': language,
      'provider': provider,
    });
  }
  
  /// 生成摘要
  static Future<Map<String, dynamic>> summarize({
    required String text,
    required String length,
    String provider = 'local',
  }) async {
    return await _sendRequest('summarize', {
      'text': text,
      'length': length,
      'provider': provider,
    });
  }
  
  /// 下载模型
  static Future<Map<String, dynamic>> downloadModel(String model) async {
    return await _sendRequest('download_model', {
      'model': model,
    });
  }
  
  /// 检查健康状态
  static Future<bool> checkHealth() async {
    try {
      final response = await _sendRequest('health', {});
      return response['status'] == 'ok';
    } catch (e) {
      print('Health check failed: $e');
      return false;
    }
  }
  
  /// 获取模型列表
  static Future<Map<String, dynamic>> getModels() async {
    return await _sendRequest('get_models', {});
  }
  
  /// 关闭服务
  static Future<void> dispose() async {
    if (_pythonProcess != null) {
      _pythonProcess!.kill();
      _pythonProcess = null;
    }
    _isInitialized = false;
    
    // 清理未完成的请求
    for (final completer in _pendingRequests.values) {
      completer.completeError('Service disposed');
    }
    _pendingRequests.clear();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  
  @override
  String toString() => 'TimeoutException: $message';
}
