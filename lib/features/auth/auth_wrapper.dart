import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/core/widgets/peek_loading_indicator.dart';
import 'package:peek/core/providers.dart';
import 'package:peek/features/home/home_page.dart';
import 'package:peek/features/onboarding/pages/onboarding_page.dart';

/// The AuthWrapper widget acts as a gatekeeper. It listens to the auth state
/// and displays the correct UI based on whether a user is logged in, logged out,
/// or if the state is still loading.
class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the provider that listens to auth state changes.

    final authState = ref.watch(authStateProvider);

    // Use .when to gracefully handle all possible states: loading, error, and data.
    return authState.when(
      data: (user) {
        // If the user object is not null, the user is authenticated.
        if (user != null) {
          // Show the main application screen.
          return const HomePage();
        } else {
          // If user is null, they are not logged in.
          // Show the onboarding/login flow.
          // Note: Your router will handle redirecting from Onboarding to Terms if needed.
          return const OnboardingPage();
        }
      },
      // While the auth state is being determined, show a loading spinner.
      loading: () => const Scaffold(
        body: Center(
          child: PeekLoadingIndicator.medium(),
        ),
      ),
      // If there's an error fetching the auth state, show an error message.
      error: (err, stack) => Scaffold(
        body: Center(
          child: Text('An error occurred: $err'),
        ),
      ),
    );
  }
}
