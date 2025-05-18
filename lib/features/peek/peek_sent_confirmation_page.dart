// lib/features/peek/pages/peek_sent_confirmation_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';

class PeekSentConfirmationPage extends StatefulWidget {
  // Using a common background path, adjust if needed or make it dynamic
  static String pageBackgroundPath = 'assets/images/onboarding_bg_01.jpg';

  const PeekSentConfirmationPage({super.key});

  @override
  State<PeekSentConfirmationPage> createState() =>
      _PeekSentConfirmationPageState();
}

class _PeekSentConfirmationPageState extends State<PeekSentConfirmationPage> {
  Timer? _navigationTimer;
  static const Duration _displayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    debugPrint("[PeekSentConfirmationPage] Initialized.");
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(_displayDuration, () {
      if (mounted) {
        debugPrint(
            "[PeekSentConfirmationPage] Timer elapsed. Navigating to Home ('/').");
        context.go('/'); // Navigate to the home screen
      }
    });
  }

  @override
  void dispose() {
    debugPrint("[PeekSentConfirmationPage] Disposing.");
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: peekBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Layer 1: Background Image ---
          Image.asset(
            PeekSentConfirmationPage.pageBackgroundPath,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                  "[PeekSentConfirmationPage] Error loading background image: $error");
              return Container(color: peekBackgroundColor); // Fallback
            },
          ),
          // --- Optional: Dark Overlay for better text readability ---
          Container(
            color: Colors.black.withOpacity(0.3), // Adjust opacity as needed
          ),
          // --- Centered Content ---
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Animated Icon Placeholder (mimicking PeekAcceptedPage) ---
                  // You can replace this with a Lottie animation for "Sent"
                  Container(
                    width: 120,
                    height: 120,
                    padding:
                        const EdgeInsets.all(20), // Padding around the icon
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: peekPrimaryColor.withOpacity(1),
                      // color: peekPrimaryColor.withOpacity(0.15),
                      // ------------ Border remove for now
                      // border: Border.all(
                      //   color: peekPrimaryColor.withOpacity(0.5),
                      //   width: 2,
                      // )
                    ),
                    child: const Icon(
                      Icons.mms,
                      color: peekBackgroundColor,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Main Confirmation Text ---
                  const Text(
                    "Peek Sent!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32, // Slightly smaller than "Peek Accepted!"
                      fontWeight: FontWeight.w600,
                      color: peekWhiteColor,
                      // shadows: [
                      //   Shadow(
                      //     blurRadius: 4.0,
                      //     color: Colors.black54,
                      //     offset: Offset(2.0, 2.0),
                      //   ),
                      // ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Optional: Sub-text ---
                  Text(
                    "Your Peek is on its way!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: peekWhiteColor.withOpacity(0.85),
                      shadows: [
                        Shadow(
                          blurRadius: 3.0,
                          color: Colors.black45,
                          offset: Offset(1.0, 1.0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40), // Space at the bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
