import 'dart:async';

import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';
import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';
import 'package:prayer_lock/features/subscription/domain/repositories/subscription_repository.dart';

/// Bridges Firebase Auth and the [SubscriptionRepository], persisting the
/// signed-in user's current [SubscriptionInfo] under `users/{uid}` in
/// Firestore.
///
/// Sync triggers:
///   • the user signs in → write the latest known subscription snapshot.
///   • RevenueCat reports a status change → write to the currently signed-in
///     user (no-op if signed out).
///
/// A single [SubscriptionSyncService.start] call (typically from `main.dart`)
/// installs both listeners for the lifetime of the app.
class SubscriptionSyncService {
  SubscriptionSyncService({
    required this.authRepository,
    required this.subscriptionRepository,
  });

  final AuthRepository authRepository;
  final SubscriptionRepository subscriptionRepository;

  StreamSubscription<AuthUser?>? _authSub;
  StreamSubscription<SubscriptionInfo>? _infoSub;
  AuthUser? _currentUser;

  /// Activates both listeners. Safe to call once at app start; calling again
  /// is a no-op while already running.
  void start() {
    if (_authSub != null || _infoSub != null) return;
    AppLogger.info('SubscriptionSyncService: starting');

    _authSub = authRepository.userStream.listen((user) {
      final justSignedIn = _currentUser?.uid != user?.uid && user != null;
      _currentUser = user;
      if (justSignedIn) {
        _push(reason: 'sign-in');
      }
    });

    _infoSub = subscriptionRepository.infoStream.listen((_) {
      _push(reason: 'subscription-change');
    });
  }

  Future<void> _push({required String reason}) async {
    final uid = _currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final info = subscriptionRepository.currentInfo;
    // Skip writes while RevenueCat hasn't produced its first CustomerInfo —
    // we'd just be persisting `unknown`/`none`, which would later be
    // overwritten by the real value anyway.
    if (info.status == AppSubscriptionStatus.unknown) return;
    AppLogger.info('SubscriptionSyncService: pushing ($reason) for $uid');
    await authRepository.updateSubscriptionRecord(uid: uid, info: info);
  }

  void dispose() {
    _authSub?.cancel();
    _infoSub?.cancel();
    _authSub = null;
    _infoSub = null;
  }
}
