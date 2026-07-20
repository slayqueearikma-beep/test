import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import 'api_service.dart';

/// Handles registration, login, refresh rotation, and secure JWT persistence.
class AuthService {
  AuthService(this._api);

  final ApiService _api;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  String? _accessToken;
  String? _refreshToken;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  String? get accessToken => _accessToken;

  void bindApi({Future<void> Function()? onSessionExpired}) {
    _api.onTokenRefresh = refreshAccessToken;
    _api.onSessionExpired = onSessionExpired;
    _syncTokenProvider();
  }

  Future<void> loadStoredToken() async {
    _accessToken = await _storage.read(key: _accessTokenKey);
    _refreshToken = await _storage.read(key: _refreshTokenKey);
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

  Future<bool> refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await _api.postJson('/auth/refresh', {
        'refresh_token': refresh,
      });
      await _saveSession(AuthSession.fromJson(response));
      await _storage.write(key: _accessTokenKey, value: _accessToken!);
      await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
      return true;
    } on Object {
      return false;
    }
  }

  /// Returns true when stored credentials can access the API (refresh if needed).
  Future<bool> ensureSessionValid() async {
    await loadStoredToken();
    if ((_accessToken == null || _accessToken!.isEmpty) &&
        (_refreshToken == null || _refreshToken!.isEmpty)) {
      return false;
    }
    try {
      await _api.getJson('/auth/me', auth: true);
      return true;
    } on Object {
      return refreshAccessToken();
    }
  }

  Future<void> persistToken(SharedPreferences prefs) async {
    if (_accessToken != null) {
      await _storage.write(key: _accessTokenKey, value: _accessToken!);
    }
    if (_refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: _refreshToken!);
    }
  }

  Future<void> logout(SharedPreferences prefs) async {
    if (_refreshToken != null) {
      try {
        await _api.postJson('/auth/logout', {'refresh_token': _refreshToken!});
      } on Object {
        // Best-effort server revocation.
      }
    }
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    _syncTokenProvider();
  }

  Future<void> deleteAccount({required String password}) async {
    await _api.deleteJson(
      '/auth/me',
      {'password': password, 'confirmation': 'DELETE'},
      auth: true,
    );
    _accessToken = null;
    _refreshToken = null;
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    _syncTokenProvider();
  }

  Future<AuthSession> _saveSession(AuthSession session) async {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
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
