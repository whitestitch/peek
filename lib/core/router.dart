// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/core/providers.dart';
import 'package:peek/features/peek/pages/peek_sender_wait_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:peek/features/home/home_page.dart';
import 'package:peek/features/onboarding/pages/onboarding_page.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/features/onboarding/terms_acceptance_screen.dart';
import 'package:peek/features/splash/splash_start.dart';
import 'package:peek/features/settings/settings_page.dart';
import 'package:peek/features/stats/pages/stats_page.dart';

import 'package:peek/core/widgets/app_shell.dart';

import 'package:peek/features/menu/about_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/peek/pages/peek_receiver_page.dart';
import '../features/peek/peek_image_view.dart';
import '../features/peek/pages/peek_wait_page.dart';
import '../features/peek/pages/peek_feedback_page.dart';
import '../features/peek/pages/peek_accepted_page.dart';
import '../features/peek/peek_declined_page.dart';
import '../features/peek/peek_timed_out_page.dart';
import '../features/auth/upgrade_account.dart';
import '../features/premium/pages/premium_page.dart';
import '../features/menu/privacy_page.dart';
import '../features/peek/reaction_screen.dart';
import 'package:peek/main.dart';

// Helper provider to ensure sign-in is only triggered once.
final _signInTriggeredProvider = StateProvider<bool>((ref) => false);

const List<String> routesInShellWithoutAppBar = ['/settings'];

const List<String> routesInShellWithoutBottomNav = [];

// Routes without AppShell
const List<String> routesWithoutShell = [
  '/terms',
  '/onboarding',
  '/receive',
  '/capture',
  '/peek-accepted',
  '/peek-declined',
  '/peek-timed-out',
  '/splash',
  '/peek-image',
  '/peek-reaction',
  '/wait',
  '/peek-feedback',
  '/upgrade',
  '/premium',
  '/privacy',
  '/info',
];

// Shell navigator key
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  // Trigger router re-evaluation on auth state changes
  final refreshTick = ValueNotifier<int>(0);

  ref.listen(authStateProvider, (previous, next) {
    refreshTick.value++;
  });

  ref.listen(userDocumentProvider, (prev, next) {
    refreshTick.value++;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refreshTick,
    initialLocation: '/splash-start',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      final userDocument = ref.read(userDocumentProvider);

      if (authState.isLoading || authState.hasError) {
        return null;
      }

      final isLoggedIn = authState.valueOrNull != null;
      final onSplash = state.matchedLocation == '/splash-start';

      // Not logged in - trigger anonymous sign-in
      if (!isLoggedIn) {
        if (onSplash) {
          if (!ref.read(_signInTriggeredProvider)) {
            Future(() {
              ref.read(_signInTriggeredProvider.notifier).state = true;
              FirebaseAuth.instance.signInAnonymously();
            });
          }
          return null;
        }
        return '/splash-start';
      }

      // User document not ready - return to splash
      if (userDocument.isLoading ||
          userDocument.hasError ||
          !userDocument.hasValue) {
        return onSplash ? null : '/splash-start';
      }

      // If we are here, isLoggedIn is true. Now check for the onboarding flow.
      final prefs = await SharedPreferences.getInstance();

      // if (isLoggedIn) {
      //   final uid = authState.valueOrNull!.uid;
      //   try {
      //     final userDoc = await FirebaseFirestore.instance
      //         .collection('users')
      //         .doc(uid)
      //         .get();

      final termsAccepted = prefs.getBool('termsAccepted') ?? false;
      final onboardingComplete = prefs.getBool(onboardingCompleteKey) ?? false;

      final currentPath = state.matchedLocation;

      if (!termsAccepted) {
        return currentPath == '/terms' ? null : '/terms';
      }

      if (!onboardingComplete) {
        return currentPath == '/onboarding' ? null : '/onboarding';
      }

      if (onboardingComplete && onSplash) {
        return '/';
      }

      // Otherwise, no redirection is needed.
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash-start',
        builder: (context, state) => const SplashStartPage(),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) => const TermsAcceptanceScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) =>
            AppShell(routerState: state, child: child),
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/stats',
            name: 'stats',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: StatsPage()),
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SettingsPage()),
          ),
          // GoRoute(
          //   path: '/onboarding',
          //   name: 'onboarding',
          //   pageBuilder: (context, state) =>
          //       const NoTransitionPage(child: OnboardingPage()),
          // ),
        ],
      ),

      // SPACE

      // GoRoute(
      //   path: '/onboarding',
      //   name: 'onboarding',
      //   builder: (context, state) => const OnboardingPage(),
      // ),
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
          final mode = state.uri.queryParameters['mode'] ?? 'response';
          return requestId != null
              ? PhotoCapturePage(requestId: requestId, mode: mode)
              : _errorScreen('❌ Missing requestId');
        },
      ),
      GoRoute(
        path: '/peek-accepted',
        name: 'peek-accepted',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId']!;
          // MODIFIED: imageUrl is no longer needed or passed to PeekAcceptedPage.
          return PeekAcceptedPage(
            requestId: requestId,
          );
        },
      ),
      GoRoute(
        path: '/peek-sender-wait',
        name: 'peek-sender-wait',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId for sender wait page');
          }
          return PeekSenderWaitPage(requestId: requestId);
        },
      ),
      GoRoute(
        path: '/peek-declined',
        name: 'peek-declined',
        builder: (context, state) => const PeekDeclinedPage(),
      ),
      GoRoute(
        path: '/peek-timed-out',
        name: 'peek-timed-out',
        builder: (context, state) => const PeekTimedOutPage(),
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
        pageBuilder: (context, state) {
          final params = state.extra as Map<String, dynamic>?;
          final requestId = params?['requestId'] as String?;
          final imageUrl = params?['imageUrl'] as String?;
          final senderLocation = params?['senderLocation'] as String?;

          if (requestId == null || imageUrl == null) {
            return MaterialPage(
              key: state.pageKey,
              child: _errorScreen(
                  '❌ Missing requestId or imageUrl for PeekImageView'),
            );
          }
          return CustomTransitionPage(
            key: state.pageKey,
            child: PeekImageView(
              requestId: requestId,
              imageUrl: imageUrl,
              senderLocation: senderLocation,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
            reverseTransitionDuration: const Duration(milliseconds: 250),
          );
        },
      ),
      GoRoute(
        path: '/peek-reaction',
        name: 'peekReaction',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final originalSenderUid =
              state.uri.queryParameters['originalSenderUid'];

          // MODIFIED: Remove imageUrl extraction and check
          // final imageUrl = state.uri.queryParameters['imageUrl'];

          if (requestId == null || originalSenderUid == null) {
            // MODIFIED: Simplified check
            debugPrint(
                "[Router] Error: Missing parameters for ReactionScreen. RequestId: $requestId, OriginalSenderUid: $originalSenderUid");
            return _errorScreen('Error: Missing reaction data.');
          }
          return ReactionScreen(
            requestId: requestId,
            originalSenderUid: originalSenderUid,
            // MODIFIED: Do not pass imageUrl here
          );
        },
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
        name: 'info',
        builder: (_, __) => const AboutPage(),
      ),
      GoRoute(
        path: '/link',
        name: 'link',
        redirect: (context, state) {
          debugPrint("🔗 [GoRouter] Handling dynamic link: ${state.uri}");
          return '/';
        },
      ),
    ],
  );
});

Widget _errorScreen(String message) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text("Error"), leading: const BackButton()),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: const TextStyle(fontSize: 18, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}
