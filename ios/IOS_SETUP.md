# iOS setup — finishing steps (run on a Mac)

The Dart/plist/project changes have been made from Windows. The steps
below require macOS + Xcode + CocoaPods and must be run on your Mac
before the app will build and run on iOS.

## 1. Fetch dependencies

```bash
cd <repo>
flutter pub get
cd ios
pod install --repo-update
cd ..
```

Expected output: `Pods/` directory + `Podfile.lock` created under `ios/`.

## 2. Wire up GoogleService-Info.plist in Xcode

The file already exists at `ios/Runner/GoogleService-Info.plist`, but it
must be added as a **member of the Runner target** (not just present on
disk), otherwise Firebase will crash at launch with
`The GOOGLE_APP_ID` / `No Firebase App` errors.

1. `open ios/Runner.xcworkspace`
2. In the Project Navigator, right-click the `Runner` folder →
   *Add Files to "Runner"...*
3. Select `GoogleService-Info.plist`.
4. **Important:** ensure the *Runner* target checkbox is ticked in the
   dialog. "Copy items if needed" can be off (the file is already there).

Verify it shows up in *Runner ▸ Build Phases ▸ Copy Bundle Resources*.

## 3. Add adhan sounds to the iOS bundle

Custom notification sounds on iOS must be bundled as resources and must
be **CAF or AIFF** (not MP3). The Dart code expects filenames
`adhan.caf` and `adhan_fajr.caf`.

### Convert the existing MP3s to CAF

```bash
# From the repo root on your Mac:
afconvert android/app/src/main/res/raw/adhan.mp3       ios/Runner/adhan.caf       -d ima4 -f caff -v
afconvert android/app/src/main/res/raw/adhan_fajr.mp3  ios/Runner/adhan_fajr.caf  -d ima4 -f caff -v
```

### Add them to the Runner target

1. Drag both `.caf` files into the `Runner` folder in Xcode.
2. Tick the **Runner** target in the dialog.
3. Verify they appear in *Runner ▸ Build Phases ▸ Copy Bundle Resources*.

If you skip this step, iOS will silently fall back to the default system
notification sound (which still works — notifications will still fire).

## 4. RevenueCat iOS API key

[lib/features/subscription/data/services/revenuecat_service.dart](../lib/features/subscription/data/services/revenuecat_service.dart)
currently has placeholder API keys:

```
static const String _iosApiKey      = 'test_YnSLhYtBinlzKfezdNwXLkeBlWl';
static const String _androidApiKey  = 'sk_dgTUqWhEMCMQfKWpZGNCVZfEXQhEF';
```

Production iOS keys from RevenueCat start with `appl_`, Android with
`goog_`. Replace both with the real values from your RevenueCat dashboard
(Project settings ▸ API keys) before shipping.

In App Store Connect you also need:
- An in-app purchase subscription group with weekly + annual products.
- Product IDs matching the entries attached to your RevenueCat
  `pro` entitlement (current offering: `current.weekly` / `current.annual`).

## 5. Google Sign-In URL scheme

Already wired in `ios/Runner/Info.plist` via `CFBundleURLTypes`. The
scheme value is the `REVERSED_CLIENT_ID` from
`GoogleService-Info.plist`. If you ever regenerate the Firebase config,
keep these two in sync.

## 6. Push notification capability (optional, only if you add FCM later)

Firebase Auth does not need APNs. Add the *Push Notifications* capability
via Xcode ▸ Signing & Capabilities **only** if you start using Firebase
Cloud Messaging. Local scheduled notifications (current adhan path) do
not require it.

## 7. Signing

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the Runner project → Signing & Capabilities.
3. Pick a team; Xcode will create a provisioning profile automatically.
4. Bundle identifier: `com.mdnahid.prayerlock` — must match the Firebase
   iOS app config.

## 8. Build and run

```bash
flutter run -d <your-iphone-id>
# or for release:
flutter build ipa --release
```

## iOS feature matrix

| Feature           | iOS support                                                                                     |
| ----------------- | ----------------------------------------------------------------------------------------------- |
| Prayer times      | ✅ Full                                                                                         |
| Quran             | ✅ Full                                                                                         |
| Dua & Dhikr       | ✅ Full                                                                                         |
| Hadith            | ✅ Full                                                                                         |
| Qibla compass     | ✅ Full (uses magnetometer; `NSMotionUsageDescription` added to Info.plist)                     |
| Adhan + reminders | ✅ Full (scheduled local notifications via `flutter_local_notifications.zonedSchedule`)         |
| Firebase Auth     | ✅ Full (email/password + Google Sign-In)                                                       |
| Crashlytics       | ✅ Full                                                                                         |
| RevenueCat paywall | ✅ Full (uses `current.weekly` / `current.annual` — configure products in App Store Connect)   |
| **App Blocker**   | ❌ **Unsupported on iOS.** iOS sandbox forbids monitoring or blocking other apps. UI is hidden on iOS at runtime via `Platform.isAndroid` gates in `main_screen.dart` and `app_blocker_screen.dart`. |
| **Home widgets**  | ❌ Not implemented on iOS. Would require a separate WidgetKit extension (Swift/SwiftUI). The `home_widget` Flutter package is not yet wired on either platform. |

## What changed in this task

- **Notifications:** On iOS, `NotificationService` now uses
  `flutter_local_notifications.zonedSchedule` with the `timezone`
  package instead of the Android-only native alarm pipeline. The native
  `PrayerAlarmChannel` path is still used on Android and is untouched.
- **Guards:** `AndroidAlarmManager.initialize()` and
  `NativeAlarmService.*` methods are now no-ops on non-Android.
- **Info.plist:** Added motion usage description (Qibla) + Google
  Sign-In URL scheme.
- **Deployment target:** Raised to iOS 13.0 in
  `project.pbxproj`, `AppFrameworkInfo.plist`, and the new `Podfile` —
  required by Firebase, RevenueCat, and flutter_local_notifications.
- **Podfile:** Created with Flutter boilerplate + enforces iOS 13.0 on
  all pods and enables the permission_handler compile flags for
  location, notifications, and sensors.
