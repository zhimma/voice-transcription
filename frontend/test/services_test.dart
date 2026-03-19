// 智能录音转写助手 - 服务层测试

import 'package:flutter_test/flutter_test.dart';
import 'package:voice_transcription/services/config_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigService Tests', () {
    late ConfigService configService;

    setUp(() {
      configService = ConfigService();
    });

    test('Can parse minimal config', () async {
      const jsonConfig = '''{
  "transcription": {
    "mode": "local",
    "local": { "model": "small", "device": "auto" },
    "cloud_channels": []
  },
  "summary": {
    "channels": [
      {
        "id": "local-summary",
        "name": "本地简化版",
        "type": "local",
        "provider": "local",
        "enabled": true,
        "priority": 1,
        "config": {}
      }
    ]
  }
}''';
      final config = await configService.importFromString(jsonConfig);
      expect(config.transcription, isNotNull);
      expect(config.summary, isNotNull);
    });

    test('Config import/validate (JSON)', () async {
      const jsonConfig = '''{
  "version": "1.0",
  "transcription": {
    "mode": "local",
    "local": { "model": "small", "device": "auto" },
    "cloud_channels": []
  },
  "summary": {
    "channels": [
      {
        "id": "local-summary",
        "name": "本地简化版",
        "type": "local",
        "provider": "local",
        "enabled": true,
        "priority": 1,
        "config": {}
      }
    ]
  }
}''';
      final config = await configService.importFromString(jsonConfig);
      await configService.validateConfig(config);
      expect(config.transcription.mode, 'local');
    });

    test('Config validation failure', () async {
      const jsonConfig = '''{
  "transcription": {
    "mode": "cloud",
    "local": { "model": "small", "device": "auto" },
    "cloud_channels": []
  },
  "summary": {
    "channels": []
  }
}''';
      await expectLater(
        () => configService.importFromString(jsonConfig),
        throwsException,
      );
    });
  });
}
