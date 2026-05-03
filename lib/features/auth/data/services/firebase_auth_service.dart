// ─── Firebase Auth Service ───────────────────────────────────────────────────

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';

/// Firebase-backed [AuthRepository].
///
/// Supports Google Sign-In and email/password auth. Identity-only — entitlement
/// state lives entirely in RevenueCat, linked by uid via
/// [RevenueCatAuthLinkService] so purchases survive reinstalls.
///
/// Singleton so the [FirebaseAuth] listener registered at construction remains
/// alive for the app's lifetime.
class FirebaseAuthService implements AuthRepository {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  // ── AuthRepository ─────────────────────────────────────────────────────────

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Stream<AuthUser?> get userStream =>
      _auth.authStateChanges().map(_toAuthUser);

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  @override
  Future<AuthUser> signInWithGoogle() async {
    AppLogger.info('FirebaseAuth: Google sign-in started');
    final googleUser = await _google.signIn();
    if (googleUser == null) throw const AuthCancelledException();

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    AppLogger.info('FirebaseAuth: Google sign-in success — ${result.user!.uid}');
    return _toAuthUser(result.user!)!;
  }

  // ── Email / Password ───────────────────────────────────────────────────────

  @override
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    AppLogger.info('FirebaseAuth: email sign-in — $email');
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toAuthUser(result.user!)!;
  }

  @override
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    AppLogger.info('FirebaseAuth: email sign-up — $email');
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user!.updateDisplayName(displayName.trim());
    await result.user!.reload();
    return _toAuthUser(_auth.currentUser!)!;
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    AppLogger.info('FirebaseAuth: signing out');
    await Future.wait([_google.signOut(), _auth.signOut()]);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  AuthUser? _toAuthUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}
