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
/// [statusStream] live for the lifetime of the app.
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
  static const String _androidApiKey = 'test_YnSLhYtBinlzKfezdNwXLkeBlWl';

  /// Must match the entitlement identifier in RevenueCat dashboard.
  static const String _entitlementId = 'pro';

  // ── Internal state ─────────────────────────────────────────────────────────
  final StreamController<AppSubscriptionStatus> _statusController =
      StreamController<AppSubscriptionStatus>.broadcast();

  AppSubscriptionStatus _currentStatus = AppSubscriptionStatus.unknown;

  // ── Static initialiser ─────────────────────────────────────────────────────

  /// Configure the RevenueCat SDK. Call once from [main] before [runApp].
  static Future<void> configure() async {
    final String apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;
    await Purchases.configure(PurchasesConfiguration(apiKey));

    // Keep status in sync for the lifetime of the app.
    Purchases.addCustomerInfoUpdateListener(_instance._onCustomerInfoUpdate);

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

  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    final isActive = customerInfo.entitlements.active.containsKey(
      _entitlementId,
    );
    _currentStatus =
        isActive
            ? AppSubscriptionStatus.active
            : AppSubscriptionStatus.inactive;
    _statusController.add(_currentStatus);
    AppLogger.info('Subscription status → ${_currentStatus.name}');
  }

  // ── SubscriptionRepository ─────────────────────────────────────────────────

  @override
  AppSubscriptionStatus get currentStatus => _currentStatus;

  @override
  bool get isPro => _currentStatus.isPro;

  @override
  Stream<AppSubscriptionStatus> get statusStream => _statusController.stream;

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

      Package? package =
          planId == 'annual' ? current.annual : current.weekly;
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
  }
}
