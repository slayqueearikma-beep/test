import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/services/crash_reporting.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Config-only base URL — never render it in the UI.
  if (kDebugMode) {
    debugPrint('MarGem API_BASE_URL=${AppConfig.apiBaseUrl}');
  }

  // Release/production builds must not ship with cleartext or emulator defaults.
  if (AppConfig.isProduction || kReleaseMode) {
    final api = AppConfig.apiBaseUrl;
    if (!api.startsWith('https://')) {
      throw StateError(
        'Release/PRODUCTION builds require HTTPS API_BASE_URL. Got: $api',
      );
    }
  }

  await CrashReporting.ensureInitialized();

  FlutterError.onError = (details) {
    CrashReporting.recordFlutterError(details);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReporting.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: MarGemApp()));
}
