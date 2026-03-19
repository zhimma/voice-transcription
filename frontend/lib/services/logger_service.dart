import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/channel.dart';

enum LogLevel { debug, info, warn, error }
enum LogFileType { app, python }

class LoggerService {
  LoggerService._();
  static final LoggerService instance = LoggerService._();

  static const _logDir = 'logs';
  static const _logFile = 'app.log';
  static const _maxRotations = 5;
  static bool _initialized = false;
  static late Directory _logsDirectory;
  static late File _logFileRef;
  static LogLevel _minLevel = LogLevel.debug;
  static int _maxBytes = 20 * 1024 * 1024;
  static int _retentionDays = 7;

  Future<void> initialize(LoggingConfig config) async {
    if (_initialized) return;
    final appDir = await getApplicationSupportDirectory();
    _logsDirectory = Directory(p.join(appDir.path, _logDir));
    if (!await _logsDirectory.exists()) {
      await _logsDirectory.create(recursive: true);
    }
    _logFileRef = File(p.join(_logsDirectory.path, _logFile));

    _minLevel = _parseLevel(config.level);
    _maxBytes = config.maxFileMb * 1024 * 1024;
    _retentionDays = config.retentionDays;
    await _cleanupOldLogs();
    _initialized = true;
    await info('Logger initialized', fields: {'level': config.level});
  }

  Future<void> setConfig(LoggingConfig config) async {
    if (!_initialized) {
      await initialize(config);
      return;
    }
    _minLevel = _parseLevel(config.level);
    _maxBytes = config.maxFileMb * 1024 * 1024;
    _retentionDays = config.retentionDays;
    await _cleanupOldLogs();
    await info('Logger config updated', fields: {
      'level': config.level,
      'max_file_mb': config.maxFileMb,
      'retention_days': config.retentionDays,
    });
  }

  Future<String> logsPath() async {
    if (!_initialized) {
      await initialize(const LoggingConfig());
    }
    return _logsDirectory.path;
  }

  Future<void> debug(String message,
      {String? taskId, Map<String, dynamic>? fields}) async {
    await _write(LogLevel.debug, message, taskId: taskId, fields: fields);
  }

  Future<void> info(String message,
      {String? taskId, Map<String, dynamic>? fields}) async {
    await _write(LogLevel.info, message, taskId: taskId, fields: fields);
  }

  Future<void> warn(String message,
      {String? taskId, Map<String, dynamic>? fields}) async {
    await _write(LogLevel.warn, message, taskId: taskId, fields: fields);
  }

  Future<void> error(String message,
      {String? taskId,
      Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? fields}) async {
    final merged = <String, dynamic>{
      if (fields != null) ...fields,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stack': stackTrace.toString(),
    };
    await _write(LogLevel.error, message, taskId: taskId, fields: merged);
  }

  Map<String, dynamic> attachTaskId(
    String taskId, {
    Map<String, dynamic>? fields,
  }) {
    return <String, dynamic>{
      'task_id': taskId,
      if (fields != null) ...fields,
    };
  }

  Future<void> _write(LogLevel level, String message,
      {String? taskId, Map<String, dynamic>? fields}) async {
    if (level.index < _minLevel.index) return;
    if (!_initialized) {
      await initialize(const LoggingConfig());
    }
    await _rotateIfNeeded();
    final payload = {
      'ts': DateTime.now().toIso8601String(),
      'level': level.name.toUpperCase(),
      'message': message,
      if (taskId != null) 'task_id': taskId,
      if (fields != null && fields.isNotEmpty) 'fields': _sanitize(fields),
    };
    final line = '${jsonEncode(payload)}\n';
    await _logFileRef.writeAsString(line, mode: FileMode.append, flush: true);
  }

  LogLevel _parseLevel(String value) {
    switch (value.toUpperCase()) {
      case 'ERROR':
        return LogLevel.error;
      case 'WARN':
      case 'WARNING':
        return LogLevel.warn;
      case 'INFO':
        return LogLevel.info;
      default:
        return LogLevel.debug;
    }
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      final lowered = key.toLowerCase();
      if (lowered.contains('api_key') ||
          lowered.contains('token') ||
          lowered.contains('authorization')) {
        out[key] = '***';
      } else {
        out[key] = value;
      }
    });
    return out;
  }

  Future<void> _rotateIfNeeded() async {
    if (!await _logFileRef.exists()) return;
    final length = await _logFileRef.length();
    if (length < _maxBytes) return;
    for (var i = _maxRotations; i >= 1; i--) {
      final older = File('${_logFileRef.path}.$i');
      if (await older.exists()) {
        if (i == _maxRotations) {
          await older.delete();
        } else {
          await older.rename('${_logFileRef.path}.${i + 1}');
        }
      }
    }
    await _logFileRef.rename('${_logFileRef.path}.1');
    _logFileRef = File(p.join(_logsDirectory.path, _logFile));
  }

  Future<void> _cleanupOldLogs() async {
    if (!await _logsDirectory.exists()) return;
    final threshold = DateTime.now().subtract(Duration(days: _retentionDays));
    await for (final entry in _logsDirectory.list()) {
      if (entry is! File) continue;
      if (!entry.path.contains(_logFile)) continue;
      final stat = await entry.stat();
      if (stat.modified.isBefore(threshold)) {
        await entry.delete();
      }
    }
  }

  Future<void> openLogsDirectory() async {
    final dir = await logsPath();
    if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else {
      await Process.run('xdg-open', [dir]);
    }
  }

  Future<String?> exportBundle() async {
    if (!_initialized) {
      await initialize(const LoggingConfig());
    }
    final target = await FilePicker.platform.saveFile(
      dialogTitle: '导出日志',
      fileName:
          'voice_transcription_logs_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    if (target == null) return null;
    final files = await _logsDirectory
        .list()
        .where((e) => e is File)
        .cast<File>()
        .where((f) {
      final name = p.basename(f.path);
      return name.startsWith('app.log') || name.startsWith('python_server.log');
    }).toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final sink = File(target).openWrite(mode: FileMode.writeOnly);
    for (final file in files) {
      sink.writeln('=== ${p.basename(file.path)} ===');
      sink.writeln(await file.readAsString());
      sink.writeln();
    }
    await sink.close();
    return target;
  }

  Future<File> getLogFile(LogFileType type) async {
    if (!_initialized) {
      await initialize(const LoggingConfig());
    }
    final fileName = type == LogFileType.app ? 'app.log' : 'python_server.log';
    final file = File(p.join(_logsDirectory.path, fileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<String> readLogFile(LogFileType type) async {
    final file = await getLogFile(type);
    return file.readAsString();
  }

  Future<List<LogEntry>> readErrorEntries({int limit = 300}) async {
    if (!_initialized) {
      await initialize(const LoggingConfig());
    }
    final entries = <LogEntry>[];
    final files = await _logsDirectory
        .list()
        .where((e) => e is File)
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));

    for (final file in files) {
      final name = p.basename(file.path);
      final lines = await file.readAsLines();
      for (final line in lines.reversed) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (name.startsWith('app.log')) {
          final parsed = _tryParseAppLog(trimmed, name);
          if (parsed != null) {
            entries.add(parsed);
          }
        } else if (name.startsWith('python_server.log')) {
          final parsed = _tryParsePythonLog(trimmed, name);
          if (parsed != null) {
            entries.add(parsed);
          }
        }
        if (entries.length >= limit) {
          entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return entries;
        }
      }
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  LogEntry? _tryParseAppLog(String line, String fileName) {
    try {
      final map = jsonDecode(line);
      if (map is! Map) return null;
      final level = map['level']?.toString().toUpperCase() ?? '';
      if (level != 'ERROR') return null;
      final ts =
          DateTime.tryParse(map['ts']?.toString() ?? '') ?? DateTime.now();
      final msg = map['message']?.toString() ?? line;
      return LogEntry(
        timestamp: ts,
        level: level,
        source: fileName,
        message: msg,
        raw: line,
      );
    } catch (_) {
      return null;
    }
  }

  LogEntry? _tryParsePythonLog(String line, String fileName) {
    if (!line.contains(' ERROR ')) return null;
    final tsText = line.length >= 19 ? line.substring(0, 19) : '';
    final ts =
        DateTime.tryParse(tsText.replaceFirst(' ', 'T')) ?? DateTime.now();
    return LogEntry(
      timestamp: ts,
      level: 'ERROR',
      source: fileName,
      message: line,
      raw: line,
    );
  }
}

class LogEntry {
  final DateTime timestamp;
  final String level;
  final String source;
  final String message;
  final String raw;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.source,
    required this.message,
    required this.raw,
  });
}
