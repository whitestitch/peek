// lib/features/peek/pages/managers/peek_feedback_ui.dart
import 'package:flutter/material.dart';

class PeekFeedbackUI {
  PreferredSizeWidget buildAppBar() {
    return AppBar(
      title: const Text('Peek Feedback'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
    );
  }

  Widget buildBody({
    required bool isSubmitting,
    required Function(String) onFeedbackSubmit,
  }) {
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Did you like the Peek?',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Thanks Button
            ElevatedButton.icon(
              onPressed: isSubmitting ? null : () => onFeedbackSubmit('thanks'),
              icon: isSubmitting
                  ? _buildButtonIcon(isSubmitting, Colors.white)
                  : const Icon(Icons.thumb_up_alt_outlined),
              label: const Text('Thanks'),
              style: buttonStyle.copyWith(
                backgroundColor:
                    WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.disabled)) {
                    return Colors.green.shade800;
                  }
                  return Colors.green.shade600;
                }),
                foregroundColor: WidgetStateProperty.all(Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // Skip Button
            OutlinedButton.icon(
              onPressed: isSubmitting ? null : () => onFeedbackSubmit('skip'),
              icon: isSubmitting
                  ? _buildButtonIcon(isSubmitting, Colors.grey.shade400)
                  : const Icon(Icons.thumb_down_alt_outlined),
              label: const Text('Skip'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                foregroundColor:
                    isSubmitting ? Colors.grey.shade600 : Colors.white70,
                side: BorderSide(
                  color: isSubmitting ? Colors.grey.shade800 : Colors.white54,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonIcon(bool isSubmitting, Color color) {
    if (isSubmitting) {
      return Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 8),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: color,
        ),
      );
    }

    // Return appropriate icon based on button type
    // This will be handled by the calling code
    return const SizedBox.shrink();
  }

  void showErrorSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Error submitting feedback. Could not save.',
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
