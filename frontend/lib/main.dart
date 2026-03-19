import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
// Menu is exported by tray_manager
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'app.dart';
import 'ffi/native_service.dart';
import 'services/config_service.dart';
import 'services/app_router.dart';
import 'services/logger_service.dart';
import 'services/hotkey_service.dart';
import 'providers/task_provider.dart';
import 'providers/config_provider.dart';

late ProviderContainer appContainer;
final _windowListener = _AppWindowListener();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化桌面端 SQLite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 初始化窗口管理
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1200, 800),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
    windowManager.addListener(_windowListener);
  });

  appContainer = ProviderContainer();
  final startupConfig = await ConfigService().loadConfig();
  await LoggerService.instance.initialize(startupConfig.logging);
  await LoggerService.instance.info('App starting');

  await _setupTray();
  await HotkeyService.instance.initialize();

  runApp(
    ProviderScope(
      parent: appContainer,
      child: const VoiceTranscriptionApp(),
    ),
  );
}

Future<void> _setupTray() async {
  final trayManager = TrayManager.instance;
  await trayManager.setIcon('assets/tray.png');
  await trayManager.setToolTip('智能录音转写助手');

  final config = await ConfigService().loadConfig();
  final recentFiles = config.recentFiles.take(5).toList();

  final menu = Menu(items: [
    MenuItem(label: '新建任务', onClick: (_) => _go('/upload')),
    MenuItem(label: '打开文件', onClick: (_) => _openFile()),
    if (recentFiles.isNotEmpty) MenuItem.separator(),
    ...recentFiles
        .map((f) => MenuItem(label: f, onClick: (_) => _openFile(path: f))),
    MenuItem.separator(),
    MenuItem(label: '退出', onClick: (_) => windowManager.close()),
  ]);

  await trayManager.setContextMenu(menu);
}

void _go(String path) {
  final context = rootNavigatorKey.currentContext;
  if (context != null) {
    GoRouter.of(context).go(path);
  }
}

Future<void> _openFile({String? path}) async {
  String? filePath = path;
  if (filePath == null) {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    filePath = result.files.single.path;
  }
  if (filePath == null) return;

  final file = resultFromPath(filePath);
  const provider = 'whisper';

  await LoggerService.instance.info(
    'Open file from menu/tray',
    fields: {'path': filePath, 'provider': provider},
  );

  final task = await appContainer.read(taskListProvider.notifier).createTask(
        fileName: file['name']!,
        filePath: file['path']!,
        fileSize: int.parse(file['size']!),
        model: 'base',
        provider: provider,
        language: 'auto',
        generateSummary: true,
        summaryLength: 'medium',
      );

  await appContainer.read(configProvider.notifier).addRecentFile(filePath);
  await appContainer.read(currentTaskProvider.notifier).loadTask(task.id);
  _go('/');
}

Map<String, String> resultFromPath(String path) {
  final name = path.split('/').last;
  final size = File(path).lengthSync();
  return {'name': name, 'path': path, 'size': size.toString()};
}

class _AppWindowListener extends WindowListener {
  bool _closing = false;

  @override
  Future<void> onWindowClose() async {
    if (_closing) return;
    _closing = true;
    try {
      await LoggerService.instance.info('App closing, cleanup python process');
      await HotkeyService.instance.dispose();
      await NativeService.dispose();
    } finally {
      await windowManager.destroy();
    }
  }
}
