import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_storage.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final storage = ref.watch(appStorageProvider);
  return LocaleNotifier(storage);
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier(this._storage) : super(_storage?.getLocale() ?? const Locale('en'));

  AppStorage? _storage;

  void updateStorage(AppStorage? storage) {
    _storage = storage;
    if (storage != null && storage.isLanguageSelected) {
      state = storage.getLocale();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (_storage == null) return;
    await _storage!.saveLanguage(languageCode);
    state = Locale(languageCode);
  }
}
