import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../models/conversation_analysis.dart';
import '../providers/task_provider.dart';
import '../services/export_service.dart';
import '../ui/app_theme.dart';
import '../ui/dynamic_conversation_analysis_view.dart';

/// 对话分析详情页 - Editorial Tech 风格
///
/// 布局：
/// - 顶部摘要卡片（横向滚动）
/// - 分节展示（可折叠）
/// - 情绪时间线可视化
/// - 服务质量评分进度条
class ConversationAnalysisPage extends ConsumerStatefulWidget {
  final String taskId;

  const ConversationAnalysisPage({super.key, required this.taskId});

  @override
  ConsumerState<ConversationAnalysisPage> createState() => _ConversationAnalysisPageState();
}

class _ConversationAnalysisPageState extends ConsumerState<ConversationAnalysisPage> {
  @override
  void initState() {
    super.initState();
    // 等待第一帧渲染完成后再加载，避免构建期状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTask();
    });
  }

  Future<void> _loadTask() async {
    // 强制刷新，确保获取最新状态
    await ref.read(currentTaskProvider.notifier).loadTask(widget.taskId, keepCurrent: false);
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(currentTaskProvider);

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: Column(
        children: [
          // 顶部栏
          _buildAppBar(taskAsync),

          // 内容区
          Expanded(
            child: taskAsync.when(
              data: (task) {
                if (task == null) {
                  return const Center(
                    child: Text('任务不存在', style: TextStyle(color: AppTheme.gray500)),
                  );
                }
                final analysis = task.conversationAnalysis;
                if (analysis == null) {
                  return _buildEmptyState();
                }
                return _buildAnalysisContent(context, analysis);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('加载失败: $e', style: const TextStyle(color: AppTheme.gray500)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(AsyncValue<Task?> taskAsync) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.gray200)),
        boxShadow: [AppShadows.sm],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.gray600),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: taskAsync.when(
              data: (task) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '对话分析报告',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.gray900,
                    ),
                  ),
                  Text(
                    task?.fileName ?? '加载中...',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.gray500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              loading: () => const Text('加载中...'),
              error: (_, __) => const Text('加载失败'),
            ),
          ),
          taskAsync.when(
            data: (task) {
              if (task?.conversationAnalysis != null) {
                return FilledButton.icon(
                  onPressed: () => _exportAnalysis(context, task!.conversationAnalysis!),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('导出 PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary600,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppTheme.gray100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 48,
              color: AppTheme.gray400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无对话分析',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '分析结果将在此展示',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisContent(BuildContext context, ConversationAnalysis analysis) {
    return DynamicConversationAnalysisView(
      data: analysis.rawData,
    );
  }

  /// 摘要卡片（横向滚动）
  Widget _buildSummaryCards(ConversationAnalysis analysis) {
    return Container(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          // 对话类型 - 突出显示
          _MetricCard(
            icon: Icons.category,
            label: '对话类型',
            value: analysis.info.type,
            color: _getTypeColor(analysis.info.type),
            size: MetricCardSize.large,
          ),
          const SizedBox(width: 12),

          // 情感得分 - 大数字展示
          _MetricCard(
            icon: Icons.sentiment_satisfied,
            label: '情感得分',
            value: analysis.structured.sentimentScore.toStringAsFixed(1),
            color: _getSentimentColor(analysis.structured.sentimentScore),
            subtitle: analysis.structured.sentimentScore > 0 ? '积极' : analysis.structured.sentimentScore < 0 ? '消极' : '中性',
          ),
          const SizedBox(width: 12),

          // 解决状态
          _MetricCard(
            icon: Icons.check_circle,
            label: '解决状态',
            value: analysis.resolution.status,
            color: _getResolutionColor(analysis.resolution.status),
          ),
          const SizedBox(width: 12),

          // 风险等级
          _MetricCard(
            icon: Icons.warning,
            label: '风险等级',
            value: analysis.structured.riskLevel,
            color: _getRiskColor(analysis.structured.riskLevel),
          ),
          const SizedBox(width: 12),

          // 对话轮次
          _MetricCard(
            icon: Icons.repeat,
            label: '对话轮次',
            value: '${analysis.info.customerTurns + analysis.info.agentTurns}',
            subtitle: '客${analysis.info.customerTurns}/服${analysis.info.agentTurns}',
            color: AppTheme.primary600,
          ),
          const SizedBox(width: 12),

          // 时长
          _MetricCard(
            icon: Icons.timer,
            label: '对话时长',
            value: '${analysis.info.durationMinutes}',
            subtitle: '分钟',
            color: AppTheme.accent600,
          ),
        ],
      ),
    );
  }

  /// 可折叠区域
  Widget _buildCollapsibleSection({
    required String title,
    required IconData icon,
    required Widget child,
    bool initiallyExpanded = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          collapsedBackgroundColor: Colors.white,
          backgroundColor: Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary600.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: AppTheme.primary600, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray900,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [child],
        ),
      ),
    );
  }

  /// 基础信息区域
  Widget _buildInfoSection(ConversationInfo info) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (info.summary != null && info.summary!.isNotEmpty) ...[
          _buildInfoRow('对话摘要', info.summary!),
          const SizedBox(height: 8),
        ],
        if (info.scenario != null && info.scenario!.isNotEmpty)
          _buildInfoRow('场景描述', info.scenario!),
        _buildInfoRow('对话类型', info.type),
        _buildInfoRow('业务标签', info.businessTag),
        _buildInfoRow('客户发言', '${info.customerTurns}次'),
        _buildInfoRow('客服发言', '${info.agentTurns}次'),
        if (info.totalMessages != null && info.totalMessages! > 0)
          _buildInfoRow('总消息数', '${info.totalMessages}条'),
        _buildInfoRow('预估时长', '${info.durationMinutes}分钟'),
        if (info.avgResponseTimeSeconds != null && info.avgResponseTimeSeconds! > 0)
          _buildInfoRow('平均响应', '${info.avgResponseTimeSeconds}秒'),
        if (info.firstResponseTimeSeconds != null && info.firstResponseTimeSeconds! > 0)
          _buildInfoRow('首次响应', '${info.firstResponseTimeSeconds}秒'),
      ],
    );
  }

  /// 客户画像区域
  Widget _buildCustomerProfileSection(CustomerProfile profile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.customerId != null && profile.customerId!.isNotEmpty)
          _buildInfoRow('客户ID', profile.customerId!),
        if (profile.customerName != null && profile.customerName!.isNotEmpty)
          _buildInfoRow('客户姓名', profile.customerName!),
        if (profile.contactInfo != null && profile.contactInfo!.isNotEmpty)
          _buildInfoRow('联系方式', profile.contactInfo!),
        _buildInfoRow('客户类型', profile.customerType),
        if (profile.membershipLevel != null && profile.membershipLevel!.isNotEmpty)
          _buildInfoRow('会员等级', profile.membershipLevel!),
        if (profile.lifetimeValue != null && profile.lifetimeValue!.isNotEmpty)
          _buildInfoRow('客户价值', profile.lifetimeValue!),
        if (profile.churnRisk != null && profile.churnRisk!.isNotEmpty)
          _buildInfoRow('流失风险', profile.churnRisk!),
        if (profile.tags.isNotEmpty)
          _buildTagRow('画像标签', profile.tags),
        if (profile.coreDemand.isNotEmpty)
          _buildInfoRow('核心诉求', profile.coreDemand),
        if (profile.expectedSolution.isNotEmpty)
          _buildInfoRow('期望方案', profile.expectedSolution),
        if (profile.explicitNeeds.isNotEmpty)
          _buildListSection('显性需求', profile.explicitNeeds),
        if (profile.implicitNeeds.isNotEmpty)
          _buildListSection('隐性需求', profile.implicitNeeds),
      ],
    );
  }

  /// 客户情绪分析区域
  Widget _buildEmotionSection(EmotionAnalysis emotion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 整体对话情绪
        if (emotion.overallEmotion != null && emotion.overallEmotion!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getEmotionColor(emotion.overallEmotion!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _getEmotionColor(emotion.overallEmotion!).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.emoji_emotions_outlined,
                  color: _getEmotionColor(emotion.overallEmotion!),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '整体对话情绪: ${emotion.overallEmotion}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _getEmotionColor(emotion.overallEmotion!),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 客服情绪状态
        if (emotion.agentEmotion != null && emotion.agentEmotion!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppTheme.primary600.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.support_agent,
                  color: AppTheme.primary600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '客服情绪状态: ${emotion.agentEmotion}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 客户情绪时间线
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.gray50,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Row(
            children: [
              _buildEmotionNode('客户初始', emotion.initialEmotion),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getEmotionColor(emotion.initialEmotion),
                        _getEmotionColor(emotion.peakEmotion),
                        _getEmotionColor(emotion.finalEmotion),
                      ],
                    ),
                  ),
                ),
              ),
              _buildEmotionNode('客户峰值', emotion.peakEmotion),
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getEmotionColor(emotion.peakEmotion),
                        _getEmotionColor(emotion.finalEmotion),
                      ],
                    ),
                  ),
                ),
              ),
              _buildEmotionNode('客户结束', emotion.finalEmotion),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildInfoRow('客户情绪趋势', emotion.emotionTrend),
        _buildInfoRow('客户情绪强度', '${emotion.emotionIntensity}/10'),

        // 关键触发点（新增）
        if (emotion.keyTriggers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildListSection('客户情绪触发点', emotion.keyTriggers, color: AppTheme.warning),
        ],
        if (emotion.emotionNodes.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            '客户关键情绪节点',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 12),
          ...emotion.emotionNodes.map((node) => _buildEmotionNodeCard(node)),
        ],
      ],
    );
  }

  /// 情绪节点卡片
  Widget _buildEmotionNodeCard(EmotionNode node) {
    final color = _getEmotionColor(node.customerEmotion);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.gray50,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '第${node.round}轮',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Text(
                  node.customerEmotion,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '触发: ${node.trigger}',
            style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
          ),
          if (node.agentResponse.isNotEmpty)
            Text(
              '应对: ${node.agentResponse}',
              style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
            ),
        ],
      ),
    );
  }

  /// 问题反馈区域
  Widget _buildFeedbackSection(FeedbackAnalysis feedback) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 是否遇到问题
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: feedback.hasIssue ? AppTheme.error.withOpacity(0.1) : AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: feedback.hasIssue ? AppTheme.error.withOpacity(0.3) : AppTheme.success.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    feedback.hasIssue ? Icons.error_outline : Icons.check_circle_outline,
                    size: 16,
                    color: feedback.hasIssue ? AppTheme.error : AppTheme.success,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    feedback.hasIssue ? '存在问题' : '无问题',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: feedback.hasIssue ? AppTheme.error : AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            if (feedback.urgency != null && feedback.urgency!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getUrgencyColor(feedback.urgency!).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getUrgencyColor(feedback.urgency!).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  '紧急度: ${feedback.urgency}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getUrgencyColor(feedback.urgency!),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // 问题摘要
        _buildInfoRow('问题摘要', feedback.issueAbstract),

        // 分类（新的 l1/l2/l3）
        if (feedback.category != null)
          _buildInfoRow(
            '问题分类',
            feedback.category!.l3 != null && feedback.category!.l3!.isNotEmpty
                ? '${feedback.category!.l1} / ${feedback.category!.l2} / ${feedback.category!.l3}'
                : '${feedback.category!.l1} / ${feedback.category!.l2}',
          ),

        // 兼容旧数据
        if (feedback.category == null)
          _buildInfoRow('问题类型', '${feedback.problemType.level1} - ${feedback.problemType.level2}'),
        if (feedback.problemType.tags.isNotEmpty)
          _buildTagRow('技术标签', feedback.problemType.tags),

        // 严重程度
        _buildSeverityBadge(feedback.severity),

        // 客户期望
        if (feedback.expectations.isNotEmpty)
          _buildListSection('客户期望', feedback.expectations, color: AppTheme.primary600),

        // 痛点
        if (feedback.painPoints.isNotEmpty)
          _buildListSection('客户痛点', feedback.painPoints, color: AppTheme.error),

        // 提及的产品
        if (feedback.mentionedProducts.isNotEmpty)
          _buildTagRow('提及产品', feedback.mentionedProducts),

        // 提及的服务
        if (feedback.mentionedServices.isNotEmpty)
          _buildTagRow('提及服务', feedback.mentionedServices),

        // 根因分析
        const SizedBox(height: 8),
        _buildInfoRow('直接原因', feedback.rootCause.directCause),
        _buildInfoRow('可能根因', feedback.rootCause.rootCause),

        // 建议解决方案
        if (feedback.solutions.isNotEmpty)
          _buildListSection('建议解决方案', feedback.solutions),
      ],
    );
  }

  /// 服务质量区域
  Widget _buildQualitySection(ConversationQuality quality) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 客服整体表现评级
        if (quality.agentPerformance != null && quality.agentPerformance!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getPerformanceColor(quality.agentPerformance!).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _getPerformanceColor(quality.agentPerformance!).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getPerformanceColor(quality.agentPerformance!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    quality.agentPerformance!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                if (quality.attitude != null && quality.attitude!.isNotEmpty)
                  Text(
                    '服务态度: ${quality.attitude}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getPerformanceColor(quality.agentPerformance!),
                    ),
                  ),
              ],
            ),
          ),

        // 响应时间评价
        if (quality.responseTime != null && quality.responseTime!.isNotEmpty)
          _buildInfoRow('响应时间', quality.responseTime!),

        // 客服服务态度
        if (quality.agentAttitude != null && quality.agentAttitude!.isNotEmpty)
          _buildInfoRow('客服服务态度', quality.agentAttitude!),

        // 客服情绪状态
        if (quality.agentEmotionState != null && quality.agentEmotionState!.isNotEmpty)
          _buildInfoRow('客服情绪状态', quality.agentEmotionState!),

        // 新评分指标（1-10分）
        if (quality.professionalism != null)
          _buildScoreBar('专业度', quality.professionalism!, 10),
        if (quality.empathy != null)
          _buildScoreBar('同理心', quality.empathy!, 10),
        if (quality.resolutionWillingness != null)
          _buildScoreBar('解决意愿', quality.resolutionWillingness!, 10),
        if (quality.productKnowledge != null)
          _buildScoreBar('产品知识', quality.productKnowledge!, 10),
        if (quality.serviceEfficiency != null)
          _buildScoreBar('服务效率', quality.serviceEfficiency!, 10),

        // 兼容旧数据：激烈程度评分
        if (quality.professionalism == null) ...[
          _buildScoreBar('专业度', quality.intensity.conflictLevel, 5),
          _buildScoreBar('沟通技巧', quality.intensity.emotionIntensity, 5),
          _buildScoreBar('响应及时', quality.intensity.languageIntensity, 5),
          _buildScoreBar('解决意愿', quality.intensity.tensionLevel, 5),
        ],

        const Divider(height: 24),

        _buildInfoRow('整体基调', quality.overallTone),
        _buildInfoRow('客户态度', quality.customerAttitude),
        _buildInfoRow('对话性质', quality.nature),

        // 客服表现优点
        if (quality.positivePoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('表现优点', quality.positivePoints, color: AppTheme.success),
        ],

        // 客服需要改进的方面
        if (quality.improvementAreas.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('改进建议', quality.improvementAreas, color: AppTheme.warning),
        ],

        // 兼容旧数据
        if (quality.positiveMoments.isNotEmpty && quality.positivePoints.isEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('正向时刻', quality.positiveMoments, color: AppTheme.success),
        ],
        if (quality.negativeMoments.isNotEmpty && quality.improvementAreas.isEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('负面时刻', quality.negativeMoments, color: AppTheme.error),
        ],
      ],
    );
  }

  /// 管理指标区域
  Widget _buildManagementSection(ManagementMetrics management) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 跟进优先级
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getPriorityColor(management.followUpPriority).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: _getPriorityColor(management.followUpPriority).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag,
                color: _getPriorityColor(management.followUpPriority),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '跟进优先级: ${management.followUpPriority}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _getPriorityColor(management.followUpPriority),
                ),
              ),
            ],
          ),
        ),

        // 各项评分
        _buildScoreBar('首次解决率', management.firstContactResolution, 10),
        _buildScoreBar('升级必要性', management.escalationNecessity, 10),
        _buildScoreBar('合规遵循度', management.complianceScore, 10),
        _buildScoreBar('客户留存风险', management.customerRetentionRisk, 10),
        _buildScoreBar('投诉风险', management.complaintRisk, 10),
        _buildScoreBar('销售机会', management.salesOpportunity, 10),
        _buildScoreBar('服务补救', management.serviceRecovery, 10),

        // 培训需求
        if (management.trainingNeeds.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('培训需求', management.trainingNeeds, color: AppTheme.primary600),
        ],

        // 知识盲点
        if (management.knowledgeGap.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildListSection('知识盲点', management.knowledgeGap, color: AppTheme.warning),
        ],
      ],
    );
  }

  /// 综合评分区域
  Widget _buildMetricsSection(ComprehensiveMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 平均分展示
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary600.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppTheme.primary600.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _getScoreColor(metrics.averageScore.toInt()).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getScoreColor(metrics.averageScore.toInt()).withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    metrics.averageScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _getScoreColor(metrics.averageScore.toInt()),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '综合评分',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getScoreLabel(metrics.averageScore.toInt()),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _getScoreColor(metrics.averageScore.toInt()),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 各项评分
        _buildScoreBar('客服效率', metrics.agentEfficiencyScore, 10),
        _buildScoreBar('客户体验', metrics.customerExperienceScore, 10),
        _buildScoreBar('对话质量', metrics.conversationQualityScore, 10),
        _buildScoreBar('业务影响', metrics.businessImpactScore, 10),
        _buildScoreBar('优先级评分', metrics.priorityScore, 10),
      ],
    );
  }

  /// 评分进度条
  Widget _buildScoreBar(String label, int score, int maxScore) {
    final progress = score / maxScore;
    final color = score >= 4 ? AppTheme.success : score >= 3 ? AppTheme.warning : AppTheme.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray600,
                  ),
                ),
              ),
              Text(
                '$score/$maxScore',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.gray200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  /// 解决情况区域
  Widget _buildResolutionSection(ResolutionStatus resolution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                icon: Icons.check_circle,
                label: '解决状态',
                value: resolution.status,
                color: _getResolutionColor(resolution.status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatusCard(
                icon: Icons.sentiment_satisfied,
                label: '满意度',
                value: resolution.satisfactionLevel,
                color: _getSatisfactionColor(resolution.satisfactionLevel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInfoRow('解决摘要', resolution.summary),
        if (resolution.unresolvedIssues.isNotEmpty)
          _buildListSection('未解决问题', resolution.unresolvedIssues, color: AppTheme.error),
      ],
    );
  }

  /// 状态卡片
  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 结构化数据区域
  Widget _buildStructuredSection(StructuredData structured) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (structured.emotionTags.isNotEmpty)
          _buildTagRow('情绪标签', structured.emotionTags),
        _buildInfoRow('对话类型', structured.conversationType),
        _buildInfoRow('冲突等级', structured.conflictLevel),
        _buildInfoRow('风险等级', structured.riskLevel),
        _buildInfoRow('需要跟进', structured.followUpRequired ? '是' : '否'),
        _buildInfoRow('需要升级', structured.escalationNeeded ? '是' : '否'),
      ],
    );
  }

  /// 信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 标签行
  Widget _buildTagRow(String label, List<String> tags) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray500,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary600.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.primary600,
                  ),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 列表区域
  Widget _buildListSection(String title, List<String> items, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.gray500,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color ?? AppTheme.primary600,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: color ?? AppTheme.gray700,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  /// 情绪节点
  Widget _buildEmotionNode(String label, String emotion) {
    final color = _getEmotionColor(emotion);

    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.gray400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            emotion,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// 严重程度徽章
  Widget _buildSeverityBadge(Severity severity) {
    final color = _getSeverityColor(severity.level);

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  severity.level,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '评分: ${severity.score}/5',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '紧急程度: ${severity.urgency}',
            style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
          ),
          Text(
            '评级理由: ${severity.reason}',
            style: const TextStyle(fontSize: 13, color: AppTheme.gray600),
          ),
        ],
      ),
    );
  }

  /// 导出分析
  void _exportAnalysis(BuildContext context, ConversationAnalysis analysis) async {
    final task = ref.read(currentTaskProvider).value;
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务信息不存在')),
      );
      return;
    }

    try {
      await ExportService().exportConversationAnalysisPdf(task, analysis);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF导出成功')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 颜色辅助方法
  Color _getSentimentColor(double score) {
    if (score > 0.5) return AppTheme.success;
    if (score > 0) return const Color(0xFF65A30D);
    if (score > -0.5) return AppTheme.warning;
    return AppTheme.error;
  }

  Color _getEmotionColor(String emotion) {
    switch (emotion) {
      case '平和':
      case '满意':
      case '感激':
        return AppTheme.success;
      case '疑惑':
      case '焦虑':
        return AppTheme.warning;
      case '愤怒':
      case '失望':
        return AppTheme.error;
      case '兴奋':
        return AppTheme.primary600;
      default:
        return AppTheme.gray600;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case '投诉':
        return AppTheme.error;
      case '售后':
        return AppTheme.warning;
      case '技术支持':
        return AppTheme.primary600;
      case '售前':
        return AppTheme.accent600;
      default:
        return AppTheme.gray600;
    }
  }

  Color _getResolutionColor(String status) {
    switch (status) {
      case '完全解决':
        return AppTheme.success;
      case '部分解决':
        return AppTheme.warning;
      case '未解决':
        return AppTheme.error;
      case '升级处理':
        return AppTheme.accent600;
      default:
        return AppTheme.gray600;
    }
  }

  Color _getSatisfactionColor(String satisfaction) {
    switch (satisfaction) {
      case '非常满意':
      case '满意':
        return AppTheme.success;
      case '基本满意':
        return AppTheme.warning;
      case '不满意':
      case '非常不满意':
        return AppTheme.error;
      default:
        return AppTheme.gray600;
    }
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case '高风险':
        return AppTheme.error;
      case '中风险':
        return AppTheme.warning;
      case '低风险':
        return AppTheme.success;
      default:
        return AppTheme.gray600;
    }
  }

  Color _getSeverityColor(String level) {
    switch (level) {
      case 'P0-致命':
        return const Color(0xFFDC2626);
      case 'P1-严重':
        return const Color(0xFFEA580C);
      case 'P2-一般':
        return AppTheme.warning;
      case 'P3-轻微':
        return const Color(0xFF059669);
      case 'P4-建议':
        return AppTheme.gray600;
      default:
        return AppTheme.gray600;
    }
  }

  /// 紧急程度颜色
  Color _getUrgencyColor(String urgency) {
    switch (urgency) {
      case '极高':
      case '紧急':
        return AppTheme.error;
      case '高':
        return const Color(0xFFEA580C);
      case '中':
        return AppTheme.warning;
      case '低':
        return AppTheme.success;
      default:
        return AppTheme.gray600;
    }
  }

  /// 客服表现评级颜色
  Color _getPerformanceColor(String performance) {
    switch (performance) {
      case '优秀':
        return const Color(0xFF059669);
      case '良好':
        return const Color(0xFF65A30D);
      case '一般':
        return AppTheme.warning;
      case '较差':
        return const Color(0xFFEA580C);
      case '很差':
        return AppTheme.error;
      default:
        return AppTheme.gray600;
    }
  }

  /// 优先级颜色
  Color _getPriorityColor(String priority) {
    switch (priority) {
      case '高':
        return AppTheme.error;
      case '中':
        return AppTheme.warning;
      case '低':
        return AppTheme.success;
      default:
        return AppTheme.gray600;
    }
  }

  /// 分数颜色（1-10分）
  Color _getScoreColor(int score) {
    if (score >= 9) return const Color(0xFF059669);
    if (score >= 7) return const Color(0xFF65A30D);
    if (score >= 5) return AppTheme.warning;
    if (score >= 3) return const Color(0xFFEA580C);
    return AppTheme.error;
  }

  /// 分数评价标签
  String _getScoreLabel(int score) {
    if (score >= 9) return '卓越';
    if (score >= 7) return '优秀';
    if (score >= 5) return '良好';
    if (score >= 3) return '一般';
    return '需改进';
  }
}

enum MetricCardSize { normal, large }

/// 指标卡片 - 更清晰的视觉层次
class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  final MetricCardSize size;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
    this.size = MetricCardSize.normal,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = size == MetricCardSize.large;

    return Container(
      width: isLarge ? 160 : 130,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: isLarge ? 20 : 18, color: color),
              ),
              const Spacer(),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.gray500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
