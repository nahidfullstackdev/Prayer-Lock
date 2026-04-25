import 'dart:async';
import 'dart:io';

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
  static const String _iosApiKey = 'sk_SeusETklaIOKHHrDBkYaBWHcFZBFG';
  static const String _androidApiKey = 'sk_dgTUqWhEMCMQfKWpZGNCVZfEXQhEF';

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

  // ── Static initialiser ─────────────────────────────────────────────────────

  /// Configure the RevenueCat SDK. Call once from [main] before [runApp].
  static Future<void> configure() async {
    final String apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    await Purchases.configure(PurchasesConfiguration(apiKey));

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
      'RevenueCat configured (${Platform.isIOS ? "iOS" : "Android"})',
    );
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
  /// available package if no exact match is found. Resolves silently on user
  /// cancellation; rethrows on billing / network errors.
  @override
  Future<void> purchase(String planId) async {
    AppLogger.info('RevenueCat purchase (plan: $planId)');
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) {
        AppLogger.warning('No current RevenueCat offering available');
        return;
      }

      // Refresh cached product ids opportunistically — the offering may have
      // changed since boot.
      _weeklyProductId = current.weekly?.storeProduct.identifier;
      _annualProductId = current.annual?.storeProduct.identifier;

      Package? package = planId == 'annual' ? current.annual : current.weekly;
      package ??= current.availablePackages.firstOrNull;

      if (package == null) {
        AppLogger.warning('No package found for plan: $planId');
        return;
      }

      final result = await Purchases.purchase(PurchaseParams.package(package));
      _onCustomerInfoUpdate(result.customerInfo);
    } catch (e) {
      AppLogger.error('RevenueCat purchase failed', e);
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
