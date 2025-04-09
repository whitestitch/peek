import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/home/home_page.dart';
import '../features/peek/peeking_page.dart';
import '../features/peek/photo_capture_page.dart';
import '../features/auth/upgrade_account.dart';
import '../features/peek/peek_receiver_page.dart';

final router = GoRouter(
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return '/'; // fallback — should never happen due to anon auth
    }
    return null;
  },
  routes: [
    // Home page
    GoRoute(path: '/', builder: (context, state) => const HomePage()),

    // Peeking page (with requestId required)
    GoRoute(
      path: '/peek/:requestId',
      builder: (context, state) {
        final requestId = state.pathParameters['requestId']!;
        return PeekingPage(requestId: requestId);
      },
    ),

    // Photo capture page
    GoRoute(
      path: '/capture',
      builder: (context, state) => const PhotoCapturePage(),
    ),

    // Upgrade account
    GoRoute(
      path: '/upgrade',
      builder: (context, state) => const UpgradeAccountPage(),
    ),

    // Peek receiver page
    GoRoute(
      path: '/receive',
      builder: (context, state) => const PeekReceiverPage(),
    ),
  ],
);
