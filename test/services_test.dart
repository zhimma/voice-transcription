// 智能录音转写助手 - 服务层测试

import 'package:flutter_test/flutter_test.dart';
import '../lib/services/config_service.dart';

void main() {
  group('ConfigService Tests', () {
    late ConfigService configService;

    setUp(() {
      configService = ConfigService();
    });

    test('Default config values', () {
      final config = configService.defaultConfig;
      
      expect(config, isNotNull);
      expect(config['transcription'], isNotNull);
      expect(config['summary'], isNotNull);
    });

    test('Config validation', () {
      final validConfig = {
        'transcription': {
          'mode': 'local',
          'local': {'model': 'small'},
        },
      };
      
      expect(configService.validateConfig(validConfig), true);
    });

    test('Invalid config detection', () {
      final invalidConfig = {
        'transcription': null,
      };
      
      expect(configService.validateConfig(invalidConfig), false);
    });
  });
}
