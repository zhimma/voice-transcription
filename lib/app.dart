import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'pages/upload_page.dart';
import 'pages/task_detail_page.dart';
import 'pages/settings_page.dart';
import 'pages/config_editor_page.dart';

class VoiceTranscriptionApp extends StatelessWidget {
  const VoiceTranscriptionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/upload',
          builder: (context, state) => const UploadPage(),
        ),
        GoRoute(
          path: '/task/:id',
          builder: (context, state) => TaskDetailPage(
            taskId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/config',
          builder: (context, state) => const ConfigEditorPage(),
        ),
      ],
    );

    return MaterialApp.router(
      title: '智能录音转写助手',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
