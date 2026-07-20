# MarGem Mobile — Play Store ready setup

## Prerequisites

- Flutter 3.16+
- Android Studio
- Google Maps API key (optional — maps are off by default)
- Production API URL (Azure Container Apps)

## Local development

```bash
flutter pub get
# Include the colon before the port (:8000). Wrong: http://192.168.1.108000
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

If `assembleDebug` fails, get the real Gradle line (not just exit code 1):

```bash
cd android && ./gradlew assembleDebug --stacktrace
# or:
flutter run -v --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

Common fixes:
- Install Android SDK Platform 35 + NDK (Side by side) from Android Studio → SDK Manager
- Ensure USB debugging works: `adb devices` shows `device`
- Free RAM if Gradle cannot start (heap is capped at 4G)

Optional demo map when API is offline (dev only):

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000 --dart-define=DEMO_FALLBACK=true
```

## Google Maps (optional)

1. Enable **Maps SDK for Android** in Google Cloud Console
2. Add to `android/local.properties` (copy from `android/local.properties.example`):

```properties
GOOGLE_MAPS_API_KEY=your_key_here
```

3. Run with maps enabled:

```bash
flutter run --dart-define=ENABLE_MAPS=true --dart-define=API_BASE_URL=http://YOUR_PC_IP:8000
```

## Play Store release build

### 1. Create a release keystore (once)

```bash
keytool -genkey -v -keystore margem-release.keystore -alias margem -keyalg RSA -keysize 2048 -validity 10000
```

### 2. Configure signing

```bash
cp android/key.properties.example android/key.properties
```

Edit `android/key.properties` with your keystore path and passwords.

### 3. Build the App Bundle

```bash
flutter build appbundle \
  --dart-define=PRODUCTION=true \
  --dart-define=API_BASE_URL=https://YOUR-API.azurecontainerapps.io \
  --dart-define=PRIVACY_POLICY_URL=https://margem.app/privacy
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 4. Play Console checklist

- [ ] Upload `app-release.aab`
- [ ] Privacy policy URL (see `PRIVACY_POLICY.md`)
- [ ] App icon (included — `assets/images/margem_logo.png`)
- [ ] Screenshots and store listing
- [ ] Content rating questionnaire

## Features

- JWT auth with **automatic token refresh** (sessions stay logged in)
- Secure token storage (`flutter_secure_storage`)
- HTTPS-only in release builds
- Image uploads for seller cover photos (via API presign)
- No fake demo data in production builds

## Physical device

Use your PC's LAN IP instead of `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8000
```
