import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';

/// Domain interface for subscription management.
///
/// The concrete implementation ([SuperwallService]) wraps the Superwall SDK
/// and optionally delegates purchases to RevenueCat via a PurchaseController.
abstract class SubscriptionRepository {
  /// The most recently known subscription status.
  AppSubscriptionStatus get currentStatus;

  /// Convenience shortcut — true only when the user is an active subscriber.
  bool get isPro;

  /// Emits the updated [AppSubscriptionStatus] whenever the underlying
  /// purchase or paywall SDK reports a change.
  Stream<AppSubscriptionStatus> get statusStream;

  /// Registers a Superwall *placement* (previously called an "event").
  ///
  /// Superwall will evaluate the placement rules configured in the dashboard
  /// and, if eligible, present the appropriate paywall. Safe to call
  /// regardless of whether the user is already subscribed — Superwall handles
  /// the hold-out logic.
  ///
  /// [placement] must match the placement identifier created in the Superwall
  /// dashboard (e.g. `'campaign_trigger'`, `'feature_locked'`).
  Future<void> register(String placement);

  /// Attempts to restore previous purchases.
  ///
  /// When using RevenueCat as the [PurchaseController], this delegates to
  /// `Purchases.restorePurchases()`. Status stream will emit the updated
  /// status once restoration completes.
  Future<void> restorePurchases();

  /// Release internal resources (stream controllers, etc.).
  void dispose();
}
