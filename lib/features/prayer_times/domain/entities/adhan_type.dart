/// Adhan sound type preference for prayer notifications
enum AdhanType {
  /// Standard adhan plays when prayer time arrives
  /// Requires adhan.mp3 / adhan_fajr.mp3 in android/app/src/main/res/raw/
  standard,

  /// No sound — vibration-only reminder
  silent;

  /// Human-readable label for settings UI
  String get displayName {
    switch (this) {
      case AdhanType.standard:
        return 'Adhan';
      case AdhanType.silent:
        return 'Silent (vibration only)';
    }
  }
}
