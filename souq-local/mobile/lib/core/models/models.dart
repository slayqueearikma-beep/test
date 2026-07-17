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
    this.address = '',
    this.phone = '',
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
  final int achievementStars;
  final double averageRating;
  final int reviewCount;
  final String address;
  final String phone;
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
      achievementStars: json['achievement_stars'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
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

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    this.priceMad,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
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
  });

  final String id;
  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      priceMad: (json['price_mad'] as num?)?.toDouble(),
      imageUrl: json['image_url'] as String? ?? '',
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
