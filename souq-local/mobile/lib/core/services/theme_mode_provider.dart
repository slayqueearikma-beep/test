import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_storage.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(appStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._storage)
      : super(_storage?.getThemeMode() ?? ThemeMode.system);

  AppStorage? _storage;

  void updateStorage(AppStorage? storage) {
    _storage = storage;
    if (storage != null) {
      state = storage.getThemeMode();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _storage?.saveThemeMode(mode);
  }

  Future<void> toggleLightDark() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
