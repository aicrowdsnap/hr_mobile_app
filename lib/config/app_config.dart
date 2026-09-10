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
      return 'https://novahr.cloud';
    }

    // Android Emulator
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'https://novahr.cloud';
    }

    // iOS Simulator
    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return 'https://novahr.cloud';
    }

    // Fallback
    return 'https://novahr.cloud';
  }
}