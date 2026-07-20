import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Full-screen map picker — never embed inside a [ScrollView].
class MapLocationPickerPage extends StatefulWidget {
  const MapLocationPickerPage({
    super.key,
    required this.initial,
    this.title = 'Set store location',
  });

  final LatLng initial;
  final String title;

  static Future<LatLng?> open(BuildContext context, {required LatLng initial, String? title}) {
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => MapLocationPickerPage(
          initial: initial,
          title: title ?? 'Set store location',
        ),
      ),
    );
  }

  @override
  State<MapLocationPickerPage> createState() => _MapLocationPickerPageState();
}

class _MapLocationPickerPageState extends State<MapLocationPickerPage> {
  late LatLng _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _position),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SafeGoogleMap(
        initialTarget: _position,
        zoom: 14,
        markers: AppConfig.hasGoogleMapsApiKey
            ? {
                Marker(markerId: const MarkerId('pick'), position: _position),
              }
            : {},
        onTap: AppConfig.hasGoogleMapsApiKey ? (pos) => setState(() => _position = pos) : null,
      ),
    );
  }
}

class SafeGoogleMap extends StatelessWidget {
  const SafeGoogleMap({
    super.key,
    required this.initialTarget,
    required this.markers,
    this.zoom = 13,
    this.myLocationEnabled = false,
    this.onMapCreated,
    this.onTap,
  });

  final LatLng initialTarget;
  final Set<Marker> markers;
  final double zoom;
  final bool myLocationEnabled;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(LatLng)? onTap;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasGoogleMapsApiKey) {
      return MapUnavailablePlaceholder(
        cityCenter: initialTarget,
        markerCount: markers.length,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialTarget, zoom: zoom),
      markers: markers,
      myLocationButtonEnabled: myLocationEnabled,
      myLocationEnabled: myLocationEnabled,
      onMapCreated: onMapCreated,
      onTap: onTap,
      gestureRecognizers: {Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer())},
    );
  }
}

class MapUnavailablePlaceholder extends StatelessWidget {
  const MapUnavailablePlaceholder({
    super.key,
    required this.cityCenter,
    this.markerCount = 0,
    this.usingDemoData = false,
  });

  final LatLng cityCenter;
  final int markerCount;
  final bool usingDemoData;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceMuted,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                usingDemoData ? 'Demo map mode' : 'Map preview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                usingDemoData
                    ? 'Showing sample businesses while the API is offline.'
                    : 'Add GOOGLE_MAPS_API_KEY to android/local.properties',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              if (markerCount > 0) ...[
                const SizedBox(height: AppSpacing.md),
                Text('$markerCount locations in this area', style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${cityCenter.latitude.toStringAsFixed(4)}, ${cityCenter.longitude.toStringAsFixed(4)}',
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StoreLocationPickerTile extends StatelessWidget {
  const StoreLocationPickerTile({
    super.key,
    required this.location,
    required this.onLocationChanged,
    this.label,
    this.hint,
  });

  final LatLng location;
  final ValueChanged<LatLng> onLocationChanged;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(label!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        if (label != null) const SizedBox(height: AppSpacing.sm),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
          child: InkWell(
            onTap: () async {
              final picked = await MapLocationPickerPage.open(context, initial: location, title: label);
              if (picked != null) onLocationChanged(picked);
            },
            borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.inputRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: 4),
                          Text(hint!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
