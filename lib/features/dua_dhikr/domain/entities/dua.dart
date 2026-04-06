// ─── Dua entity ───────────────────────────────────────────────────────────────

class Dua {
  const Dua({
    required this.id,
    required this.categoryId,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.reference,
    this.count = 1,
    this.orderIndex = 0,
  });

  final String id;
  final String categoryId;
  final String arabic;
  final String transliteration;
  final String translation;

  /// Source reference (e.g. "Bukhari 6306").
  final String reference;

  /// Recommended repetition count (1, 3, 7, 33, etc.).
  final int count;

  /// Display order within its category.
  final int orderIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Dua && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
