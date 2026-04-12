import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';

/// Domain interface for subscription management backed by RevenueCat.
abstract class SubscriptionRepository {
  /// The most recently known subscription status.
  AppSubscriptionStatus get currentStatus;

  /// Convenience shortcut — true only when the user is an active subscriber.
  bool get isPro;

  /// Emits the updated [AppSubscriptionStatus] whenever RevenueCat reports a
  /// customer-info change.
  Stream<AppSubscriptionStatus> get statusStream;

  /// Initiates a direct purchase for the given [planId].
  ///
  /// [planId] must be `'monthly'` or `'lifetime'` — mapped to the matching
  /// RevenueCat [PackageType] in the current offering. Resolves silently if
  /// the user cancels. Throws on network / billing errors so the caller can
  /// surface them.
  Future<void> purchase(String planId);

  /// Attempts to restore previous purchases and updates [statusStream].
  Future<void> restorePurchases();

  /// Release internal resources (stream controllers, etc.).
  void dispose();
}
