import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prayer_lock/features/auth/presentation/providers/auth_providers.dart';
import 'package:prayer_lock/features/subscription/data/services/revenuecat_auth_link_service.dart';
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

/// Long-lived bridge that mirrors Firebase Auth state into RevenueCat by
/// calling `Purchases.logIn(uid)` on sign-in and `Purchases.logOut()` on
/// sign-out. Read once at app start (from `MuslimCompanionApp.build`) so the
/// underlying stream subscription stays active for the lifetime of the
/// [ProviderContainer].
///
/// See [RevenueCatAuthLinkService] for the rationale (purchase persistence
/// across reinstalls and devices).
final revenueCatAuthLinkServiceProvider = Provider<RevenueCatAuthLinkService>((
  ref,
) {
  final service = RevenueCatAuthLinkService(
    authRepository: ref.read(authRepositoryProvider),
  )..start();
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
/// Use this when the consumer needs plan metadata beyond the boolean
/// `isProProvider` (e.g. rendering plan-specific copy in the paywall or
/// showing the renewal date in account screens).
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

/// Resolves once `RevenueCatService.configure()` completes — true on success,
/// false on failure (caught by `AppInitializer._guard`). Loading state means
/// configure is still running in deferred init.
///
/// The paywall watches this so the upgrade button can be disabled with a clear
/// message if subscriptions are unavailable, instead of failing opaquely after
/// the user taps it.
final revenueCatReadyProvider = FutureProvider<bool>((ref) {
  return RevenueCatService.configReady;
});
