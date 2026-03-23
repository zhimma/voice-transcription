/// 客服对话分析结果模型
/// 用于存储客服-客户对话的深度分析结果

/// 解析布尔值，支持 bool 和 String 类型（"true"/"false"）
bool? _parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is String) {
    return value.toLowerCase() == 'true';
  }
  return null;
}

class ConversationAnalysis {
  final String id;
  final String taskId;

  // 基础信息（保留强类型字段用于向后兼容）
  final ConversationInfo info;

  // 客户画像
  final CustomerProfile customerProfile;

  // 情绪分析
  final EmotionAnalysis emotionAnalysis;

  // 问题反馈分析（如果是反馈类对话）
  final FeedbackAnalysis? feedbackAnalysis;

  // 对话质量评估
  final ConversationQuality quality;

  // 管理指标（新增）
  final ManagementMetrics? management;

  // 综合评分（新增）
  final ComprehensiveMetrics? metrics;

  // 解决情况
  final ResolutionStatus resolution;

  // 洞察建议
  final Insights insights;

  // 结构化数据
  final StructuredData structured;

  // 分析时间
  final DateTime createdAt;

  // 新增：存储原始JSON数据，用于动态渲染
  final Map<String, dynamic> rawData;

  const ConversationAnalysis({
    required this.id,
    required this.taskId,
    required this.info,
    required this.customerProfile,
    required this.emotionAnalysis,
    this.feedbackAnalysis,
    required this.quality,
    this.management,
    this.metrics,
    required this.resolution,
    required this.insights,
    required this.structured,
    required this.createdAt,
    this.rawData = const {},
  });

  /// 从API响应创建ConversationAnalysis
  /// 同时解析强类型字段和保存原始数据
  factory ConversationAnalysis.fromApiResponse(
    String id,
    String taskId,
    Map<String, dynamic> response,
  ) {
    // 尝试解析为强类型（向后兼容）
    ConversationInfo? info;
    CustomerProfile? customerProfile;
    EmotionAnalysis? emotionAnalysis;
    FeedbackAnalysis? feedbackAnalysis;
    ConversationQuality? quality;
    ManagementMetrics? management;
    ComprehensiveMetrics? metrics;
    ResolutionStatus? resolution;
    Insights? insights;
    StructuredData? structured;

    try {
      final normalizedResult = _normalizeResult(response);
      info = ConversationInfo.fromJson(
        Map<String, dynamic>.from(normalizedResult['info'] as Map? ?? {}),
      );
      customerProfile = CustomerProfile.fromJson(
        Map<String, dynamic>.from(
          normalizedResult['customer_profile'] as Map? ?? {},
        ),
      );
      emotionAnalysis = EmotionAnalysis.fromJson(
        Map<String, dynamic>.from(
          normalizedResult['emotion_analysis'] as Map? ?? {},
        ),
      );
      feedbackAnalysis =
          normalizedResult['feedback_analysis'] != null
              ? FeedbackAnalysis.fromJson(
                Map<String, dynamic>.from(
                  normalizedResult['feedback_analysis']! as Map,
                ),
              )
              : null;
      quality = ConversationQuality.fromJson(
        Map<String, dynamic>.from(normalizedResult['quality'] as Map? ?? {}),
      );
      management =
          normalizedResult['management'] != null
              ? ManagementMetrics.fromJson(
                Map<String, dynamic>.from(
                  normalizedResult['management']! as Map,
                ),
              )
              : null;
      metrics =
          normalizedResult['metrics'] != null
              ? ComprehensiveMetrics.fromJson(
                Map<String, dynamic>.from(normalizedResult['metrics']! as Map),
              )
              : null;
      resolution = ResolutionStatus.fromJson(
        Map<String, dynamic>.from(normalizedResult['resolution'] as Map? ?? {}),
      );
      insights = Insights.fromJson(
        Map<String, dynamic>.from(normalizedResult['insights'] as Map? ?? {}),
      );
      structured = StructuredData.fromJson(
        Map<String, dynamic>.from(normalizedResult['structured'] as Map? ?? {}),
      );
    } catch (e) {
      // 解析失败不阻断，使用空对象，rawData仍然可用
      info = null;
      customerProfile = null;
      emotionAnalysis = null;
      feedbackAnalysis = null;
      quality = null;
      management = null;
      metrics = null;
      resolution = null;
      insights = null;
      structured = null;
    }

    return ConversationAnalysis(
      id: id,
      taskId: taskId,
      info: info ??
          ConversationInfo(
            type: '',
            businessTag: '',
            durationMinutes: 0,
            customerTurns: 0,
            agentTurns: 0,
          ),
      customerProfile: customerProfile ??
          CustomerProfile(
            customerType: '',
            tags: const [],
            consumptionFeature: '',
            historyRelation: '',
            coreDemand: '',
            explicitNeeds: const [],
            implicitNeeds: const [],
            expectedSolution: '',
          ),
      emotionAnalysis: emotionAnalysis ??
          EmotionAnalysis(
            initialEmotion: '',
            peakEmotion: '',
            finalEmotion: '',
            emotionTrend: '',
            emotionIntensity: 0,
            keyTriggers: const [],
            emotionNodes: const [],
          ),
      feedbackAnalysis: feedbackAnalysis,
      quality: quality ??
          ConversationQuality(
            overallTone: '',
            customerAttitude: '',
            agentAttitude: '',
            agentEmotionState: '',
            nature: '',
            intensity: const IntensityRating(
              conflictLevel: 0,
              emotionIntensity: 0,
              languageIntensity: 0,
              tensionLevel: 0,
              overallRating: '',
            ),
            positivePoints: const [],
            positiveMoments: const [],
            negativeMoments: const [],
            conflictMoments: const [],
            improvementAreas: const [],
          ),
      management: management,
      metrics: metrics,
      resolution: resolution ??
          ResolutionStatus(
            status: '',
            customerSatisfied: false,
            satisfactionLevel: '',
            secondaryIssue: false,
            unresolvedIssues: const [],
            summary: '',
          ),
      insights: insights ??
          const Insights(
            keyFindings: [],
            riskSignals: [],
            opportunities: [],
            suggestions: [],
            followUpRequired: false,
            followUpActions: [],
            escalationNeeded: false,
            escalationReason: '',
            alertFlags: [],
          ),
      structured: structured ??
          StructuredData(
            conversationType: '',
            sentimentScore: 0,
            resolutionStatus: '',
            customerSatisfaction: '',
            emotionTags: const [],
            conflictLevel: '',
            riskLevel: '',
            followUpRequired: false,
            escalationNeeded: false,
          ),
      rawData: Map<String, dynamic>.from(response),
      createdAt: DateTime.now(),
    );
  }

  /// 规范化结果，确保所有必需字段存在
  static Map<String, dynamic> _normalizeResult(Map<String, dynamic> result) {
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'info': info.toJson(),
      'customer_profile': customerProfile.toJson(),
      'emotion_analysis': emotionAnalysis.toJson(),
      'feedback_analysis': feedbackAnalysis?.toJson(),
      'quality': quality.toJson(),
      'management': management?.toJson(),
      'metrics': metrics?.toJson(),
      'resolution': resolution.toJson(),
      'insights': insights.toJson(),
      'structured': structured.toJson(),
      'raw_data': rawData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ConversationAnalysis.fromJson(Map<String, dynamic> json) {
    return ConversationAnalysis(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      info: ConversationInfo.fromJson(
        Map<String, dynamic>.from(json['info'] as Map? ?? {}),
      ),
      customerProfile: CustomerProfile.fromJson(
        Map<String, dynamic>.from(json['customer_profile'] as Map? ?? {}),
      ),
      emotionAnalysis: EmotionAnalysis.fromJson(
        Map<String, dynamic>.from(json['emotion_analysis'] as Map? ?? {}),
      ),
      feedbackAnalysis: json['feedback_analysis'] != null
          ? FeedbackAnalysis.fromJson(
              Map<String, dynamic>.from(json['feedback_analysis'] as Map),
            )
          : null,
      quality: ConversationQuality.fromJson(
        Map<String, dynamic>.from(json['quality'] as Map? ?? {}),
      ),
      management: json['management'] != null
          ? ManagementMetrics.fromJson(
              Map<String, dynamic>.from(json['management'] as Map),
            )
          : null,
      metrics: json['metrics'] != null
          ? ComprehensiveMetrics.fromJson(
              Map<String, dynamic>.from(json['metrics'] as Map),
            )
          : null,
      resolution: ResolutionStatus.fromJson(
        Map<String, dynamic>.from(json['resolution'] as Map? ?? {}),
      ),
      insights: Insights.fromJson(
        Map<String, dynamic>.from(json['insights'] as Map? ?? {}),
      ),
      structured: StructuredData.fromJson(
        Map<String, dynamic>.from(json['structured'] as Map? ?? {}),
      ),
      rawData: json['raw_data'] != null
          ? Map<String, dynamic>.from(json['raw_data'] as Map)
          : {},
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

/// 对话基础信息
class ConversationInfo {
  final String type; // 咨询/投诉/售后/售前/技术支持/账单疑问/其他
  final String? scenario; // 场景描述（提示词中有，模型新增）
  final String? summary; // 一句话摘要（提示词中有，模型新增）
  final String businessTag; // 业务标签
  final int durationMinutes; // 对话时长（分钟）
  final int customerTurns; // 客户发言次数
  final int agentTurns; // 客服发言次数
  final int? totalMessages; // 总消息数（提示词中有，模型新增）
  final int? avgResponseTimeSeconds; // 平均响应时间（提示词中有，模型新增）
  final int? firstResponseTimeSeconds; // 首次响应时间（提示词中有，模型新增）

  const ConversationInfo({
    required this.type,
    this.scenario,
    this.summary,
    required this.businessTag,
    required this.durationMinutes,
    required this.customerTurns,
    required this.agentTurns,
    this.totalMessages,
    this.avgResponseTimeSeconds,
    this.firstResponseTimeSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'scenario': scenario,
      'summary': summary,
      'business_tag': businessTag,
      'duration_minutes': durationMinutes,
      'customer_turns': customerTurns,
      'agent_turns': agentTurns,
      'total_messages': totalMessages,
      'avg_response_time_seconds': avgResponseTimeSeconds,
      'first_response_time_seconds': firstResponseTimeSeconds,
    };
  }

  factory ConversationInfo.fromJson(Map<String, dynamic> json) {
    return ConversationInfo(
      type: json['type']?.toString() ?? '未知',
      scenario: json['scenario']?.toString(),
      summary: json['summary']?.toString(),
      businessTag: json['business_tag']?.toString() ?? '其他',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      customerTurns: (json['customer_turns'] as num?)?.toInt() ?? 0,
      agentTurns: (json['agent_turns'] as num?)?.toInt() ?? 0,
      totalMessages: (json['total_messages'] as num?)?.toInt(),
      avgResponseTimeSeconds: (json['avg_response_time_seconds'] as num?)?.toInt(),
      firstResponseTimeSeconds: (json['first_response_time_seconds'] as num?)?.toInt(),
    );
  }
}

/// 客户画像
class CustomerProfile {
  final String? customerId; // 客户ID（提示词中有）
  final String? customerName; // 客户姓名（提示词中有）
  final String? contactInfo; // 联系方式（提示词中有）
  final String customerType; // 新客/老客户/VIP/潜在高价值客户
  final String? accountInfo; // 账号相关信息（提示词中有）
  final String? membershipLevel; // 会员等级（提示词中有）
  final String? purchaseHistory; // 购买历史（提示词中有）
  final String? lifetimeValue; // 客户生命周期价值：高/中/低（提示词中有）
  final String? churnRisk; // 流失风险：高/中/低（提示词中有）
  final List<String> tags; // 画像标签
  final String consumptionFeature; // 消费特征
  final String historyRelation; // 历史关系
  final String coreDemand; // 核心诉求
  final List<String> explicitNeeds; // 显性需求
  final List<String> implicitNeeds; // 隐性需求
  final String expectedSolution; // 期望解决方案

  const CustomerProfile({
    this.customerId,
    this.customerName,
    this.contactInfo,
    required this.customerType,
    this.accountInfo,
    this.membershipLevel,
    this.purchaseHistory,
    this.lifetimeValue,
    this.churnRisk,
    required this.tags,
    required this.consumptionFeature,
    required this.historyRelation,
    required this.coreDemand,
    required this.explicitNeeds,
    required this.implicitNeeds,
    required this.expectedSolution,
  });

  Map<String, dynamic> toJson() {
    return {
      'customer_id': customerId,
      'customer_name': customerName,
      'contact_info': contactInfo,
      'customer_type': customerType,
      'account_info': accountInfo,
      'membership_level': membershipLevel,
      'purchase_history': purchaseHistory,
      'lifetime_value': lifetimeValue,
      'churn_risk': churnRisk,
      'tags': tags,
      'consumption_feature': consumptionFeature,
      'history_relation': historyRelation,
      'core_demand': coreDemand,
      'explicit_needs': explicitNeeds,
      'implicit_needs': implicitNeeds,
      'expected_solution': expectedSolution,
    };
  }

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      customerId: json['customer_id']?.toString(),
      customerName: json['customer_name']?.toString(),
      contactInfo: json['contact_info']?.toString(),
      customerType: json['customer_type']?.toString() ?? '未知',
      accountInfo: json['account_info']?.toString(),
      membershipLevel: json['membership_level']?.toString(),
      purchaseHistory: json['purchase_history']?.toString(),
      lifetimeValue: json['lifetime_value']?.toString(),
      churnRisk: json['churn_risk']?.toString(),
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      consumptionFeature: json['consumption_feature']?.toString() ?? '',
      historyRelation: json['history_relation']?.toString() ?? '',
      coreDemand: json['core_demand']?.toString() ?? '',
      explicitNeeds:
          (json['explicit_needs'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      implicitNeeds:
          (json['implicit_needs'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      expectedSolution: json['expected_solution']?.toString() ?? '',
    );
  }
}

/// 情绪分析
class EmotionAnalysis {
  final String? overallEmotion; // 整体对话情绪：平和/友好/紧张/激烈/对抗
  final String initialEmotion; // 客户初始情绪
  final String peakEmotion; // 客户峰值情绪
  final String finalEmotion; // 客户结束情绪
  final String emotionTrend; // 客户情绪趋势：上升/下降/波动/平稳
  final int emotionIntensity; // 客户情绪强度 1-10
  final String? agentEmotion; // 客服情绪状态：平和/耐心/急躁/专业/疲惫
  final List<String> keyTriggers; // 触发客户情绪变化的关键点
  final List<EmotionNode> emotionNodes; // 关键情绪节点

  const EmotionAnalysis({
    this.overallEmotion,
    required this.initialEmotion,
    required this.peakEmotion,
    required this.finalEmotion,
    required this.emotionTrend,
    required this.emotionIntensity,
    this.agentEmotion,
    required this.keyTriggers,
    required this.emotionNodes,
  });

  Map<String, dynamic> toJson() {
    return {
      'overall_emotion': overallEmotion,
      'initial_emotion': initialEmotion,
      'peak_emotion': peakEmotion,
      'final_emotion': finalEmotion,
      'emotion_trend': emotionTrend,
      'emotion_intensity': emotionIntensity,
      'agent_emotion': agentEmotion,
      'key_triggers': keyTriggers,
      'emotion_nodes': emotionNodes.map((e) => e.toJson()).toList(),
    };
  }

  factory EmotionAnalysis.fromJson(Map<String, dynamic> json) {
    return EmotionAnalysis(
      overallEmotion: json['overall_emotion']?.toString(),
      initialEmotion: json['initial_emotion']?.toString() ?? '平和',
      peakEmotion: json['peak_emotion']?.toString() ?? '平和',
      finalEmotion: json['final_emotion']?.toString() ?? '平和',
      emotionTrend: json['emotion_trend']?.toString() ?? '平稳',
      emotionIntensity: (json['emotion_intensity'] as num?)?.toInt() ??
          (json['intensity'] as num?)?.toInt() ?? 5,
      agentEmotion: json['agent_emotion']?.toString(),
      keyTriggers: (json['key_triggers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      emotionNodes: (json['emotion_nodes'] as List?)
              ?.map((e) => EmotionNode.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }
}

/// 情绪节点
class EmotionNode {
  final String round; // 第几轮对话
  final String trigger; // 触发事件
  final String customerEmotion; // 客户情绪
  final String agentResponse; // 客服应对

  const EmotionNode({
    required this.round,
    required this.trigger,
    required this.customerEmotion,
    required this.agentResponse,
  });

  Map<String, dynamic> toJson() {
    return {
      'round': round,
      'trigger': trigger,
      'customer_emotion': customerEmotion,
      'agent_response': agentResponse,
    };
  }

  factory EmotionNode.fromJson(Map<String, dynamic> json) {
    return EmotionNode(
      round: json['round']?.toString() ?? '',
      trigger: json['trigger']?.toString() ?? '',
      customerEmotion: json['customer_emotion']?.toString() ?? '',
      agentResponse: json['agent_response']?.toString() ?? '',
    );
  }
}

/// 问题反馈分析
class FeedbackAnalysis {
  final bool hasIssue; // 是否遇到问题（提示词中有）
  final String issueAbstract; // 问题摘要（提示词中有）
  final Category? category; // 问题分类 l1/l2/l3（提示词中有）
  final String? urgency; // 紧急程度（提示词中有）
  final List<String> expectations; // 客户期望（提示词中有）
  final List<String> painPoints; // 痛点（提示词中有）
  final List<String> mentionedProducts; // 提及的产品（提示词中有）
  final List<String> mentionedServices; // 提及的服务（提示词中有）
  // 保留原有字段以兼容旧数据
  final String summary;
  final String productService;
  final String occurrenceTime;
  final String frequency;
  final String impactScope;
  final ProblemType problemType;
  final Severity severity;
  final RootCause rootCause;
  final List<String> solutions;

  const FeedbackAnalysis({
    required this.hasIssue,
    required this.issueAbstract,
    this.category,
    this.urgency,
    required this.expectations,
    required this.painPoints,
    required this.mentionedProducts,
    required this.mentionedServices,
    required this.summary,
    required this.productService,
    required this.occurrenceTime,
    required this.frequency,
    required this.impactScope,
    required this.problemType,
    required this.severity,
    required this.rootCause,
    required this.solutions,
  });

  Map<String, dynamic> toJson() {
    return {
      'has_issue': hasIssue,
      'issue_abstract': issueAbstract,
      'category': category?.toJson(),
      'urgency': urgency,
      'expectations': expectations,
      'pain_points': painPoints,
      'mentioned_products': mentionedProducts,
      'mentioned_services': mentionedServices,
      'summary': summary,
      'product_service': productService,
      'occurrence_time': occurrenceTime,
      'frequency': frequency,
      'impact_scope': impactScope,
      'problem_type': problemType.toJson(),
      'severity': severity.toJson(),
      'root_cause': rootCause.toJson(),
      'solutions': solutions,
    };
  }

  factory FeedbackAnalysis.fromJson(Map<String, dynamic> json) {
    return FeedbackAnalysis(
      hasIssue: _parseBool(json['has_issue']) ?? false,
      issueAbstract: json['issue_abstract']?.toString() ??
          json['summary']?.toString() ??
          '',
      category: json['category'] != null
          ? Category.fromJson(Map<String, dynamic>.from(json['category'] as Map))
          : null,
      urgency: json['urgency']?.toString(),
      expectations: (json['expectations'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      painPoints: (json['pain_points'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mentionedProducts: (json['mentioned_products'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mentionedServices: (json['mentioned_services'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      summary: json['summary']?.toString() ?? '',
      productService: json['product_service']?.toString() ?? '',
      occurrenceTime: json['occurrence_time']?.toString() ?? '',
      frequency: json['frequency']?.toString() ?? '',
      impactScope: json['impact_scope']?.toString() ?? '',
      problemType: ProblemType.fromJson(
        Map<String, dynamic>.from(json['problem_type'] as Map? ?? {}),
      ),
      severity: Severity.fromJson(
        Map<String, dynamic>.from(json['severity'] as Map? ?? {}),
      ),
      rootCause: RootCause.fromJson(
        Map<String, dynamic>.from(json['root_cause'] as Map? ?? {}),
      ),
      solutions:
          (json['solutions'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 问题分类（提示词中的 category l1/l2/l3）
class Category {
  final String l1; // 一级分类
  final String l2; // 二级分类
  final String? l3; // 三级分类（可选）

  const Category({
    required this.l1,
    required this.l2,
    this.l3,
  });

  Map<String, dynamic> toJson() {
    return {
      'l1': l1,
      'l2': l2,
      'l3': l3,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      l1: json['l1']?.toString() ?? '其他',
      l2: json['l2']?.toString() ?? '其他',
      l3: json['l3']?.toString(),
    );
  }
}

/// 问题类型
class ProblemType {
  final String level1; // 一级分类：产品问题/服务问题/物流问题等
  final String level2; // 二级分类
  final List<String> tags; // 技术/业务标签

  const ProblemType({
    required this.level1,
    required this.level2,
    required this.tags,
  });

  Map<String, dynamic> toJson() {
    return {
      'level1': level1,
      'level2': level2,
      'tags': tags,
    };
  }

  factory ProblemType.fromJson(Map<String, dynamic> json) {
    return ProblemType(
      level1: json['level1'] as String? ?? '其他',
      level2: json['level2'] as String? ?? '其他',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 严重程度
class Severity {
  final String level; // P0-致命 / P1-严重 / P2-一般 / P3-轻微 / P4-建议
  final int score; // 1-5分
  final String reason; // 评级理由
  final String urgency; // 紧急程度

  const Severity({
    required this.level,
    required this.score,
    required this.reason,
    required this.urgency,
  });

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'score': score,
      'reason': reason,
      'urgency': urgency,
    };
  }

  factory Severity.fromJson(Map<String, dynamic> json) {
    return Severity(
      level: json['level'] as String? ?? 'P2-一般',
      score: json['score'] as int? ?? 3,
      reason: json['reason'] as String? ?? '',
      urgency: json['urgency'] as String? ?? '本周内',
    );
  }

  /// 获取严重程度的颜色
  String get color {
    switch (level) {
      case 'P0-致命':
        return '#DC2626'; // 红色
      case 'P1-严重':
        return '#EA580C'; // 橙色
      case 'P2-一般':
        return '#D97706'; // 黄色
      case 'P3-轻微':
        return '#059669'; // 绿色
      case 'P4-建议':
        return '#6B7280'; // 灰色
      default:
        return '#6B7280';
    }
  }
}

/// 根因分析
class RootCause {
  final String directCause; // 直接原因
  final String rootCause; // 可能根因
  final String triggerCondition; // 触发条件
  final String responsibility; // 责任归属

  const RootCause({
    required this.directCause,
    required this.rootCause,
    required this.triggerCondition,
    required this.responsibility,
  });

  Map<String, dynamic> toJson() {
    return {
      'direct_cause': directCause,
      'root_cause': rootCause,
      'trigger_condition': triggerCondition,
      'responsibility': responsibility,
    };
  }

  factory RootCause.fromJson(Map<String, dynamic> json) {
    return RootCause(
      directCause: json['direct_cause'] as String? ?? '',
      rootCause: json['root_cause'] as String? ?? '',
      triggerCondition: json['trigger_condition'] as String? ?? '',
      responsibility: json['responsibility'] as String? ?? '',
    );
  }
}

/// 对话质量评估
class ConversationQuality {
  final String? agentPerformance; // 客服整体表现：优秀/良好/一般/较差/很差
  final String? agentAttitude; // 客服服务态度：热情/友好/耐心/专业/冷淡/不耐烦
  final String? agentEmotionState; // 客服情绪状态：积极/平和/疲惫/急躁
  final String? responseTime; // 响应时间评价：及时/一般/较慢
  final int? professionalism; // 专业度评分 1-10
  final int? empathy; // 同理心评分 1-10
  final int? resolutionWillingness; // 解决意愿评分 1-10
  final int? productKnowledge; // 产品知识评分 1-10
  final int? serviceEfficiency; // 服务效率评分 1-10
  final String? attitude; // 服务态度（旧字段，兼容）
  final List<String> positivePoints; // 客服表现的优点
  final List<String> improvementAreas; // 客服需要改进的方面
  // 保留原有字段以兼容旧数据
  final String overallTone; // 整体基调
  final String customerAttitude; // 客户态度
  final String nature; // 对话性质
  final IntensityRating intensity; // 激烈程度评分
  final List<String> positiveMoments; // 正向/表扬 moments
  final List<String> negativeMoments; // 贬义/抱怨 moments
  final List<String> conflictMoments; // 激烈/冲突 moments

  const ConversationQuality({
    this.agentPerformance,
    this.agentAttitude,
    this.agentEmotionState,
    this.responseTime,
    this.professionalism,
    this.empathy,
    this.resolutionWillingness,
    this.productKnowledge,
    this.serviceEfficiency,
    this.attitude,
    required this.positivePoints,
    required this.improvementAreas,
    required this.overallTone,
    required this.customerAttitude,
    required this.nature,
    required this.intensity,
    required this.positiveMoments,
    required this.negativeMoments,
    required this.conflictMoments,
  });

  Map<String, dynamic> toJson() {
    return {
      'agent_performance': agentPerformance,
      'agent_attitude': agentAttitude,
      'agent_emotion_state': agentEmotionState,
      'response_time': responseTime,
      'professionalism': professionalism,
      'empathy': empathy,
      'resolution_willingness': resolutionWillingness,
      'product_knowledge': productKnowledge,
      'service_efficiency': serviceEfficiency,
      'attitude': attitude,
      'positive_points': positivePoints,
      'improvement_areas': improvementAreas,
      'overall_tone': overallTone,
      'customer_attitude': customerAttitude,
      'nature': nature,
      'intensity': intensity.toJson(),
      'positive_moments': positiveMoments,
      'negative_moments': negativeMoments,
      'conflict_moments': conflictMoments,
    };
  }

  factory ConversationQuality.fromJson(Map<String, dynamic> json) {
    return ConversationQuality(
      agentPerformance: json['agent_performance']?.toString(),
      agentAttitude: json['agent_attitude']?.toString(),
      agentEmotionState: json['agent_emotion_state']?.toString(),
      responseTime: json['response_time']?.toString(),
      professionalism: (json['professionalism'] as num?)?.toInt(),
      empathy: (json['empathy'] as num?)?.toInt(),
      resolutionWillingness: (json['resolution_willingness'] as num?)?.toInt(),
      productKnowledge: (json['product_knowledge'] as num?)?.toInt(),
      serviceEfficiency: (json['service_efficiency'] as num?)?.toInt(),
      attitude: json['attitude']?.toString(),
      positivePoints: (json['positive_points'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      improvementAreas: (json['improvement_areas'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      overallTone: json['overall_tone'] as String? ?? '中性',
      customerAttitude: json['customer_attitude'] as String? ?? '中立',
      nature: json['nature'] as String? ?? '正常咨询',
      intensity: IntensityRating.fromJson(
        Map<String, dynamic>.from(json['intensity'] as Map? ?? {}),
      ),
      positiveMoments:
          (json['positive_moments'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      negativeMoments:
          (json['negative_moments'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      conflictMoments:
          (json['conflict_moments'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }
}

/// 激烈程度评分
class IntensityRating {
  final int conflictLevel; // 冲突等级 1-5
  final int emotionIntensity; // 情绪强度 1-5
  final int languageIntensity; // 语言激烈度 1-5
  final int tensionLevel; // 对话紧张度 1-5
  final String overallRating; // A-平和 / B-轻微摩擦 / C-中度争执 / D-激烈冲突 / E-严重投诉

  const IntensityRating({
    required this.conflictLevel,
    required this.emotionIntensity,
    required this.languageIntensity,
    required this.tensionLevel,
    required this.overallRating,
  });

  Map<String, dynamic> toJson() {
    return {
      'conflict_level': conflictLevel,
      'emotion_intensity': emotionIntensity,
      'language_intensity': languageIntensity,
      'tension_level': tensionLevel,
      'overall_rating': overallRating,
    };
  }

  factory IntensityRating.fromJson(Map<String, dynamic> json) {
    return IntensityRating(
      conflictLevel: json['conflict_level'] as int? ?? 1,
      emotionIntensity: json['emotion_intensity'] as int? ?? 1,
      languageIntensity: json['language_intensity'] as int? ?? 1,
      tensionLevel: json['tension_level'] as int? ?? 1,
      overallRating: json['overall_rating'] as String? ?? 'A-平和',
    );
  }

  /// 计算平均分
  double get averageScore {
    return (conflictLevel + emotionIntensity + languageIntensity + tensionLevel) / 4;
  }

  /// 获取颜色
  String get color {
    switch (overallRating) {
      case 'A-平和':
        return '#059669';
      case 'B-轻微摩擦':
        return '#65A30D';
      case 'C-中度争执':
        return '#D97706';
      case 'D-激烈冲突':
        return '#EA580C';
      case 'E-严重投诉':
        return '#DC2626';
      default:
        return '#6B7280';
    }
  }
}

/// 解决情况
class ResolutionStatus {
  final String status; // 完全解决/部分解决/未解决/待跟进/升级处理
  final bool customerSatisfied; // 客户是否满意
  final String satisfactionLevel; // 满意/基本满意/不满意/未表态
  final bool secondaryIssue; // 是否产生二次问题
  final List<String> unresolvedIssues; // 未解决问题清单
  final String summary; // 解决情况摘要

  const ResolutionStatus({
    required this.status,
    required this.customerSatisfied,
    required this.satisfactionLevel,
    required this.secondaryIssue,
    required this.unresolvedIssues,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'customer_satisfied': customerSatisfied,
      'satisfaction_level': satisfactionLevel,
      'secondary_issue': secondaryIssue,
      'unresolved_issues': unresolvedIssues,
      'summary': summary,
    };
  }

  factory ResolutionStatus.fromJson(Map<String, dynamic> json) {
    return ResolutionStatus(
      status: json['status'] as String? ?? '待跟进',
      customerSatisfied: _parseBool(json['customer_satisfied']) ?? false,
      satisfactionLevel: json['satisfaction_level'] as String? ?? '未表态',
      secondaryIssue: _parseBool(json['secondary_issue']) ?? false,
      unresolvedIssues:
          (json['unresolved_issues'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      summary: json['summary'] as String? ?? '',
    );
  }
}

/// 管理指标（用于部门管理和运营决策）
class ManagementMetrics {
  final int firstContactResolution; // 首次解决率评分 1-10
  final int escalationNecessity; // 升级必要性评分 1-10
  final int complianceScore; // 合规遵循度评分 1-10
  final int customerRetentionRisk; // 客户留存风险评分 1-10
  final int complaintRisk; // 投诉风险评分 1-10
  final int salesOpportunity; // 销售机会评分 1-10
  final int serviceRecovery; // 服务补救评分 1-10
  final String followUpPriority; // 跟进优先级：高/中/低
  final List<String> trainingNeeds; // 培训需求
  final List<String> knowledgeGap; // 知识盲点

  const ManagementMetrics({
    required this.firstContactResolution,
    required this.escalationNecessity,
    required this.complianceScore,
    required this.customerRetentionRisk,
    required this.complaintRisk,
    required this.salesOpportunity,
    required this.serviceRecovery,
    required this.followUpPriority,
    required this.trainingNeeds,
    required this.knowledgeGap,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_contact_resolution': firstContactResolution,
      'escalation_necessity': escalationNecessity,
      'compliance_score': complianceScore,
      'customer_retention_risk': customerRetentionRisk,
      'complaint_risk': complaintRisk,
      'sales_opportunity': salesOpportunity,
      'service_recovery': serviceRecovery,
      'follow_up_priority': followUpPriority,
      'training_needs': trainingNeeds,
      'knowledge_gap': knowledgeGap,
    };
  }

  factory ManagementMetrics.fromJson(Map<String, dynamic> json) {
    return ManagementMetrics(
      firstContactResolution: (json['first_contact_resolution'] as num?)?.toInt() ?? 5,
      escalationNecessity: (json['escalation_necessity'] as num?)?.toInt() ?? 5,
      complianceScore: (json['compliance_score'] as num?)?.toInt() ?? 5,
      customerRetentionRisk: (json['customer_retention_risk'] as num?)?.toInt() ?? 5,
      complaintRisk: (json['complaint_risk'] as num?)?.toInt() ?? 5,
      salesOpportunity: (json['sales_opportunity'] as num?)?.toInt() ?? 5,
      serviceRecovery: (json['service_recovery'] as num?)?.toInt() ?? 5,
      followUpPriority: json['follow_up_priority'] as String? ?? '中',
      trainingNeeds: (json['training_needs'] as List?)?.map((e) => e.toString()).toList() ?? [],
      knowledgeGap: (json['knowledge_gap'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 综合评分指标
class ComprehensiveMetrics {
  final int agentEfficiencyScore; // 客服综合效率分 1-10
  final int customerExperienceScore; // 客户体验分 1-10
  final int conversationQualityScore; // 对话质量分 1-10
  final int businessImpactScore; // 业务影响分 1-10
  final int priorityScore; // 优先级综合评分 1-10

  const ComprehensiveMetrics({
    required this.agentEfficiencyScore,
    required this.customerExperienceScore,
    required this.conversationQualityScore,
    required this.businessImpactScore,
    required this.priorityScore,
  });

  Map<String, dynamic> toJson() {
    return {
      'agent_efficiency_score': agentEfficiencyScore,
      'customer_experience_score': customerExperienceScore,
      'conversation_quality_score': conversationQualityScore,
      'business_impact_score': businessImpactScore,
      'priority_score': priorityScore,
    };
  }

  factory ComprehensiveMetrics.fromJson(Map<String, dynamic> json) {
    return ComprehensiveMetrics(
      agentEfficiencyScore: (json['agent_efficiency_score'] as num?)?.toInt() ?? 5,
      customerExperienceScore: (json['customer_experience_score'] as num?)?.toInt() ?? 5,
      conversationQualityScore: (json['conversation_quality_score'] as num?)?.toInt() ?? 5,
      businessImpactScore: (json['business_impact_score'] as num?)?.toInt() ?? 5,
      priorityScore: (json['priority_score'] as num?)?.toInt() ?? 5,
    );
  }

  /// 计算平均分
  double get averageScore {
    return (agentEfficiencyScore + customerExperienceScore + conversationQualityScore + businessImpactScore + priorityScore) / 5;
  }
}

/// 洞察与建议
class Insights {
  final List<String> keyFindings; // 关键发现
  final List<String> riskSignals; // 风险信号
  final List<String> opportunities; // 机会点
  final List<String> suggestions; // 改进建议
  final bool followUpRequired; // 是否需要跟进
  final List<String> followUpActions; // 跟进行动
  final bool escalationNeeded; // 是否需要升级
  final String escalationReason; // 升级原因
  final List<String> alertFlags; // 预警标记

  const Insights({
    required this.keyFindings,
    required this.riskSignals,
    required this.opportunities,
    required this.suggestions,
    required this.followUpRequired,
    required this.followUpActions,
    required this.escalationNeeded,
    required this.escalationReason,
    required this.alertFlags,
  });

  Map<String, dynamic> toJson() {
    return {
      'key_findings': keyFindings,
      'risk_signals': riskSignals,
      'opportunities': opportunities,
      'suggestions': suggestions,
      'follow_up_required': followUpRequired,
      'follow_up_actions': followUpActions,
      'escalation_needed': escalationNeeded,
      'escalation_reason': escalationReason,
      'alert_flags': alertFlags,
    };
  }

  factory Insights.fromJson(Map<String, dynamic> json) {
    return Insights(
      keyFindings: (json['key_findings'] as List?)?.map((e) => e.toString()).toList() ?? [],
      riskSignals: (json['risk_signals'] as List?)?.map((e) => e.toString()).toList() ?? [],
      opportunities: (json['opportunities'] as List?)?.map((e) => e.toString()).toList() ?? [],
      suggestions: (json['suggestions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      followUpRequired: _parseBool(json['follow_up_required']) ?? false,
      followUpActions: (json['follow_up_actions'] as List?)?.map((e) => e.toString()).toList() ?? [],
      escalationNeeded: _parseBool(json['escalation_needed']) ?? false,
      escalationReason: json['escalation_reason'] as String? ?? '',
      alertFlags: (json['alert_flags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 结构化数据
class StructuredData {
  final String conversationType;
  final double sentimentScore; // -1 到 1
  final String resolutionStatus;
  final String customerSatisfaction;
  final List<String> emotionTags;
  final String conflictLevel;
  final String riskLevel;
  final bool followUpRequired;
  final bool escalationNeeded;

  const StructuredData({
    required this.conversationType,
    required this.sentimentScore,
    required this.resolutionStatus,
    required this.customerSatisfaction,
    required this.emotionTags,
    required this.conflictLevel,
    required this.riskLevel,
    required this.followUpRequired,
    required this.escalationNeeded,
  });

  Map<String, dynamic> toJson() {
    return {
      'conversation_type': conversationType,
      'sentiment_score': sentimentScore,
      'resolution_status': resolutionStatus,
      'customer_satisfaction': customerSatisfaction,
      'emotion_tags': emotionTags,
      'conflict_level': conflictLevel,
      'risk_level': riskLevel,
      'follow_up_required': followUpRequired,
      'escalation_needed': escalationNeeded,
    };
  }

  factory StructuredData.fromJson(Map<String, dynamic> json) {
    return StructuredData(
      conversationType: json['conversation_type'] as String? ?? '',
      sentimentScore: (json['sentiment_score'] as num?)?.toDouble() ?? 0.0,
      resolutionStatus: json['resolution_status'] as String? ?? '',
      customerSatisfaction: json['customer_satisfaction'] as String? ?? '',
      emotionTags:
          (json['emotion_tags'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      conflictLevel: json['conflict_level'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? '低',
      followUpRequired: _parseBool(json['follow_up_required']) ?? false,
      escalationNeeded: _parseBool(json['escalation_needed']) ?? false,
    );
  }
}
