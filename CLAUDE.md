# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Prayer Lock** (`com.mdnahid.prayerlock`) — Build Discipline, Pray on Time.
Prayer Lock is not just another Islamic app—it’s a discipline system designed to help you consistently pray on time, without distractions.

Built for modern Muslims who struggle with focus in a digital world, Prayer Lock combines essential daily tools with behavior-driven features that actively guide you toward maintaining Salah on time.

**Key Principle**: Every line of code serves a spiritual purpose. Build with care, precision, and respect.

## Feature Tiers

### Free (Ad-Supported)

| Feature                 | Notes                                                                                                  |
| ----------------------- | ------------------------------------------------------------------------------------------------------ |
| **Prayer Times**        | Location-based (GPS) + manual city/country selection; all calculation methods & madhabs                |
| **Quran Reader**        | Full text, audio recitation, bookmarks, full-text search                                               |
| **Dua Categories**      | Limited selection (morning, evening, anxiety, travel, sleep, meal, etc.) — remaining categories locked |
| **Hadith Section**      | Limited daily hadiths with short explanations — bulk collection locked                                 |
| **Qibla Direction**     | Basic compass via `flutter_qiblah`                                                                     |
| **Adhan Notifications** | Full adhan + 1 reminder per prayer (pre-prayer alert)                                                  |
| **Google AdMob Ads**    | Lightweight, non-intrusive banner/interstitial ads via `google_mobile_ads`                             |

### Pro (Subscription via RevenueCat)

| Feature                 | Notes                                                                                                                                                                                                                                                                                                                |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **App Blocker**         | Blocks user-selected apps (e.g. Instagram, TikTok) during prayer windows. Uses Android `UsageStatsManager` + `SYSTEM_ALERT_WINDOW` overlay + `AccessibilityService`. Overlay shows CTA card: toggle "I prayed — don't fake it, Allah is watching you" + Unblock button. On confirm → unblock all + navigate to Home. |
| **Full Dua & Hadith**   | Unlocks all dua categories and complete hadith collections                                                                                                                                                                                                                                                           |
| **Home Screen Widgets** | Android AppWidget showing next prayer time + countdown; implemented via `home_widget` package                                                                                                                                                                                                                        |

**Monetisation rules:**

- `isProProvider` (Riverpod) gates all Pro UI — single source of truth; reads from RevenueCat entitlement
- RevenueCat (`revenuecat_service.dart`) handles both paywall presentation and entitlement verification — lives in `subscription/data/services/`; `superwall_service.dart` is a stub (Superwall was replaced)
- Free users see a tasteful upgrade prompt when tapping locked content — never a hard paywall on core worship features (prayer times, full Quran always free)
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

# Build
flutter build apk --release
flutter build appbundle --release
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
│   ├── utils/        # AppLogger
│   └── widgets/      # (empty — shared widgets not yet extracted)
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
└── main_screen.dart   # Bottom nav shell + provisional screens
```

### Implementation Status

| Feature           | Domain | Data | Presentation                                           | Tier                        |
| ----------------- | ------ | ---- | ------------------------------------------------------ | --------------------------- |
| **Home**          | —      | —    | ✅ Complete (`home_screen.dart`)                       | Free                        |
| **Quran**         | ✅     | ✅   | ✅ 5 screens, 7 widgets, 5 providers                   | Free                        |
| **Prayer Times**  | ✅     | ✅   | ✅ 2 screens, 5 providers (`prayer_times_screen.dart`, `prayer_settings_screen.dart`) | Free |
| **Notifications** | ✅     | —    | ✅ `notification_service.dart` in prayer_times/providers | Free                      |
| **Qibla**         | ✅     | ✅   | ⏳ No screen yet (data/domain live in `prayer_times/`) | Free                        |
| **Dua & Dhikr**   | ⏳     | ⏳   | ⏳ Provisional `DuaDhikrScreen` in `main_screen.dart`  | Free (limited) / Pro (full) |
| **Hadith**        | ⏳     | ⏳   | ⏳ Provisional `HadithScreen` in `main_screen.dart`    | Free (limited) / Pro (full) |
| **AdMob Ads**     | —      | —    | ⏳ Not started                                         | Free only                   |
| **App Blocker**   | ✅     | ✅   | ✅ `app_blocker_screen.dart` + `AppBlockerNotifier`    | Pro                         |
| **Home Widgets**  | —      | —    | ⏳ Not started                                         | Pro                         |
| **Subscription**  | ✅     | ✅   | ⏳ Providers only; no screens/widgets yet              | —                           |
| **Calendar**      | ⏳     | ⏳   | ⏳ Not started (no feature folder yet)                 | Free                        |

`main_screen.dart` contains provisional `HadithScreen`, `DuaDhikrScreen`, and `MoreScreen` inline — move to feature folders as features are built. `main.dart` handles app initialization and is the `ProviderScope`/`ConsumerWidget` root. `selectedTabProvider` (bottom nav index) is defined in `main.dart`.

**App startup sequence** (order matters):
1. `AndroidAlarmManager.initialize()`
2. `Hive.initFlutter()` + open `quran_data` box
3. `PrayerTimesLocalDataSource().initialize()` (registers Hive adapters + opens boxes)
4. `NotificationService().initialize()` + `requestPermissions()`
5. `RevenueCatService.configure()`
6. `runApp(ProviderScope(...))`

## SQLite Database (`muslim_companion.db`)

Managed by the singleton `DatabaseHelper` in `core/database/database_helper.dart`. Schema:

| Table       | Purpose                                                                                 |
| ----------- | --------------------------------------------------------------------------------------- |
| `surahs`    | 114 chapters (id, Arabic name, transliteration, English, revelation place, total ayahs) |
| `ayahs`     | 6236 verses (surah_id, ayah_number, textArabic, textEnglish)                            |
| `ayahs_fts` | FTS5 virtual table — auto-synced via triggers for full-text search                      |
| `bookmarks` | User bookmarks (surah_id, ayah_id, created_at)                                          |
| `last_read` | Single-row table tracking last reading position                                         |

Quran data is fetched from the Al-Quran Cloud API (`https://api.alquran.cloud/v1`) and cached locally in SQLite. Prayer times use the Aladhan API (`https://api.aladhan.com/v1`) and are cached in Hive.

## State Management

**Riverpod** (mandatory). All providers live in `features/<feature>/presentation/providers/`.

```dart
// StateNotifier for complex state
final surahListProvider = StateNotifierProvider<SurahListNotifier, SurahListState>((ref) {
  return SurahListNotifier(getAllSurahsUseCase: ref.read(getAllSurahsUseCaseProvider));
});

// Family provider for parameterised state (e.g. per-surah)
final surahDetailProvider = StateNotifierProvider.family<SurahDetailNotifier, SurahDetailState, int>(
  (ref, surahId) => SurahDetailNotifier(surahId: surahId, ...),
);
```

**Cross-cutting providers:**

- `themeProvider` in `core/theme/theme_provider.dart` — app-wide dark/light toggle
- `arabicFontSizeProvider` in `quran/presentation/widgets/font_size_controls.dart` — persisted Arabic font size (18–32, default 24)
- `translationVisibilityProvider` in `quran/presentation/widgets/ayah_card.dart` — toggle English translation

**Key rules:**

- `ref.read` in `initState` / callbacks; `ref.watch` in `build`
- `ref.listen` in `build` to react to state transitions (e.g. scroll-to-initial-ayah after data loads)
- Never call a use-case inside a `FutureBuilder` builder — capture the `Future` once in `initState`:

```dart
late Future<dynamic> _resultFuture;

@override
void initState() {
  super.initState();
  _resultFuture = ref.read(someUseCaseProvider)();  // captured once
}
```

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
- **`theme_provider.dart`** — Riverpod `themeProvider` (StateNotifierProvider), persisted via SharedPreferences

`main.dart` is a `ConsumerWidget` that watches `themeProvider` and syncs `SystemChrome` overlay style.

**Color palettes (defined in AppTheme):**

- Dark ("Midnight Oasis") — bg `#0D1520`, surface `#152032`, primary emerald `#10B981`, secondary gold `#D4A574`, tertiary teal `#14B8A6`
- Light ("Ivory Sanctuary") — bg `#F5F2EB`, surface `#FFFFFF`, primary `#15803D`, secondary gold `#C9A961`

All widgets use `Theme.of(context).colorScheme` — no hardcoded colors. For the rare cases where behavior differs by theme, use `Theme.of(context).brightness == Brightness.dark`.

## UI/UX Guidelines

**Typography:**

- Arabic text: Amiri font (`assets/fonts/arabic/Amiri-Regular.ttf`, `Amiri-Bold.ttf`) — fonts are present in assets but **not yet registered in pubspec.yaml**; add the `fonts:` section when enabling
- Always set `textDirection: TextDirection.rtl` on Arabic `Text` widgets

**Layout conventions used across the app:**

- Cards: bordered (`cs.outlineVariant`), `borderRadius: 14–16`, using `cs.surfaceContainer` background — no shadows
- `SliverAppBar(expandedHeight: 110, pinned: true)` with green gradient for detail screens
- `CustomScrollView` + `SliverList.builder` for long lists (Flutter 3.7+)
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
- Endpoints: `GET /surah` (all chapters), `GET /surah/{id}` (chapter + ayahs)
- Data is seeded into SQLite after first fetch; subsequent reads are local-only

### Hadith — sunnah.com API _(not yet implemented)_

- **Base URL**: `https://api.sunnah.com/v1`
- Requires `x-api-key` header
- Collections: `bukhari`, `muslim`, `tirmidhi`, `abudawud`, `nasai`, `ibnmajah`
- Free tier: cache a small curated set locally in SQLite; Pro unlocks full browsing

## AdMob Integration

- Package: `google_mobile_ads`
- Ad units: banner (bottom of list screens) + interstitial (on navigation between major sections, max 1 per session interval)
- **Never show ads on**: Quran reading screen, prayer time screen, active prayer notification
- Hide all ads for Pro subscribers (`isProProvider` check before rendering ad widgets)
- Ad unit IDs stored in `core/constants/ad_constants.dart`; test IDs in debug, real IDs in release via `--dart-define` or `.env`

## App Blocker (Pro) — Android Only

**How it works:**

1. User selects apps to block in Settings → App Blocker (shows installed app list)
2. During each prayer window (start → start + estimated duration), a foreground service polls foreground app via `UsageStatsManager`
3. If a blocked app is detected, draw a full-screen overlay (`SYSTEM_ALERT_WINDOW`) showing the Prayer Lock screen
4. Prayer Lock screen UI:
   - App name + "This app is blocked during prayer time" message
   - Toggle: "I have prayed — don't fake it, Allah is watching you 🤲"
   - "Unblock" CTA button (enabled only when toggle is ON)
   - On Unblock: dismiss overlay, cancel foreground service, navigate to app Home screen

**Required permissions (request at runtime with rationale):**

- `PACKAGE_USAGE_STATS` — detect foreground app (requires user to grant in Special App Access)
- `SYSTEM_ALERT_WINDOW` — draw overlay above other apps
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` — keep blocker alive

**Architecture:**

- `features/app_blocker/` — full clean-arch feature folder
- Native Android channel (`MethodChannel`) for `UsageStatsManager` (no Dart API exists)
- Overlay rendered as a Flutter `Activity` with `TYPE_APPLICATION_OVERLAY` window flag, OR a native XML layout for reliability
- `AppBlockerService` (Android `Service`) started/stopped by `AppBlockerNotifier` (Riverpod)
- Blocked app list persisted in Hive

**iOS note:** iOS sandboxing prevents app monitoring — this feature is Android-only; hide the UI on iOS entirely.

## Home Screen Widgets (Pro) — Android

- Package: `home_widget` (pub.dev)
- Widget shows: next prayer name, time, and countdown
- Updated via `HomeWidget.saveWidgetData` + `HomeWidget.updateWidget` whenever prayer times refresh
- Widget layout defined in `android/app/src/main/res/layout/prayer_widget.xml`
- Register `AppWidgetProvider` in `AndroidManifest.xml`
- iOS equivalent: WidgetKit — defer until after Android is complete

## Platform Notes

- **Android Min SDK**: 26 (Android 7.0), **Target SDK**: 34
- **Permissions (free):** `INTERNET`, `ACCESS_FINE_LOCATION`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`
- **Permissions (Pro — App Blocker):** `PACKAGE_USAGE_STATS` (Special App Access, not grantable via `requestPermissions`), `SYSTEM_ALERT_WINDOW` (overlay), `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`
- Exact alarms on Android 12+ require explicit user permission — handle gracefully
- `PACKAGE_USAGE_STATS` requires directing user to Settings → Special App Access → Usage Access (use `Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)`)
- App Blocker feature is **Android-only** — hide entirely on iOS; do not request iOS entitlements for it

## Critical Notes

1. **Prayer Notifications**: MUST be reliable. Use exact alarms. Test on multiple Android versions.
2. **Quranic Text**: Triple-check accuracy. Handle Arabic text with utmost respect.
3. **Offline**: Most features must work without internet. SQLite is primary for Quran/Hadith; Hive for settings/cache.
4. **Privacy**: Location used only for prayer times. No tracking without explicit consent. App Blocker usage data never leaves the device.
5. **Performance**: Cold start < 2s, 60 FPS, memory < 150 MB, APK < 50 MB.
6. **Pro Gating**: Always check `isProProvider` before rendering locked content. Never hard-block prayer times or full Quran — those are always free.
7. **App Blocker UX**: The Prayer Lock overlay must be impossible to dismiss without the "I prayed" toggle — but always provide an emergency exit (long-press 5s or settings back-door) in case of bugs.
8. **AdMob Policy**: No ads on sacred content screens (Quran reading, active prayer). Follow AdMob content policies — Islamic content is permitted; verify ad categories to avoid inappropriate ads (use ad content filtering).
9. **App Blocker Permission Flow**: Walk users through `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` grants with clear in-app explanations before requesting — these are sensitive permissions and Google Play reviews them carefully.

## Key Packages

| Package                       | Purpose                                                      |
| ----------------------------- | ------------------------------------------------------------ |
| `flutter_riverpod`            | State management                                             |
| `dartz`                       | `Either<Failure, Success>` functional pattern                |
| `sqflite`                     | SQLite (Quran DB, bookmarks, last read)                      |
| `hive` / `hive_flutter`       | Fast cache & preferences                                     |
| `shared_preferences`          | Simple settings (font size, calculation method)              |
| `dio`                         | HTTP client (Al-Quran Cloud, Aladhan)                        |
| `geolocator`                  | GPS for prayer times                                         |
| `flutter_local_notifications` | Prayer time alerts                                           |
| `android_alarm_manager_plus`  | Exact alarms (Android)                                       |
| `audioplayers`                | Quran recitation audio                                       |
| `flutter_qiblah`              | Qibla compass                                                |
| `hijri`                       | Hijri calendar conversion                                    |
| `geocoding`                   | Reverse geocoding for city/country name from coordinates     |
| `purchases_flutter`           | RevenueCat subscriptions                                     |
| `purchases_ui_flutter`        | RevenueCat paywall UI components                             |
| `logger`                      | Pretty-printed logs via `AppLogger`                          |
| `intl`                        | Date/time formatting                                         |
| `http`                        | Lightweight HTTP (supplement to Dio where needed)            |
| `google_mobile_ads`           | AdMob banner & interstitial ads (free tier) — **not yet added to pubspec.yaml** |
| `home_widget`                 | Android/iOS home screen widgets (Pro) — **not yet added to pubspec.yaml** |
| `permission_handler`          | Runtime permission requests (USAGE_STATS, OVERLAY, LOCATION) |
| `flutter_svg`                 | SVG asset rendering                                          |
| `cached_network_image`        | Network image caching                                        |

---

**Remember**: This is a spiritual tool. Reliability > features. Respect > speed. Build it right.
