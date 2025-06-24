// lib/features/peek/splash_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart'; // Not needed if only using default instance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

/// SplashPage:
///   - Fetches/validates image URL if not provided.
///   - Runs a 3-second countdown.
///   - Navigates to PeekImageView with necessary data.
class SplashPage extends StatefulWidget {
  final String requestId;
  final String? initialImageUrl; // URL can be passed directly

  const SplashPage({super.key, required this.requestId, this.initialImageUrl});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  int _count = 3; // Countdown duration
  Timer? _timer; // Timer for the countdown
  String? _imageUrl; // Holds the final image URL
  bool _isLoading = true; // Tracks loading state (URL fetching)
  String? _errorMessage; // Holds any error message

  @override
  void initState() {
    super.initState();
    // Start the preparation process immediately
    _prepareAndStart();
  }

  /// Fetches URL (if needed) and starts the countdown.
  Future<void> _prepareAndStart() async {
    // Ensure initial state is loading and no error
    // Use mounted check even before async gap for robustness if called elsewhere later
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // 1. Determine the image URL
      if (widget.initialImageUrl != null &&
          widget.initialImageUrl!.isNotEmpty) {
        _imageUrl = widget.initialImageUrl!;
        debugPrint("[SplashPage] Using provided initialImageUrl.");
      } else {
        debugPrint(
          "[SplashPage] No initialImageUrl, fetching from Firestore...",
        );
        // Fetch from Firestore if URL not provided
        final snap = await FirebaseFirestore.instance
            .collection('peek_requests')
            .doc(widget.requestId)
            .get();

        // Check mounted status after await
        if (!mounted) return;

        final data = snap.data();
        final storagePath = data?['storagePath'] as String?;
        final directUrl = data?['imageUrl'] as String?;

        if (directUrl != null && directUrl.isNotEmpty) {
          _imageUrl = directUrl;
          debugPrint("[SplashPage] Found direct imageUrl in Firestore.");
        } else if (storagePath != null && storagePath.isNotEmpty) {
          debugPrint(
            "[SplashPage] Found storagePath: $storagePath, getting download URL...",
          );
          // Get URL from storage path
          _imageUrl =
              await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
        } else {
          // Handle case where neither URL nor path is found
          throw Exception(
            'Image URL or storage path not found in Firestore document.',
          );
        }
      }

      // Check mounted status again after potential async URL fetch
      if (!mounted) return;

      // --- REMOVED PRECACHE ---
      // 2. Precache the image (REMOVED - Caused context error)
      // debugPrint("[SplashPage] Pre-caching image: $_imageUrl");
      // await precacheImage(NetworkImage(_imageUrl!), context); // <-- REMOVED THIS LINE
      // debugPrint("[SplashPage] Image pre-cached successfully.");
      // --- END REMOVAL ---

      // Check mounted status before final state update and timer start
      if (!mounted) return;

      // 3. Mark loading complete and start the countdown
      setState(() {
        _isLoading = false;
      });
      _startCountdownTimer();
    } catch (e) {
      debugPrint('❌ [SplashPage] Error during preparation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load Peek.\nPlease go home.'; // Updated error message
        });
        // Removed auto-navigate home on error, let user decide via button
        // Future.delayed(const Duration(seconds: 4), _goHome);
      }
    }
  }

  /// Starts the actual 3..2..1 timer.
  void _startCountdownTimer() {
    _timer?.cancel(); // Ensure no duplicate timers

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      // Decrement countdown
      if (_count > 1) {
        setState(() {
          _count--;
        });
      } else {
        // Countdown finished
        t.cancel();
        debugPrint(
          "[SplashPage] Countdown finished. Navigating to /peek-image.",
        );
        if (mounted) {
          // MODIFIED: Pass parameters via `extra` to align with the router's expectation.
          // This is more robust for complex data than using query parameters.
          context.go(
            '/peek-image',
            extra: {
              'requestId': widget.requestId,
              'imageUrl':
                  _imageUrl!, // URL should be non-null here if no error occurred
            },
          );
        }
      }
    });
  }

  /// Navigates to the home screen.
  void _goHome() {
    if (mounted) {
      debugPrint("[SplashPage] Navigating home.");
      context.go('/');
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Important: Cancel timer on dispose
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    // --- Build Logic based on State ---
    if (_isLoading) {
      // State 1: Loading URL/preparing
      content = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text("Preparing Peek...", style: TextStyle(color: Colors.white70)),
        ],
      );
    } else if (_errorMessage != null) {
      // State 2: Error occurred during preparation
      content = Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 20),
            // Provide a button to go home manually on error
            TextButton(
              onPressed: _goHome,
              child: const Text(
                "Go Home",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    } else {
      // State 3: Loading successful, show countdown
      content = Text(
        '$_count', // Display the current countdown number
        style: const TextStyle(
          color: Colors.white,
          fontSize: 96,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 8.0, color: Colors.black45)],
        ),
      );
    }
    // --- End Build Logic ---

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: content),
    );
  }
}
