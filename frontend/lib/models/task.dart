import 'dart:convert';
import 'conversation_analysis.dart';

enum TaskStatus { pending, processing, completed, failed }

enum WorkflowStatus { pending, running, completed, failed }

class Task {
  final String id;
  final String taskNo;
  final TaskStatus status;
  final int progress;
  final String fileName;
  final String filePath;
  final int fileSize;
  final String? audioFormat;
  final int? duration;
  final int? sampleRate;
  final String model;
  final String language;
  final String provider;
  final bool enableSpeaker;
  final bool generateSummary;
  final String summaryLength;
  final bool enableConversationAnalysis;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? errorMessage;

  final TranscriptionResult? transcription;
  final SummaryResult? summary;
  final ConversationAnalysis? conversationAnalysis;
  final List<WorkflowStep> steps;

  Task({
    required this.id,
    required this.taskNo,
    required this.status,
    this.progress = 0,
    required this.fileName,
    required this.filePath,
    required this.fileSize,
    this.audioFormat,
    this.duration,
    this.sampleRate,
    required this.model,
    this.language = 'auto',
    this.provider = 'whisper',
    this.enableSpeaker = false,
    this.generateSummary = true,
    this.summaryLength = 'medium',
    this.enableConversationAnalysis = false,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.transcription,
    this.summary,
    this.conversationAnalysis,
    List<WorkflowStep>? steps,
  }) : steps = List.unmodifiable(steps ?? const []);

  Task copyWith({
    String? id,
    String? taskNo,
    TaskStatus? status,
    int? progress,
    String? fileName,
    String? filePath,
    int? fileSize,
    String? audioFormat,
    int? duration,
    int? sampleRate,
    String? model,
    String? language,
    String? provider,
    bool? enableSpeaker,
    bool? generateSummary,
    String? summaryLength,
    bool? enableConversationAnalysis,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    TranscriptionResult? transcription,
    SummaryResult? summary,
    ConversationAnalysis? conversationAnalysis,
    List<WorkflowStep>? steps,
  }) {
    return Task(
      id: id ?? this.id,
      taskNo: taskNo ?? this.taskNo,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      audioFormat: audioFormat ?? this.audioFormat,
      duration: duration ?? this.duration,
      sampleRate: sampleRate ?? this.sampleRate,
      model: model ?? this.model,
      language: language ?? this.language,
      provider: provider ?? this.provider,
      enableSpeaker: enableSpeaker ?? this.enableSpeaker,
      generateSummary: generateSummary ?? this.generateSummary,
      summaryLength: summaryLength ?? this.summaryLength,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      transcription: transcription ?? this.transcription,
      summary: summary ?? this.summary,
      conversationAnalysis: conversationAnalysis ?? this.conversationAnalysis,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_no': taskNo,
      'status': status.name,
      'progress': progress,
      'file_name': fileName,
      'file_path': filePath,
      'file_size': fileSize,
      'audio_format': audioFormat,
      'duration': duration,
      'sample_rate': sampleRate,
      'model': model,
      'language': language,
      'provider': provider,
      'enable_speaker': enableSpeaker,
      'generate_summary': generateSummary,
      'summary_length': summaryLength,
      'enable_conversation_analysis': enableConversationAnalysis,
      'created_at': createdAt.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'error_message': errorMessage,
      'transcription': transcription?.toJson(),
      'summary': summary?.toJson(),
      'conversation_analysis': conversationAnalysis?.toJson(),
      'steps': steps.map((s) => s.toJson()).toList(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      taskNo: json['task_no'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => TaskStatus.pending,
      ),
      progress: json['progress'] as int? ?? 0,
      fileName: json['file_name'] as String? ?? '',
      filePath: json['file_path'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      audioFormat: json['audio_format'] as String?,
      duration: json['duration'] as int?,
      sampleRate: json['sample_rate'] as int?,
      model: json['model'] as String? ?? 'small',
      language: json['language'] as String? ?? 'auto',
      provider: json['provider'] as String? ?? 'whisper',
      enableSpeaker: json['enable_speaker'] as bool? ?? false,
      generateSummary: json['generate_summary'] as bool? ?? true,
      summaryLength: json['summary_length'] as String? ?? 'medium',
      enableConversationAnalysis: json['enable_conversation_analysis'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      transcription: json['transcription'] != null
          ? TranscriptionResult.fromJson(
              Map<String, dynamic>.from(json['transcription'] as Map))
          : null,
      summary: json['summary'] != null
          ? SummaryResult.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map))
          : null,
      conversationAnalysis: json['conversation_analysis'] != null
          ? ConversationAnalysis.fromJson(
              Map<String, dynamic>.from(json['conversation_analysis'] as Map))
          : null,
      steps: (json['steps'] as List?)
              ?.map((e) =>
                  WorkflowStep.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }
}

class TranscriptionResult {
  final String id;
  final String taskId;
  final String fullText;
  final int? wordCount;
  final String language;
  final double? confidence;
  final List<Segment> segments;
  final DateTime createdAt;

  const TranscriptionResult({
    required this.id,
    required this.taskId,
    required this.fullText,
    this.wordCount,
    required this.language,
    this.confidence,
    required this.segments,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'full_text': fullText,
      'word_count': wordCount,
      'language': language,
      'confidence': confidence,
      'segments': segments.map((s) => s.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      fullText: json['full_text'] as String? ?? '',
      wordCount: json['word_count'] as int?,
      language: json['language'] as String? ?? 'unknown',
      confidence: (json['confidence'] as num?)?.toDouble(),
      segments: (json['segments'] as List?)
              ?.map(
                  (e) => Segment.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  static List<Segment> decodeSegments(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => Segment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}

class Segment {
  final int id;
  final double startTime;
  final double endTime;
  final String text;

  const Segment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': startTime,
      'end': endTime,
      'text': text,
    };
  }

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      id: json['id'] as int? ?? 0,
      startTime: (json['start'] as num?)?.toDouble() ?? 0,
      endTime: (json['end'] as num?)?.toDouble() ?? 0,
      text: json['text'] as String? ?? '',
    );
  }
}

class SummaryResult {
  final String id;
  final String taskId;
  final String short;
  final String medium;
  final String long;
  final List<String> keyPoints;
  final List<String> keywords;
  final DateTime createdAt;

  // 新增：存储原始JSON数据，用于动态渲染
  final Map<String, dynamic> rawData;

  const SummaryResult({
    required this.id,
    required this.taskId,
    required this.short,
    required this.medium,
    required this.long,
    required this.keyPoints,
    required this.keywords,
    required this.createdAt,
    this.rawData = const {},
  });

  /// 从API响应创建SummaryResult
  /// 同时提取固定字段和保存原始数据
  factory SummaryResult.fromApiResponse(
    String id,
    String taskId,
    Map<String, dynamic> response,
  ) {
    return SummaryResult(
      id: id,
      taskId: taskId,
      // 尝试提取已知字段（向后兼容）
      short: _extractString(response, ['short', 'brief', 'summary_short']) ?? '',
      medium:
          _extractString(response, ['medium', 'summary', 'summary_medium']) ??
              '',
      long:
          _extractString(response, ['long', 'detailed', 'summary_long']) ?? '',
      keyPoints:
          _extractStringList(response, ['key_points', 'keyPoints', 'points']) ??
              [],
      keywords:
          _extractStringList(response, ['keywords', 'tags', 'key_words']) ?? [],
      // 存储完整原始数据
      rawData: Map<String, dynamic>.from(response),
      createdAt: DateTime.now(),
    );
  }

  /// 辅助方法：从多个可能的key中提取字符串
  static String? _extractString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  /// 辅助方法：从多个可能的key中提取字符串列表
  static List<String>? _extractStringList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value.map((e) => e.toString()).toList();
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'short': short,
      'medium': medium,
      'long': long,
      'key_points': keyPoints,
      'keywords': keywords,
      'raw_data': rawData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SummaryResult.fromJson(Map<String, dynamic> json) {
    return SummaryResult(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      short: json['short'] as String? ?? '',
      medium: json['medium'] as String? ?? '',
      long: json['long'] as String? ?? '',
      keyPoints:
          (json['key_points'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      keywords:
          (json['keywords'] as List?)?.map((e) => e.toString()).toList() ?? [],
      rawData: json['raw_data'] != null
          ? Map<String, dynamic>.from(json['raw_data'] as Map)
          : {},
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }
}

class WorkflowStep {
  final String id;
  final String taskId;
  final String name;
  final WorkflowStatus status;
  final String? channel;
  final int progress;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? error;
  final List<String> logs;

  const WorkflowStep({
    required this.id,
    required this.taskId,
    required this.name,
    required this.status,
    this.channel,
    this.progress = 0,
    this.startTime,
    this.endTime,
    this.error,
    this.logs = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'name': name,
      'status': status.name,
      'channel': channel,
      'progress': progress,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'error': error,
      'logs': logs,
    };
  }

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id'] as String? ?? '',
      taskId: json['task_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: WorkflowStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending'),
        orElse: () => WorkflowStatus.pending,
      ),
      channel: json['channel'] as String?,
      progress: json['progress'] as int? ?? 0,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.parse(json['end_time'] as String)
          : null,
      error: json['error'] as String?,
      logs: (json['logs'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
