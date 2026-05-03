# iOS setup — finishing steps (run on a Mac)

The Dart, `Info.plist`, Podfile, and Xcode-project changes have been made
from Windows. The steps below require **macOS + Xcode + CocoaPods** and
must be run on your Mac before the app will build and ship to the App
Store.

- Bundle identifier: `com.mdnahid.prayerlock` (matches the Firebase iOS app and the RevenueCat iOS app).
- iOS deployment target: **13.0** — set in `ios/Runner.xcodeproj/project.pbxproj`, `ios/Podfile`, and the `post_install` block. Required by Firebase 11, RevenueCat 9, and `flutter_local_notifications` 18.
- Last verified against commit `291f490` on 2026-05-02.

---

## 1. Fetch dependencies

```bash
cd <repo>
flutter pub get
cd ios
pod install --repo-update
cd ..
```

Expected output: `Pods/` directory + `Podfile.lock` created under `ios/`.

> First-time `pod install` is slow — it pulls ~20 pods including
> `Firebase/Auth`, `Firebase/Crashlytics`, `RevenueCat`, and
> `flutter_local_notifications`. Subsequent runs use the local CocoaPods
> cache.

---

## 2. Wire up `GoogleService-Info.plist` in Xcode

The file already exists at [ios/Runner/GoogleService-Info.plist](Runner/GoogleService-Info.plist),
but it must be added as a **member of the Runner target** (not just
present on disk), otherwise Firebase will crash at launch with
`The GOOGLE_APP_ID` / `No Firebase App` errors.

1. `open ios/Runner.xcworkspace`
2. In the Project Navigator, right-click the `Runner` folder →
   *Add Files to "Runner"...*
3. Select `GoogleService-Info.plist`.
4. **Important:** ensure the *Runner* target checkbox is ticked in the
   dialog. *Copy items if needed* can be off (the file is already there).

**Verify:** open Xcode → select the Runner target → *Build Phases* →
*Copy Bundle Resources*. `GoogleService-Info.plist` must appear in the
list.

---

## 3. Bundle the adhan sounds

Custom notification sounds on iOS must be bundled as resources and must
be **CAF or AIFF** (not MP3). The Dart code in
[notification_service.dart](../lib/features/prayer_times/presentation/providers/notification_service.dart)
expects the exact filenames `adhan.caf` and `adhan_fajr.caf`.

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

If you skip this step, scheduled prayer notifications still fire — only
the sound degrades to the system default. The "branded adhan" UX needs
both files present.

---

## 4. Privacy manifest (`PrivacyInfo.xcprivacy`)

Apple **requires** a privacy manifest for every app submitted to the App
Store (enforced since 1 May 2024). Without it, App Store Connect will
reject the build at processing time.

Many of our pods (`firebase_*`, `purchases_flutter`,
`flutter_local_notifications`, `shared_preferences`) ship their own
manifests — Xcode aggregates them — but the **app target still needs
its own** declaring app-level data collection and the required-reason
APIs we touch directly.

Create [ios/Runner/PrivacyInfo.xcprivacy](Runner/PrivacyInfo.xcprivacy)
with the following contents:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>

  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <!-- Crashlytics -->
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeCrashData</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <!-- Coarse location for prayer times -->
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeCoarseLocation</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <false/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
      </array>
    </dict>
    <!-- Firebase Auth user id -->
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeUserID</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        <string>NSPrivacyCollectedDataTypePurposeAuthentication</string>
      </array>
    </dict>
    <!-- Firebase Auth email (provided by user at sign-in) -->
    <dict>
      <key>NSPrivacyCollectedDataType</key>
      <string>NSPrivacyCollectedDataTypeEmailAddress</string>
      <key>NSPrivacyCollectedDataTypeLinked</key>
      <true/>
      <key>NSPrivacyCollectedDataTypeTracking</key>
      <false/>
      <key>NSPrivacyCollectedDataTypePurposes</key>
      <array>
        <string>NSPrivacyCollectedDataTypePurposeAuthentication</string>
      </array>
    </dict>
  </array>

  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- shared_preferences -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>CA92.1</string></array>
    </dict>
    <!-- sqflite, path_provider, Hive -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>C617.1</string></array>
    </dict>
    <!-- Crashlytics -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>E174.1</string></array>
    </dict>
    <!-- Firebase, flutter_local_notifications -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategorySystemBootTime</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array><string>35F9.1</string></array>
    </dict>
  </array>
</dict>
</plist>
```

Then add the file to the Runner target the same way as
`GoogleService-Info.plist` (drag → tick *Runner* → verify under *Build
Phases ▸ Copy Bundle Resources*).

---

## 5. Export-compliance flag

Add the following pair to [ios/Runner/Info.plist](Runner/Info.plist) so
TestFlight does not prompt for export-compliance answers on every
upload — Prayer Lock uses only HTTPS and Apple-provided cryptography:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

If a future build adds non-standard crypto (custom symmetric ciphers,
homemade TLS, etc.), flip this to `<true/>` and complete the export
questionnaire in App Store Connect.

---

## 6. RevenueCat iOS API key

[lib/features/subscription/data/services/revenuecat_service.dart](../lib/features/subscription/data/services/revenuecat_service.dart)
currently has development placeholder keys. Production keys from the
RevenueCat dashboard (*Project settings ▸ API keys*) must replace them
before shipping:

- iOS production key prefix: `appl_…`
- Android production key prefix: `goog_…`

In **App Store Connect** you also need:
- An auto-renewing subscription group with **weekly** and **annual**
  products inside it.
- Product IDs that match the entries attached to your RevenueCat `pro`
  entitlement, and to the current offering's package types
  (`current.weekly` / `current.annual` per CLAUDE.md). The app's
  `SubscriptionRepository.purchase('weekly' | 'annual')` resolves these
  package types — falling back to `availablePackages.first` only when
  neither is configured.

---

## 7. Google Sign-In URL scheme

Already wired in [ios/Runner/Info.plist](Runner/Info.plist) lines 69–79
via `CFBundleURLTypes`. The scheme value is the `REVERSED_CLIENT_ID`
from `GoogleService-Info.plist`. If you ever regenerate the Firebase
config, keep these two in sync. **Verified — no action needed.**

---

## 8. Push notifications, APNs, and `UIBackgroundModes`

Local scheduled notifications (the current adhan path —
`flutter_local_notifications.zonedSchedule`) do **not** need APNs and do
**not** need the *Push Notifications* capability in Xcode. Firebase
Auth also does **not** need APNs.

### Recommended cleanup

Today `Info.plist` declares:

```xml
<key>UIBackgroundModes</key>
<array>
  <string>fetch</string>
  <string>processing</string>
  <string>remote-notification</string>
</array>
```

None of these are exercised by the app:

- `remote-notification` declares the app receives **silent pushes from
  APNs**. We have no APNs server. App Store reviewers commonly flag
  apps that declare this without a corresponding feature — recommend
  removing.
- `fetch` and `processing` are for `BGTaskScheduler` work the app does
  not register. Safe to drop too.

A minimal `Info.plist` for the current feature set has no
`UIBackgroundModes` array at all.

### When to add the Push Notifications capability

Only if the project later adopts Firebase Cloud Messaging (or any other
APNs-based push provider). At that point: Xcode → Runner target →
*Signing & Capabilities* → *+ Capability* → *Push Notifications*. Xcode
will auto-create `Runner.entitlements` containing `aps-environment` at
that step.

---

## 9. Signing

1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the Runner project → *Signing & Capabilities*.
3. Pick a team; Xcode will create a provisioning profile automatically.
4. Bundle identifier: `com.mdnahid.prayerlock` — must match the
   Firebase iOS app config and the RevenueCat iOS app config.

The project does **not** ship a `Runner.entitlements` file yet — that
is correct. Xcode generates one on first capability add (Push
Notifications, Sign in with Apple, App Groups, etc.).

---

## 10. Build and run

```bash
flutter run -d <your-iphone-id>
# or for release:
flutter build ipa --release
```

> Notifications, location, and any background-related features must be
> tested on a **real device**. The iOS Simulator does not deliver
> scheduled local notifications reliably and reports synthetic location.

---

## iOS feature matrix

| Feature             | iOS support                                                                                                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Prayer times        | ✅ Full                                                                                                                                     |
| Quran               | ✅ Full                                                                                                                                     |
| Dua & Dhikr         | ✅ Full                                                                                                                                     |
| Hadith              | ✅ Full                                                                                                                                     |
| Qibla compass       | ✅ Full (uses magnetometer; `NSMotionUsageDescription` set in `Info.plist`)                                                                 |
| Adhan + reminders   | ✅ Scheduled local notifications via `flutter_local_notifications.zonedSchedule`. Custom adhan sound requires step 3; otherwise system default. |
| Firebase Auth       | ✅ Full (email/password + Google Sign-In; URL scheme wired)                                                                                 |
| Crashlytics         | ✅ Full (release builds only — `kDebugMode` gate in `main.dart`)                                                                            |
| RevenueCat paywall  | ✅ Full (uses `current.weekly` / `current.annual` packages — configure products in App Store Connect). Linked to Firebase uid via `RevenueCatAuthLinkService` so purchases follow the user across reinstalls. |
| **App Blocker**     | ❌ **Unsupported on iOS.** iOS sandbox forbids monitoring or blocking other apps. UI is hidden via `Platform.isAndroid` gates in `main_screen.dart`, `app_blocker_screen.dart`, and `pro_paywall_sheet.dart`. |
| **Home widgets**    | ❌ Not implemented on iOS. Would require a separate WidgetKit extension (Swift/SwiftUI). The `home_widget` Flutter package is gated to Android in `home_widget_service.dart`. |

---

## App Store Connect submission checklist

- [ ] Bundle ID `com.mdnahid.prayerlock` registered in App Store Connect, matching Firebase + RevenueCat iOS app configs.
- [ ] `GoogleService-Info.plist` added to the Runner target (step 2).
- [ ] `adhan.caf` and `adhan_fajr.caf` bundled (step 3).
- [ ] `PrivacyInfo.xcprivacy` added to the Runner target (step 4).
- [ ] `ITSAppUsesNonExemptEncryption=false` set in `Info.plist` (step 5).
- [ ] App Privacy answers in App Store Connect aligned with `PrivacyInfo.xcprivacy` (Crash data, Coarse location, User ID, Email — none used for tracking).
- [ ] Production RevenueCat iOS API key (`appl_…`) substituted in `revenuecat_service.dart` (step 6).
- [ ] Auto-renewing subscription group + Weekly + Annual products created and attached to the RevenueCat `pro` entitlement (step 6).
- [ ] Privacy policy URL hosted somewhere reachable. The repo already contains `privacy-policy.md` — publish it (e.g. GitHub Pages) and supply the URL in App Store Connect.
- [ ] Screenshots prepared for all required device classes (iPhone 6.9", 6.5"; iPad 13" / 12.9" if iPad is supported).
- [ ] Tested on a real device (step 10), including: location prompt, motion prompt for Qibla, scheduled adhan, Google Sign-In, RevenueCat purchase sandbox flow.
