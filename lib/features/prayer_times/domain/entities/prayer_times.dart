import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';

/// Entity representing complete daily prayer times
class PrayerTimes {
  final DateTime date;
  final Prayer fajr;
  final Prayer dhuhr;
  final Prayer asr;
  final Prayer maghrib;
  final Prayer isha;
  final LocationData location;
  final String calculationMethod;
  final String madhab;

  const PrayerTimes({
    required this.date,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.location,
    required this.calculationMethod,
    required this.madhab,
  });

  /// Get prayer by name
  Prayer getPrayer(PrayerName name) {
    switch (name) {
      case PrayerName.fajr:
        return fajr;
      case PrayerName.dhuhr:
        return dhuhr;
      case PrayerName.asr:
        return asr;
      case PrayerName.maghrib:
        return maghrib;
      case PrayerName.isha:
        return isha;
    }
  }

  /// Get all prayers as a list in chronological order
  List<Prayer> get allPrayers => [fajr, dhuhr, asr, maghrib, isha];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PrayerTimes &&
        other.date == date &&
        other.fajr == fajr &&
        other.dhuhr == dhuhr &&
        other.asr == asr &&
        other.maghrib == maghrib &&
        other.isha == isha &&
        other.location == location &&
        other.calculationMethod == calculationMethod &&
        other.madhab == madhab;
  }

  @override
  int get hashCode {
    return date.hashCode ^
        fajr.hashCode ^
        dhuhr.hashCode ^
        asr.hashCode ^
        maghrib.hashCode ^
        isha.hashCode ^
        location.hashCode ^
        calculationMethod.hashCode ^
        madhab.hashCode;
  }

  @override
  String toString() {
    return 'PrayerTimes(date: $date, location: ${location.cityName}, method: $calculationMethod)';
  }
}
