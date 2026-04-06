/// Bookmark entity representing a saved Ayah position
///
/// Immutable business object with no dependencies
class Bookmark {
  /// Unique identifier for the bookmark (nullable for new bookmarks)
  final int? id;

  /// ID of the Surah
  final int surahId;

  /// ID of the Ayah
  final int ayahId;

  /// Name of the Surah (for display purposes)
  final String surahName;

  /// Ayah number within the Surah
  final int ayahNumber;

  /// When the bookmark was created
  final DateTime createdAt;

  const Bookmark({
    this.id,
    required this.surahId,
    required this.ayahId,
    required this.surahName,
    required this.ayahNumber,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Bookmark &&
        other.id == id &&
        other.surahId == surahId &&
        other.ayahId == ayahId &&
        other.surahName == surahName &&
        other.ayahNumber == ayahNumber &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      surahId,
      ayahId,
      surahName,
      ayahNumber,
      createdAt,
    );
  }

  @override
  String toString() {
    return 'Bookmark(id: $id, surahId: $surahId, ayahId: $ayahId, surahName: $surahName, ayahNumber: $ayahNumber, createdAt: $createdAt)';
  }
}
