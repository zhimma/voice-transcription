import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';
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
  bool _hideSecrets = true;

  @override
  void initState() {
    super.initState();
    final config = ref.read(configProvider).value;
    if (config != null) {
      _editor.text = ref.read(configProvider.notifier).exportToString(hideSecrets: _hideSecrets);
    }
  }

  Future<void> _save() async {
    final msg = await ref.read(configProvider.notifier).importFromString(_editor.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
                  Text('全局配置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text('集中管理转写策略与默认参数。', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ],
              ),
              const Spacer(),
              _IconButton(
                icon: _hideSecrets ? Icons.visibility_off : Icons.visibility,
                label: _hideSecrets ? '隐藏密钥' : '显示密钥',
                onTap: () {
                  setState(() {
                    _hideSecrets = !_hideSecrets;
                  });
                  _refreshPreview();
                },
              ),
              const SizedBox(width: 8),
              _IconButton(icon: Icons.refresh, label: '重置', onTap: _refreshPreview),
              const SizedBox(width: 8),
              _IconButton(icon: Icons.upload_file, label: '导入', onTap: _save),
              const SizedBox(width: 8),
              _PrimaryButton(label: '保存配置', onTap: _save),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
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
                        const Text('配置预览', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.6)),
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
            ),
          ),
        ],
      ),
    );
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
