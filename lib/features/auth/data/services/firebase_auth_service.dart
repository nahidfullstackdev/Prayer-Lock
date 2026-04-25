// ─── Firebase Auth Service ───────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';
import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';

/// Firebase-backed [AuthRepository].
///
/// Supports Google Sign-In and email/password auth.
/// User profiles are stored in Firestore: `users/{uid}`.
///
/// Singleton so the [FirebaseAuth] listener registered at construction remains
/// alive for the app's lifetime.
class FirebaseAuthService implements AuthRepository {
  static final FirebaseAuthService _instance = FirebaseAuthService._internal();
  factory FirebaseAuthService() => _instance;
  FirebaseAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    await _persistUser(result.user!);
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
    await _persistUser(result.user!);
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
    final user = _auth.currentUser!;
    await _persistUser(user, isNewUser: true);
    return _toAuthUser(user)!;
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    AppLogger.info('FirebaseAuth: signing out');
    await Future.wait([_google.signOut(), _auth.signOut()]);
  }

  // ── Subscription record ────────────────────────────────────────────────────

  @override
  Future<void> updateSubscriptionRecord({
    required String uid,
    required SubscriptionInfo info,
  }) async {
    if (uid.isEmpty) return;
    try {
      await _db.collection('users').doc(uid).set(
        <String, dynamic>{
          'subscriptionStatus': info.status.name,
          'subscriptionPlan': info.plan.label,
          'subscriptionProductId': info.productIdentifier,
          'subscriptionExpiresAt': info.expirationDate == null
              ? null
              : Timestamp.fromDate(info.expirationDate!),
          'subscriptionWillRenew': info.willRenew,
          'subscriptionInTrial': info.isInTrial,
          'subscriptionUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      AppLogger.info(
        'Firestore: subscription synced for $uid → '
        '${info.status.name}/${info.plan.label}',
      );
    } catch (e, st) {
      AppLogger.error('Firestore subscription sync failed', e, st);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Upserts the user document in Firestore so their profile is available
  /// for server-side features (e.g. Pro entitlement sync, support lookups).
  Future<void> _persistUser(User user, {bool isNewUser = false}) async {
    try {
      final data = <String, dynamic>{
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoUrl': user.photoURL,
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      if (isNewUser) {
        data['createdAt'] = FieldValue.serverTimestamp();
        data['platform'] = 'mobile';
      }
      await _db
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));
    } catch (e, st) {
      AppLogger.error('Firestore user persist failed', e, st);
      // Non-fatal: auth succeeds even if Firestore write fails.
    }
  }

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
