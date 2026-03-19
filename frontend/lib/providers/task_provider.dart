import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_service.dart';

// 任务搜索关键字（全局）
final taskKeywordProvider = StateProvider<String>((ref) => '');

// 任务服务 Provider
final taskServiceProvider = Provider<TaskService>((ref) => TaskService());

// 任务列表 Provider
final taskListProvider =
    StateNotifierProvider<TaskListNotifier, AsyncValue<List<Task>>>((ref) {
  return TaskListNotifier(ref.read(taskServiceProvider));
});

// 当前任务 Provider
final currentTaskProvider =
    StateNotifierProvider<CurrentTaskNotifier, AsyncValue<Task?>>((ref) {
  return CurrentTaskNotifier(ref.read(taskServiceProvider));
});

// 任务列表状态管理
class TaskListNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final TaskService _service;

  TaskListNotifier(this._service) : super(const AsyncValue.loading()) {
    loadTasks();
  }

  /// 加载任务列表
  Future<void> loadTasks(
      {TaskStatus? status, String? keyword, bool silent = false}) async {
    if (!silent || state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final tasks = await _service.getTasks(status: status, keyword: keyword);
      state = AsyncValue.data(tasks);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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
    final task = await _service.createTask(
      fileName: fileName,
      filePath: filePath,
      fileSize: fileSize,
      model: model,
      provider: provider,
      language: language,
      generateSummary: generateSummary,
      summaryLength: summaryLength,
    );

    // 刷新列表
    await loadTasks();

    // 开始执行
    _service.executeTask(task);

    return task;
  }

  /// 删除任务
  Future<void> deleteTask(String id) async {
    await _service.deleteTask(id);
    await loadTasks();
  }

  Future<void> retryTask(String id) async {
    await _service.retryTask(id);
    await loadTasks();
  }
}

// 当前任务状态管理
class CurrentTaskNotifier extends StateNotifier<AsyncValue<Task?>> {
  final TaskService _service;

  CurrentTaskNotifier(this._service) : super(const AsyncValue.data(null));

  /// 加载任务
  Future<void> loadTask(String id, {bool keepCurrent = true}) async {
    if (!keepCurrent || state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final task = await _service.getTask(id);
      state = AsyncValue.data(task);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// 立即切换选中任务，避免点击后无响应感
  void setCurrentTask(Task task) {
    state = AsyncValue.data(task);
  }

  /// 刷新任务
  Future<void> refresh() async {
    final currentTask = state.value;
    if (currentTask != null) {
      await loadTask(currentTask.id);
    }
  }

  /// 清除当前任务
  void clear() {
    state = const AsyncValue.data(null);
  }
}

// 任务进度 Stream Provider
final taskProgressProvider =
    StreamProvider.family<double, String>((ref, taskId) {
  // 模拟进度更新
  return Stream.periodic(const Duration(seconds: 1), (i) => i * 0.1)
      .take(10)
      .map((i) => i > 1.0 ? 1.0 : i);
});
