# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Prayer Lock** (`com.mdnahid.prayerlock`) — Build Discipline, Pray on Time.

Built for modern Muslims who struggle with focus in a digital world, Prayer Lock combines essential daily tools with behavior-driven features that actively guide users toward maintaining Salah on time.

**Key Principle**: Every line of code serves a spiritual purpose. Build with care, precision, and respect.

## Feature Tiers

### Free (Ad-Supported)

| Feature                 | Notes                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| **Prayer Times**        | Location-based (GPS) + manual city/country selection; all calculation methods & madhabs                |
| **Quran Reader**        | Full text, audio recitation, bookmarks, full-text search                                               |
| **Dua Categories**      | Limited selection (morning, evening, anxiety, travel, sleep, meal, etc.) — remaining categories locked |
| **Hadith Section**      | Limited daily hadiths — bulk collection locked                                                         |
| **Qibla Direction**     | Basic compass via `flutter_qiblah`                                                                     |
| **Adhan Notifications** | Full adhan + 1 reminder per prayer (pre-prayer alert)                                                  |
| **Google AdMob Ads**    | Lightweight banner/interstitial ads via `google_mobile_ads`                                            |

### Pro (Subscription via RevenueCat)

| Feature                 | Notes                                                                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **App Blocker**         | Blocks user-selected apps during prayer windows via `UsageStatsManager` + `SYSTEM_ALERT_WINDOW` overlay. Android-only.                                 |
| **Full Dua & Hadith**   | Unlocks all dua categories and complete hadith collections                                                                                             |
| **Home Screen Widgets** | Android AppWidget showing next prayer time + countdown via `home_widget` package                                                                       |

**Monetisation rules:**

- `isProProvider` (Riverpod) gates all Pro UI — single source of truth; reads from RevenueCat entitlement
- The custom `ProPaywallSheet` is the only paywall UI — RevenueCat's own paywall UI (`purchases_ui_flutter`) is **not used**
- `RevenueCatService` in `subscription/data/services/revenuecat_service.dart` handles entitlement verification and direct purchases via `Purchases.purchase(PurchaseParams.package(...))`
- `SubscriptionRepository.purchase(String planId)` takes `'monthly'` or `'lifetime'` — matched to the RevenueCat current offering's `PackageType`
- `superwall_service.dart` is a stub (Superwall was replaced by RevenueCat)
- Free users see `ProPaywallSheet` when tapping locked content — never block prayer times or full Quran (always free)
- AdMob ads are hidden for Pro users

## Development Commands

```bash
# Run the app
flutter run

# Run on specific device
flutter run -d <device-id>

# Code analysis
flutter analyze

# Run tests / single test
flutter test
flutter test test/path/to/test_file.dart

# Code generation (Riverpod, Hive) — always use the flag to avoid conflicts
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Clean & rebuild
flutter clean && flutter pub get

# Build — signed release (requires android/key.properties + android/upload-keystore.jks)
flutter build appbundle --release   # Play Store (.aab)
flutter build apk --release         # Direct APK
```

## Architecture

**Clean Architecture (Mandatory)** — feature-first folder structure:

```
lib/
├── core/
│   ├── constants/    # API endpoints & timeouts (api_constants.dart)
│   ├── database/     # SQLite singleton (database_helper.dart)
│   ├── errors/       # Failure hierarchy (failures.dart)
│   ├── network/      # Dio singleton with logging interceptor (dio_client.dart)
│   ├── theme/        # AppTheme (dark/light ThemeData) + ThemeNotifier (Riverpod)
│   └── utils/        # AppLogger
├── features/
│   └── <feature>/
│       ├── data/
│       │   ├── datasources/   # Remote & Local
│       │   ├── models/        # JSON + Hive models
│       │   └── repositories/  # Implementations
│       ├── domain/
│       │   ├── entities/      # Pure Dart objects
│       │   ├── repositories/  # Interfaces
│       │   └── usecases/      # Business logic
│       └── presentation/
│           ├── providers/     # Riverpod StateNotifiers
│           ├── screens/       # Full-screen pages
│           └── widgets/       # Feature-specific widgets
├── main.dart          # App init, ProviderScope root, ConsumerWidget
└── main_screen.dart   # Bottom nav shell + MoreScreen (inline) + permission bootstrap
```

### Implementation Status

| Feature           | Domain | Data | Presentation                                                                      | Tier                        |
| ----------------- | ------ | ---- | --------------------------------------------------------------------------------- | --------------------------- |
| **Home**          | —      | —    | ✅ `home_screen.dart`                                                             | Free                        |
| **Quran**         | ✅     | ✅   | ✅ 5 screens, 7 widgets, 5 providers                                              | Free                        |
| **Prayer Times**  | ✅     | ✅   | ✅ `prayer_times_screen.dart`, `prayer_settings_screen.dart`, 5 providers         | Free                        |
| **Notifications** | ✅     | —    | ✅ `notification_service.dart` in `prayer_times/providers/`                      | Free                        |
| **Qibla**         | ✅     | ✅   | ✅ `qibla_compass_sheet.dart` (modal sheet, no dedicated screen)                  | Free                        |
| **Dua & Dhikr**   | ✅     | ✅   | ✅ `duadhikr_screen.dart`, `dua_detail_screen.dart`, 3 providers, `dua_card.dart` | Free (limited) / Pro (full) |
| **Hadith**        | ✅     | ✅   | ✅ `hadith_screen.dart`, `hadith_list_screen.dart`, 4 providers, `hadith_card.dart` | Free (limited) / Pro (full) |
| **Onboarding**    | —      | —    | ✅ `onboarding_screen.dart` + `onboarding_provider.dart` (presentation only)     | —                           |
| **Auth**          | ✅     | ✅   | ✅ `auth_screen.dart` (bottom sheet only — no standalone screen)                  | —                           |
| **AdMob Ads**     | —      | —    | ⏳ Not started                                                                    | Free only                   |
| **App Blocker**   | ✅     | ✅   | ✅ `app_blocker_screen.dart` + `AppBlockerNotifier`                               | Pro                         |
| **Home Widgets**  | —      | —    | ⏳ Not started                                                                    | Pro                         |
| **Subscription**  | ✅     | ✅   | ✅ `pro_paywall_sheet.dart`; no dedicated screen                                  | —                           |
| **Calendar**      | ⏳     | ⏳   | ⏳ Folder exists but empty                                                        | Free                        |

`main_screen.dart` imports `HadithScreen` and `DuaDhikrScreen` from their feature folders. `MoreScreen` remains inline in `main_screen.dart`. `selectedTabProvider` (bottom nav index) is defined in `main.dart`.

**App startup sequence** (order matters):
1. `Firebase.initializeApp()` + Crashlytics error hooks (must be first — auth depends on it)
2. `AndroidAlarmManager.initialize()`
3. `Hive.initFlutter()` + open `quran_data` box
4. `PrayerTimesLocalDataSource().initialize()` (registers Hive adapters + opens boxes)
5. `NotificationService().initialize()` + `requestPermissions()`
6. `RevenueCatService.configure()`
7. `runApp(ProviderScope(...))`

`main.dart` is a `ConsumerWidget` that watches `onboardingCompletedProvider` — routes to `OnboardingScreen` on first launch, `MainScreen` thereafter.

## Permission Bootstrap

`MainScreen` is a `ConsumerStatefulWidget` (not `ConsumerWidget`) and handles runtime permission requests once on first frame via `addPostFrameCallback`. The flow:

1. Request `Permission.notification` + `Permission.locationWhenInUse` together (system dialogs; no-op if already granted)
2. On Android: query `AppBlockerRepository.hasUsageStatsPermission()` and `hasOverlayPermission()` via native MethodChannel
3. If either special permission is missing, show `_SpecialPermissionsSheet` — a bottom sheet explaining each missing permission with "Grant" buttons that open the correct Settings page
4. `WidgetsBindingObserver` is registered; on `AppLifecycleState.resumed`, re-checks special permissions **only** when `_openedSpecialSettings == true` (set when a "Grant" button is tapped), preventing repeated prompts after ordinary background/foreground cycles

For Usage Stats and Overlay: the `AppBlockerNativeDataSource` MethodChannel (`com.mdnahid.prayerlock/app_blocker`) handles both checking and opening the correct Settings intent — do not use `permission_handler` for these two.

## Firebase

Firebase Core + Crashlytics are integrated (`firebase_options.dart` generated by `flutterfire configure`).

- Crashlytics is **disabled in debug mode** (`kDebugMode` check in `main.dart`); collects crash data in release only
- Both `FlutterError.onError` and `PlatformDispatcher.instance.onError` are routed to Crashlytics
- Firebase Auth is the only Firebase product in active use — Firestore not yet added
- Android: `google-services` plugin must be **≥ 4.4.1** (currently `4.4.2` in `settings.gradle.kts`) — Crashlytics plugin v3 hard-requires this
- Proguard: `android/app/proguard-rules.pro` has `-dontwarn` rules for Play Core split-install stubs

## Authentication

Firebase Auth with email/password + Google Sign-In. Auth is always a modal bottom sheet — never a standalone screen.

```dart
final signedIn = await showAuthSheet(context, ref.read(authRepositoryProvider));
```

**Providers** (all in `auth/presentation/providers/auth_providers.dart`):

- `authRepositoryProvider` → `FirebaseAuthService` singleton
- `authUserProvider` — `StreamProvider<AuthUser?>` — null when signed out or loading
- `isSignedInProvider` — `Provider<bool>` — derived from `authUserProvider`

**Auth gate pattern** — auth is required only at the moment of purchase:

```dart
// In ProPaywallSheet._handleUpgrade()
final isSignedIn = ref.read(isSignedInProvider);
if (!isSignedIn) {
  final signedIn = await showAuthSheet(context, ref.read(authRepositoryProvider));
  if (!signedIn || !mounted) return;
}
// proceed with RevenueCat purchase
```

`MoreScreen` does **not** show a sign-in card. Auth surfaces only when the user taps "Unlock Pro".

## Paywall Flow

`showProPaywall(context, repo, placement: '...')` presents `ProPaywallSheet` as a modal bottom sheet. The sheet owns all paywall UI and:

1. Checks `isSignedInProvider`; shows `AuthSheet` first if not signed in
2. User selects Monthly or Lifetime plan card
3. On "Unlock Pro" tap, calls `repo.purchase(planId)` where `planId` is `'monthly'` or `'lifetime'`
4. `RevenueCatService.purchase()` fetches the current offering, finds the matching `Package`, then calls `Purchases.purchase(PurchaseParams.package(pkg))`

The `onUpgradeTap` callback type on `ProPaywallSheet` is `Future<void> Function(String planId)`. The `showProPaywall` helper wires it as `(planId) => repo.purchase(planId)`.

## SQLite Database (`muslim_companion.db`)

Managed by the singleton `DatabaseHelper` in `core/database/database_helper.dart`. Schema:

| Table       | Purpose                                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| `surahs`    | 114 chapters (id, Arabic name, transliteration, English, revelation place, total ayahs) |
| `ayahs`     | 6236 verses (surah_id, ayah_number, textArabic, textEnglish)                            |
| `ayahs_fts` | FTS5 virtual table — auto-synced via triggers for full-text search                      |
| `bookmarks` | User bookmarks (surah_id, ayah_id, created_at)                                          |
| `last_read` | Single-row table tracking last reading position                                         |

Quran data is fetched from the Al-Quran Cloud API and cached in SQLite. Prayer times use the Aladhan API and are cached in Hive.

## State Management

**Riverpod** (mandatory). All providers live in `features/<feature>/presentation/providers/`.

```dart
// StateNotifier for complex state
final surahListProvider = StateNotifierProvider<SurahListNotifier, SurahListState>((ref) {
  return SurahListNotifier(getAllSurahsUseCase: ref.read(getAllSurahsUseCaseProvider));
});

// Family provider for parameterised state
final surahDetailProvider = StateNotifierProvider.family<SurahDetailNotifier, SurahDetailState, int>(
  (ref, surahId) => SurahDetailNotifier(surahId: surahId, ...),
);
```

**Cross-cutting providers:**

- `themeProvider` — `core/theme/theme_provider.dart`
- `isProProvider` — `subscription/presentation/providers/subscription_providers.dart`
- `authRepositoryProvider` / `authUserProvider` / `isSignedInProvider` — `auth/presentation/providers/auth_providers.dart`
- `arabicFontSizeProvider` — `quran/presentation/widgets/font_size_controls.dart`
- `translationVisibilityProvider` — `quran/presentation/widgets/ayah_card.dart`

**Key rules:**

- `ref.read` in `initState` / callbacks; `ref.watch` in `build`
- `ref.listen` in `build` to react to state transitions
- Capture futures once in `initState`, never inside a `FutureBuilder` builder

**Provider location pitfalls:**

- `locationProvider` is defined in `prayer_times_providers.dart`, NOT in `location_notifier.dart`
- All prayer-times dependency wiring lives in `prayer_times_providers.dart`

## Error Handling

```dart
Future<Either<Failure, T>> example() async {
  try {
    final data = await remoteDataSource.getData();
    return Right(data);
  } on NetworkException {
    try {
      return Right(await localDataSource.getCached());
    } catch (e) {
      return Left(CacheFailure('No cached data available'));
    }
  } catch (e) {
    return Left(UnknownFailure(e.toString()));
  }
}
```

Failure types: `ServerFailure`, `NetworkFailure`, `CacheFailure`, `DatabaseFailure`, `PermissionFailure`, `UnknownFailure`.

## Theme System

Dark-first design. Defined in `core/theme/`:

- **`app_theme.dart`** — `AppTheme.dark()` and `AppTheme.light()` with full Material 3 ColorScheme
- **`theme_provider.dart`** — Riverpod `themeProvider`, persisted via SharedPreferences

**Color palettes:**

- Dark ("Midnight Oasis") — bg `#0D1520`, surface `#152032`, primary emerald `#10B981`, secondary gold `#D4A574`, tertiary teal `#14B8A6`
- Light ("Ivory Sanctuary") — bg `#F5F2EB`, surface `#FFFFFF`, primary `#15803D`, secondary gold `#C9A961`

All widgets use `Theme.of(context).colorScheme` — no hardcoded colors. Use `Theme.of(context).brightness == Brightness.dark` for the rare cases where behavior differs by theme.

## UI/UX Guidelines

**Typography:**

- Arabic text: Amiri font (`assets/fonts/arabic/Amiri-Regular.ttf`, `Amiri-Bold.ttf`) — present in assets but **not yet registered in pubspec.yaml**; add the `fonts:` section when enabling
- Always set `textDirection: TextDirection.rtl` on Arabic `Text` widgets

**Layout conventions:**

- Cards: bordered (`cs.outlineVariant`), `borderRadius: 14–16`, `cs.surfaceContainer` background — no shadows
- `SliverAppBar(expandedHeight: 110, pinned: true)` with green gradient for detail screens
- `CustomScrollView` + `SliverList.builder` for long lists
- Generous padding: 16–24 dp

**Deprecations to avoid:**

- Use `color.withValues(alpha: x)` — **not** `color.withOpacity(x)` (deprecated in Flutter 3.27+)

## Important Lint Rules

From `analysis_options.yaml`:

- `prefer_single_quotes` — single quotes for all strings
- `require_trailing_commas` — required
- `avoid_print` — use `AppLogger` from `lib/core/utils/logger.dart`
- `always_declare_return_types` — explicit return types everywhere
- `prefer_const_constructors` — const wherever possible
- `always_use_package_imports` — never relative imports (e.g. `package:prayer_lock/...`)

## Logging

```dart
import 'package:prayer_lock/core/utils/logger.dart';

AppLogger.debug('message');
AppLogger.info('message');
AppLogger.warning('message');
AppLogger.error('message', error, stackTrace);
```

## API Integration

### Prayer Times — Aladhan API

- **Base URL**: `https://api.aladhan.com/v1`
- Endpoint: `GET /timingsByCity?city=X&country=Y&method=M&school=S`
- Calculation methods: MWL=3, ISNA=2, Egyptian=5, Makkah=4, Kuwait=9, Qatar=10
- Madhabs: Shafi/Maliki/Hanbali=0, Hanafi=1
- Cache in Hive for 30 days offline access

### Quran — Al-Quran Cloud API

- **Base URL**: `https://api.alquran.cloud/v1` (configured in `DioClient`)
- Endpoints: `GET /surah`, `GET /surah/{id}`
- Data is seeded into SQLite after first fetch; subsequent reads are local-only

### Hadith — sunnah.com API _(not yet implemented)_

- **Base URL**: `https://api.sunnah.com/v1`
- Requires `x-api-key` header
- Collections: `bukhari`, `muslim`, `tirmidhi`, `abudawud`, `nasai`, `ibnmajah`

## AdMob Integration

- Package: `google_mobile_ads` — **not yet added to pubspec.yaml**
- Ad units: banner (bottom of list screens) + interstitial (on navigation between major sections, max 1 per session)
- **Never show ads on**: Quran reading screen, prayer time screen, active prayer notification
- Hide all ads for Pro subscribers (`isProProvider` check before rendering ad widgets)
- Ad unit IDs stored in `core/constants/ad_constants.dart`; test IDs in debug, real IDs in release via `--dart-define`

## App Blocker (Pro) — Android Only

**How it works:**

1. User selects apps to block in More → App Blocker (shows installed app list)
2. During each prayer window, a foreground service polls foreground app via `UsageStatsManager`
3. If a blocked app is detected, draw a full-screen `SYSTEM_ALERT_WINDOW` overlay
4. Overlay shows "I have prayed — don't fake it, Allah is watching you" toggle + Unblock button; Unblock is only enabled when toggle is ON

**MethodChannel:** `com.mdnahid.prayerlock/app_blocker` — used for `getInstalledApps`, `startBlockerService`, `stopBlockerService`, `isBlockerServiceRunning`, `hasUsageStatsPermission`, `hasOverlayPermission`, `openUsageStatsSettings`, `openOverlaySettings`. This channel is also used by `MainScreen`'s permission bootstrap.

**Required permissions:**

- `PACKAGE_USAGE_STATS` — Special App Access; cannot be granted via `requestPermissions()` — must open `Settings.ACTION_USAGE_ACCESS_SETTINGS`
- `SYSTEM_ALERT_WINDOW` — must open `Settings.ACTION_MANAGE_OVERLAY_PERMISSION`
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE`

iOS: hide App Blocker UI entirely — sandboxing prevents app monitoring.

## Home Screen Widgets (Pro) — Android

- Package: `home_widget` — **not yet added to pubspec.yaml**
- Widget shows: next prayer name, time, and countdown
- Updated via `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget` whenever prayer times refresh
- Widget layout defined in `android/app/src/main/res/layout/prayer_widget.xml`

## Android Release Signing

`android/key.properties` (gitignored) is read in `android/app/build.gradle.kts` before the `android {}` block.

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=../upload-keystore.jks
```

`android/upload-keystore.jks` is also gitignored. Back both files up outside the repo — losing the upload keystore means losing the ability to push Play Store updates.

## Platform Notes

- **Android Min SDK**: 26 (Android 7.0), **Target SDK**: 34
- **Permissions (free):** `INTERNET`, `ACCESS_FINE_LOCATION`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`
- **Permissions (Pro — App Blocker):** `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`
- Exact alarms on Android 12+ require explicit user permission — handle gracefully
- App Blocker is **Android-only** — hide UI on iOS; no iOS entitlements for it

## Key Packages

| Package                       | Purpose                                                                        |
| ----------------------------- | ------------------------------------------------------------------------------ |
| `flutter_riverpod`            | State management                                                               |
| `dartz`                       | `Either<Failure, Success>` functional pattern                                  |
| `sqflite`                     | SQLite (Quran DB, bookmarks, last read)                                        |
| `hive` / `hive_flutter`       | Fast cache & preferences                                                       |
| `shared_preferences`          | Simple settings (font size, calculation method)                                |
| `dio`                         | HTTP client (Al-Quran Cloud, Aladhan)                                          |
| `geolocator`                  | GPS for prayer times                                                           |
| `flutter_local_notifications` | Prayer time alerts                                                             |
| `android_alarm_manager_plus`  | Exact alarms (Android)                                                         |
| `audioplayers`                | Quran recitation audio                                                         |
| `flutter_qiblah` (v3)         | Qibla compass — stream type is `Stream<QiblahDirection>` (NOT `QiblahData`)   |
| `hijri`                       | Hijri calendar conversion                                                      |
| `geocoding`                   | Reverse geocoding for city/country name from coordinates                       |
| `purchases_flutter`           | RevenueCat SDK — entitlement verification + direct purchase via `Purchases.purchase(PurchaseParams.package(...))` |
| `permission_handler`          | Runtime permission requests (notification, location); **not** used for Usage Stats or Overlay (those use the native MethodChannel) |
| `logger`                      | Pretty-printed logs via `AppLogger`                                            |
| `intl`                        | Date/time formatting                                                           |
| `http`                        | Lightweight HTTP (supplement to Dio where needed)                              |
| `google_mobile_ads`           | AdMob — **not yet added to pubspec.yaml**                                      |
| `home_widget`                 | Home screen widgets (Pro) — **not yet added to pubspec.yaml**                  |
| `flutter_svg`                 | SVG asset rendering                                                             |
| `cached_network_image`        | Network image caching                                                          |

## Critical Notes

1. **Prayer Notifications**: MUST be reliable. Use exact alarms. Test on multiple Android versions.
2. **Quranic Text**: Triple-check accuracy. Handle Arabic text with utmost respect.
3. **Offline**: Most features must work without internet. SQLite is primary for Quran/Hadith; Hive for settings/cache.
4. **Privacy**: Location used only for prayer times. App Blocker usage data never leaves the device.
5. **Performance**: Cold start < 2s, 60 FPS, memory < 150 MB, APK < 50 MB.
6. **Pro Gating**: Always check `isProProvider` before rendering locked content. Never hard-block prayer times or full Quran.
7. **App Blocker UX**: The overlay must be impossible to dismiss without the "I prayed" toggle — always provide an emergency exit (long-press 5s or settings back-door).
8. **AdMob Policy**: No ads on sacred content screens (Quran reading, active prayer). Use ad content filtering to avoid inappropriate ads on Islamic content.
9. **App Blocker Permissions**: `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` are Play Store–reviewed sensitive permissions. The initial prompt lives in `MainScreen._SpecialPermissionsSheet`; the in-context prompts live in `AppBlockerScreen` permission banners. Do not request them silently.

---

**Remember**: This is a spiritual tool. Reliability > features. Respect > speed. Build it right.
