import 'package:hive/hive.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/location_data.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_times.dart';

/// Hive model for caching prayer times with 30-day retention.
/// Adapter is hand-written below — typeId 0, field layout must stay
/// identical to the previously generated adapter so existing user
/// data on disk keeps decoding.
class CachedPrayerTimesModel extends HiveObject {
  final String dateKey; // 'yyyy-MM-dd'
  final String fajrTime; // ISO8601 string
  final String dhuhrTime;
  final String asrTime;
  final String maghribTime;
  final String ishaTime;
  final double latitude;
  final double longitude;
  final int calculationMethod;
  final int madhab;
  final int cachedAt; // Unix timestamp (seconds)
  final String? cityName;
  final String? countryName;

  CachedPrayerTimesModel({
    required this.dateKey,
    required this.fajrTime,
    required this.dhuhrTime,
    required this.asrTime,
    required this.maghribTime,
    required this.ishaTime,
    required this.latitude,
    required this.longitude,
    required this.calculationMethod,
    required this.madhab,
    required this.cachedAt,
    this.cityName,
    this.countryName,
  });

  /// Create from Aladhan API response
  factory CachedPrayerTimesModel.fromApiResponse(
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

    return CachedPrayerTimesModel(
      dateKey: _formatDateKey(date),
      fajrTime: _parseTimeToIso(timings['Fajr'] as String, date),
      dhuhrTime: _parseTimeToIso(timings['Dhuhr'] as String, date),
      asrTime: _parseTimeToIso(timings['Asr'] as String, date),
      maghribTime: _parseTimeToIso(timings['Maghrib'] as String, date),
      ishaTime: _parseTimeToIso(timings['Isha'] as String, date),
      latitude: location.latitude,
      longitude: location.longitude,
      calculationMethod: settings.calculationMethod,
      madhab: settings.madhab,
      cachedAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      cityName: location.cityName,
      countryName: location.countryName,
    );
  }

  /// Convert to PrayerTimes entity
  PrayerTimes toEntity(Map<PrayerName, bool> notificationsEnabled) {
    final date = _parseDateKey(dateKey);
    final location = LocationData(
      latitude: latitude,
      longitude: longitude,
      cityName: cityName,
      countryName: countryName,
      timestamp: DateTime.now(),
    );

    return PrayerTimes(
      date: date,
      fajr: Prayer(
        name: PrayerName.fajr,
        time: DateTime.parse(fajrTime),
        notificationEnabled: notificationsEnabled[PrayerName.fajr] ?? true,
      ),
      dhuhr: Prayer(
        name: PrayerName.dhuhr,
        time: DateTime.parse(dhuhrTime),
        notificationEnabled: notificationsEnabled[PrayerName.dhuhr] ?? true,
      ),
      asr: Prayer(
        name: PrayerName.asr,
        time: DateTime.parse(asrTime),
        notificationEnabled: notificationsEnabled[PrayerName.asr] ?? true,
      ),
      maghrib: Prayer(
        name: PrayerName.maghrib,
        time: DateTime.parse(maghribTime),
        notificationEnabled: notificationsEnabled[PrayerName.maghrib] ?? true,
      ),
      isha: Prayer(
        name: PrayerName.isha,
        time: DateTime.parse(ishaTime),
        notificationEnabled: notificationsEnabled[PrayerName.isha] ?? true,
      ),
      location: location,
      calculationMethod: _getMethodName(calculationMethod),
      madhab: madhab == 0 ? 'Shafi' : 'Hanafi',
    );
  }

  /// Check if cache is valid for the given date, location, and calculation settings.
  /// Returns false if any of these have changed since caching.
  bool isValidFor(
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) =>
      invalidationReason(date, location, settings) == null;

  /// Returns null when the cache is valid, or a short human-readable string
  /// describing the first failed check. Lets the repository log *why* it had
  /// to hit the API when troubleshooting "cache never used" reports.
  String? invalidationReason(
    DateTime date,
    LocationData location,
    PrayerSettings settings,
  ) {
    if (dateKey != _formatDateKey(date)) {
      return 'date mismatch (cached=$dateKey, requested=${_formatDateKey(date)})';
    }
    if (calculationMethod != settings.calculationMethod) {
      return 'method changed (cached=$calculationMethod, current=${settings.calculationMethod})';
    }
    if (madhab != settings.madhab) {
      return 'madhab changed (cached=$madhab, current=${settings.madhab})';
    }
    final cachedLocation = LocationData(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
    );
    if (cachedLocation.isDifferentFrom(location)) {
      return 'location moved >10km '
          '(cached=$latitude,$longitude → current=${location.latitude},${location.longitude})';
    }
    final cacheAge = DateTime.now().millisecondsSinceEpoch ~/ 1000 - cachedAt;
    const thirtyDaysInSeconds = 30 * 24 * 60 * 60;
    if (cacheAge > thirtyDaysInSeconds) {
      return 'cache aged out (${cacheAge ~/ 86400}d old)';
    }
    return null;
  }

  /// Format date as 'yyyy-MM-dd'
  static String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date key back to DateTime
  static DateTime _parseDateKey(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Parse time string "HH:mm" to ISO8601 with date
  static String _parseTimeToIso(String timeStr, DateTime date) {
    // Remove any timezone info (e.g., "12:30 (EST)" -> "12:30")
    final cleanTime = timeStr.split(' ')[0];
    final parts = cleanTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final dateTime = DateTime(date.year, date.month, date.day, hour, minute);
    return dateTime.toIso8601String();
  }

  /// Get calculation method name from Aladhan API method ID
  static String _getMethodName(int method) {
    switch (method) {
      case 0:
        return 'Shia Ithna-Ashari';
      case 1:
        return 'University of Islamic Sciences, Karachi';
      case 2:
        return 'Islamic Society of North America (ISNA)';
      case 3:
        return 'Muslim World League (MWL)';
      case 4:
        return 'Umm Al-Qura University, Makkah';
      case 5:
        return 'Egyptian General Authority of Survey';
      case 6:
        return 'Institute of Geophysics, University of Tehran';
      case 7:
        return 'Gulf Region';
      case 8:
        return 'Kuwait';
      case 9:
        return 'Qatar';
      case 10:
        return 'Majlis Ugama Islam Singapura, Singapore';
      case 11:
        return 'Union Organization Islamic de France';
      case 12:
        return 'Diyanet İşleri Başkanlığı, Turkey';
      case 13:
        return 'Spiritual Administration of Muslims of Russia';
      case 14:
        return 'Moonsighting Committee Worldwide';
      case 15:
        return 'Dubai';
      default:
        return 'Unknown';
    }
  }
}

class CachedPrayerTimesModelAdapter extends TypeAdapter<CachedPrayerTimesModel> {
  @override
  final int typeId = 0;

  @override
  CachedPrayerTimesModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedPrayerTimesModel(
      dateKey: fields[0] as String,
      fajrTime: fields[1] as String,
      dhuhrTime: fields[2] as String,
      asrTime: fields[3] as String,
      maghribTime: fields[4] as String,
      ishaTime: fields[5] as String,
      latitude: fields[6] as double,
      longitude: fields[7] as double,
      calculationMethod: fields[8] as int,
      madhab: fields[9] as int,
      cachedAt: fields[10] as int,
      cityName: fields[11] as String?,
      countryName: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CachedPrayerTimesModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.dateKey)
      ..writeByte(1)
      ..write(obj.fajrTime)
      ..writeByte(2)
      ..write(obj.dhuhrTime)
      ..writeByte(3)
      ..write(obj.asrTime)
      ..writeByte(4)
      ..write(obj.maghribTime)
      ..writeByte(5)
      ..write(obj.ishaTime)
      ..writeByte(6)
      ..write(obj.latitude)
      ..writeByte(7)
      ..write(obj.longitude)
      ..writeByte(8)
      ..write(obj.calculationMethod)
      ..writeByte(9)
      ..write(obj.madhab)
      ..writeByte(10)
      ..write(obj.cachedAt)
      ..writeByte(11)
      ..write(obj.cityName)
      ..writeByte(12)
      ..write(obj.countryName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedPrayerTimesModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
