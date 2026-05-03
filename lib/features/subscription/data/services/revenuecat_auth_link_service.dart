import 'dart:async';

import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/auth/domain/entities/auth_user.dart';
import 'package:prayer_lock/features/auth/domain/repositories/auth_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Bridges Firebase Auth state to RevenueCat by calling `Purchases.logIn(uid)`
/// on sign-in and `Purchases.logOut()` on sign-out.
///
/// Why this matters: without it, Pro purchases attach to RevenueCat's
/// anonymous device-uuid. After a reinstall, the user signs in to the same
/// Firebase account but RevenueCat sees a fresh anonymous customer — the
/// entitlement is invisible until the user manually taps "Restore Purchases".
/// Linking the uid up front makes purchases follow the user across devices
/// and reinstalls.
///
/// Cold-start: [RevenueCatService.configure] already passes the current
/// Firebase uid as `appUserID`, so the very first auth-stream emission is
/// usually a no-op here. This service handles every subsequent sign-in /
/// sign-out during the running session.
class RevenueCatAuthLinkService {
  RevenueCatAuthLinkService({required this.authRepository});

  final AuthRepository authRepository;

  StreamSubscription<AuthUser?>? _sub;

  /// The uid currently applied to RevenueCat. `null` means logged-out
  /// (anonymous appUserID). Used to short-circuit no-op stream rebuilds.
  String? _appliedUid;

  /// Activates the listener. Idempotent — calling again while running is a
  /// no-op.
  void start() {
    if (_sub != null) return;
    AppLogger.info('RevenueCatAuthLinkService: starting');
    _sub = authRepository.userStream.listen(_onAuthChange);
  }

  Future<void> _onAuthChange(AuthUser? user) async {
    final uid = (user?.uid.isNotEmpty ?? false) ? user!.uid : null;
    if (uid == _appliedUid) return;

    try {
      if (uid != null) {
        await Purchases.logIn(uid);
        AppLogger.info('RevenueCat: linked to $uid');
      } else {
        await Purchases.logOut();
        AppLogger.info('RevenueCat: signed out (anonymous)');
      }
      _appliedUid = uid;
    } catch (e) {
      // Most likely cause: RevenueCat not yet configured on the very first
      // emission. Configure already sets appUserID itself, so this is
      // typically harmless — we'll catch up on the next auth change.
      AppLogger.warning('RevenueCat link skipped: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
