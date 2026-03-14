// 智能录音转写助手 - 数据模型测试

import 'package:flutter_test/flutter_test.dart';
import '../lib/models/task.dart';
import '../lib/models/channel.dart';

void main() {
  group('Task Model Tests', () {
    test('Task creation', () {
      final task = Task(
        id: '1',
        name: '测试任务',
        audioPath: '/path/to/audio.mp3',
        status: TaskStatus.pending,
        createdAt: DateTime.now(),
      );
      
      expect(task.id, '1');
      expect(task.name, '测试任务');
      expect(task.status, TaskStatus.pending);
    });

    test('Task status transitions', () {
      var task = Task(
        id: '1',
        name: '测试',
        audioPath: '/path/audio.mp3',
        status: TaskStatus.pending,
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
        name: '测试任务',
        audioPath: '/path/to/audio.mp3',
        status: TaskStatus.completed,
        createdAt: DateTime(2024, 1, 1),
        result: TranscriptionResult(
          text: '转写结果',
          language: 'zh',
          duration: 60.0,
          segments: [],
        ),
      );
      
      final json = task.toJson();
      final restored = Task.fromJson(json);
      
      expect(restored.id, task.id);
      expect(restored.name, task.name);
      expect(restored.status, task.status);
    });
  });

  group('Channel Model Tests', () {
    test('Channel creation', () {
      final channel = Channel(
        id: 'qwen',
        name: '通义千问',
        type: ChannelType.cloud,
        enabled: true,
      );
      
      expect(channel.id, 'qwen');
      expect(channel.name, '通义千问');
      expect(channel.type, ChannelType.cloud);
      expect(channel.enabled, true);
    });

    test('Channel toggle', () {
      var channel = Channel(
        id: 'test',
        name: '测试',
        type: ChannelType.local,
        enabled: false,
      );
      
      channel = channel.copyWith(enabled: true);
      expect(channel.enabled, true);
    });
  });
}
