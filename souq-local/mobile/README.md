# Mobile app setup

## Prerequisites

- Flutter 3.16+
- Android Studio / Xcode
- Google Maps API key with Maps SDK enabled
- Firebase project (for auth + FCM in production)

## Google Maps (required for map tab)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select a project → **APIs & Services → Library**
3. Enable **Maps SDK for Android** (and iOS if needed)
4. **Credentials → Create credentials → API key**
5. Replace the placeholder in `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="AIzaSy...your_real_key"/>
```

6. Rebuild the app (`flutter run`). A blank/gray map means the key is missing or invalid.

**Seller registration:** the map opens on a separate full screen (tap the location row on step 2). Do not embed `GoogleMap` inside scrollable forms — it crashes on Android.

**Demo mode:** if the backend API is offline, the map tab shows sample businesses automatically.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Use your machine IP instead of `10.0.2.2` on a physical device.

### First-time Android setup

If `android/` is missing, generate it without overwriting Dart sources:

```bash
flutter create . --platforms=android
git checkout -- lib/main.dart lib/app.dart   # keep MarGem entry point
```

**Windows:** enable **Developer Mode** (Settings → Privacy & security → For developers) so Flutter plugins can use symlinks.

**NDK version mismatch:** add to `android/app/build.gradle.kts` inside the `android { }` block:

```kotlin
ndkVersion = "27.0.12077973"
```

Install NDK 27 in Android Studio → SDK Manager → SDK Tools → NDK (Side by side).

## Backend API (live data)

The app calls `http://10.0.2.2:8000` on the **Android emulator** (your PC's localhost). If the API is not running, the app shows **demo businesses** automatically.

### Start the backend

From the repo root (`souq-local/`):

```bash
docker compose up
```

Or without Docker:

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Then run the app:

```bash
cd mobile
flutter run
```

**Physical phone:** use your PC's LAN IP instead of `10.0.2.2`:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.XX:8000
```

Disable demo fallback (show errors instead):

```bash
flutter run --dart-define=DEMO_FALLBACK=false
```

## Firebase (production auth)

1. Create a Firebase project
2. Add Android and iOS apps
3. Download `google-services.json` and `GoogleService-Info.plist`
4. Run `flutterfire configure` to generate `firebase_options.dart`
5. Set `AUTH_DEV_BYPASS=false` on the backend and configure `FIREBASE_CREDENTIALS_PATH`
