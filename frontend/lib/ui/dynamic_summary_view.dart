import 'package:flutter/material.dart';
import 'dynamic_json_view.dart';

/// 摘要结果动态渲染组件
/// 针对摘要结果优化展示效果
class DynamicSummaryView extends StatelessWidget {
  final Map<String, dynamic> data;

  const DynamicSummaryView({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 对摘要数据进行排序和分组
    final sortedData = _sortSummaryData(data);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主要内容（摘要）优先展示
        if (sortedData['main'] != null)
          _buildMainContent(sortedData['main']!),

        // 关键要点
        if (sortedData['points'] != null)
          _buildPoints(sortedData['points']!),

        // 标签/关键词
        if (sortedData['tags'] != null)
          _buildTags(sortedData['tags']!),

        // 其他内容
        if (sortedData['others'] != null && sortedData['others']!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            child: DynamicJsonView(
              data: sortedData['others']!,
              initialDepth: 0,
              showCopyButton: false,
            ),
          ),
      ],
    );
  }

  Map<String, Map<String, dynamic>> _sortSummaryData(
    Map<String, dynamic> data,
  ) {
    final main = <String, dynamic>{};
    final points = <String, dynamic>{};
    final tags = <String, dynamic>{};
    final others = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;

      // 跳过空值
      if (value == null) continue;
      if (value is String && value.isEmpty) continue;
      if (value is List && value.isEmpty) continue;

      // 识别主要摘要字段
      if (['short', 'medium', 'long', 'brief', 'summary', 'abstract', 'content']
          .contains(key)) {
        main[entry.key] = value;
      }
      // 识别要点字段
      else if ([
        'key_points',
        'keypoints',
        'points',
        'highlights',
        'takeaways',
        'key_findings',
        'keyFindings',
      ].contains(key)) {
        points[entry.key] = value;
      }
      // 识别标签字段
      else if ([
        'keywords',
        'tags',
        'key_words',
        'categories',
        'topics',
      ].contains(key)) {
        tags[entry.key] = value;
      }
      // 其他字段
      else {
        others[entry.key] = value;
      }
    }

    return {
      'main': main,
      'points': points,
      'tags': tags,
      'others': others,
    };
  }

  Widget _buildMainContent(Map<String, dynamic> data) {
    // 优先展示长摘要，其次中摘要，最后短摘要
    final content = data['long'] ??
        data['medium'] ??
        data['summary'] ??
        data['content'] ??
        data['short'] ??
        data['brief'] ??
        data.values.firstOrNull;

    if (content == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.summarize, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                '内容摘要',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content.toString(),
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoints(Map<String, dynamic> data) {
    final pointsValue = data.values.firstOrNull;
    if (pointsValue == null) return const SizedBox.shrink();

    List<dynamic> points = [];
    if (pointsValue is List) {
      points = pointsValue;
    } else if (pointsValue is String) {
      points = pointsValue.split('\n').where((s) => s.isNotEmpty).toList();
    }

    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 20, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '关键要点',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...points.where((p) => p != null && p.toString().isNotEmpty).map(
            (point) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        point.toString(),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTags(Map<String, dynamic> data) {
    final tagsValue = data.values.firstOrNull;
    if (tagsValue == null) return const SizedBox.shrink();

    List<String> tags = [];
    if (tagsValue is List) {
      tags = tagsValue.map((t) => t.toString()).toList();
    } else if (tagsValue is String) {
      tags = tagsValue.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_outline, size: 20, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Text(
                '关键词',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.purple[200]!),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.purple[800],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
