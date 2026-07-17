import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/data/demo_map_data.dart';
import '../../core/models/models.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';
import '../buyer/buyer_home_screen.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late Future<_MapData> _mapFuture;
  String? _loadedCity;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final city = ref.read(buyerCityProvider);
    if (_loadedCity != city) {
      _loadedCity = city;
      _mapFuture = _loadMapData(city);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final city = ref.watch(buyerCityProvider);

    return FutureBuilder<_MapData>(
      future: _mapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data ?? _MapData.demo(city);
        final pins = data.pins;
        final warnings = data.warnings;
        final usingDemo = data.usingDemo;

        final sellerMarkers = pins.map((pin) {
          return Marker(
            markerId: MarkerId(pin.id),
            position: LatLng(pin.latitude, pin.longitude),
            infoWindow: InfoWindow(
              title: pin.businessName,
              snippet: '${pin.averageRating} ★ · ${pin.achievementStars} achievement stars',
              onTap: () => context.push('/seller/${pin.id}'),
            ),
            icon: pin.achievementStars > 0
                ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
                : BitmapDescriptor.defaultMarker,
          );
        }).toSet();

        final warningMarkers = warnings.map((zone) {
          return Marker(
            markerId: MarkerId('warning-${zone.id}'),
            position: LatLng(zone.latitude, zone.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: '⚠ ${zone.name}', snippet: zone.description),
          );
        }).toSet();

        final initial = pins.isNotEmpty
            ? LatLng(pins.first.latitude, pins.first.longitude)
            : DemoMapData.cityCenter(city);

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: initial, zoom: 13),
              markers: {...sellerMarkers, ...warningMarkers},
              myLocationButtonEnabled: true,
              myLocationEnabled: true,
              gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: AppSpacing.screenHorizontal,
              right: AppSpacing.screenHorizontal,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(city, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (usingDemo)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Demo', style: TextStyle(color: AppColors.warning, fontSize: 12)),
                        )
                      else if (warnings.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(l10n.warningZones(warnings.length), style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (usingDemo)
              Positioned(
                bottom: AppSpacing.lg,
                left: AppSpacing.screenHorizontal,
                right: AppSpacing.screenHorizontal,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Demo businesses shown — start the backend API for live data.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<_MapData> _loadMapData(String city) async {
    try {
      final results = await Future.wait([
        apiServiceProvider.fetchMapPins(city: city),
        apiServiceProvider.fetchWarningZones(city: city),
      ]);
      return _MapData(
        pins: results[0] as List<MapPinModel>,
        warnings: results[1] as List<WarningZoneModel>,
        usingDemo: false,
      );
    } catch (_) {
      return _MapData.demo(city);
    }
  }
}

class _MapData {
  const _MapData({
    required this.pins,
    required this.warnings,
    required this.usingDemo,
  });

  final List<MapPinModel> pins;
  final List<WarningZoneModel> warnings;
  final bool usingDemo;

  factory _MapData.demo(String city) {
    return _MapData(
      pins: DemoMapData.pinsForCity(city),
      warnings: const [],
      usingDemo: true,
    );
  }
}
