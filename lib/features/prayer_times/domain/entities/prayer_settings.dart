import 'package:prayer_lock/features/prayer_times/domain/entities/adhan_type.dart';
import 'package:prayer_lock/features/prayer_times/domain/entities/prayer_name.dart';

/// Entity representing user preferences for prayer times calculation
class PrayerSettings {
  /// Calculation method for prayer times
  /// 0: Shia Ithna-Ashari
  /// 1: University of Islamic Sciences, Karachi
  /// 2: Islamic Society of North America (ISNA)
  /// 3: Muslim World League (MWL)
  /// 4: Umm Al-Qura University, Makkah
  /// 5: Egyptian General Authority of Survey
  /// 6: Institute of Geophysics, University of Tehran
  /// 7: Gulf Region
  final int calculationMethod;

  /// Madhab for Asr time calculation
  /// 0: Shafi (Standard)
  /// 1: Hanafi
  final int madhab;

  /// Map of notification enabled status for each prayer
  final Map<PrayerName, bool> notificationsEnabled;

  /// Minutes before prayer to show notification (0, 5, 10, 15)
  final int notificationMinutesBefore;

  /// Adhan sound type played with the notification
  final AdhanType adhanType;

  const PrayerSettings({
    this.calculationMethod = 3, // Muslim World League by default
    this.madhab = 0, // Shafi by default
    this.notificationsEnabled = const {
      PrayerName.fajr: true,
      PrayerName.dhuhr: true,
      PrayerName.asr: true,
      PrayerName.maghrib: true,
      PrayerName.isha: true,
    },
    this.notificationMinutesBefore = 0,
    this.adhanType = AdhanType.standard,
  });

  /// Returns the display name of the calculation method.
  /// Method IDs match the Aladhan API /timings endpoint `method` parameter.
  String get calculationMethodName {
    switch (calculationMethod) {
      case 0:
        return 'Jafari / Shia Ithna-Ashari';
      case 1:
        return 'University of Islamic Sciences, Karachi';
      case 2:
        return 'Islamic Society of North America';
      case 3:
        return 'Muslim World League';
      case 4:
        return 'Umm Al-Qura University, Makkah';
      case 5:
        return 'Egyptian General Authority of Survey';
      case 7:
        return 'Institute of Geophysics, University of Tehran';
      case 8:
        return 'Gulf Region';
      case 9:
        return 'Kuwait';
      case 10:
        return 'Qatar';
      case 11:
        return 'Majlis Ugama Islam Singapura, Singapore';
      case 12:
        return 'Union Organization Islamic de France';
      case 13:
        return 'Diyanet İşleri Başkanlığı, Turkey';
      case 14:
        return 'Spiritual Administration of Muslims of Russia';
      case 15:
        return 'Moonsighting Committee Worldwide';
      case 16:
        return 'Dubai';
      case 17:
        return 'Jabatan Kemajuan Islam Malaysia (JAKIM)';
      case 18:
        return 'Tunisia';
      case 19:
        return 'Algeria';
      case 20:
        return 'KEMENAG - Kementerian Agama Republik Indonesia';
      case 21:
        return 'Morocco';
      case 22:
        return 'Comunidade Islamica de Lisboa';
      case 23:
        return 'Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan';
      default:
        return 'Unknown';
    }
  }

  /// Returns the display name of the madhab
  String get madhabName {
    return madhab == 0 ? 'Shafi' : 'Hanafi';
  }

  PrayerSettings copyWith({
    int? calculationMethod,
    int? madhab,
    Map<PrayerName, bool>? notificationsEnabled,
    int? notificationMinutesBefore,
    AdhanType? adhanType,
  }) {
    return PrayerSettings(
      calculationMethod: calculationMethod ?? this.calculationMethod,
      madhab: madhab ?? this.madhab,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      adhanType: adhanType ?? this.adhanType,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PrayerSettings &&
        other.calculationMethod == calculationMethod &&
        other.madhab == madhab &&
        other.notificationMinutesBefore == notificationMinutesBefore &&
        other.adhanType == adhanType;
  }

  @override
  int get hashCode {
    return calculationMethod.hashCode ^
        madhab.hashCode ^
        notificationMinutesBefore.hashCode ^
        adhanType.hashCode;
  }

  @override
  String toString() {
    return 'PrayerSettings(method: $calculationMethodName, madhab: $madhabName, notifyBefore: ${notificationMinutesBefore}m, adhan: ${adhanType.displayName})';
  }
}
