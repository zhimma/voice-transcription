import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_page.dart';
import 'pages/upload_page.dart';
import 'pages/settings_page.dart';
import 'pages/logs_page.dart';
import 'providers/task_provider.dart';
import 'providers/config_provider.dart';
import 'services/app_router.dart';
import 'services/export_service.dart';
import 'services/logger_service.dart';
import 'ui/app_theme.dart';
import 'ui/app_shell.dart';

class VoiceTranscriptionApp extends StatelessWidget {
  const VoiceTranscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            final active = _activeByPath(path);
            final title = _titleByPath(path);
            return AppShell(
              active: active,
              title: title,
              contentKey: path,
              child: child,
            );
          },
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomePage(embedded: true),
              ),
            ),
            GoRoute(
              path: '/upload',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: UploadPage(embedded: true),
              ),
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SettingsPage(embedded: true),
              ),
            ),
            GoRoute(
              path: '/logs',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LogsPage(embedded: true),
              ),
            ),
            GoRoute(
              path: '/config',
              redirect: (_, __) => '/settings',
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: '智能录音转写助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) {
        final content = _AppShortcuts(child: child ?? const SizedBox.shrink());
        if (defaultTargetPlatform == TargetPlatform.macOS) {
          return PlatformMenuBar(
            menus: _buildMenus(context),
            child: content,
          );
        }
        return content;
      },
    );
  }

  static AppNavItem _activeByPath(String path) {
    if (path.startsWith('/upload')) return AppNavItem.newTask;
    if (path.startsWith('/settings')) return AppNavItem.models;
    if (path.startsWith('/logs')) return AppNavItem.logs;
    if (path.startsWith('/config')) return AppNavItem.models;
    return AppNavItem.tasks;
  }

  static String _titleByPath(String path) {
    if (path.startsWith('/upload')) return '新建任务';
    if (path.startsWith('/settings')) return '模型与API';
    if (path.startsWith('/logs')) return '日志中心';
    if (path.startsWith('/config')) return '模型与API';
    return '任务';
  }

  List<PlatformMenuItem> _buildMenus(BuildContext context) {
    return [
      PlatformMenu(
        label: '文件',
        menus: [
          PlatformMenuItem(
            label: '新建任务',
            onSelected: () => GoRouter.of(context).go('/upload'),
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyN, meta: true),
          ),
          PlatformMenuItem(
            label: '打开文件',
            onSelected: () => openFile(context),
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: '导出转写',
                onSelected: () => exportCurrent(context),
                shortcut:
                    const SingleActivator(LogicalKeyboardKey.keyS, meta: true),
              ),
            ],
          ),
          PlatformMenuItem(
            label: '退出',
            onSelected: _exitApp,
          ),
        ],
      ),
      PlatformMenu(
        label: '编辑',
        menus: [
          PlatformMenuItem(
            label: '查找',
            onSelected: () => GoRouter.of(context).go('/'),
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyF, meta: true),
          ),
        ],
      ),
      PlatformMenu(
        label: '帮助',
        menus: [
          PlatformMenuItem(
            label: '关于',
            onSelected: () => _showAbout(context),
          ),
        ],
      ),
    ];
  }

  static Future<void> openFile(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.path == null) return;

    final container = ProviderScope.containerOf(context, listen: false);
    const provider = 'whisper';

    final task = await container.read(taskListProvider.notifier).createTask(
          fileName: file.name,
          filePath: file.path!,
          fileSize: file.size,
          model: 'base',
          provider: provider,
          language: 'auto',
          generateSummary: true,
          summaryLength: 'medium',
        );

    await LoggerService.instance
        .info('Open file and create task', taskId: task.id, fields: {
      'file': file.path!,
      'provider': provider,
    });

    await container.read(currentTaskProvider.notifier).loadTask(task.id);
    container.read(configProvider.notifier).addRecentFile(file.path!);
    GoRouter.of(context).go('/');
  }

  static Future<void> exportCurrent(BuildContext context) async {
    final container = ProviderScope.containerOf(context, listen: false);
    final task = container.read(currentTaskProvider).value;
    if (task == null) return;
    final exporter = ExportService();
    await exporter.exportPdf(task);
  }

  static void _exitApp() {
    // ignore: dart:io usage for exit
    Future(() => SystemNavigator.pop());
  }

  static void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: '智能录音转写助手',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026',
    );
  }
}

class OpenFileIntent extends Intent {
  const OpenFileIntent();
}

class NewTaskIntent extends Intent {
  const NewTaskIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class _AppShortcuts extends StatelessWidget {
  final Widget child;
  const _AppShortcuts({required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyO, meta: true): OpenFileIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true):
            OpenFileIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, meta: true): NewTaskIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true):
            NewTaskIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, meta: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): SearchIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, meta: true): ExportIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): ExportIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenFileIntent: CallbackAction<OpenFileIntent>(
            onInvoke: (_) => _AppActions.openFile(context),
          ),
          NewTaskIntent: CallbackAction<NewTaskIntent>(
            onInvoke: (_) => GoRouter.of(context).go('/upload'),
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) => GoRouter.of(context).go('/'),
          ),
          ExportIntent: CallbackAction<ExportIntent>(
            onInvoke: (_) => _AppActions.exportCurrent(context),
          ),
        },
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );
  }
}

class _AppActions {
  static Future<void> openFile(BuildContext context) =>
      VoiceTranscriptionApp.openFile(context);

  static Future<void> exportCurrent(BuildContext context) =>
      VoiceTranscriptionApp.exportCurrent(context);
}
