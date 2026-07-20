/// App configuration — update for your environment.
class AppConfig {
  /// Production API URL. Set at build time:
  /// `flutter build apk --dart-define=API_BASE_URL=https://your-api.azurecontainerapps.io`
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

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

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  /// Show demo map pins when the API is unreachable (dev only).
  static const bool demoFallback = bool.fromEnvironment(
    'DEMO_FALLBACK',
    defaultValue: false,
  );

  static bool get allowDemoData => !isProduction && demoFallback;

  /// Privacy policy URL for Play Store listing and in-app link.
  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://margem.app/privacy',
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
