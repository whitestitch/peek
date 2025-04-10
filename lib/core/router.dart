import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home/home_page.dart';
import '../features/peek/peeking_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/peek/splash_page.dart';
import '../features/auth/upgrade_account.dart';
import '../features/peek/peek_receiver_page.dart';

final router = GoRouter(
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return '/'; // fallback for unauthenticated
    }
    return null;
  },
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
      path: '/splash',
      builder: (context, state) {
        final requestId = state.uri.queryParameters['requestId'];
        final imageUrl = state.uri.queryParameters['imageUrl'];
        if (requestId == null || imageUrl == null) {
          return const Scaffold(
            body: Center(child: Text('❌ Missing required parameters')),
          );
        }
        return SplashPage(requestId: requestId);
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
      path: '/receive',
      builder: (context, state) => const PeekReceiverPage(),
    ),

    GoRoute(
      path: '/upgrade',
      builder: (context, state) => const UpgradeAccountPage(),
    ),
  ],
);
