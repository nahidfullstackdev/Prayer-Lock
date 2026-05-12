import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:prayer_lock/core/utils/logger.dart';
import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';
import 'package:prayer_lock/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Concrete implementation of [SubscriptionRepository] backed by RevenueCat
/// (purchases_flutter).
///
/// ── Singleton ─────────────────────────────────────────────────────────────
/// A singleton so the same listener registered in [configure] keeps
/// [statusStream] / [infoStream] live for the lifetime of the app.
///
/// ── Setup checklist ───────────────────────────────────────────────────────
/// 1. Replace [_iosApiKey] / [_androidApiKey] with your RevenueCat API keys.
/// 2. In the RevenueCat dashboard, create an entitlement named [_entitlementId]
///    and attach your App Store / Google Play subscription products to it.
class RevenueCatService implements SubscriptionRepository {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  // ── API keys — replace with your RevenueCat dashboard keys ────────────────
  static const String _iosApiKey = 'test_YnSLhYtBinlzKfezdNwXLkeBlWl';
  static const String _androidApiKey = 'goog_YElbyJRfgPtKfRfvklcOyYwkScA';

  /// Must match the entitlement identifier in RevenueCat dashboard.
  static const String _entitlementId = 'pro';

  // ── Internal state ─────────────────────────────────────────────────────────
  final StreamController<AppSubscriptionStatus> _statusController =
      StreamController<AppSubscriptionStatus>.broadcast();
  final StreamController<SubscriptionInfo> _infoController =
      StreamController<SubscriptionInfo>.broadcast();

  AppSubscriptionStatus _currentStatus = AppSubscriptionStatus.unknown;
  SubscriptionInfo _currentInfo = SubscriptionInfo.unknown;

  /// Cached store-product identifiers for the weekly / annual packages,
  /// captured from the current offering during [configure]. Used to map an
  /// active entitlement's `productIdentifier` to a [SubscriptionPlan].
  String? _weeklyProductId;
  String? _annualProductId;

  /// Resolves to true once [configure] has finished successfully, or false
  /// if it failed. Lets UI gate the upgrade button so the user gets a clear
  /// message instead of a generic "purchase failed" later.
  static final Completer<bool> _configReadyCompleter = Completer<bool>();
  static Future<bool> get configReady => _configReadyCompleter.future;

  // ── Static initialiser ─────────────────────────────────────────────────────

  /// Configure the RevenueCat SDK. Called from `AppInitializer.runDeferred`
  /// after Firebase Auth has rehydrated, so [FirebaseAuth.instance.currentUser]
  /// reflects the persisted session — we pass that uid as RevenueCat's
  /// `appUserID` to bind the entitlement to the Firebase user from frame 0.
  ///
  /// In-session sign-in / sign-out is handled separately by
  /// [RevenueCatAuthLinkService] via `Purchases.logIn` / `Purchases.logOut`.
  static Future<void> configure() async {
    try {
      final String apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
      final String? firebaseUid = FirebaseAuth.instance.currentUser?.uid;

      final config = PurchasesConfiguration(apiKey);
      if (firebaseUid != null && firebaseUid.isNotEmpty) {
        config.appUserID = firebaseUid;
      }
      await Purchases.configure(config);

      // Keep status in sync for the lifetime of the app.
      Purchases.addCustomerInfoUpdateListener(_instance._onCustomerInfoUpdate);

      // Cache offering product ids before the first status emission so that
      // plan detection is accurate from the start.
      await _instance._cacheOfferingProductIds();

      // Seed initial status immediately.
      try {
        final customerInfo = await Purchases.getCustomerInfo();
        _instance._onCustomerInfoUpdate(customerInfo);
      } catch (e) {
        AppLogger.error('RevenueCat initial getCustomerInfo failed', e);
      }

      AppLogger.info(
        'RevenueCat configured (${Platform.isIOS ? "iOS" : "Android"}) '
        '— appUserID: ${firebaseUid ?? "anonymous"}',
      );
      if (!_configReadyCompleter.isCompleted) {
        _configReadyCompleter.complete(true);
      }
    } catch (e) {
      if (!_configReadyCompleter.isCompleted) {
        _configReadyCompleter.complete(false);
      }
      rethrow;
    }
  }

  Future<void> _cacheOfferingProductIds() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      _weeklyProductId = current?.weekly?.storeProduct.identifier;
      _annualProductId = current?.annual?.storeProduct.identifier;
    } catch (e) {
      AppLogger.warning('RevenueCat getOfferings failed: $e');
    }
  }

  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[_entitlementId];
    final isActive = entitlement != null;

    _currentStatus =
        isActive
            ? AppSubscriptionStatus.active
            : AppSubscriptionStatus.inactive;

    _currentInfo = SubscriptionInfo(
      status: _currentStatus,
      plan:
          isActive
              ? _planFor(entitlement.productIdentifier)
              : SubscriptionPlan.none,
      productIdentifier: entitlement?.productIdentifier,
      expirationDate: _parseDate(entitlement?.expirationDate),
      willRenew: entitlement?.willRenew,
      isInTrial: entitlement?.periodType == PeriodType.trial,
    );

    _statusController.add(_currentStatus);
    _infoController.add(_currentInfo);

    AppLogger.info(
      'Subscription status → ${_currentStatus.name} '
      '(plan: ${_currentInfo.plan.label}, productId: ${_currentInfo.productIdentifier ?? "—"})',
    );
  }

  /// Maps a store product identifier to a [SubscriptionPlan].
  ///
  /// First compares against the cached weekly / annual product ids from the
  /// current RevenueCat offering. Falls back to a substring heuristic so a
  /// plan label is still produced when offerings could not be loaded (e.g.
  /// offline at boot but a cached entitlement is restored).
  SubscriptionPlan _planFor(String productIdentifier) {
    if (_weeklyProductId != null && productIdentifier == _weeklyProductId) {
      return SubscriptionPlan.weekly;
    }
    if (_annualProductId != null && productIdentifier == _annualProductId) {
      return SubscriptionPlan.annual;
    }
    final lower = productIdentifier.toLowerCase();
    if (lower.contains('week')) return SubscriptionPlan.weekly;
    if (lower.contains('annual') || lower.contains('year')) {
      return SubscriptionPlan.annual;
    }
    return SubscriptionPlan.none;
  }

  DateTime? _parseDate(String? iso) {
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  // ── SubscriptionRepository ─────────────────────────────────────────────────

  @override
  AppSubscriptionStatus get currentStatus => _currentStatus;

  @override
  SubscriptionInfo get currentInfo => _currentInfo;

  @override
  bool get isPro => _currentStatus.isPro;

  @override
  Stream<AppSubscriptionStatus> get statusStream => _statusController.stream;

  @override
  Stream<SubscriptionInfo> get infoStream => _infoController.stream;

  /// Fetches the current RevenueCat offering and purchases the package that
  /// matches [planId] (`'weekly'` or `'annual'`). Falls back to the first
  /// available package if no exact match is found.
  ///
  /// Returns `true` only when the `pro` entitlement is active in the resulting
  /// `CustomerInfo`. Returns `false` when the user cancels the store dialog.
  /// Throws when no offering / package is available, or on billing / network
  /// errors — the caller is expected to surface a user-facing message.
  ///
  /// Before talking to the store, ensures RevenueCat's `appUserID` matches the
  /// current Firebase uid. This closes the race between [Purchases.logIn]
  /// (kicked off asynchronously by [RevenueCatAuthLinkService] when auth state
  /// changes) and an immediate post-sign-in purchase.
  @override
  Future<bool> purchase(String planId) async {
    AppLogger.info('RevenueCat purchase (plan: $planId)');

    await _ensureLinkedToCurrentFirebaseUser();

    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null) {
      AppLogger.warning('No current RevenueCat offering available');
      throw const SubscriptionPurchaseException(
        'Subscriptions are not available right now. Please try again later.',
      );
    }

    // Refresh cached product ids opportunistically — the offering may have
    // changed since boot.
    _weeklyProductId = current.weekly?.storeProduct.identifier;
    _annualProductId = current.annual?.storeProduct.identifier;

    Package? package = planId == 'annual' ? current.annual : current.weekly;
    package ??= current.availablePackages.firstOrNull;

    if (package == null) {
      AppLogger.warning('No package found for plan: $planId');
      throw const SubscriptionPurchaseException(
        'The selected plan is not available. Please try a different plan.',
      );
    }

    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfoUpdate(result.customerInfo);
      return result.customerInfo.entitlements.active.containsKey(
        _entitlementId,
      );
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        AppLogger.info('RevenueCat purchase cancelled by user');
        return false;
      }
      AppLogger.error('RevenueCat purchase failed', e);
      rethrow;
    }
  }

  /// Ensures RevenueCat's `appUserID` is linked to the current Firebase user
  /// before initiating a purchase. Idempotent — short-circuits when the ids
  /// already match (the common case once [RevenueCatAuthLinkService] has
  /// caught up). Failures are logged but not rethrown: a stale link is
  /// preferable to blocking the purchase entirely.
  Future<void> _ensureLinkedToCurrentFirebaseUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final currentAppUserId = await Purchases.appUserID;
      if (currentAppUserId != uid) {
        await Purchases.logIn(uid);
        AppLogger.info('RevenueCat: re-linked to $uid before purchase');
      }
    } catch (e) {
      AppLogger.warning('Failed to verify RevenueCat link before purchase: $e');
    }
  }

  @override
  Future<void> restorePurchases() async {
    AppLogger.info('RevenueCat restorePurchases');
    try {
      final customerInfo = await Purchases.restorePurchases();
      _onCustomerInfoUpdate(customerInfo);
    } catch (e) {
      AppLogger.error('RevenueCat restorePurchases failed', e);
    }
  }

  @override
  void dispose() {
    _statusController.close();
    _infoController.close();
  }
}
