import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class PeekFeedbackPage extends StatefulWidget {
  final String requestId;

  const PeekFeedbackPage({super.key, required this.requestId});

  @override
  State<PeekFeedbackPage> createState() => _PeekFeedbackPageState();
}

class _PeekFeedbackPageState extends State<PeekFeedbackPage> {
  bool _isSubmitting = false; // To disable buttons during Firestore update
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static const String _feedbackTimestampKey = 'feedbackLastPromptTimestamp';

  Future<void> _submitFeedback(String feedbackValue) async {
    if (_isSubmitting) return; // Prevent double taps

    setState(() {
      _isSubmitting = true; // Show loading state/disable buttons
    });

    try {
      // Get reference to the specific peek request document
      final docRef = FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId);

      // Update the document with the feedback field
      await docRef.update({'feedback': feedbackValue});

      debugPrint(
        "[PeekFeedbackPage] Feedback '$feedbackValue' submitted for request ${widget.requestId}",
      );

      // Update SharedPreferences timestamp (keep existing try-catch)
      try {
        final prefs = await SharedPreferences.getInstance();
        final nowMillis = DateTime.now().millisecondsSinceEpoch;
        await prefs.setInt(_feedbackTimestampKey, nowMillis);
        debugPrint("[PeekFeedbackPage] Updated feedbackLastPromptTimestamp.");
      } catch (e) {
        debugPrint(
          "Error updating feedback timestamp in SharedPreferences: $e",
        );
      }

      // Log success analytics (keep existing try-catch)
      try {
        await _analytics.logEvent(
          name: 'peek_feedback_submitted',
          parameters: {
            'request_id_partial': widget.requestId.substring(0, 8),
            'feedback_value': feedbackValue,
          },
        );
        debugPrint("[PeekFeedbackPage] Logged peek_feedback_submitted event.");
      } catch (e) {
        debugPrint("Error logging peek_feedback_submitted event: $e");
      }

      // Navigate home after successful submission
      if (mounted) {
        context.go('/');
      }
    } catch (e, st) {
      // Catch stack trace for better debugging if needed
      debugPrint(
        "❌ [PeekFeedbackPage] Error submitting feedback for ${widget.requestId}: $e\n$st", // Log stack trace too
      );

      // Log failure analytics (keep existing try-catch)
      try {
        await _analytics.logEvent(
          name: 'peek_feedback_failed',
          parameters: {
            'request_id_partial': widget.requestId.substring(0, 8),
            'feedback_value': feedbackValue,
            'error': e.toString().substring(
              0,
              99 < e.toString().length ? 99 : e.toString().length,
            ),
          },
        );
        debugPrint("[PeekFeedbackPage] Logged peek_feedback_failed event.");
      } catch (e) {
        debugPrint("Error logging peek_feedback_failed event: $e");
      }

      // --- MODIFICATION: Handle UI feedback and navigate home on error ---
      if (mounted) {
        // 1. Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error submitting feedback. Could not save.',
            ), // Slightly clearer message
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 3), // Let it show briefly
          ),
        );

        // 2. Reset submitting state (still useful visually before nav)
        setState(() {
          _isSubmitting = false;
        });

        // 3. Navigate home after a delay to allow SnackBar visibility
        await Future.delayed(
          const Duration(milliseconds: 3100),
        ); // Wait slightly longer than SnackBar duration
        if (mounted) {
          // Check mounted again after delay
          context.go('/');
        }
        // --- END MODIFICATION ---
      }
    } finally {
      // --- ADDED Finally Block ---
      // Ensure the loading state is always reset, even if an
      // unexpected error occurs or if mounted checks fail above.
      if (mounted && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
        });
      }
      // --- END Finally Block ---
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Keep existing build method ---
    final buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Peek Feedback'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Center(
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
              ElevatedButton.icon(
                onPressed:
                    _isSubmitting ? null : () => _submitFeedback('thanks'),
                icon:
                    _isSubmitting
                        ? Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.thumb_up_alt_outlined),
                label: const Text('Thanks'),
                style: buttonStyle.copyWith(
                  backgroundColor: MaterialStateProperty.resolveWith<Color?>((
                    states,
                  ) {
                    if (states.contains(MaterialState.disabled))
                      return Colors.green.shade800;
                    return Colors.green.shade600;
                  }),
                  foregroundColor: MaterialStateProperty.all(Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : () => _submitFeedback('skip'),
                icon:
                    _isSubmitting
                        ? Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(right: 8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.grey.shade400,
                          ),
                        )
                        : const Icon(Icons.thumb_down_alt_outlined),
                label: const Text('Skip'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  foregroundColor:
                      _isSubmitting ? Colors.grey.shade600 : Colors.white70,
                  side: BorderSide(
                    color:
                        _isSubmitting ? Colors.grey.shade800 : Colors.white54,
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
      ),
    );
  }
}
