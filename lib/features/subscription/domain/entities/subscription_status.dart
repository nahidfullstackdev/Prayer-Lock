/// App-level subscription status, independent of any third-party SDK.
enum AppSubscriptionStatus {
  /// Status has not yet been determined (e.g. on first launch before SDK response).
  unknown,

  /// User holds an active pro subscription.
  active,

  /// User has no active subscription.
  inactive;

  /// Convenience: true only when the user is an active subscriber.
  bool get isPro => this == AppSubscriptionStatus.active;
}

/// Billing cadence of the active Pro subscription.
///
/// Mirrors the two RevenueCat packages exposed in the paywall: weekly and
/// annual. [none] is used when the user is not subscribed (or status is
/// [AppSubscriptionStatus.unknown]).
enum SubscriptionPlan {
  weekly,
  annual,
  none;

  /// Stable lower-case string used when persisting to Firestore.
  String get label => switch (this) {
        SubscriptionPlan.weekly => 'weekly',
        SubscriptionPlan.annual => 'annual',
        SubscriptionPlan.none => 'none',
      };
}

/// Snapshot of the user's subscription as reported by RevenueCat.
///
/// Carries enough detail to persist a complete subscription record in
/// Firestore: status, plan, store product id, expiry, renewal flag, and trial
/// flag. All trailing fields are nullable because they are unavailable while
/// the user is not subscribed.
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.status,
    required this.plan,
    this.productIdentifier,
    this.expirationDate,
    this.willRenew,
    this.isInTrial,
  });

  final AppSubscriptionStatus status;
  final SubscriptionPlan plan;
  final String? productIdentifier;
  final DateTime? expirationDate;
  final bool? willRenew;
  final bool? isInTrial;

  /// Initial value before the first CustomerInfo callback arrives.
  static const SubscriptionInfo unknown = SubscriptionInfo(
    status: AppSubscriptionStatus.unknown,
    plan: SubscriptionPlan.none,
  );

  bool get isPro => status.isPro;
}
