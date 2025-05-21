// lib/core/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/menu/about_page.dart';

// --- Imports exactly as you provided ---
import '../features/home/home_page.dart';
// import '../features/peek/peeking_page.dart';
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
import '../features/menu/about_page.dart';
// import '../features/menu/drawer_menu.dart';
// ** Import the new Settings Page **
import '../features/settings/settings_page.dart';
import '../features/onboarding/pages/onboarding_page.dart';
import '../features/peek/reaction_screen.dart';
import '../features/stats/pages/stats_page.dart';
import '../features/peek/peek_sent_confirmation_page.dart';
import '../core/widgets/app_shell.dart';

// This key is for the Navigator within the ShellRoute
// final GlobalKey<NavigatorState> _shellNavigatorKey =
//     GlobalKey<NavigatorState>(debugLabel: 'shell');
final GlobalKey<NavigatorState> shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

// HIDE TOP APPBAR WIDGET
const List<String> routesInShellWithoutAppBar = [
  // Example: if '/settings/profile-edit' was a child of ShellRoute and needed a custom AppBar or no AppBar
  // '/settings/profile-edit',
  '/stats',
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

GoRouter createRouter(GlobalKey<NavigatorState> rootNavigatorKey,
    {String initialLocation = '/'}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation, // Use the parameter here
    debugLogDiagnostics: true,
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (BuildContext context, GoRouterState state, Widget child) {
          // The AppShell widget builds the Scaffold with BottomNavigationBar
          // 'child' is the widget for the current nested route (e.g., HomePage, StatsPage)
          return AppShell(routerState: state, child: child);
        },
        routes: <RouteBase>[
          // Child routes of the ShellRoute
          GoRoute(
            path: '/',
            name: 'home',
            pageBuilder: (context, state) => const NoTransitionPage(
              // Avoid transitions between shell tabs
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: '/stats',
            name: 'stats',
            pageBuilder: (context, state) => const NoTransitionPage(
              // pageBuilder: (context, state) => const NoTransitionPage(
              child: StatsPage(),
            ),
          ),
          GoRoute(
            path: '/settings', // Settings is now part of the shell
            name: 'settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsPage(),
            ),
          ),
        ],
      ),

      // NONE SHELL/ROUT
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // GoRoute(
      //   path: '/peek/:requestId',
      //   name: 'peeking',
      //   builder: (context, state) {
      //     final requestId = state.pathParameters['requestId'];
      //     if (requestId == null) {
      //       return _errorScreen('❌ Missing requestId');
      //     }
      //     return PeekingPage(requestId: requestId);
      //   },
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
          final imageUrl = state.uri.queryParameters['imageUrl']!;
          return PeekAcceptedPage(requestId: requestId, imageUrl: imageUrl);
        },
      ),

      GoRoute(
        path: '/peek-declined', // Corrected path to match navigation call
        name: 'peek-declined',
        builder: (context, state) {
          // PeekDeclinedPage does not require requestId or imageUrl
          return const PeekDeclinedPage();
        },
      ),

      GoRoute(
        path: '/peek-timed-out', // Path for the new timed-out page
        name: 'peek-timed-out', // Route name
        builder: (context, state) {
          // This page doesn't require parameters from the route
          return const PeekTimedOutPage();
        },
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
        path: '/peek-reaction',
        name: 'peekReaction',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final originalSenderUid =
              state.uri.queryParameters['originalSenderUid'];
          final imageUrl =
              state.uri.queryParameters['imageUrl']; // <-- Add this

          if (requestId == null ||
              originalSenderUid == null ||
              imageUrl == null) {
            // <-- Check imageUrl too
            debugPrint(
                "[Router] Error: Missing parameters for ReactionScreen. RequestId: $requestId, OriginalSenderUid: $originalSenderUid, ImageUrl: $imageUrl");
            return _errorScreen('Error: Missing reaction data.');
          }
          return ReactionScreen(
            requestId: requestId,
            originalSenderUid: originalSenderUid,
            imageUrl: imageUrl, // <-- Pass it to ReactionScreen
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
      // GoRoute(
      //   path: '/info',
      //   name: 'about',
      //   builder: (_, __) => const AboutPage(),
      // ),
      // GoRoute(
      //   path: '/settings',
      //   name: 'settings',
      //   builder: (context, state) => const SettingsPage(),
      // ),
      // GoRoute(
      //   path: '/stats',
      //   name: 'stats',
      //   builder: (context, state) => const StatsPage(),
      // ),
    ],
  );
}

Widget _errorScreen(String message) {
  return Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
        // Added AppBar to error screen for consistency
        title: const Text("Error"),
        leading: BackButton(
          onPressed: () {
            // For now, relies on default pop behavior or manual handling if needed.
          },
        )),
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
