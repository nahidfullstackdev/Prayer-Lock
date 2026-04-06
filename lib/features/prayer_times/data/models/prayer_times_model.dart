import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Model for parsing Aladhan API response
class PrayerTimesModel {
  final DateTime date;
  final Prayer fajr;
  final Prayer dhuhr;
  final Prayer asr;
  final Prayer maghrib;
  final Prayer isha;
  final LocationData location;
  final String calculationMethod;
  final String madhab;

  const PrayerTimesModel({
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

  /// Parse from Aladhan API JSON response
  factory PrayerTimesModel.fromJson(
    Map<String, dynamic> json,
    LocationData location,
    PrayerSettings settings,
  ) {
    final data = json['data'] as Map<String, dynamic>;
    final timings = data['timings'] as Map<String, dynamic>;
    final gregorianDate = data['date']['gregorian'] as Map<String, dynamic>;

    // Parse date string (format: "13-02-2026")
    final dateParts = (gregorianDate['date'] as String).split('-');
    final day = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final year = int.parse(dateParts[2]);
    final date = DateTime(year, month, day);

    return PrayerTimesModel(
      date: date,
      fajr: _parsePrayer(PrayerName.fajr, timings['Fajr'] as String, date, settings),
      dhuhr: _parsePrayer(PrayerName.dhuhr, timings['Dhuhr'] as String, date, settings),
      asr: _parsePrayer(PrayerName.asr, timings['Asr'] as String, date, settings),
      maghrib: _parsePrayer(PrayerName.maghrib, timings['Maghrib'] as String, date, settings),
      isha: _parsePrayer(PrayerName.isha, timings['Isha'] as String, date, settings),
      location: location,
      calculationMethod: settings.calculationMethodName,
      madhab: settings.madhabName,
    );
  }

  /// Parse individual prayer time
  static Prayer _parsePrayer(
    PrayerName name,
    String timeStr,
    DateTime date,
    PrayerSettings settings,
  ) {
    // Remove any timezone info (e.g., "12:30 (EST)" -> "12:30")
    final cleanTime = timeStr.split(' ')[0];
    final parts = cleanTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final time = DateTime(date.year, date.month, date.day, hour, minute);

    return Prayer(
      name: name,
      time: time,
      notificationEnabled: settings.notificationsEnabled[name] ?? true,
    );
  }

  /// Convert to domain entity
  PrayerTimes toEntity() {
    return PrayerTimes(
      date: date,
      fajr: fajr,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      location: location,
      calculationMethod: calculationMethod,
      madhab: madhab,
    );
  }
}
