import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../services/logger_service.dart';
import '../services/config_service.dart';
import '../models/channel.dart';

/// 本地服务调用 - 启动 Python 服务并通过 HTTP 访问
class NativeService {
  static const String _baseUrl = 'http://127.0.0.1:8765';
  static const int _port = 8765;
  static Process? _pythonProcess;
  static bool _isInitialized = false;
  static Future<void>? _initializing;
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(minutes: 30),
    ),
  );

  /// 初始化 Python 服务
  static Future<void> initialize() async {
    if (_isInitialized) return;
    if (_initializing != null) return _initializing!;
    _initializing = _doInitialize();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  static Future<void> _doInitialize() async {
    if (_isInitialized) return;

    // 如果已有服务并且接口兼容，直接复用
    final healthy = await checkHealth();
    final compatible = await _checkApiCompatibility();
    if (healthy && compatible) {
      _isInitialized = true;
      return;
    }
    if (healthy && !compatible) {
      await LoggerService.instance.warn(
        'Existing Python service is incompatible, attempting cleanup',
      );
      await _cleanupStaleService();
    }

    try {
      final appDir = await getApplicationSupportDirectory();
      final logger = LoggerService.instance;
      // 每次启动都尝试同步内置 server.py，避免旧版本脚本残留
      await _extractBundledServer(appDir.path);
      final pythonPath = await _getPythonPath();
      final scriptPath = await _getScriptPath();

      await logger.info('Starting Python service', fields: {
        'python': pythonPath,
        'script': scriptPath,
      });

      _pythonProcess = await _startProcessWithRetry(
        pythonPath: pythonPath,
        scriptPath: scriptPath,
      );

      _pythonProcess!.stdout.transform(systemEncoding.decoder).listen((data) {
        if (data.toString().trim().isNotEmpty) {
          logger.debug('Python stdout', fields: {'line': data.trim()});
        }
      });
      _pythonProcess!.stderr.transform(systemEncoding.decoder).listen((data) {
        if (data.toString().trim().isNotEmpty) {
          logger.warn('Python stderr', fields: {'line': data.trim()});
        }
      });

      await Future.delayed(const Duration(seconds: 2));

      final startupHealthy = await checkHealth();
      final startupCompatible = await _checkApiCompatibility();
      if (!startupHealthy && !startupCompatible) {
        throw Exception(
          'Python service check failed (healthy=$startupHealthy, compatible=$startupCompatible)',
        );
      }

      if (startupHealthy && !startupCompatible) {
        await logger.warn(
          'Python service started but /models is not compatible; continue in fallback mode',
        );
      }
      _isInitialized = true;
      await logger.info('Python service initialized');
    } catch (e) {
      await LoggerService.instance
          .error('Python service initialize failed', error: e);
      throw Exception('Failed to initialize Python service: $e');
    }
  }

  static Future<Process> _startProcessWithRetry({
    required String pythonPath,
    required String scriptPath,
  }) async {
    final appDir = await getApplicationSupportDirectory();
    final logsDir = await LoggerService.instance.logsPath();
    final config = await ConfigService().loadConfig();
    final modelsDir = await _resolveModelDir(config);
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    Exception? lastError;
    for (var i = 0; i < 3; i++) {
      try {
        final env = Map<String, String>.from(Platform.environment);
        env['VOICE_APP_SUPPORT_DIR'] = appDir.path;
        env['VOICE_LOG_DIR'] = logsDir;
        env['VOICE_MODEL_DIR'] = modelsDir.path;
        env['VOICE_MODEL_SOURCE'] = config.transcription.local.modelSource;
        final hfEndpoint = config.transcription.local.hfEndpoint?.trim() ?? '';
        final whisperBaseUrl =
            config.transcription.local.whisperWeightsBaseUrl?.trim() ?? '';
        if (hfEndpoint.isNotEmpty) {
          env['HF_ENDPOINT'] = hfEndpoint;
        }
        if (whisperBaseUrl.isNotEmpty) {
          env['VOICE_WHISPER_WEIGHTS_BASE_URL'] = whisperBaseUrl;
        }
        final process = await Process.start(
          pythonPath,
          [scriptPath],
          mode: ProcessStartMode.normal,
          environment: env,
        );
        await _writePidFile(process.pid);
        return process;
      } catch (e) {
        lastError = Exception(e.toString());
        await LoggerService.instance.warn(
          'Python start attempt failed',
          fields: {'attempt': i + 1, 'error': e.toString()},
        );
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    throw lastError ?? Exception('Unknown startup failure');
  }

  static Future<Directory> _resolveModelDir(AppConfig config) async {
    final custom = config.transcription.local.modelRootDir?.trim() ?? '';
    if (custom.isNotEmpty) {
      return Directory(custom);
    }
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        (await getApplicationSupportDirectory()).path;
    return Directory('$home/.voice-transcription/models');
  }

  static Future<void> _cleanupStaleService() async {
    try {
      if (_pythonProcess != null) {
        _pythonProcess!.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 350));
      }
      final pid = await _readPidFile();
      if (pid != null) {
        await _killPid(pid);
      }
      await _killByPort();
      await _deletePidFile();
    } catch (e) {
      await LoggerService.instance.warn(
        'Failed to cleanup stale python service',
        fields: {'error': e.toString()},
      );
    } finally {
      _pythonProcess = null;
      _isInitialized = false;
    }
  }

  static Future<String> _pidFilePath() async {
    final appDir = await getApplicationSupportDirectory();
    final pythonDir = Directory('${appDir.path}/python');
    if (!await pythonDir.exists()) {
      await pythonDir.create(recursive: true);
    }
    return '${pythonDir.path}/server.pid';
  }

  static Future<void> _writePidFile(int pid) async {
    final path = await _pidFilePath();
    await File(path).writeAsString(pid.toString(), flush: true);
  }

  static Future<int?> _readPidFile() async {
    final path = await _pidFilePath();
    final file = File(path);
    if (!await file.exists()) return null;
    final raw = (await file.readAsString()).trim();
    return int.tryParse(raw);
  }

  static Future<void> _deletePidFile() async {
    final path = await _pidFilePath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<void> _killPid(int pid) async {
    if (pid <= 0) return;
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '$pid', '/F']);
      } else {
        await Process.run('kill', ['-9', '$pid']);
      }
    } catch (_) {}
  }

  static Future<void> _killByPort() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'cmd',
          ['/c', 'netstat -ano | findstr :$_port'],
        );
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length < 5) continue;
          final pid = int.tryParse(parts.last);
          if (pid != null && pid > 0) {
            await _killPid(pid);
          }
        }
        return;
      }

      final result = await Process.run('lsof', ['-ti', 'tcp:$_port']);
      final pids = result.stdout
          .toString()
          .split('\n')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();
      for (final pid in pids) {
        await _killPid(pid);
      }
    } catch (_) {}
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

    // 尝试使用应用包内的 Python 运行时
    final bundledPython = await _getBundledPythonPath();
    if (bundledPython != null && await File(bundledPython).exists()) {
      return bundledPython;
    }

    // 最后使用应用私有虚拟环境，避免污染系统 Python。
    return _ensureManagedPythonEnvironment();
  }

  static Future<String?> _getBundledPythonPath() async {
    try {
      final exePath = Platform.resolvedExecutable;
      final exeDir = File(exePath).parent.path;

      if (Platform.isMacOS) {
        // macOS: <App>.app/Contents/MacOS/<exe>
        const marker = '/Contents/MacOS';
        final idx = exeDir.indexOf(marker);
        if (idx != -1) {
          final resourcesDir = '${exeDir.substring(0, idx)}/Contents/Resources';
          return '$resourcesDir/python/bin/python3';
        }
      }

      if (Platform.isWindows || Platform.isLinux) {
        // Windows/Linux: bundle 根目录
        return '$exeDir/python/${Platform.isWindows ? 'python.exe' : 'bin/python3'}';
      }
    } catch (e) {
      await LoggerService.instance.warn('Failed to locate bundled python',
          fields: {'error': e.toString()});
    }
    return null;
  }

  /// 获取脚本路径
  static Future<String> _getScriptPath() async {
    final appDir = await getApplicationSupportDirectory();
    final scriptPath = '${appDir.path}/python/server.py';

    if (!await File(scriptPath).exists()) {
      await _extractBundledServer(appDir.path);
    }

    // 如果脚本不存在，使用相对路径（开发环境）
    if (!await File(scriptPath).exists()) {
      if (await File('backend/server.py').exists()) {
        return 'backend/server.py';
      }
      return 'python/server.py';
    }

    return scriptPath;
  }

  static Future<String> _getRequirementsPath() async {
    final appDir = await getApplicationSupportDirectory();
    final requirementsPath = '${appDir.path}/python/requirements.txt';
    if (!await File(requirementsPath).exists()) {
      await _extractBundledServer(appDir.path);
    }
    if (await File(requirementsPath).exists()) {
      return requirementsPath;
    }
    if (await File('backend/requirements.txt').exists()) {
      return 'backend/requirements.txt';
    }
    return requirementsPath;
  }

  static Future<String> _ensureManagedPythonEnvironment() async {
    final appDir = await getApplicationSupportDirectory();
    final venvDir = Directory('${appDir.path}/managed_python');
    final pythonPath = Platform.isWindows
        ? '${venvDir.path}/Scripts/python.exe'
        : '${venvDir.path}/bin/python3';
    final pipPath = Platform.isWindows
        ? '${venvDir.path}/Scripts/pip.exe'
        : '${venvDir.path}/bin/pip';
    final markerPath = '${venvDir.path}/.requirements.lock';
    final requirementsPath = await _getRequirementsPath();
    final requirementsFile = File(requirementsPath);
    final requirementsContent = await requirementsFile.exists()
        ? await requirementsFile.readAsString()
        : '';

    if (!await File(pythonPath).exists()) {
      if (!await venvDir.exists()) {
        await venvDir.create(recursive: true);
      }
      final basePython = Platform.isWindows ? 'python' : 'python3';
      final create = await Process.run(basePython, ['-m', 'venv', venvDir.path]);
      if (create.exitCode != 0) {
        throw Exception(
          '创建应用私有 Python 环境失败: ${create.stderr ?? create.stdout}',
        );
      }
    }

    final markerFile = File(markerPath);
    final markerMatches = await markerFile.exists() &&
        await markerFile.readAsString() == requirementsContent;
    if (!markerMatches) {
      final upgradePip = await Process.run(pythonPath, ['-m', 'pip', 'install', '--upgrade', 'pip']);
      if (upgradePip.exitCode != 0) {
        throw Exception('升级 pip 失败: ${upgradePip.stderr ?? upgradePip.stdout}');
      }
      final install = await Process.run(
        pipPath,
        ['install', '-r', requirementsPath],
      );
      if (install.exitCode != 0) {
        throw Exception('安装 Python 依赖失败: ${install.stderr ?? install.stdout}');
      }
      await markerFile.writeAsString(requirementsContent, flush: true);
      await LoggerService.instance.info(
        'Managed Python environment prepared',
        fields: {'venv': venvDir.path},
      );
    }

    return pythonPath;
  }

  /// 从应用资源中释放 Python 运行脚本和依赖清单
  static Future<void> _extractBundledServer(String appDirPath) async {
    try {
      final targetDir = Directory('$appDirPath/python');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      final files = <String, String>{
        'server.py': await rootBundle.loadString('assets/python/server.py'),
        'requirements.txt':
            await rootBundle.loadString('assets/python/requirements.txt'),
      };
      for (final entry in files.entries) {
        final targetFile = File('${targetDir.path}/${entry.key}');
        await targetFile.writeAsString(entry.value);
      }
    } catch (e) {
      await LoggerService.instance.warn('Failed to extract bundled server',
          fields: {'error': e.toString()});
    }
  }

  /// 语音识别
  static Future<Map<String, dynamic>> transcribe({
    required String audioPath,
    required String model,
    String language = 'auto',
    String provider = 'whisper',
    String? taskId,
    Map<String, dynamic>? providerConfig,
  }) async {
    await initialize();
    final response = await _dio.post(
      '/transcribe',
      data: {
        'audio_path': audioPath,
        'model': model,
        'language': language,
        'provider': provider,
        'task_id': taskId,
        'provider_config': providerConfig ?? {},
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 生成摘要
  static Future<Map<String, dynamic>> summarize({
    required String text,
    required String length,
    String provider = 'local',
    String? taskId,
    Map<String, dynamic>? providerConfig,
  }) async {
    await initialize();
    final response = await _dio.post(
      '/summarize',
      data: {
        'text': text,
        'length': length,
        'provider': provider,
        'task_id': taskId,
        'provider_config': providerConfig ?? {},
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 下载模型
  static Future<Map<String, dynamic>> downloadModel(
    String model, {
    String? taskId,
    String? source,
  }) async {
    await initialize();
    final response = await _dio.post(
      '/download_model',
      data: {
        'model': model,
        'task_id': taskId,
        if (source != null && source.trim().isNotEmpty) 'source': source.trim(),
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> getDownloadStatus(String model) async {
    await initialize();
    final response = await _dio.get(
      '/download_status',
      queryParameters: {'model': model},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// 检查健康状态
  static Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['status'] == 'ok';
    } catch (e) {
      await LoggerService.instance
          .warn('Health check failed', fields: {'error': e.toString()});
      return false;
    }
  }

  static Future<bool> _checkApiCompatibility() async {
    try {
      final response = await _dio.get('/models');
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['models'] is List;
    } catch (_) {
      return false;
    }
  }

  /// 获取模型列表
  static Future<Map<String, dynamic>> getModels() async {
    await initialize();
    try {
      final response = await _dio.get('/models');
      return Map<String, dynamic>.from(response.data as Map);
    } catch (_) {
      return {
        'models': [
          {'name': 'tiny', 'status': 'unknown', 'size': '--'},
          {'name': 'base', 'status': 'unknown', 'size': '--'},
          {'name': 'small', 'status': 'unknown', 'size': '--'},
          {'name': 'medium', 'status': 'unknown', 'size': '--'},
          {'name': 'large-v3', 'status': 'unknown', 'size': '--'},
        ]
      };
    }
  }

  /// 关闭服务
  static Future<void> dispose() async {
    await _cleanupStaleService();
  }

  static Future<void> restart() async {
    await dispose();
    await initialize();
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
