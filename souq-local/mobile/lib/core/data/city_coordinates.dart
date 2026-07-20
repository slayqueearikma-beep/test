import 'package:google_maps_flutter/google_maps_flutter.dart';

/// City center coordinates for map defaults (not demo business data).
class CityCoordinates {
  CityCoordinates._();

  static LatLng centerFor(String city) {
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
}
