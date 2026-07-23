import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/models.dart';
import 'city_coordinates.dart';

/// Demo map pins used when the backend is offline or Maps API is not configured.
class DemoMapData {
  DemoMapData._();

  static LatLng cityCenter(String city) => CityCoordinates.centerFor(city);

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
        businessName: 'Tech Corner',
        latitude: center.latitude + 0.003,
        longitude: center.longitude - 0.007,
        achievementStars: 0,
        averageRating: 4.2,
        categorySlugs: const ['electronics'],
      ),
    ];
  }
}
