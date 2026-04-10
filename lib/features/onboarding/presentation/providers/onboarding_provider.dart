import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kOnboardingCompleted = 'onboarding_completed_v1';

/// Returns true if the user has already completed onboarding.
final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleted) ?? false;
});

final onboardingNotifierProvider = Provider<OnboardingNotifier>((ref) {
  return OnboardingNotifier(ref);
});

class OnboardingNotifier {
  OnboardingNotifier(this._ref);
  final Ref _ref;

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingCompleted, true);
    _ref.invalidate(onboardingCompletedProvider);
  }
}
