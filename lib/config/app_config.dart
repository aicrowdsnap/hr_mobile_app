import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _configuredBaseUrl =
      String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    // Production / QA / custom environment
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    // Flutter Web
    if (kIsWeb) {
      return 'https://novahr.crowdsnap.ai';
    }

    // Android Emulator
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'https://novahr.crowdsnap.ai';
    }

    // iOS Simulator
    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return 'https://novahr.crowdsnap.ai';
    }

    // Fallback
    return 'https://novahr.crowdsnap.ai';
  }
}