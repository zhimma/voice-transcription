import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 动态JSON数据渲染组件
///
/// 递归渲染任意JSON结构，支持：
/// - 中文key作为label
/// - 嵌套Map/Array
/// - 不同类型值（字符串、数字、布尔、列表、对象）
class DynamicJsonView extends StatelessWidget {
  final Map<String, dynamic> data;
  final int initialDepth;
  final bool showCopyButton;
  final bool showEmptyValues;

  const DynamicJsonView({
    super.key,
    required this.data,
    this.initialDepth = 0,
    this.showCopyButton = true,
    this.showEmptyValues = false,
  });

  @override
  Widget build(BuildContext context) {
    // 过滤空值
    final filteredData = showEmptyValues
        ? data
        : _filterEmptyValues(data);

    if (filteredData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCopyButton) _buildCopyButton(filteredData),
        ..._buildEntries(filteredData, initialDepth),
      ],
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

  Widget _buildCopyButton(Map<String, dynamic> dataToCopy) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Clipboard.setData(ClipboardData(text: _formatForCopy(dataToCopy)));
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '复制全部内容',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries(Map<String, dynamic> map, int depth) {
    final entries = <Widget>[];

    for (final entry in map.entries) {
      final key = entry.key;
      final value = entry.value;

      // 跳过空值
      if (!_shouldShowValue(value)) continue;

      entries.add(_buildEntry(key, value, depth));
    }

    return entries;
  }

  bool _shouldShowValue(dynamic value) {
    if (showEmptyValues) return true;
    if (value == null) return false;
    if (value is String && value.isEmpty) return false;
    if (value is List && value.isEmpty) return false;
    if (value is Map && value.isEmpty) return false;
    return true;
  }

  Widget _buildEntry(String key, dynamic value, int depth) {
    // 根据值类型选择渲染方式
    if (value is Map<String, dynamic>) {
      return _buildObjectEntry(key, value, depth);
    } else if (value is List) {
      return _buildListEntry(key, value, depth);
    } else {
      return _buildPrimitiveEntry(key, value, depth);
    }
  }

  Widget _buildObjectEntry(String key, Map<String, dynamic> value, int depth) {
    final indent = depth * 16.0;

    // 过滤空值
    final filteredValue = showEmptyValues ? value : _filterEmptyValues(value);
    if (filteredValue.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 对象标题
          Container(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              children: [
                Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: Colors.blue[600],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatKey(key),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 递归渲染对象内容
          Container(
            margin: const EdgeInsets.only(left: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildEntries(filteredValue, depth + 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListEntry(String key, List<dynamic> value, int depth) {
    final indent = depth * 16.0;

    // 过滤掉空值
    final nonEmptyItems = value
        .where((item) => item != null && (item is! String || item.isNotEmpty))
        .toList();

    if (nonEmptyItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 列表标题
          Container(
            padding: EdgeInsets.only(left: indent),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  size: 16,
                  color: Colors.green[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${_formatKey(key)} (${nonEmptyItems.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 列表内容
          Container(
            margin: const EdgeInsets.only(left: 16),
            child: Column(
              children: nonEmptyItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2, right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(child: _buildListItem(item, depth + 1)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(dynamic value, int depth) {
    if (value is Map<String, dynamic>) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _buildEntries(value, depth),
      );
    } else {
      return Text(
        value.toString(),
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[700],
        ),
      );
    }
  }

  Widget _buildPrimitiveEntry(String key, dynamic value, int depth) {
    final indent = depth * 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.only(left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          SizedBox(
            width: 120,
            child: Text(
              _formatKey(key),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Value
          Expanded(
            child: _buildValueWidget(value),
          ),
        ],
      ),
    );
  }

  Widget _buildValueWidget(dynamic value) {
    // 根据值类型选择不同的展示样式
    final stringValue = value.toString();

    // 布尔值
    if (value is bool) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: value ? Colors.green[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          value ? '是' : '否',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: value ? Colors.green[700] : Colors.red[700],
          ),
        ),
      );
    }

    // 数字
    if (value is num) {
      return Text(
        stringValue,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.blue[700],
          fontFamily: 'JetBrains Mono',
        ),
      );
    }

    // 长文本
    if (stringValue.length > 100) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          stringValue,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.grey[800],
          ),
        ),
      );
    }

    // 普通文本
    return Text(
      stringValue,
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey[800],
      ),
    );
  }

  /// 格式化key为中文label
  String _formatKey(String key) {
    // 将snake_case转换为可读的中文label
    final keyMap = {
      // 摘要相关
      'short': '简要摘要',
      'medium': '标准摘要',
      'long': '详细摘要',
      'summary': '摘要',
      'key_points': '关键要点',
      'keyPoints': '关键要点',
      'keywords': '关键词',
      'tags': '标签',
      // 对话分析 - 基础信息
      'type': '类型',
      'info': '基础信息',
      'business_tag': '业务标签',
      'businessTag': '业务标签',
      'duration_minutes': '时长(分钟)',
      'durationMinutes': '时长(分钟)',
      'customer_turns': '客户发言次数',
      'customerTurns': '客户发言次数',
      'agent_turns': '客服发言次数',
      'agentTurns': '客服发言次数',
      'scenario': '场景',
      'summary': '摘要',
      // 客户画像
      'customer_profile': '客户画像',
      'customerProfile': '客户画像',
      'customer_type': '客户类型',
      'customerType': '客户类型',
      'tags': '标签',
      'consumption_feature': '消费特征',
      'consumptionFeature': '消费特征',
      'history_relation': '历史关系',
      'historyRelation': '历史关系',
      'core_demand': '核心诉求',
      'coreDemand': '核心诉求',
      'explicit_needs': '显性需求',
      'explicitNeeds': '显性需求',
      'implicit_needs': '隐性需求',
      'implicitNeeds': '隐性需求',
      'expected_solution': '期望方案',
      'expectedSolution': '期望方案',
      // 情绪分析
      'emotion_analysis': '情绪分析',
      'emotionAnalysis': '情绪分析',
      'overall_emotion': '整体情绪',
      'overallEmotion': '整体情绪',
      'initial_emotion': '初始情绪',
      'initialEmotion': '初始情绪',
      'peak_emotion': '峰值情绪',
      'peakEmotion': '峰值情绪',
      'final_emotion': '结束情绪',
      'finalEmotion': '结束情绪',
      'emotion_trend': '情绪趋势',
      'emotionTrend': '情绪趋势',
      'emotion_intensity': '情绪强度',
      'emotionIntensity': '情绪强度',
      'agent_emotion': '客服情绪',
      'agentEmotion': '客服情绪',
      'key_triggers': '关键触发点',
      'keyTriggers': '关键触发点',
      'emotion_nodes': '情绪节点',
      'emotionNodes': '情绪节点',
      // 质量评估
      'quality': '服务质量',
      'overall_tone': '整体基调',
      'overallTone': '整体基调',
      'customer_attitude': '客户态度',
      'customerAttitude': '客户态度',
      'agent_attitude': '客服态度',
      'agentAttitude': '客服态度',
      'agent_emotion_state': '客服情绪状态',
      'agentEmotionState': '客服情绪状态',
      'nature': '对话性质',
      'intensity': '强度指标',
      'conflict_level': '冲突等级',
      'conflictLevel': '冲突等级',
      'language_intensity': '语言激烈度',
      'languageIntensity': '语言激烈度',
      'tension_level': '紧张度',
      'tensionLevel': '紧张度',
      'overall_rating': '整体评级',
      'overallRating': '整体评级',
      // 解决情况
      'resolution': '解决情况',
      'status': '状态',
      'customer_satisfied': '客户满意',
      'customerSatisfied': '客户满意',
      'satisfaction_level': '满意度',
      'satisfactionLevel': '满意度',
      'secondary_issue': '衍生问题',
      'secondaryIssue': '衍生问题',
      'unresolved_issues': '未解决问题',
      'unresolvedIssues': '未解决问题',
      // 结构化数据
      'structured': '结构化数据',
      'sentiment_score': '情感得分',
      'sentimentScore': '情感得分',
      'resolution_status': '解决状态',
      'resolutionStatus': '解决状态',
      'customer_satisfaction': '客户满意度',
      'customerSatisfaction': '客户满意度',
      'emotion_tags': '情绪标签',
      'emotionTags': '情绪标签',
      'conflict_level': '冲突等级',
      'conflictLevel': '冲突等级',
      'risk_level': '风险等级',
      'riskLevel': '风险等级',
      'follow_up_required': '需要跟进',
      'followUpRequired': '需要跟进',
      'escalation_needed': '需要升级',
      'escalationNeeded': '需要升级',
    };

    // 如果 key 已经是中文，直接返回
    if (_isChinese(key)) {
      return key;
    }

    return keyMap[key] ?? _camelCaseToWords(key);
  }

  /// 检查字符串是否包含中文
  bool _isChinese(String input) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(input);
  }

  /// 驼峰/下划线转空格分隔
  String _camelCaseToWords(String input) {
    // 先处理下划线
    var result = input.replaceAll('_', ' ');
    // 再处理驼峰
    result = result.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    // 首字母大写
    if (result.isEmpty) return input;
    return result[0].toUpperCase() + result.substring(1);
  }

  /// 格式化为可复制文本
  String _formatForCopy(Map<String, dynamic> data, {int indent = 0}) {
    final buffer = StringBuffer();
    final prefix = '  ' * indent;

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      final label = _formatKey(key);

      if (value is Map<String, dynamic>) {
        buffer.writeln('$prefix$label:');
        buffer.write(_formatForCopy(value, indent: indent + 1));
      } else if (value is List) {
        buffer.writeln('$prefix$label:');
        for (final item in value) {
          buffer.writeln('$prefix  - $item');
        }
      } else {
        buffer.writeln('$prefix$label: $value');
      }
    }

    return buffer.toString();
  }
}
