import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http';

import '../config/app_config.dart';
import '../data/demo_catalog_data.dart';
import '../data/demo_map_data.dart';
import '../models/auth_models.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const _requestTimeout = Duration(seconds: 10);
  static const _submitTimeout = Duration(seconds: 25);

  final http.Client _client;

  /// True when the last request fell back to offline demo data.
  bool isUsingDemoData = false;

  /// JWT from [AuthService] — attached to protected routes.
  String? Function()? tokenProvider;

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
    return Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);
  }

  Future<void> checkHealth() async {
    final response = await _get(_uri('/health'));
    _ensureSuccess(response);
  }

  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body, {bool auth = false}) async {
    final response = await _post(
      _uri(path),
      headers: _jsonHeaders(auth: auth),
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
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

  String get _connectionErrorMessage =>
      'Cannot reach the API at ${AppConfig.apiBaseUrl}. '
      'Start the backend (docker compose up) and, on a physical phone, '
      'run with --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000';

  Future<String> createSeller(SellerCreatePayload payload) async {
    final data = await postJson('/sellers', payload.toJson(), auth: true);
    return data['id'] as String;
  }

  Future<void> addProduct(String sellerId, ProductCreatePayload payload) async {
    await postJson('/sellers/$sellerId/products', payload.toJson(), auth: true);
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
    return _withDemoFallback(
      () async {
        final params = <String, String>{};
        if (city != null && city.isNotEmpty) params['city'] = city;
        if (category != null && category.isNotEmpty) params['category'] = category;
        if (query != null && query.isNotEmpty) params['q'] = query;

        final response = await _get(_uri('/sellers', params.isEmpty ? null : params), headers: _authHeaders);
        _ensureSuccess(response);
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => SellerModel.fromJson(e as Map<String, dynamic>)).toList();
      },
      () => DemoCatalogData.sellersForCity(city ?? 'Casablanca', query: query),
    );
  }

  Future<SellerModel> fetchSeller(String id) async {
    return _withDemoFallback(
      () async {
        final response = await _get(_uri('/sellers/$id'));
        _ensureSuccess(response);
        return SellerModel.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      },
      () {
        final demo = DemoCatalogData.sellerById(id);
        if (demo == null) throw ApiException('Seller not found');
        return demo;
      },
    );
  }

  Future<List<MapPinModel>> fetchMapPins({String? city, String? category}) async {
    return _withDemoFallback(
      () async {
        final params = <String, String>{};
        if (city != null && city.isNotEmpty) params['city'] = city;
        if (category != null && category.isNotEmpty) params['category'] = category;

        final response = await _get(_uri('/sellers/map', params.isEmpty ? null : params));
        _ensureSuccess(response);
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => MapPinModel.fromJson(e as Map<String, dynamic>)).toList();
      },
      () => DemoMapData.pinsForCity(city ?? 'Casablanca'),
    );
  }

  Future<List<CategoryModel>> fetchCategories() async {
    return _withDemoFallback(
      () async {
        final response = await _get(_uri('/categories'));
        _ensureSuccess(response);
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)).toList();
      },
      () => DemoCatalogData.categories,
    );
  }

  Future<List<WarningZoneModel>> fetchWarningZones({String? city}) async {
    return _withDemoFallback(
      () async {
        final params = city != null ? {'city': city} : null;
        final response = await _get(_uri('/warning-zones', params));
        _ensureSuccess(response);
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => WarningZoneModel.fromJson(e as Map<String, dynamic>)).toList();
      },
      () => const <WarningZoneModel>[],
    );
  }

  Future<List<ReviewModel>> fetchReviews(String sellerId) async {
    return _withDemoFallback(
      () async {
        final response = await _get(_uri('/sellers/$sellerId/reviews'));
        _ensureSuccess(response);
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => ReviewModel.fromJson(e as Map<String, dynamic>)).toList();
      },
      () => DemoCatalogData.reviewsForSeller(sellerId),
    );
  }

  Future<void> submitReview(String sellerId, {required int rating, String comment = ''}) async {
    final response = await _post(
      _uri('/sellers/$sellerId/reviews'),
      headers: _jsonHeaders(auth: true),
      body: jsonEncode({'rating': rating, 'comment': comment}),
    );
    _ensureSuccess(response);
  }

  Future<T> _withDemoFallback<T>(Future<T> Function() request, T Function() fallback) async {
    if (!AppConfig.demoFallbackOnError) {
      isUsingDemoData = false;
      return request();
    }

    try {
      isUsingDemoData = false;
      return await request().timeout(const Duration(seconds: 8));
    } on Object {
      isUsingDemoData = true;
      return fallback();
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw ApiException(
      _messageFromErrorResponse(response),
      statusCode: response.statusCode,
    );
  }

  String _messageFromErrorResponse(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
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
      // Fall through to generic message.
    }
    return 'Request failed (${response.statusCode})';
  }
}

final apiServiceProvider = ApiService();
