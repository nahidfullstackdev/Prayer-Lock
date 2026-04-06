import 'package:prayer_lock/features/quran/domain/entities/last_read.dart';

/// LastRead data model with SQLite mapping
///
/// Extends LastRead entity and adds database serialization methods
class LastReadModel extends LastRead {
  const LastReadModel({
    required super.surahId,
    required super.ayahId,
    required super.surahName,
    required super.ayahNumber,
    required super.updatedAt,
  });

  /// Create LastReadModel from SQLite map
  factory LastReadModel.fromMap(Map<String, dynamic> map) {
    return LastReadModel(
      surahId: map['surah_id'] as int,
      ayahId: map['ayah_id'] as int,
      surahName: map['surah_name'] as String,
      ayahNumber: map['ayah_number'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  /// JSON map for Hive cache storage
  Map<String, dynamic> toJson() {
    return {
      'surah_id': surahId,
      'ayah_id': ayahId,
      'surah_name': surahName,
      'ayah_number': ayahNumber,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Create LastReadModel from Hive cache map
  factory LastReadModel.fromCacheJson(Map<String, dynamic> json) {
    return LastReadModel(
      surahId: json['surah_id'] as int,
      ayahId: json['ayah_id'] as int,
      surahName: json['surah_name'] as String,
      ayahNumber: json['ayah_number'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
    );
  }

  /// Convert LastReadModel to LastRead entity
  LastRead toEntity() {
    return LastRead(
      surahId: surahId,
      ayahId: ayahId,
      surahName: surahName,
      ayahNumber: ayahNumber,
      updatedAt: updatedAt,
    );
  }

  /// Create LastReadModel from LastRead entity
  factory LastReadModel.fromEntity(LastRead lastRead) {
    return LastReadModel(
      surahId: lastRead.surahId,
      ayahId: lastRead.ayahId,
      surahName: lastRead.surahName,
      ayahNumber: lastRead.ayahNumber,
      updatedAt: lastRead.updatedAt,
    );
  }
}
