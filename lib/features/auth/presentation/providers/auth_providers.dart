import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/auth/data/services/firebase_auth_service.dart';
import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';

// ── Service provider ──────────────────────────────────────────────────────────

/// Singleton [FirebaseAuthService] exposed as [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthService();
});

// ── Auth state providers ──────────────────────────────────────────────────────

/// Stream of the currently authenticated [AuthUser].
/// Emits null when signed out or before Firebase resolves the initial state.
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.read(authRepositoryProvider).userStream;
});

/// Convenience: true once a user is confirmed signed in.
/// Defaults to false while the stream is loading or on error.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authUserProvider).maybeWhen(
    data: (user) => user != null,
    orElse: () => false,
  );
});
