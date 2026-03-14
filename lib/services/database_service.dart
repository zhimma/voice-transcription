import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/task.dart';

class DatabaseService {
  static Database? _db;
  static final DatabaseService instance = DatabaseService._internal();
  
  DatabaseService._internal();
  
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }
  
  Future<Database> _initDatabase() async {
    final appDir = await getApplicationSupportDirectory();
    final dbPath = join(appDir.path, 'voice_transcription.db');
    
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // 任务表
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        task_no TEXT NOT NULL,
        status TEXT NOT NULL,
        progress INTEGER DEFAULT 0,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        audio_format TEXT,
        duration INTEGER,
        model TEXT NOT NULL,
        language TEXT DEFAULT 'auto',
        enable_speaker INTEGER DEFAULT 0,
        generate_summary INTEGER DEFAULT 1,
        summary_length TEXT DEFAULT 'medium',
        created_at TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        error_message TEXT
      )
    ''');
    
    // 转写结果表
    await db.execute('''
      CREATE TABLE transcriptions (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        full_text TEXT NOT NULL,
        word_count INTEGER,
        language TEXT,
        confidence REAL,
        segments TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    
    // 摘要表
    await db.execute('''
      CREATE TABLE summaries (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        short TEXT,
        medium TEXT,
        long TEXT,
        key_points TEXT,
        keywords TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    
    // 工作流步骤表
    await db.execute('''
      CREATE TABLE workflow_steps (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        channel TEXT,
        progress INTEGER DEFAULT 0,
        start_time TEXT,
        end_time TEXT,
        error TEXT,
        logs TEXT,
        FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
      )
    ''');
    
    // 索引
    await db.execute('CREATE INDEX idx_tasks_status ON tasks(status)');
    await db.execute('CREATE INDEX idx_tasks_created_at ON tasks(created_at)');
    await db.execute('CREATE INDEX idx_transcriptions_task_id ON transcriptions(task_id)');
    await db.execute('CREATE INDEX idx_summaries_task_id ON summaries(task_id)');
  }
  
  // 任务 CRUD
  Future<String> insertTask(Task task) async {
    final db = await database;
    await db.insert('tasks', _taskToMap(task));
    return task.id;
  }
  
  Future<Task?> getTask(String id) async {
    final db = await database;
    final maps = await db.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) return null;
    
    final task = _mapToTask(maps.first);
    
    // 加载关联数据
    task.transcription = await getTranscription(id);
    task.summary = await getSummary(id);
    task.steps = await getWorkflowSteps(id);
    
    return task;
  }
  
  Future<List<Task>> getTasks({
    TaskStatus? status,
    String? keyword,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    
    String? where;
    List<Object?>? whereArgs;
    
    if (status != null) {
      where = 'status = ?';
      whereArgs = [status.name];
    }
    
    if (keyword != null && keyword.isNotEmpty) {
      where = where != null ? '$where AND file_name LIKE ?' : 'file_name LIKE ?';
      whereArgs = whereArgs != null ? [...whereArgs, '%$keyword%'] : ['%$keyword%'];
    }
    
    final maps = await db.query(
      'tasks',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    
    return maps.map(_mapToTask).toList();
  }
  
  Future<void> updateTask(Task task) async {
    final db = await database;
    await db.update(
      'tasks',
      _taskToMap(task),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }
  
  Future<void> updateTaskStatus(String id, TaskStatus status, {String? error}) async {
    final db = await database;
    final updates = {'status': status.name};
    
    if (status == TaskStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    if (error != null) {
      updates['error_message'] = error;
    }
    
    await db.update(
      'tasks',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> updateTaskProgress(String id, int progress) async {
    final db = await database;
    await db.update(
      'tasks',
      {'progress': progress},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteTask(String id) async {
    final db = await database;
    await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // 转写结果
  Future<void> insertTranscription(TranscriptionResult result) async {
    final db = await database;
    await db.insert('transcriptions', _transcriptionToMap(result));
  }
  
  Future<TranscriptionResult?> getTranscription(String taskId) async {
    final db = await database;
    final maps = await db.query(
      'transcriptions',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    
    if (maps.isEmpty) return null;
    return _mapToTranscription(maps.first);
  }
  
  // 摘要
  Future<void> insertSummary(SummaryResult summary) async {
    final db = await database;
    await db.insert('summaries', _summaryToMap(summary));
  }
  
  Future<SummaryResult?> getSummary(String taskId) async {
    final db = await database;
    final maps = await db.query(
      'summaries',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
    
    if (maps.isEmpty) return null;
    return _mapToSummary(maps.first);
  }
  
  // 工作流步骤
  Future<void> insertWorkflowStep(WorkflowStep step) async {
    final db = await database;
    await db.insert('workflow_steps', _stepToMap(step));
  }
  
  Future<void> updateWorkflowStep(WorkflowStep step) async {
    final db = await database;
    await db.update(
      'workflow_steps',
      _stepToMap(step),
      where: 'id = ?',
      whereArgs: [step.id],
    );
  }
  
  Future<List<WorkflowStep>> getWorkflowSteps(String taskId) async {
    final db = await database;
    final maps = await db.query(
      'workflow_steps',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'created_at',
    );
    return maps.map(_mapToStep).toList();
  }
  
  // 转换方法
  Map<String, dynamic> _taskToMap(Task task) {
    return {
      'id': task.id,
      'task_no': task.taskNo,
      'status': task.status.name,
      'progress': task.progress,
      'file_name': task.fileName,
      'file_path': task.filePath,
      'file_size': task.fileSize,
      'audio_format': task.audioFormat,
      'duration': task.duration,
      'model': task.model,
      'language': task.language,
      'enable_speaker': task.enableSpeaker ? 1 : 0,
      'generate_summary': task.generateSummary ? 1 : 0,
      'summary_length': task.summaryLength,
      'created_at': task.createdAt.toIso8601String(),
      'started_at': task.startedAt?.toIso8601String(),
      'completed_at': task.completedAt?.toIso8601String(),
      'error_message': task.errorMessage,
    };
  }
  
  Task _mapToTask(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      taskNo: map['task_no'],
      status: TaskStatus.values.firstWhere((e) => e.name == map['status']),
      progress: map['progress'],
      fileName: map['file_name'],
      filePath: map['file_path'],
      fileSize: map['file_size'],
      audioFormat: map['audio_format'],
      duration: map['duration'],
      model: map['model'],
      language: map['language'],
      enableSpeaker: map['enable_speaker'] == 1,
      generateSummary: map['generate_summary'] == 1,
      summaryLength: map['summary_length'],
      createdAt: DateTime.parse(map['created_at']),
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at']) : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at']) : null,
      errorMessage: map['error_message'],
    );
  }
  
  Map<String, dynamic> _transcriptionToMap(TranscriptionResult result) {
    return {
      'id': result.id,
      'task_id': result.taskId,
      'full_text': result.fullText,
      'word_count': result.wordCount,
      'language': result.language,
      'confidence': result.confidence,
      'segments': result.segments.map((s) => s.toJson()).toList().toString(),
      'created_at': result.createdAt.toIso8601String(),
    };
  }
  
  TranscriptionResult _mapToTranscription(Map<String, dynamic> map) {
    return TranscriptionResult(
      id: map['id'],
      taskId: map['task_id'],
      fullText: map['full_text'],
      wordCount: map['word_count'],
      language: map['language'],
      confidence: map['confidence'],
      segments: [], // TODO: parse segments
      createdAt: DateTime.parse(map['created_at']),
    );
  }
  
  Map<String, dynamic> _summaryToMap(SummaryResult summary) {
    return {
      'id': summary.id,
      'task_id': summary.taskId,
      'short': summary.short,
      'medium': summary.medium,
      'long': summary.long,
      'key_points': summary.keyPoints.join(','),
      'keywords': summary.keywords.join(','),
      'created_at': summary.createdAt.toIso8601String(),
    };
  }
  
  SummaryResult _mapToSummary(Map<String, dynamic> map) {
    return SummaryResult(
      id: map['id'],
      taskId: map['task_id'],
      short: map['short'],
      medium: map['medium'],
      long: map['long'],
      keyPoints: map['key_points']?.toString().split(',') ?? [],
      keywords: map['keywords']?.toString().split(',') ?? [],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
  
  Map<String, dynamic> _stepToMap(WorkflowStep step) {
    return {
      'id': step.id,
      'task_id': step.taskId,
      'name': step.name,
      'status': step.status.name,
      'channel': step.channel,
      'progress': step.progress,
      'start_time': step.startTime?.toIso8601String(),
      'end_time': step.endTime?.toIso8601String(),
      'error': step.error,
      'logs': step.logs.join('\n'),
    };
  }
  
  WorkflowStep _mapToStep(Map<String, dynamic> map) {
    return WorkflowStep(
      id: map['id'],
      taskId: map['task_id'],
      name: map['name'],
      status: WorkflowStatus.values.firstWhere((e) => e.name == map['status']),
      channel: map['channel'],
      progress: map['progress'],
      startTime: map['start_time'] != null ? DateTime.parse(map['start_time']) : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      error: map['error'],
      logs: map['logs']?.toString().split('\n') ?? [],
    );
  }
  
  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
