import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'api_service.dart';

/// Handles registration, login, and JWT persistence for the MarGem API.
class AuthService {
  AuthService(this._api);

  final ApiService _api;
  String? _accessToken;

  static const _tokenKey = 'access_token';

  String? get accessToken => _accessToken;

  Future<void> loadStoredToken(SharedPreferences prefs) async {
    _accessToken = prefs.getString(_tokenKey);
    _syncTokenProvider();
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String accountType,
    required String displayName,
  }) async {
    final response = await _api.postJson('/auth/register', {
      'email': email,
      'password': password,
      'account_type': accountType,
      'display_name': displayName,
    });
    return _saveSession(AuthSession.fromJson(response));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    return _saveSession(AuthSession.fromJson(response));
  }

  Future<void> persistToken(SharedPreferences prefs) async {
    if (_accessToken != null) {
      await prefs.setString(_tokenKey, _accessToken!);
    }
  }

  Future<void> logout(SharedPreferences prefs) async {
    _accessToken = null;
    await prefs.remove(_tokenKey);
    _syncTokenProvider();
  }

  AuthSession _saveSession(AuthSession session) {
    _accessToken = session.accessToken;
    _syncTokenProvider();
    return session;
  }

  void _syncTokenProvider() {
    _api.tokenProvider = () => _accessToken;
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(apiServiceProvider);
});

final authSessionProvider = StateProvider<AuthSession?>((ref) => null);
