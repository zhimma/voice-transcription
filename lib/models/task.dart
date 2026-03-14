import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
class Task with _$Task {
  const factory Task({
    required String id,
    required String taskNo,
    required TaskStatus status,
    @Default(0) int progress,
    required String fileName,
    required String filePath,
    required int fileSize,
    String? audioFormat,
    int? duration,
    required String model,
    @Default('auto') String language,
    @Default(false) bool enableSpeaker,
    @Default(true) bool generateSummary,
    @Default('medium') String summaryLength,
    required DateTime createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    TranscriptionResult? transcription,
    SummaryResult? summary,
    @Default([]) List<WorkflowStep> steps,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

enum TaskStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

@freezed
class TranscriptionResult with _$TranscriptionResult {
  const factory TranscriptionResult({
    required String id,
    required String fullText,
    required int wordCount,
    required String language,
    @Default(0.95) double confidence,
    @Default([]) List<Segment> segments,
    required DateTime createdAt,
  }) = _TranscriptionResult;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionResultFromJson(json);
}

@freezed
class Segment with _$Segment {
  const factory Segment({
    required int id,
    required double startTime,
    required double endTime,
    required String text,
    String? speaker,
  }) = _Segment;

  factory Segment.fromJson(Map<String, dynamic> json) =>
      _$SegmentFromJson(json);
}

@freezed
class SummaryResult with _$SummaryResult {
  const factory SummaryResult({
    required String id,
    required String short,
    required String medium,
    required String long,
    @Default([]) List<String> keyPoints,
    @Default([]) List<String> keywords,
    required DateTime createdAt,
  }) = _SummaryResult;

  factory SummaryResult.fromJson(Map<String, dynamic> json) =>
      _$SummaryResultFromJson(json);
}

@freezed
class WorkflowStep with _$WorkflowStep {
  const factory WorkflowStep({
    required String id,
    required String name,
    required WorkflowStatus status,
    String? channel,
    @Default(0) int progress,
    DateTime? startTime,
    DateTime? endTime,
    String? error,
    @Default([]) List<String> logs,
  }) = _WorkflowStep;

  factory WorkflowStep.fromJson(Map<String, dynamic> json) =>
      _$WorkflowStepFromJson(json);
}

enum WorkflowStatus {
  pending,
  running,
  completed,
  failed,
  skipped,
}
