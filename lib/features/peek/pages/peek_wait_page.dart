import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Assuming peek_controller.dart exists and defines peekControllerProvider
// Adjust the import path if necessary
import 'package:peek/features/peek/controllers/peek_controller.dart';

/// Waits for acceptance from a receiver; on accept, routes into SplashPage.
/// Navigates home on rejection or timeout.
class PeekWaitPage extends ConsumerStatefulWidget {
  final String requestId;
  const PeekWaitPage({super.key, required this.requestId});

  @override
  ConsumerState<PeekWaitPage> createState() => _PeekWaitPageState();
}

class _PeekWaitPageState extends ConsumerState<PeekWaitPage> {
  StreamSubscription<DocumentSnapshot>? _sub; // Firestore listener subscription
  Timer? _timeoutTimer; // Timer to handle lack of response
  bool _hasTimedOut = false; // Flag to track if timeout occurred
  bool _navigated = false; // Flag to prevent multiple navigation calls

  @override
  void initState() {
    super.initState();
    // Set a fallback timeout (e.g., 30 seconds) for the receiver to respond
    _timeoutTimer = Timer(const Duration(seconds: 30), _onTimeout);
    _listenForPeek(); // Start listening for updates on the peek request
    debugPrint("[PeekWaitPage] Initialized for request ${widget.requestId}");
  }

  /// Listens to the Firestore document for status changes ('accepted', 'rejected', 'timeout').
  void _listenForPeek() {
    _sub = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (snap) {
            // Ensure widget is still mounted and data exists before processing
            if (!mounted || !snap.exists || _navigated) return;

            final data = snap.data();
            if (data == null) {
              debugPrint(
                "⚠️ [PeekWaitPage] Snapshot data is null for ${widget.requestId}.",
              );
              _handleInternalError("Peek data disappeared unexpectedly.");
              // Maybe navigate home with error? Or just keep listening?
              // For now, just return and wait for next update.
              return;
            }

            final status = data['status'] as String?;
            final imageUrl =
                data['imageUrl'] as String?; // Get the URL if present

            debugPrint(
              "[PeekWaitPage] Listener update: status=$status, imageUrl=${imageUrl != null ? 'present' : 'null'}",
            );

            // Handle different statuses
            switch (status) {
              case 'accepted':
                // Ensure imageUrl is valid before navigating
                // --- START MODIFICATION ---
                // Only proceed if the image URL is actually present and valid.
                // If status is 'accepted' but URL is missing, just wait for the next snapshot.
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  debugPrint(
                    "[PeekWaitPage] Status 'accepted' and imageUrl present. Navigating.",
                  );
                  _goToSplash(imageUrl); // Navigate to splash screen
                } else {
                  // Status is 'accepted', but URL isn't here YET. This is likely an intermediate
                  // state during the Firestore update. Just wait for the next snapshot update.
                  debugPrint(
                    "[PeekWaitPage] Status 'accepted' but imageUrl missing/empty. Waiting for next update...",
                  );
                  // REMOVED: _handleInternalError("Received Peek was incomplete.");
                }
                // --- END MODIFICATION ---
                break;
              case 'rejected':
                _onRejected(); // Handle rejection
                break;
              case 'timeout':
                _onTimeout(); // Handle explicit timeout status from Firestore
                break;
              case 'pending':
              default:
                // Still waiting, do nothing.
                break;
            }
          },
          onError: (e) {
            // Log listener errors but don't necessarily crash
            debugPrint(
              '❌ [PeekWaitPage] Listener error for ${widget.requestId}: $e',
            );
            if (mounted && !_navigated) {
              // Optionally show an error message and navigate away
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Connection error while waiting. Please try again.',
                  ),
                  backgroundColor:
                      Colors.orangeAccent, // orange for connection issue?
                ),
              );
              _cancelAll(); // Stop timers/listeners
              _navigated = true;
              context.go('/');
            }
          },
          onDone: () {
            debugPrint(
              "[PeekWaitPage] Listener stream closed for ${widget.requestId}.",
            );
            // This might happen if the document is deleted externally
            // If not already navigated, maybe go home?
            if (mounted && !_navigated) {
              context.go('/');
            }
          },
        );
  }

  /// Handles navigation and cleanup when the peek request times out locally or via Firestore status.
  void _onTimeout() {
    if (!mounted || _hasTimedOut || _navigated)
      return; // Prevent multiple calls
    debugPrint(
      "[PeekWaitPage] Timeout reached for request ${widget.requestId}.",
    );

    _navigated = true; // Set navigation flag early
    _cancelAll(); // Stop listening and local timeout timer

    // Update UI to show timeout message immediately
    // Use setState only if the widget is still mounted (though _navigated should prevent further builds)
    if (mounted) {
      setState(() => _hasTimedOut = true);
    }

    // Attempt to mark the request as expired in Firestore via controller
    // Do this in the background, don't wait for it.
    ref
        .read(peekControllerProvider.notifier)
        .expirePeek(widget.requestId)
        .catchError(
          (e) => debugPrint('⚠️ [PeekWaitPage] expirePeek error: $e'),
        );

    // Navigate home after showing the timeout message for a few seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        // Check mounted again before navigation
        context.go('/');
      }
    });
  }

  /// Navigates to the SplashPage when the peek is accepted and image URL is available.
  void _goToSplash(String imageUrl) {
    if (!mounted || _navigated) return; // Prevent multiple calls
    debugPrint(
      "[PeekWaitPage] Peek accepted. Navigating to SplashPage with imageUrl: $imageUrl",
    );
    _navigated = true; // Set navigation flag
    _cancelAll(); // Stop listening and timeout timer

    // --- FIX: Pass imageUrl directly to queryParameters ---
    // GoRouter and Uri handle necessary encoding for the query parameter context.
    final uri = Uri(
      path: '/splash',
      queryParameters: {
        'requestId': widget.requestId,
        // Pass the RAW imageUrl string.
        'initialImageUrl': imageUrl,
      },
    );
    // --- End of Fix ---

    // Navigate using the constructed URI
    context.go(uri.toString());
  }

  /// Handles navigation when the peek request is rejected by the receiver.
  void _onRejected() {
    if (!mounted || _navigated) return; // Prevent multiple calls
    debugPrint("[PeekWaitPage] Peek rejected for request ${widget.requestId}.");
    _navigated = true; // Set navigation flag
    _cancelAll(); // Stop listening and timeout timer

    // Show a confirmation message to the user
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User was not ready to Peek.')),
    );
    // Navigate back home
    context.go('/');
  }

  /// Handles unexpected internal errors during listening.
  void _handleInternalError(String message) {
    if (!mounted || _navigated) return;
    debugPrint("❌ [PeekWaitPage] Internal Error: $message");
    _navigated = true;
    _cancelAll();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Something went wrong ($message). Returning home.',
        ), // Simplified msg
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) {
        context.go('/');
      }
    });
  }
  // ---> END OF NEW METHOD <---

  /// Cancels the Firestore listener and the timeout timer.
  void _cancelAll() {
    debugPrint(
      "[PeekWaitPage] Cancelling listener and timer for ${widget.requestId}.",
    );
    _sub?.cancel();
    _sub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    debugPrint("[PeekWaitPage] Disposing for request ${widget.requestId}.");
    _cancelAll(); // Ensure resources are cleaned up
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the content based on the timeout state
    Widget bodyContent =
        _hasTimedOut
            // Show timeout message if _hasTimedOut is true
            ? const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '😔 No one is available to Peek right now.\nTry again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            )
            // Otherwise, show the waiting indicator
            : const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 24),
                Text(
                  '👀 Waiting for someone to Peek…',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.redAccent, // Consider using theme color
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );

    return Scaffold(
      backgroundColor:
          Colors.black, // Or use Theme.of(context).scaffoldBackgroundColor
      // Optional: Add AppBar if needed for cancellation
      // appBar: AppBar(
      //   title: const Text("Waiting..."),
      //   leading: IconButton(
      //     icon: const Icon(Icons.close),
      //     onPressed: () {
      //        // Implement cancellation logic if desired
      //        _cancelAll();
      //        _navigated = true; // Prevent listener nav
      //        // Maybe update Firestore status to 'cancelled'?
      //        context.go('/');
      //     },
      //   ),
      // ),
      body: Center(child: bodyContent),
    );
  }
}
