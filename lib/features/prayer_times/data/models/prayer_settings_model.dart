import 'package:hive/hive.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';

part 'prayer_settings_model.g.dart';

/// Hive model for storing prayer settings
@HiveType(typeId: 1)
class PrayerSettingsModel extends HiveObject {
  @HiveField(0)
  final int calculationMethod;

  @HiveField(1)
  final int madhab;

  @HiveField(2)
  final Map<String, bool> notificationsEnabled; // Hive doesn't support enum keys directly

  @HiveField(3)
  final int notificationMinutesBefore;

  /// Index of AdhanType enum — stored as int for Hive compatibility.
  /// Defaults to 0 (AdhanType.standard) when reading old records that lack this field.
  @HiveField(4)
  final int adhanTypeIndex;

  PrayerSettingsModel({
    required this.calculationMethod,
    required this.madhab,
    required this.notificationsEnabled,
    required this.notificationMinutesBefore,
    this.adhanTypeIndex = 0,
  });

  /// Create model from domain entity
  factory PrayerSettingsModel.fromEntity(PrayerSettings entity) {
    // Convert enum-keyed map to string-keyed map
    final notificationsMap = <String, bool>{};
    entity.notificationsEnabled.forEach((key, value) {
      notificationsMap[key.name] = value;
    });

    return PrayerSettingsModel(
      calculationMethod: entity.calculationMethod,
      madhab: entity.madhab,
      notificationsEnabled: notificationsMap,
      notificationMinutesBefore: entity.notificationMinutesBefore,
      adhanTypeIndex: entity.adhanType.index,
    );
  }

  /// Convert model to domain entity
  PrayerSettings toEntity() {
    // Convert string-keyed map back to enum-keyed map
    final notificationsMap = <PrayerName, bool>{};
    notificationsEnabled.forEach((key, value) {
      final prayerName = PrayerName.values.firstWhere(
        (e) => e.name == key,
        orElse: () => PrayerName.fajr,
      );
      notificationsMap[prayerName] = value;
    });

    final adhanType = adhanTypeIndex < AdhanType.values.length
        ? AdhanType.values[adhanTypeIndex]
        : AdhanType.standard;

    return PrayerSettings(
      calculationMethod: calculationMethod,
      madhab: madhab,
      notificationsEnabled: notificationsMap,
      notificationMinutesBefore: notificationMinutesBefore,
      adhanType: adhanType,
    );
  }
}
