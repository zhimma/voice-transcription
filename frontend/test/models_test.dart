// 智能录音转写助手 - 数据模型测试

import 'package:flutter_test/flutter_test.dart';
import '../lib/models/task.dart';
import '../lib/models/channel.dart';

void main() {
  group('Task Model Tests', () {
    test('Task creation', () {
      final task = Task(
        id: '1',
        taskNo: 'TR20240101000000',
        status: TaskStatus.pending,
        fileName: 'audio.mp3',
        filePath: '/path/to/audio.mp3',
        fileSize: 1024,
        model: 'small',
        createdAt: DateTime.now(),
      );
      
      expect(task.id, '1');
      expect(task.fileName, 'audio.mp3');
      expect(task.status, TaskStatus.pending);
    });

    test('Task status transitions', () {
      var task = Task(
        id: '1',
        taskNo: 'TR20240101000001',
        status: TaskStatus.pending,
        fileName: 'audio.mp3',
        filePath: '/path/audio.mp3',
        fileSize: 2048,
        model: 'small',
        createdAt: DateTime.now(),
      );
      
      // 状态转换
      task = task.copyWith(status: TaskStatus.processing);
      expect(task.status, TaskStatus.processing);
      
      task = task.copyWith(status: TaskStatus.completed);
      expect(task.status, TaskStatus.completed);
    });

    test('Task toJson/fromJson', () {
      final task = Task(
        id: '1',
        taskNo: 'TR20240101000002',
        status: TaskStatus.completed,
        fileName: 'audio.mp3',
        filePath: '/path/to/audio.mp3',
        fileSize: 4096,
        model: 'small',
        createdAt: DateTime(2024, 1, 1),
        transcription: TranscriptionResult(
          id: 't1',
          taskId: '1',
          fullText: '转写结果',
          language: 'zh',
          segments: const [],
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      
      final json = task.toJson();
      final restored = Task.fromJson(json);
      
      expect(restored.id, task.id);
      expect(restored.fileName, task.fileName);
      expect(restored.status, task.status);
    });
  });

  group('Channel Model Tests', () {
    test('Channel creation', () {
      final channel = ChannelConfig(
        id: 'qwen',
        name: '通义千问',
        type: ChannelType.api,
        provider: 'qwen',
        enabled: true,
        priority: 1,
        config: const {},
      );
      
      expect(channel.id, 'qwen');
      expect(channel.name, '通义千问');
      expect(channel.type, ChannelType.api);
      expect(channel.enabled, true);
    });

    test('Channel toggle', () {
      var channel = ChannelConfig(
        id: 'test',
        name: '测试',
        type: ChannelType.local,
        provider: 'local',
        enabled: false,
        priority: 1,
        config: const {},
      );
      
      channel = channel.copyWith(enabled: true);
      expect(channel.enabled, true);
    });
  });
}
