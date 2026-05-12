/// A single prayer-window during which selected apps should be blocked.
///
/// Crossed to native via [scheduleBlockerWindows] — see
/// `AppBlockerChannel.scheduleBlockerWindows` on the Kotlin side.
class BlockerWindow {
  const BlockerWindow({
    required this.prayerId,
    required this.startMs,
    required this.endMs,
  });

  /// 0=Fajr, 1=Dhuhr, 2=Asr, 3=Maghrib, 4=Isha (matches `PrayerName.index`).
  final int prayerId;

  /// Window start (UTC milliseconds since epoch) — the adhan time.
  final int startMs;

  /// Window end (UTC milliseconds since epoch) — typically `startMs + 20min`.
  final int endMs;

  Map<String, Object> toMap() => {
    'prayerId': prayerId,
    'startMs': startMs,
    'endMs': endMs,
  };
}
