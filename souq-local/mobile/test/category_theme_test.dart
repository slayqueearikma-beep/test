import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:souq_local/core/models/models.dart';
import 'package:souq_local/core/services/app_storage.dart';

void main() {
  test('CategoryModel localizedName falls back to English', () {
    const category = CategoryModel(
      id: '1',
      slug: 'food',
      nameEn: 'Food',
      nameFr: 'Nourriture',
      nameAr: '',
      icon: 'restaurant',
    );
    expect(category.localizedName('en'), 'Food');
    expect(category.localizedName('fr'), 'Nourriture');
    expect(category.localizedName('ar'), 'Food');
  });

  test('AppStorage persists theme mode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);
    expect(storage.getThemeMode(), ThemeMode.system);
    await storage.saveThemeMode(ThemeMode.dark);
    expect(storage.getThemeMode(), ThemeMode.dark);
    await storage.saveThemeMode(ThemeMode.light);
    expect(storage.getThemeMode(), ThemeMode.light);
  });
}
