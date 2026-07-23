class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.slug,
    required this.nameEn,
    this.nameFr = '',
    this.nameAr = '',
    required this.icon,
  });

  final String id;
  final String slug;
  final String nameEn;
  final String nameFr;
  final String nameAr;
  final String icon;

  String localizedName(String languageCode) {
    switch (languageCode) {
      case 'fr':
        return nameFr.isNotEmpty ? nameFr : nameEn;
      case 'ar':
        return nameAr.isNotEmpty ? nameAr : nameEn;
      default:
        return nameEn;
    }
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      slug: json['slug'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameFr: json['name_fr'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
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
    this.avgProductQuality = 0,
    this.avgCustomerService = 0,
    this.avgCommunication = 0,
    this.avgTrustworthiness = 0,
    this.logoImageUrl = '',
    this.address = '',
    this.phone = '',
    this.websiteUrl = '',
    this.instagramUrl = '',
    this.facebookUrl = '',
    this.tiktokUrl = '',
    this.whatsappNumber = '',
    this.paymentMethods = const [],
    this.deliveryMethods = const [],
    this.serviceAreas = const [],
    this.openingHours = const OpeningHoursModel(),
    this.profileViewCount = 0,
    this.inquiryCount = 0,
    this.favoriteCount = 0,
    this.contactClickCount = 0,
    this.avgResponseMinutes = 0,
    this.isPremium = false,
    this.verificationStatus = 'unverified',
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
  final double avgProductQuality;
  final double avgCustomerService;
  final double avgCommunication;
  final double avgTrustworthiness;
  final String address;
  final String phone;
  final String websiteUrl;
  final String instagramUrl;
  final String facebookUrl;
  final String tiktokUrl;
  final String whatsappNumber;
  final List<String> paymentMethods;
  final List<String> deliveryMethods;
  final List<String> serviceAreas;
  final OpeningHoursModel openingHours;
  final int profileViewCount;
  final int inquiryCount;
  final int favoriteCount;
  final int contactClickCount;
  final int avgResponseMinutes;
  final bool isPremium;
  final String verificationStatus;
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
      avgProductQuality:
          (json['avg_product_quality'] as num?)?.toDouble() ?? 0,
      avgCustomerService:
          (json['avg_customer_service'] as num?)?.toDouble() ?? 0,
      avgCommunication: (json['avg_communication'] as num?)?.toDouble() ?? 0,
      avgTrustworthiness:
          (json['avg_trustworthiness'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      websiteUrl: json['website_url'] as String? ?? '',
      instagramUrl: json['instagram_url'] as String? ?? '',
      facebookUrl: json['facebook_url'] as String? ?? '',
      tiktokUrl: json['tiktok_url'] as String? ?? '',
      whatsappNumber: json['whatsapp_number'] as String? ?? '',
      paymentMethods: (json['payment_methods'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      deliveryMethods: (json['delivery_methods'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      serviceAreas: (json['service_areas'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      openingHours: OpeningHoursModel.fromJson(
        json['opening_hours'] is Map<String, dynamic>
            ? json['opening_hours'] as Map<String, dynamic>
            : null,
      ),
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      inquiryCount: json['inquiry_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactClickCount: json['contact_click_count'] as int? ?? 0,
      avgResponseMinutes: json['avg_response_minutes'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
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
    this.inquiryCount = 0,
    this.favoriteCount = 0,
    this.contactClickCount = 0,
    this.avgResponseMinutes = 0,
    this.isPremium = false,
    this.verificationStatus = 'unverified',
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
  final int inquiryCount;
  final int favoriteCount;
  final int contactClickCount;
  final int avgResponseMinutes;
  final bool isPremium;
  final String verificationStatus;

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
      inquiryCount: json['inquiry_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactClickCount: json['contact_click_count'] as int? ?? 0,
      avgResponseMinutes: json['avg_response_minutes'] as int? ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
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
    this.priceNegotiable = false,
    this.availabilityNote = '',
    this.acceptedPaymentMethods = const [],
    this.deliveryOptions = const [],
    this.mediaUrls = const [],
    this.videoUrl = '',
    this.categorySlug = '',
    this.stockQuantity = 1,
    this.isFeatured = false,
    this.isPaused = false,
  });

  final String id;
  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;
  final bool isAvailable;
  final bool priceNegotiable;
  final String availabilityNote;
  final List<String> acceptedPaymentMethods;
  final List<String> deliveryOptions;
  final List<String> mediaUrls;
  final String videoUrl;
  final String categorySlug;
  final int stockQuantity;
  final bool isFeatured;
  final bool isPaused;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
      isAvailable: json['is_available'] as bool? ?? true,
      priceNegotiable: json['price_negotiable'] as bool? ?? false,
      availabilityNote: json['availability_note'] as String? ?? '',
      acceptedPaymentMethods:
          (json['accepted_payment_methods'] as List<dynamic>? ?? [])
              .map((item) => item.toString())
              .toList(),
      deliveryOptions: (json['delivery_options'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      mediaUrls: (json['media_urls'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      videoUrl: json['video_url'] as String? ?? '',
      categorySlug: json['category_slug'] as String? ?? '',
      stockQuantity: json['stock_quantity'] as int? ?? 1,
      isFeatured: json['is_featured'] as bool? ?? false,
      isPaused: json['is_paused'] as bool? ?? false,
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
    required this.overallRating,
    required this.productQuality,
    required this.customerService,
    required this.communication,
    required this.trustworthiness,
    required this.comment,
    required this.buyerDisplayName,
    required this.createdAt,
  });

  final String id;
  final int rating;
  final double overallRating;
  final int productQuality;
  final int customerService;
  final int communication;
  final int trustworthiness;
  final String comment;
  final String buyerDisplayName;
  final String createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final productQuality = json['product_quality'] as int? ?? json['rating'] as int? ?? 0;
    final customerService = json['customer_service'] as int? ?? productQuality;
    final communication = json['communication'] as int? ?? productQuality;
    final trustworthiness = json['trustworthiness'] as int? ?? productQuality;
    final overall = (json['overall_rating'] as num?)?.toDouble() ??
        ((productQuality + customerService + communication + trustworthiness) /
            4.0);
    return ReviewModel(
      id: json['id'] as String,
      rating: json['rating'] as int? ?? overall.round(),
      overallRating: overall,
      productQuality: productQuality,
      customerService: customerService,
      communication: communication,
      trustworthiness: trustworthiness,
      comment: json['comment'] as String? ?? '',
      buyerDisplayName: json['buyer_display_name'] as String? ?? 'Buyer',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class ReviewEligibilityModel {
  const ReviewEligibilityModel({
    required this.canReview,
    required this.reason,
    required this.hasReviewed,
  });

  final bool canReview;
  final String reason;
  final bool hasReviewed;

  factory ReviewEligibilityModel.fromJson(Map<String, dynamic> json) {
    return ReviewEligibilityModel(
      canReview: json['can_review'] as bool? ?? false,
      reason: json['reason'] as String? ?? 'unknown',
      hasReviewed: json['has_reviewed'] as bool? ?? false,
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

class FavoriteItemModel {
  const FavoriteItemModel({
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

  factory FavoriteItemModel.fromJson(Map<String, dynamic> json) {
    return FavoriteItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String? ?? '',
      productName: json['product_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      sellerId: json['seller_id'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? '',
    );
  }
}

class SellerFollowModel {
  const SellerFollowModel({
    required this.id,
    required this.sellerId,
    required this.businessName,
    required this.city,
    this.logoImageUrl = '',
    this.averageRating = 0,
    this.isPremium = false,
    this.verificationStatus = 'unverified',
  });

  final String id;
  final String sellerId;
  final String businessName;
  final String city;
  final String logoImageUrl;
  final double averageRating;
  final bool isPremium;
  final String verificationStatus;

  factory SellerFollowModel.fromJson(Map<String, dynamic> json) {
    return SellerFollowModel(
      id: json['id'] as String,
      sellerId: json['seller_id'] as String,
      businessName: json['business_name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      logoImageUrl: json['logo_image_url'] as String? ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      verificationStatus:
          json['verification_status'] as String? ?? 'unverified',
    );
  }
}

class SellerAnalyticsModel {
  const SellerAnalyticsModel({
    required this.productCount,
    required this.availableProductCount,
    required this.serviceCount,
    required this.inquiryCount,
    required this.favoriteCount,
    required this.contactClickCount,
    required this.avgResponseMinutes,
    required this.reviewCount,
    required this.averageRating,
    required this.profileViewCount,
    required this.verificationStatus,
    required this.isPremium,
    required this.followerEstimate,
  });

  final int productCount;
  final int availableProductCount;
  final int serviceCount;
  final int inquiryCount;
  final int favoriteCount;
  final int contactClickCount;
  final int avgResponseMinutes;
  final int reviewCount;
  final double averageRating;
  final int profileViewCount;
  final String verificationStatus;
  final bool isPremium;
  final int followerEstimate;

  factory SellerAnalyticsModel.fromJson(Map<String, dynamic> json) {
    return SellerAnalyticsModel(
      productCount: json['product_count'] as int? ?? 0,
      availableProductCount: json['available_product_count'] as int? ?? 0,
      serviceCount: json['service_count'] as int? ?? 0,
      inquiryCount: json['inquiry_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      contactClickCount: json['contact_click_count'] as int? ?? 0,
      avgResponseMinutes: json['avg_response_minutes'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      profileViewCount: json['profile_view_count'] as int? ?? 0,
      verificationStatus: json['verification_status'] as String? ?? '',
      isPremium: json['is_premium'] as bool? ?? false,
      followerEstimate: json['follower_estimate'] as int? ?? 0,
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

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.lastMessageAt,
    this.peerUserId = '',
    this.peerName = '',
    this.unreadCount = 0,
    this.lastMessagePreview = '',
  });

  final String id;
  final String buyerId;
  final String sellerId;
  final String peerUserId;
  final String lastMessageAt;
  final String peerName;
  final int unreadCount;
  final String lastMessagePreview;

  bool get hasUnread => unreadCount > 0;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String? ?? '',
      sellerId: json['seller_id'] as String? ?? '',
      peerUserId: json['peer_user_id'] as String? ??
          json['buyer_id'] as String? ??
          '',
      lastMessageAt: json['last_message_at'] as String? ?? '',
      peerName: json['peer_name'] as String? ?? '',
      unreadCount: json['unread_count'] as int? ?? 0,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final String createdAt;
  final String? readAt;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      readAt: json['read_at'] as String?,
    );
  }
}
