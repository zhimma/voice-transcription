import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/conversation_analysis.dart';
import '../models/channel.dart';
import 'config_service.dart';
import 'logger_service.dart';

/// 客服对话分析服务
/// 调用大模型对客服-客户对话进行深度分析
class ConversationAnalysisService {
  static const String _defaultPromptTemplate =
      '你是一个专业的客服对话分析专家。请对以下客服-客户对话进行深度分析，并以JSON格式返回分析结果。\n\n'
      '对话内容：\n'
      '```\n'
      '{transcription}\n'
      '```\n\n'
      '请按照以下JSON结构输出分析结果（只输出JSON，不要其他内容）。注意：所有 JSON 键名必须使用中文！\n\n'
      r'```json'
      '\n'
      '{\n'
      '  "基础信息": {\n'
      '    "对话类型": "咨询/投诉/售后/售前/技术支持/账单疑问/其他",\n'
      '    "业务标签": "业务标签名称",\n'
      '    "对话时长": "对话时长分钟数",\n'
      '    "客户发言次数": "客户发言次数",\n'
      '    "客服发言次数": "客服发言次数"\n'
      '  },\n'
      '  "客户画像": {\n'
      '    "客户类型": "新客/老客户/VIP/潜在高价值客户/未知",\n'
      '    "画像标签": ["理性型/冲动型/耐心/急躁/专业/小白等"],\n'
      '    "消费特征": "消费特征描述",\n'
      '    "历史关系": "历史关系描述",\n'
      '    "核心诉求": "核心诉求",\n'
      '    "显性需求": ["显性需求列表"],\n'
      '    "隐性需求": ["隐性需求列表"],\n'
      '    "期望解决方案": "期望解决方案"\n'
      '  },\n'
      '  "情绪分析": {\n'
      '    "整体情绪": "整体对话情绪：平和/友好/紧张/激烈/对抗",\n'
      '    "初始情绪": "客户初始情绪：平和/满意/疑惑/焦虑/愤怒/失望/兴奋",\n'
      '    "峰值情绪": "客户峰值情绪",\n'
      '    "结束情绪": "客户结束情绪",\n'
      '    "情绪趋势": "客户情绪趋势：上升/下降/波动/平稳",\n'
      '    "情绪强度": "客户情绪强度 1-10",\n'
      '    "客服情绪": "客服情绪状态：平和/耐心/急躁/专业/疲惫",\n'
      '    "关键触发点": ["触发客户情绪变化的关键点"],\n'
      '    "情绪节点": [\n'
      '      {\n'
      '        "轮次": "第几轮对话",\n'
      '        "触发事件": "触发事件",\n'
      '        "客户情绪": "客户情绪",\n'
      '        "客服应对": "客服应对"\n'
      '      }\n'
      '    ]\n'
      '  },\n'
      '  "问题反馈": {\n'
      '    "问题摘要": "一句话问题摘要",\n'
      '    "涉及产品服务": "涉及产品/服务",\n'
      '    "发生时间": "问题发生时间描述",\n'
      '    "发生频次": "首次/偶尔/经常/频繁",\n'
      '    "影响范围": "个人/部分用户/所有用户",\n'
      '    "问题分类": {\n'
      '      "一级分类": "产品问题/服务问题/物流问题/系统问题/其他",\n'
      '      "二级分类": "二级分类",\n'
      '      "标签": ["技术标签", "业务标签"]\n'
      '    },\n'
      '    "严重程度": {\n'
      '      "等级": "P0-致命/P1-严重/P2-一般/P3-轻微/P4-建议",\n'
      '      "评分": "严重程度评分1-5",\n'
      '      "评级理由": "评级理由",\n'
      '      "紧急程度": "立即/24小时内/本周内/不紧急"\n'
      '    },\n'
      '    "根因分析": {\n'
      '      "直接原因": "直接原因",\n'
      '      "可能根因": "可能根因",\n'
      '      "触发条件": "触发条件",\n'
      '      "责任归属": "客户/公司/第三方/多方/待定"\n'
      '    },\n'
      '    "解决方案": ["建议解决方案1", "建议解决方案2"]\n'
      '  },\n'
      '  "服务质量": {\n'
      '    "整体基调": "友好/中性/紧张/对抗",\n'
      '    "客户态度": "配合/中立/抵触/激烈",\n'
      '    "客服服务态度": "热情/友好/耐心/专业/冷淡/不耐烦",\n'
      '    "客服情绪状态": "积极/平和/疲惫/急躁",\n'
      '    "对话性质": "正常咨询/问题反馈/投诉抱怨/争议处理",\n'
      '    "强度指标": {\n'
      '      "冲突等级": "冲突等级1-5",\n'
      '      "情绪强度": "情绪强度1-5",\n'
      '      "语言激烈度": "语言激烈度1-5",\n'
      '      "对话紧张度": "对话紧张度1-5",\n'
      '      "整体评级": "A-平和/B-轻微摩擦/C-中度争执/D-激烈冲突/E-严重投诉"\n'
      '    },\n'
      '    "正向时刻": ["正向/表扬 moments"],\n'
      '    "负面时刻": ["贬义/抱怨 moments"],\n'
      '    "冲突时刻": ["激烈/冲突 moments"]\n'
      '  },\n'
      '  "解决情况": {\n'
      '    "解决状态": "完全解决/部分解决/未解决/待跟进/升级处理",\n'
      '    "客户是否满意": "true/false",\n'
      '    "满意度": "满意/基本满意/不满意/未表态",\n'
      '    "是否有衍生问题": "true/false",\n'
      '    "未解决问题": ["未解决问题清单"],\n'
      '    "解决摘要": "解决情况摘要"\n'
      '  },\n'
      '  "综合评估": {\n'
      '    "对话类型": "对话类型",\n'
      '    "情感得分": "情感得分-1到1",\n'
      '    "解决状态": "解决状态",\n'
      '    "客户满意度": "客户满意度",\n'
      '    "情绪标签": ["情绪标签"],\n'
      '    "冲突等级": "低/中/高",\n'
      '    "风险等级": "低/中/高",\n'
      '    "是否需要跟进": "true/false",\n'
      '    "是否需要升级": "true/false"\n'
      '  }\n'
      '}\n'
      r'```'
      '\n\n注意：\n'
      '1. 所有 JSON 键名必须使用中文，如"基础信息"、"客户画像"、"情绪分析"等\n'
      '2. 如果对话不是反馈/投诉类，问题反馈部分可以简化，但必须包含基本字段\n'
      '3. 情绪节点最多列出3-5个关键时刻\n'
      '4. 所有评分要客观公正，基于对话内容判断\n'
      '5. 返回必须是合法的JSON格式，不要有注释';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  /// 执行对话分析
  ///
  /// [transcription] - 转写后的完整对话文本
  /// [taskId] - 任务ID，用于日志追踪
  Future<ConversationAnalysis> analyze({
    required String transcription,
    required String taskId,
  }) async {
    await LoggerService.instance.info(
      'Starting conversation analysis',
      taskId: taskId,
      fields: {'text_length': transcription.length},
    );

    try {
      // 获取配置
      final config = await ConfigService().loadConfig();
      final providerConfig = _resolveAnalysisProviderConfig(config);

      // 准备提示词（使用配置的提示词或默认提示词）
      final promptTemplate = config.prompts.conversationAnalysis.isNotEmpty
          ? config.prompts.conversationAnalysis
          : _defaultPromptTemplate;
      final prompt = promptTemplate.replaceAll(
        '{transcription}',
        transcription,
      );

      // 调用大模型
      final result = await _callLLM(
        prompt: prompt,
        providerConfig: providerConfig,
        taskId: taskId,
      );

      // 解析结果
      final analysis = _parseAnalysisResult(result, taskId);

      await LoggerService.instance.info(
        'Conversation analysis completed',
        taskId: taskId,
        fields: {
          'conversation_type': analysis.info.type,
          'sentiment_score': analysis.structured.sentimentScore,
          'risk_level': analysis.structured.riskLevel,
        },
      );

      return analysis;
    } catch (e, st) {
      await LoggerService.instance.error(
        'Conversation analysis failed',
        taskId: taskId,
        error: e,
        stackTrace: st,
      );
      throw Exception('对话分析失败: $e');
    }
  }

  /// 调用大模型API
  Future<Map<String, dynamic>> _callLLM({
    required String prompt,
    required Map<String, dynamic> providerConfig,
    required String taskId,
  }) async {
    final provider = providerConfig['provider'] as String? ?? 'local';

    if (provider == 'local') {
      // 本地模式：调用 NativeService
      return await _callLocalLLM(prompt, providerConfig, taskId);
    } else {
      // 云端模式：直接调用API
      return await _callCloudLLM(prompt, providerConfig, taskId);
    }
  }

  /// 调用本地LLM
  Future<Map<String, dynamic>> _callLocalLLM(
    String prompt,
    Map<String, dynamic> config,
    String taskId,
  ) async {
    // 使用 summarize 端点作为通用LLM调用
    // 实际项目中可能需要添加专门的 analysis 端点
    final response = await _dio.post(
      'http://127.0.0.1:8765/summarize',
      data: {
        'text': prompt,
        'length': 'long',
        'provider': 'local',
        'task_id': taskId,
        'provider_config': config,
      },
    );

    final data = response.data as Map<String, dynamic>;

    // 从摘要结果中提取JSON
    final summary = data['long']?.toString() ??
        data['medium']?.toString() ??
        data['short']?.toString() ??
        data['summary']?.toString() ??
        '';

    return _extractJsonFromText(summary);
  }

  /// 调用云端LLM
  Future<Map<String, dynamic>> _callCloudLLM(
    String prompt,
    Map<String, dynamic> config,
    String taskId,
  ) async {
    final apiKey = config['api_key']?.toString() ?? '';
    final apiUrl = config['api_url']?.toString() ?? '';
    final model = config['model']?.toString() ?? 'gpt-4';

    if (apiKey.isEmpty || apiUrl.isEmpty) {
      throw Exception('API Key 或 API URL 未配置');
    }

    // 根据不同提供商构建请求
    final provider = config['provider']?.toString() ?? '';

    if (provider == 'qwen') {
      return await _callQwenAPI(prompt, apiKey, apiUrl, model, taskId);
    } else if (provider == 'openai' || provider == 'azure') {
      return await _callOpenAIAPI(prompt, apiKey, apiUrl, model, taskId);
    } else {
      throw Exception('不支持的提供商: $provider');
    }
  }

  /// 调用通义千问API
  Future<Map<String, dynamic>> _callQwenAPI(
    String prompt,
    String apiKey,
    String apiUrl,
    String model,
    String taskId,
  ) async {
    final response = await _dio.post(
      '${apiUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': '你是一个专业的客服对话分析专家，擅长分析客服-客户对话内容，提取关键信息。'
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 4096,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final content = response.data['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _extractJsonFromText(content);
  }

  /// 调用OpenAI风格API
  Future<Map<String, dynamic>> _callOpenAIAPI(
    String prompt,
    String apiKey,
    String apiUrl,
    String model,
    String taskId,
  ) async {
    final response = await _dio.post(
      '${apiUrl.replaceAll(RegExp(r'/$'), '')}/chat/completions',
      data: {
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a professional customer service conversation analyst.'
          },
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.3,
        'max_tokens': 4096,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final content = response.data['choices']?[0]?['message']?['content']?.toString() ?? '';
    return _extractJsonFromText(content);
  }

  /// 从文本中提取JSON
  Map<String, dynamic> _extractJsonFromText(String text) {
    // 尝试直接解析
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // 尝试从代码块中提取
      final codeBlockPattern = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
      final matches = codeBlockPattern.allMatches(text);
      for (final match in matches) {
        final jsonText = match.group(1)?.trim() ?? '';
        try {
          return jsonDecode(jsonText) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }
      }

      // 尝试查找JSON对象边界
      final jsonPattern = RegExp(r'\{[\s\S]*\}');
      final jsonMatch = jsonPattern.firstMatch(text);
      if (jsonMatch != null) {
        try {
          return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
        } catch (_) {}
      }

      throw Exception('无法从响应中提取有效的JSON: $text');
    }
  }

  /// 解析分析结果
  ConversationAnalysis _parseAnalysisResult(
    Map<String, dynamic> result,
    String taskId,
  ) {
    try {
      return ConversationAnalysis.fromApiResponse(
        DateTime.now().millisecondsSinceEpoch.toString(),
        taskId,
        result,
      );
    } catch (e) {
      throw Exception('解析分析结果失败: $e');
    }
  }

  /// 规范化结果，确保所有必需字段存在
  Map<String, dynamic> _normalizeResult(Map<String, dynamic> result) {
    return {
      'info': result['info'] ?? {},
      'customer_profile': result['customer_profile'] ?? {},
      'emotion_analysis': result['emotion_analysis'] ?? {},
      'feedback_analysis': result['feedback_analysis'],
      'quality': result['quality'] ?? {},
      'management': result['management'],
      'metrics': result['metrics'],
      'resolution': result['resolution'] ?? {},
      'insights': result['insights'] ?? {},
      'structured': result['structured'] ?? {},
    };
  }

  /// 获取分析服务配置
  Map<String, dynamic> _resolveAnalysisProviderConfig(AppConfig config) {
    // 优先使用摘要渠道配置
    final channels = config.summary.channels.where((c) => c.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    if (channels.isEmpty) {
      return {'provider': 'local'};
    }

    final selected = channels.first;
    return {
      'provider': selected.provider,
      'api_key': selected.config['api_key'],
      'api_url': selected.config['api_url'],
      'model': selected.config['model'],
    };
  }
}
