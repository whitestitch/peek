// lib/features/onboarding/providers/onboarding_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String onboardingCompleteKey = 'onboardingComplete';

// Provider to check if onboarding is complete (reads once)
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(onboardingCompleteKey) ?? false;
});

// Provider/Notifier to manage setting onboarding as complete
final onboardingNotifierProvider = NotifierProvider<OnboardingNotifier, void>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<void> {
  @override
  void build() {
    // No initial state needed for a notifier that just performs actions
  }

  /// Marks onboarding as complete in SharedPreferences.
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(onboardingCompleteKey, true);
      print("[OnboardingNotifier] Onboarding marked as complete.");
      // Invalidate the FutureProvider so subsequent reads get the new value
      ref.invalidate(onboardingCompleteProvider);
    } catch (e) {
      print("❌ Error saving onboarding completion status: $e");
      // Handle error appropriately, maybe log it
    }
  }

  /// DEBUG ONLY: Resets onboarding completion status.
  Future<void> resetOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(onboardingCompleteKey);
      print("[OnboardingNotifier] DEBUG: Onboarding status reset.");
      ref.invalidate(onboardingCompleteProvider);
    } catch (e) {
      print("❌ Error resetting onboarding status: $e");
    }
  }
}
