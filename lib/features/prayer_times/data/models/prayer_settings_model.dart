import 'package:hive/hive.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_settings.dart';

/// Hive model for storing prayer settings.
/// Adapter is hand-written below — typeId 1, field layout must stay
/// identical to the previously generated adapter so existing user
/// data on disk keeps decoding. Field 4 (adhanTypeIndex) is missing
/// from records written before that field was added; the read path
/// falls back to 0 (AdhanType.standard).
class PrayerSettingsModel extends HiveObject {
  final int calculationMethod;
  final int madhab;
  // Hive doesn't support enum keys directly, hence String keys.
  final Map<String, bool> notificationsEnabled;
  final int notificationMinutesBefore;
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

class PrayerSettingsModelAdapter extends TypeAdapter<PrayerSettingsModel> {
  @override
  final int typeId = 1;

  @override
  PrayerSettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PrayerSettingsModel(
      calculationMethod: fields[0] as int,
      madhab: fields[1] as int,
      notificationsEnabled: (fields[2] as Map).cast<String, bool>(),
      notificationMinutesBefore: fields[3] as int,
      // Field 4 may be absent in records written before adhanType was added.
      // Falling back to 0 (AdhanType.standard) keeps existing users on adhan.
      adhanTypeIndex: fields[4] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PrayerSettingsModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.calculationMethod)
      ..writeByte(1)
      ..write(obj.madhab)
      ..writeByte(2)
      ..write(obj.notificationsEnabled)
      ..writeByte(3)
      ..write(obj.notificationMinutesBefore)
      ..writeByte(4)
      ..write(obj.adhanTypeIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrayerSettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
