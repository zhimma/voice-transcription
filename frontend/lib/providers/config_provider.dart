import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../services/config_service.dart';

// 配置服务 Provider
final configServiceProvider = Provider<ConfigService>((ref) => ConfigService());

// 配置状态 Provider
final configProvider = StateNotifierProvider<ConfigNotifier, AsyncValue<AppConfig>>((ref) {
  return ConfigNotifier(ref.read(configServiceProvider));
});

// 配置状态管理
class ConfigNotifier extends StateNotifier<AsyncValue<AppConfig>> {
  final ConfigService _service;
  
  ConfigNotifier(this._service) : super(const AsyncValue.loading()) {
    loadConfig();
  }
  
  /// 加载配置
  Future<void> loadConfig() async {
    state = const AsyncValue.loading();
    try {
      final config = await _service.loadConfig();
      state = AsyncValue.data(config);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// 保存配置
  Future<void> saveConfig(AppConfig config) async {
    try {
      await _service.saveConfig(config);
      state = AsyncValue.data(config);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// 更新语音识别模式
  Future<void> updateTranscriptionMode(String mode) async {
    final current = state.value;
    if (current == null) return;
    
    final newConfig = current.copyWith(
      transcription: current.transcription.copyWith(mode: mode),
    );
    await saveConfig(newConfig);
  }
  
  /// 更新本地模型
  Future<void> updateLocalModel(String model) async {
    final current = state.value;
    if (current == null) return;
    
    final newConfig = current.copyWith(
      transcription: current.transcription.copyWith(
        local: current.transcription.local.copyWith(model: model),
      ),
    );
    await saveConfig(newConfig);
  }
  
  /// 添加云端渠道
  Future<void> addCloudChannel(ChannelConfig channel) async {
    final current = state.value;
    if (current == null) return;
    
    final channels = [...current.transcription.cloudChannels, channel];
    final newConfig = current.copyWith(
      transcription: current.transcription.copyWith(cloudChannels: channels),
    );
    await saveConfig(newConfig);
  }
  
  /// 删除云端渠道
  Future<void> removeCloudChannel(String id) async {
    final current = state.value;
    if (current == null) return;
    
    final channels = current.transcription.cloudChannels
        .where((c) => c.id != id)
        .toList();
    final newConfig = current.copyWith(
      transcription: current.transcription.copyWith(cloudChannels: channels),
    );
    await saveConfig(newConfig);
  }
  
  /// 更新渠道优先级
  Future<void> reorderChannels(List<ChannelConfig> channels) async {
    final current = state.value;
    if (current == null) return;
    
    // 更新优先级
    final updatedChannels = channels.asMap().entries.map((e) {
      return e.value.copyWith(priority: e.key + 1);
    }).toList();
    
    final newConfig = current.copyWith(
      transcription: current.transcription.copyWith(cloudChannels: updatedChannels),
    );
    await saveConfig(newConfig);
  }
  
  /// 从字符串导入配置
  Future<String> importFromString(String configStr) async {
    try {
      final config = await _service.importFromString(configStr);
      await saveConfig(config);
      return '配置导入成功';
    } catch (e) {
      return '导入失败: $e';
    }
  }

  Future<void> addRecentFile(String filePath) async {
    try {
      final updated = await _service.addRecentFile(filePath);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
  
  /// 导出配置
  String exportToString({bool hideSecrets = false}) {
    final current = state.value;
    if (current == null) return '';
    return _service.exportToString(current, hideSecrets: hideSecrets);
  }
}
