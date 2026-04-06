// ─── DuaCategory entity ───────────────────────────────────────────────────────

class DuaCategory {
  const DuaCategory({
    required this.id,
    required this.name,
    required this.arabic,
    required this.description,
    required this.iconName,
    required this.isPro,
    required this.duaCount,
    this.orderIndex = 0,
  });

  final String id;
  final String name;
  final String arabic;
  final String description;

  /// Material icon name string — resolved to [IconData] in the presentation layer.
  final String iconName;

  /// Whether this category is gated behind a Pro subscription.
  final bool isPro;

  final int duaCount;
  final int orderIndex;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is DuaCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
