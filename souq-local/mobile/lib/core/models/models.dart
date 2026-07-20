class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.icon,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String icon;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameEn: json['name_en'] as String,
      icon: json['icon'] as String? ?? 'store',
    );
  }
}

class OpeningHoursModel {
  const OpeningHoursModel({
    this.days = const {},
    this.open = '09:00',
    this.close = '21:00',
  });

  final Map<String, bool> days;
  final String open;
  final String close;

  factory OpeningHoursModel.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const OpeningHoursModel();
    }
    final rawDays = json['days'];
    final days = <String, bool>{};
    if (rawDays is Map) {
      rawDays.forEach((key, value) {
        days[key.toString()] = value == true;
      });
    }
    return OpeningHoursModel(
      days: days,
      open: json['open'] as String? ?? '09:00',
      close: json['close'] as String? ?? '21:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'days': days,
        'open': open,
        'close': close,
      };

  bool get isEmpty => days.isEmpty;
}

class SellerModel {
  const SellerModel({
    required this.id,
    required this.businessName,
    required this.description,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.coverImageUrl,
    required this.achievementStars,
    required this.averageRating,
    required this.reviewCount,
    this.logoImageUrl = '',
    this.address = '',
    this.phone = '',
    this.openingHours = const OpeningHoursModel(),
    this.profileViewCount = 0,
    this.categories = const [],
    this.products = const [],
    this.services = const [],
  });

  final String id;
  final String businessName;
  final String description;
  final String city;
  final double latitude;
  final double longitude;
  final String coverImageUrl;
  final String logoImageUrl;
  final int achievementStars;
  final double averageRating;
  final int reviewCount;
  final String address;
  final String phone;
  final OpeningHoursModel openingHours;
  final int profileViewCount;
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<ServiceModel> services;

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    return SellerModel(
      id: json['id'] as String,
      businessName: json['business_name'] as String,
      description: json['description'] as String? ?? '',
      city: json['city'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      coverImageUrl: json['cover_image_url'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      achievementStars: json['achievement_stars'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      openingHours: OpeningHoursModel.fromJson(
        json['opening_hours'] is Map<String, dynamic>
            ? json['opening_hours'] as Map<String, dynamic>
            : null,
      ),
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List<dynamic>? ?? [])
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => ServiceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SellerDashboardStats {
  const SellerDashboardStats({
    required this.sellerId,
    required this.businessName,
    required this.profileViewCount,
    required this.productCount,
    required this.availableProductCount,
    required this.serviceCount,
    required this.reviewCount,
    required this.averageRating,
    required this.achievementStars,
    required this.recentReviewCount,
    required this.isActive,
  });

  final String sellerId;
  final String businessName;
  final int profileViewCount;
  final int productCount;
  final int availableProductCount;
  final int serviceCount;
  final int reviewCount;
  final double averageRating;
  final int achievementStars;
  final int recentReviewCount;
  final bool isActive;

  factory SellerDashboardStats.fromJson(Map<String, dynamic> json) {
    return SellerDashboardStats(
      sellerId: json['seller_id'] as String,
      businessName: json['business_name'] as String,
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      productCount: json['product_count'] as int? ?? 0,
      availableProductCount: json['available_product_count'] as int? ?? 0,
      serviceCount: json['service_count'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      achievementStars: json['achievement_stars'] as int? ?? 0,
      recentReviewCount: json['recent_review_count'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get formattedViews {
    if (profileViewCount >= 1000) {
      final k = profileViewCount / 1000;
      return k >= 10 ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return '$profileViewCount';
  }

  String get ratingTrend {
    if (reviewCount == 0) return 'No reviews yet';
    return '${averageRating.toStringAsFixed(1)} avg';
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    this.priceMad,
    this.imageUrl = '',
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    this.priceMad,
    this.imageUrl = '',
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.buyerDisplayName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final String comment;
  final String buyerDisplayName;
  final String createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String? ?? '',
      buyerDisplayName: json['buyer_display_name'] as String? ?? 'Buyer',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class MapPinModel {
  const MapPinModel({
    required this.id,
    required this.businessName,
    required this.latitude,
    required this.longitude,
    required this.achievementStars,
    required this.averageRating,
    required this.categorySlugs,
  });

  final String id;
  final String businessName;
  final double latitude;
  final double longitude;
  final int achievementStars;
  final double averageRating;
  final List<String> categorySlugs;

  factory MapPinModel.fromJson(Map<String, dynamic> json) {
    return MapPinModel(
      id: json['id'] as String,
      businessName: json['business_name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      achievementStars: json['achievement_stars'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      categorySlugs: (json['category_slugs'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }
}

class WarningZoneModel {
  const WarningZoneModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  factory WarningZoneModel.fromJson(Map<String, dynamic> json) {
    return WarningZoneModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusMeters: (json['radius_meters'] as num?)?.toDouble() ?? 200,
    );
  }
}

class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.productId,
    required this.sellerId,
    required this.quantity,
    required this.unitPriceMad,
    required this.productName,
    required this.imageUrl,
    required this.sellerName,
    required this.stockQuantity,
    required this.isAvailable,
  });

  final String id;
  final String productId;
  final String sellerId;
  final int quantity;
  final double unitPriceMad;
  final String productName;
  final String imageUrl;
  final String sellerName;
  final int stockQuantity;
  final bool isAvailable;

  double get lineTotalMad => unitPriceMad * quantity;

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      sellerId: json['seller_id'] as String,
      quantity: json['quantity'] as int? ?? 1,
      unitPriceMad: (json['unit_price_mad'] as num?)?.toDouble() ?? 0,
      productName: json['product_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? '',
      stockQuantity: json['stock_quantity'] as int? ?? 99,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }
}

class WishlistItemModel {
  const WishlistItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.priceMad,
    required this.sellerId,
    required this.sellerName,
  });

  final String id;
  final String productId;
  final String productName;
  final String imageUrl;
  final double? priceMad;
  final String sellerId;
  final String sellerName;

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    return WishlistItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      sellerId: json['seller_id'] as String,
      sellerName: json['seller_name'] as String? ?? '',
    );
  }
}

class CheckoutPayload {
  const CheckoutPayload({
    required this.deliveryName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    required this.deliveryCity,
    this.buyerNote = '',
    this.paymentMethod = 'cod',
    this.sellerId,
  });

  final String deliveryName;
  final String deliveryPhone;
  final String deliveryAddress;
  final String deliveryCity;
  final String buyerNote;
  final String paymentMethod;
  final String? sellerId;

  Map<String, dynamic> toJson() => {
        'delivery_name': deliveryName,
        'delivery_phone': deliveryPhone,
        'delivery_address': deliveryAddress,
        'delivery_city': deliveryCity,
        'buyer_note': buyerNote,
        'payment_method': paymentMethod,
        if (sellerId != null) 'seller_id': sellerId,
      };
}

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMad,
    required this.totalMad,
    required this.imageUrl,
  });

  final String id;
  final String? productId;
  final String productName;
  final int quantity;
  final double unitPriceMad;
  final double totalMad;
  final String imageUrl;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unitPriceMad: (json['unit_price_mad'] as num?)?.toDouble() ?? 0,
      totalMad: (json['total_mad'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.status,
    required this.subtotalMad,
    required this.deliveryFeeMad,
    required this.totalMad,
    required this.currency,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryName,
    required this.deliveryPhone,
    required this.deliveryAddress,
    required this.deliveryCity,
    required this.buyerNote,
    required this.sellerNote,
    required this.createdAt,
    required this.items,
    required this.sellerName,
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String status;
  final double subtotalMad;
  final double deliveryFeeMad;
  final double totalMad;
  final String currency;
  final String paymentMethod;
  final String paymentStatus;
  final String deliveryName;
  final String deliveryPhone;
  final String deliveryAddress;
  final String deliveryCity;
  final String buyerNote;
  final String sellerNote;
  final String createdAt;
  final List<OrderItemModel> items;
  final String sellerName;

  bool get canBuyerCancel => status == 'pending' || status == 'accepted';
  bool get canSellerAccept => status == 'pending';
  bool get canSellerMarkReady => status == 'accepted';
  bool get canSellerComplete => status == 'accepted' || status == 'ready';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      sellerId: json['seller_id'] as String,
      status: json['status'] as String? ?? 'pending',
      subtotalMad: (json['subtotal_mad'] as num?)?.toDouble() ?? 0,
      deliveryFeeMad: (json['delivery_fee_mad'] as num?)?.toDouble() ?? 0,
      totalMad: (json['total_mad'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'MAD',
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      paymentStatus: json['payment_status'] as String? ?? '',
      deliveryName: json['delivery_name'] as String? ?? '',
      deliveryPhone: json['delivery_phone'] as String? ?? '',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      deliveryCity: json['delivery_city'] as String? ?? '',
      buyerNote: json['buyer_note'] as String? ?? '',
      sellerNote: json['seller_note'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      sellerName: json['seller_name'] as String? ?? '',
    );
  }
}

class SellerAnalyticsModel {
  const SellerAnalyticsModel({
    required this.productCount,
    required this.availableProductCount,
    required this.orderCount,
    required this.pendingOrders,
    required this.completedOrders,
    required this.revenueMad,
    required this.averageOrderMad,
    required this.reviewCount,
    required this.averageRating,
    required this.profileViewCount,
    required this.verificationStatus,
    required this.isPremium,
  });

  final int productCount;
  final int availableProductCount;
  final int orderCount;
  final int pendingOrders;
  final int completedOrders;
  final double revenueMad;
  final double averageOrderMad;
  final int reviewCount;
  final double averageRating;
  final int profileViewCount;
  final String verificationStatus;
  final bool isPremium;

  factory SellerAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return SellerAnalyticsModel(
      productCount: json['product_count'] as int? ?? 0,
      availableProductCount: json['available_product_count'] as int? ?? 0,
      orderCount: json['order_count'] as int? ?? 0,
      pendingOrders: json['pending_orders'] as int? ?? 0,
      completedOrders: json['completed_orders'] as int? ?? 0,
      revenueMad: (json['revenue_mad'] as num?)?.toDouble() ?? 0,
      averageOrderMad: (json['average_order_mad'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      verificationStatus: json['verification_status'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
    );
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.data,
    required this.readAt,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String kind;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      kind: json['kind'] as String? ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : const {},
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SubscriptionPlanModel {
  const SubscriptionPlanModel({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.priceMad,
    required this.billingPeriodDays,
    required this.features,
    required this.isActive,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final double priceMad;
  final int billingPeriodDays;
  final List<String> features;
  final bool isActive;

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble() ?? 0,
      billingPeriodDays: json['billing_period_days'] as int? ?? 30,
      features: (json['features'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class SubscriptionModel {
  const SubscriptionModel({
    required this.id,
    required this.plan,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.provider,
  });

  final String id;
  final SubscriptionPlanModel plan;
  final String status;
  final String currentPeriodStart;
  final String currentPeriodEnd;
  final String provider;

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      plan:
          SubscriptionPlanModel.fromJson(json['plan'] as Map<String, dynamic>),
      status: json['status'] as String? ?? '',
      currentPeriodStart: json['current_period_start'] as String? ?? '',
      currentPeriodEnd: json['current_period_end'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
    );
  }
}
