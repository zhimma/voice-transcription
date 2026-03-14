import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../services/database_service.dart';
import '../ffi/native_service.dart';

final taskServiceProvider = Provider<TaskService>((ref) {
  return TaskService();
});

class TaskService {
  final _db = DatabaseService.instance;
  final _uuid = const Uuid();
  
  /// 创建任务
  Future<Task> createTask({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String model,
    String language = 'auto',
    bool generateSummary = true,
    String summaryLength = 'medium',
  }) async {
    final task = Task(
      id: _uuid.v4(),
      taskNo: _generateTaskNo(),
      status: TaskStatus.pending,
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      model: model,
      language: language,
      generateSummary: generateSummary,
      summaryLength: summaryLength,
      createdAt: DateTime.now(),
    );
    
    await _db.insertTask(task);
    return task;
  }
  
  /// 获取任务列表
  Future<List<Task>> getTasks({
    TaskStatus? status,
    String? keyword,
    int limit = 50,
    int offset = 0,
  }) async {
    return await _db.getTasks(
      status: status,
      keyword: keyword,
      limit: limit,
      offset: offset,
    );
  }
  
  /// 获取单个任务
  Future<Task?> getTask(String id) async {
    return await _db.getTask(id);
  }
  
  /// 更新任务状态
  Future<void> updateTaskStatus(String id, TaskStatus status, {String? error}) async {
    await _db.updateTaskStatus(id, status, error: error);
  }
  
  /// 更新任务进度
  Future<void> updateTaskProgress(String id, int progress) async {
    await _db.updateTaskProgress(id, progress);
  }
  
  /// 删除任务
  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
  }
  
  /// 执行任务（完整流程）
  Future<void> executeTask(Task task) async {
    try {
      // 1. 更新状态为处理中
      await updateTaskStatus(task.id, TaskStatus.processing);
      
      // 2. 语音识别
      await _executeTranscription(task);
      
      // 3. 生成摘要（如果启用）
      if (task.generateSummary && task.transcription != null) {
        await _executeSummary(task);
      }
      
      // 4. 完成
      await updateTaskStatus(task.id, TaskStatus.completed);
      
    } catch (e) {
      await updateTaskStatus(task.id, TaskStatus.failed, error: e.toString());
    }
  }
  
  /// 执行语音识别
  Future<void> _executeTranscription(Task task) async {
    await updateTaskProgress(task.id, 10);
    
    try {
      final result = await NativeService.transcribe(
        audioPath: task.filePath,
        model: task.model,
        language: task.language,
      );
      
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      
      // 保存转写结果
      final transcription = TranscriptionResult(
        id: _uuid.v4(),
        taskId: task.id,
        fullText: result['text'],
        wordCount: result['text'].toString().length,
        language: result['language'] ?? 'unknown',
        segments: (result['segments'] as List?)
            ?.map((s) => Segment(
                  id: s['id'],
                  startTime: s['start'].toDouble(),
                  endTime: s['end'].toDouble(),
                  text: s['text'],
                ))
            .toList() ?? [],
        createdAt: DateTime.now(),
      );
      
      await _db.insertTranscription(transcription);
      await updateTaskProgress(task.id, 60);
      
    } catch (e) {
      throw Exception('语音识别失败: $e');
    }
  }
  
  /// 执行摘要生成
  Future<void> _executeSummary(Task task) async {
    await updateTaskProgress(task.id, 70);
    
    try {
      final transcription = await _db.getTranscription(task.id);
      if (transcription == null) return;
      
      final result = await NativeService.summarize(
        text: transcription.fullText,
        length: task.summaryLength,
      );
      
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      
      // 保存摘要结果
      final summary = SummaryResult(
        id: _uuid.v4(),
        taskId: task.id,
        short: result['short'] ?? result['summary'],
        medium: result['medium'] ?? result['summary'],
        long: result['long'] ?? result['summary'],
        keyPoints: List<String>.from(result['key_points'] ?? []),
        keywords: List<String>.from(result['keywords'] ?? []),
        createdAt: DateTime.now(),
      );
      
      await _db.insertSummary(summary);
      await updateTaskProgress(task.id, 100);
      
    } catch (e) {
      // 摘要失败不阻断流程
      print('摘要生成失败: $e');
    }
  }
  
  /// 生成任务编号
  String _generateTaskNo() {
    final now = DateTime.now();
    return 'TR${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }
}
