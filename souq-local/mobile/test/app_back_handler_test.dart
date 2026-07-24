import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/navigation/app_back_handler.dart';

void main() {
  group('isAppRootLocation', () {
    test('marks buyer home and seller dashboard as roots', () {
      expect(isAppRootLocation('/buyer/home'), isTrue);
      expect(isAppRootLocation('/seller/dashboard'), isTrue);
      expect(isAppRootLocation('/login'), isTrue);
    });

    test('does not treat nested screens as roots', () {
      expect(isAppRootLocation('/seller/abc'), isFalse);
      expect(isAppRootLocation('/product/a/b'), isFalse);
      expect(isAppRootLocation('/messages/1'), isFalse);
      expect(isAppRootLocation('/favorites'), isFalse);
      expect(isAppRootLocation('/seller/products'), isFalse);
    });
  });
}
