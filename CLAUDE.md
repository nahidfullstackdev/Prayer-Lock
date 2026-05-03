# CLAUDE.md

## Project Overview

**Prayer Lock** (`com.mdnahid.prayerlock`) — A spiritual discipline app for Muslims to maintain Salah on time. Combines prayer times, Quran reader, dua/hadith collections, and behavior-driven features like app blocking during prayer windows.

**Guiding Principle**: Reliability > features. Respect > speed. Every line of code serves a spiritual purpose.

---

## Commands

```bash
flutter run                          # Run the app
flutter run -d <device-id>           # Run on specific device
flutter analyze                      # Code analysis
flutter test                         # Run all tests
flutter test test/path/to/file.dart  # Run single test

# Code generation (Riverpod only — Hive adapters are hand-written)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

flutter clean && flutter pub get     # Clean & rebuild

# Release builds (require android/key.properties + android/upload-keystore.jks)
flutter build appbundle --release    # Play Store (.aab)
flutter build apk --release          # Direct APK
```

---

## Architecture

**Clean Architecture** — feature-first folder structure:

```
lib/
├── core/
│   ├── constants/       # API endpoints (api_constants.dart)
│   ├── database/        # SQLite singleton (database_helper.dart)
│   ├── errors/          # Failure hierarchy (failures.dart)
│   ├── network/         # Dio singleton (dio_client.dart), ConnectivityService
│   ├── startup/         # AppInitializer (two-phase boot)
│   ├── theme/           # AppTheme + ThemeNotifier
│   ├── utils/           # AppLogger
│   └── widgets/         # Cross-feature widgets (BrandLogo, AdhanTestWidget)
├── features/
│   └── <feature>/
│       ├── data/        # datasources/, models/, repositories/
│       ├── domain/      # entities/, repositories/ (interfaces), usecases/
│       └── presentation/ # providers/, screens/, widgets/
├── main.dart            # App init, ProviderScope root
└── main_screen.dart     # Bottom nav shell, MoreScreen (inline), permission bootstrap
```

---

## Feature Tiers

### Free (Ad-Supported)

- **Prayer Times** — GPS + manual city selection, all calculation methods & madhabs
- **Quran Reader** — Full text, audio, bookmarks, FTS search
- **Dua Categories** — Limited selection (remaining locked)
- **Hadith** — Limited daily hadiths (bulk locked)
- **Qibla Direction** — Compass via `flutter_qiblah`
- **Adhan Notifications** — Full adhan + 1 reminder per prayer
- **AdMob Ads** — Banner/interstitial via `google_mobile_ads` (not yet added to pubspec)

### Pro (Subscription via RevenueCat)

- **App Blocker** — Blocks apps during prayer windows (Android-only)
- **Full Dua & Hadith** — Unlocks all categories/collections
- **Home Screen Widgets** — Next prayer countdown via `home_widget`

### Monetisation Rules

- `isProProvider` (Riverpod) is the single source of truth for Pro gating
- `ProPaywallSheet` is the only paywall UI (RevenueCat's own paywall UI is **not used**)
- Plans: **Weekly $0.99/wk**, **Yearly $14.99/yr** (3-day free trial, default selection)
- Prices currently hardcoded in `_PlanCard` / `_billingNote`
- `SubscriptionRepository.purchase(planId)` takes `'weekly'` or `'annual'`, returns `Future<bool>`
- **Never block** prayer times or full Quran — always free
- AdMob ads hidden for Pro users

---

## App Startup (Two-Phase Boot)

1. **Pre-`runApp`** — Firebase init + Crashlytics error hooks → `runApp(ProviderScope(...))`
2. **Critical init** (`AppInitializer.runCritical()`) — Awaited while splash screen shows:
   - `Hive.initFlutter()` → open `quran_data` and `app_blocker` boxes
   - `PrayerTimesLocalDataSource().initialize()` (singleton via `factory`)
3. **Deferred init** (`AppInitializer.runDeferred()`) — UI already interactive:
   - `AndroidAlarmManager.initialize()`, timezone init, `NotificationService`, `RevenueCatService.configure()`, `HomeWidgetService.initialize()`

**Rule**: Don't move deferred services back into `main()`. Gate specific screens on the service if needed, not the whole app.

---

## State Management (Riverpod)

All providers in `features/<feature>/presentation/providers/`.

**Cross-cutting providers**: `themeProvider`, `isProProvider`, `authRepositoryProvider`, `authUserProvider`, `isSignedInProvider`, `arabicFontSizeProvider`, `translationVisibilityProvider`.

**Rules**:

- `ref.read` in `initState`/callbacks; `ref.watch` in `build`; `ref.listen` in `build` for reactions
- `locationProvider` is in `prayer_times_providers.dart`, NOT `location_notifier.dart`
- Capture futures once in `initState`, never inside `FutureBuilder` builder

---

## Offline-First Prayer Times Cache

**Contract**: The UI must never show "no data" when the cache holds any entry.

**3-tier cache resolver** (`resolveCachedPrayerTimes`):

1. Exact `dateKey` match
2. Same year+month, latest `dateKey`
3. Globally most-recently-cached entry

**Rule**: Always use `resolveCachedPrayerTimes` for user-facing reads. Direct `getCachedPrayerTimes` is only for exact-date checks (SWR validity, pre-warm dedup).

**Repository flow** (`getPrayerTimes`):

1. Fresh cache → return (SWR refresh if stale >1h)
2. Online → fetch from Aladhan, cache, return
3. Offline/failure → 3-tier fallback, queue retry
4. Empty cache → return `Failure`

After every read, `_maybePrewarmNextDay()` fetches day N+1 in background. `cacheUpdates` stream notifies the notifier of background writes.

---

## Prayer Notifications (Native Alarm Pipeline)

Fully native pipeline — the old `android_alarm_manager_plus` Dart-isolate path is dead (killed by OEM battery optimization).

```
NotificationService (Dart)
  → NativeAlarmService (Dart bridge)
  → PrayerAlarmChannel (Kotlin, MethodChannel "prayer_alarm")
  → AlarmManager.setExactAndAllowWhileIdle()
  → PrayerAlarmReceiver (Kotlin)
  → NotificationManagerCompat
```

**Notification Channels** (IDs must match `PrayerAlarmReceiver.kt`):

| ID                  | Sound            | Use                     |
| ------------------- | ---------------- | ----------------------- |
| `prayer_adhan`      | `adhan.mp3`      | Dhuhr/Asr/Maghrib/Isha  |
| `prayer_fajr_adhan` | `adhan_fajr.mp3` | Fajr only               |
| `prayer_silent`     | —                | Vibration-only reminder |

`adhanType` encoding: `0` standard, `1` Fajr, `2` silent.

**Never reuse a channel ID with different sound/importance** — Android caches channel settings per-install.

Legacy `android_alarm_manager_plus` init and receivers remain in place — do not remove.

---

## Authentication

Firebase Auth (email/password + Google Sign-In). Always a modal bottom sheet, never a standalone screen.

```dart
final signedIn = await showAuthSheet(context, ref.read(authRepositoryProvider));
```

**Auth gate**: Auth required only at purchase time (in `ProPaywallSheet._handleUpgrade`).

**Profile surface** in MoreScreen: `_ProfileCard` (signed-out CTA / signed-in avatar+badge), `_ProfileSheet` (manage subscription, restore purchases, sign out, delete account via mailto).

---

## Auth ↔ RevenueCat Link

Pro entitlement bound to Firebase uid. Three integration points:

1. **Cold start** — `RevenueCatService.configure()` passes `currentUser?.uid` as `appUserID`
2. **In-session** — `RevenueCatAuthLinkService` listens to `userStream`, calls `logIn`/`logOut`
3. **Purchase-time guard** — `_ensureLinkedToCurrentFirebaseUser()` before fetching offerings

---

## Hive Adapters (Hand-Written)

`hive_generator` was removed (analyzer conflict). Adapters are hand-written at the bottom of each model file:

| File                             | typeId | Fields |
| -------------------------------- | ------ | ------ |
| `cached_prayer_times_model.dart` | 0      | 13     |
| `prayer_settings_model.dart`     | 1      | 5      |
| `location_data_model.dart`       | 2      | 5      |

**Rules**:

- Wire format is load-bearing — keep `writeByte` markers byte-identical
- Never reuse a `typeId`
- To add a field: append as next-highest field number, use `fields[N] as T? ?? defaultValue` in read
- Do not reintroduce `hive_generator` or `part 'X.g.dart'`

---

## SQLite Database (`muslim_companion.db`)

Singleton `DatabaseHelper` in `core/database/`.

| Table       | Purpose                                       |
| ----------- | --------------------------------------------- |
| `surahs`    | 114 chapters                                  |
| `ayahs`     | 6236 verses (Arabic + English)                |
| `ayahs_fts` | FTS5 virtual table (auto-synced via triggers) |
| `bookmarks` | User bookmarks                                |
| `last_read` | Single-row last reading position              |

---

## APIs

| API                        | Base URL                       | Cache               |
| -------------------------- | ------------------------------ | ------------------- |
| **Aladhan** (Prayer Times) | `https://api.aladhan.com/v1`   | Hive, 30 days       |
| **Al-Quran Cloud** (Quran) | `https://api.alquran.cloud/v1` | SQLite (seed once)  |
| **sunnah.com** (Hadith)    | `https://api.sunnah.com/v1`    | Not yet implemented |

---

## MethodChannels

| Channel                               | Purpose                                                  |
| ------------------------------------- | -------------------------------------------------------- |
| `com.mdnahid.prayerlock/app_blocker`  | App blocker + special permissions (Usage Stats, Overlay) |
| `com.mdnahid.prayerlock/prayer_alarm` | Native alarm scheduling, battery optimization            |

---

## Theme System

Dark-first design. All widgets use `Theme.of(context).colorScheme` — no hardcoded colors.

- **Dark** ("Midnight Oasis") — bg `#0D1520`, primary emerald `#10B981`
- **Light** ("Ivory Sanctuary") — bg `#F5F2EB`, primary `#15803D`

Theme persisted via SharedPreferences. Use `Theme.of(context).brightness == Brightness.dark` for theme-conditional behavior.

---

## Error Handling

Pattern: `Future<Either<Failure, T>>` with remote → local fallback.

Failure types: `ServerFailure`, `NetworkFailure`, `CacheFailure`, `DatabaseFailure`, `PermissionFailure`, `UnknownFailure`.

---

## App Blocker (Pro, Android-Only)

1. User selects apps to block in More → App Blocker
2. Foreground service polls via `UsageStatsManager` during prayer windows
3. Blocked app detected → `SYSTEM_ALERT_WINDOW` overlay with "I have prayed" toggle
4. Overlay must be impossible to dismiss without the toggle — provide emergency exit (long-press 5s)

**Permissions**: `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`. Requested via native MethodChannel, not `permission_handler`. Hide UI entirely on iOS.

---

## Permission Bootstrap

`MainScreen.initState` → `addPostFrameCallback`:

1. Request notification + location permissions
2. On Android: check Usage Stats + Overlay permissions
3. If missing → show `_SpecialPermissionsSheet`
4. `WidgetsBindingObserver` re-checks on resume only when `_openedSpecialSettings == true`

---

## Platform Config

- **Android**: minSdk 26, targetSdk 34
- **Signing**: `android/key.properties` + `android/upload-keystore.jks` (both gitignored)
- **Firebase**: Core + Crashlytics only (no Firestore). Disabled in debug mode.

---

## Brand Assets

Launcher icons are pre-sized and committed directly — `flutter_launcher_icons` is not used.

- `assets/android/` — dark launcher icons + `play_store_512.png`
- `assets/ios/` — iOS AppIcon images
- `assets/light/` — light-mode variants for `BrandLogo`

`BrandLogo` picks dark/light variant based on `Theme.of(context).brightness`.

---

## Lint Rules

- `prefer_single_quotes` — single quotes for all strings
- `require_trailing_commas` — required
- `avoid_print` — use `AppLogger`
- `always_declare_return_types`
- `prefer_const_constructors`
- `always_use_package_imports` — never relative imports

---

## Logging

```dart
import 'package:prayer_lock/core/utils/logger.dart';

AppLogger.debug('message');
AppLogger.info('message');
AppLogger.warning('message');
AppLogger.error('message', error, stackTrace);
```

---

## Deprecation Note

Use `color.withValues(alpha: x)` — **not** `color.withOpacity(x)` (deprecated in Flutter 3.27+).

---

## Critical Rules

1. **Prayer notifications must be reliable** — use native alarm pipeline only. Test on Xiaomi, Infinix, OPPO.
2. **Quranic text** — triple-check accuracy, handle Arabic with utmost respect.
3. **Offline-first** — most features must work without internet. Use `resolveCachedPrayerTimes` for fallback.
4. **Privacy** — location for prayer times only. App Blocker data never leaves device.
5. **Performance** — cold start <2s, 60 FPS, memory <150 MB, APK <50 MB.
6. **Pro gating** — always check `isProProvider`. Never block prayer times or full Quran.
7. **AdMob** — no ads on Quran reading, prayer time screen, or active prayer notification.
8. **App Blocker permissions** — `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` are Play Store–reviewed sensitive permissions. Never request silently.
