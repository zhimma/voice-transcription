import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/task_provider.dart';
import '../providers/config_provider.dart';
import '../ffi/native_service.dart';
import '../ui/app_shell.dart';

class UploadPage extends ConsumerStatefulWidget {
  final bool embedded;
  const UploadPage({super.key, this.embedded = false});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  String? _filePath;
  String? _fileName;
  int? _fileSize;
  String? _hint;
  String _language = 'auto';
  String _quality = 'balanced';
  String? _error;
  bool _dragging = false;
  bool _submitting = false;

  static const _allowed = {
    'mp3',
    'wav',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'opus',
    'wma',
    'aiff',
    'aif',
    'caf',
    'mp4',
    'm4b',
    'amr',
    '3gp',
  };

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _allowed.toList(),
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;
    await _setFile(file.path!);
  }

  Future<void> _setFile(String path) async {
    final ext = path.split('.').last.toLowerCase();
    if (!_allowed.contains(ext)) {
      setState(() {
        _error = '不支持的文件格式';
      });
      return;
    }
    final f = File(path);
    final size = await f.length();
    if (size > 500 * 1024 * 1024) {
      setState(() {
        _error = '文件超过 500MB 限制';
      });
      return;
    }
    var hint = '文件大小 ${_formatBytes(size)}，可直接开始处理。';
    if (size > 200 * 1024 * 1024) {
      hint = '大文件（${_formatBytes(size)}）：建议使用“平衡（中等）”质量，处理更稳定。';
      if (_quality == 'hd') {
        _quality = 'balanced';
      }
    }
    setState(() {
      _error = null;
      _filePath = path;
      _fileName = path.split('/').last;
      _fileSize = size;
      _hint = hint;
    });
  }

  Future<void> _createTask() async {
    if (_submitting) return;
    if (_filePath == null || _fileName == null || _fileSize == null) {
      setState(() => _error = '请先选择文件');
      return;
    }
    setState(() => _submitting = true);
    final model = _quality == 'balanced' ? 'base' : 'small';
    const provider = 'whisper';

    try {
      final models = await NativeService.getModels();
      final list = (models['models'] as List?)?.cast<Map>() ?? [];
      final found = list.firstWhere(
        (m) => m['name']?.toString() == model,
        orElse: () => <String, dynamic>{},
      );
      final downloaded =
          found.isNotEmpty && found['status']?.toString() == 'downloaded';
      if (!downloaded) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = '当前模型未下载，请先在“模型与API”页面下载模型';
        });
        final go = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _MissingModelDialog(model: model),
        );
        if (go == true && mounted) {
          context.go('/settings');
        }
        return;
      }

      final task = await ref.read(taskListProvider.notifier).createTask(
            fileName: _fileName!,
            filePath: _filePath!,
            fileSize: _fileSize!,
            model: model,
            provider: provider,
            language: _language,
            generateSummary: true,
            summaryLength: 'medium',
            enableConversationAnalysis: true,
          );

      await ref.read(configProvider.notifier).addRecentFile(_filePath!);
      await ref.read(currentTaskProvider.notifier).loadTask(task.id);
      if (!mounted) return;
      await ref.read(taskListProvider.notifier).loadTasks(silent: true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务已创建，正在处理。可在任务管理查看实时进度。')),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '创建任务失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('创建失败，请检查配置后重试')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _NewTaskCard(
        dragging: _dragging,
        fileName: _fileName,
        fileSize: _fileSize,
        hint: _hint,
        error: _error,
        onPick: _pickFile,
        onStart: _createTask,
        submitting: _submitting,
        onDragState: (value) => setState(() => _dragging = value),
        onDrop: (path) async => _setFile(path),
        language: _language,
        quality: _quality,
        onLanguageChanged: (value) => setState(() => _language = value),
        onQualityChanged: (value) => setState(() => _quality = value),
      ),
    );
    if (widget.embedded) return content;
    return AppShell(
      active: AppNavItem.newTask,
      title: '新建任务',
      child: content,
    );
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _MissingModelDialog extends StatelessWidget {
  final String model;

  const _MissingModelDialog({required this.model});

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
                    '需要先下载本地识别模型',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              '当前任务需要使用“$model”模型，但本机还没有准备好对应文件。先完成下载，再开始识别，流程才是可用的。',
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '接下来会发生什么',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 10),
                  Text('1. 跳转到“模型与API”页面'),
                  SizedBox(height: 4),
                  Text('2. 打开模型下载进度弹窗'),
                  SizedBox(height: 4),
                  Text('3. 下载完成后返回任务页继续识别'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('稍后再说'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
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

class _NewTaskCard extends StatelessWidget {
  final bool dragging;
  final String? fileName;
  final int? fileSize;
  final String? hint;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback onStart;
  final bool submitting;
  final ValueChanged<bool> onDragState;
  final ValueChanged<String> onDrop;
  final String language;
  final String quality;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onQualityChanged;

  const _NewTaskCard({
    required this.dragging,
    required this.fileName,
    required this.fileSize,
    required this.hint,
    required this.error,
    required this.onPick,
    required this.onStart,
    required this.submitting,
    required this.onDragState,
    required this.onDrop,
    required this.language,
    required this.quality,
    required this.onLanguageChanged,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          _CardHeader(),
          _CompactBody(
            dragging: dragging,
            fileName: fileName,
            fileSize: fileSize,
            hint: hint,
            error: error,
            onPick: onPick,
            onDragState: onDragState,
            onDrop: onDrop,
            language: language,
            quality: quality,
            onLanguageChanged: onLanguageChanged,
            onQualityChanged: onQualityChanged,
          ),
          _CardFooter(onStart: onStart, submitting: submitting),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('新建转写',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text('秒级将媒体转换为文本',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
          const Spacer(),
          const Text(
            '标准模式：本地识别 + 摘要可走远端',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _CompactBody extends StatelessWidget {
  final bool dragging;
  final String? fileName;
  final int? fileSize;
  final String? hint;
  final String? error;
  final VoidCallback onPick;
  final ValueChanged<bool> onDragState;
  final ValueChanged<String> onDrop;
  final String language;
  final String quality;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onQualityChanged;

  const _CompactBody({
    required this.dragging,
    required this.fileName,
    required this.fileSize,
    required this.hint,
    required this.error,
    required this.onPick,
    required this.onDragState,
    required this.onDrop,
    required this.language,
    required this.quality,
    required this.onLanguageChanged,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: _DropZone(
              dragging: dragging,
              fileName: fileName,
              fileSize: fileSize,
              hint: hint,
              error: error,
              onPick: onPick,
              onDragState: onDragState,
              onDrop: onDrop,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fileName != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '已选文件：$fileName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                _LeftSettings(
                  language: language,
                  onLanguageChanged: onLanguageChanged,
                ),
                const SizedBox(height: 12),
                _RightSettings(
                  quality: quality,
                  onQualityChanged: onQualityChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DropZone extends StatelessWidget {
  final bool dragging;
  final String? fileName;
  final int? fileSize;
  final String? hint;
  final String? error;
  final VoidCallback onPick;
  final ValueChanged<bool> onDragState;
  final ValueChanged<String> onDrop;

  const _DropZone({
    required this.dragging,
    required this.fileName,
    required this.fileSize,
    required this.hint,
    required this.error,
    required this.onPick,
    required this.onDragState,
    required this.onDrop,
  });

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => onDragState(true),
      onDragExited: (_) => onDragState(false),
      onDragDone: (details) {
        onDragState(false);
        if (details.files.isNotEmpty) {
          onDrop(details.files.first.path);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: dragging
                ? const Color(0xFF256AF4)
                : const Color(0xFF256AF4).withOpacity(0.3),
            width: 2,
          ),
          gradient: const LinearGradient(
            colors: [Color(0x142563EB), Color(0x007C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2463EB), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2463EB).withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.upload_file, color: Colors.white, size: 34),
              ],
            ),
            const SizedBox(height: 14),
            Text(fileName ?? '准备开始转写？',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (fileSize != null) ...[
              const SizedBox(height: 6),
              Text(
                '已选择 ${_formatBytes(fileSize!)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              '拖拽音频或视频到此处。\nMP3, WAV, M4A, MP4（最大 500MB）',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ] else if (hint != null) ...[
              const SizedBox(height: 10),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF256AF4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            InkWell(
              onTap: onPick,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text('浏览文件',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}

class _SettingsGrid extends StatelessWidget {
  final String language;
  final String quality;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<String> onQualityChanged;

  const _SettingsGrid({
    required this.language,
    required this.quality,
    required this.onLanguageChanged,
    required this.onQualityChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
              child: _LeftSettings(
                  language: language, onLanguageChanged: onLanguageChanged)),
          const SizedBox(width: 32),
          Expanded(
              child: _RightSettings(
                  quality: quality, onQualityChanged: onQualityChanged)),
        ],
      ),
    );
  }
}

class _LeftSettings extends StatelessWidget {
  final String language;
  final ValueChanged<String> onLanguageChanged;

  const _LeftSettings({
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
            icon: Icons.language, color: const Color(0xFF6366F1), label: '语言'),
        const SizedBox(height: 12),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: language,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动识别（推荐）')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('英语')),
                DropdownMenuItem(value: 'ja', child: Text('日语')),
              ],
              onChanged: (value) => onLanguageChanged(value ?? 'auto'),
            ),
          ),
        ),
      ],
    );
  }
}

class _RightSettings extends StatelessWidget {
  final String quality;
  final ValueChanged<String> onQualityChanged;

  const _RightSettings({required this.quality, required this.onQualityChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
            icon: Icons.auto_awesome,
            color: const Color(0xFFF59E0B),
            label: '处理质量'),
        const SizedBox(height: 12),
        _QualityOption(
          title: '平衡（中等）',
          subtitle: '速度与准确率均衡',
          selected: quality == 'balanced',
          accent: const Color(0xFF256AF4),
          onTap: () => onQualityChanged('balanced'),
        ),
        const SizedBox(height: 12),
        _QualityOption(
          title: '高保真（大型）',
          subtitle: '复杂音频最高精度',
          selected: quality == 'hd',
          accent: const Color(0xFF6366F1),
          onTap: () => onQualityChanged('hd'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionLabel(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _QualityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _QualityOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(0.04) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  selected ? accent.withOpacity(0.4) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
                color: selected ? accent : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selected ? accent : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFooter extends StatelessWidget {
  final VoidCallback onStart;
  final bool submitting;
  const _CardFooter({required this.onStart, required this.submitting});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        color: Color(0xFFF8FAFC),
      ),
      child: Row(
        children: [
          Row(
            children: [
              if (submitting)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.info_outline,
                    size: 13, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(
                submitting ? '任务创建中…' : '开始后可在任务管理查看实时进度',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B)),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: submitting ? null : () {},
            child: const Text('取消',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8))),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: submitting ? null : onStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2463EB), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2463EB).withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(submitting ? '提交中…' : '开始转写',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  const SizedBox(width: 8),
                  Icon(
                    submitting ? Icons.hourglass_top : Icons.arrow_forward,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterMeta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.verified_user, size: 14, color: Color(0xFF22C55E)),
        SizedBox(width: 6),
        Text('数据在本地处理',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600)),
        SizedBox(width: 16),
        Text('版本 2.4.0',
            style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
