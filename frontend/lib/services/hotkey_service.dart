import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:go_router/go_router.dart';
import 'app_router.dart';
import 'logger_service.dart';

/// 全局快捷键服务
class HotkeyService {
  static final HotkeyService instance = HotkeyService._();
  HotkeyService._();

  bool _initialized = false;
  final List<HotKey> _registeredHotkeys = [];

  /// 初始化快捷键
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await hotKeyManager.unregisterAll();
      _registeredHotkeys.clear();

      // 注册快捷键
      await _registerMinimizeHotkey();
      await _registerNewTaskHotkey();
      await _registerSettingsHotkey();
      await _registerFocusHotkey();
      await _registerShowHideHotkey();

      _initialized = true;
      await LoggerService.instance.info('Hotkey service initialized');
    } catch (e, st) {
      await LoggerService.instance.error(
        'Failed to initialize hotkey service',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 销毁快捷键
  Future<void> dispose() async {
    if (!_initialized) return;
    await hotKeyManager.unregisterAll();
    _registeredHotkeys.clear();
    _initialized = false;
  }

  /// 注册最小化快捷键 (Cmd/Ctrl + M)
  Future<void> _registerMinimizeHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyM,
      modifiers: [HotKeyModifier.meta], // Cmd on macOS
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await LoggerService.instance.debug('Hotkey: minimize window');
        await windowManager.minimize();
      },
    );

    _registeredHotkeys.add(hotKey);
  }

  /// 注册新建任务快捷键 (Cmd/Ctrl + N)
  Future<void> _registerNewTaskHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyN,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await LoggerService.instance.debug('Hotkey: new task');
        await _showWindowAndNavigate('/upload');
      },
    );

    _registeredHotkeys.add(hotKey);
  }

  /// 注册设置快捷键 (Cmd/Ctrl + ,)
  Future<void> _registerSettingsHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.comma,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await LoggerService.instance.debug('Hotkey: open settings');
        await _showWindowAndNavigate('/settings');
      },
    );

    _registeredHotkeys.add(hotKey);
  }

  /// 注册聚焦快捷键 (Cmd/Ctrl + L)
  Future<void> _registerFocusHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyL,
      modifiers: [HotKeyModifier.meta],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await LoggerService.instance.debug('Hotkey: focus window');
        await windowManager.show();
        await windowManager.focus();
      },
    );

    _registeredHotkeys.add(hotKey);
  }

  /// 注册显示/隐藏快捷键 (Cmd/Ctrl + Shift + H)
  Future<void> _registerShowHideHotkey() async {
    final hotKey = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      hotKey,
      keyDownHandler: (_) async {
        await LoggerService.instance.debug('Hotkey: toggle visibility');
        final isVisible = await windowManager.isVisible();
        if (isVisible) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.focus();
        }
      },
    );

    _registeredHotkeys.add(hotKey);
  }

  /// 显示窗口并导航
  Future<void> _showWindowAndNavigate(String path) async {
    await windowManager.show();
    await windowManager.focus();

    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      GoRouter.of(context).go(path);
    }
  }

  /// 获取已注册的快捷键列表（用于显示在设置中）
  List<Map<String, String>> getRegisteredHotkeys() {
    return [
      {'name': '最小化窗口', 'shortcut': _getShortcutLabel('M')},
      {'name': '新建任务', 'shortcut': _getShortcutLabel('N')},
      {'name': '打开设置', 'shortcut': _getShortcutLabel(',')},
      {'name': '聚焦窗口', 'shortcut': _getShortcutLabel('L')},
      {'name': '显示/隐藏', 'shortcut': _getShortcutLabel('⇧H')},
    ];
  }

  String _getShortcutLabel(String key) {
    if (Platform.isMacOS) {
      return '⌘$key';
    }
    return 'Ctrl+$key';
  }
}
