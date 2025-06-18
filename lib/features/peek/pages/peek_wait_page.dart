import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Assuming peek_controller.dart exists and defines peekControllerProvider
// Adjust the import path if necessary
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:rive/rive.dart'; // <<< Import Rive
import 'package:peek/theme/colors.dart';

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

  static const String _backgroundImagePath = 'assets/images/wait_peek_bg.jpg';
  static const String _riveAnimationPath = 'assets/animations/peek_radar.riv';
  static const String _riveAnimationName = 'peek_radar';

  @override
  void initState() {
    super.initState();
    // Set a fallback timeout (e.g., 30 seconds) for the receiver to respond
    _timeoutTimer = Timer(const Duration(seconds: 30), _onTimeout);
    _listenForPeek(); // Start listening for updates on the peek request
    material.debugPrint(
        "[PeekWaitPage] Initialized for request ${widget.requestId}");
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
          material.debugPrint(
            "⚠️ [PeekWaitPage] Snapshot data is null for ${widget.requestId}.",
          );
          _handleInternalError("Peek data disappeared unexpectedly.");
          // Maybe navigate home with error? Or just keep listening?
          // For now, just return and wait for next update.
          return;
        }

        final status = data['status'] as String?;
        final imageUrl = data['imageUrl'] as String?;
        // You might want to get User B's display name to show in the status message
        // final receiverName = data['receiverDisplayName'] as String?;

        material.debugPrint(
          "[PeekWaitPage] Listener update: status=$status, imageUrl=${imageUrl != null ? 'present' : 'null'}",
        );

        // Handle different statuses
        switch (status) {
          case 'accepted':
            if (imageUrl != null && imageUrl.isNotEmpty) {
              material.debugPrint(
                "[PeekWaitPage] Status 'accepted' AND imageUrl IS PRESENT. Navigating to image confirmation page.",
              );
              // CORRECTED: Navigate to the confirmation page instead of directly to splash.
              _goToImageConfirmationPage(widget.requestId, imageUrl);
            } else {
              // Status is 'accepted', but URL isn't here YET.
              material.debugPrint(
                "[PeekWaitPage] Status 'accepted', but imageUrl is still MISSING. User A remains on PeekWaitPage, listening.",
              );
              // The commented-out block for navigating to /peek-accepted with empty imageUrl
              // was for a different scenario. For this flow, if imageUrl is missing, we just wait.

              // Navigate to PeekAcceptedPage to show "Peek Accepted!" to the SENDER
              // if (mounted && !_navigated) {
              //   _navigated = true;
              //   _cancelAll();
              //   context.go(Uri(
              //     path: '/peek-accepted',
              //     queryParameters: {
              //       'requestId': widget.requestId,
              //       'imageUrl': '',
              //     },
              //   ).toString());
              // }
            }

            break;

          // User B has captured and sent the image.
          case 'responded_with_image':
            if (imageUrl != null && imageUrl.isNotEmpty) {
              material.debugPrint(
                "[PeekWaitPage] Status 'responded_with_image' AND imageUrl IS PRESENT. Navigating to splash.",
              );
              // _goToSplash(imageUrl);
              _goToImageConfirmationPage(widget.requestId, imageUrl);
            } else {
              // This state is unexpected: status implies image is ready, but URL is missing.
              material.debugPrint(
                "⚠️ [PeekWaitPage] Status 'responded_with_image' but imageUrl is MISSING. This is unexpected. Waiting for potential correction or local timeout.",
              );
            }
            break;

          case 'pending_acceptance': // Explicitly handle the initial or intermediate pending state
            material.debugPrint(
              "[PeekWaitPage] Status 'pending_acceptance'. Waiting for User B to respond.",
            );
            // Optionally: Update a UI message here (e.g., "Waiting for User B to accept...")
            break;

          case 'rejected':
          case 'declined':
            _onRejected();
            break;
          case 'timeout':
            _onTimeout();
            break;
          case 'pending':
          default:
            // Still waiting, do nothing.
            break;
        }
      },
      onError: (e) {
        // Log listener errors but don't necessarily crash
        material.debugPrint(
          '❌ [PeekWaitPage] Listener error for ${widget.requestId}: $e',
        );
        if (mounted && !_navigated) {
          // Optionally show an error message and navigate away
          material.ScaffoldMessenger.of(context).showSnackBar(
            const material.SnackBar(
              content: material.Text(
                'Connection error while waiting. Please try again.',
              ),
              backgroundColor:
                  material.Colors.orangeAccent, // orange for connection issue?
            ),
          );
          _cancelAll(); // Stop timers/listeners
          _navigated = true;
          context.go('/');
        }
      },
      onDone: () {
        material.debugPrint(
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

  // Add this new method to your _PeekWaitPageState class:
  void _goToImageConfirmationPage(String requestId, String imageUrl) {
    if (!mounted || _navigated) return;
    _navigated = true;
    _cancelAll(); // Cancel listener and timer from PeekWaitPage

    material.debugPrint(
      "[PeekWaitPage] Navigating to /peek-accepted with requestId: $requestId and imageUrl (present). This page should show for 3s.",
    );

    // Navigate to 'peek_accepted_page.dart'.
    // This page will then handle the 3-second delay and navigation to '/splash'.
    context.go(Uri(
      path: '/peek-accepted', // This is your route for peek_accepted_page.dart
      queryParameters: {
        'requestId': requestId,
        'imageUrl': imageUrl, // Pass the imageUrl
        // Optional: Add a context parameter if peek_accepted_page handles multiple scenarios
        // 'source': 'image_received_by_sender',
      },
    ).toString());
  }

  /// Handles navigation and cleanup when the peek request times out locally or via Firestore status.
  void _onTimeout() {
    if (!mounted || _navigated)
      return; // Prevent multiple calls if _navigated was already true
    // _hasTimedOut is no longer used to control UI here.
    material.debugPrint(
      "[PeekWaitPage] Timeout reached for request ${widget.requestId}. Navigating to PeekTimedOutPage.",
    );

    _navigated = true;
    _cancelAll();

    // Attempt to mark the request as expired in Firestore via controller
    // Do this in the background, don't wait for it.
    ref
        .read(peekControllerProvider.notifier)
        .expirePeek(widget.requestId)
        .catchError(
          (e) => material.debugPrint('⚠️ [PeekWaitPage] expirePeek error: $e'),
        );

    // Navigate to the dedicated PeekTimedOutPage
    // Ensure your GoRouter configuration has a route for '/peek-timed-out'
    context.go('/peek-timed-out');
  }

  /// Navigates to the Peek Accept page
  void _goToPeekAcceptedPage(String imageUrl) {
    if (!mounted || _navigated) return; // Prevent multiple calls
    material.debugPrint(
      "[PeekWaitPage] Peek accepted. Navigating to PeekAcceptedPage with imageUrl: $imageUrl",
    );
    _navigated = true; // Set navigation flag
    _cancelAll(); // Stop listening and timeout timer

    // Construct the URI for PeekAcceptedPage
    // Ensure your GoRouter configuration has a route for '/peek-accepted'
    final uri = Uri(
      path: '/peek-accepted', // New path for PeekAcceptedPage
      queryParameters: {
        'requestId': widget.requestId,
        'imageUrl': imageUrl, // Pass imageUrl
      },
    );
    context.go(uri.toString());
  }

  /// Navigates to the SplashPage when the peek is accepted and image URL is available.
  void _goToSplash(String imageUrl) {
    if (!mounted || _navigated) return; // Prevent multiple calls
    material.debugPrint(
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
    material.debugPrint(
        "[PeekWaitPage] Peek rejected for request ${widget.requestId}.");
    _navigated = true; // Set navigation flag
    _cancelAll(); // Stop listening and timeout timer

    // Show a confirmation message to the user
    context.go('/peek-declined');
    // material.ScaffoldMessenger.of(context).showSnackBar(
    //   const material.SnackBar(
    //       content: material.Text('User was not ready to Peek.')),
    // );
    // // Navigate back home
    // context.go('/');
  }

  /// Handles unexpected internal errors during listening.
  void _handleInternalError(String message) {
    if (!mounted || _navigated) return;
    material.debugPrint("❌ [PeekWaitPage] Internal Error: $message");
    _navigated = true;
    _cancelAll();

    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
        content: material.Text(
          'Something went wrong ($message). Returning home.',
        ), // Simplified msg
        backgroundColor: material.Colors.redAccent,
        duration: Duration(seconds: 3),
      ),
    );

    Future.delayed(const Duration(milliseconds: 3100), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  /// Cancels the Firestore listener and the timeout timer.
  void _cancelAll() {
    material.debugPrint(
      "[PeekWaitPage] Cancelling listener and timer for ${widget.requestId}.",
    );
    _sub?.cancel();
    _sub = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    material.debugPrint(
        "[PeekWaitPage] Disposing for request ${widget.requestId}.");
    _cancelAll(); // Ensure resources are cleaned up
    super.dispose();
  }

  Future<void> _stopSearching() async {
    if (!mounted || _navigated) return;
    material.debugPrint(
        "[PeekWaitPage] User initiated stop searching for ${widget.requestId}.");
    _navigated = true;
    _cancelAll();
    try {
      // Ensure PeekController has 'cancelPeek' method
      await ref
          .read(peekControllerProvider.notifier)
          .cancelPeek(widget.requestId); // <<< Keep this call
      material.debugPrint("[PeekWaitPage] Peek request cancellation sent.");
    } catch (e) {
      material.debugPrint("⚠️ [PeekWaitPage] Error calling cancelPeek: $e");
    }
    if (mounted) context.go('/');
  }

  @override
  material.Widget build(material.BuildContext context) {
    // Determine the content based on the timeout state
    // Show timeout message if _hasTimedOut is true
    material.Widget mainContentWidget = _hasTimedOut
        ? const material.Padding(
            padding: material.EdgeInsets.symmetric(horizontal: 35.0),
            child: material.Text(
              'No one to Peek now!',
              textAlign: material.TextAlign.center,
              style: material.TextStyle(
                fontWeight: material.FontWeight.w600,
                color: peekWhiteColor,
                fontSize: 32,
              ),
            ),
          )
        // Otherwise, show the waiting indicator
        : const material.Padding(
            padding: const material.EdgeInsets.symmetric(horizontal: 35.0),
            child: material.Column(
              mainAxisSize: material.MainAxisSize.min,
              crossAxisAlignment: material.CrossAxisAlignment.center,
              children: [
                material.SizedBox(
                    height: 12,
                    width: 12,
                    child: material.Center(
                        child: material.CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: peekWhiteColor,
                    ))),
                material.SizedBox(height: 24),
                material.Text(
                  'Waiting for someone to Peek...',
                  style: material.TextStyle(
                    fontWeight: material.FontWeight.w600,
                    color: peekWhiteColor,
                    fontSize: 28,
                  ),
                  textAlign: material.TextAlign.center,
                ),
              ],
            ),
          );

    return material.Scaffold(
      // <<< Use prefix
      backgroundColor: peekBackgroundColor,
      body: material.Stack(
        // <<< Use prefix
        fit: material.StackFit.expand,
        children: [
          // --- Layer 1: Background Image ---
          material.Image.asset(
            // <<< Use prefix
            _backgroundImagePath,
            fit: material.BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              material
                  .debugPrint("❌ Error loading wait background image: $error");
              return material.Container(
                  color: peekBackgroundColor); // <<< Use prefix
            },
          ),

          // --- Layer 2: Rive Animation (Centered) ---
          material.SizedBox(
            height: 100,
            child: RiveAnimation.asset(
              // No prefix needed for Rive
              _riveAnimationPath,
              animations: const [_riveAnimationName],
              fit: material.BoxFit.fitHeight,
              placeHolder: const material.SizedBox.shrink(), // <<< Use prefix
              // REMOVED onError parameter
              onInit: (artboard) {
                // You can still use onInit if needed
                material.debugPrint("Rive loaded: ${artboard.name}");
              },
            ),
          ),

          material.Padding(
            // Use Padding for safe area and bottom offset
            padding:
                material.MediaQuery.of(context).padding + // Include safe area
                    const material.EdgeInsets.only(
                        bottom: 40.0,
                        left: 20.0,
                        right: 20.0), // Adjust bottom padding
            child: material.Column(
              mainAxisAlignment:
                  material.MainAxisAlignment.end, // Align to bottom
              crossAxisAlignment: material.CrossAxisAlignment.center,
              children: [
                // Spacer pushes content down
                const material.Spacer(),

                // Display Waiting or Timeout message
                mainContentWidget, // Use the variable defined above

                const material.SizedBox(
                    height: 40), // Space between text and button

                // Conditional Stop Button
                if (!_hasTimedOut)
                  material.OutlinedButton(
                    onPressed: _stopSearching, // Correct method call
                    style: material.OutlinedButton.styleFrom(/* Keep Style */),
                    child: const material.Text(
                      'Stop', /* Keep Style */
                    ),
                  )
                else
                  // Placeholder to maintain space when button hidden
                  const material.SizedBox(
                      height: 50 + 14 * 2), // Approx button height + padding

                // No extra SizedBox needed at the very end, Padding handles it
              ],
            ),
          ),

          // Optional: Darkening Overlay
          // material.Container(color: material.Colors.black.withOpacity(0.3)),

          // --- Layer 3: Main Content (Waiting/Timeout UI) ---
          // material.Column(
          //   // Use a Column to structure vertically
          //   children: [
          //     const material.Spacer(), // <<< ADD Spacer to push content down
          //     mainContentWidget, // <<< Place the determined content widget here
          //     // Add padding below the text content before the absolute bottom edge
          //     material.SizedBox(
          //         height: material.MediaQuery.of(context).size.height *
          //             0.15), // <<< Example bottom padding (adjust multiplier)
          //   ],
          // ),
        ],
      ),
    );
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
    // body: Center(child: bodyContent),
  }
}
