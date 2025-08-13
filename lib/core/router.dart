// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/core/providers.dart';
import 'package:peek/features/peek/pages/peek_sender_wait_page.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- Feature Page Imports ---
import 'package:peek/features/home/home_page.dart';
import 'package:peek/features/onboarding/pages/onboarding_page.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';
import 'package:peek/features/onboarding/terms_acceptance_screen.dart';
import 'package:peek/features/splash/splash_start.dart';
import 'package:peek/features/settings/settings_page.dart';
import 'package:peek/features/stats/pages/stats_page.dart';

// --- App Shell and other top-level pages ---
import 'package:peek/core/widgets/app_shell.dart';
import 'package:peek/features/auth/auth_wrapper.dart';
import 'package:peek/services/terms_service.dart';

// All other pages
import 'package:peek/features/menu/about_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/peek/peek_receiver_page.dart';
import '../features/peek/peek_image_view.dart';
import '../features/peek/pages/peek_wait_page.dart';
import '../features/peek/pages/peek_feedback_page.dart';
import '../features/peek/peek_accepted_page.dart';
import '../features/peek/peek_declined_page.dart';
import '../features/peek/peek_timed_out_page.dart';
import '../features/auth/upgrade_account.dart';
import '../features/premium/pages/premium_page.dart';
import '../features/menu/privacy_page.dart';
import '../features/peek/reaction_screen.dart';
import '../features/peek/peek_sent_confirmation_page.dart';
import 'package:peek/main.dart';

// Helper provider to ensure sign-in is only triggered once.
final _signInTriggeredProvider = StateProvider<bool>((ref) => false);

// HIDE TOP APPBAR WIDGET
const List<String> routesInShellWithoutAppBar = [
  // Example: if '/settings/profile-edit' was a child of ShellRoute and needed a custom AppBar or no AppBar
  // '/settings/profile-edit',
  // '/stats',
  '/settings'
];

// List of route paths (CHILDREN of ShellRoute) where the AppShell's BottomNavigationBar should be hidden.
// (This was your existing routesInShellWithoutBottomNav, keeping its purpose for BottomNav)
const List<String> routesInShellWithoutBottomNav = [
  // Example:
  // '/settings/full-screen-subpage',
];

// List of TOP-LEVEL route paths that should NOT use the AppShell at all.
// These routes will not have the AppShell's AppBar or BottomNavigationBar.
// (This was your existing routesWithoutShell)
const List<String> routesWithoutShell = [
  '/terms',
  '/onboarding',
  '/receive',
  '/capture',
  '/peek-accepted',
  '/peek-declined',
  '/peek-timed-out',
  '/peek-sent-confirmation',
  '/splash',
  '/peek-image',
  '/peek-reaction',
  '/wait',
  '/peek-feedback',
  '/upgrade',
  '/premium',
  // If /privacy and /info are full-screen and don't need the shell, they belong here.
  // If they are part of the shell (e.g. opened from drawer, want AppBar/BottomNav),
  // they should be child routes of ShellRoute.
  // For now, assuming they are top-level full-screen as per previous setup.
  '/privacy',
  '/info',
];

// This list is now less critical if AppShell directly uses routesInShellWithoutBottomNav
// and routesInShellWithoutAppBar. It was originally for HomePage to manage its own BottomNav.
// If AppShell uses the more specific lists above, this one might become redundant or serve a different purpose.
// For clarity, the AppShell will use the new specific lists.
const List<String> routesWithoutBottomNav = [
  '/terms',
  '/onboarding',
  '/receive',
  '/capture',
  '/peek-accepted',
  '/peek-declined',
  '/peek-timed-out',
  '/peek-sent-confirmation',
  '/splash',
  '/peek-image',
  '/peek-reaction',
  '/wait',
  '/peek-feedback',
  '/upgrade',
  '/premium',
  '/privacy',
  '/info',
  // '/settings', // Settings is now part of ShellRoute, AppShell controls its AppBar/BottomNav
  // '/stats',    // Stats is now part of ShellRoute
];

// final rootNavigatorKey = GlobalKey<NavigatorState>();
// This key is for the shell navigator.
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// final rootNavigatorKeyProvider =
//     Provider<GlobalKey<NavigatorState>>((ref) => rootNavigatorKey);

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  // This ValueNotifier will trigger the router to re-evaluate its redirects
  // whenever the authentication state changes. This is the key to the fix.
  // Use a simple tick so we always notify (even if auth value is "equal").
  final refreshTick = ValueNotifier<int>(0);
  final refreshListenable = ValueNotifier<AsyncValue<User?>>(authState);

  // Update the listenable when auth state changes
  ref.listen(authStateProvider, (previous, next) {
    debugPrint("🔄 Auth state changed in router - updating refresh listenable");
    refreshTick.value++;
  });

  // Also refresh when the user document readiness changes,
  // so we can leave /splash-start as soon as the doc exists.
  ref.listen(userDocumentProvider, (prev, next) {
    debugPrint("🔄 User document changed - refreshing router redirects");
    // Bump the same notifier; ValueNotifier notifies even with the same value.
    // Force a notify regardless of equality.
    refreshTick.value++;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: refreshTick,
    initialLocation: '/splash-start',
    debugLogDiagnostics: true,
    redirect: (context, state) async {
      // Watch the initialization provider.
      final userDocument = ref.read(userDocumentProvider);

      debugPrint(
          "🔄 Router redirect called - location: ${state.matchedLocation}");
      debugPrint(
          "🔄 Auth state: loading=${authState.isLoading}, hasError=${authState.hasError}, value=${authState.valueOrNull?.uid}");

      // While auth state is loading, show the splash screen.
      if (authState.isLoading || authState.hasError) {
        debugPrint(
            "🔄 Auth still loading or has error, staying on current location");
        return null; // Returning null from redirect preserves the current location
      }

      final isLoggedIn = authState.valueOrNull != null;
      final onSplash = state.matchedLocation == '/splash-start';

      // Case A: NOT logged in → keep on splash and trigger anon sign-in once
      if (!isLoggedIn) {
        if (onSplash) {
          if (!ref.read(_signInTriggeredProvider)) {
            Future(() {
              ref.read(_signInTriggeredProvider.notifier).state = true;
              FirebaseAuth.instance.signInAnonymously();
            });
          }
          return null; // stay on splash while sign-in happens
        }
        return '/splash-start';
      }

      // Case B: Logged in but user doc not ready → keep/return to splash
      if (userDocument.isLoading ||
          userDocument.hasError ||
          !userDocument.hasValue) {
        debugPrint(
            "🔄 Gatekeeper: Logged in but user document not ready (loading=${userDocument.isLoading}, hasError=${userDocument.hasError}, hasValue=${userDocument.hasValue}). Staying on/returning to splash.");
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

      //     if (!userDoc.exists) {
      //       debugPrint("🔄 Creating user document in router for $uid");
      //       await FirebaseFirestore.instance.collection('users').doc(uid).set({
      //         'uid': uid,
      //         'displayName': 'User ${uid.substring(0, 6)}',
      //         'createdAt': FieldValue.serverTimestamp(),
      //         'isPremium': false,
      //         'dailyPeekCount': 0,
      //         'isAnonymous': authState.valueOrNull!.isAnonymous,
      //       });
      //     }
      //   } catch (e) {
      //     debugPrint("🔄 Error creating user doc in router: $e");
      //   }
      // }

      final termsAccepted = prefs.getBool('termsAccepted') ?? false;
      final onboardingComplete = prefs.getBool(onboardingCompleteKey) ?? false;
      final onAuthFlow = state.matchedLocation == '/terms' ||
          state.matchedLocation == '/onboarding';

      final currentPath = state.matchedLocation;

      if (!termsAccepted) {
        // return onAuthFlow ? null : '/terms';
        return currentPath == '/terms' ? null : '/terms';
      }

      if (!onboardingComplete) {
        // return onAuthFlow ? null : '/onboarding';
        return currentPath == '/onboarding' ? null : '/onboarding';
      }

      // If the user is fully set up and is on any of the initial screens, go to home.
      // if (onSplash || onAuthFlow) {
      //   return '/';
      // }
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
          return requestId != null
              ? PhotoCapturePage(requestId: requestId)
              : _errorScreen('❌ Missing requestId');
        },
      ),
      GoRoute(
        path: '/peek-accepted',
        name: 'peek-accepted',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId']!;
          // MODIFIED: imageUrl is no longer needed or passed to PeekAcceptedPage.
          // final imageUrl = state.uri.queryParameters['imageUrl']!;
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
        path: '/peek-sent-confirmation',
        name: 'peekSentConfirmation',
        builder: (context, state) => const PeekSentConfirmationPage(),
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
