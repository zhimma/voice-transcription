import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
class ChannelConfig with _$ChannelConfig {
  const factory ChannelConfig({
    required String id,
    required String name,
    required ChannelType type,
    required String provider,
    @Default(true) bool enabled,
    @Default(1) int priority,
    required Map<String, dynamic> config,
  }) = _ChannelConfig;

  factory ChannelConfig.fromJson(Map<String, dynamic> json) =>
      _$ChannelConfigFromJson(json);
}

enum ChannelType {
  local,
  api,
}

enum ChannelProvider {
  whisper,
  qwen,
  openai,
  deepseek,
  local,
}

@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    @Default('1.0') String version,
    required TranscriptionConfig transcription,
    required SummaryConfig summary,
    @Default(AppSettings()) AppSettings app,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}

@freezed
class TranscriptionConfig with _$TranscriptionConfig {
  const factory TranscriptionConfig({
    @Default('local') String mode,
    required LocalTranscriptionConfig local,
    @Default([]) List<ChannelConfig> cloudChannels,
  }) = _TranscriptionConfig;

  factory TranscriptionConfig.fromJson(Map<String, dynamic> json) =>
      _$TranscriptionConfigFromJson(json);
}

@freezed
class LocalTranscriptionConfig with _$LocalTranscriptionConfig {
  const factory LocalTranscriptionConfig({
    @Default('small') String model,
    @Default('auto') String device,
  }) = _LocalTranscriptionConfig;

  factory LocalTranscriptionConfig.fromJson(Map<String, dynamic> json) =>
      _$LocalTranscriptionConfigFromJson(json);
}

@freezed
class SummaryConfig with _$SummaryConfig {
  const factory SummaryConfig({
    @Default([]) List<ChannelConfig> channels,
  }) = _SummaryConfig;

  factory SummaryConfig.fromJson(Map<String, dynamic> json) =>
      _$SummaryConfigFromJson(json);
}

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default('auto') String theme,
    @Default('zh-CN') String language,
    @Default(true) bool autoUpdate,
  }) = _AppSettings;

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      _$AppSettingsFromJson(json);
}

@freezed
class ModelInfo with _$ModelInfo {
  const factory ModelInfo({
    required String name,
    required String displayName,
    required int size, // MB
    required String description,
    @Default(false) bool downloaded,
    String? downloadUrl,
    DateTime? downloadedAt,
  }) = _ModelInfo;

  factory ModelInfo.fromJson(Map<String, dynamic> json) =>
      _$ModelInfoFromJson(json);
}
