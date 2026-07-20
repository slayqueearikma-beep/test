import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountType { buyer, seller, guest }

class GuestCartItem {
  const GuestCartItem({
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.sellerName = '',
  });

  final String productId;
  final String sellerId;
  final int quantity;
  final String name;
  final double price;
  final String imageUrl;
  final String sellerName;

  double get lineTotal => price * quantity;

  GuestCartItem copyWith({
    String? productId,
    String? sellerId,
    int? quantity,
    String? name,
    double? price,
    String? imageUrl,
    String? sellerName,
  }) {
    return GuestCartItem(
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      quantity: quantity ?? this.quantity,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerName: sellerName ?? this.sellerName,
    );
  }

  factory GuestCartItem.fromJson(Map<String, dynamic> json) {
    return GuestCartItem(
      productId:
          json['productId'] as String? ?? json['product_id'] as String? ?? '',
      sellerId:
          json['sellerId'] as String? ?? json['seller_id'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? json['product_name'] as String? ?? '',
      price: (json['price'] as num? ??
              json['price_mad'] as num? ??
              json['unit_price_mad'] as num? ??
              0)
          .toDouble(),
      imageUrl:
          json['imageUrl'] as String? ?? json['image_url'] as String? ?? '',
      sellerName:
          json['sellerName'] as String? ?? json['seller_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'sellerId': sellerId,
        'quantity': quantity,
        'name': name,
        'price': price,
        'imageUrl': imageUrl,
        'sellerName': sellerName,
      };
}

class UserSession {
  const UserSession({
    required this.name,
    required this.email,
    required this.accountType,
    this.city,
    this.businessName,
    this.sellerId,
  });

  final String name;
  final String email;
  final AccountType accountType;
  final String? city;
  final String? businessName;
  final String? sellerId;
  bool get isGuest => accountType == AccountType.guest;
  bool get isAuthenticated => !isGuest;

  UserSession copyWith({
    String? name,
    String? email,
    AccountType? accountType,
    String? city,
    String? businessName,
    String? sellerId,
  }) {
    return UserSession(
      name: name ?? this.name,
      email: email ?? this.email,
      accountType: accountType ?? this.accountType,
      city: city ?? this.city,
      businessName: businessName ?? this.businessName,
      sellerId: sellerId ?? this.sellerId,
    );
  }
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
  static const _sellerIdKey = 'seller_id';
  static const _languageCodeKey = 'language_code';
  static const _languageSelectedKey = 'language_selected';
  static const _guestCartKey = 'guest_cart_items';

  bool get isOnboardingComplete =>
      _prefs.getBool(_onboardingCompleteKey) ?? false;
  bool get isLoggedIn => _prefs.getBool(_loggedInKey) ?? false;
  bool get isLanguageSelected => _prefs.getBool(_languageSelectedKey) ?? false;

  String get languageCode => _prefs.getString(_languageCodeKey) ?? 'en';

  Locale getLocale() => Locale(languageCode);

  Future<void> saveLanguage(String languageCode) async {
    await _prefs.setString(_languageCodeKey, languageCode);
    await _prefs.setBool(_languageSelectedKey, true);
  }

  Future<void> completeOnboarding() =>
      _prefs.setBool(_onboardingCompleteKey, true);

  Future<void> saveSession(UserSession session) async {
    await _prefs.setBool(_loggedInKey, true);
    await _prefs.setString(_accountTypeKey, session.accountType.name);
    await _prefs.setString(_userNameKey, session.name);
    await _prefs.setString(_userEmailKey, session.email);
    if (session.city != null) {
      await _prefs.setString(_userCityKey, session.city!);
    }
    if (session.businessName != null) {
      await _prefs.setString(_businessNameKey, session.businessName!);
    } else {
      await _prefs.remove(_businessNameKey);
    }
    if (session.sellerId != null && session.sellerId!.isNotEmpty) {
      await _prefs.setString(_sellerIdKey, session.sellerId!);
    } else {
      await _prefs.remove(_sellerIdKey);
    }
  }

  Future<void> saveGuestSession({String? city}) {
    return saveSession(
      UserSession(
        name: 'Guest',
        email: '',
        accountType: AccountType.guest,
        city: city,
      ),
    );
  }

  UserSession? getSession() {
    if (!isLoggedIn) return null;
    final typeName = _prefs.getString(_accountTypeKey);
    if (typeName == null) return null;
    final accountType = AccountType.values.firstWhere(
      (type) => type.name == typeName,
      orElse: () => AccountType.buyer,
    );
    return UserSession(
      name: _prefs.getString(_userNameKey) ??
          (accountType == AccountType.guest ? 'Guest' : 'User'),
      email: _prefs.getString(_userEmailKey) ?? '',
      accountType: accountType,
      city: _prefs.getString(_userCityKey),
      businessName: _prefs.getString(_businessNameKey),
      sellerId: _prefs.getString(_sellerIdKey),
    );
  }

  Future<void> logout() async {
    await _prefs.remove(_loggedInKey);
    await _prefs.remove(_accountTypeKey);
    await _prefs.remove(_userNameKey);
    await _prefs.remove(_userEmailKey);
    await _prefs.remove(_userCityKey);
    await _prefs.remove(_businessNameKey);
    await _prefs.remove(_sellerIdKey);
  }

  List<GuestCartItem> getGuestCartItems() {
    final raw = _prefs.getString(_guestCartKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => GuestCartItem.fromJson(item as Map<String, dynamic>))
          .where((item) => item.productId.isNotEmpty && item.quantity > 0)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> saveGuestCartItems(List<GuestCartItem> items) async {
    await _prefs.setString(
      _guestCartKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
  }

  Future<List<GuestCartItem>> addGuestCartItem(GuestCartItem item) async {
    final items = [...getGuestCartItems()];
    final index =
        items.indexWhere((entry) => entry.productId == item.productId);
    if (index == -1) {
      items.add(item.copyWith(quantity: item.quantity.clamp(1, 99).toInt()));
    } else {
      items[index] = items[index].copyWith(
        quantity: (items[index].quantity + item.quantity).clamp(1, 99).toInt(),
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
      );
    }
    await saveGuestCartItems(items);
    return items;
  }

  Future<List<GuestCartItem>> updateGuestCartQuantity(
      String productId, int quantity) async {
    final items = getGuestCartItems()
        .map((item) => item.productId == productId
            ? item.copyWith(quantity: quantity.clamp(1, 99).toInt())
            : item)
        .toList();
    await saveGuestCartItems(items);
    return items;
  }

  Future<List<GuestCartItem>> removeGuestCartItem(String productId) async {
    final items = getGuestCartItems()
        .where((item) => item.productId != productId)
        .toList();
    await saveGuestCartItems(items);
    return items;
  }

  Future<void> clearGuestCart() => _prefs.remove(_guestCartKey);

  Future<void> resetAll() async {
    await _prefs.clear();
  }
}

final sharedPreferencesProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final appStorageProvider = Provider<AppStorage?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.maybeWhen(data: AppStorage.new, orElse: () => null);
});

final userSessionProvider = StateProvider<UserSession?>((ref) {
  return ref.watch(appStorageProvider)?.getSession();
});
