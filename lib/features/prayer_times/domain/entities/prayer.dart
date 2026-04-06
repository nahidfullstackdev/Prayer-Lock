import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';

/// Entity representing a single prayer with its time and notification settings
class Prayer {
  final PrayerName name;
  final DateTime time;
  final bool notificationEnabled;

  const Prayer({
    required this.name,
    required this.time,
    required this.notificationEnabled,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Prayer &&
        other.name == name &&
        other.time == time &&
        other.notificationEnabled == notificationEnabled;
  }

  @override
  int get hashCode => name.hashCode ^ time.hashCode ^ notificationEnabled.hashCode;

  @override
  String toString() {
    return 'Prayer(name: ${name.displayName}, time: $time, notificationEnabled: $notificationEnabled)';
  }
}
