// lib/features/peek/peek_accepted_page.dart
import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart' as material;
import 'package:go_router/go_router.dart';
import 'package:peek/theme/colors.dart';

class PeekAcceptedPage extends material.StatefulWidget {
  final String requestId;
  static String pageBackgroundPath = 'assets/images/peek_accepted_bg.jpg';

  const PeekAcceptedPage({
    material.Key? key,
    required this.requestId,
  }) : super(key: key);

  @override
  material.State<PeekAcceptedPage> createState() => _PeekAcceptedPageState();
}

class _PeekAcceptedPageState extends material.State<PeekAcceptedPage> {
  Timer? _navigationTimer;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    material
        .debugPrint("[PeekAcceptedPage] Initialized for 3-second celebration.");

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
    _confettiController.play();

    // After 3 seconds, navigate to the new waiting page.
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        material.debugPrint(
            "[PeekAcceptedPage] Celebration finished. Navigating to sender wait page.");
        context.go('/peek-sender-wait?requestId=${widget.requestId}');
      }
    });
  }

  @override
  void dispose() {
    material.debugPrint("[PeekAcceptedPage] Disposing.");
    _navigationTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor: peekBackgroundColor,
      body: material.Stack(
        fit: material.StackFit.expand,
        alignment: material.Alignment.center,
        children: [
          material.Image.asset(
            PeekAcceptedPage.pageBackgroundPath,
            fit: material.BoxFit.cover,
          ),
          material.Align(
            alignment: material.Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 25,
              gravity: 0.2,
              emissionFrequency: 0.05,
              colors: const [
                peekPrimaryColor,
                peekSecondaryColor,
                peekAccentColor,
              ],
            ),
          ),
          material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(20.0),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                children: [
                  material.Image.asset(
                    'assets/images/yes.png',
                    width: 260,
                    height: 260,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback in case the image fails to load
                      return const material.Icon(
                        material.Icons.check_circle_outline,
                        color: peekPrimaryColor,
                        size: 350,
                      );
                    },
                  ),
                  // const material.SizedBox(height: 32),
                  const material.Text(
                    "Peek Accepted!",
                    style: material.TextStyle(
                      fontSize: 32,
                      fontWeight: material.FontWeight.w600,
                      color: peekWhiteColor,
                    ),
                  ),

                  const material.SizedBox(height: 15),

                  // Subtitle
                  material.Text(
                    'Some one in the World...',
                    style: material.Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: peekWhiteColor.withOpacity(0.85)),
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
