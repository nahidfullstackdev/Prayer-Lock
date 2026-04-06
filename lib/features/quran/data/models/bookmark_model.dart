import 'package:prayer_lock/features/quran/domain/entities/bookmark.dart';

/// Bookmark data model with SQLite mapping
///
/// Extends Bookmark entity and adds database serialization methods
class BookmarkModel extends Bookmark {
  const BookmarkModel({
    super.id,
    required super.surahId,
    required super.ayahId,
    required super.surahName,
    required super.ayahNumber,
    required super.createdAt,
  });

  /// Create BookmarkModel from SQLite map
  factory BookmarkModel.fromMap(Map<String, dynamic> map) {
    return BookmarkModel(
      id: map['id'] as int?,
      surahId: map['surah_id'] as int,
      ayahId: map['ayah_id'] as int,
      surahName: map['surah_name'] as String,
      ayahNumber: map['ayah_number'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// JSON map for Hive cache storage
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'surah_name': surahName,
      'ayah_number': ayahNumber,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Create BookmarkModel from Hive cache map
  factory BookmarkModel.fromCacheJson(Map<String, dynamic> json) {
    return BookmarkModel(
      id: json['id'] as int?,
      surahId: json['surah_id'] as int,
      ayahId: json['ayah_id'] as int,
      surahName: json['surah_name'] as String,
      ayahNumber: json['ayah_number'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
    );
  }

  /// Convert BookmarkModel to Bookmark entity
  Bookmark toEntity() {
    return Bookmark(
      id: id,
      surahId: surahId,
      ayahId: ayahId,
      surahName: surahName,
      ayahNumber: ayahNumber,
      createdAt: createdAt,
    );
  }

  /// Create BookmarkModel from Bookmark entity
  factory BookmarkModel.fromEntity(Bookmark bookmark) {
    return BookmarkModel(
      id: bookmark.id,
      surahId: bookmark.surahId,
      ayahId: bookmark.ayahId,
      surahName: bookmark.surahName,
      ayahNumber: bookmark.ayahNumber,
      createdAt: bookmark.createdAt,
    );
  }
}
