import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Existing Pages
import '../features/home/home_page.dart';
import '../features/peek/peeking_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/peek/peek_receiver_page.dart';
import '../features/peek/peek_image_view.dart';
import '../features/auth/upgrade_account.dart';

// Drawer / Premium Pages
import '../features/premium/premium_page.dart';
import '../features/menu/privacy_page.dart';
import '../features/menu/about_page.dart';

GoRouter createRouter(GlobalKey<NavigatorState> rootNavigatorKey) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomePage()),

      GoRoute(
        path: '/peek/:requestId',
        builder: (context, state) {
          final requestId = state.pathParameters['requestId']!;
          return PeekingPage(requestId: requestId);
        },
      ),

      GoRoute(
        path: '/capture',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return const Scaffold(
              body: Center(child: Text('❌ Missing requestId')),
            );
          }
          return PhotoCapturePage(requestId: requestId);
        },
      ),

      GoRoute(
        path: '/splash',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          if (requestId == null) {
            return const Scaffold(
              body: Center(child: Text('❌ Missing requestId')),
            );
          }
          return SplashPage(requestId: requestId);
        },
      ),

      GoRoute(
        path: '/peek-image',
        builder: (context, state) {
          final requestId = state.uri.queryParameters['requestId'];
          final imageUrl = state.uri.queryParameters['imageUrl'];
          if (requestId == null || imageUrl == null) {
            return const Scaffold(
              body: Center(child: Text('❌ Missing requestId or imageUrl')),
            );
          }
          return PeekImageView(requestId: requestId, imageUrl: imageUrl);
        },
      ),

      GoRoute(
        path: '/receive',
        builder: (context, state) => const PeekReceiverPage(),
      ),
      GoRoute(
        path: '/upgrade',
        builder: (context, state) => const UpgradeAccountPage(),
      ),
      GoRoute(
        path: '/premium',
        builder: (context, state) => const PremiumPage(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(path: '/info', builder: (context, state) => const AboutPage()),
    ],
  );
}
