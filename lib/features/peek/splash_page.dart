// lib/features/peek/splash_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

/// SplashPage:
///   - Fetches/validates image URL if not provided.
///   - Precaches the image.
///   - Runs a 3-second countdown.
///   - Navigates to PeekImageView.
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
  bool _isLoading = true; // Tracks loading state (URL fetching/precaching)
  String? _errorMessage; // Holds any error message

  @override
  void initState() {
    super.initState();
    _prepareAndStart();
  }

  /// Fetches URL (if needed), precaches, and starts the countdown.
  Future<void> _prepareAndStart() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    }); // Start loading state

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
        // Fetch storagePath from Firestore if URL not provided
        final snap =
            await FirebaseFirestore.instance
                .collection('peek_requests')
                .doc(widget.requestId)
                .get();
        final data = snap.data();
        final storagePath = data?['storagePath'] as String?;
        final directUrl =
            data?['imageUrl'] as String?; // Also check if URL is already there

        if (directUrl != null && directUrl.isNotEmpty) {
          _imageUrl = directUrl;
          debugPrint("[SplashPage] Found direct imageUrl in Firestore.");
        } else if (storagePath != null && storagePath.isNotEmpty) {
          debugPrint(
            "[SplashPage] Found storagePath: $storagePath, getting download URL...",
          );
          // If only storagePath exists, get the download URL
          // Ensure correct bucket if not default (though likely default here)
          _imageUrl =
              await FirebaseStorage.instance.ref(storagePath).getDownloadURL();
        } else {
          // No URL or path found
          throw Exception(
            'Image URL or storage path not found in Firestore document.',
          );
        }
      }

      if (!mounted) return; // Check after async operations

      // 2. Precache the image
      debugPrint("[SplashPage] Pre-caching image: $_imageUrl");
      await precacheImage(NetworkImage(_imageUrl!), context);
      debugPrint("[SplashPage] Image pre-cached successfully.");

      if (!mounted) return;

      // 3. Start the countdown
      setState(() {
        _isLoading = false;
      }); // Loading finished
      _startCountdownTimer();
    } catch (e) {
      debugPrint('❌ [SplashPage] Error during preparation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load Peek details.\nPlease go back.'; // User-friendly error
        });
        // Optionally auto-navigate home after showing error briefly
        // Future.delayed(const Duration(seconds: 4), _goHome);
      }
    }
  }

  /// Starts the actual 3..2..1 timer.
  void _startCountdownTimer() {
    if (_timer?.isActive ?? false) _timer!.cancel(); // Ensure no double timers

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      // Check count *before* setState
      if (_count > 1) {
        // --- LINT FIX: Added curly braces ---
        setState(() {
          _count--;
        });
        // ------------------------------------
      } else {
        // Countdown finished
        t.cancel();
        debugPrint(
          "[SplashPage] Countdown finished. Navigating to /peek-image.",
        );
        // Navigate to the image view page
        context.go(
          Uri(
            path: '/peek-image',
            queryParameters: {
              'requestId': widget.requestId,
              'imageUrl': _imageUrl!, // URL is guaranteed non-null here
            },
          ).toString(),
        );
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
    _timer?.cancel(); // Cancel timer if active
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_isLoading) {
      // Show loading indicator while fetching URL/precaching
      content = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text("Preparing Peek...", style: TextStyle(color: Colors.white70)),
        ],
      );
    } else if (_errorMessage != null) {
      // Show error message if preparation failed
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
      // Show countdown timer
      content = Text(
        '$_count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 96, // Larger countdown
          fontWeight: FontWeight.bold,
          shadows: [Shadow(blurRadius: 8.0, color: Colors.black45)],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: content),
    );
  }
}
