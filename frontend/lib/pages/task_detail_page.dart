import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  @override
  void initState() {
    super.initState();
    // 加载任务
    Future.microtask(() {
      ref.read(currentTaskProvider.notifier).loadTask(widget.taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(currentTaskProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('任务详情'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          bottom: const TabBar(tabs: [Tab(text: '工作流'), Tab(text: '结果')]),
        ),
        body: taskAsync.when(
          data: (task) => task != null
              ? TabBarView(children: [
                  _buildWorkflowTab(task),
                  _buildResultTab(task),
                ])
              : const Center(child: Text('任务不存在')),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  Widget _buildWorkflowTab(Task task) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStep('上传文件', _getStepStatus(task, 0), task.createdAt.toString(),
            Icons.upload_file, completed: true),
        _buildConnector(),
        _buildStep(
            '语音识别',
            _getStepStatus(task, 1),
            _getStepTime(task, 1),
            Icons.mic,
            progress: task.progress,
            channel: task.model),
        _buildConnector(),
        _buildStep('生成摘要', _getStepStatus(task, 2), _getStepTime(task, 2),
            Icons.summarize,
            completed: task.status == TaskStatus.completed),
        _buildConnector(),
        _buildStep('完成', _getStepStatus(task, 3), _getStepTime(task, 3),
            Icons.check_circle,
            completed: task.status == TaskStatus.completed),
      ],
    );
  }

  String _getStepStatus(Task task, int step) {
    if (step == 0) return 'completed';
    if (task.status == TaskStatus.failed) return 'failed';
    if (task.status == TaskStatus.pending) return 'pending';

    if (step == 1) {
      if (task.progress < 60) return 'running';
      return 'completed';
    }
    if (step == 2) {
      if (task.progress >= 60 && task.progress < 100) return 'running';
      if (task.progress >= 100) return 'completed';
      return 'pending';
    }
    if (step == 3) {
      return task.status == TaskStatus.completed ? 'completed' : 'pending';
    }
    return 'pending';
  }

  String _getStepTime(Task task, int step) {
    if (step == 0) return task.createdAt.toString().substring(0, 16);
    if (step == 3 && task.status == TaskStatus.completed) {
      return task.completedAt?.toString().substring(0, 16) ?? '-';
    }
    return task.status == TaskStatus.running ? '进行中...' : '等待中';
  }

  Widget _buildStep(String title, String status, String time, IconData icon,
      {int? progress, String? channel, bool completed = false}) {
    final colors = {
      'completed': Colors.green,
      'running': Colors.blue,
      'failed': Colors.red,
      'pending': Colors.grey,
    };
    final color = colors[status] ?? Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(time,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    ],
                  ),
                ),
                Icon(
                    status == 'completed'
                        ? Icons.check_circle
                        : status == 'running'
                            ? Icons.sync
                            : Icons.schedule,
                    color: color),
              ],
            ),
            if (channel != null) ...[
              const SizedBox(height: 8),
              Chip(label: Text(channel)),
            ],
            if (progress != null && status == 'running') ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress / 100),
              Text('$progress%', style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Container(
        margin: const EdgeInsets.only(left: 40), width: 2, height: 24, color: Colors.grey[300]);
  }

  Widget _buildResultTab(Task task) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 文件信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('文件信息',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildInfoRow('文件名', task.fileName),
                _buildInfoRow('大小', '${(task.fileSize / 1024 / 1024).toStringAsFixed(2)} MB'),
                _buildInfoRow('模型', task.model),
                _buildInfoRow('语言', task.language),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 转写结果
        if (task.transcription != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('转写结果',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: 复制到剪贴板
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('复制'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(task.transcription!.fullText,
                        style: const TextStyle(height: 1.6)),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),

        // 摘要
        if (task.summary != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('智能摘要',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(task.summary!.medium, style: const TextStyle(height: 1.6)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: task.summary!.keywords
                        .map((k) => Chip(label: Text(k)))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
