import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';

/// Demo map pins used when the backend is offline or Maps API is not configured.
class DemoMapData {
  DemoMapData._();

  static LatLng cityCenter(String city) {
    return switch (city) {
      'Rabat' => const LatLng(34.0209, -6.8416),
      'Marrakech' => const LatLng(31.6295, -7.9811),
      'Fes' => const LatLng(34.0181, -5.0078),
      'Tangier' => const LatLng(35.7595, -5.8340),
      'Agadir' => const LatLng(30.4278, -9.5981),
      'Meknes' => const LatLng(33.8935, -5.5473),
      'Oujda' => const LatLng(34.6814, -1.9086),
      _ => const LatLng(33.5731, -7.5898), // Casablanca
    };
  }

  static List<MapPinModel> pinsForCity(String city) {
    final center = cityCenter(city);
    return [
      MapPinModel(
        id: 'demo-1',
        businessName: 'Atlas Café',
        latitude: center.latitude + 0.008,
        longitude: center.longitude + 0.006,
        achievementStars: 2,
        averageRating: 4.8,
        categorySlugs: const ['food'],
      ),
      MapPinModel(
        id: 'demo-2',
        businessName: 'Souk Artisan',
        latitude: center.latitude - 0.006,
        longitude: center.longitude + 0.004,
        achievementStars: 1,
        averageRating: 4.5,
        categorySlugs: const ['clothing'],
      ),
      MapPinModel(
        id: 'demo-3',
        businessName: 'Riad Services',
        latitude: center.latitude + 0.003,
        longitude: center.longitude - 0.009,
        achievementStars: 0,
        averageRating: 4.2,
        categorySlugs: const ['services'],
      ),
    ];
  }
}
