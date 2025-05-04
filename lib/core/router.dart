// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- Imports exactly as you provided ---
import '../features/home/home_page.dart';
import '../features/peek/peeking_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/peek/peek_receiver_page.dart';
import '../features/peek/peek_image_view.dart';
import '../features/peek/pages/peek_wait_page.dart';
import '../features/peek/pages/peek_feedback_page.dart';
import '../features/auth/upgrade_account.dart';
import '../features/premium/pages/premium_page.dart';
import '../features/menu/privacy_page.dart';
import '../features/menu/about_page.dart';
import '../features/menu/drawer_menu.dart';
// ** Import the new Settings Page **
import '../features/settings/settings_page.dart';
import '../features/onboarding/pages/onboarding_page.dart';

GoRouter createRouter(GlobalKey<NavigatorState> rootNavigatorKey,
    {String initialLocation = '/'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation, // Use the parameter here
    debugLogDiagnostics: true,
    routes: [
      // --- Routes exactly as you provided ---
      GoRoute(path: '/', name: 'home', builder: (_, __) => const HomePage()),

      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      GoRoute(
        path: '/peek/:requestId',
        name: 'peeking',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId');
          }
          return PeekingPage(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/receive',
        name: 'receive',
        builder: (_, __) => const PeekReceiverPage(),
      ),
      GoRoute(
        path: '/capture',
        name: 'capture',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          return requestId != null
              ? PhotoCapturePage(requestId: requestId)
              : _errorScreen('❌ Missing requestId');
        },
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final imageUrl = state.uri.queryParameters['initialImageUrl'] ??
              state.uri.queryParameters['imageUrl'];
          if (requestId == null) return _errorScreen('❌ Missing requestId');
          return SplashPage(requestId: requestId, initialImageUrl: imageUrl);
        },
      ),
      GoRoute(
        path: '/peek-image',
        name: 'peek-image',
        // --- Use pageBuilder instead of builder ---
        pageBuilder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final imageUrl = state.uri.queryParameters['imageUrl'];
          if (requestId == null || imageUrl == null) {
            // IMPORTANT: Handle error case properly within pageBuilder
            // Option 1: Return a standard page with the error screen
            return MaterialPage(
              // Or CupertinoPage
              key: state.pageKey,
              child: _errorScreen('❌ Missing requestId or imageUrl'),
            );
            // Option 2: Navigate away or throw (less ideal for pageBuilder)
          }

          // --- Define the Custom Transition ---
          return CustomTransitionPage(
            key: state.pageKey, // Use state.pageKey for efficient rebuilds
            child: PeekImageView(requestId: requestId, imageUrl: imageUrl),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              // Example: Fade Transition
              return FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                child: child,
              );
              // Example: Slide Transition (from bottom)
              // return SlideTransition(
              //   position: Tween<Offset>(
              //     begin: const Offset(0.0, 1.0),
              //     end: Offset.zero,
              //   ).chain(CurveTween(curve: Curves.easeOut)).animate(animation),
              //   child: child,
              // );
            },
            transitionDuration: const Duration(
              milliseconds: 300,
            ), // Adjust duration
            reverseTransitionDuration: const Duration(
              milliseconds: 250,
            ), // Optional reverse duration
          );
        },
        // --- Remove the old builder ---
        // builder: (context, state) { ... },
      ),
      GoRoute(
        path: '/wait',
        name: 'wait',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          return requestId != null
              ? PeekWaitPage(requestId: requestId)
              : _errorScreen('❌ Missing requestId');
        },
      ),
      GoRoute(
        path: '/peek-feedback',
        name: 'peek-feedback',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId for feedback');
          }
          return PeekFeedbackPage(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/upgrade',
        name: 'upgrade',
        builder: (_, __) => const UpgradeAccountPage(),
      ),
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (_, __) => const PeekPremiumPage(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (_, __) => const PrivacyPage(),
      ),
      GoRoute(
        path: '/info',
        name: 'about',
        builder: (_, __) => const AboutPage(),
      ),

      // --- ✨ ADDED SETTINGS ROUTE ---
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsPage(),
      ),
      // --- END ADDED ROUTE ---
    ],
  );
}

Widget _errorScreen(String message) {
  // --- _errorScreen exactly as you provided ---
  return Scaffold(
    backgroundColor: Colors.black,
    body: Center(
      child: Text(
        message,
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    ),
  );
}
