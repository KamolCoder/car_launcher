# Car Launcher

Car head-unit launcher for Galaxy Tab S9: Yandex Music control via MediaSession, GPS speed, clock, dock,
autostart on ignition (charger connected).

## Setup

```bash
flutter create --org uz.kamol --platforms android car_launcher
cd car_launcher
flutter pub add flutter_riverpod geolocator
```

Copy from this archive over the generated project:

- `lib/` — whole folder (delete generated `lib/main.dart` first)
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/uz/kamol/car_launcher/*.kt` (replaces generated `MainActivity.kt`)
- `android/app/src/main/res/` (merge: `xml/device_admin.xml`, `values/car_launcher_strings.xml`)

In `android/app/build.gradle.kts` set:

```kotlin
defaultConfig {
    minSdk = 29
}
```

Run: `flutter run --release`

## On the tablet

1. Open the app → Settings (dock) → grant everything marked red:
   notification access, display over other apps, location, default launcher, battery "Unrestricted".
2. Android settings: lock screen "None" or "Swipe", screen timeout 30 s – 1 min.
3. Open Yandex Music once and start any track (so its media session exists).

## Split screen

Dock → «Навигатор» opens Yandex Navigator in split screen next to the launcher.
The home task can't be split, so `DashboardActivity` (same Flutter UI, normal resizeable task) is started
and it launches Navigator with `FLAG_ACTIVITY_LAUNCH_ADJACENT`. Below 900 dp width the UI switches to the
compact layout; «Полный экран» returns to the home launcher.

## Alice

Dock «Алиса» / mic button in split screen → `ACTION_VOICE_COMMAND` to the standalone «Алиса AI» app
(`com.yandex.aliceapp`), else its main screen, else Play Store. «Яндекс — с Алисой» (`com.yandex.searchapp`)
is not used: it opens its browser UI instead of voice mode.
Hands-free «Слушай, Алиса»: Alice AI → Settings → Voice activation; set it as default digital assistant
and keep it in «Never sleeping apps».

## Logic

- Charger connected for 1.5 s → ignition ON → launcher to front (wakes screen) → Yandex Music play.
- While ignition is ON the service holds a screen wake lock → screen stays on whatever app is in front.
- Charger gone for 8 s → ignition OFF → pause all media sessions + take audio focus (other players stop),
  launcher to front, release wake lock, `DevicePolicyManager.lockNow()` after 1.5 s.
  8 s debounce ignores the power drop while cranking the starter.
  Without device admin (Settings → «Блокировка экрана») the system screen timeout turns the screen off.
