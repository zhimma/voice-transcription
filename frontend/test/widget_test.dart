// 智能录音转写助手 - Widget 测试

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_transcription/app.dart';

void main() {
  group('App Widget Tests', () {
    testWidgets('App launches successfully', (WidgetTester tester) async {
      await tester.pumpWidget(const VoiceTranscriptionApp());
      
      // 验证应用启动
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Home page displays correctly', (WidgetTester tester) async {
      await tester.pumpWidget(const VoiceTranscriptionApp());
      await tester.pumpAndSettle();
      
      // 验证首页标题
      expect(find.text('智能录音转写助手'), findsOneWidget);
    });
  });
}
