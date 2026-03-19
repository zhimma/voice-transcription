import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import '../models/channel.dart';
import '../models/prompt_history.dart';
import 'database_service.dart';
import 'logger_service.dart';

class ConfigService {
  static const String _configFileName = 'config.json';
  static AppConfig? _cachedConfig;

  static const String defaultConversationAnalysisPrompt =
      r'你是一个专业的客服对话分析专家。请对以下客服-客户对话进行深度分析，并以JSON格式返回分析结果。\n\n'
      r'对话内容：\n'
      r'```\n'
      r'{transcription}\n'
      r'```\n\n'
      r'请按照以下JSON结构输出分析结果（只输出JSON，不要其他内容）：\n\n'
      r'{ "info": { "type": "对话类型", "scenario": "场景", "summary": "摘要" }, "customer": { "customerId": "客户ID", "customerName": "客户姓名", "contactInfo": "联系方式", "customerType": "客户类型", "accountInfo": "账号信息" }, "emotion": { "customerEmotion": "情绪", "intensity": 5, "trends": "情绪变化", "keyTriggers": ["触发点"] }, "feedback": { "hasIssue": true, "issueAbstract": "问题摘要", "category": {"l1": "一级分类", "l2": "二级分类"}, "severity": "严重程度", "expectations": ["期望"] }, "quality": { "agentPerformance": "客服表现", "responseTime": "响应时间", "professionalism": 8, "communication": 8, "resolutionWillingness": 9 }, "resolution": { "status": "解决状态", "customerSatisfied": true, "resolutionTimeMinutes": 15, "summary": "解决方案摘要", "nextSteps": ["步骤"] }, "structured": { "products": ["产品"], "keywords": ["关键词"], "entities": {}, "tags": ["标签"] } }\n\n'
      r'注意：返回必须是合法的JSON格式，不要有注释，所有字段都必须包含。';

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
      prompts: PromptsConfig(
        conversationAnalysis: defaultConversationAnalysisPrompt,
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

  // 提示词管理方法
  Future<String> getActivePrompt(String promptType) async {
    final db = DatabaseService.instance;
    final activePrompt = await db.getActivePrompt(promptType);
    if (activePrompt != null) {
      return activePrompt.content;
    }
    // 如果没有激活的提示词，使用配置中的默认提示词
    final config = await loadConfig();
    if (promptType == 'conversation_analysis') {
      return config.prompts.conversationAnalysis.isNotEmpty
          ? config.prompts.conversationAnalysis
          : defaultConversationAnalysisPrompt;
    }
    return '';
  }

  Future<void> savePromptVersion(
    String promptType,
    String content, {
    String? note,
    String? createdBy,
  }) async {
    final db = DatabaseService.instance;

    // 获取下一个版本号
    final nextVersion = await db.getNextPromptVersion(promptType);

    // 创建新的历史记录
    final history = PromptHistory(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      promptType: promptType,
      content: content,
      version: nextVersion,
      isActive: true,
      note: note,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    // 插入新记录
    await db.insertPromptHistory(history);

    // 设置为激活状态（会自动取消其他版本的激活状态）
    await db.setActivePrompt(promptType, history.id);

    // 同时更新配置文件
    final config = await loadConfig();
    if (promptType == 'conversation_analysis') {
      final newConfig = config.copyWith(
        prompts: config.prompts.copyWith(conversationAnalysis: content),
      );
      await saveConfig(newConfig);
    }
  }

  Future<List<PromptHistory>> getPromptHistory(String promptType,
      {int limit = 20}) async {
    return await DatabaseService.instance.getPromptHistory(promptType,
        limit: limit);
  }

  Future<void> activatePromptVersion(String promptType, String id) async {
    final db = DatabaseService.instance;

    // 设置为激活状态
    await db.setActivePrompt(promptType, id);

    // 获取该版本内容并更新配置
    final history = await db.getPromptHistory(promptType);
    final selected = history.firstWhere((h) => h.id == id);
    final config = await loadConfig();
    if (promptType == 'conversation_analysis') {
      final newConfig = config.copyWith(
        prompts: config.prompts.copyWith(conversationAnalysis: selected.content),
      );
      await saveConfig(newConfig);
    }
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
