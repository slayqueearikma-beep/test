class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.accountType,
    required this.displayName,
  });

  final String id;
  final String email;
  final String accountType;
  final String displayName;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      displayName: json['display_name'] as String? ?? '',
    );
  }

  bool get isBuyer => accountType == 'buyer';
  bool get isSeller => accountType == 'seller';
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    this.expiresIn = 3600,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final int expiresIn;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int? ?? 3600,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class SellerCreatePayload {
  const SellerCreatePayload({
    required this.businessName,
    required this.description,
    required this.address,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.coverImageUrl = '',
    this.categoryIds = const [],
  });

  final String businessName;
  final String description;
  final String address;
  final String city;
  final double latitude;
  final double longitude;
  final String phone;
  final String coverImageUrl;
  final List<String> categoryIds;

  Map<String, dynamic> toJson() => {
        'business_name': businessName,
        'description': description,
        'address': address,
        'city': city,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'cover_image_url': coverImageUrl,
        'category_ids': categoryIds,
      };
}

class ProductCreatePayload {
  const ProductCreatePayload({
    required this.name,
    required this.description,
    this.priceMad,
    this.imageUrl = '',
  });

  final String name;
  final String description;
  final double? priceMad;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (priceMad != null) 'price_mad': priceMad,
        'image_url': imageUrl,
      };
}

/// Maps seller onboarding UI labels to backend category slugs.
const sellerCategorySlugMap = <String, String>{
  'Food': 'food',
  'Clothing': 'clothing',
  'Electronics': 'electronics',
  'Beauty': 'beauty',
  'Services': 'services',
  'Home & Garden': 'home',
  'Health': 'health',
  'Sports': 'sports',
};
