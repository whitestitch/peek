import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Core Screens
import '../features/home/home_page.dart';
import '../features/peek/peeking_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/peek/peek_receiver_page.dart';
import '../features/peek/peek_image_view.dart';
import '../features/peek/pages/peek_wait_page.dart';

// Auth & Premium
import '../features/auth/upgrade_account.dart';
import '../features/premium/premium_page.dart';

// Menu Pages
import '../features/menu/privacy_page.dart';
import '../features/menu/about_page.dart';

/// Centralized app router using GoRouter and the root navigator key from main.dart
GoRouter createRouter(GlobalKey<NavigatorState> rootNavigatorKey) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      /// 🏠 Home
      GoRoute(path: '/', name: 'home', builder: (_, __) => const HomePage()),

      /// 👁 Peeking Flow: requester waits for response
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

      /// 📡 Receiver listens for incoming Peek
      GoRoute(
        path: '/receive',
        name: 'receive',
        builder: (_, __) => const PeekReceiverPage(),
      ),

      /// 📷 After receiver accepts: capture a photo
      GoRoute(
        path: '/capture',
        name: 'capture',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId');
          }
          return PhotoCapturePage(requestId: requestId);
        },
      ),

      /// 💧 After upload: splash & countdown
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final imageUrl = state.uri.queryParameters['imageUrl'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId');
          }
          return SplashPage(requestId: requestId, initialImageUrl: imageUrl);
        },
      ),

      /// 🕒 Fallback wait if no one responds in time
      GoRoute(
        path: '/wait',
        name: 'wait',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId');
          }
          return PeekWaitPage(requestId: requestId);
        },
      ),

      /// 🖼 Finally, display the peeked image
      GoRoute(
        path: '/peek-image',
        name: 'peek-image',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return _errorScreen('❌ Missing requestId');
          }
          return PeekImageView(requestId: requestId);
        },
      ),

      /// 🔐 Upgrade anonymous user
      GoRoute(
        path: '/upgrade',
        name: 'upgrade',
        builder: (_, __) => const UpgradeAccountPage(),
      ),

      /// 💎 Premium subscription page
      GoRoute(
        path: '/premium',
        name: 'premium',
        builder: (_, __) => const PremiumPage(),
      ),

      /// 🔒 Privacy policy
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (_, __) => const PrivacyPage(),
      ),

      /// ℹ️ About page
      GoRoute(
        path: '/info',
        name: 'about',
        builder: (_, __) => const AboutPage(),
      ),
    ],
  );
}

/// Shared fallback widget for missing or invalid parameters.
Widget _errorScreen(String message) {
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
