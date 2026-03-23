import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/task_provider.dart';
import '../services/export_service.dart';
import '../models/task.dart';
import '../models/conversation_analysis.dart';
import '../ui/app_theme.dart';
import '../ui/markdown_viewer.dart';
import '../ui/components.dart';
import '../ui/dynamic_summary_view.dart';
import '../ui/dynamic_conversation_analysis_view.dart';

/// 任务详情页 - Editorial Tech 风格
///
/// 布局：
/// - 顶部栏：返回、文件名、导出按钮
/// - 标签栏：转写文本 | 内容摘要 | 对话分析 | 音频
/// - 内容区：根据标签切换
/// - 底部：音频播放器（可收起）
class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final AudioPlayer _player = AudioPlayer();
  final ExportService _exportService = ExportService();
  Timer? _refreshTimer;
  String? _audioError;
  bool _isPlayerMinimized = false;

  @override
  void initState() {
    super.initState();
    // 等待第一帧渲染完成后再加载，避免构建期状态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTask();
      // 第一帧完成后启动定时器
      _startRefreshTimer();
    });
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final task = ref.read(currentTaskProvider).value;
      if (task == null) return;
      if (task.status == TaskStatus.pending ||
          task.status == TaskStatus.processing) {
        ref.read(currentTaskProvider.notifier).refresh();
      }
    });
  }

  Future<void> _loadTask() async {
    // 强制刷新，确保获取最新状态
    await ref.read(currentTaskProvider.notifier).loadTask(widget.taskId, keepCurrent: false);
  }

  Future<void> _loadAudio(String? path) async {
    if (path == null) return;
    if (!File(path).existsSync()) {
      if (_audioError != '音频文件不存在或已被移动') {
        setState(() => _audioError = '音频文件不存在或已被移动');
      }
      return;
    }
    if (_audioError != null) {
      setState(() => _audioError = null);
    }
    await _player.setFilePath(path);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(currentTaskProvider);
    final task = taskAsync.value;

    return Scaffold(
      backgroundColor: AppTheme.gray50,
      body: Column(
        children: [
          // 顶部栏
          _DetailTopBar(
            taskAsync: taskAsync,
            onBack: () => context.pop(),
          ),

          // 主体内容
          Expanded(
            child: taskAsync.when(
              data: (task) {
                if (task == null) {
                  return _EmptyState(
                    icon: Icons.error_outline,
                    title: '任务不存在',
                    subtitle: '任务可能已被删除或尚未创建完成',
                    onAction: _loadTask,
                    actionLabel: '重试',
                  );
                }
                _loadAudio(task.filePath);
                return _DetailBody(
                  task: task,
                  audioError: _audioError,
                  player: _player,
                );
              },
              loading: () => const _EmptyState(
                icon: Icons.hourglass_empty,
                title: '加载中',
                subtitle: '正在获取任务详情…',
              ),
              error: (e, _) => _EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                subtitle: e.toString(),
                onAction: _loadTask,
                actionLabel: '重试',
              ),
            ),
          ),

          // 音频播放器
          if (task != null && task.status == TaskStatus.completed)
            _AudioPlayerBar(
              player: _player,
              isMinimized: _isPlayerMinimized,
              onToggleMinimize: () {
                setState(() => _isPlayerMinimized = !_isPlayerMinimized);
              },
            ),
        ],
      ),
    );
  }
}

/// 顶部栏
class _DetailTopBar extends StatelessWidget {
  final AsyncValue<Task?> taskAsync;
  final VoidCallback onBack;

  const _DetailTopBar({
    required this.taskAsync,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final task = taskAsync.value;

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
          // 返回按钮
          _IconButton(
            icon: Icons.arrow_back,
            onTap: onBack,
          ),
          const SizedBox(width: 16),

          // 文件信息
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task != null)
                  FileNameDisplay(
                    fileName: task.fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                    showCopyButton: true,
                  )
                else
                  const Text(
                    '加载中...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.gray900,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (task != null) ...[
                      _StatusBadge(status: task.status),
                      const SizedBox(width: 12),
                      Text(
                        '创建于 ${_formatDate(task.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray500,
                        ),
                      ),
                    ] else
                      const Text(
                        '加载中...',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.gray400,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 导出按钮
          if (task != null && task.status == TaskStatus.completed) ...[
            _IconButton(
              icon: Icons.download,
              onTap: () => _showExportMenu(context, task),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showExportMenu(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ExportMenu(task: task),
    );
  }
}

/// 状态徽章
class _StatusBadge extends StatelessWidget {
  final TaskStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      TaskStatus.pending => ('待处理', AppTheme.gray600),
      TaskStatus.processing => ('处理中', AppTheme.primary600),
      TaskStatus.completed => ('已完成', AppTheme.success),
      TaskStatus.failed => ('失败', AppTheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 图标按钮
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Icon(icon, size: 20, color: AppTheme.gray600),
      ),
    );
  }
}

/// 导出菜单
class _ExportMenu extends StatefulWidget {
  final Task task;

  const _ExportMenu({required this.task});

  @override
  State<_ExportMenu> createState() => _ExportMenuState();
}

class _ExportMenuState extends State<_ExportMenu> {
  bool _isExporting = false;
  String _exportStatus = '';

  Future<void> _exportPdf(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _exportStatus = '正在生成 PDF...';
    });

    try {
      final exportService = ExportService();
      // 如果有对话分析，导出分析报告；否则导出基础报告
      if (widget.task.conversationAnalysis != null) {
        await exportService.exportConversationAnalysisPdf(
          widget.task,
          widget.task.conversationAnalysis!,
        );
      } else {
        await exportService.exportPdf(widget.task);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF 导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '导出失败: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportTxt(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _exportStatus = '正在导出 TXT...';
    });

    try {
      final exportService = ExportService();
      await exportService.exportTxt(widget.task);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('TXT 导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '导出失败: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  Future<void> _exportJson(BuildContext context) async {
    setState(() {
      _isExporting = true;
      _exportStatus = '正在导出 JSON...';
    });

    try {
      final exportService = ExportService();
      await exportService.exportJson(widget.task);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('JSON 导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _exportStatus = '导出失败: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '导出内容',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '选择要导出的格式',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: 20),
            if (_isExporting) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _exportStatus,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.gray600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              _ExportOption(
                icon: Icons.picture_as_pdf,
                label: 'PDF 文档',
                subtitle: widget.task.conversationAnalysis != null
                    ? '包含对话分析报告'
                    : '适合打印和分享',
                color: AppTheme.error,
                onTap: () => _exportPdf(context),
              ),
              const SizedBox(height: 12),
              _ExportOption(
                icon: Icons.text_snippet,
                label: 'TXT 文本',
                subtitle: '纯文本格式',
                color: AppTheme.gray600,
                onTap: () => _exportTxt(context),
              ),
              const SizedBox(height: 12),
              _ExportOption(
                icon: Icons.code,
                label: 'JSON 数据',
                subtitle: '包含完整结构化数据',
                color: AppTheme.primary600,
                onTap: () => _exportJson(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 导出选项
class _ExportOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ExportOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.gray500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppTheme.gray400,
            ),
          ],
        ),
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppTheme.gray400),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// 详情主体
class _DetailBody extends StatefulWidget {
  final Task task;
  final String? audioError;
  final AudioPlayer player;

  const _DetailBody({
    required this.task,
    this.audioError,
    required this.player,
  });

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 标签栏
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary600,
            unselectedLabelColor: AppTheme.gray500,
            indicatorColor: AppTheme.primary600,
            indicatorWeight: 2,
            tabs: const [
              Tab(text: '转写文本'),
              Tab(text: '内容摘要'),
              Tab(text: '对话分析'),
              Tab(text: '音频'),
            ],
          ),
        ),

        // 标签内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _TranscriptView(task: widget.task, player: widget.player),
              _SummaryView(task: widget.task),
              _AnalysisView(task: widget.task),
              _AudioView(task: widget.task, player: widget.player),
            ],
          ),
        ),
      ],
    );
  }
}

/// 转写文本视图
class _TranscriptView extends StatefulWidget {
  final Task task;
  final AudioPlayer player;

  const _TranscriptView({required this.task, required this.player});

  @override
  State<_TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<_TranscriptView> {
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  int _currentMatchIndex = 0;
  List<int> _matchIndices = [];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentMatchIndex = 0;
    });

    // 延迟执行滚动，等待列表构建完成
    if (query.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollToFirstMatch();
      });
    }
  }

  void _scrollToFirstMatch() {
    if (_matchIndices.isEmpty) return;

    final targetIndex = _matchIndices[_currentMatchIndex];
    final itemHeight = 80.0; // 估算每项高度
    final offset = targetIndex * itemHeight;

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _navigateToNextMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _matchIndices.length;
    });
    _scrollToFirstMatch();
  }

  void _navigateToPreviousMatch() {
    if (_matchIndices.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex - 1 + _matchIndices.length) % _matchIndices.length;
    });
    _scrollToFirstMatch();
  }

  @override
  Widget build(BuildContext context) {
    final segments = widget.task.transcription?.segments ?? [];
    final fullText = widget.task.transcription?.fullText ?? '';

    // 过滤片段
    final filteredSegments = _searchQuery.isEmpty
        ? segments
        : segments.where((s) =>
            s.text.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    // 更新匹配索引
    _matchIndices = [];
    if (_searchQuery.isNotEmpty) {
      for (int i = 0; i < segments.length; i++) {
        if (segments[i].text.toLowerCase().contains(_searchQuery.toLowerCase())) {
          _matchIndices.add(i);
        }
      }
    }

    if (segments.isEmpty) {
      return const _EmptyState(
        icon: Icons.text_snippet_outlined,
        title: '暂无转写内容',
        subtitle: '转写结果将在此显示',
      );
    }

    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.gray200)),
          ),
          child: Row(
            children: [
              // 搜索框
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.gray50,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: TextField(
                    onChanged: _updateSearch,
                    decoration: InputDecoration(
                      hintText: '搜索转写文本...',
                      hintStyle: TextStyle(color: AppTheme.gray400, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: AppTheme.gray400, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 搜索结果导航
              if (_searchQuery.isNotEmpty && _matchIndices.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary50,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: _navigateToPreviousMatch,
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(Icons.chevron_left, size: 18, color: AppTheme.primary600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_currentMatchIndex + 1}/${_matchIndices.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: _navigateToNextMatch,
                        borderRadius: BorderRadius.circular(4),
                        child: Icon(Icons.chevron_right, size: 18, color: AppTheme.primary600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (_searchQuery.isNotEmpty) ...[
                Text(
                  '无匹配',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.gray500,
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // 统计信息
              Text(
                '${filteredSegments.length} 片段 · ${fullText.length} 字',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.gray500,
                ),
              ),
              const SizedBox(width: 12),

              // 复制全部
              _ToolbarButton(
                icon: Icons.copy,
                label: '复制全部',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: fullText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制全部转写文本'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // 转写列表
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(24),
            itemCount: filteredSegments.length,
            itemBuilder: (context, index) {
              final segment = filteredSegments[index];
              final originalIndex = segments.indexOf(segment);
              final isHighlighted = _searchQuery.isNotEmpty &&
                  segment.text.toLowerCase().contains(_searchQuery.toLowerCase());
              final isCurrentMatch = isHighlighted &&
                  _matchIndices.isNotEmpty &&
                  originalIndex == _matchIndices[_currentMatchIndex];

              return _TranscriptItem(
                text: segment.text,
                startTime: Duration(milliseconds: (segment.startTime * 1000).toInt()),
                endTime: Duration(milliseconds: (segment.endTime * 1000).toInt()),
                isAlternate: originalIndex % 2 == 1,
                isHighlighted: isHighlighted,
                isCurrentMatch: isCurrentMatch,
                searchQuery: _searchQuery,
                onTap: () {
                  widget.player.seek(Duration(milliseconds: (segment.startTime * 1000).toInt()));
                },
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: segment.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('已复制片段'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 转写片段
class _TranscriptItem extends StatelessWidget {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final bool isAlternate;
  final bool isHighlighted;
  final bool isCurrentMatch;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onCopy;

  const _TranscriptItem({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.isAlternate,
    this.isHighlighted = false,
    this.isCurrentMatch = false,
    this.searchQuery = '',
    required this.onTap,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: isCurrentMatch ? const EdgeInsets.all(8) : null,
      decoration: BoxDecoration(
        color: isCurrentMatch ? AppTheme.warning50 : null,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isCurrentMatch
            ? Border.all(color: AppTheme.warning.withOpacity(0.5))
            : null,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 时间戳
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCurrentMatch
                          ? AppTheme.warning.withOpacity(0.2)
                          : AppTheme.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatTime(startTime),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray600,
                        fontFamily: 'JetBrains Mono',
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTime(endTime),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.gray400,
                      fontFamily: 'JetBrains Mono',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // 说话人标识
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isAlternate
                    ? AppTheme.accent600.withOpacity(0.1)
                    : AppTheme.primary600.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  isAlternate ? 'B' : 'A',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isAlternate ? AppTheme.accent600 : AppTheme.primary600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 文本内容
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isAlternate ? AppTheme.gray50 : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppTheme.gray200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildHighlightedText(),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onCopy,
                      borderRadius: BorderRadius.circular(4),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 14,
                          color: AppTheme.gray400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText() {
    if (searchQuery.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppTheme.gray700,
        ),
      );
    }

    final lowerQuery = searchQuery.toLowerCase();
    final lowerText = text.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // 添加剩余文本
        if (start < text.length) {
          spans.add(TextSpan(
            text: text.substring(start),
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.gray700,
            ),
          ));
        }
        break;
      }

      // 添加匹配前的文本
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppTheme.gray700,
          ),
        ));
      }

      // 添加高亮匹配的文本
      spans.add(TextSpan(
        text: text.substring(index, index + searchQuery.length),
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
          color: AppTheme.gray700,
          backgroundColor: Color(0xFFFFEB3B),
          fontWeight: FontWeight.w600,
        ),
      ));

      start = index + searchQuery.length;
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 工具栏按钮
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.gray600),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 摘要视图
class _SummaryView extends StatelessWidget {
  final Task task;

  const _SummaryView({required this.task});

  @override
  Widget build(BuildContext context) {
    final summary = task.summary;

    if (summary == null) {
      return const _EmptyState(
        icon: Icons.summarize_outlined,
        title: '暂无摘要',
        subtitle: '摘要生成后将在此显示',
      );
    }

    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.gray200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary600),
                    const SizedBox(width: 6),
                    Text(
                      'AI 生成',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 动态渲染内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: DynamicSummaryView(
              data: summary.rawData,
            ),
          ),
        ),
      ],
    );
  }
}

/// 分析视图
class _AnalysisView extends StatelessWidget {
  final Task task;

  const _AnalysisView({required this.task});

  @override
  Widget build(BuildContext context) {
    final analysis = task.conversationAnalysis;

    if (analysis == null) {
      return _EmptyState(
        icon: Icons.psychology_outlined,
        title: '暂无对话分析',
        subtitle: task.enableConversationAnalysis
            ? '分析完成后将在此显示'
            : '请在创建任务时开启对话分析',
      );
    }

    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.gray200)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary50,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary600),
                    const SizedBox(width: 6),
                    Text(
                      'AI 分析',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 动态渲染内容
        Expanded(
          child: DynamicConversationAnalysisView(
            data: analysis.rawData,
          ),
        ),
      ],
    );
  }
}

/// 音频视图
class _AudioView extends StatelessWidget {
  final Task task;
  final AudioPlayer player;

  const _AudioView({required this.task, required this.player});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primary600.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.music_note,
              size: 60,
              color: AppTheme.primary600,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            task.fileName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${task.audioFormat?.toUpperCase() ?? '未知'} · ${task.duration != null ? '${task.duration! ~/ 60}:${(task.duration! % 60).toString().padLeft(2, '0')}' : '--:--'}',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

/// 分析类型徽章
class _AnalysisTypeBadge extends StatelessWidget {
  final String type;

  const _AnalysisTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      '投诉' => AppTheme.error,
      '售后' => AppTheme.warning,
      '技术支持' => AppTheme.primary600,
      '售前' => AppTheme.accent600,
      _ => AppTheme.gray600,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.category, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '对话类型: $type',
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
}

/// 分析卡片
class _AnalysisCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _AnalysisCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.gray700,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.gray900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 情绪时间线
class _EmotionTimeline extends StatelessWidget {
  final EmotionAnalysis analysis;

  const _EmotionTimeline({required this.analysis});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EmotionNode(label: '初始', emotion: analysis.initialEmotion),
        const Expanded(
          child: Divider(indent: 8, endIndent: 8),
        ),
        _EmotionNode(label: '峰值', emotion: analysis.peakEmotion),
        const Expanded(
          child: Divider(indent: 8, endIndent: 8),
        ),
        _EmotionNode(label: '结束', emotion: analysis.finalEmotion),
      ],
    );
  }
}

/// 情绪节点
class _EmotionNode extends StatelessWidget {
  final String label;
  final String emotion;

  const _EmotionNode({required this.label, required this.emotion});

  @override
  Widget build(BuildContext context) {
    final color = switch (emotion) {
      '愤怒' || '失望' => AppTheme.error,
      '焦虑' || '疑惑' => AppTheme.warning,
      '平和' || '满意' => AppTheme.success,
      '兴奋' => AppTheme.accent600,
      _ => AppTheme.gray600,
    };

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
}

/// 摘要卡片
class _SummaryCard extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.content,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.info50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary600.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary600),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppTheme.primary900,
            ),
          ),
        ],
      ),
    );
  }
}

/// 区块标题
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.gray500),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.gray700,
          ),
        ),
      ],
    );
  }
}

/// 要点项目
class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: AppTheme.primary500,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppTheme.gray600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 关键词芯片
class _KeywordChip extends StatelessWidget {
  final String label;

  const _KeywordChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.gray200),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.gray500,
        ),
      ),
    );
  }
}

/// 音频播放器栏
class _AudioPlayerBar extends StatelessWidget {
  final AudioPlayer player;
  final bool isMinimized;
  final VoidCallback onToggleMinimize;

  const _AudioPlayerBar({
    required this.player,
    required this.isMinimized,
    required this.onToggleMinimize,
  });

  @override
  Widget build(BuildContext context) {
    if (isMinimized) {
      return Container(
        height: 48,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.gray900,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            _MiniPlayButton(player: player),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final duration = player.duration ?? Duration.zero;
                  return Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontFamily: 'JetBrains Mono',
                    ),
                  );
                },
              ),
            ),
            IconButton(
              onPressed: onToggleMinimize,
              icon: const Icon(Icons.expand_less, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppTheme.gray200),
        boxShadow: [AppShadows.lg],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 播放按钮
              _PlayButton(player: player),
              const SizedBox(width: 16),

              // 进度条
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = player.duration ?? Duration.zero;
                    final progress = duration.inMilliseconds == 0
                        ? 0.0
                        : position.inMilliseconds / duration.inMilliseconds;

                    return Column(
                      children: [
                        // 进度条
                        GestureDetector(
                          onTapDown: (details) {
                            final box = context.findRenderObject() as RenderBox?;
                            if (box == null) return;
                            final local = box.globalToLocal(details.globalPosition);
                            final width = box.size.width;
                            final ratio = (local.dx / width).clamp(0.0, 1.0);
                            final newPos = duration * ratio;
                            player.seek(newPos);
                          },
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.gray200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress.isNaN ? 0 : progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary600,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 时间显示
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.gray500,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.gray500,
                                fontFamily: 'JetBrains Mono',
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(width: 16),

              // 最小化按钮
              IconButton(
                onPressed: onToggleMinimize,
                icon: Icon(Icons.expand_more, color: AppTheme.gray500, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 播放按钮
class _PlayButton extends StatelessWidget {
  final AudioPlayer player;

  const _PlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return InkWell(
          onTap: () async {
            if (isPlaying) {
              await player.pause();
            } else {
              await player.play();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary600,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// 迷你播放按钮
class _MiniPlayButton extends StatelessWidget {
  final AudioPlayer player;

  const _MiniPlayButton({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: player.playingStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data ?? false;

        return InkWell(
          onTap: () async {
            if (isPlaying) {
              await player.pause();
            } else {
              await player.play();
            }
          },
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 20,
          ),
        );
      },
    );
  }
}

/// 评分网格
class _ScoreGrid extends StatelessWidget {
  final List<_ScoreItem> scores;

  const _ScoreGrid({required this.scores});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: scores.map((score) => Expanded(child: score)).toList(),
    );
  }
}

/// 评分项
class _ScoreItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  final String? displayValue;

  const _ScoreItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.displayValue,
  });

  @override
  Widget build(BuildContext context) {
    final scoreColor = color ?? _getDefaultColor(value);
    final text = displayValue ?? value.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scoreColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: scoreColor),
          const SizedBox(height: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getDefaultColor(int score) {
    if (score >= 8) return AppTheme.success;
    if (score >= 6) return AppTheme.warning;
    return AppTheme.error;
  }
}

/// 优先级徽章
class _PriorityBadge extends StatelessWidget {
  final int score;

  const _PriorityBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (score) {
      >= 8 => ('紧急', AppTheme.error),
      >= 6 => ('高', AppTheme.warning),
      >= 4 => ('中', AppTheme.primary600),
      _ => ('低', AppTheme.success),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
