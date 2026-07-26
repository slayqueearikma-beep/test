import 'package:flutter_test/flutter_test.dart';
import 'package:souq_local/core/services/app_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest session can be persisted and read', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);

    const guest = UserSession(
      name: 'Guest',
      email: '',
      accountType: AccountType.guest,
    );
    await storage.saveSession(guest);
    final loaded = storage.getSession();
    expect(loaded, isNotNull);
    expect(loaded!.accountType, AccountType.guest);
    expect(loaded.isGuest, isTrue);
  });

  test('authenticated profile PII is not persisted in SharedPreferences',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AppStorage(prefs);

    await storage.saveSession(const UserSession(
      name: 'Private Name',
      email: 'private@example.com',
      accountType: AccountType.buyer,
      sellerId: 'seller-123',
    ));

    expect(prefs.getString('user_name'), isNull);
    expect(prefs.getString('user_email'), isNull);
    expect(storage.getSession()!.sellerId, 'seller-123');
  });
}
