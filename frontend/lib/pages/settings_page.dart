import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _mode = 'local';
  String _selectedModel = 'small';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/config'),
            child: const Text('配置文件'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 语音识别设置
          _buildSection('语音识别', [
            ListTile(
              title: const Text('识别模式'),
              subtitle: Text(_mode == 'local' ? '本地识别' : '云端识别'),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'local', label: Text('本地')),
                  ButtonSegment(value: 'cloud', label: Text('云端')),
                ],
                selected: {_mode},
                onSelectionChanged: (v) => setState(() => _mode = v.first),
              ),
            ),
            if (_mode == 'local') ...[
              const Divider(),
              ListTile(
                title: const Text('本地模型'),
                subtitle: Text(_selectedModel),
                trailing: DropdownButton<String>(
                  value: _selectedModel,
                  items: ['tiny', 'base', 'small', 'medium', 'large']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedModel = v!),
                ),
              ),
              ListTile(
                title: const Text('模型管理'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showModelManager(),
              ),
            ],
            if (_mode == 'cloud') ...[
              const Divider(),
              ListTile(
                title: const Text('云端渠道'),
                trailing: const Icon(Icons.add),
                onTap: () => _addCloudChannel(),
              ),
              _buildChannelItem('千问API', 'qwen', true),
              _buildChannelItem('OpenAI', 'openai', false),
            ],
          ]),

          // 摘要设置
          _buildSection('摘要生成', [
            ListTile(
              title: const Text('摘要渠道'),
              trailing: const Icon(Icons.add),
              onTap: () => _addSummaryChannel(),
            ),
            _buildChannelItem('千问API', 'qwen', true, isSummary: true),
            _buildChannelItem('DeepSeek', 'deepseek', false, isSummary: true),
            _buildChannelItem('本地简化', 'local', true, isSummary: true),
          ]),

          // 关于
          _buildSection('关于', [
            const ListTile(
              title: Text('版本'),
              trailing: Text('1.0.0'),
            ),
            ListTile(
              title: const Text('检查更新'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildChannelItem(String name, String provider, bool enabled,
      {bool isSummary = false}) {
    return ListTile(
      leading: Icon(enabled ? Icons.check_circle : Icons.circle_outlined,
          color: enabled ? Colors.green : Colors.grey),
      title: Text(name),
      subtitle: Text(provider),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  void _showModelManager() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('模型管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Small'),
              subtitle: const Text('244 MB · 已下载'),
              trailing: TextButton(onPressed: () {}, child: const Text('删除')),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Medium'),
              subtitle: const Text('769 MB · 未下载'),
              trailing: TextButton(onPressed: () {}, child: const Text('下载')),
            ),
          ],
        ),
      ),
    );
  }

  void _addCloudChannel() {
    // TODO: 添加云端渠道
  }

  void _addSummaryChannel() {
    // TODO: 添加摘要渠道
  }
}
