// lib/features/peek/pages/managers/peek_sender_wait_ui.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peek/theme/colors.dart';

class PeekSenderWaitUI {
  static const String _backgroundImagePath = 'assets/images/wait_peek_bg.jpg';
  static const String _logoPath = 'assets/images/peekio_eye.svg';

  PreferredSizeWidget buildAppBar({required VoidCallback onCancel}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: 'Cancel Peek',
          onPressed: onCancel,
        ),
      ],
    );
  }

  Widget buildBody({
    required BuildContext context,
    required int? secondsRemaining,
    required AnimationController animationController,
  }) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        // Background Image
        Image.asset(
          _backgroundImagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(color: peekBackgroundColor);
          },
        ),

        // Main Content
        Center(
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Spinning Logo
                RotationTransition(
                  turns: animationController,
                  child: SvgPicture.asset(
                    _logoPath,
                    width: 120,
                    height: 120,
                  ),
                ),

                const SizedBox(height: 32),

                // Title
                Text(
                  'Get Ready!',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 32,
                        color: peekWhiteColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 15),

                // Subtitle
                Text(
                  'Your Peek is on its way...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: peekWhiteColor.withValues(alpha: 0.85),
                      ),
                ),

                const SizedBox(height: 15),

                // Countdown Display
                if (secondsRemaining != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$secondsRemaining',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: peekWhiteColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> showTimeoutDialog(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 24),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: peekBackgroundColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(48, 48, 24, 100),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_off_outlined,
                      size: 60, color: Colors.white70),
                  const SizedBox(height: 20),
                  const Text(
                    "Time's Up!",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "The other user didn't take a photo in time.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peekSecondaryColor,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 24 + 8,
              right: 12,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        );
      },
    );
  }
}
