import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/config_provider.dart';
import '../ffi/native_service.dart';
import '../models/channel.dart';
import '../services/config_service.dart';
import '../ui/app_shell.dart';

class SettingsPage extends ConsumerWidget {
  final bool embedded;
  const SettingsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (embedded) return const _SettingsContent();
    return AppShell(
      active: AppNavItem.models,
      title: '模型与API',
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends ConsumerStatefulWidget {
  const _SettingsContent();

  @override
  ConsumerState<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends ConsumerState<_SettingsContent> {
  bool _jsonMode = false;
  bool _hideSecrets = true;
  final TextEditingController _jsonEditor = TextEditingController();

  @override
  void dispose() {
    _jsonEditor.dispose();
    super.dispose();
  }

  void _reloadJsonPreview() {
    _jsonEditor.text = ref
        .read(configProvider.notifier)
        .exportToString(hideSecrets: _hideSecrets);
  }

  Future<void> _saveJson() async {
    final msg = await ref
        .read(configProvider.notifier)
        .importFromString(_jsonEditor.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(configProvider);
    final exported = ref.read(configProvider.notifier).exportToString(
          hideSecrets: _hideSecrets,
        );
    if (exported.isNotEmpty && _jsonEditor.text.isEmpty) {
      _jsonEditor.text = exported;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      child: configAsync.when(
        data: (config) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _SectionHeader(
                    title: '模型与API',
                    subtitle: '统一管理模型、接口与配置。',
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: _jsonMode ? '切换到可视化配置' : '切换到 JSON 配置',
                    onPressed: () {
                      setState(() {
                        _jsonMode = !_jsonMode;
                      });
                      if (_jsonMode) {
                        _reloadJsonPreview();
                      }
                    },
                    icon: Icon(
                      _jsonMode
                          ? Icons.tune_rounded
                          : Icons.data_object_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_jsonMode)
                _JsonEditorCard(
                  controller: _jsonEditor,
                  hideSecrets: _hideSecrets,
                  onToggleSecrets: () {
                    setState(() => _hideSecrets = !_hideSecrets);
                    _reloadJsonPreview();
                  },
                  onReload: _reloadJsonPreview,
                  onSave: _saveJson,
                )
              else ...[
                Row(
                  children: [
                    Expanded(child: _LabeledSelect(label: '语言', value: '中文')),
                    const SizedBox(width: 32),
                    Expanded(
                        child: _LabeledSelect(
                            label: '导出格式', value: 'PDF / TXT / JSON')),
                  ],
                ),
                const SizedBox(height: 24),
                _AppearanceSelector(),
                const SizedBox(height: 24),
                _PathSelector(config: config),
                const SizedBox(height: 16),
                const _RuntimeNotice(),
                const SizedBox(height: 48),
                _SectionHeader(title: '云端集成', subtitle: '安全连接高性能推理引擎。'),
                const SizedBox(height: 20),
                _CloudApiForm(config: config),
                const SizedBox(height: 48),
                _LocalModelsHeader(),
                const SizedBox(height: 12),
                _LocalDownloadSourceCard(config: config),
                const SizedBox(height: 12),
                _LocalModelList(),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('加载失败: $e'),
      ),
    );
  }
}

class _RuntimeNotice extends StatelessWidget {
  const _RuntimeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, size: 16, color: Color(0xFF256AF4)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '桌面端已内置 Python 运行时与数据库组件，用户无需额外安装依赖即可使用。',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonEditorCard extends StatelessWidget {
  final TextEditingController controller;
  final bool hideSecrets;
  final VoidCallback onToggleSecrets;
  final VoidCallback onReload;
  final VoidCallback onSave;

  const _JsonEditorCard({
    required this.controller,
    required this.hideSecrets,
    required this.onToggleSecrets,
    required this.onReload,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 620,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.data_object_rounded,
                  size: 16, color: Color(0xFF256AF4)),
              const SizedBox(width: 8),
              const Text(
                'JSON 配置',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToggleSecrets,
                child: Text(hideSecrets ? '显示密钥' : '隐藏密钥'),
              ),
              TextButton(onPressed: onReload, child: const Text('刷新')),
              FilledButton(onPressed: onSave, child: const Text('保存')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                minLines: null,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ],
    );
  }
}

class _LabeledSelect extends StatelessWidget {
  final String label;
  final String value;
  const _LabeledSelect({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.4)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Expanded(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600))),
              const Icon(Icons.unfold_more, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppearanceSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('外观',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.4)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF256AF4), width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.light_mode, color: Color(0xFF256AF4)),
                    SizedBox(width: 8),
                    Text('浅色',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF256AF4))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.dark_mode, color: Color(0xFF94A3B8)),
                    SizedBox(width: 8),
                    Text('深色',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PathSelector extends ConsumerStatefulWidget {
  final AppConfig config;
  const _PathSelector({required this.config});

  @override
  ConsumerState<_PathSelector> createState() => _PathSelectorState();
}

class _PathSelectorState extends ConsumerState<_PathSelector> {
  bool _saving = false;

  Future<void> _pickDir() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择模型存储目录',
    );
    if (dir == null || dir.trim().isEmpty) return;
    setState(() => _saving = true);
    final updated = widget.config.copyWith(
      transcription: widget.config.transcription.copyWith(
        local: widget.config.transcription.local.copyWith(
          modelRootDir: dir.trim(),
        ),
      ),
    );
    await ref.read(configProvider.notifier).saveConfig(updated);
    await NativeService.restart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('模型存储目录已更新，模型状态已重新扫描')),
    );
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final modelPath = widget.config.transcription.local.modelRootDir;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('模型存储目录',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF94A3B8),
                letterSpacing: 1.4)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                (modelPath == null || modelPath.trim().isEmpty)
                    ? '~/.voice-transcription/models'
                    : modelPath,
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _pickDir,
              child: Text(
                _saving ? '保存中...' : '更改',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF256AF4),
                    letterSpacing: 1.4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '按模型尺寸自动分目录：tiny / base / small / medium / large-v3',
          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
        ),
        const Divider(color: Color(0xFFE2E8F0)),
      ],
    );
  }
}

class _CloudApiForm extends ConsumerStatefulWidget {
  final AppConfig config;
  const _CloudApiForm({required this.config});

  @override
  ConsumerState<_CloudApiForm> createState() => _CloudApiFormState();
}

class _CloudApiFormState extends ConsumerState<_CloudApiForm> {
  late final TextEditingController _qwenKey;
  late final TextEditingController _qwenUrl;
  late final TextEditingController _qwenSummaryModel;
  bool _testingQwen = false;
  String? _qwenStatus;

  @override
  void initState() {
    super.initState();
    final qwen = widget.config.summary.channels.firstWhere(
      (c) => c.provider == 'qwen',
      orElse: () => const ChannelConfig(
        id: 'summary-qwen',
        name: 'Qwen 摘要',
        type: ChannelType.api,
        provider: 'qwen',
        enabled: false,
        priority: 1,
        config: {},
      ),
    );
    _qwenKey =
        TextEditingController(text: qwen.config['api_key']?.toString() ?? '');
    _qwenUrl = TextEditingController(
      text: qwen.config['api_url']?.toString() ??
          'https://dashscope.aliyuncs.com/compatible-mode/v1',
    );
    _qwenSummaryModel = TextEditingController(
      text: qwen.config['model']?.toString() ?? 'qwen3.5-plus',
    );
  }

  @override
  void dispose() {
    _qwenKey.dispose();
    _qwenUrl.dispose();
    _qwenSummaryModel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final summaryChannels = <ChannelConfig>[
      ChannelConfig(
        id: 'summary-qwen',
        name: 'Qwen 摘要',
        type: ChannelType.api,
        provider: 'qwen',
        enabled: _qwenKey.text.trim().isNotEmpty,
        priority: 1,
        config: {
          'api_key': _qwenKey.text.trim(),
          'api_url': _qwenUrl.text.trim(),
          'model': _qwenSummaryModel.text.trim().isEmpty
              ? 'qwen3.5-plus'
              : _qwenSummaryModel.text.trim(),
        },
      ),
      const ChannelConfig(
        id: 'summary-local',
        name: '本地摘要',
        type: ChannelType.local,
        provider: 'local',
        enabled: true,
        priority: 2,
        config: {},
      ),
    ];

    final updated = widget.config.copyWith(
      transcription: widget.config.transcription.copyWith(cloudChannels: []),
      summary: widget.config.summary.copyWith(channels: summaryChannels),
    );
    await ref.read(configProvider.notifier).saveConfig(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Qwen 云端配置已保存')),
    );
  }

  Future<void> _testQwen() async {
    setState(() {
      _testingQwen = true;
      _qwenStatus = null;
    });
    final result = await ConfigService().testChannelDetailed(
      ChannelConfig(
        id: 'qwen',
        name: 'Qwen 摘要',
        type: ChannelType.api,
        provider: 'qwen',
        enabled: true,
        priority: 1,
        config: {
          'api_key': _qwenKey.text.trim(),
          'api_url': _qwenUrl.text.trim(),
          'model': _qwenSummaryModel.text.trim().isEmpty
              ? 'qwen3.5-plus'
              : _qwenSummaryModel.text.trim(),
        },
      ),
    );
    setState(() {
      _testingQwen = false;
      _qwenStatus = result.ok
          ? '连接成功'
          : (result.field == null
              ? result.message
              : '${result.message}（字段: ${result.field}）');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ApiCard(
          title: 'Qwen 摘要服务',
          subtitle: '仅用于云端文本摘要，不参与本地转写',
          keyController: _qwenKey,
          urlController: _qwenUrl,
          summaryModelController: _qwenSummaryModel,
          primary: true,
          testing: _testingQwen,
          statusText: _qwenStatus,
          onTest: _testQwen,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _save,
            child: const Text('保存 Qwen 配置',
                style: TextStyle(
                    color: Color(0xFF256AF4), fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

class _ApiCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController keyController;
  final TextEditingController urlController;
  final TextEditingController? summaryModelController;
  final bool primary;
  final bool testing;
  final String? statusText;
  final VoidCallback onTest;

  const _ApiCard({
    required this.title,
    required this.subtitle,
    required this.keyController,
    required this.urlController,
    this.summaryModelController,
    required this.primary,
    required this.testing,
    required this.statusText,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    final accent = primary ? const Color(0xFF256AF4) : const Color(0xFF8B5CF6);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.api, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ],
              ),
              TextButton(
                onPressed: testing ? null : onTest,
                child: Text(testing ? '测试中...' : '测试连接'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: keyController,
            decoration: const InputDecoration(labelText: 'API Key'),
            obscureText: true,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(labelText: 'API URL'),
          ),
          if (summaryModelController != null) ...[
            const SizedBox(height: 8),
            TextField(
              controller: summaryModelController,
              decoration: const InputDecoration(
                labelText: '摘要模型',
                helperText: '文本摘要推荐使用 qwen3.5-plus / qwen-turbo，不要使用 captioner 音频模型',
              ),
            ),
          ],
          if (statusText != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                statusText!,
                style: TextStyle(
                  fontSize: 12,
                  color: statusText == '连接成功'
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocalModelsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('本地模型',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 6),
            Text('管理隐私优先的本地转写引擎。',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFDE68A).withOpacity(0.2),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
          ),
          child: Row(
            children: const [
              SizedBox(
                  width: 6,
                  height: 6,
                  child: DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color(0xFFF59E0B), shape: BoxShape.circle))),
              SizedBox(width: 6),
              Text('引擎就绪',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                      letterSpacing: 1.2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocalDownloadSourceCard extends ConsumerStatefulWidget {
  final AppConfig config;
  const _LocalDownloadSourceCard({required this.config});

  @override
  ConsumerState<_LocalDownloadSourceCard> createState() =>
      _LocalDownloadSourceCardState();
}

class _LocalDownloadSourceCardState
    extends ConsumerState<_LocalDownloadSourceCard> {
  static const _sources = <String, String>{
    'modelscope': 'ModelScope（推荐）',
    'legacy': '兼容回退（HF/OpenAI）',
  };
  late final TextEditingController _hfEndpointController;
  late final TextEditingController _weightsBaseController;
  late String _source;
  bool _showAdvanced = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _source = widget.config.transcription.local.modelSource;
    _showAdvanced = _source != 'modelscope';
    _hfEndpointController = TextEditingController(
      text: widget.config.transcription.local.hfEndpoint ?? '',
    );
    _weightsBaseController = TextEditingController(
      text: widget.config.transcription.local.whisperWeightsBaseUrl ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _LocalDownloadSourceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextHf = widget.config.transcription.local.hfEndpoint ?? '';
    final nextBase =
        widget.config.transcription.local.whisperWeightsBaseUrl ?? '';
    final nextSource = widget.config.transcription.local.modelSource;
    if (_source != nextSource) {
      _source = nextSource;
      _showAdvanced = _source != 'modelscope';
    }
    if (_hfEndpointController.text != nextHf) {
      _hfEndpointController.text = nextHf;
    }
    if (_weightsBaseController.text != nextBase) {
      _weightsBaseController.text = nextBase;
    }
  }

  @override
  void dispose() {
    _hfEndpointController.dispose();
    _weightsBaseController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final updated = widget.config.copyWith(
      transcription: widget.config.transcription.copyWith(
        local: widget.config.transcription.local.copyWith(
          modelSource: _source,
          hfEndpoint: _hfEndpointController.text.trim().isEmpty
              ? null
              : _hfEndpointController.text.trim(),
          whisperWeightsBaseUrl: _weightsBaseController.text.trim().isEmpty
              ? null
              : _weightsBaseController.text.trim(),
        ),
      ),
    );
    await ref.read(configProvider.notifier).saveConfig(updated);
    await NativeService.restart();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('模型下载配置已保存并生效')),
    );
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '模型下载源',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _source == 'modelscope'
                ? '默认下载源为 ModelScope（官方推荐）。'
                : '当前使用兼容回退下载源（可切回 ModelScope）。',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _sources.containsKey(_source) ? _source : 'modelscope',
            decoration: const InputDecoration(labelText: '下载源'),
            items: _sources.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _source = value;
                _showAdvanced = value != 'modelscope';
              });
            },
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _hfEndpointController,
              decoration: const InputDecoration(
                labelText: 'HF_ENDPOINT（高级可选）',
                hintText: '例如: https://hf-mirror.com',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weightsBaseController,
              decoration: const InputDecoration(
                labelText: 'VOICE_WHISPER_WEIGHTS_BASE_URL（高级可选）',
                hintText: '例如: https://your-cdn.example.com',
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (_showAdvanced)
                TextButton(
                  onPressed: () {
                    _hfEndpointController.text = '';
                    _weightsBaseController.text = '';
                  },
                  child: const Text('清空高级项'),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中...' : '保存下载源'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LocalModelList extends ConsumerStatefulWidget {
  @override
  ConsumerState<_LocalModelList> createState() => _LocalModelListState();
}

class _LocalModelListState extends ConsumerState<_LocalModelList> {
  Map<String, dynamic>? _models;
  final Set<String> _downloading = <String>{};
  final Map<String, int> _progress = <String, int>{};
  final Map<String, String> _progressMessage = <String, String>{};
  Timer? _pollTimer;
  String? _error;

  Future<void> _loadModels() async {
    try {
      final data = await NativeService.getModels();
      setState(() {
        _models = data;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _models = const {'models': []};
        _error = '模型服务不可用: $e';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadModels();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_downloading.isEmpty) return;
    for (final model in _downloading.toList()) {
      try {
        final s = await NativeService.getDownloadStatus(model);
        if (!mounted) return;
        final status = s['status']?.toString() ?? 'unknown';
        final progress = (s['progress'] as num?)?.toInt() ?? 0;
        final message = s['message']?.toString() ?? '';
        setState(() {
          _progress[model] = progress;
          _progressMessage[model] = message;
          if (status == 'downloaded' || status == 'failed') {
            _downloading.remove(model);
          }
        });
      } catch (_) {}
    }
    await _loadModels();
  }

  Future<void> _openDownloadDialog({
    required String model,
    required String source,
    required String modelDir,
    required bool autoStart,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ModelDownloadDialog(
        model: model,
        source: source,
        modelDir: modelDir,
        autoStart: autoStart,
      ),
    );
    await _loadModels();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider).valueOrNull;
    final selectedSource =
        config?.transcription.local.modelSource ?? 'modelscope';
    final models = (_models?['models'] as List?)?.cast<Map>() ?? [];
    return Container(
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9)),
            bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        children: _error != null
            ? [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: const TextStyle(color: Color(0xFFEF4444))),
                ),
                TextButton(onPressed: _loadModels, child: const Text('重试')),
              ]
            : models.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无已下载模型'),
                    ),
                  ]
                : models.map((m) {
                    return _ModelRow(
                      title: m['name']?.toString() ?? 'unknown',
                      subtitle: m['size']?.toString() ?? '--',
                      status: m['status']?.toString() ?? 'unknown',
                      downloading:
                          _downloading.contains(m['name']?.toString() ?? ''),
                      progress: _progress[m['name']?.toString() ?? ''] ??
                          ((m['progress'] as num?)?.toInt() ?? 0),
                      progressMessage:
                          _progressMessage[m['name']?.toString() ?? ''] ??
                              (m['message']?.toString() ?? ''),
                      source: m['source']?.toString() ?? selectedSource,
                      modelDir: m['model_dir']?.toString() ?? '--',
                      onDownload: () async {
                        final name = m['name']?.toString() ?? 'small';
                        if (_downloading.contains(name)) return;
                        setState(() {
                          _downloading.add(name);
                          _progress[name] = 1;
                          _progressMessage[name] = 'queued';
                        });
                        await _openDownloadDialog(
                          model: name,
                          source: selectedSource,
                          modelDir: m['model_dir']?.toString() ?? '--',
                          autoStart: true,
                        );
                      },
                      onShowProgress: () async {
                        final name = m['name']?.toString() ?? 'small';
                        await _openDownloadDialog(
                          model: name,
                          source: m['source']?.toString() ?? selectedSource,
                          modelDir: m['model_dir']?.toString() ?? '--',
                          autoStart: false,
                        );
                      },
                    );
                  }).toList(),
      ),
    );
  }
}

class _ModelRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final bool downloading;
  final int progress;
  final String progressMessage;
  final String source;
  final String modelDir;
  final VoidCallback onDownload;
  final VoidCallback onShowProgress;

  const _ModelRow({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.downloading,
    required this.progress,
    required this.progressMessage,
    required this.source,
    required this.modelDir,
    required this.onDownload,
    required this.onShowProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = status == 'downloaded';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.description, color: Color(0xFF3B82F6)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF94A3B8))),
                const SizedBox(height: 2),
                Text(
                  '源: $source',
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
                Text(
                  modelDir,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          if (isDownloaded)
            const Text('已下载',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                    letterSpacing: 1.2))
          else
            SizedBox(
              width: 220,
              child: downloading
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '下载中 $progress%',
                          style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (progress.clamp(0, 100)) / 100,
                        ),
                        if (progressMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              progressMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: onShowProgress,
                          child: const Text('查看进度'),
                        ),
                      ],
                    )
                  : Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: onDownload, child: const Text('下载')),
                    ),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ModelDownloadDialog extends StatefulWidget {
  final String model;
  final String source;
  final String modelDir;
  final bool autoStart;

  const _ModelDownloadDialog({
    required this.model,
    required this.source,
    required this.modelDir,
    required this.autoStart,
  });

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  Timer? _timer;
  int _progress = 0;
  String _status = 'queued';
  String _message = '等待下载';
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _start();
    } else {
      _refresh();
    }
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await NativeService.downloadModel(
        widget.model,
        source: widget.source,
      );
      await _refresh();
    } finally {
      if (mounted) {
        setState(() => _starting = false);
      }
    }
  }

  Future<void> _refresh() async {
    final data = await NativeService.getDownloadStatus(widget.model);
    if (!mounted) return;
    setState(() {
      _progress = (data['progress'] as num?)?.toInt() ?? 0;
      _status = data['status']?.toString() ?? 'unknown';
      _message = data['message']?.toString() ?? '';
    });
    if (_status == 'downloaded' || _status == 'failed') {
      _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _status == 'downloaded';
    final isFailed = _status == 'failed';
    final accent = isFailed
        ? const Color(0xFFDC2626)
        : isDone
            ? const Color(0xFF059669)
            : const Color(0xFF256AF4);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 120, vertical: 80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Container(
        width: 620,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 760),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                isDone
                                    ? Icons.check_rounded
                                    : isFailed
                                        ? Icons.error_outline_rounded
                                        : Icons.downloading_rounded,
                                color: accent,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.model} 模型下载',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isDone
                                        ? '模型已就绪，可以回到任务页开始识别。'
                                        : isFailed
                                            ? '下载失败，请检查网络或下载源配置。'
                                            : '正在实时同步下载进度与校验阶段。',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _MetaPill(label: '下载源', value: widget.source),
                                  const SizedBox(width: 10),
                                  _MetaPill(label: '状态', value: _status),
                                  const Spacer(),
                                  Text(
                                    '$_progress%',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 12,
                                  value: (_progress.clamp(0, 100)) / 100,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(accent),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SelectableText(
                                _message.isEmpty ? '等待状态更新' : _message,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.modelDir,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          isDone || isFailed ? () => Navigator.of(context).pop() : null,
                      child: Text(isDone ? '完成' : '关闭'),
                    ),
                    const SizedBox(width: 8),
                    if (!_starting && !isDone && !isFailed)
                      FilledButton(
                        onPressed: widget.autoStart ? null : _start,
                        child: const Text('开始下载'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final String value;

  const _MetaPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF475569),
        ),
      ),
    );
  }
}
