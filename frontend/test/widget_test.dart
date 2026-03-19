// 智能录音转写助手 - Widget 测试

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_transcription/app.dart';

void main() {
  group('App Widget Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: VoiceTranscriptionApp()),
      );

      // 验证应用启动
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Home page displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: VoiceTranscriptionApp()),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // 验证首页关键元素
      expect(find.text('任务管理'), findsOneWidget);
      expect(find.text('新建任务'), findsWidgets);
    });
  });
}
