import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import '../models/channel.dart';
import 'logger_service.dart';

class ConfigService {
  static const String _configFileName = 'config.json';
  static AppConfig? _cachedConfig;

  // 获取配置目录
  Future<String> get _configDir async {
    final appDir = await getApplicationSupportDirectory();
    final configDir = Directory('${appDir.path}/config');
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir.path;
  }

  // 获取配置文件路径
  Future<String> get _configPath async {
    return '${await _configDir}/$_configFileName';
  }

  // 加载配置
  Future<AppConfig> loadConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }

    final path = await _configPath;
    final file = File(path);

    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content);
      _cachedConfig = AppConfig.fromJson(json);
    } else {
      // 使用默认配置
      _cachedConfig = _defaultConfig();
    }

    return _cachedConfig!;
  }

  // 保存配置
  Future<void> saveConfig(AppConfig config) async {
    final path = await _configPath;
    final file = File(path);
    final content = jsonEncode(config.toJson());
    await file.writeAsString(content);
    _cachedConfig = config;
    await LoggerService.instance.setConfig(config.logging);
  }

  Future<AppConfig> addRecentFile(String filePath, {int maxItems = 10}) async {
    final current = await loadConfig();
    final updated = [
      filePath,
      ...current.recentFiles.where((f) => f != filePath),
    ];
    final trimmed = updated.take(maxItems).toList();
    final newConfig = current.copyWith(recentFiles: trimmed);
    await saveConfig(newConfig);
    return newConfig;
  }

  // 从字符串导入配置（支持 JSON/YAML）
  Future<AppConfig> importFromString(String configStr) async {
    Map<String, dynamic> json;

    // 尝试 JSON
    try {
      json = jsonDecode(configStr);
    } catch (_) {
      // 尝试 YAML
      try {
        final yaml = loadYaml(configStr);
        json = _yamlToJson(yaml);
      } catch (e) {
        throw Exception('配置文件格式错误，请使用 JSON 或 YAML 格式');
      }
    }

    final config = AppConfig.fromJson(json);
    await validateConfig(config);
    return config;
  }

  // 导出配置为字符串
  String exportToString(AppConfig config, {bool hideSecrets = false}) {
    var exportConfig = config;

    if (hideSecrets) {
      // 隐藏敏感信息
      exportConfig = _maskSecrets(config);
    }

    return const JsonEncoder.withIndent('  ').convert(exportConfig.toJson());
  }

  // 验证配置
  Future<void> validateConfig(AppConfig config) async {
    // 验证语音识别配置
    if (config.transcription.cloudChannels.isEmpty &&
        config.transcription.mode == 'cloud') {
      throw Exception('云端模式至少需要配置一个渠道');
    }

    // 验证 API Key 格式
    for (final channel in config.transcription.cloudChannels) {
      if (channel.type == ChannelType.api) {
        final apiKey = channel.config['api_key'] as String?;
        if (apiKey == null || apiKey.isEmpty) {
          throw Exception('渠道 ${channel.name} 未配置 API Key');
        }
      }
    }

    // 验证摘要配置
    if (config.summary.channels.isEmpty) {
      throw Exception('至少需要配置一个摘要渠道');
    }

    // 验证优先级不重复
    final priorities = <int>{};
    for (final channel in config.transcription.cloudChannels) {
      if (!priorities.add(channel.priority)) {
        throw Exception('语音识别渠道优先级不能重复');
      }
    }
  }

  // 测试渠道连接
  Future<bool> testChannel(ChannelConfig channel) async {
    final result = await testChannelDetailed(channel);
    return result.ok;
  }

  Future<ChannelTestResult> testChannelDetailed(ChannelConfig channel) async {
    final apiKey = channel.config['api_key']?.toString().trim() ?? '';
    final apiUrl = channel.config['api_url']?.toString().trim() ?? '';
    if (apiKey.isEmpty || apiUrl.isEmpty) {
      return const ChannelTestResult(
        ok: false,
        message: '请填写 API Key 和 API URL',
        field: 'api_key/api_url',
      );
    }

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
        sendTimeout: const Duration(seconds: 8),
      ),
    );

    try {
      if (channel.provider == 'qwen') {
        // 连通性测试固定用文本模型，避免音频专用模型因输入类型不匹配而误报失败。
        const model = 'qwen3.5-plus';
        final response = await dio.post(
          '${apiUrl.replaceAll(RegExp(r"/+$"), "")}/chat/completions',
          data: {
            'model': model,
            'messages': [
              {
                'role': 'user',
                'content': 'ping',
              }
            ],
            'max_tokens': 1,
          },
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
          ),
        );
        final ok = response.statusCode != null && response.statusCode! < 300;
        return ChannelTestResult(
          ok: ok,
          message: ok ? '连接成功' : '连接失败: HTTP ${response.statusCode}',
        );
      }
      return const ChannelTestResult(
        ok: false,
        message: '当前仅支持 Qwen 渠道测试',
        field: 'provider',
      );
    } on DioException catch (e) {
      return ChannelTestResult(
        ok: false,
        message: '连接失败: ${e.message ?? '网络错误'}',
      );
    } catch (e) {
      return ChannelTestResult(
        ok: false,
        message: '连接失败: $e',
      );
    }
  }

  // 获取启用的语音识别渠道（按优先级排序）
  List<ChannelConfig> getEnabledTranscriptionChannels(AppConfig config) {
    final channels =
        config.transcription.cloudChannels.where((c) => c.enabled).toList();
    channels.sort((a, b) => a.priority.compareTo(b.priority));
    return channels;
  }

  // 获取启用的摘要渠道（按优先级排序）
  List<ChannelConfig> getEnabledSummaryChannels(AppConfig config) {
    final channels = config.summary.channels.where((c) => c.enabled).toList();
    channels.sort((a, b) => a.priority.compareTo(b.priority));
    return channels;
  }

  // 默认配置
  AppConfig _defaultConfig() {
    return const AppConfig(
      transcription: TranscriptionConfig(
        mode: 'local',
        local: LocalTranscriptionConfig(
          model: 'base',
          device: 'auto',
          modelSource: 'modelscope',
        ),
        cloudChannels: [],
      ),
      summary: SummaryConfig(
        channels: [
          ChannelConfig(
            id: 'local-summary',
            name: '本地简化版',
            type: ChannelType.local,
            provider: 'local',
            enabled: true,
            priority: 1,
            config: {},
          ),
        ],
      ),
      recentFiles: [],
      logging: LoggingConfig(
        level: 'DEBUG',
        maxFileMb: 20,
        retentionDays: 7,
      ),
    );
  }

  // YAML 转 JSON
  Map<String, dynamic> _yamlToJson(YamlMap yaml) {
    final result = <String, dynamic>{};
    yaml.forEach((key, value) {
      result[key.toString()] = _convertYamlValue(value);
    });
    return result;
  }

  dynamic _convertYamlValue(dynamic value) {
    if (value is YamlMap) {
      return _yamlToJson(value);
    } else if (value is YamlList) {
      return value.map((e) => _convertYamlValue(e)).toList();
    }
    return value;
  }

  // 隐藏敏感信息
  AppConfig _maskSecrets(AppConfig config) {
    // 创建副本并隐藏 API Key
    final maskedChannels = config.transcription.cloudChannels.map((channel) {
      final maskedConfig = Map<String, dynamic>.from(channel.config);
      if (maskedConfig.containsKey('api_key')) {
        maskedConfig['api_key'] = '********';
      }
      return channel.copyWith(config: maskedConfig);
    }).toList();

    final maskedSummaryChannels = config.summary.channels.map((channel) {
      final maskedConfig = Map<String, dynamic>.from(channel.config);
      if (maskedConfig.containsKey('api_key')) {
        maskedConfig['api_key'] = '********';
      }
      return channel.copyWith(config: maskedConfig);
    }).toList();

    return config.copyWith(
      transcription: config.transcription.copyWith(
        cloudChannels: maskedChannels,
      ),
      summary: config.summary.copyWith(
        channels: maskedSummaryChannels,
      ),
    );
  }
}

class ChannelTestResult {
  final bool ok;
  final String message;
  final String? field;

  const ChannelTestResult({
    required this.ok,
    required this.message,
    this.field,
  });
}
