/// Authenticated user — SDK-agnostic, used throughout the presentation layer.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  /// Up to two-letter initials derived from display name, then email.
  String get initials {
    final name = displayName?.trim() ?? '';
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return name[0].toUpperCase();
    }
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  /// Display name if set, otherwise the email prefix (before @).
  String get displayNameOrEmail {
    final name = displayName?.trim() ?? '';
    return name.isNotEmpty ? name : email.split('@').first;
  }
}
