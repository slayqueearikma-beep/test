import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/config/app_config.dart';

void main() {
  group('normalizeApiBaseUrl', () {
    test('inserts missing colon before common ports', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.1038000'),
        'http://192.168.11.103:8000',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('http://10.0.2.28080'),
        'http://10.0.2.2:8080',
      );
    });

    test('preserves correctly formed URLs', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.103:8000'),
        'http://192.168.11.103:8000',
      );
      expect(
        AppConfig.normalizeApiBaseUrl('https://api.margem.ma'),
        'https://api.margem.ma',
      );
    });

    test('strips trailing slashes', () {
      expect(
        AppConfig.normalizeApiBaseUrl('http://192.168.11.103:8000/'),
        'http://192.168.11.103:8000',
      );
    });
  });
}
