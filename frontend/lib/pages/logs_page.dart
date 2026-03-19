import 'dart:async';
import 'package:flutter/material.dart';
import '../services/logger_service.dart';
import '../ui/app_shell.dart';

class LogsPage extends StatefulWidget {
  final bool embedded;
  const LogsPage({super.key, this.embedded = false});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool _loading = true;
  bool _autoRefresh = true;
  bool _followTail = true;
  String? _error;
  String _appLogText = '';
  String _pythonLogText = '';
  Timer? _timer;
  final ScrollController _appScroll = ScrollController();
  final ScrollController _pythonScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_autoRefresh) {
        _loadLogs(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _appScroll.dispose();
    _pythonScroll.dispose();
    super.dispose();
  }

  Future<void> _loadLogs({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final appText = await LoggerService.instance.readLogFile(LogFileType.app);
      final pythonText =
          await LoggerService.instance.readLogFile(LogFileType.python);
      if (!mounted) return;
      setState(() {
        _appLogText = appText;
        _pythonLogText = pythonText;
        _loading = false;
      });
      if (_followTail) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _jumpToTail(_appScroll);
          _jumpToTail(_pythonScroll);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _jumpToTail(ScrollController controller) {
    if (!controller.hasClients) return;
    controller.jumpTo(controller.position.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '日志中心',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '整文件追踪，支持自动刷新与末尾跟随',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF64748B)),
                ),
              ),
              TextButton(
                onPressed: () => LoggerService.instance.openLogsDirectory(),
                child: const Text('打开目录'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () async {
                  final file = await LoggerService.instance.exportBundle();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(file == null ? '已取消导出' : '日志已导出: $file'),
                    ),
                  );
                },
                child: const Text('导出'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _loadLogs(),
                child: const Text('刷新'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('自动刷新'),
              Switch(
                value: _autoRefresh,
                onChanged: (value) => setState(() => _autoRefresh = value),
              ),
              const SizedBox(width: 12),
              const Text('跟随末尾'),
              Switch(
                value: _followTail,
                onChanged: (value) => setState(() => _followTail = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('加载日志失败: $_error'))
                    : DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            const TabBar(
                              tabs: [
                                Tab(text: 'App 日志'),
                                Tab(text: 'Python 日志'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _LogViewer(
                                    text: _appLogText,
                                    controller: _appScroll,
                                  ),
                                  _LogViewer(
                                    text: _pythonLogText,
                                    controller: _pythonScroll,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return AppShell(
      active: AppNavItem.logs,
      title: '日志中心',
      child: body,
    );
  }
}

class _LogViewer extends StatelessWidget {
  final String text;
  final ScrollController controller;

  const _LogViewer({required this.text, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const Center(child: Text('暂无日志内容'));
    }
    final lines = text.split('\n');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          child: SelectableText.rich(
            TextSpan(
              children: [
                for (final line in lines)
                  TextSpan(
                    text: '$line\n',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.4,
                      color: _highlight(line),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _highlight(String line) {
    if (line.contains('Traceback') || line.contains('ERROR')) {
      return const Color(0xFFFCA5A5);
    }
    if (line.contains('WARN') || line.contains('warning')) {
      return const Color(0xFFFDE68A);
    }
    return const Color(0xFFE2E8F0);
  }
}
