import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Release/production builds must not ship with cleartext or emulator defaults.
  if (AppConfig.isProduction || kReleaseMode) {
    final api = AppConfig.apiBaseUrl;
    if (!api.startsWith('https://')) {
      throw StateError(
        'Release/PRODUCTION builds require HTTPS API_BASE_URL. Got: $api',
      );
    }
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(const ProviderScope(child: MarGemApp()));
}
