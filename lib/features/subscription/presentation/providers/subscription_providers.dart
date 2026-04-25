import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/subscription/data/services/revenuecat_service.dart';
import 'package:prayer_lock/features/subscription/domain/entities/subscription_status.dart';
import 'package:prayer_lock/features/subscription/domain/repositories/subscription_repository.dart';

// ── Service provider ──────────────────────────────────────────────────────────

/// Singleton [RevenueCatService].
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  final service = RevenueCatService();
  ref.onDispose(service.dispose);
  return service;
});

/// [SubscriptionRepository] interface — use this in use-cases and notifiers.
final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return ref.read(revenueCatServiceProvider);
});

// ── Status providers ──────────────────────────────────────────────────────────

/// Live stream of [AppSubscriptionStatus].
///
/// Emits a new value whenever RevenueCat reports a subscription change.
/// Starts as [AsyncLoading] until the first [CustomerInfo] is received.
final subscriptionStatusProvider =
    StreamProvider<AppSubscriptionStatus>((ref) {
  return ref.read(revenueCatServiceProvider).statusStream;
});

/// Live stream of [SubscriptionInfo] — status + plan + product id + expiry.
///
/// Use this when the consumer needs to know which plan the user is on
/// (e.g. the Firestore subscription-record sync).
final subscriptionInfoProvider = StreamProvider<SubscriptionInfo>((ref) {
  return ref.read(revenueCatServiceProvider).infoStream;
});

/// Convenience provider — true when the user has an active pro subscription.
///
/// Defaults to false while the status is loading or unknown.
final isProProvider = Provider<bool>((ref) {
  return ref
      .watch(subscriptionStatusProvider)
      .maybeWhen(
        data: (status) => status.isPro,
        orElse: () => false,
      );
});
