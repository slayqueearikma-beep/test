import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/auth_models.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

typedef TokenRefreshCallback = Future<bool> Function();
typedef SessionExpiredCallback = Future<void> Function();

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 15);
  static const _submitTimeout = Duration(seconds: 25);

  final http.Client _client;

  String? Function()? tokenProvider;
  TokenRefreshCallback? onTokenRefresh;
  SessionExpiredCallback? onSessionExpired;

  bool _refreshInProgress = false;

  Map<String, String> get _authHeaders {
    final token = tokenProvider?.call();
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, String> _jsonHeaders({bool auth = false}) {
    return {
      'Content-Type': 'application/json',
      if (auth) ..._authHeaders,
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.apiBaseUrl}$path')
        .replace(queryParameters: query);
  }

  Future<void> checkHealth() async {
    final response = await _get(_uri('/health'));
    _ensureSuccess(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['database'] == 'error') {
      throw ApiException('API database is unavailable');
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async {
    final response = await _request(
      () => _client.patch(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJson(String path, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri(path), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getJsonList(String path, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri(path), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<void> deleteJson(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final response = await _request(
      () => _client.delete(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<void> deletePath(String path, {bool auth = false}) async {
    final response = await _request(
      () => _client.delete(
        _uri(path),
        headers: auth ? _jsonHeaders(auth: true) : _jsonHeaders(),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<void> postVoid(String path, Map<String, dynamic> body,
      {bool auth = false}) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
        body: jsonEncode(body),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> postEmpty(String path,
      {bool auth = false}) async {
    final response = await _request(
      () => _post(
        _uri(path),
        headers: _jsonHeaders(auth: auth),
      ),
      auth: auth,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<http.Response> _get(Uri uri, {Map<String, String>? headers}) {
    return _send(() => _client.get(uri, headers: headers));
  }

  Future<http.Response> _post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return _send(() => _client.post(uri, headers: headers, body: body));
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send, {
    required bool auth,
  }) async {
    var response = await _send(send);
    if (auth &&
        response.statusCode == 401 &&
        onTokenRefresh != null &&
        !_refreshInProgress) {
      _refreshInProgress = true;
      try {
        final refreshed = await onTokenRefresh!();
        if (refreshed) {
          response = await _send(send);
        } else if (onSessionExpired != null) {
          await onSessionExpired!();
        }
      } finally {
        _refreshInProgress = false;
      }
    }
    return response;
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on TimeoutException {
      throw ApiException(_connectionErrorMessage);
    } on SocketException {
      throw ApiException(_connectionErrorMessage);
    } on http.ClientException {
      throw ApiException(_connectionErrorMessage);
    } on ApiException {
      rethrow;
    } on Object {
      throw ApiException(_connectionErrorMessage);
    }
  }

  Future<T> runSubmit<T>(Future<T> Function() action) {
    return action().timeout(
      _submitTimeout,
      onTimeout: () => throw ApiException(
        'Request timed out after ${_submitTimeout.inSeconds}s.\n$_connectionErrorMessage',
      ),
    );
  }

  String get _connectionErrorMessage {
    if (AppConfig.isProduction) {
      return 'Cannot reach the server. Check your internet connection and try again.';
    }
    final base = AppConfig.apiBaseUrl;
    final tip = RegExp(r':\d+$').hasMatch(base)
        ? ''
        : '\nTip: API_BASE_URL must include a colon before the port, e.g. http://192.168.1.10:8000';
    return 'Cannot reach the API at $base. Check your network connection and API_BASE_URL.$tip';
  }

  Future<String> createSeller(SellerCreatePayload payload) async {
    final data = await postJson('/sellers', payload.toJson(), auth: true);
    return data['id'] as String;
  }

  Future<SellerModel> fetchMySeller() async {
    final data = await getJson('/sellers/me', auth: true);
    return SellerModel.fromJson(data);
  }

  Future<SellerDashboardStats> fetchMySellerDashboard() async {
    final data = await getJson('/sellers/me/dashboard', auth: true);
    return SellerDashboardStats.fromJson(data);
  }

  Future<SellerModel> updateSeller(
      String sellerId, SellerUpdatePayload payload) async {
    final data =
        await patchJson('/sellers/$sellerId', payload.toJson(), auth: true);
    return SellerModel.fromJson(data);
  }

  Future<ProductModel> addProduct(
      String sellerId, ProductCreatePayload payload) async {
    final data = await postJson('/sellers/$sellerId/products', payload.toJson(),
        auth: true);
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> updateProduct(
    String sellerId,
    String productId,
    ProductUpdatePayload payload,
  ) async {
    final data = await patchJson(
      '/sellers/$sellerId/products/$productId',
      payload.toJson(),
      auth: true,
    );
    return ProductModel.fromJson(data);
  }

  Future<void> deleteProduct(String sellerId, String productId) async {
    await deletePath('/sellers/$sellerId/products/$productId', auth: true);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _request(
      () => _post(
        _uri('/auth/me/password'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      ),
      auth: true,
    );
    _ensureSuccess(response);
  }

  Future<List<AuthDeviceSession>> fetchAuthSessions() async {
    final data = await getJsonList('/auth/sessions', auth: true);
    return data
        .map((item) => AuthDeviceSession.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> revokeAuthSession(String sessionId) {
    return deletePath('/auth/sessions/$sessionId', auth: true);
  }

  Future<String?> categoryIdForSlug(String slug) async {
    final categories = await fetchCategories();
    for (final cat in categories) {
      if (cat.slug == slug) return cat.id;
    }
    return null;
  }

  Future<List<SellerModel>> fetchSellers({
    String? city,
    String? category,
    String? query,
  }) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (query != null && query.isNotEmpty) params['q'] = query;

    final response = await _request(
      () => _get(_uri('/sellers', params.isEmpty ? null : params),
          headers: _authHeaders),
      auth: _authHeaders.isNotEmpty,
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => SellerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SellerModel> fetchSeller(String id, {bool auth = false}) async {
    final response = await _request(
      () => _get(_uri('/sellers/$id'), headers: auth ? _authHeaders : null),
      auth: auth,
    );
    _ensureSuccess(response);
    return SellerModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<MapPinModel>> fetchMapPins(
      {String? city, String? category}) async {
    final params = <String, String>{};
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (category != null && category.isNotEmpty) params['category'] = category;

    final response =
        await _get(_uri('/sellers/map', params.isEmpty ? null : params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => MapPinModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final response = await _get(_uri('/categories'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<WarningZoneModel>> fetchWarningZones({String? city}) async {
    final params = city != null ? {'city': city} : null;
    final response = await _get(_uri('/warning-zones', params));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => WarningZoneModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ReviewModel>> fetchReviews(String sellerId) async {
    final response = await _get(_uri('/sellers/$sellerId/reviews'));
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> submitReview(String sellerId,
      {required int rating, String comment = ''}) async {
    final response = await _request(
      () => _post(
        _uri('/sellers/$sellerId/reviews'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
  }

  Future<List<FavoriteItemModel>> fetchFavorites() async {
    final data = await getJsonList('/favorites', auth: true);
    return data
        .map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteItemModel> addFavoriteProduct(String productId) async {
    final data = await postEmpty('/favorites/products/$productId', auth: true);
    return FavoriteItemModel.fromJson(data);
  }

  Future<void> removeFavoriteProduct(String productId) {
    return deletePath('/favorites/products/$productId', auth: true);
  }

  Future<List<FavoriteItemModel>> migrateGuestFavorites(
      List<Map<String, dynamic>> items) async {
    final response = await _request(
      () => _post(
        _uri('/favorites/migrate-guest'),
        headers: _jsonHeaders(auth: true),
        body: jsonEncode({'items': items}),
      ),
      auth: true,
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => FavoriteItemModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SellerFollowModel> followSeller(String sellerId) async {
    final data = await postEmpty('/follows/sellers/$sellerId', auth: true);
    return SellerFollowModel.fromJson(data);
  }

  Future<void> unfollowSeller(String sellerId) {
    return deletePath('/follows/sellers/$sellerId', auth: true);
  }

  Future<List<SellerFollowModel>> listFollows() async {
    final data = await getJsonList('/follows', auth: true);
    return data
        .map((item) => SellerFollowModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> createContactEvent({
    required String sellerId,
    required String channel,
  }) {
    return postVoid(
      '/contact-events',
      {'seller_id': sellerId, 'channel': channel},
      auth: _authHeaders.isNotEmpty,
    );
  }

  Future<void> createReport({
    String? sellerId,
    String? productId,
    required String reason,
    String details = '',
  }) {
    return postVoid(
      '/reports',
      {
        if (sellerId != null) 'seller_id': sellerId,
        if (productId != null) 'product_id': productId,
        'reason': reason,
        'details': details,
      },
      auth: _authHeaders.isNotEmpty,
    );
  }

  Future<void> trackRecentlyViewed({String? sellerId, String? productId}) {
    final params = <String, String>{
      if (sellerId != null) 'seller_id': sellerId,
      if (productId != null) 'product_id': productId,
    };
    return _request(
      () => _post(
        _uri('/recently-viewed', params),
        headers: _jsonHeaders(auth: true),
      ),
      auth: true,
    ).then(_ensureSuccess);
  }

  Future<SellerAnalyticsModel> fetchSellerAnalytics() async {
    final data = await getJson('/seller/analytics', auth: true);
    return SellerAnalyticsModel.fromJson(data);
  }

  Future<List<AppNotificationModel>> fetchNotifications() async {
    final data = await getJsonList('/notifications', auth: true);
    return data
        .map((item) =>
            AppNotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markNotificationRead(String id) {
    return postVoid('/notifications/$id/read', const {}, auth: true);
  }

  Future<void> markAllNotificationsRead() {
    return postVoid('/notifications/read-all', const {}, auth: true);
  }

  Future<List<SubscriptionPlanModel>> fetchSubscriptionPlans() async {
    final data = await getJsonList('/subscriptions/plans');
    return data
        .map((item) =>
            SubscriptionPlanModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SubscriptionModel?> fetchMySubscription() async {
    final response = await _request(
      () => _get(_uri('/subscriptions/me'), headers: _authHeaders),
      auth: true,
    );
    _ensureSuccess(response);
    if (response.body.isEmpty || response.body == 'null') return null;
    return SubscriptionModel.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SubscriptionModel> subscribe(String planCode) async {
    final data =
        await postEmpty('/subscriptions/subscribe/$planCode', auth: true);
    return SubscriptionModel.fromJson(data);
  }

  Future<void> requestPasswordReset(String email) {
    return postVoid('/auth/password-reset/request', {'email': email},
        auth: false);
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) {
    return postVoid(
      '/auth/password-reset/confirm',
      {'token': token, 'new_password': newPassword},
      auth: false,
    );
  }

  Future<void> requestEmailVerification() {
    return postVoid('/auth/verify-email/request', const {}, auth: true);
  }

  Future<void> confirmEmailVerification(String token) {
    return postVoid('/auth/verify-email/confirm', {'token': token},
        auth: false);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(
      _messageFromErrorResponse(response),
      statusCode: response.statusCode,
    );
  }

  String _messageFromErrorResponse(http.Response response) {
    if (response.statusCode == 429) {
      return 'Too many requests. Please wait about a minute and try again.';
    }
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final error = body['error'];
        if (error is String && error.isNotEmpty) {
          if (error.toLowerCase().contains('rate limit')) {
            return 'Too many requests. Please wait about a minute and try again.';
          }
          return error;
        }
        final detail = body['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List) {
          final messages = detail
              .map((item) {
                if (item is Map<String, dynamic>) {
                  final msg = item['msg']?.toString();
                  if (msg == null || msg.isEmpty) return null;
                  final loc = item['loc'];
                  if (loc is List && loc.isNotEmpty) {
                    return '${loc.last}: $msg';
                  }
                  return msg;
                }
                return item.toString();
              })
              .whereType<String>()
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
        }
      }
    } on Object {
      // Fall through.
    }
    return 'Request failed (${response.statusCode})';
  }
}

final apiServiceProvider = ApiService();
