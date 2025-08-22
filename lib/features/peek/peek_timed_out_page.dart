// lib/features/peek/peek_timed_out_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart'; // Assuming your color constants

class PeekTimedOutPage extends material.StatefulWidget {
  static const String pageBackgroundPath = 'assets/images/onboarding_bg_02.jpg';

  const PeekTimedOutPage({material.Key? key})
      : super(key: key); // <<< MAKE SURE THIS IS PeekTimedOutPage

  @override
  material.State<PeekTimedOutPage> createState() => _PeekTimedOutPageState();
}

class _PeekTimedOutPageState extends material.State<PeekTimedOutPage> {
  Timer? _navigationTimer;
  static const Duration _displayDuration = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    material.debugPrint("[PeekTimedOutPage] Initialized.");
    _startNavigationTimer();
  }

  void _startNavigationTimer() {
    _navigationTimer = Timer(_displayDuration, () {
      if (mounted) {
        material.debugPrint(
            "[PeekTimedOutPage] Timer elapsed. Navigating to home.");
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    material.debugPrint("[PeekTimedOutPage] Disposing.");
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor: peekBackgroundColor,
      body: material.Stack(
        fit: material.StackFit.expand,
        children: [
          material.Image.asset(
            PeekTimedOutPage.pageBackgroundPath,
            fit: material.BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              material.debugPrint(
                  "[PeekTimedOutPage] Error loading background image: $error");
              return material.Container(color: peekBackgroundColor);
            },
          ),
          material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(20.0),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  material.Icon(
                    material.Icons.timer_off_outlined,
                    color: peekWhiteColor.withValues(alpha: 0.7),
                    size: 80,
                  ),
                  const material.SizedBox(height: 32),
                  const material.Text(
                    "No one to Peek now!",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 28,
                      fontWeight: material.FontWeight.bold,
                      color: peekWhiteColor,
                    ),
                  ),
                  const material.SizedBox(height: 16),
                  material.Text(
                    "Your Peek request timed out.\nMaybe try again later?",
                    textAlign: material.TextAlign.center,
                    style: material.TextStyle(
                      fontSize: 16,
                      color: peekWhiteColor.withValues(alpha: 0.8),
                      height: 1.4,
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
