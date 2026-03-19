import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../services/export_service.dart';
import '../ui/app_shell.dart';

final taskDateFilterProvider = StateProvider<String>((ref) => 'all');
final taskStatusFilterProvider = StateProvider<String>((ref) => 'all');
final taskPageProvider = StateProvider<int>((ref) => 1);
final taskPageSizeProvider = StateProvider<int>((ref) => 8);

class HomePage extends ConsumerStatefulWidget {
  final bool embedded;
  const HomePage({super.key, this.embedded = false});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      final current = ref.read(currentTaskProvider).value;
      if (current != null &&
          (current.status == TaskStatus.pending ||
              current.status == TaskStatus.processing)) {
        await ref.read(currentTaskProvider.notifier).refresh();
      }
      final keyword = ref.read(taskKeywordProvider);
      await ref.read(taskListProvider.notifier).loadTasks(
            keyword: keyword,
            silent: true,
          );
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        const Expanded(child: _TaskListPanel()),
        Container(
          width: 460,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Theme.of(context).dividerColor),
            ),
            color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
          ),
          child: const _InspectorPanel(),
        ),
      ],
    );
    if (widget.embedded) return content;
    return AppShell(
      active: AppNavItem.tasks,
      title: '任务',
      child: content,
    );
  }
}

class _TaskListPanel extends ConsumerWidget {
  const _TaskListPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final dateFilter = ref.watch(taskDateFilterProvider);
    final statusFilter = ref.watch(taskStatusFilterProvider);
    final page = ref.watch(taskPageProvider);
    final pageSize = ref.watch(taskPageSizeProvider);

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 120,
                child: _DateFilter(
                  value: dateFilter,
                  onChanged: (v) {
                    ref.read(taskDateFilterProvider.notifier).state = v;
                    ref.read(taskPageProvider.notifier).state = 1;
                  },
                ),
              ),
              SizedBox(
                width: 120,
                child: _StatusFilter(
                  value: statusFilter,
                  onChanged: (v) {
                    ref.read(taskStatusFilterProvider.notifier).state = v;
                    ref.read(taskPageProvider.notifier).state = 1;
                  },
                ),
              ),
              SizedBox(
                width: 96,
                child: _PageSizeFilter(
                  value: pageSize,
                  onChanged: (v) {
                    ref.read(taskPageSizeProvider.notifier).state = v;
                    ref.read(taskPageProvider.notifier).state = 1;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _TableHeader(),
          const SizedBox(height: 8),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered = _applyStatusFilter(
                  _applyDateFilter(tasks, dateFilter),
                  statusFilter,
                );
                if (tasks.isEmpty) {
                  return _EmptyState();
                }
                if (filtered.isEmpty) {
                  return const Center(child: Text('当前筛选条件下没有任务'));
                }
                final totalPages = (filtered.length / pageSize).ceil();
                final safePage = page.clamp(1, totalPages);
                final start = (safePage - 1) * pageSize;
                final end = (start + pageSize).clamp(0, filtered.length);
                final pageItems = filtered.sublist(start, end);
                return ListView.builder(
                  itemCount: pageItems.length,
                  itemBuilder: (context, index) =>
                      _TaskRow(task: pageItems[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('加载失败: $e'),
              ),
            ),
          ),
          tasksAsync.when(
            data: (tasks) {
              final filtered = _applyStatusFilter(
                _applyDateFilter(tasks, dateFilter),
                statusFilter,
              );
              if (filtered.isEmpty) return const SizedBox.shrink();
              final totalPages = (filtered.length / pageSize).ceil();
              final safePage = page.clamp(1, totalPages);
              return _PaginationBar(
                current: safePage,
                total: totalPages,
                totalItems: filtered.length,
                onChanged: (p) => ref.read(taskPageProvider.notifier).state = p,
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: const [
          Expanded(flex: 5, child: _HeaderCell('文件详情', align: TextAlign.left)),
          Expanded(flex: 2, child: _HeaderCell('状态', align: TextAlign.center)),
          Expanded(flex: 2, child: _HeaderCell('进度', align: TextAlign.center)),
          Expanded(flex: 3, child: _HeaderCell('创建日期', align: TextAlign.right)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _HeaderCell(this.text, {required this.align});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: align,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

List<Task> _applyDateFilter(List<Task> tasks, String filter) {
  if (filter == 'all') return tasks;
  final now = DateTime.now();
  DateTime start;
  switch (filter) {
    case 'today':
      start = DateTime(now.year, now.month, now.day);
      break;
    case '7d':
      start = now.subtract(const Duration(days: 7));
      break;
    case '30d':
      start = now.subtract(const Duration(days: 30));
      break;
    default:
      return tasks;
  }
  return tasks.where((t) => t.createdAt.isAfter(start)).toList();
}

List<Task> _applyStatusFilter(List<Task> tasks, String filter) {
  if (filter == 'all') return tasks;
  return tasks.where((t) => t.status.name == filter).toList();
}

class _DateFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DateFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('全部时间')),
            DropdownMenuItem(value: 'today', child: Text('今天')),
            DropdownMenuItem(value: '7d', child: Text('近7天')),
            DropdownMenuItem(value: '30d', child: Text('近30天')),
          ],
          onChanged: (v) => onChanged(v ?? 'all'),
        ),
      ),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('全部状态')),
            DropdownMenuItem(value: 'pending', child: Text('等待中')),
            DropdownMenuItem(value: 'processing', child: Text('处理中')),
            DropdownMenuItem(value: 'completed', child: Text('已完成')),
            DropdownMenuItem(value: 'failed', child: Text('失败')),
          ],
          onChanged: (v) => onChanged(v ?? 'all'),
        ),
      ),
    );
  }
}

class _PageSizeFilter extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _PageSizeFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 8, child: Text('8/页')),
            DropdownMenuItem(value: 20, child: Text('20/页')),
            DropdownMenuItem(value: 50, child: Text('50/页')),
          ],
          onChanged: (v) => onChanged(v ?? 8),
        ),
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int current;
  final int total;
  final int totalItems;
  final ValueChanged<int> onChanged;
  const _PaginationBar({
    required this.current,
    required this.total,
    required this.totalItems,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            '共 $totalItems 条',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          IconButton(
            onPressed: current > 1 ? () => onChanged(current - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('$current / $total'),
          IconButton(
            onPressed: current < total ? () => onChanged(current + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends ConsumerWidget {
  final Task task;
  const _TaskRow({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(task.status);
    final selectedId =
        ref.watch(currentTaskProvider.select((v) => v.value?.id));
    final isSelected = selectedId == task.id;
    return InkWell(
      onTap: () {
        final notifier = ref.read(currentTaskProvider.notifier);
        notifier.setCurrentTask(task);
        notifier.loadTask(task.id, keepCurrent: true);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.35)
                : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black)
                  .withOpacity(isSelected ? 0.14 : 0.04),
              blurRadius: isSelected ? 20 : 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child:
                        Icon(_iconForTask(task), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      task.fileName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 88;
                  return Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 6 : 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: statusColor.withOpacity(0.25)),
                      ),
                      child: compact
                          ? Text(
                              _statusShortLabel(task.status),
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _statusLabel(task.status),
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: statusColor,
                                      ),
                                ),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${task.progress}%',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: (task.progress / 100).clamp(0, 1),
                        backgroundColor:
                            Theme.of(context).dividerColor.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        _formatDate(task.createdAt),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (task.status == TaskStatus.failed)
                      IconButton(
                        tooltip: '重试任务',
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        onPressed: () async {
                          try {
                            await ref
                                .read(taskListProvider.notifier)
                                .retryTask(task.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('任务已重试')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              final message = e.toString();
                              if (message.contains('当前无可用本地模型')) {
                                await showDialog<void>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) =>
                                      const _RetryNeedsModelDialog(),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            }
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => ref
                          .read(taskListProvider.notifier)
                          .deleteTask(task.id),
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
}

class _RetryNeedsModelDialog extends StatelessWidget {
  const _RetryNeedsModelDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 140, vertical: 120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF256AF4).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.memory_rounded,
                    color: Color(0xFF256AF4),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    '重试前需要先下载模型',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              '当前机器没有可用的本地识别模型，所以任务不能直接重试。先到“模型与API”页面下载模型，完成后再返回任务列表继续操作。',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/settings');
                  },
                  child: const Text('去下载模型'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          '还没有任务，先去新建一个转写任务吧。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _InspectorPanel extends ConsumerStatefulWidget {
  const _InspectorPanel();

  @override
  ConsumerState<_InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends ConsumerState<_InspectorPanel> {
  final AudioPlayer _player = AudioPlayer();
  final ExportService _exporter = ExportService();
  String? _audioError;
  bool _showAllSegments = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadAudio(Task task) async {
    if (task.filePath.isEmpty || !File(task.filePath).existsSync()) {
      if (_audioError != '音频文件不存在或已移动') {
        setState(() => _audioError = '音频文件不存在或已移动');
      }
      return;
    }
    try {
      await _player.setFilePath(task.filePath);
      if (_audioError != null) {
        setState(() => _audioError = null);
      }
    } catch (e) {
      setState(() => _audioError = '音频加载失败: $e');
    }
  }

  Future<void> _export(Task task, String format) async {
    if ((task.transcription?.fullText ?? '').trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前没有可导出的转写内容')),
        );
      }
      return;
    }
    if (format == 'pdf') await _exporter.exportPdf(task);
    if (format == 'txt') await _exporter.exportTxt(task);
    if (format == 'json') await _exporter.exportJson(task);
  }

  Future<void> _jumpTo(double seconds) async {
    try {
      await _player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
      if (!_player.playing) {
        await _player.play();
      }
    } catch (_) {}
  }

  Future<void> _copyText(String label, String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label 暂无可复制内容')),
        );
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制$label')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(currentTaskProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: SelectionArea(
        child: taskAsync.when(
        data: (task) {
          if (task == null) {
            return Center(
              child: Text(
                '选择一个任务以查看详情',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            );
          }
          _loadAudio(task);
          final summary = task.summary;
          final summaryBody = _preferredSummaryText(summary);
          final keywords = _normalizedKeywords(summary?.keywords ?? []);
          final segments = task.transcription?.segments ?? [];
          final visibleCount =
              _showAllSegments ? segments.length : segments.length.clamp(0, 8);
          return ListView(
            children: [
              Text(
                '任务工作区',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                task.fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InspectorCard(
                      title: '状态',
                      value: '${_statusLabel(task.status)} (${task.progress}%)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InspectorCard(
                      title: '模型',
                      value: task.model,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InspectorCard(
                      title: '语言',
                      value: task.language,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InspectorCard(
                      title: '来源',
                      value: task.provider,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _ExportChip(label: 'PDF', onTap: () => _export(task, 'pdf')),
                  const SizedBox(width: 8),
                  _ExportChip(label: 'TXT', onTap: () => _export(task, 'txt')),
                  const SizedBox(width: 8),
                  _ExportChip(
                    label: 'JSON',
                    onTap: () => _export(task, 'json'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExportChip(
                    label: '复制摘要',
                    onTap: () => _copyText('摘要', summaryBody),
                  ),
                  _ExportChip(
                    label: '复制要点',
                    onTap: () =>
                        _copyText('要点', (summary?.keyPoints ?? []).join('\n')),
                  ),
                  _ExportChip(
                    label: '复制全文',
                    onTap: () => _copyText(
                      '转写全文',
                      task.transcription?.fullText ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _PlayerBar(player: _player, errorText: _audioError),
              const SizedBox(height: 16),
              _SectionTitle(
                title: '重点摘要',
                trailing: summaryBody.trim().isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _copyText('摘要', summaryBody),
                        child: const Text('复制'),
                      ),
              ),
              const SizedBox(height: 8),
              _SummaryPanel(summary: summary, keywords: keywords),
              const SizedBox(height: 14),
              _SectionTitle(
                title: '完整原文',
                trailing: (task.transcription?.fullText ?? '').trim().isEmpty
                    ? null
                    : TextButton(
                        onPressed: () => _copyText(
                          '转写全文',
                          task.transcription?.fullText ?? '',
                        ),
                        child: const Text('复制全文'),
                      ),
              ),
              const SizedBox(height: 8),
              _StructuredContentCard(
                text: task.transcription?.fullText ?? '',
                emptyText: '暂无转写内容',
              ),
              const SizedBox(height: 14),
              const _SectionTitle(title: '流程日志'),
              const SizedBox(height: 8),
              _WorkflowLogCard(steps: task.steps),
              const SizedBox(height: 14),
              _SectionTitle(
                title: '分段时间轴',
                trailing: segments.isEmpty
                    ? null
                    : TextButton(
                        onPressed: () =>
                            setState(() => _showAllSegments = !_showAllSegments),
                        child: Text(
                          _showAllSegments ? '收起' : '查看全部 (${segments.length})',
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              _SegmentTimelineCard(
                segments: segments,
                visibleCount: visibleCount,
                onJumpTo: _jumpTo,
                onCopyText: _copyText,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('加载失败: $e'),
        ),
      )),
    );
  }
}

class _InspectorCard extends StatelessWidget {
  final String title;
  final String value;
  const _InspectorCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionTitle({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.3,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final SummaryResult? summary;
  final List<String> keywords;
  const _SummaryPanel({required this.summary, required this.keywords});

  @override
  Widget build(BuildContext context) {
    final keyPoints =
        summary?.keyPoints.where((e) => e.trim().isNotEmpty).toList() ?? [];
    final lead = summary?.short.trim() ?? '';
    final detail = _preferredSummaryText(summary);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lead.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF256AF4).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: const Color(0xFF256AF4).withOpacity(0.12)),
              ),
              child: SelectableText(
                lead,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.7,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          if (keyPoints.isNotEmpty) ...[
            Text(
              '要点',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            ...keyPoints.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 7),
                      decoration: const BoxDecoration(
                        color: Color(0xFF256AF4),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        point,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.7,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (keywords.isNotEmpty) ...[
            Text(
              '关键词',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: keywords.map((k) => _TagChip(label: k)).toList(),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            '完整摘要',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          _StructuredTextView(
            text: detail,
            emptyText: '暂无摘要内容',
          ),
        ],
      ),
    );
  }
}

class _StructuredContentCard extends StatelessWidget {
  final String text;
  final String emptyText;
  const _StructuredContentCard({
    required this.text,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _StructuredTextView(
        text: text,
        emptyText: emptyText,
      ),
    );
  }
}

class _StructuredTextView extends StatelessWidget {
  final String text;
  final String emptyText;
  const _StructuredTextView({
    required this.text,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) {
      return Text(
        emptyText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
      );
    }
    final lines = cleaned
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) => _StructuredLine(line: line)).toList(),
    );
  }
}

class _StructuredLine extends StatelessWidget {
  final String line;
  const _StructuredLine({required this.line});

  @override
  Widget build(BuildContext context) {
    final heading = RegExp(r'^\s*#{1,6}\s+').firstMatch(line);
    final ordered = RegExp(r'^\s*(\d+)\.\s+').firstMatch(line);
    final unordered = RegExp(r'^\s*[-*]\s+').firstMatch(line);
    if (heading != null) {
      final text = line.replaceFirst(heading.group(0)!, '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SelectableText(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.5,
              ),
        ),
      );
    }
    if (ordered != null) {
      final prefix = ordered.group(1)!;
      final text = line.replaceFirst(ordered.group(0)!, '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$prefix.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.7,
                    ),
              ),
            ),
            Expanded(
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.7,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    if (unordered != null) {
      final text = line.replaceFirst(unordered.group(0)!, '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 8, right: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.7,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SelectableText(
        line,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.8,
            ),
      ),
    );
  }
}

class _WorkflowLogCard extends StatelessWidget {
  final List<WorkflowStep> steps;
  const _WorkflowLogCard({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: steps.isEmpty
          ? const Text('暂无流程日志')
          : Column(
              children: steps.take(6).map((step) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.name,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      Text(
                        '${step.status.name} · ${step.progress}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _SegmentTimelineCard extends StatelessWidget {
  final List<Segment> segments;
  final int visibleCount;
  final Future<void> Function(double seconds) onJumpTo;
  final Future<void> Function(String label, String text) onCopyText;

  const _SegmentTimelineCard({
    required this.segments,
    required this.visibleCount,
    required this.onJumpTo,
    required this.onCopyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: segments.isEmpty
          ? const Text('暂无转写分段')
          : Column(
              children: List.generate(visibleCount, (index) {
                final s = segments[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => onJumpTo(s.startTime),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '[${_formatTime(s.startTime)}] ${s.text}',
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '跳转到此处播放',
                        icon: const Icon(Icons.play_circle_outline, size: 18),
                        onPressed: () => onJumpTo(s.startTime),
                      ),
                      IconButton(
                        tooltip: '复制本段',
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        onPressed: () => onCopyText('本段', s.text),
                      ),
                    ],
                  ),
                );
              }),
            ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ExportChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExportChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  final AudioPlayer player;
  final String? errorText;
  const _PlayerBar({required this.player, this.errorText});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = player.duration ?? Duration.zero;
        final progress = duration.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (errorText != null) ...[
                Text(
                  errorText!,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFB91C1C)),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      if (player.playing) {
                        await player.pause();
                      } else {
                        await player.play();
                      }
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF256AF4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        player.playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: progress.isNaN ? 0 : progress,
                            alignment: Alignment.centerLeft,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF256AF4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position),
                                style: const TextStyle(fontSize: 10)),
                            Text(_formatDuration(duration),
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _statusColor(TaskStatus status) {
  switch (status) {
    case TaskStatus.completed:
      return const Color(0xFF10B981);
    case TaskStatus.processing:
      return const Color(0xFF256AF4);
    case TaskStatus.failed:
      return const Color(0xFFF43F5E);
    case TaskStatus.pending:
      return const Color(0xFF94A3B8);
  }
}

String _statusLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.completed:
      return '已完成';
    case TaskStatus.processing:
      return '转写中';
    case TaskStatus.failed:
      return '失败';
    case TaskStatus.pending:
      return '待处理';
  }
}

String _statusShortLabel(TaskStatus status) {
  switch (status) {
    case TaskStatus.completed:
      return '完成';
    case TaskStatus.processing:
      return '进行';
    case TaskStatus.failed:
      return '失败';
    case TaskStatus.pending:
      return '待办';
  }
}

IconData _iconForTask(Task task) {
  final lower = task.fileName.toLowerCase();
  if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return Icons.videocam;
  return Icons.audio_file;
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _formatTime(double seconds) {
  final total = seconds.floor();
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _formatDuration(Duration duration) {
  final total = duration.inSeconds;
  final m = (total ~/ 60).toString().padLeft(2, '0');
  final s = (total % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

String _preferredSummaryText(SummaryResult? summary) {
  if (summary == null) return '';
  final longText = summary.long.trim();
  if (longText.isNotEmpty) return longText;
  final mediumText = summary.medium.trim();
  if (mediumText.isNotEmpty) return mediumText;
  return summary.short.trim();
}

List<String> _normalizedKeywords(List<String> keywords) {
  final compact = <String>[];
  for (final raw in keywords) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 24 || compact.contains(value)) {
      continue;
    }
    compact.add(value);
  }
  return compact.take(12).toList();
}
