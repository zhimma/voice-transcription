import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/task_provider.dart';
import '../providers/config_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  List<File> _selectedFiles = [];
  String _selectedModel = 'small';
  String _selectedLanguage = 'auto';
  bool _generateSummary = true;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _models = [
    {'name': 'tiny', 'size': 39, 'desc': '快速预览'},
    {'name': 'base', 'size': 74, 'desc': '平衡速度'},
    {'name': 'small', 'size': 244, 'desc': '推荐'},
    {'name': 'medium', 'size': 769, 'desc': '高精度'},
    {'name': 'large', 'size': 1550, 'desc': '最高精度'},
  ];

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.paths
            .where((path) => path != null)
            .map((path) => File(path!))
            .toList();
      });
    }
  }

  Future<void> _startTranscription() async {
    if (_selectedFiles.isEmpty) return;

    setState(() => _isLoading = true);

    final taskNotifier = ref.read(taskListProvider.notifier);

    try {
      for (final file in _selectedFiles) {
        final task = await taskNotifier.createTask(
          fileName: file.path.split('/').last,
          filePath: file.path,
          fileSize: file.lengthSync(),
          model: _selectedModel,
          language: _selectedLanguage,
          generateSummary: _generateSummary,
        );

        // 跳转到任务详情
        context.go('/task/${task.id}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建任务失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('上传转写'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: configAsync.when(
        data: (config) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUploadZone(),
              const SizedBox(height: 24),
              if (_selectedFiles.isNotEmpty) ...[
                _buildFileList(),
                const SizedBox(height: 24),
                _buildConfigSection(config),
                const SizedBox(height: 24),
                _buildStartButton(),
              ],
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载配置失败: $e')),
      ),
    );
  }

  Widget _buildUploadZone() {
    return GestureDetector(
      onTap: _pickFiles,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('点击或拖拽音频文件到此处',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('支持 MP3, WAV, M4A, AAC, FLAC, OGG',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('已选择 ${_selectedFiles.length} 个文件',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._selectedFiles.map((file) => ListTile(
                  leading: const Icon(Icons.audio_file),
                  title: Text(file.path.split('/').last),
                  subtitle: Text(_formatFileSize(file.lengthSync())),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedFiles.remove(file)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigSection(dynamic config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('转写配置', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Text('选择模型', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _models.map((model) {
                final selected = _selectedModel == model['name'];
                return ChoiceChip(
                  label: Text('${model['name']} (${model['size']}MB)'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedModel = model['name']),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: '识别语言',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('自动检测')),
                DropdownMenuItem(value: 'zh', child: Text('中文')),
                DropdownMenuItem(value: 'en', child: Text('英文')),
              ],
              onChanged: (v) => setState(() => _selectedLanguage = v!),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('自动生成摘要'),
              value: _generateSummary,
              onChanged: (v) => setState(() => _generateSummary = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _startTranscription,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow),
        label: Text(_isLoading ? '创建中...' : '开始转写'),
      ),
    );
  }
}
