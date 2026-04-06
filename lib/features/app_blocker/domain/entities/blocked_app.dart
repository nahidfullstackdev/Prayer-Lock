/// Represents an installed app that can be selected for blocking.
class BlockedApp {
  const BlockedApp({
    required this.packageName,
    required this.appName,
    this.iconBase64,
  });

  final String packageName;
  final String appName;

  /// Base-64 encoded PNG icon from the native side; null if unavailable.
  final String? iconBase64;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockedApp && other.packageName == packageName);

  @override
  int get hashCode => packageName.hashCode;

  @override
  String toString() => 'BlockedApp($packageName, $appName)';
}
