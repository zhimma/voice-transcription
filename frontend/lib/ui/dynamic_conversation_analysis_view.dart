import 'package:flutter/material.dart';
import 'dynamic_json_view.dart';

/// 对话分析结果动态渲染组件
/// 针对对话分析数据结构优化展示
class DynamicConversationAnalysisView extends StatefulWidget {
  final Map<String, dynamic> data;

  const DynamicConversationAnalysisView({super.key, required this.data});

  @override
  State<DynamicConversationAnalysisView> createState() =>
      _DynamicConversationAnalysisViewState();
}

class _DynamicConversationAnalysisViewState
    extends State<DynamicConversationAnalysisView> {
  late Map<String, Map<String, dynamic>> _groupedData;

  @override
  void initState() {
    super.initState();
    _groupedData = _groupAnalysisData(widget.data);
  }

  @override
  Widget build(BuildContext context) {
    // 过滤空值
    final summaryData = _filterEmptyValues(_groupedData['summary'] ?? {});
    final otherGroups = _groupedData.entries
        .where((e) => e.key != 'summary' && e.value.isNotEmpty)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部摘要卡片
          if (summaryData.isNotEmpty)
            _buildSummaryCards(summaryData),

          if (summaryData.isNotEmpty)
            const SizedBox(height: 24),

          // 分节展示
          ...otherGroups.asMap().entries.map((entry) {
            final index = entry.key;
            final groupEntry = entry.value;
            final isLast = index == otherGroups.length - 1;

            return Column(
              children: [
                _buildSection(
                  title: _getSectionTitle(groupEntry.key),
                  icon: _getSectionIcon(groupEntry.key),
                  data: _filterEmptyValues(groupEntry.value),
                ),
                if (!isLast) const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 过滤空值
  Map<String, dynamic> _filterEmptyValues(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      result[entry.key] = value;
    }
    return result;
  }

  Map<String, Map<String, dynamic>> _groupAnalysisData(
    Map<String, dynamic> data,
  ) {
    final groups = <String, Map<String, dynamic>>{
      'summary': {},
      'basic_info': {},
      'customer': {},
      'emotion': {},
      'quality': {},
      'resolution': {},
      'insights': {},
      'others': {},
    };

    // 定义字段分组规则（按key匹配）- 支持中文和英文key
    final groupRules = {
      'summary': [
        '对话类型',
        '情感得分',
        'sentiment_score',
        '风险等级',
        'risk_level',
        '状态',
        'status',
        '满意度',
        'satisfaction',
        '时长',
        'duration',
        '对话时长',
      ],
      'basic_info': [
        '基础信息',
        'info',
        '场景',
        'scenario',
        '业务标签',
        'business_tag',
        '发言次数',
        'turns',
        '客户发言次数',
        'customer_turns',
        '客服发言次数',
        'agent_turns',
        '消息数',
        'messages',
        '总消息数',
        'total_messages',
        '响应时间',
        'response_time',
      ],
      'customer': [
        '客户',
        'customer',
        '客户画像',
        'customer_profile',
        '画像',
        'profile',
        '人设',
        'persona',
        '需求',
        'demand',
        'needs',
        'demands',
      ],
      'emotion': [
        '情绪',
        'emotion',
        '情感',
        'sentiment',
        '心情',
        'mood',
        '感受',
        'feeling',
        '情绪分析',
        'emotion_analysis',
      ],
      'quality': [
        '服务质量',
        'quality',
        '服务',
        'service',
        '表现',
        'performance',
        '评分',
        'rating',
        '得分',
        'score',
        '评估',
        'evaluation',
      ],
      'resolution': [
        '解决情况',
        'resolution',
        '解决方案',
        'solution',
        '已解决',
        'solved',
        '解决状态',
        'resolution_status',
        '跟进',
        'follow_up',
        '升级',
        'escalation',
      ],
      'insights': [
        '洞察',
        'insights',
        '发现',
        'findings',
        '建议',
        'suggestions',
        '推荐',
        'recommendations',
        'advice',
        '提示',
        'tips',
      ],
    };

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // 跳过空值
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;

      // 检查是否是嵌套对象（如 基础信息, 客户画像 等）
      if (value is Map<String, dynamic>) {
        // 根据key名直接分配到对应分组（支持中文和英文）
        if (key == 'info' || key == '基础信息' || key.contains('basic')) {
          groups['basic_info']![entry.key] = value;
        } else if (key.contains('customer') || key.contains('profile') ||
                   key == '客户画像' || key == '客户') {
          groups['customer']![entry.key] = value;
        } else if (key.contains('emotion') || key == '情绪分析' || key == '情绪') {
          groups['emotion']![entry.key] = value;
        } else if (key.contains('quality') || key == '服务质量' || key == '服务') {
          groups['quality']![entry.key] = value;
        } else if (key.contains('resolution') || key == '解决情况' || key == '解决') {
          groups['resolution']![entry.key] = value;
        } else if (key.contains('feedback') || key == '问题反馈' || key == '反馈') {
          groups['quality']![entry.key] = value; // 问题反馈合并到质量
        } else if (key.contains('insight') || key.contains('structured') ||
                   key == '综合评估' || key == '洞察') {
          groups['insights']![entry.key] = value;
        } else if (key.contains('management') || key.contains('metric') ||
                   key == '管理指标') {
          groups['summary']![entry.key] = value; // 管理指标合并到摘要
        } else {
          groups['others']![entry.key] = value;
        }
        continue;
      }

      // 根据key匹配规则分组
      var assigned = false;
      for (final rule in groupRules.entries) {
        if (rule.value.any((r) => key.contains(r.toLowerCase()))) {
          groups[rule.key]![entry.key] = value;
          assigned = true;
          break;
        }
      }

      if (!assigned) {
        groups['others']![entry.key] = value;
      }
    }

    // 移除空分组
    return groups..removeWhere((_, value) => value.isEmpty);
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    // 转换为卡片数据
    final cardItems = data.entries
        .where((e) => e.value != null)
        .map((e) => _MetricCardItem(
              label: _formatKey(e.key),
              value: e.value.toString(),
            ))
        .toList();

    if (cardItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关键指标',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cardItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = cardItems[index];
              return _MetricCard(
                label: item.label,
                value: item.value,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Map<String, dynamic> data,
  }) {
    if (data.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[600], size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: DynamicJsonView(
                data: data,
                initialDepth: 0,
                showCopyButton: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSectionTitle(String key) {
    final titles = {
      'summary': '核心指标',
      'basic_info': '基础信息',
      'customer': '客户画像',
      'emotion': '情绪分析',
      'quality': '服务质量',
      'resolution': '解决情况',
      'insights': '洞察建议',
      'others': '其他信息',
    };
    return titles[key] ?? key;
  }

  IconData _getSectionIcon(String key) {
    final icons = {
      'summary': Icons.analytics,
      'basic_info': Icons.info_outline,
      'customer': Icons.person_outline,
      'emotion': Icons.sentiment_satisfied_outlined,
      'quality': Icons.grade_outlined,
      'resolution': Icons.check_circle_outline,
      'insights': Icons.lightbulb_outline,
      'others': Icons.more_horiz,
    };
    return icons[key] ?? Icons.folder_outlined;
  }

  String _formatKey(String key) {
    // 将snake_case转换为可读的中文label
    final keyMap = {
      // 核心指标
      'type': '对话类型',
      'sentiment_score': '情感得分',
      'sentimentScore': '情感得分',
      'risk_level': '风险等级',
      'riskLevel': '风险等级',
      'status': '状态',
      'satisfaction': '满意度',
      'satisfaction_level': '满意度',
      'satisfactionLevel': '满意度',
      'duration': '时长',
      'duration_minutes': '时长(分钟)',
      'durationMinutes': '时长(分钟)',
      // 基础信息
      'info': '基础信息',
      'scenario': '场景',
      'business_tag': '业务标签',
      'businessTag': '业务标签',
      'turns': '发言次数',
      'customer_turns': '客户发言',
      'customerTurns': '客户发言',
      'agent_turns': '客服发言',
      'agentTurns': '客服发言',
      'messages': '消息数',
      'total_messages': '总消息数',
      'totalMessages': '总消息数',
      'response_time': '响应时间',
      'responseTime': '响应时间',
      // 客户画像
      'customer': '客户信息',
      'customer_profile': '客户画像',
      'customerProfile': '客户画像',
      'profile': '画像',
      'persona': '人设',
      'customer_type': '客户类型',
      'customerType': '客户类型',
      'demand': '需求',
      'needs': '需求',
      'demands': '需求',
      // 情绪分析
      'emotion': '情绪',
      'sentiment': '情感',
      'mood': '心情',
      'feeling': '感受',
      'emotion_analysis': '情绪分析',
      'emotionAnalysis': '情绪分析',
      'overall_emotion': '整体情绪',
      'overallEmotion': '整体情绪',
      'initial_emotion': '初始情绪',
      'initialEmotion': '初始情绪',
      'final_emotion': '结束情绪',
      'finalEmotion': '结束情绪',
      'emotion_trend': '情绪趋势',
      'emotionTrend': '情绪趋势',
      'emotion_intensity': '情绪强度',
      'emotionIntensity': '情绪强度',
      // 服务质量
      'quality': '服务质量',
      'service': '服务',
      'performance': '表现',
      'rating': '评分',
      'score': '得分',
      'evaluation': '评估',
      'overall_rating': '整体评级',
      'overallRating': '整体评级',
      // 解决情况
      'resolution': '解决情况',
      'solution': '解决方案',
      'solved': '已解决',
      'resolution_status': '解决状态',
      'resolutionStatus': '解决状态',
      'follow_up': '跟进',
      'followUp': '跟进',
      'escalation': '升级',
      'escalation_needed': '需要升级',
      'escalationNeeded': '需要升级',
      // 洞察建议
      'insights': '洞察',
      'findings': '发现',
      'suggestions': '建议',
      'recommendations': '推荐',
      'advice': '建议',
      'tips': '提示',
    };

    return keyMap[key] ?? _camelCaseToWords(key);
  }

  String _camelCaseToWords(String input) {
    var result = input.replaceAll('_', ' ');
    result = result.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    if (result.isEmpty) return input;
    return result[0].toUpperCase() + result.substring(1);
  }
}

class _MetricCardItem {
  final String label;
  final String value;

  const _MetricCardItem({required this.label, required this.value});
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value.length > 15 ? '${value.substring(0, 15)}...' : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
