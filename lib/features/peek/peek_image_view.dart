import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore access (User status)
import 'package:firebase_auth/firebase_auth.dart'; // For getting current user
import 'package:firebase_storage/firebase_storage.dart'; // For potential cleanup
import 'package:go_router/go_router.dart'; // Import GoRouter for navigation

// --- StatefulWidget Definition ---
class PeekImageView extends StatefulWidget {
  final String requestId; // ID for cleanup purposes
  final String imageUrl; // URL of the image to display

  const PeekImageView({
    super.key,
    required this.requestId,
    required this.imageUrl,
  });

  @override
  State<PeekImageView> createState() => _PeekImageViewState();
}
// --- End of StatefulWidget Definition ---

// --- State Class Definition ---
class _PeekImageViewState extends State<PeekImageView>
    with SingleTickerProviderStateMixin {
  // Mixin if animations were needed

  // --- State Variables ---
  bool _isPremium = false; // Tracks user's premium status
  bool _showImage =
      false; // Controls image visibility (set true after load attempt)
  bool _imageLoaded =
      false; // Set true after successful image load/precache check
  bool _loadAttempted = false; // Tracks if we've tried to load the image
  bool _loadFailed = false; // Set true if image load/display fails

  // REMOVED: _countdown and _countdownTimer - Handled by SplashPage
  // int _countdown = 3;
  // Timer? _countdownTimer;

  Timer? _viewTimer; // Timer controlling how long the image is shown
  Timer? _replayTimer; // Timer for premium replay button visibility

  int _viewDuration = 5; // Default view duration (seconds) for non-premium
  bool _showReplay =
      false; // Controls visibility of the replay button (premium)

  // Store imageUrl in a final variable for easier access
  late final String _imageUrl;
  // --- End of State Variables ---

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl; // Assign from widget property

    // 1. Load user status to determine view duration and replay possibility
    _loadUserStatus().then((_) {
      // 2. Once status is loaded, attempt to display the image immediately
      //    (assuming SplashPage handled preloading)
      if (mounted) {
        // REMOVED: _startCountdown();
        _loadImageAndStartView(); // New method to handle immediate display
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
        _viewDuration = _isPremium ? 10 : 5;
        debugPrint(
          "[PeekImageView] User premium: $_isPremium, View duration: $_viewDuration",
        );
      });
    } catch (e) {
      debugPrint('⚠️ [PeekImageView] Failed to load premium status: $e');
      if (mounted)
        setState(() {
          _isPremium = false;
          _viewDuration = 5;
        });
    }
  }

  /// Sets state to show the image and starts the view timer.
  /// Assumes image is likely precached by SplashPage, but handles loading state.
  void _loadImageAndStartView() {
    if (!mounted || _loadAttempted) return; // Prevent multiple attempts

    // We assume SplashPage tried to preload. We immediately try to show.
    // The Image.network widget handles actual loading/errors.
    setState(() {
      _loadAttempted = true;
      _showImage = true; // Attempt to show the image container
      // We don't know for sure if it *actually* loaded yet, Image.network handles that.
      // Set _imageLoaded true optimistically, errorBuilder will catch issues.
      _imageLoaded = true;
      _loadFailed = false; // Reset potential previous failure
    });
    debugPrint(
      "[PeekImageView] Attempting image display, starting view timer.",
    );
    _startViewTimer(); // Start the visibility timer
  }

  // REMOVED: _startCountdown() method
  // REMOVED: _preloadImage() method (display is now handled directly in build/loadImageAndStartView)

  /// Starts the timer that determines how long the image is visible.
  void _startViewTimer() {
    _viewTimer?.cancel(); // Cancel any existing view timer
    debugPrint(
      "[PeekImageView] Starting view timer for $_viewDuration seconds.",
    );
    _viewTimer = Timer(Duration(seconds: _viewDuration), () {
      if (!mounted) return;
      debugPrint("[PeekImageView] View timer finished.");

      if (_isPremium) {
        debugPrint(
          "[PeekImageView] Premium user: Hiding image, showing replay.",
        );
        setState(() {
          _showImage = false;
          _showReplay = true;
        });
        _replayTimer?.cancel();
        _replayTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            debugPrint("[PeekImageView] Replay timer finished, cleaning up.");
            _cleanup();
          }
        });
      } else {
        // --- FIX FOR NON-PREMIUM TIMEOUT (Issue 1) ---
        debugPrint(
          "[PeekImageView] Non-premium user: Hiding image, cleaning up.",
        );
        setState(() {
          _showImage = false;
        });
        _cleanup(); // Triggers navigation home via GoRouter
        // --- End of Fix ---
      }
    });
  }

  /// Handles the action when the premium user taps the replay button.
  void _replayPeek() {
    if (!mounted || !_isPremium || !_showReplay) return;
    debugPrint("[PeekImageView] Replay peek triggered.");
    _replayTimer?.cancel();
    setState(() {
      _showImage = true;
      _showReplay = false;
    });
    _startViewTimer(); // Restart the view timer
  }

  /// Cleans up resources (timers) and navigates home using GoRouter.
  Future<void> _cleanup() async {
    debugPrint("[PeekImageView] Cleanup initiated.");
    // 1. Cancel all active timers
    // REMOVED: _countdownTimer?.cancel();
    _viewTimer?.cancel();
    _replayTimer?.cancel();

    // 2. Navigate home using GoRouter
    if (mounted) {
      try {
        debugPrint("[PeekImageView] Navigating home via context.go('/')");
        // Use context.go('/') for potentially more reliable navigation with GoRouter
        context.go('/');
        // REMOVED: Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        debugPrint("⚠️ [PeekImageView] Navigation failed during cleanup: $e");
        // Fallback or error logging might be needed here
      }
    } else {
      debugPrint("[PeekImageView] Cleanup attempted but widget not mounted.");
    }

    // 3. Background cleanup (Firestore/Storage) - Now handled by Cloud Function or separate logic
    //    Keeping this page focused on viewing and navigation simplifies it.
    //    If cleanup MUST happen here, add it back, but be aware of potential issues
    //    if the app closes before cleanup completes.
    /* --- Optional: Add back if essential, but background cleanup is preferred ---
    try {
      final docRef = FirebaseFirestore.instance.collection('peek_requests').doc(widget.requestId);
      await docRef.delete();
      debugPrint("[PeekImageView] Firestore doc deleted: ${widget.requestId}");

      if (_imageUrl.isNotEmpty && _imageUrl.startsWith('https://firebasestorage.googleapis.com')) {
         final storageRef = FirebaseStorage.instance.refFromURL(_imageUrl);
         await storageRef.delete();
         debugPrint("[PeekImageView] Storage image deleted: $_imageUrl");
      } else {
         debugPrint('⚠️ [PeekImageView] Skipping Storage delete - Invalid URL format: $_imageUrl');
      }
    } catch (e) {
      debugPrint('⚠️ [PeekImageView] Background cleanup error (Firestore/Storage): $e');
    }
    */
  }

  @override
  void dispose() {
    debugPrint("[PeekImageView] Disposing.");
    // Ensure all timers are cancelled when the widget is permanently removed
    // REMOVED: _countdownTimer?.cancel();
    _viewTimer?.cancel();
    _replayTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;

    // --- Build Logic based on State ---

    // State 1: Image is set to be shown (actual loading handled by Image.network)
    if (_showImage) {
      bodyContent = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Image successfully displayed on screen
                // We can set _imageLoaded definitively here if needed, but not strictly required
                // WidgetsBinding.instance.addPostFrameCallback((_) {
                //   if(mounted) setState(() => _imageLoaded = true);
                // });
                return child;
              }
              // Show loading indicator while downloading
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, error, stackTrace) {
              // This catches errors during image fetching/decoding
              debugPrint(
                '❌ [PeekImageView] Image.network errorBuilder: $error',
              );
              // Use post frame callback to avoid setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _loadFailed = true; // Mark as failed
                    _showImage = false; // Stop trying to show the image view
                    _imageLoaded = false;
                  });
                  // Optionally trigger cleanup immediately on load failure
                  // _viewTimer?.cancel(); // Stop timer if it was running
                  // _cleanup();
                }
              });
              // Show a placeholder during the frame where error occurred
              return const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white60,
                  size: 60,
                ),
              );
            },
          ),
        ],
      );
    }
    // State 2: Premium user - Replay button shown
    else if (_showReplay && _isPremium) {
      bodyContent = Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: ElevatedButton.icon(
              onPressed: _replayPeek,
              icon: const Icon(Icons.replay),
              label: const Text('Replay Peek'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      );
    }
    // State 3: Load Failed
    else if (_loadFailed) {
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
              // Option to go home immediately after failure
              TextButton(
                onPressed: _cleanup, // Use cleanup to navigate home
                child: const Text(
                  'Go Home',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              // Removed "Try Again" as it complicates the flow without countdown
            ],
          ),
        ),
      );
    }
    // State 4: Initial loading state (before _loadAttempted or after timer ends before nav)
    else {
      // Shows briefly while user status loads or timers end
      bodyContent = const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Scaffold(backgroundColor: Colors.black, body: bodyContent);
  }
}
