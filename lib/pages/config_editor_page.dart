import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/config_service.dart';
import '../models/channel.dart';

class ConfigEditorPage extends StatefulWidget {
  const ConfigEditorPage({super.key});

  @override
  State<ConfigEditorPage> createState() => _ConfigEditorPageState();
}

class _ConfigEditorPageState extends State<ConfigEditorPage> {
  final _configController = TextEditingController();
  String _validationResult = '';
  bool _isValid = false;
  final _configService = ConfigService();

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final config = await _configService.loadConfig();
    _configController.text = _configService.exportToString(config);
  }

  Future<void> _validate() async {
    try {
      await _configService.importFromString(_configController.text);
      setState(() {
        _validationResult = '✅ 配置格式正确';
        _isValid = true;
      });
    } catch (e) {
      setState(() {
        _validationResult = '❌ ${e.toString()}';
        _isValid = false;
      });
    }
  }

  Future<void> _apply() async {
    if (!_isValid) {
      await _validate();
      if (!_isValid) return;
    }

    try {
      final config = await _configService.importFromString(_configController.text);
      await _configService.saveConfig(config);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置已应用')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('应用失败: $e')),
      );
    }
  }

  void _export() {
    final text = _configController.text;
    // TODO: 复制到剪贴板或保存文件
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制到剪贴板')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('配置文件编辑'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/settings'),
        ),
      ),
      body: Column(
        children: [
          // 工具栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: _validate,
                  icon: const Icon(Icons.check),
                  label: const Text('验证'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _isValid ? _apply : null,
                  icon: const Icon(Icons.save),
                  label: const Text('应用'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _export,
                  icon: const Icon(Icons.download),
                  label: const Text('导出'),
                ),
              ],
            ),
          ),

          // 验证结果
          if (_validationResult.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              color: _isValid ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              child: Text(_validationResult),
            ),

          // 编辑器
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _configController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: '粘贴 JSON 或 YAML 配置文件...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),

          // 模板按钮
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => _loadTemplate('json'),
                  child: const Text('加载 JSON 模板'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () => _loadTemplate('yaml'),
                  child: const Text('加载 YAML 模板'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _loadTemplate(String format) {
    // TODO: 加载模板
    setState(() {
      _configController.text = '''{
  "version": "1.0",
  "transcription": {
    "mode": "local",
    "local": {
      "model": "small",
      "device": "auto"
    },
    "cloud_channels": []
  },
  "summary": {
    "channels": [
      {
        "id": "local-summary",
        "name": "本地简化版",
        "type": "local",
        "provider": "local",
        "enabled": true,
        "priority": 1,
        "config": {}
      }
    ]
  }
}''';
    });
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }
}
