// lib/features/peek/peek_accepted_page.dart
import 'dart:async';
import 'package:flutter/material.dart'
    as material; // Using alias for consistency
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart'; // Assuming your color constants are here

class PeekAcceptedPage extends material.StatefulWidget {
  final String requestId;
  final String imageUrl;

  static String pageBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

  const PeekAcceptedPage({
    material.Key? key, // Use material.Key
    required this.requestId,
    required this.imageUrl,
  }) : super(key: key);

  @override
  material.State<PeekAcceptedPage> createState() => _PeekAcceptedPageState();
}

class _PeekAcceptedPageState extends material.State<PeekAcceptedPage> {
  Timer? _navigationTimer;
  // Duration for this screen before automatically navigating
  static const Duration _displayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    material.debugPrint(
        "[PeekAcceptedPage] Initialized for request ${widget.requestId}");
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(_displayDuration, () {
      if (mounted) {
        material.debugPrint(
            "[PeekAcceptedPage] Timer elapsed. Navigating to SplashPage.");
        // Construct the URI for SplashPage
        final uri = Uri(
          path: '/splash', // Path for SplashPage
          queryParameters: {
            'requestId': widget.requestId,
            'initialImageUrl': widget.imageUrl,
          },
        );
        context.go(uri.toString());
      }
    });
  }

  @override
  void dispose() {
    material.debugPrint(
        "[PeekAcceptedPage] Disposing for request ${widget.requestId}.");
    _navigationTimer?.cancel(); // Cancel the timer if the widget is disposed
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor:
          peekBackgroundColor, // Fallback if image fails or for transitions
      body: material.Stack(
        // Use Stack to layer widgets
        fit: material.StackFit.expand, // Make the Stack fill the screen
        children: [
          // --- Layer 1: Background Image ---
          material.Image.asset(
            PeekAcceptedPage.pageBackgroundPath, // Use defined path
            fit: material.BoxFit.cover, // Cover the entire area
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint(
                  "[PeekAcceptedPage] Error loading background image: $error");
              // Fallback solid color if image fails
              return material.Container(color: peekBackgroundColor);
            },
          ),
          // --- Primary Animation Placeholder ---
          // TODO: Replace this with your Lottie animation or other visual
          material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(20.0),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  // --- Primary Animation Placeholder ---
                  material.Container(
                    width: 120,
                    height: 120,
                    decoration: const material.BoxDecoration(
                      color: peekPrimaryColor,
                      shape: material.BoxShape.circle,
                    ),
                    child: const material.Icon(
                      material.Icons.timelapse,
                      color: peekBackgroundColor,
                      size: 60,
                    ),
                  ),
                  const material.SizedBox(height: 32),

                  // --- Main Confirmation Text ---
                  const material.Text(
                    "Peek Accepted!",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 32,
                      fontWeight: material.FontWeight.bold,
                      color: peekWhiteColor,
                      // Optional: Add a shadow for better readability over varied backgrounds
                      // shadows: [
                      //   material.Shadow(
                      //     blurRadius: 4.0,
                      //     color: material.Colors.black.withOpacity(0.5),
                      //     offset: material.Offset(2.0, 2.0),
                      //   ),
                      // ],
                    ),
                  ),
                  const material.SizedBox(height: 16),

                  // --- Optional: Sub-text ---
                  material.Text(
                    "Get ready, your Peek is on its way!",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 18,
                      color: peekWhiteColor.withOpacity(
                          0.9), // Slightly more opaque for readability
                      // Optional: Add a shadow
                      // shadows: [
                      //   material.Shadow(
                      //     blurRadius: 3.0,
                      //     color: material.Colors.black.withOpacity(0.5),
                      //     offset: material.Offset(1.0, 1.0),
                      //   ),
                      // ],
                    ),
                  ),
                  const material.SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
