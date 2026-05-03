# Privacy Policy — Prayer Lock

**App:** Prayer Lock (`com.mdnahid.prayerlock`)
**Effective date:** 2 May 2026
**Last updated:** 2 May 2026
**Contact:** thisisnahid78@gmail.com

---

## A short summary

Prayer Lock is a free Islamic companion app that helps you keep your Salah on time. We have built it to respect your privacy:

- We use your **location only to calculate accurate prayer times for where you are** — not for advertising, not for tracking, not for selling.
- We do **not** run behavioural analytics, we do **not** profile your activity, and we do **not** show advertisements.
- Sensitive on-device features such as the **App Blocker** read information about which apps are running purely on your phone — that information **never leaves your device**.
- We only ask you to sign in (with email or Google) at the moment you choose to upgrade to **Prayer Lock Pro**. Browsing the Quran, prayer times, Qibla, free duas and free hadiths does not require an account.
- Subscription billing is handled by RevenueCat and the Google Play / Apple App Store; we never see or store your payment card.

The sections below explain everything in detail.

---

## 1. Who we are

Prayer Lock is published by an independent developer ("we", "us", "our"). For any privacy question, request or complaint you can write to **thisisnahid78@gmail.com**. We will respond within a reasonable time and, where applicable, within the timeframes required by your local data-protection law (for example 30 days under the GDPR).

This policy applies to the Prayer Lock mobile application on Android and iOS. It does not apply to any third-party website or service that the app may link to.

---

## 2. Data we collect, why we collect it, and where it goes

The table below lists every category of personal data the app processes, the purpose, the third-party processor (if any), and how long it is retained.

| Data | Why we process it | Where it goes | Retention |
| --- | --- | --- | --- |
| **Approximate and precise location** (GPS coordinates) | Compute prayer times for your current city using the Aladhan API and reverse-geocode coordinates into a city/country label so you can see where the times are calculated for. | Sent to the Aladhan API (`api.aladhan.com`) on each refresh. Coordinates and the resolved city/country name are also cached locally on your device for offline use. The reverse-geocoding lookup is performed by the **operating-system geocoder** (Apple MapKit on iOS, Android system geocoder on Android). | Local cache up to 30 days, then re-fetched. Aladhan does not require an account and we do not pass any identifier alongside the coordinates. |
| **Email address, display name, profile photo URL** | Create your Prayer Lock Pro account so we can verify your subscription on a new device and restore purchases. Provided by you (email/password sign-up) or by Google when you choose Google Sign-In. | Stored in **Firebase Authentication** only. We do not maintain a separate user database. | Until you delete your account (see *Your rights* below). |
| **Authentication tokens** | Keep you signed in across app launches. | Issued and managed by Firebase Authentication and Google Sign-In; stored in the platform's secure storage on your device. | Until you sign out or revoke access. |
| **Subscription status** (status, plan, product ID, expiry timestamp, will-renew flag, trial flag) | Determine whether your Pro entitlement is active so locked features unlock. | Verified by **RevenueCat** exclusively. Your Firebase user ID is shared with RevenueCat so a purchase made on one device is recognised when you sign in on another. | For the lifetime of your subscription record per RevenueCat's retention policy. |
| **Purchase receipts** | Process the actual purchase and renewal. | Handled by **Google Play Billing** (Android) or **App Store** (iOS) and surfaced to RevenueCat. We never see or store your payment card details. | Per Google / Apple / RevenueCat policy. |
| **Crash diagnostics** (stack trace, device model, OS version, app version, locale, anonymous installation ID) | Detect and fix crashes so the app stays reliable. | **Firebase Crashlytics**. Crash collection is **disabled in debug builds** and only runs in production releases. | Per Firebase Crashlytics' default retention (90 days). |
| **Notification delivery state** | Schedule the adhan / reminder at the correct time, including after a device reboot. | Stored entirely on your device (Android `SharedPreferences` and `AlarmManager`; iOS local notifications). | Until you change settings or uninstall the app. |

**We do not collect:**

- Any analytics or behavioural-tracking data (no Firebase Analytics, no Google Analytics, no third-party SDK of that kind is integrated)
- Advertising identifiers (we do not currently show advertisements)
- Contacts, calendar, photos, microphone or camera input
- Health, fitness, financial or biometric data
- Your reading history of the Quran or which duas you opened

---

## 3. Data that stays only on your device

The following data is created and used **locally** and is never uploaded to our servers or any third-party server:

- Quran bookmarks and last-read position (stored in the local SQLite database)
- Prayer settings — calculation method, madhab, adhan type, reminder offset (Hive cache)
- Cached prayer times for offline use (Hive cache)
- The list of apps you have chosen to block during prayer windows (Hive + Android `SharedPreferences`)
- App Blocker state — which app is currently in the foreground while a prayer window is active (read in real time by the on-device foreground service and discarded)
- Theme preference (dark / light) and onboarding-completed flag

Uninstalling the app removes all of this local data.

---

## 4. Permissions we request and why

The app requests the minimum permissions necessary for each feature. You can revoke any permission from your device's system settings at any time; the corresponding feature will simply stop working.

### Both Android and iOS

| Permission | Why |
| --- | --- |
| **Location** (precise / when-in-use) | Calculate prayer times for your current location. |
| **Notifications** | Deliver the adhan and the pre-prayer reminder. |
| **Motion sensors** (iOS `NSMotionUsageDescription`) | Drive the Qibla compass via the magnetometer. |

### Android-only

| Permission | Why |
| --- | --- |
| `INTERNET` | Fetch prayer times, Quran content and hadiths from public APIs. |
| `SCHEDULE_EXACT_ALARM` / `USE_EXACT_ALARM` | Trigger the adhan precisely at prayer time on Android 12+. |
| `POST_NOTIFICATIONS` | Show the adhan / reminder notification on Android 13+. |
| `VIBRATE`, `WAKE_LOCK` | Vibrate and wake the screen for prayer notifications. |
| `RECEIVE_BOOT_COMPLETED` | Re-schedule prayer alarms after you reboot the device, so you do not miss the adhan. |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Optional — ask you to exempt the app from aggressive battery optimisation so the adhan is reliably delivered on devices that otherwise kill background alarms. You can decline. |

### Pro-only (Android, App Blocker)

These are sensitive permissions reviewed by Google Play. We only request them if you choose to use the App Blocker.

| Permission | Why | Data flow |
| --- | --- | --- |
| `PACKAGE_USAGE_STATS` (Usage Access) | Detect which app is currently in the foreground during a prayer window so we can show the lock overlay. | Read locally by the on-device foreground service. **Never transmitted off the device.** |
| `SYSTEM_ALERT_WINDOW` (Display over other apps) | Draw the prayer-lock overlay over the blocked app. | UI only — no data. |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` | Run the lightweight service that polls the foreground app while a prayer window is active. | UI only — no data. |

We do not request, use or transmit usage statistics for any purpose other than enforcing your own App Blocker rules on your own device.

App Blocker is **not available on iOS** because Apple's sandboxing model does not permit this kind of inter-app monitoring; iOS users will not see App Blocker UI or any related permission prompt.

---

## 5. Third-party services we rely on

The following third parties process some of your data on our behalf or in connection with the app. Each link points to that provider's own privacy policy.

| Service | Provider | What it processes | Provider policy |
| --- | --- | --- | --- |
| Firebase Authentication | Google LLC | Email, password hash, display name, profile photo URL, auth tokens | https://policies.google.com/privacy |
| Firebase Crashlytics | Google LLC | Crash stack traces, device/OS metadata, anonymous installation ID (release builds only) | https://policies.google.com/privacy |
| Google Sign-In | Google LLC | OAuth flow when you choose to sign in with Google | https://policies.google.com/privacy |
| Google Play Billing | Google LLC | Subscription purchase and renewal on Android | https://policies.google.com/privacy |
| App Store In-App Purchase | Apple Inc. | Subscription purchase and renewal on iOS | https://www.apple.com/legal/privacy/ |
| RevenueCat | RevenueCat, Inc. | Subscription entitlement verification, restore-purchase. Your Firebase user ID is sent to RevenueCat as the customer identifier so purchases follow you across reinstalls. | https://www.revenuecat.com/privacy/ |
| Aladhan API | IslamicNetwork | Latitude, longitude, calculation method and madhab parameters in each prayer-time request — no account or identifier is sent | https://aladhan.com/privacy-policy |
| Al-Quran Cloud API | Islamic Network | Standard HTTP request metadata only — no personal data, no account | https://alquran.cloud/ |
| jsDelivr CDN (Hadith content) | jsDelivr | Standard HTTP request metadata only — no personal data, no account | https://www.jsdelivr.com/terms/privacy-policy-jsdelivr-net |
| OS reverse-geocoder | Apple Inc. (iOS) / Google LLC (Android system) | Converts coordinates into a city/country label | https://www.apple.com/legal/privacy/ · https://policies.google.com/privacy |

We do not have any other third-party SDK that collects personal data. In particular, the app does **not** integrate Firebase Analytics, Firebase Cloud Messaging, Firebase Performance, Firebase Remote Config, AdMob, Facebook SDK, or any social-media SDK other than Google Sign-In.

---

## 6. Sharing and selling of personal data

- We do **not** sell your personal data.
- We do **not** share your personal data with third parties for advertising or marketing purposes.
- We do **not** carry out cross-context behavioural advertising or profiling.
- We disclose data to the processors listed in section 5 only to the extent necessary to provide the feature you asked for (sign-in, subscription, prayer times, crash reports).
- We may disclose information if required to do so by law, by valid legal process, or to protect the rights, property or safety of our users or the public.

If you are a California resident, this means we do not "sell" or "share" personal information as those terms are defined under the California Consumer Privacy Act (CCPA / CPRA).

---

## 7. Children's privacy

Prayer Lock is intended for a general audience and is not directed at children under the age of 13 (or under 16 in the European Economic Area and the United Kingdom). We do not knowingly collect personal data from children. If you believe a child has provided us with personal data, please email **thisisnahid78@gmail.com** and we will delete it.

---

## 8. Your rights

Depending on where you live, you may have some or all of the following rights regarding your personal data:

- **Access** — request a copy of the personal data we hold about you
- **Correction** — ask us to fix data that is inaccurate or incomplete
- **Deletion** — ask us to delete your account and associated data
- **Portability** — receive your data in a machine-readable format
- **Withdraw consent** — withdraw any consent you previously gave (e.g. revoke location permission in system settings)
- **Object or restrict processing** — under the GDPR / UK GDPR
- **Lodge a complaint** with your local data-protection authority

To exercise any of these rights, email **thisisnahid78@gmail.com** from the address you signed up with. We will verify your identity before acting on the request.

**How to delete your account.** Until an in-app "Delete account" button is available, send a deletion request to **thisisnahid78@gmail.com**. We will delete your Firebase Authentication record and request deletion of your RevenueCat customer record (which holds your subscription history under your Firebase user ID). Crashlytics records are anonymous and are not linked to your account. Local data on your device is removed by uninstalling the app.

---

## 9. Data retention

- **Firebase Auth credentials** — kept until you delete your account.
- **Subscription record** — kept while your subscription is active, then for the period required by Google / Apple / RevenueCat for refund and tax purposes, then deleted with your account.
- **Crashlytics data** — retained per Firebase's default Crashlytics policy (currently 90 days for unresolved crashes).
- **Local cache on your device** — kept until you uninstall the app or clear app data; prayer-times entries are pruned after about 30 days.

---

## 10. International transfers

Our processors (Google, Apple, RevenueCat, IslamicNetwork, jsDelivr) operate globally, which means your data may be processed in the United States or other countries whose data-protection laws may differ from those of your country of residence. Where required by law, those processors rely on Standard Contractual Clauses or equivalent safeguards. Their respective privacy policies (linked in section 5) describe those safeguards in detail.

---

## 11. Security

- All network requests are made over **HTTPS / TLS**.
- Authentication is handled by Firebase Authentication; we never see your password.
- Subscription receipts are validated by RevenueCat and the platform store; we never see your payment card.
- Local caches are stored in the app's private sandbox, which is isolated from other apps on the device.

No method of electronic storage or transmission is 100% secure. We work to protect your data but cannot guarantee absolute security.

---

## 12. Changes to this policy

We may update this policy from time to time, for example when we add a new feature or third-party processor. The current version is always available at the URL where this document is hosted. When we make material changes we will update the **Effective date** at the top of this page and, where appropriate, notify you in the app before the change takes effect.

---

## 13. Contact

If you have any question, concern, request or complaint about this privacy policy or about how Prayer Lock handles your data, please write to:

**thisisnahid78@gmail.com**
