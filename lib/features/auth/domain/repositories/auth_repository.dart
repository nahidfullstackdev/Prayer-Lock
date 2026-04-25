import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';

/// Domain interface for authentication.
///
/// Concrete implementation: [FirebaseAuthService].
abstract class AuthRepository {
  /// The currently signed-in user, or null when not authenticated.
  AuthUser? get currentUser;

  /// Emits the authenticated [AuthUser] on sign-in and null on sign-out.
  Stream<AuthUser?> get userStream;

  /// Signs in with Google. Throws [AuthCancelledException] if the user
  /// dismisses the Google account picker without selecting an account.
  Future<AuthUser> signInWithGoogle();

  /// Signs in with email and password.
  Future<AuthUser> signInWithEmail({
    required String email,
    required String password,
  });

  /// Creates a new account with email, password, and display name.
  Future<AuthUser> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  /// Signs out the current user from all providers.
  Future<void> signOut();

  /// Persists the user's current [SubscriptionInfo] under
  /// `users/{uid}` in Firestore. No-op when [uid] is empty.
  ///
  /// Stored fields: `subscriptionStatus`, `subscriptionPlan`,
  /// `subscriptionProductId`, `subscriptionExpiresAt`, `subscriptionWillRenew`,
  /// `subscriptionInTrial`, `subscriptionUpdatedAt`.
  Future<void> updateSubscriptionRecord({
    required String uid,
    required SubscriptionInfo info,
  });
}

/// Thrown when the user cancels Google Sign-In without selecting an account.
class AuthCancelledException implements Exception {
  const AuthCancelledException();

  @override
  String toString() => 'AuthCancelledException: user cancelled sign-in';
}
