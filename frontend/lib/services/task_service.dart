import 'package:uuid/uuid.dart';
import '../models/task.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../ffi/native_service.dart';
import '../services/config_service.dart';
import 'logger_service.dart';

class TaskService {
  final _db = DatabaseService.instance;
  final _uuid = const Uuid();

  /// 创建任务
  Future<Task> createTask({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String model,
    String provider = 'whisper',
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
      provider: provider,
      generateSummary: generateSummary,
      summaryLength: summaryLength,
      createdAt: DateTime.now(),
    );

    await _db.insertTask(task);
    await LoggerService.instance.info(
      'Task created',
      taskId: task.id,
      fields: {'file_name': fileName, 'provider': provider, 'model': model},
    );
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
  Future<void> updateTaskStatus(String id, TaskStatus status,
      {String? error}) async {
    await _db.updateTaskStatus(id, status, error: error);
  }

  /// 更新任务进度
  Future<void> updateTaskProgress(String id, int progress) async {
    await _db.updateTaskProgress(id, progress);
  }

  /// 删除任务
  Future<void> deleteTask(String id) async {
    await _db.deleteTask(id);
    await LoggerService.instance.info('Task deleted', taskId: id);
  }

  Future<void> retryTask(String taskId) async {
    final task = await getTask(taskId);
    if (task == null) {
      throw Exception('任务不存在');
    }
    if (task.status == TaskStatus.processing) {
      throw Exception('任务处理中，不能重试');
    }

    var retryTask = task;
    final downloadedModel = await _pickDownloadedModel(task.model);
    if (downloadedModel == null) {
      throw Exception('当前无可用本地模型，请先到“模型与API”下载模型后再重试');
    }
    if (downloadedModel != task.model) {
      retryTask = task.copyWith(model: downloadedModel);
      await _db.updateTask(retryTask);
      await LoggerService.instance.warn(
        'Retry task model switched',
        taskId: taskId,
        fields: {'from': task.model, 'to': downloadedModel},
      );
    }

    await _db.resetTaskForRetry(taskId);
    final reloaded = await getTask(taskId);
    if (reloaded == null) {
      throw Exception('任务重试失败，任务不存在');
    }
    await LoggerService.instance.info('Task retry', taskId: taskId);
    await executeTask(reloaded);
  }

  Future<String?> _pickDownloadedModel(String preferredModel) async {
    final models = await NativeService.getModels();
    final list = (models['models'] as List?)?.cast<Map>() ?? [];

    final byName = <String, Map>{
      for (final m in list)
        if (m['name'] != null) m['name'].toString(): m,
    };

    final isPreferredReady =
        byName[preferredModel]?['status']?.toString() == 'downloaded';
    if (isPreferredReady) return preferredModel;

    const fallbackOrder = ['base', 'tiny', 'small', 'medium', 'large-v3'];
    for (final name in fallbackOrder) {
      if (byName[name]?['status']?.toString() == 'downloaded') {
        return name;
      }
    }
    return null;
  }

  /// 执行任务（完整流程）
  Future<void> executeTask(Task task) async {
    try {
      await _createWorkflowStep(task, '准备', WorkflowStatus.running);
      // 1. 更新状态为处理中
      await updateTaskStatus(task.id, TaskStatus.processing);
      await LoggerService.instance
          .info('Task execution started', taskId: task.id);

      // 2. 语音识别
      await _createWorkflowStep(task, '语音识别', WorkflowStatus.running);
      await _executeTranscription(task);
      await _completeWorkflowStep(task, '语音识别');

      // 3. 生成摘要（如果启用）
      if (task.generateSummary) {
        await _createWorkflowStep(task, '摘要生成', WorkflowStatus.running);
        await _executeSummary(task);
        await _completeWorkflowStep(task, '摘要生成');
      }

      // 4. 完成
      await updateTaskStatus(task.id, TaskStatus.completed);
      await _completeWorkflowStep(task, '准备');
      await LoggerService.instance
          .info('Task execution completed', taskId: task.id);
    } catch (e, st) {
      await updateTaskStatus(task.id, TaskStatus.failed, error: e.toString());
      await _failWorkflowStep(task, e.toString());
      await LoggerService.instance.error(
        'Task execution failed',
        taskId: task.id,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 执行语音识别
  Future<void> _executeTranscription(Task task) async {
    await updateTaskProgress(task.id, 15);

    try {
      final config = await ConfigService().loadConfig();
      final providerConfig = _resolveProviderConfig(config, task.provider);
      if ((providerConfig['provider'] == 'whisper' ||
              providerConfig['provider'] == 'local') &&
          (providerConfig['model']?.toString().isNotEmpty == true)) {
        await _ensureLocalModel(task, providerConfig['model'].toString());
      }
      final result = await NativeService.transcribe(
        audioPath: task.filePath,
        model: task.model,
        language: task.language,
        provider: task.provider,
        taskId: task.id,
        providerConfig: providerConfig,
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
                .toList() ??
            [],
        createdAt: DateTime.now(),
      );

      await _db.insertTranscription(transcription);
      await updateTaskProgress(task.id, 75);
    } catch (e, st) {
      await LoggerService.instance.error(
        'Transcription failed',
        taskId: task.id,
        error: e,
        stackTrace: st,
      );
      throw Exception('语音识别失败: $e');
    }
  }

  Future<void> _ensureLocalModel(Task task, String model) async {
    try {
      final models = await NativeService.getModels();
      final list = (models['models'] as List?)?.cast<Map>() ?? [];
      final target = list.firstWhere(
        (m) => m['name']?.toString() == model,
        orElse: () => <String, dynamic>{},
      );
      if (target.isNotEmpty && target['status']?.toString() == 'downloaded') {
        return;
      }
      throw Exception('模型未下载: $model');
    } on Exception {
      rethrow;
    } catch (e) {
      throw Exception('模型检查失败: $e');
    }
  }

  /// 执行摘要生成
  Future<void> _executeSummary(Task task) async {
    await updateTaskProgress(task.id, 85);

    try {
      final transcription = await _db.getTranscription(task.id);
      if (transcription == null) return;
      final config = await ConfigService().loadConfig();
      final providerConfig = _resolveSummaryProviderConfig(config);

      final result = await NativeService.summarize(
        text: transcription.fullText,
        length: task.summaryLength,
        provider: providerConfig['provider'] as String? ?? 'local',
        taskId: task.id,
        providerConfig: providerConfig,
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
    } catch (e, st) {
      // 摘要失败不阻断流程
      await LoggerService.instance.warn(
        'Summary failed, continue task',
        taskId: task.id,
        fields: {'error': e.toString()},
      );
      await LoggerService.instance.error(
        'Summary exception detail',
        taskId: task.id,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// 生成任务编号
  String _generateTaskNo() {
    final now = DateTime.now();
    return 'TR${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> _resolveProviderConfig(
      AppConfig config, String provider) {
    if (provider == 'whisper' || provider == 'local') {
      return {
        'provider': 'whisper',
        'model': config.transcription.local.model,
        'model_source': config.transcription.local.modelSource,
        'model_root_dir': config.transcription.local.modelRootDir,
        'hf_endpoint': config.transcription.local.hfEndpoint,
        'whisper_weights_base_url':
            config.transcription.local.whisperWeightsBaseUrl,
      };
    }
    final channel = config.transcription.cloudChannels
        .where((c) => c.enabled && c.provider == provider)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (channel.isEmpty) {
      return {'provider': 'whisper'};
    }
    final selected = channel.first;
    return {
      'provider': selected.provider,
      'api_key': selected.config['api_key'],
      'api_url': selected.config['api_url'],
      'model': selected.config['model'],
    };
  }

  Map<String, dynamic> _resolveSummaryProviderConfig(AppConfig config) {
    final channel = config.summary.channels.where((c) => c.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    if (channel.isEmpty) {
      return {'provider': 'local'};
    }
    final selected = channel.first;
    return {
      'provider': selected.provider,
      'api_key': selected.config['api_key'],
      'api_url': selected.config['api_url'],
      'model': selected.config['model'],
    };
  }

  Future<void> _createWorkflowStep(
      Task task, String name, WorkflowStatus status) async {
    final step = WorkflowStep(
      id: _uuid.v4(),
      taskId: task.id,
      name: name,
      status: status,
      startTime: DateTime.now(),
      progress: status == WorkflowStatus.running ? 10 : 0,
    );
    await _db.insertWorkflowStep(step);
  }

  Future<void> _completeWorkflowStep(Task task, String name) async {
    final steps = await _db.getWorkflowSteps(task.id);
    final step = steps.lastWhere((s) => s.name == name,
        orElse: () => WorkflowStep(
              id: _uuid.v4(),
              taskId: task.id,
              name: name,
              status: WorkflowStatus.completed,
            ));
    final updated = WorkflowStep(
      id: step.id,
      taskId: step.taskId,
      name: step.name,
      status: WorkflowStatus.completed,
      channel: step.channel,
      progress: 100,
      startTime: step.startTime,
      endTime: DateTime.now(),
      error: step.error,
      logs: step.logs,
    );
    await _db.updateWorkflowStep(updated);
  }

  Future<void> _failWorkflowStep(Task task, String error) async {
    final steps = await _db.getWorkflowSteps(task.id);
    if (steps.isEmpty) return;
    final step = steps.last;
    final updated = WorkflowStep(
      id: step.id,
      taskId: step.taskId,
      name: step.name,
      status: WorkflowStatus.failed,
      channel: step.channel,
      progress: step.progress,
      startTime: step.startTime,
      endTime: DateTime.now(),
      error: error,
      logs: [...step.logs, error],
    );
    await _db.updateWorkflowStep(updated);
  }
}
