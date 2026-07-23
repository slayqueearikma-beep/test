import 'package:google_maps_flutter/google_maps_flutter.dart';

/// City center coordinates for map defaults (Casablanca-only launch).
class CityCoordinates {
  CityCoordinates._();

  static const LatLng casablanca = LatLng(33.5731, -7.5898);

  static LatLng centerFor(String city) {
    // MarGem currently operates in Casablanca only.
    return casablanca;
  }
}
