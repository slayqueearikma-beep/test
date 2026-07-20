/// App configuration — update for your environment.
class AppConfig {
  /// Production API URL. Set at build time:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000`
  ///
  /// Important: include the colon before the port (`:8000`). A common typo is
  /// `http://192.168.1.108000` which cannot resolve.
  static final String apiBaseUrl = normalizeApiBaseUrl(
    const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://10.0.2.2:8000',
    ),
  );

  /// Fixes common `API_BASE_URL` typos such as a missing `:` before the port
  /// (`http://192.168.11.1038000` → `http://192.168.11.103:8000`) and strips
  /// trailing slashes so path joins stay correct.
  static String normalizeApiBaseUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return 'http://10.0.2.2:8000';

    // Strip trailing slashes (keep scheme://host[:port] form).
    while (url.endsWith('/') && url.length > 1) {
      url = url.substring(0, url.length - 1);
    }

    // Missing colon before a well-known port glued to an IPv4 host.
    // Try longer ports first so 8080 wins over 80.
    const stuckPorts = ['8443', '8080', '8000', '5000', '3000', '443', '80'];
    for (final port in stuckPorts) {
      if (!url.endsWith(port)) continue;
      final withoutPort = url.substring(0, url.length - port.length);
      final hostMatch =
          RegExp(r'^(https?://)(\d{1,3}(?:\.\d{1,3}){3})$').firstMatch(withoutPort);
      if (hostMatch == null) continue;
      final host = hostMatch[2]!;
      final octets = host.split('.').map(int.parse).toList();
      if (octets.any((octet) => octet < 0 || octet > 255)) continue;
      url = '${hostMatch[1]}$host:$port';
      break;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      // Keep the raw value so the connection error still surfaces it.
      return url;
    }
    return url;
  }

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
