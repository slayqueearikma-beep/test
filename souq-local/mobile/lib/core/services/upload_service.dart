import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import 'api_service.dart';

/// Uploads images via the API presign → PUT flow.
class UploadService {
  UploadService(this._api);

  final ApiService _api;
  static const _uploadTimeout = Duration(seconds: 60);

  Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      throw ApiException('Image must be 8 MB or smaller');
    }
    final filename = file.name.isNotEmpty ? file.name : 'upload.jpg';
    final contentType = _contentTypeFor(filename);

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _uploadOnce(
          bytes: bytes,
          filename: filename,
          contentType: contentType,
        );
      } on ApiException catch (error) {
        lastError = error;
        // Retry once on transient storage / network failures.
        final retryable = error.statusCode == null ||
            error.statusCode == 503 ||
            error.statusCode == 502 ||
            error.message.toLowerCase().contains('timeout') ||
            error.message.toLowerCase().contains('unavailable');
        if (!retryable || attempt == 1) rethrow;
      }
    }
    throw lastError is ApiException
        ? lastError
        : ApiException('Image upload failed');
  }

  Future<String> _uploadOnce({
    required List<int> bytes,
    required String filename,
    required String contentType,
  }) async {
    final presign = await _api.postJson(
      '/uploads/presign',
      {'filename': filename, 'content_type': contentType},
      auth: true,
    );

    final uploadUrl = presign['upload_url'] as String?;
    final publicUrl = presign['public_url'] as String?;
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        publicUrl == null ||
        publicUrl.isEmpty) {
      throw ApiException('Storage did not return upload URLs');
    }

    final isLocalApiUpload = uploadUrl.startsWith(AppConfig.apiBaseUrl);
    final response = await http
        .put(
          Uri.parse(uploadUrl),
          headers: {
            'Content-Type': contentType,
            'x-ms-blob-type': 'BlockBlob',
            if (isLocalApiUpload) ..._api.authHeaders,
          },
          body: bytes,
        )
        .timeout(
          _uploadTimeout,
          onTimeout: () => throw ApiException('Image upload timed out'),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Image upload to storage failed (${response.statusCode})',
        statusCode: response.statusCode,
      );
    }

    return publicUrl;
  }

  String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }
}

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(apiServiceProvider);
});
