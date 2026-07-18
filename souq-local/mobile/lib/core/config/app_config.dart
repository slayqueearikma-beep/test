/// App configuration — update for your environment.
class AppConfig {
  /// Backend URL. Defaults to Android emulator loopback (10.0.2.2).
  /// On a physical phone, use your PC's LAN IP:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Set via --dart-define=GOOGLE_MAPS_API_KEY=your_key
  /// Must match the key in android/app/src/main/AndroidManifest.xml
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static bool get hasGoogleMapsApiKey =>
      mapsEnabled &&
      googleMapsApiKey.isNotEmpty &&
      googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY';

  /// Maps are opt-in. Pass --dart-define=ENABLE_MAPS=true with a valid key.
  static const bool mapsEnabled = bool.fromEnvironment(
    'ENABLE_MAPS',
    defaultValue: false,
  );

  /// When true (default), show sample businesses if the API is unreachable.
  static const bool demoFallbackOnError = bool.fromEnvironment(
    'DEMO_FALLBACK',
    defaultValue: true,
  );

  static const String appName = 'MarGem';
  static const String appTagline = 'Discover Morocco\'s Hidden Gems';

  static const List<String> moroccanCities = [
    'Casablanca',
    'Rabat',
    'Marrakech',
    'Fes',
    'Tangier',
    'Agadir',
    'Meknes',
    'Oujda',
  ];
}
