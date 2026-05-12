# Prayer Lock — Release Setup Guide

This is the runbook for getting Prayer Lock from source to the App Store and Google Play. The Android side ships from any platform. The iOS side requires a Mac with Xcode for the final mile — the project was developed on Windows, so this document focuses on the macOS-only steps that must be completed before the first iOS build.

---

## Contents

1. [Prerequisites](#1-prerequisites)
2. [First-time Mac setup](#2-first-time-mac-setup)
3. [Audio file inventory](#3-audio-file-inventory)
4. [Generate the iOS CAF notification sounds](#4-generate-the-ios-caf-notification-sounds)
5. [Wire iOS files into the Runner target in Xcode](#5-wire-ios-files-into-the-runner-target-in-xcode)
6. [Signing & Capabilities](#6-signing--capabilities)
7. [RevenueCat production setup](#7-revenuecat-production-setup)
8. [App Store Connect and IAP products](#8-app-store-connect-and-iap-products)
9. [Fill in the iOS App Store ID](#9-fill-in-the-ios-app-store-id)
10. [Build & test on a real iPhone](#10-build--test-on-a-real-iphone)
11. [TestFlight upload](#11-testflight-upload)
12. [App Store submission checklist](#12-app-store-submission-checklist)
13. [Android release notes](#13-android-release-notes)
14. [Deferred — iOS Home Widget (future work)](#14-deferred--ios-home-widget-future-work)
15. [Features that are Android-only by platform](#15-features-that-are-android-only-by-platform)

---

## 1. Prerequisites

- macOS 13+ with Xcode 15 or newer (App Store Connect requires Xcode 15 to upload)
- Apple Developer Program enrollment (paid, $99/yr) — required for signing, TestFlight, and submission
- CocoaPods (`sudo gem install cocoapods` if missing)
- Flutter SDK matching `pubspec.yaml` constraints
- RevenueCat account with the production iOS API key (prefix `appl_...`)

---

## 2. First-time Mac setup

```bash
# Clone and fetch Dart dependencies
git clone <repo-url>
cd prayer_lock
flutter pub get

# Resolve and download CocoaPods dependencies (must be run on macOS)
cd ios
pod install --repo-update
cd ..

# Open the iOS workspace (NOT the .xcodeproj)
open ios/Runner.xcworkspace
```

The `pod install` step generates `ios/Podfile.lock` and creates the `Pods/` directory. Both are gitignored — every Mac contributor runs `pod install` once after pulling the repo.

If `pod install` fails with deployment-target errors, confirm the `Podfile` still has `platform :ios, '13.0'` and the post-install hook in the project root sets `IPHONEOS_DEPLOYMENT_TARGET = '13.0'` for every pod.

---

## 3. Audio file inventory

| File | Purpose |
| --- | --- |
| `assets/sounds/adhan.mp3` | Full-length Adhan, played in-app on iOS when foreground |
| `assets/sounds/adhan_fajr.mp3` | Full-length Fajr Adhan, played in-app on iOS when foreground |
| `assets/sounds/adhan_short.mp3` | <=30s Adhan source for the iOS notification sound |
| `assets/sounds/adhan_short_fajr.mp3` | <=30s Fajr Adhan source for the iOS notification |
| `android/app/src/main/res/raw/adhan.mp3` | Android notification channel sound (`prayer_adhan`) |
| `android/app/src/main/res/raw/adhan_fajr.mp3` | Android notification channel sound (`prayer_fajr_adhan`) |

If you replace any audio, keep file names identical or the Android channel sound silently falls back to default — notification channels are immutable per-install on Android (uninstall + reinstall to reset).

---

## 4. Generate the iOS CAF notification sounds

iOS hard-caps notification sounds at ~30 seconds and requires `.caf` or `.aiff` format (Flutter assets aren't accessible to the system notification subsystem). Convert the short MP3s to CAF in place under `ios/Runner/`:

```bash
afconvert assets/sounds/adhan_short.mp3      ios/Runner/adhan.caf      -d ima4 -f caff -v
afconvert assets/sounds/adhan_short_fajr.mp3 ios/Runner/adhan_fajr.caf -d ima4 -f caff -v
```

`afconvert` ships with macOS. The `-d ima4 -f caff` flags produce IMA4-encoded CAF, which Apple recommends for notification sounds.

Until these files exist and are bundled (next section), iOS scheduling still works but the notification plays the system default sound. The full-length in-app playback works regardless when the app is in the foreground at fire time.

iOS architecture note — what the user actually hears, and why:

- **Notification fires while app is backgrounded/killed:** the system plays `adhan.caf` / `adhan_fajr.caf` for up to 30s. Dart code does not run.
- **Notification fires while app is foreground:** the notification still plays the .caf, and `AdhanAudioService` plays the full-length `.mp3` via `audioplayers` (configured in [adhan_audio_service.dart](lib/features/prayer_times/data/services/adhan_audio_service.dart) with `AVAudioSessionCategory.playback` + `mixWithOthers`).
- **In-app Adhan Timer doesn't survive backgrounding:** iOS suspends Dart isolates shortly after the app goes background. The `_scheduleIosAdhanTimer` in [notification_service.dart](lib/features/prayer_times/presentation/providers/notification_service.dart) only fires if the app is alive at prayer time. This is the standard iOS prayer-app pattern.

This is intentional and matches the user-confirmed approach (truncated adhan in the notification, full adhan only when foreground).

---

## 5. Wire iOS files into the Runner target in Xcode

Open `ios/Runner.xcworkspace` (the `.xcworkspace`, NOT `.xcodeproj`).

### 5a. Bundle the CAF sounds

1. In the Project Navigator (left sidebar), drag `adhan.caf` and `adhan_fajr.caf` from `ios/Runner/` into the **Runner** group.
2. In the dialog, tick **Copy items if needed** = OFF (they're already in `ios/Runner/`), tick **Add to targets: Runner**, click Finish.
3. Select the **Runner** target -> **Build Phases** -> **Copy Bundle Resources**. Both `adhan.caf` and `adhan_fajr.caf` must appear.

### 5b. Bundle PrivacyInfo.xcprivacy

Apple has required a privacy manifest for every submission since 1 May 2024. The file is already created at `ios/Runner/PrivacyInfo.xcprivacy`.

1. Drag `PrivacyInfo.xcprivacy` from `ios/Runner/` into the **Runner** group in Xcode.
2. Tick **Add to targets: Runner**, click Finish.
3. Verify it appears in **Runner** target -> **Build Phases** -> **Copy Bundle Resources**.

### 5c. Verify GoogleService-Info.plist target membership

1. Click `GoogleService-Info.plist` in the Project Navigator.
2. In the right sidebar (File Inspector), under **Target Membership**, confirm **Runner** is ticked.
3. Confirm the file appears in **Build Phases** -> **Copy Bundle Resources**.

---

## 6. Signing & Capabilities

Select the **Runner** target -> **Signing & Capabilities** tab.

### 6a. Signing

1. Tick **Automatically manage signing**.
2. Select your Apple Developer **Team**.
3. Confirm **Bundle Identifier** is `com.mdnahid.prayerlock` (matches `project.pbxproj` and `GoogleService-Info.plist`).
4. Xcode auto-generates the provisioning profile. Wait for the green checkmark.

### 6b. Capabilities

Required capability for this project:

- **Background Modes** -> **Audio, AirPlay, and Picture in Picture** (already declared in `Info.plist` as `UIBackgroundModes`/`audio`; this is the Xcode-side counterpart and is required for App Store review).

If **Background Modes** is not yet present, click **+ Capability** -> **Background Modes** -> tick **Audio, AirPlay, and Picture in Picture**.

No other capabilities are needed for the current feature set (no Push Notifications, no Sign in with Apple, no Family Controls, no App Groups — the iOS Home Widget is deferred).

---

## 7. RevenueCat production setup

The repo currently ships with a development RevenueCat API key at [revenuecat_service.dart:29](lib/features/subscription/data/services/revenuecat_service.dart#L29):

```dart
static const String _iosApiKey = 'test_YnSLhYtBinlzKfezdNwXLkeBlWl';
```

Sandbox/development keys will not work on the App Store. Before any TestFlight upload:

1. Log in to https://app.revenuecat.com
2. Create a project (or use the existing Prayer Lock project)
3. Add an iOS app with bundle ID `com.mdnahid.prayerlock`
4. Copy the iOS **Public SDK key** (prefix `appl_...`)
5. Replace `_iosApiKey` in [revenuecat_service.dart](lib/features/subscription/data/services/revenuecat_service.dart) with the production key

Alternative — keep the key out of source control:

```dart
static const String _iosApiKey =
    String.fromEnvironment('REVENUECAT_IOS_KEY', defaultValue: 'test_...');
```

Then build with `--dart-define=REVENUECAT_IOS_KEY=appl_...`. (Same for `REVENUECAT_ANDROID_KEY` if you want symmetry.)

---

## 8. App Store Connect and IAP products

1. Sign in to https://appstoreconnect.apple.com
2. **My Apps** -> **+** -> **New App**. Use bundle ID `com.mdnahid.prayerlock`. SKU can be anything stable (e.g. `prayer-lock-ios`).
3. Take note of the **Apple ID** (numeric) assigned to your app. This is what goes in `IOS_APP_STORE_ID` (see step 9).
4. Create In-App Purchase products matching the RevenueCat configuration (see [CLAUDE.md](CLAUDE.md) -> Monetisation Rules):
   - **Weekly subscription**, $0.99/wk, with a 3-day free trial (default-selected plan)
   - **Annual subscription**, $14.99/yr
5. Submit the IAP products for review with the first binary (you cannot test sandbox purchases until they're in "Ready to Submit" status).
6. In RevenueCat, link each App Store product to the corresponding RevenueCat package (`$rc_weekly`, `$rc_annual`) under the **Offerings** tab.

---

## 9. Fill in the iOS App Store ID

The Rate / Share buttons in MoreScreen need the App Store numeric ID. Until set, they show a "will be available after launch" SnackBar on iOS.

`_kIosAppStoreId` in [main_screen.dart](lib/main_screen.dart) reads from a `--dart-define`:

```dart
const String _kIosAppStoreId = String.fromEnvironment('IOS_APP_STORE_ID');
```

Once the App Store record exists (step 8), build with:

```bash
flutter build ipa --release --dart-define=IOS_APP_STORE_ID=1234567890
```

Replace `1234567890` with the numeric Apple ID from App Store Connect. No source change required.

---

## 10. Build & test on a real iPhone

```bash
# Plug in iPhone, trust this Mac on the device
flutter devices                          # confirm device shows up
flutter run -d <ios-device-id>           # debug install + run
```

Manual test checklist on a physical device:

- [ ] Cold start: location and notification permission prompts appear with the configured descriptions
- [ ] Prayer times calculate and display; offline mode (airplane mode) still shows cached times
- [ ] Schedule a near-term test prayer via the existing in-app test widget; verify the notification fires with adhan sound (<=30s)
- [ ] Qibla compass rotates with device orientation (motion permission)
- [ ] App Blocker screen shows the "iOS-unsupported" message and does not crash
- [ ] Home Screen Widget row is NOT visible in MoreScreen (intentionally hidden on iOS)
- [ ] Google Sign-In: account picker opens and sign-in completes
- [ ] Email/password sign-in works
- [ ] Subscription paywall opens; sandbox purchase completes (requires App Store sandbox tester account configured in App Store Connect -> Users and Access -> Sandbox)
- [ ] Crashlytics: trigger a release-mode test crash; confirm it appears in the Firebase console within ~5 min

The iOS Simulator does not play custom notification sounds reliably and does not honour the silent switch the same way as hardware — always test prayer notifications on a real device.

---

## 11. TestFlight upload

```bash
flutter build ipa --release --dart-define=IOS_APP_STORE_ID=<id>
```

The IPA is written to `build/ios/ipa/`. Upload via Xcode Organizer:

1. Open Xcode -> **Window** -> **Organizer** -> **Archives** tab
2. Alternatively, drag the `.ipa` into Transporter (download from Mac App Store)
3. Distribute App -> App Store Connect -> Upload
4. Wait for processing (~5-30 min). Watch for any "missing privacy manifest" or "non-exempt encryption" warnings — if both are configured (steps 5b and the existing `Info.plist`), you should see neither.
5. Once processed, the build appears in App Store Connect -> TestFlight -> iOS Builds. Add internal testers and invite them.

---

## 12. App Store submission checklist

- [ ] **App Privacy** section in App Store Connect filled out (matches `PrivacyInfo.xcprivacy`: crash data, coarse location, user ID, email, purchase history; none used for tracking)
- [ ] **App Tracking Transparency** prompt NOT shown (we don't track — confirmed by `NSPrivacyTracking=false`)
- [ ] Screenshots uploaded for required device sizes: 6.7" iPhone (1290x2796) and 12.9" iPad Pro (2048x2732). Other sizes are auto-scaled by Apple.
- [ ] App Preview videos (optional)
- [ ] App Description, Keywords, Support URL, Marketing URL filled
- [ ] **Demo account credentials** in App Information -> App Review Information (a Firebase Auth test account so reviewers can access Pro paywall)
- [ ] **Review Notes**: explain that App Blocker is Android-only by design (iOS sandbox), Home Widget is deferred for a future release. This pre-empts reviewer questions.
- [ ] Age rating questionnaire completed (no objectionable content, no user-generated content -> 4+)
- [ ] Content Rights: confirm you have rights to all audio (Adhan recordings) and Quran text used
- [ ] Price tier set; Pro subscription products attached to this app version
- [ ] **Export Compliance**: should auto-pass thanks to `ITSAppUsesNonExemptEncryption=false` in `Info.plist`

Submit for review. First-pass review usually takes 24-48h.

---

## 13. Android release notes

The Android pipeline is independent of the iOS steps above.

### Signing

`android/key.properties` and `android/upload-keystore.jks` are gitignored. Each release machine needs:

- `android/key.properties` with `storePassword`, `keyPassword`, `keyAlias`, `storeFile` lines
- `android/upload-keystore.jks` matching those credentials

Generate a new keystore (one-time) if needed:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Build commands

```bash
# Play Store bundle (preferred for upload)
flutter build appbundle --release

# Direct APK (sideload / testing)
flutter build apk --release
```

The `.aab` is written to `build/app/outputs/bundle/release/`.

### Permissions to call out in Play Console

- `PACKAGE_USAGE_STATS` and `SYSTEM_ALERT_WINDOW` are sensitive — provide a screen recording showing exactly when the App Blocker uses each.
- `SCHEDULE_EXACT_ALARM` and `USE_EXACT_ALARM` — declare that the app's core function is reliable Salah notifications at exact times.
- `RECEIVE_BOOT_COMPLETED` — needed to reschedule alarms after device reboot (otherwise users miss morning Fajr after an overnight restart).

---

## 14. Deferred — iOS Home Widget (future work)

The iOS Home Widget is not shipped in the current iOS release. The Dart side ([home_widget_service.dart](lib/features/home_widget/data/services/home_widget_service.dart)) already declares the App Group ID `group.com.mdnahid.prayerlock.widget` and writes shared data via the `home_widget` plugin. The "Add Widget" CTA is hidden on iOS in MoreScreen to avoid a dead button.

To add the iOS widget in a future release:

1. In Xcode, **File -> New -> Target -> Widget Extension**. Name it `PrayerWidget`. Bundle ID auto-derives to `com.mdnahid.prayerlock.PrayerWidget`.
2. Add **App Groups** capability to both the Runner target and the PrayerWidget target. Use the same group ID: `group.com.mdnahid.prayerlock.widget`.
3. Register the App Group ID in the Apple Developer portal under **Identifiers -> App Groups**.
4. In the widget extension's `TimelineProvider`, read shared data via `UserDefaults(suiteName: "group.com.mdnahid.prayerlock.widget")`. Keys written by the Dart side (see [home_widget_service.dart](lib/features/home_widget/data/services/home_widget_service.dart)):
   - `next_prayer_name`, `next_prayer_arabic`, `next_prayer_time`, `next_prayer_countdown`, `last_updated_ms`
5. Build a SwiftUI view that renders the same data the Android widget shows. Refer to `android/app/src/main/kotlin/com/mdnahid/prayerlock/PrayerWidgetProvider.kt` for the layout intent.
6. Remove the iOS gate around the "Home Screen Widget" CTA in [main_screen.dart](lib/main_screen.dart).
7. Update the iOS `PrivacyInfo.xcprivacy` if the widget reads any new APIs.

---

## 15. Features that are Android-only by platform

These are intentionally not available on iOS because the platform forbids them — not a missing implementation:

- **App Blocker** — iOS sandbox prohibits an app from drawing system overlays over other apps, and there's no Accessibility Service equivalent to detect the foreground package. Family Controls (Screen Time API, iOS 16+) is parental-consent-only and system-wide, not a fit. The App Blocker screen in MoreScreen shows an "iOS-unsupported" message and does not crash.
- **Battery Optimization settings** — iOS manages background power globally; there are no per-app exemption settings to expose.
- **OEM Auto-Start settings** — Xiaomi/OPPO/Vivo/etc. specific intents do not apply to iOS.
- **Boot Receiver** — iOS persists scheduled local notifications across device reboot natively; no boot-time rescheduling is needed.

Reviewers occasionally flag App Blocker as a missing feature on iOS — the App Store Connect review notes (step 12) should explicitly mention this is by design.
