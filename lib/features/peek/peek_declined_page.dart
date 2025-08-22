// lib/features/peek/peek_declined_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart'; // Assuming your color constants

class PeekDeclinedPage extends material.StatefulWidget {
  // Define your background image path here
  // Example:

  static String pageBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

  const PeekDeclinedPage({material.Key? key}) : super(key: key);

  @override
  material.State<PeekDeclinedPage> createState() => _PeekDeclinedPageState();
}

class _PeekDeclinedPageState extends material.State<PeekDeclinedPage> {
  Timer? _navigationTimer;
  static const Duration _displayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    material.debugPrint("[PeekDeclinedPage] Initialized.");
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(_displayDuration, () {
      if (mounted) {
        material.debugPrint(
            "[PeekDeclinedPage] Timer elapsed. Navigating to home.");
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    material.debugPrint("[PeekDeclinedPage] Disposing.");
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor: peekBackgroundColor, // Fallback if image fails
      body: material.Stack(
        // Use Stack to layer widgets
        fit: material.StackFit.expand, // Make the Stack fill the screen
        children: [
          // --- Layer 1: Background Image ---
          material.Image.asset(
            PeekDeclinedPage.pageBackgroundPath, // Use defined path
            fit: material.BoxFit.cover, // Cover the entire area
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint(
                  "[PeekDeclinedPage] Error loading background image: $error");
              // Fallback solid color if image fails
              return material.Container(color: peekBackgroundColor);
            },
          ),

          // --- Layer 2: Optional Dimming Overlay ---
          // material.Container(
          //   color: material.Colors.black.withOpacity(0.4), // Adjust opacity as needed
          // ),

          // --- Layer 3: Main Content ---
          material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(20.0),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  // --- Visual Element Placeholder ---
                  material.Icon(
                    material.Icons.sentiment_very_dissatisfied_outlined,
                    color: peekWhiteColor.withValues(alpha: 0.7),
                    size: 80,
                  ),
                  const material.SizedBox(height: 32),

                  // --- Main Message ---
                  const material.Text(
                    "Peek Declined",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 28,
                      fontWeight: material.FontWeight.bold,
                      color: peekWhiteColor,
                      // Optional: Add a shadow for better readability
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
                    "They weren't ready to Peek this time.\nReturning to home...",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 16,
                      color: peekWhiteColor.withValues(
                          alpha: 0.8), // Slightly more opaque
                      height: 1.4,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
