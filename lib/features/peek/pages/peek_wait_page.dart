import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/overlay_animation_service.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:rive/rive.dart';
import 'package:peek/theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  // static const String _backgroundImagePath = 'assets/images/wait_peek_bg.jpg';
  static const String _riveAnimationPath =
      'assets/animations/peek_wait_radar.riv';
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
        final reaction = data['reaction'] as String?;

        material.debugPrint(
          "[PeekWaitPage] Listener update: status=$status, imageUrl=${imageUrl != null ? 'present' : 'null'}",
        );

        // Handle different statuses
        switch (status) {
          case 'accepted':
            // The request has been accepted. Navigate to the confirmation page
            // which will then be responsible for listening for the image.
            if (!_navigated) {
              material.debugPrint(
                  "[PeekWaitPage] Status 'accepted'. Navigating to PeekAcceptedPage.");
              _navigated = true;
              _cancelAll();
              context.go('/peek-accepted?requestId=${widget.requestId}');
            }
            break;

          case 'responded_with_image':
            // This case is now primarily handled by PeekAcceptedPage.
            // This acts as a fallback in case the listener transition is slow.
            if (imageUrl != null && imageUrl.isNotEmpty && !_navigated) {
              _goToImageConfirmationPage(widget.requestId, imageUrl);
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
        duration: const Duration(seconds: 5),
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
    // Ensure resources are cleaned up
    _cancelAll();
    super.dispose();
  }

  Future<void> _stopSearching() async {
    if (!mounted || _navigated) return;
    material.debugPrint(
        "[PeekWaitPage] User initiated stop searching for ${widget.requestId}.");

    _navigated = true;
    _cancelAll();

    try {
      // Call the controller to update the status to 'cancelled_by_sender'
      // This will be picked up by the other user's listener and trigger cancellation panel
      ref
          .read(peekControllerProvider.notifier)
          .cancelPeekBySender(widget.requestId);

      // Navigate directly to home with cancellation parameters
      if (mounted) {
        material.debugPrint(
            "[PeekWaitPage] Navigating to home with sender cancellation...");
        context.go('/?show=peekCancelled&reason=sender_cancelled');
      }
    } catch (e) {
      material.debugPrint("⚠️ [PeekWaitPage] Error calling cancelPeek: $e");
      // Fallback navigation if cancellation fails
      if (mounted) {
        context.go('/');
      }
    }
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
            padding: const material.EdgeInsets.symmetric(
              vertical: 2,
              horizontal: 8,
            ),
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
      backgroundColor: peekBackgroundColor,
      body: material.Stack(
        fit: material.StackFit.expand,
        children: [
          // --- Layer 2: Rive Animation (Centered) ---
          material.Center(
            child: material.SizedBox(
              height: 750,
              width: 750,
              child: RiveAnimation.asset(
                _riveAnimationPath,
                animations: const [_riveAnimationName],
                fit: material.BoxFit.cover,
                placeHolder: const material.SizedBox.shrink(),
                onInit: (artboard) {
                  material.debugPrint("Rive loaded: ${artboard.name}");
                },
              ),
            ),
          ),

          // --- Layer 2: UI Content (Text and Button) ---
          material.Padding(
            padding: const material.EdgeInsets.symmetric(horizontal: 40.0),
            child: material.Column(
              children: [
                // This Spacer pushes all the content below it to the bottom of the screen.
                const material.Spacer(),

                // The "Waiting for..." text content
                mainContentWidget,

                const material.SizedBox(
                    height: 30), // Space between text and button

                // The Stop button
                if (!_hasTimedOut)
                  material.SizedBox(
                    width: double.infinity, // Make button wider for better UI
                    child: material.OutlinedButton(
                      onPressed: _stopSearching,
                      child: const material.Text('Stop'),
                    ),
                  ),

                // Bottom padding to lift the button from the edge
                const material.SizedBox(height: 60),
              ],
            ),
          ),

          // --- Layer 3: Top Logo ---
          material.Padding(
            padding: material.EdgeInsets.only(
              top: material.MediaQuery.of(context).padding.top + 20,
              left: 35.0,
            ),
            child: material.Align(
              alignment: material.Alignment.topLeft,
              child: material.Row(
                mainAxisSize: material.MainAxisSize.min,
                crossAxisAlignment: material.CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/peekio_logo.svg',
                    height: 30, // Adjusted for text balance
                    colorFilter: const material.ColorFilter.mode(
                      peekWhiteColor,
                      material.BlendMode.srcIn,
                    ),
                  ),
                  const material.SizedBox(width: 12),
                  const material.Text(
                    "Peekio",
                    style: material.TextStyle(
                      fontWeight: material.FontWeight.w600,
                      color: peekWhiteColor,
                      fontSize: 32,
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
