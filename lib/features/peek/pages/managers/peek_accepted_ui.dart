// lib/features/peek/pages/managers/peek_accepted_ui.dart
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:peek/theme/colors.dart';
import 'peek_accepted_celebration_manager.dart';

class PeekAcceptedUI {
  Widget buildBody({
    required BuildContext context,
    required ConfettiController celebrationController,
    required String backgroundImagePath,
  }) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // Background Image
        Image.asset(
          backgroundImagePath,
          fit: BoxFit.cover,
        ),

        // Confetti Animation
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: celebrationController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: PeekAcceptedCelebrationManager.numberOfParticles,
            gravity: PeekAcceptedCelebrationManager.gravity,
            emissionFrequency: PeekAcceptedCelebrationManager.emissionFrequency,
            colors: PeekAcceptedCelebrationManager.confettiColors,
          ),
        ),

        // Main Content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Image
                Image.asset(
                  'assets/images/yes.png',
                  width: 260,
                  height: 260,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback in case the image fails to load
                    return const Icon(
                      Icons.check_circle_outline,
                      color: peekPrimaryColor,
                      size: 350,
                    );
                  },
                ),

                const Text(
                  "Peek Accepted!",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: peekWhiteColor,
                  ),
                ),

                const SizedBox(height: 15),

                // Subtitle
                Text(
                  'Some one in the World...',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: peekWhiteColor.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
