# Adhan Audio — Usage

There is **no new caller-side API**. The full-length Adhan rides on top of the existing notification-scheduling flow, which is already invoked from two places:

1. After a successful Aladhan fetch in `PrayerTimesNotifier.loadPrayerTimes`.
2. On any settings change in `PrayerSettingsNotifier`.

Both call `schedulePrayerNotificationsUseCase`, which delegates to:

```dart
NotificationService.scheduleAllPrayers(
  prayerTimes: prayerTimes, // domain entity, not Map<String, DateTime>
  settings:    prayerSettings,
);
```

## What happens per platform

| Platform | Schedule action |
| -------- | --------------- |
| Android  | Native `AlarmManager.setAlarmClock` → `PrayerAlarmReceiver` → notification on `prayer_adhan` / `prayer_fajr_adhan` channel. The full-length Adhan plays as the channel sound regardless of app state. |
| iOS — app alive | `flutter_local_notifications.zonedSchedule` posts an early-reminder notification (≤30 s CAF sound) at `prayer.time - notificationMinutesBefore`. A sibling `Timer` fires at the real `prayer.time` and calls `AdhanAudioService().playAdhan()` — full-length playback via `AVAudioPlayer` configured with `.playback + .mixWithOthers`. |
| iOS — app killed | Only the scheduled notification fires (30 s CAF). Tapping the notification opens the app, and the tap handler resumes the full Adhan from `AdhanAudioService`. |

## Manual playback (debug only)

For testing without waiting for a real prayer time:

```dart
import 'package:prayer_lock/features/prayer_times/data/services/adhan_audio_service.dart';

await AdhanAudioService().playAdhan(isFajr: false);
// ...
await AdhanAudioService().stop();
```

The existing `AdhanTestWidget` (debug builds only, hidden in release) exercises the full pipeline — prefer it over manual calls.

## Lifetime notes

- `AdhanAudioService` is a singleton. It is initialised once in `AppInitializer.runDeferred` and reused for the lifetime of the app.
- Dart `Timer` objects do not survive app kill. If iOS terminates the app, the next call to `scheduleAllPrayers` (triggered automatically on the next app launch by `PrayerTimesNotifier.loadPrayerTimes`) rebuilds them.
- The notification fire time is `prayer.time − notificationMinutesBefore` (the reminder). The in-app full Adhan fires at `prayer.time` (the actual prayer time). If `notificationMinutesBefore == 0` the two coincide.
