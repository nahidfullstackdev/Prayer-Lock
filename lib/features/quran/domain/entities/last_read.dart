/// LastRead entity representing the user's last read position
///
/// Immutable business object with no dependencies
class LastRead {
  /// ID of the Surah
  final int surahId;

  /// ID of the Ayah
  final int ayahId;

  /// Name of the Surah (for display purposes)
  final String surahName;

  /// Ayah number within the Surah
  final int ayahNumber;

  /// When the position was last updated
  final DateTime updatedAt;

  const LastRead({
    required this.surahId,
    required this.ayahId,
    required this.surahName,
    required this.ayahNumber,
    required this.updatedAt,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is LastRead &&
        other.surahId == surahId &&
        other.ayahId == ayahId &&
        other.surahName == surahName &&
        other.ayahNumber == ayahNumber &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      surahId,
      ayahId,
      surahName,
      ayahNumber,
      updatedAt,
    );
  }

  @override
  String toString() {
    return 'LastRead(surahId: $surahId, ayahId: $ayahId, surahName: $surahName, ayahNumber: $ayahNumber, updatedAt: $updatedAt)';
  }
}
