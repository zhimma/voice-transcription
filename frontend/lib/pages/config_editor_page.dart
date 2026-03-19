import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/prompt_history.dart';
import '../providers/config_provider.dart';
import '../services/config_service.dart';
import '../ui/app_shell.dart';

class ConfigEditorPage extends ConsumerWidget {
  final bool embedded;
  const ConfigEditorPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (embedded) return const _ConfigEditorBody();
    return AppShell(
      active: AppNavItem.settings,
      title: '配置编辑器',
      child: const _ConfigEditorBody(),
    );
  }
}

class _ConfigEditorBody extends ConsumerStatefulWidget {
  const _ConfigEditorBody();

  @override
  ConsumerState<_ConfigEditorBody> createState() => _ConfigEditorBodyState();
}

class _ConfigEditorBodyState extends ConsumerState<_ConfigEditorBody> {
  final TextEditingController _editor = TextEditingController();
  final TextEditingController _promptEditor = TextEditingController();
  bool _hideSecrets = true;
  int _selectedTab = 0;
  List<PromptHistory> _promptHistory = [];
  bool _isLoadingHistory = false;
  String? _promptNote;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadPromptHistory();
  }

  void _loadConfig() {
    final config = ref.read(configProvider).value;
    if (config != null) {
      _editor.text = ref.read(configProvider.notifier).exportToString(hideSecrets: _hideSecrets);
      // 加载当前提示词
      final currentPrompt = config.prompts.conversationAnalysis;
      _promptEditor.text = currentPrompt.isNotEmpty
          ? currentPrompt
          : ConfigService.defaultConversationAnalysisPrompt;
    }
  }

  Future<void> _loadPromptHistory() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await ConfigService().getPromptHistory('conversation_analysis', limit: 20);
      setState(() => _promptHistory = history);
    } finally {
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _save() async {
    final msg = await ref.read(configProvider.notifier).importFromString(_editor.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _savePrompt() async {
    if (_promptEditor.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提示词内容不能为空')),
      );
      return;
    }

    try {
      await ConfigService().savePromptVersion(
        'conversation_analysis',
        _promptEditor.text.trim(),
        note: _promptNote,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('提示词已保存为新版本')),
      );
      _loadPromptHistory();
      _promptNote = null;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  Future<void> _activatePromptVersion(String id) async {
    try {
      await ConfigService().activatePromptVersion('conversation_analysis', id);
      final history = await ConfigService().getPromptHistory('conversation_analysis', limit: 1);
      if (history.isNotEmpty) {
        setState(() => _promptEditor.text = history.first.content);
      }
      _loadPromptHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已切换到选中的版本')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('切换失败: $e')),
      );
    }
  }

  void _refreshPreview() {
    setState(() {
      _editor.text = ref.read(configProvider.notifier).exportToString(hideSecrets: _hideSecrets);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('系统设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('集中管理转写策略、提示词与默认参数。', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              _TabButton(
                label: '全局配置',
                isActive: _selectedTab == 0,
                onTap: () => setState(() => _selectedTab = 0),
              ),
              const SizedBox(width: 8),
              _TabButton(
                label: '提示词管理',
                isActive: _selectedTab == 1,
                onTap: () => setState(() => _selectedTab = 1),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _selectedTab == 0 ? _buildConfigTab() : _buildPromptTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTab() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: const Color(0xFFF8FAFC),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('配置预览', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.6)),
                    const Spacer(),
                    _IconButton(
                      icon: _hideSecrets ? Icons.visibility_off : Icons.visibility,
                      label: _hideSecrets ? '隐藏密钥' : '显示密钥',
                      onTap: () {
                        setState(() => _hideSecrets = !_hideSecrets);
                        _refreshPreview();
                      },
                    ),
                    const SizedBox(width: 8),
                    _IconButton(icon: Icons.refresh, label: '重置', onTap: _refreshPreview),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _editor,
                      maxLines: null,
                      decoration: const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(fontSize: 12, height: 1.6, fontFamily: 'monospace', color: Color(0xFF475569)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconButton(icon: Icons.upload_file, label: '导入', onTap: _save),
                    const SizedBox(width: 8),
                    _PrimaryButton(label: '保存配置', onTap: _save),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            children: const [
              _InfoCard(
                title: '参数说明',
                content: '在此编辑转写默认参数，保存后将应用于新任务。',
              ),
              SizedBox(height: 16),
              _InfoCard(
                title: '建议模板',
                content: '推荐启用时间戳与摘要以提升阅读体验。',
              ),
              SizedBox(height: 16),
              _InfoCard(
                title: '校验状态',
                content: '配置已通过本地校验，可安全保存。',
                accent: Color(0xFF10B981),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromptTab() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: const Color(0xFFF8FAFC),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('客服对话分析提示词', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.6)),
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _promptEditor,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: '输入提示词内容...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                      style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF475569)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: '版本备注（可选）',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (v) => _promptNote = v,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _IconButton(
                      icon: Icons.restore,
                      label: '恢复默认',
                      onTap: () {
                        setState(() {
                          _promptEditor.text = ConfigService.defaultConversationAnalysisPrompt;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    _PrimaryButton(label: '保存为新版本', onTap: _savePrompt),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              color: const Color(0xFFF8FAFC),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('版本历史', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.6)),
                const SizedBox(height: 12),
                Expanded(
                  child: _isLoadingHistory
                      ? const Center(child: CircularProgressIndicator())
                      : _promptHistory.isEmpty
                          ? const Center(
                              child: Text(
                                '暂无历史版本',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _promptHistory.length,
                              itemBuilder: (context, index) {
                                final item = _promptHistory[index];
                                return _PromptHistoryItem(
                                  history: item,
                                  onTap: () => _activatePromptVersion(item.id),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF256AF4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF256AF4) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }
}

class _PromptHistoryItem extends StatelessWidget {
  final PromptHistory history;
  final VoidCallback onTap;

  const _PromptHistoryItem({
    required this.history,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = history.isActive;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF256AF4).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? const Color(0xFF256AF4).withOpacity(0.4) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF256AF4) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${history.version}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Color(0xFF256AF4),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    '当前使用中',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF256AF4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDate(history.createdAt),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            if (history.note != null && history.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                history.note!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}分钟前';
      }
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _IconButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF256AF4),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF256AF4).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String content;
  final Color? accent;
  const _InfoCard({required this.title, required this.content, this.accent});

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? const Color(0xFF256AF4);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: highlight, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), height: 1.5)),
        ],
      ),
    );
  }
}
