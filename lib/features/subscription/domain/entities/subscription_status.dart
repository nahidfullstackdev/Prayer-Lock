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
