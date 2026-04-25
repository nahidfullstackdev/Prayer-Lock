import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';

/// Domain interface for subscription management backed by RevenueCat.
abstract class SubscriptionRepository {
  /// The most recently known subscription status.
  AppSubscriptionStatus get currentStatus;

  /// The most recently known full [SubscriptionInfo] (status + plan + product
  /// id + expiry). Use this when persisting the subscription record server-side
  /// or when the UI needs to render plan-specific copy.
  SubscriptionInfo get currentInfo;

  /// Convenience shortcut — true only when the user is an active subscriber.
  bool get isPro;

  /// Emits the updated [AppSubscriptionStatus] whenever RevenueCat reports a
  /// customer-info change.
  Stream<AppSubscriptionStatus> get statusStream;

  /// Emits the full [SubscriptionInfo] whenever RevenueCat reports a
  /// customer-info change. Replaces [statusStream] when callers need plan
  /// detail (e.g. to write `subscriptionPlan` to Firestore).
  Stream<SubscriptionInfo> get infoStream;

  /// Initiates a direct purchase for the given [planId].
  ///
  /// [planId] must be `'weekly'` or `'annual'` — mapped to the matching
  /// RevenueCat [PackageType] in the current offering. Resolves silently if
  /// the user cancels. Throws on network / billing errors so the caller can
  /// surface them.
  Future<void> purchase(String planId);

  /// Attempts to restore previous purchases and updates [statusStream].
  Future<void> restorePurchases();

  /// Release internal resources (stream controllers, etc.).
  void dispose();
}
