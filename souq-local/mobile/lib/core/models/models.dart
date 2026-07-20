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
