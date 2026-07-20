import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';

class CartLineItem {
  const CartLineItem({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.name,
    required this.unitPriceMad,
    required this.imageUrl,
    required this.sellerName,
    required this.isRemote,
    this.stockQuantity = 99,
    this.isAvailable = true,
  });

  final String id;
  final String productId;
  final String sellerId;
  final int quantity;
  final String name;
  final double unitPriceMad;
  final String imageUrl;
  final String sellerName;
  final bool isRemote;
  final int stockQuantity;
  final bool isAvailable;

  double get lineTotalMad => unitPriceMad * quantity;

  factory CartLineItem.fromRemote(CartItemModel item) {
    return CartLineItem(
      id: item.id,
      productId: item.productId,
      sellerId: item.sellerId,
      quantity: item.quantity,
      name: item.productName,
      unitPriceMad: item.unitPriceMad,
      imageUrl: item.imageUrl,
      sellerName: item.sellerName,
      isRemote: true,
      stockQuantity: item.stockQuantity,
      isAvailable: item.isAvailable,
    );
  }

  factory CartLineItem.fromGuest(GuestCartItem item) {
    return CartLineItem(
      id: item.productId,
      productId: item.productId,
      sellerId: item.sellerId,
      quantity: item.quantity,
      name: item.name,
      unitPriceMad: item.price,
      imageUrl: item.imageUrl,
      sellerName: item.sellerName,
      isRemote: false,
    );
  }
}

class CartSummary {
  const CartSummary(this.items);

  final List<CartLineItem> items;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  double get subtotalMad =>
      items.fold(0, (sum, item) => sum + item.lineTotalMad);
  bool get isEmpty => items.isEmpty;
}

final cartProvider =
    AsyncNotifierProvider<CartNotifier, List<CartLineItem>>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<List<CartLineItem>> {
  bool get _isGuestCart {
    final session = ref.read(userSessionProvider);
    return session == null || session.isGuest;
  }

  AppStorage get _storage {
    final storage = ref.read(appStorageProvider);
    if (storage == null) {
      throw ApiException('App storage is not ready. Please restart the app.');
    }
    return storage;
  }

  @override
  Future<List<CartLineItem>> build() async {
    final storage = ref.watch(appStorageProvider);
    if (storage == null) return const [];
    final session = ref.watch(userSessionProvider);
    if (session == null || session.isGuest) {
      return storage.getGuestCartItems().map(CartLineItem.fromGuest).toList();
    }
    final items = await apiServiceProvider.fetchCart();
    return items.map(CartLineItem.fromRemote).toList();
  }

  Future<void> addProduct({
    required ProductModel product,
    required String sellerId,
    required String sellerName,
    int quantity = 1,
  }) async {
    if (product.priceMad == null) {
      throw ApiException('Product has no price');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (_isGuestCart) {
        final session = ref.read(userSessionProvider);
        if (session == null) {
          await _storage.saveGuestSession(city: AppConfig.moroccanCities.first);
          ref.read(userSessionProvider.notifier).state = _storage.getSession();
        }
        final items = await _storage.addGuestCartItem(
          GuestCartItem(
            productId: product.id,
            sellerId: sellerId,
            quantity: quantity,
            name: product.name,
            price: product.priceMad!,
            imageUrl: product.imageUrl,
            sellerName: sellerName,
          ),
        );
        return items.map(CartLineItem.fromGuest).toList();
      }
      await apiServiceProvider.addCartItem(
          productId: product.id, quantity: quantity);
      final items = await apiServiceProvider.fetchCart();
      return items.map(CartLineItem.fromRemote).toList();
    });
  }

  Future<void> updateQuantity(CartLineItem item, int quantity) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (_isGuestCart) {
        final items =
            await _storage.updateGuestCartQuantity(item.productId, quantity);
        return items.map(CartLineItem.fromGuest).toList();
      }
      await apiServiceProvider.updateCartItem(
          itemId: item.id, quantity: quantity);
      final items = await apiServiceProvider.fetchCart();
      return items.map(CartLineItem.fromRemote).toList();
    });
  }

  Future<void> remove(CartLineItem item) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      if (_isGuestCart) {
        final items = await _storage.removeGuestCartItem(item.productId);
        return items.map(CartLineItem.fromGuest).toList();
      }
      await apiServiceProvider.deleteCartItem(item.id);
      final items = await apiServiceProvider.fetchCart();
      return items.map(CartLineItem.fromRemote).toList();
    });
  }

  Future<void> reload() async {
    ref.invalidateSelf();
    await future;
  }
}

List<Map<String, dynamic>> guestCartMigrationPayload(AppStorage storage) {
  return storage
      .getGuestCartItems()
      .map((item) => {
            'product_id': item.productId,
            'quantity': item.quantity,
          })
      .toList();
}
