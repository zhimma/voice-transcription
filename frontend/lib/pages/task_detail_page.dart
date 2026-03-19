import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../providers/task_provider.dart';
import '../services/export_service.dart';
import '../models/task.dart';
import '../ui/desktop_subpage_header.dart';

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

  @override
  void initState() {
    super.initState();
    _loadTask();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      final task = ref.read(currentTaskProvider).value;
      if (task == null) return;
      if (task.status == TaskStatus.pending || task.status == TaskStatus.processing) {
        ref.read(currentTaskProvider.notifier).refresh();
      }
    });
  }

  Future<void> _loadTask() async {
    await ref.read(currentTaskProvider.notifier).loadTask(widget.taskId);
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              _DetailTopBar(
                taskAsync: taskAsync,
                exportEnabled: task != null,
                onExport: (format) => _handleExport(task, format),
                onOpenExportMenu: () => _openExportMenu(task),
              ),
              Expanded(
                child: taskAsync.when(
                  data: (task) {
                    if (task == null) {
                      return _EmptyState(
                        title: '任务不存在',
                        subtitle: '任务可能已被删除或尚未创建完成。',
                        onRetry: _loadTask,
                      );
                    }
                    _loadAudio(task.filePath);
                    return _DetailBody(task: task, player: _player, audioError: _audioError);
                  },
                  loading: () => const _EmptyState(
                    title: '加载中',
                    subtitle: '正在获取任务详情…',
                  ),
                  error: (e, _) => _EmptyState(
                    title: '加载失败',
                    subtitle: e.toString(),
                    onRetry: _loadTask,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: _AudioPlayerBar(player: _player),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(Task? task, String format) async {
    if (task == null) {
      _showMessage('任务还在加载，暂时无法导出');
      return;
    }
    if (task.status == TaskStatus.pending || task.status == TaskStatus.processing) {
      _showMessage('任务仍在处理中，请稍后导出');
      return;
    }
    final hasText = (task.transcription?.fullText ?? '').trim().isNotEmpty;
    if (!hasText) {
      _showMessage('当前没有可导出的转写内容');
      return;
    }
    if (format == 'pdf') await _exportService.exportPdf(task);
    if (format == 'txt') await _exportService.exportTxt(task);
    if (format == 'json') await _exportService.exportJson(task);
  }

  Future<void> _openExportMenu(Task? task) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ExportSheetItem(
                  label: '导出为 PDF',
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleExport(task, 'pdf');
                  },
                ),
                _ExportSheetItem(
                  label: '导出为 TXT',
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleExport(task, 'txt');
                  },
                ),
                _ExportSheetItem(
                  label: '导出为 JSON',
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleExport(task, 'json');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _DetailTopBar extends StatelessWidget {
  final AsyncValue<Task?> taskAsync;
  final ValueChanged<String> onExport;
  final VoidCallback onOpenExportMenu;
  final bool exportEnabled;

  const _DetailTopBar({
    required this.taskAsync,
    required this.onExport,
    required this.onOpenExportMenu,
    required this.exportEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final task = taskAsync.value;
    return Container(
      height: 64,
      padding: EdgeInsets.only(
        left: desktopWindowInsetLeft(),
        right: desktopWindowInsetRight(),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              } else {
                context.go('/');
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(Icons.arrow_back, size: 18, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task?.fileName ?? '转写详情', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                task?.createdAt != null ? '录制于 ${_formatDate(task!.createdAt)}' : '加载中',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), letterSpacing: 1.4, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              children: [
                _MiniExportButton(
                  label: 'PDF',
                  enabled: exportEnabled,
                  onTap: () => onExport('pdf'),
                ),
                _MiniExportButton(
                  label: 'TXT',
                  enabled: exportEnabled,
                  onTap: () => onExport('txt'),
                ),
                _MiniExportButton(
                  label: 'JSON',
                  enabled: exportEnabled,
                  onTap: () => onExport('json'),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: exportEnabled ? onOpenExportMenu : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: exportEnabled ? const Color(0xFF256AF4) : const Color(0xFFCBD5F5),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF256AF4).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: const [
                  Icon(Icons.ios_share, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text('导出', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFF256AF4).withOpacity(0.2), width: 2),
              color: const Color(0xFFE2E8F0),
            ),
            child: const Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _MiniExportButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  const _MiniExportButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: enabled ? const Color(0xFF94A3B8) : const Color(0xFFCBD5F5),
          ),
        ),
      ),
    );
  }
}

class _ExportSheetItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ExportSheetItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;
  const _EmptyState({required this.title, required this.subtitle, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B))),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Task task;
  final AudioPlayer player;
  final String? audioError;
  const _DetailBody({required this.task, required this.player, this.audioError});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TranscriptPanel(task: task)),
        SizedBox(width: 320, child: _InsightsPanel(audioError: audioError)),
      ],
    );
  }
}

class _TranscriptPanel extends StatelessWidget {
  final Task task;
  const _TranscriptPanel({required this.task});

  @override
  Widget build(BuildContext context) {
    final segments = task.transcription?.segments ?? [];
    if (segments.isEmpty) {
      return const Center(child: Text('暂无转写内容'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: segments.map((s) {
          return _TranscriptSegment(
            initials: 'SP',
            name: 'Speaker',
            time: _formatTime(s.startTime),
            color: const Color(0xFF256AF4),
            text: s.text,
          );
        }).toList(),
      ),
    );
  }
}

class _TranscriptSegment extends StatelessWidget {
  final String initials;
  final String name;
  final String time;
  final Color color;
  final String text;

  const _TranscriptSegment({
    required this.initials,
    required this.name,
    required this.time,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              const SizedBox(width: 10),
              Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFFCBD5F5), fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsPanel extends ConsumerWidget {
  final String? audioError;
  const _InsightsPanel({this.audioError});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(currentTaskProvider).value;
    final summary = task?.summary;
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFFF1F5F9))),
        color: Color(0xFFF8FAFC),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('AI 洞察', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 2.2)),
                Icon(Icons.auto_awesome, size: 18, color: Color(0xFF256AF4)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('摘要', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text('重新生成', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF256AF4))),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF256AF4).withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF256AF4).withOpacity(0.12)),
              ),
              child: Text(
                summary?.medium ?? '暂无摘要内容',
                style: const TextStyle(fontSize: 11, height: 1.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            if (audioError != null) ...[
              const Text('播放状态', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Text(audioError!, style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
              ),
              const SizedBox(height: 20),
            ],
            const Text('要点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            ...(summary?.keyPoints ?? ['暂无要点']).map((item) => _InsightBullet(color: const Color(0xFF3B82F6), text: item)).toList(),
            const SizedBox(height: 20),
            const Text('关键词', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (summary?.keywords ?? ['暂无关键词'])
                  .map((k) => _KeywordChip(label: k))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightBullet extends StatelessWidget {
  final Color color;
  final String text;
  const _InsightBullet({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _KeywordChip extends StatelessWidget {
  final String label;
  const _KeywordChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 1.0),
      ),
    );
  }
}

class _AudioPlayerBar extends StatelessWidget {
  final AudioPlayer player;
  const _AudioPlayerBar({required this.player});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: StreamBuilder<Duration>(
          stream: player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = player.duration ?? Duration.zero;
            final progress = duration.inMilliseconds == 0
                ? 0.0
                : position.inMilliseconds / duration.inMilliseconds;
            return Row(
              children: [
                Row(
                  children: [
                    _ControlIcon(icon: Icons.skip_previous, onTap: () {}),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () async {
                        if (player.playing) {
                          await player.pause();
                        } else {
                          await player.play();
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFF256AF4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(player.playing ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _ControlIcon(icon: Icons.skip_next, onTap: () {}),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(position), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                          const Text('当前：Speaker', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF256AF4), letterSpacing: 1.2)),
                          Text(_formatDuration(duration), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: progress.isNaN ? 0 : progress,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF256AF4),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: const [
                    _SpeedPill(label: '0.5x'),
                    SizedBox(width: 6),
                    _SpeedPill(label: '1.0x', active: true),
                    SizedBox(width: 6),
                    _SpeedPill(label: '1.5x'),
                  ],
                ),
                const SizedBox(width: 16),
                _ControlIcon(icon: Icons.volume_up, onTap: () {}),
                const SizedBox(width: 6),
                _ControlIcon(icon: Icons.bookmarks, onTap: () {}),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ControlIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  final String label;
  final bool active;
  const _SpeedPill({required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: active ? const Color(0xFF256AF4) : const Color(0xFFE2E8F0)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: active ? const Color(0xFF256AF4) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${duration.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
}

String _formatTime(double seconds) {
  final d = Duration(seconds: seconds.floor());
  return _formatDuration(d);
}
