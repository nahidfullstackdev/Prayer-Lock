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
- `SubscriptionRepository.purchase(String planId)` takes `'weekly'` or `'annual'` — matched to the RevenueCat current offering's `PackageType` (`current.weekly` / `current.annual`); falls back to `availablePackages.first` when neither is configured
- Pricing surfaced in the paywall: **Weekly $0.99/wk** and **Yearly $14.99/yr** with a **3-day free trial** (≈ $1.25/m). Yearly is the default selection. Prices are hardcoded in `_PlanCard` / `_billingNote` until `Purchases.getOfferings()` price strings are wired in
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

# Code generation (Riverpod only — Hive adapters are hand-written, see "Hive Adapters" below)
# Always use the flag to avoid conflicts
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
│   ├── startup/      # AppInitializer (two-phase critical/deferred boot)
│   ├── theme/        # AppTheme (dark/light ThemeData) + ThemeNotifier (Riverpod)
│   ├── utils/        # AppLogger
│   └── widgets/      # Cross-feature widgets (BrandLogo, AdhanTestWidget)
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
| **Notifications** | ✅     | ✅   | ✅ `notification_service.dart` (providers) + `native_alarm_service.dart` (data) + `notification_settings_sheet.dart` (widget) | Free                        |
| **Qibla**         | ✅     | ✅   | ✅ `qibla_compass_sheet.dart` (modal sheet, no dedicated screen)                  | Free                        |
| **Dua & Dhikr**   | ✅     | ✅   | ✅ `duadhikr_screen.dart`, `dua_detail_screen.dart`, 3 providers, `dua_card.dart` | Free (limited) / Pro (full) |
| **Hadith**        | ✅     | ✅   | ✅ `hadith_screen.dart`, `hadith_list_screen.dart`, 4 providers, `hadith_card.dart` | Free (limited) / Pro (full) |
| **Onboarding**    | —      | —    | ✅ `onboarding_screen.dart` + `onboarding_provider.dart` (presentation only)     | —                           |
| **Auth**          | ✅     | ✅   | ✅ `auth_screen.dart` (bottom sheet only — no standalone screen)                  | —                           |
| **AdMob Ads**     | —      | —    | ⏳ Not started                                                                    | Free only                   |
| **App Blocker**   | ✅     | ✅   | ✅ `app_blocker_screen.dart` + `AppBlockerNotifier`                               | Pro                         |
| **Home Widgets**  | —      | ✅   | ⏳ Data-only: `HomeWidgetService` + native `PrayerWidgetProvider.kt` + `layout/prayer_widget.xml` — no in-app management UI yet | Pro                         |
| **Subscription**  | ✅     | ✅   | ✅ `pro_paywall_sheet.dart`; no dedicated screen                                  | —                           |
| **Calendar**      | ⏳     | ⏳   | ✅ `islamic_calendar_screen.dart`, `ramadan_tracker_screen.dart` (presentation only — `data/` & `domain/` folders exist but empty) | Free                        |

`main_screen.dart` imports `HadithScreen` and `DuaDhikrScreen` from their feature folders. `MoreScreen` remains inline in `main_screen.dart`. `selectedTabProvider` (bottom nav index) is defined in `main.dart`.

**App startup — two-phase boot** (for cold-start performance `main` only awaits Firebase):

1. **Pre-`runApp`** — the only thing blocking the first frame. Firebase has to come first so Crashlytics hooks capture errors from frame 0:
   - `Firebase.initializeApp()` + `FlutterError.onError` / `PlatformDispatcher.instance.onError` → Crashlytics
   - `setCrashlyticsCollectionEnabled(!kDebugMode)`
   - `runApp(ProviderScope(...))`
2. **Critical init** — `AppInitializer.runCritical()` in [lib/core/startup/app_initializer.dart](lib/core/startup/app_initializer.dart). Awaited inside `_AppHome.initState()` while `_SplashScreen` is on screen. Runs in parallel after `Hive.initFlutter()`:
   - `Hive.openBox('quran_data')`
   - `Hive.openBox('app_blocker')`
   - `PrayerTimesLocalDataSource().initialize()` (registers its own Hive adapters + opens prayer boxes). The data source is a **singleton via `factory PrayerTimesLocalDataSource()`** so the Riverpod provider receives the same instance that AppInitializer just initialised — both must agree, otherwise the `late final` boxes would only be assigned on one side. `initialize()` is idempotent (shared `_initFuture`).
3. **Deferred init** — `AppInitializer.runDeferred()` fired via `unawaited(...)` once critical completes. The UI is already interactive. Each task is guarded so one failure can't abort the rest:
   - `AndroidAlarmManager.initialize()` (Android only)
   - `tzdata.initializeTimeZones()` + `FlutterTimezone.getLocalTimezone()` → `tz.setLocalLocation`
   - `NotificationService().initialize()` (creates notification channels)
   - `RevenueCatService.configure()` (network round-trip; `isProProvider` treats the `unknown` seed as free until the first real `CustomerInfo` arrives)
   - `HomeWidgetService.initialize()`

`_AppHome` is a `ConsumerStatefulWidget`. Its `initState` captures the critical `Future` once; the `FutureBuilder` in `build` shows `_SplashScreen` until it resolves, then routes via `onboardingCompletedProvider` — completed → `MainScreen`, not completed → `OnboardingScreen`.

Rules:
- Don't move services out of `runDeferred` back into `main()` — that undoes the cold-start work. If a deferred service needs to be ready before a specific screen renders, gate that screen on the service, not the whole app.
- `subscriptionSyncServiceProvider` is activated inside `MuslimCompanionApp.build` before RevenueCat finishes configuring; it only subscribes to streams, so this is intentional and safe. The first real `CustomerInfo` emission pushes through once configure lands.

## Offline-First Prayer Times Cache

`PrayerTimesRepositoryImpl` and `PrayerTimesLocalDataSource` enforce a contract: **the UI must never show a "no data" state when the cache holds any entry.** Treat this as load-bearing — it is what makes the app usable offline at midnight, on a flaky train, or after the user has opened it once and then gone airplane-mode.

**3-tier cache resolver** — `PrayerTimesLocalDataSource.resolveCachedPrayerTimes({dateKey, date})` walks:

1. Exact `dateKey` match
2. Same year+month, latest `dateKey`
3. Globally most-recently-cached entry (`getLatestCache()`)

Returns null only when the box is completely empty. **Never call `getCachedPrayerTimes(dateKey)` alone for a user-facing read** — use the resolver so fallback kicks in. Direct `getCachedPrayerTimes` is reserved for "is this *exact* date already cached?" checks (SWR validity, pre-warm dedup).

**Repository decision flow** in `PrayerTimesRepositoryImpl.getPrayerTimes`:

1. Exact cache fresh & valid → return now. If older than soft TTL (1h), fire silent stale-while-revalidate refresh.
2. Online → hit Aladhan. On success cache and return.
3. Offline OR network failed → resolve via the 3-tier fallback. If we were online (transient failure), queue a background retry for the requested dateKey.
4. Cache truly empty → only now return `Failure`.

After every successful read, `_maybePrewarmNextDay()` fires — so opening the app at any point on day N also fetches day N+1 in the background. The next calendar rollover finds the cache already warm even if the user is offline at 12:01am.

**Background-fetch dedup** — `_scheduleBackgroundRefresh()` is the single choke-point. SWR, pre-warm, and post-failure retries all funnel through it; a `_inFlightRefreshes` set keyed by `dateKey` prevents duplicate concurrent fetches.

**`cacheUpdates` Stream** — `PrayerTimesRepository.cacheUpdates` emits a `dateKey` after every successful background write. `PrayerTimesNotifier._onCacheUpdate` filters to today's key and calls `loadPrayerTimes(silent: true)` — no spinner flash, just fresh data. Tomorrow's pre-warm emit is harmless (filtered out).

Rules when touching this code:
- Reads from `PrayerTimesLocalDataSource` are **synchronous** (the boxes are `late final` after `initialize()`). Don't add `await` on reads — the analyzer will warn.
- Writes (`cachePrayerTimes`, `saveSettings`, `saveLocation`) stay async because Hive's persistence is async.
- The dateKey returned by the fallback may not match the requested date. Caller should accept that the entity's `date` reflects when the cached times were originally for, not "today". This is the deliberate trade-off vs. a blank screen.

## Permission Bootstrap

`MainScreen` is a `ConsumerStatefulWidget` (not `ConsumerWidget`) and handles runtime permission requests once on first frame via `addPostFrameCallback`. The flow:

1. Request `Permission.notification` + `Permission.locationWhenInUse` together (system dialogs; no-op if already granted)
2. On Android: query `AppBlockerRepository.hasUsageStatsPermission()` and `hasOverlayPermission()` via native MethodChannel
3. If either special permission is missing, show `_SpecialPermissionsSheet` — a bottom sheet explaining each missing permission with "Grant" buttons that open the correct Settings page
4. `WidgetsBindingObserver` is registered; on `AppLifecycleState.resumed`, re-checks special permissions **only** when `_openedSpecialSettings == true` (set when a "Grant" button is tapped), preventing repeated prompts after ordinary background/foreground cycles

For Usage Stats and Overlay: the `AppBlockerNativeDataSource` MethodChannel (`com.mdnahid.prayerlock/app_blocker`) handles both checking and opening the correct Settings intent — do not use `permission_handler` for these two.

**Android MethodChannels in this app:**

- `com.mdnahid.prayerlock/app_blocker` — registered by `AppBlockerChannel` in `MainActivity.configureFlutterEngine`
- `com.mdnahid.prayerlock/prayer_alarm` — registered by `PrayerAlarmChannel` in `MainActivity.configureFlutterEngine` (see *Prayer Notifications* below)

## Firebase

Firebase Core + Crashlytics are integrated (`firebase_options.dart` generated by `flutterfire configure`).

- Crashlytics is **disabled in debug mode** (`kDebugMode` check in `main.dart`); collects crash data in release only
- Both `FlutterError.onError` and `PlatformDispatcher.instance.onError` are routed to Crashlytics
- Firebase Auth is the only Firebase product in active use — Firestore not yet added
- Android: `google-services` plugin must be **≥ 4.4.1** (currently `4.4.2` in `settings.gradle.kts`) — Crashlytics plugin v3 hard-requires this
- Proguard: `android/app/proguard-rules.pro` has `-dontwarn` rules for Play Core split-install stubs

## Prayer Notifications (Native Alarm Pipeline)

The previous `android_alarm_manager_plus` → Dart-isolate → `FlutterLocalNotificationsPlugin.show()` path was killed by OEM battery optimization on Xiaomi MIUI, Infinix HiOS, OPPO ColorOS, etc. It has been replaced by a fully native pipeline:

```
NotificationService (Dart)
  → NativeAlarmService (Dart bridge)
  → PrayerAlarmChannel (Kotlin, MethodChannel "com.mdnahid.prayerlock/prayer_alarm")
  → AlarmManager.setExactAndAllowWhileIdle()
  → PrayerAlarmReceiver (Kotlin BroadcastReceiver)
  → NotificationManagerCompat
```

Key files:

- [lib/features/prayer_times/presentation/providers/notification_service.dart](lib/features/prayer_times/presentation/providers/notification_service.dart) — `NotificationRepository` impl; creates channels, translates `AdhanType` + `PrayerName` to the integer encoding the native layer expects
- [lib/features/prayer_times/data/services/native_alarm_service.dart](lib/features/prayer_times/data/services/native_alarm_service.dart) — MethodChannel wrapper; Android-only (no-ops elsewhere)
- [android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerAlarmChannel.kt](android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerAlarmChannel.kt) — scheduling + battery-optimization helpers
- [android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerAlarmReceiver.kt](android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerAlarmReceiver.kt) — fires notifications
- [android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerBootReceiver.kt](android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerBootReceiver.kt) — reschedules alarms after `BOOT_COMPLETED` / `MY_PACKAGE_REPLACED` / `QUICKBOOT_POWERON`

**MethodChannel `com.mdnahid.prayerlock/prayer_alarm` methods:**

- `scheduleExactPrayerAlarm(id, timeMs, prayerName, arabicName, adhanType, minutesBefore)` — `id` is `PrayerName.index` (0–4)
- `cancelPrayerAlarm(id)` / `cancelAllPrayerAlarms()`
- `isBatteryOptimizationIgnored()` → `bool`
- `openBatteryOptimizationSettings()` — opens `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- `openAutoStartSettings(manufacturer)` — opens OEM-specific auto-start screen (xiaomi/redmi/poco/oppo/realme/oneplus/vivo/huawei/honor/samsung/tecno/infinix/itel/asus/meizu/lenovo)

Native persistence: alarm metadata is stored in SharedPreferences file `prayer_alarm_prefs` under keys `alarm_<id>_time_ms` / `_name` / `_arabic` / `_adhan_type` / `_minutes_before` — this lets `PrayerBootReceiver` reconstruct PendingIntents after reboot without a Flutter engine.

**Notification channels** (created in `NotificationService._createNotificationChannels`; IDs must match `PrayerAlarmReceiver.kt` constants — channel settings are immutable after first creation):

| ID                   | Sound (`res/raw/`)     | Use                                |
| -------------------- | ---------------------- | ---------------------------------- |
| `prayer_adhan`       | `adhan.mp3`            | Dhuhr / Asr / Maghrib / Isha       |
| `prayer_fajr_adhan`  | `adhan_fajr.mp3`       | Fajr only                          |
| `prayer_silent`      | —                      | Vibration-only reminder            |

`adhanType` encoding on the wire: `0` standard, `1` Fajr, `2` silent. Never reuse a channel ID with different sound/importance — Android caches channel settings per-install; deliver a new ID instead.

Small-icon asset: [android/app/src/main/res/drawable/ic_prayer_notify.xml](android/app/src/main/res/drawable/ic_prayer_notify.xml).

Legacy `android_alarm_manager_plus` is still initialized in `main.dart` and its manifest receivers remain declared — leave them in place; other code paths (e.g. future reschedulers) may still depend on the plugin, and removing the initialization will break those.

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
2. User selects Weekly or Yearly plan card (Yearly is default; carries the 3-day free trial badge)
3. On "Unlock Pro" tap, calls `repo.purchase(planId)` where `planId` is `'weekly'` or `'annual'`
4. `RevenueCatService.purchase()` fetches the current offering, picks `current.weekly` / `current.annual`, then calls `Purchases.purchase(PurchaseParams.package(pkg))`

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

## Hive Adapters (Hand-Written — Do Not Regenerate)

`hive_generator` was removed from `dev_dependencies` because it caps `analyzer` at 6.11.0, which conflicts with `source_gen` / Dart macros on macOS (iOS toolchain). Hive itself (`hive: ^2.2.3`, `hive_flutter: ^1.1.0`) is still used at runtime — only the codegen step is gone.

The three model files in `features/prayer_times/data/models/` each include a hand-written `TypeAdapter<T>` at the bottom of the same file:

| File                              | typeId | Field count | Notes                                                                                  |
| --------------------------------- | ------ | ----------- | -------------------------------------------------------------------------------------- |
| `cached_prayer_times_model.dart`  | 0      | 13          | Aladhan response cache, 30-day retention                                               |
| `prayer_settings_model.dart`      | 1      | 5           | Field 4 (`adhanTypeIndex`) was added later — read path falls back to `0` if absent    |
| `location_data_model.dart`        | 2      | 5           | GPS cache                                                                              |

**Rules when touching these files:**

- **Wire format is load-bearing.** The `writeByte` field markers, `numOfFields` header, and per-field types must stay byte-identical to the previously generated adapters or existing user installs will fail to decode their cached data.
- **Never reuse a `typeId`** for a different model — Hive caches type registrations on disk.
- **To add a field:** append it as the next-highest field number in `write()`, increase `writeByte(N)`, and in `read()` use `fields[N] as T? ?? defaultValue` so old records (which won't have the field) still decode. The existing `adhanTypeIndex` is the worked example.
- **Do not reintroduce `hive_generator`** or `part 'X.g.dart'` directives — that brings the macOS analyzer conflict back. If a fourth Hive model is needed, hand-write the adapter the same way.
- Adapter registration in `prayer_times_local_data_source.dart` (`Hive.registerAdapter(...)`) and `Hive.openBox` calls in `app_initializer.dart` are unchanged — adapter class names and typeIds were preserved.

The Quran and App Blocker datasources use untyped `Box<dynamic>` and never needed adapters.

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

## Brand Assets

Pre-sized launcher artwork is committed directly into the native projects — `flutter_launcher_icons` is **not** used (it can't emit both dark and light variants). The Flutter-side source PNGs live in three folders registered under `flutter.assets` in `pubspec.yaml`:

- **`assets/android/`** — dark launcher icons at every density (`ic_launcher_{mdpi_48,hdpi_72,xhdpi_96,xxhdpi_144,xxxhdpi_192}.png`) + `play_store_512.png`. These map 1:1 into:
  - `android/app/src/main/res/mipmap-*/ic_launcher.png` (legacy square)
  - `android/app/src/main/res/drawable-*/ic_launcher_foreground.png` (adaptive foreground — no inset, source already has launcher-safe padding)
  - Adaptive background color `#E8E2CF` lives in `values/colors.xml`; the adaptive XML is `mipmap-anydpi-v26/ic_launcher.xml`
- **`assets/ios/`** — iOS AppIcon images by pixel size (`AppIcon_{20,29,40,58,60,80,87,120,152,167,180,1024}.png`). Copied verbatim into `ios/Runner/Assets.xcassets/AppIcon.appiconset/` and referenced by `Contents.json` using modern slots only (pre-iOS 7 legacy 50/57/72/76@1x were dropped)
- **`assets/light/`** — light-mode variants (`AppIcon_{192,512,1024}_light.png`) used by `BrandLogo` only

When the artwork changes, re-copy the density variants into their native folders manually — there is no generator step.

**In-app logo — `BrandLogo`** ([lib/core/widgets/brand_logo.dart](lib/core/widgets/brand_logo.dart)):
- Picks `assets/android/play_store_512.png` in dark mode and `assets/light/AppIcon_512_light.png` in light mode via `Theme.of(context).brightness`
- Used by `_SplashScreen` in `main.dart` (128 px, background also flips by theme — `#0D1520` dark / `#F5F2EB` light) and by `_GlowLogo` in `onboarding_screen.dart` (110 px inside a radial-gradient glow)

Note: the **native** Android launch screen (`drawable/launch_background.xml`) still uses the white default — `flutter_native_splash` is not yet integrated.

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

- Package: `home_widget` (in `pubspec.yaml`). Dart bridge: [lib/features/home_widget/data/services/home_widget_service.dart](lib/features/home_widget/data/services/home_widget_service.dart). Native provider: `android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerWidgetProvider.kt` (registered in `AndroidManifest.xml`)
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
- **Permissions (free):** `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `POST_NOTIFICATIONS`, `VIBRATE`, `WAKE_LOCK`, `RECEIVE_BOOT_COMPLETED`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
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
| `home_widget`                 | Home screen widgets (Pro) — bridges Dart ↔ Android AppWidget                   |
| `flutter_svg`                 | SVG asset rendering                                                             |
| `cached_network_image`        | Network image caching                                                          |
| `connectivity_plus`           | Wrapped by `lib/core/network/connectivity_service.dart` — `isOnline()` one-shot + `onStatusChange` distinct stream. Repo uses it to gate network calls; `isOnlineProvider` drives the auto-refresh-on-reconnect listener in `prayer_times_providers.dart`. Note: reports *interface* state, not host reachability — captive portals still report online, hence the repository's stale-cache fallback on `DioException`. |

## Critical Notes

1. **Prayer Notifications**: MUST be reliable. Use the native alarm pipeline (see *Prayer Notifications* section) — never revert to the `android_alarm_manager_plus` Dart-isolate path, which is killed by OEM battery optimization. Test on Xiaomi, Infinix, and OPPO in addition to stock Android.
2. **Quranic Text**: Triple-check accuracy. Handle Arabic text with utmost respect.
3. **Offline**: Most features must work without internet. SQLite is primary for Quran/Hadith; Hive for settings/cache. Prayer times follow an explicit offline-first contract — see *Offline-First Prayer Times Cache* section. Use `resolveCachedPrayerTimes` for fallback, never `getCachedPrayerTimes` alone for user-facing reads.
4. **Privacy**: Location used only for prayer times. App Blocker usage data never leaves the device.
5. **Performance**: Cold start < 2s, 60 FPS, memory < 150 MB, APK < 50 MB.
6. **Pro Gating**: Always check `isProProvider` before rendering locked content. Never hard-block prayer times or full Quran.
7. **App Blocker UX**: The overlay must be impossible to dismiss without the "I prayed" toggle — always provide an emergency exit (long-press 5s or settings back-door).
8. **AdMob Policy**: No ads on sacred content screens (Quran reading, active prayer). Use ad content filtering to avoid inappropriate ads on Islamic content.
9. **App Blocker Permissions**: `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` are Play Store–reviewed sensitive permissions. The initial prompt lives in `MainScreen._SpecialPermissionsSheet`; the in-context prompts live in `AppBlockerScreen` permission banners. Do not request them silently.

---

**Remember**: This is a spiritual tool. Reliability > features. Respect > speed. Build it right.
