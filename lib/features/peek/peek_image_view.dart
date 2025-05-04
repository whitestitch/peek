// lib/features/peek/peek_image_view.dart
import 'dart:async'; // For Timer (now only needed for non-premium)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore access (User status)
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user
import 'package:go_router/go_router.dart'; // Import GoRouter for navigation
import 'package:firebase_analytics/firebase_analytics.dart';

// --- StatefulWidget Definition (Keep As Is) ---
class PeekImageView extends StatefulWidget {
  final String requestId;
  final String imageUrl;

  const PeekImageView({
    super.key,
    required this.requestId,
    required this.imageUrl,
  });

  @override
  State<PeekImageView> createState() => _PeekImageViewState();
}

// --- State Class Definition ---
class _PeekImageViewState extends State<PeekImageView>
    with SingleTickerProviderStateMixin {
  static const String _feedbackTimestampKey = 'feedbackLastPromptTimestamp';
  static const Duration _feedbackPromptInterval = Duration(days: 7);
  // --- State Variables ---
  bool _isPremium = false;
  bool _showImage = false;
  bool _imageLoaded = false;
  bool _loadAttempted = false;
  bool _loadFailed = false;

  // Only needed for non-premium users now
  Timer? _viewTimer;
  // Removed _replayTimer, _showReplay

  // View duration only relevant for non-premium
  int _viewDuration = 5;

  late final String _imageUrl;
  // --- End of State Variables ---

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _viewStartedLogged = false; // Flag to log view start only once

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl;
    _loadUserStatus().then((_) {
      if (mounted) {
        _loadImageAndStartView();
      }
    });
  }

  /// Fetches the current user's premium status from Firestore.
  Future<void> _loadUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("[PeekImageView] User not logged in for premium check.");
      if (mounted)
        setState(() {
          _isPremium = false;
          _viewDuration = 5;
        });
      return;
    }
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      if (!mounted) return;
      final isPremiumUser = doc.data()?['isPremium'] == true;
      setState(() {
        _isPremium = isPremiumUser;
        // _viewDuration only matters if not premium, but set it anyway
        _viewDuration =
            _isPremium
                ? 9999
                : 5; // Use a very large number for premium or simply don't use timer
        debugPrint("[PeekImageView] User premium: $_isPremium");
      });
    } catch (e) {
      debugPrint('⚠️ [PeekImageView] Failed to load premium status: $e');
      // ---> START OPTIONAL ADDITION <---
      if (mounted) {
        // Show a brief, non-blocking message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not verify user status.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      if (mounted)
        setState(() {
          _isPremium = false;
          _viewDuration = 5;
        });
    }
  }

  /// Sets state to show the image and starts the view timer ONLY for non-premium users.
  void _loadImageAndStartView() {
    if (!mounted || _loadAttempted) return;
    setState(() {
      _loadAttempted = true;
      _showImage = true;
      _imageLoaded = true; // Assume loaded, errorBuilder will handle failure
      _loadFailed = false;
    });
    debugPrint("[PeekImageView] Attempting image display.");

    // Log peek view started event (only once per view)
    if (!_viewStartedLogged) {
      try {
        // --- FIX: Convert boolean to String for Analytics ---
        _analytics.logEvent(
          name: 'peek_view_started',
          parameters: {
            'request_id_partial':
                widget.requestId.length >= 8
                    ? widget.requestId.substring(0, 8)
                    : widget.requestId, // Safe substring
            'viewer_is_premium':
                _isPremium
                    .toString(), // Convert bool to 'true' or 'false' string
          },
        );
        _viewStartedLogged = true;
        debugPrint("[PeekImageView] Logged peek_view_started event.");
      } catch (e) {
        debugPrint("Error logging peek_view_started event: $e");
      }
    }

    // Start timer logic (Keep As Is)
    if (!_isPremium) {
      debugPrint("[PeekImageView] Non-premium user, starting view timer.");
      _startViewTimer();
    } else {
      debugPrint("[PeekImageView] Premium user, image will stay visible.");
    }
  }

  /// Decides whether to show feedback or go home based on the last prompt time.
  Future<void> _decideNextNavigation() async {
    if (!mounted) return; // Ensure widget is still alive

    bool shouldShowFeedback = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPromptMillis = prefs.getInt(_feedbackTimestampKey) ?? 0;
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      // Check if the interval has passed since the last prompt
      if ((nowMillis - lastPromptMillis) >
          _feedbackPromptInterval.inMilliseconds) {
        shouldShowFeedback = true;
        debugPrint(
          "[PeekImageView] Feedback interval passed. Will navigate to feedback.",
        );
        // Update the timestamp NOW so we don't prompt again immediately if nav fails
        // We could also update it only *after* successful navigation from the feedback page,
        // but doing it here is simpler for this widget.
        await prefs.setInt(_feedbackTimestampKey, nowMillis);
      } else {
        debugPrint(
          "[PeekImageView] Feedback interval not passed. Will navigate home.",
        );
      }
    } catch (e) {
      debugPrint("Error reading/writing feedback timestamp: $e");
      // Default to navigating home if SharedPreferences fails
      shouldShowFeedback = false;
    }

    // Perform navigation based on the decision
    if (!mounted)
      return; // Check mounted again after async SharedPreferences call

    try {
      if (shouldShowFeedback) {
        context.go('/peek-feedback?requestId=${widget.requestId}');
      } else {
        context.go('/'); // Navigate home directly
      }
    } catch (e) {
      debugPrint(
        "⚠️ [PeekImageView] Navigation failed in _decideNextNavigation: $e",
      );
      // Attempt fallback navigation if primary fails
      if (mounted && !shouldShowFeedback)
        context.go('/'); // Try navigating home again on error
    }
  }

  /// Starts the timer ONLY for non-premium users.
  /// Navigates non-premium users to feedback page upon completion.
  void _startViewTimer() {
    // Double check: Should only be called if !_isPremium
    if (_isPremium) return;

    _viewTimer?.cancel();
    debugPrint(
      "[PeekImageView] Starting view timer for $_viewDuration seconds (Non-Premium).",
    );
    _viewTimer = Timer(Duration(seconds: _viewDuration), () {
      // --- Timer Finished Callback (Non-Premium Only) ---
      if (!mounted) return;
      debugPrint("[PeekImageView] Non-premium view timer finished.");
      setState(() {
        _showImage = false;
      });
      _decideNextNavigation(); // Navigate non-premium to feedback
      // --- End Timer Finished Callback ---
    });
  }

  /// Cleans up timers (if any) and navigates home using GoRouter.
  /// Now primarily used by the "Close" button for premium users.
  Future<void> _cleanup() async {
    debugPrint("[PeekImageView] Cleanup initiated (Navigating Home).");
    // Cancel timer if it exists (relevant for non-premium flow if called unexpectedly)
    _viewTimer?.cancel();
    // _replayTimer removed

    await _decideNextNavigation(); // Check if feedback should be
    debugPrint("[PeekImageView] Cleanup finished (Navigation attempted).");
  }

  // --- REMOVED _viewAgain method ---

  // --- _navigateToFeedback (Only called for non-premium now) ---
  /// Navigates non-premium users to the feedback page.
  void _navigateToFeedback() {
    // Ensure this isn't called for premium users
    if (_isPremium || !mounted) return;

    debugPrint("[PeekImageView] Navigating non-premium user to feedback page.");
    // Cancel timers before navigating
    _viewTimer?.cancel();
    // _replayTimer removed

    try {
      context.go('/peek-feedback?requestId=${widget.requestId}');
    } catch (e) {
      debugPrint("⚠️ [PeekImageView] Navigation to feedback failed: $e");
      _cleanup(); // Fallback to home
    }
  }

  @override
  void dispose() {
    debugPrint("[PeekImageView] Disposing.");
    _viewTimer?.cancel(); // Cancel non-premium timer if active
    // _replayTimer removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    // State 1: Image is showing (Handles both premium and non-premium)
    if (_showImage) {
      bodyContent = Stack(
        fit: StackFit.expand,
        children: [
          // --- MODIFICATION: Replace loadingBuilder with frameBuilder for Fade-in ---
          Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            // Use frameBuilder for fade logic
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) {
                // If image was already in cache, show it immediately
                return child;
              }
              // Otherwise, fade it in
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1, // Fade in when frame is ready
                duration: const Duration(milliseconds: 400), // Adjust duration
                curve: Curves.easeOut, // Adjust curve
                child: child,
              );
            },
            // Keep loadingBuilder for the progress indicator while downloading
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Loading complete, frameBuilder takes over display
                return child;
              }
              // Show indicator while loading
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, error, stackTrace) {
              // Keep existing error builder logic
              debugPrint(
                '❌ [PeekImageView] Image.network errorBuilder: $error',
              );
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  setState(() {
                    _loadFailed = true;
                    _showImage = false;
                    _imageLoaded = false;
                  });
              });
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white60,
                  size: 60,
                ),
              );
            },
          ),

          // --- MODIFICATION: Add Close Button for Premium Users ---
          if (_isPremium) // Only show for premium users
            Positioned(
              top: 50, // Adjust position as needed (consider SafeArea)
              right: 15,
              child: CircleAvatar(
                // Use CircleAvatar for nice background
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  tooltip: 'Close Peek',
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white,
                  onPressed: _cleanup, // Call cleanup to navigate home
                ),
              ),
            ),
          // --- END MODIFICATION ---
        ],
      );
    }
    // --- REMOVED State 2 (Replay Button State) ---
    // else if (_showReplay && _isPremium) { ... }
    // State 3 -> Now State 2: Load Failed
    else if (_loadFailed) {
      // ... (Load failed build logic - no changes needed) ...
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 16),
              const Text(
                '❌ Failed to load Peek',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/'), // Go home on load failure
                child: const Text(
                  'Go Home',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // State 4 -> Now State 3: Initial loading or intermediate state
    else {
      // ... (Loading indicator - no changes needed) ...
      bodyContent = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Scaffold(backgroundColor: Colors.black, body: bodyContent);
  }
}
