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
      return 'https://hr-app-5ui3.onrender.com';
    }

    // Android Emulator
    if (defaultTargetPlatform ==
        TargetPlatform.android) {
      return 'https://hr-app-5ui3.onrender.com';
    }

    // iOS Simulator
    if (defaultTargetPlatform ==
        TargetPlatform.iOS) {
      return 'https://hr-app-5ui3.onrender.com';
    }

    // Fallback
    return 'https://hr-app-5ui3.onrender.com';
  }
}