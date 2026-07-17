import '../models/models.dart';
import 'demo_map_data.dart';

/// Offline demo catalog — shown when the backend API is not running.
class DemoCatalogData {
  DemoCatalogData._();

  static const _food = CategoryModel(id: 'demo-cat-food', slug: 'food', nameEn: 'Food', icon: 'restaurant');
  static const _clothing = CategoryModel(id: 'demo-cat-clothing', slug: 'clothing', nameEn: 'Clothing', icon: 'checkroom');
  static const _electronics = CategoryModel(id: 'demo-cat-electronics', slug: 'electronics', nameEn: 'Electronics', icon: 'devices');
  static const _beauty = CategoryModel(id: 'demo-cat-beauty', slug: 'beauty', nameEn: 'Beauty', icon: 'spa');
  static const _services = CategoryModel(id: 'demo-cat-services', slug: 'services', nameEn: 'Services', icon: 'build');
  static const _home = CategoryModel(id: 'demo-cat-home', slug: 'home', nameEn: 'Home & Garden', icon: 'home');
  static const _health = CategoryModel(id: 'demo-cat-health', slug: 'health', nameEn: 'Health', icon: 'local_hospital');
  static const _sports = CategoryModel(id: 'demo-cat-sports', slug: 'sports', nameEn: 'Sports', icon: 'sports_soccer');

  static const categories = [_food, _clothing, _electronics, _beauty, _services, _home, _health, _sports];

  static List<SellerModel> sellersForCity(String city, {String? query}) {
    final center = DemoMapData.cityCenter(city);
    final all = [
      SellerModel(
        id: 'demo-1',
        businessName: 'Atlas Café',
        description: 'Moroccan breakfast, mint tea, and fresh pastries in a cozy riad setting.',
        city: city,
        latitude: center.latitude + 0.008,
        longitude: center.longitude + 0.006,
        coverImageUrl: '',
        achievementStars: 2,
        averageRating: 4.8,
        reviewCount: 214,
        address: 'Medina, $city',
        phone: '+212 522 111 222',
        categories: const [_food],
        products: const [
          ProductModel(id: 'demo-p1', name: 'Mint Tea Set', description: 'Traditional tea service', priceMad: 45),
        ],
      ),
      SellerModel(
        id: 'demo-2',
        businessName: 'Souk Artisan',
        description: 'Handmade leather goods, carpets, and Moroccan crafts from local artisans.',
        city: city,
        latitude: center.latitude - 0.006,
        longitude: center.longitude + 0.004,
        coverImageUrl: '',
        achievementStars: 1,
        averageRating: 4.5,
        reviewCount: 89,
        address: 'Souk district, $city',
        phone: '+212 522 333 444',
        categories: const [_clothing],
      ),
      SellerModel(
        id: 'demo-3',
        businessName: 'Riad Services',
        description: 'Home repair, plumbing, and electrical services with same-day booking.',
        city: city,
        latitude: center.latitude + 0.003,
        longitude: center.longitude - 0.009,
        coverImageUrl: '',
        achievementStars: 0,
        averageRating: 4.2,
        reviewCount: 36,
        address: 'Hay Mohammadi, $city',
        phone: '+212 522 555 666',
        categories: const [_services],
        services: const [
          ServiceModel(id: 'demo-s1', name: 'Plumbing visit', description: 'On-site diagnosis', priceMad: 150),
        ],
      ),
      SellerModel(
        id: 'demo-4',
        businessName: 'Hana Chicken',
        description: 'Crispy fried chicken and local favorites — a Casablanca classic.',
        city: city,
        latitude: center.latitude + 0.004,
        longitude: center.longitude - 0.002,
        coverImageUrl: '',
        achievementStars: 3,
        averageRating: 4.9,
        reviewCount: 512,
        address: 'Boulevard Zerktouni, $city',
        phone: '+212 522 000 000',
        categories: const [_food],
      ),
    ];

    if (query == null || query.trim().isEmpty) return all;

    final q = query.toLowerCase();
    return all
        .where(
          (s) =>
              s.businessName.toLowerCase().contains(q) ||
              s.description.toLowerCase().contains(q) ||
              s.city.toLowerCase().contains(q),
        )
        .toList();
  }

  static SellerModel? sellerById(String id) {
    for (final city in ['Casablanca', 'Rabat', 'Marrakech', 'Fes']) {
      for (final seller in sellersForCity(city)) {
        if (seller.id == id) return seller;
      }
    }
    return null;
  }

  static List<ReviewModel> reviewsForSeller(String sellerId) {
    return const [
      ReviewModel(
        id: 'demo-r1',
        rating: 5,
        comment: 'Excellent service and very friendly staff!',
        buyerDisplayName: 'Youssef',
        createdAt: '2026-01-12',
      ),
      ReviewModel(
        id: 'demo-r2',
        rating: 4,
        comment: 'Great quality. Will come again.',
        buyerDisplayName: 'Sara',
        createdAt: '2026-02-03',
      ),
    ];
  }
}
