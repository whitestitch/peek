// lib/features/peek/pages/managers/peek_accepted_celebration_manager.dart
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:peek/theme/colors.dart';

class PeekAcceptedCelebrationManager {
  late final ConfettiController _confettiController;

  PeekAcceptedCelebrationManager() {
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));
  }

  ConfettiController get confettiController => _confettiController;

  void startCelebration() {
    _confettiController.play();
  }

  void stopCelebration() {
    _confettiController.stop();
  }

  void dispose() {
    _confettiController.dispose();
  }

  // Confetti configuration constants
  static const List<Color> confettiColors = [
    peekPrimaryColor,
    peekSecondaryColor,
    peekAccentColor,
  ];

  static const double gravity = 0.2;
  static const double emissionFrequency = 0.05;
  static const int numberOfParticles = 25;
}
