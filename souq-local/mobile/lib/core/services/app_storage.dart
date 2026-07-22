import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AccountType { buyer, seller, guest }

class GuestFavoriteItem {
  const GuestFavoriteItem({
    required this.productId,
    required this.sellerId,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.sellerName = '',
  });

  final String productId;
  final String sellerId;
  final String name;
  final double price;
  final String imageUrl;
  final String sellerName;

  GuestFavoriteItem copyWith({
    String? productId,
    String? sellerId,
    String? name,
    double? price,
    String? imageUrl,
    String? sellerName,
  }) {
    return GuestFavoriteItem(
      productId: productId ?? this.productId,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      sellerName: sellerName ?? this.sellerName,
    );
  }

  factory GuestFavoriteItem.fromJson(Map<String, dynamic> json) {
    return GuestFavoriteItem(
      productId:
          json['productId'] as String? ?? json['product_id'] as String? ?? '',
      sellerId:
          json['sellerId'] as String? ?? json['seller_id'] as String? ?? '',
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
  static const _themeModeKey = 'theme_mode';
  static const _guestFavoritesKey = 'guest_favorite_items';
  static const _legacyGuestCartKey = 'guest_cart_items';

  bool get isOnboardingComplete =>
      _prefs.getBool(_onboardingCompleteKey) ?? false;
  bool get isLoggedIn => _prefs.getBool(_loggedInKey) ?? false;
  bool get isLanguageSelected => _prefs.getBool(_languageSelectedKey) ?? false;

  String get languageCode => _prefs.getString(_languageCodeKey) ?? 'en';

  Locale getLocale() => Locale(languageCode);

  ThemeMode getThemeMode() {
    switch (_prefs.getString(_themeModeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _prefs.setString(_themeModeKey, value);
  }

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

  List<GuestFavoriteItem> getGuestFavoriteItems() {
    final raw = _prefs.getString(_guestFavoritesKey) ??
        _prefs.getString(_legacyGuestCartKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) =>
              GuestFavoriteItem.fromJson(item as Map<String, dynamic>))
          .where((item) =>
              item.productId.isNotEmpty || item.sellerId.isNotEmpty)
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> saveGuestFavoriteItems(List<GuestFavoriteItem> items) async {
    await _prefs.setString(
      _guestFavoritesKey,
      jsonEncode(items.map((item) => item.toJson()).toList()),
    );
    await _prefs.remove(_legacyGuestCartKey);
  }

  Future<List<GuestFavoriteItem>> addGuestFavoriteItem(
      GuestFavoriteItem item) async {
    final items = [...getGuestFavoriteItems()];
    final index = items.indexWhere((entry) {
      if (item.productId.isNotEmpty) {
        return entry.productId == item.productId;
      }
      return entry.productId.isEmpty && entry.sellerId == item.sellerId;
    });
    if (index == -1) {
      items.add(item);
    } else {
      items[index] = items[index].copyWith(
        name: item.name,
        price: item.price,
        imageUrl: item.imageUrl,
        sellerId: item.sellerId,
        sellerName: item.sellerName,
      );
    }
    await saveGuestFavoriteItems(items);
    return items;
  }

  Future<List<GuestFavoriteItem>> removeGuestFavoriteItem(
      String productId) async {
    final items = getGuestFavoriteItems()
        .where((item) => item.productId != productId)
        .toList();
    await saveGuestFavoriteItems(items);
    return items;
  }

  Future<List<GuestFavoriteItem>> removeGuestFavoriteSeller(
      String sellerId) async {
    final items = getGuestFavoriteItems()
        .where((item) =>
            !(item.sellerId == sellerId && item.productId.isEmpty))
        .toList();
    await saveGuestFavoriteItems(items);
    return items;
  }

  Future<void> clearGuestFavorites() async {
    await _prefs.remove(_guestFavoritesKey);
    await _prefs.remove(_legacyGuestCartKey);
  }

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

List<Map<String, dynamic>> guestFavoritesMigrationPayload(AppStorage storage) {
  return storage
      .getGuestFavoriteItems()
      .map((item) => {
            'product_id': item.productId,
            if (item.sellerId.isNotEmpty) 'seller_id': item.sellerId,
          })
      .toList();
}
