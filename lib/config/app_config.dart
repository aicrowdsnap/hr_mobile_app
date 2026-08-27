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
      return 'http://localhost:3000';
    }

    // Android Emulator
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    // iOS Simulator
    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return 'http://localhost:3000';
    }

    // Fallback
    return 'http://localhost:3000';
  }
}