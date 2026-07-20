import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountType { buyer, seller }

class UserSession {
  const UserSession({
    required this.name,
    required this.email,
    required this.accountType,
    this.city,
    this.businessName,
  });

  final String name;
  final String email;
  final AccountType accountType;
  final String? city;
  final String? businessName;
}

class AppStorage {
  AppStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _loggedInKey = 'logged_in';
  static const _accountTypeKey = 'account_type';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userCityKey = 'user_city';
  static const _businessNameKey = 'business_name';
  static const _languageCodeKey = 'language_code';
  static const _languageSelectedKey = 'language_selected';

  bool get isOnboardingComplete => _prefs.getBool(_onboardingCompleteKey) ?? false;
  bool get isLoggedIn => _prefs.getBool(_loggedInKey) ?? false;
  bool get isLanguageSelected => _prefs.getBool(_languageSelectedKey) ?? false;

  String get languageCode => _prefs.getString(_languageCodeKey) ?? 'en';

  Locale getLocale() => Locale(languageCode);

  Future<void> saveLanguage(String languageCode) async {
    await _prefs.setString(_languageCodeKey, languageCode);
    await _prefs.setBool(_languageSelectedKey, true);
  }

  Future<void> completeOnboarding() => _prefs.setBool(_onboardingCompleteKey, true);

  Future<void> saveSession(UserSession session) async {
    await _prefs.setBool(_loggedInKey, true);
    await _prefs.setString(_accountTypeKey, session.accountType.name);
    await _prefs.setString(_userNameKey, session.name);
    await _prefs.setString(_userEmailKey, session.email);
    if (session.city != null) await _prefs.setString(_userCityKey, session.city!);
    if (session.businessName != null) await _prefs.setString(_businessNameKey, session.businessName!);
  }

  UserSession? getSession() {
    if (!isLoggedIn) return null;
    final typeName = _prefs.getString(_accountTypeKey);
    if (typeName == null) return null;
    return UserSession(
      name: _prefs.getString(_userNameKey) ?? 'User',
      email: _prefs.getString(_userEmailKey) ?? '',
      accountType: AccountType.values.byName(typeName),
      city: _prefs.getString(_userCityKey),
      businessName: _prefs.getString(_businessNameKey),
    );
  }

  Future<void> logout() async {
    await _prefs.remove(_loggedInKey);
    await _prefs.remove(_accountTypeKey);
    await _prefs.remove(_userNameKey);
    await _prefs.remove(_userEmailKey);
    await _prefs.remove(_userCityKey);
    await _prefs.remove(_businessNameKey);
  }

  Future<void> resetAll() async {
    await _prefs.clear();
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final appStorageProvider = Provider<AppStorage?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.maybeWhen(data: AppStorage.new, orElse: () => null);
});

final userSessionProvider = StateProvider<UserSession?>((ref) {
  return ref.watch(appStorageProvider)?.getSession();
});
