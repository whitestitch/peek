// lib/features/peek/splash_page.dart

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart'; // Not needed if only using default instance
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/firestore_service.dart';
import 'package:peek/core/widgets/peek_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SplashPage:
///   - Fetches/validates image URL if not provided.
///   - Runs a 3-second countdown.
///   - Navigates to PeekImageView with necessary data.
class SplashPage extends ConsumerStatefulWidget {
  final String requestId;
  final String? initialImageUrl; // URL can be passed directly

  const SplashPage({super.key, required this.requestId, this.initialImageUrl});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  // Countdown duration
  int _count = 3;
  // Timer for the countdown
  Timer? _timer;
  // Holds the final image URL
  String? _imageUrl;
  // Flag to determine if location should be shown
  String? _senderLocation;
  bool _canShowLocation = false;
  // Tracks loading state (URL fetching)
  bool _isLoading = true;
  // Holds any error message
  String? _errorMessage;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _prepareAndStart();
    }
  }

  /// Fetches URL (if needed) and starts the countdown.
  Future<void> _prepareAndStart() async {
    // Ensure initial state is loading and no error
    // Use mounted check even before async gap for robustness if called elsewhere later
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Get the sender's location directly from the router's query parameters.
      final String? locationFromNav =
          GoRouterState.of(context).uri.queryParameters['senderLocation'];
      debugPrint(
          "[SplashPage] Received senderLocation from navigation: $locationFromNav");

      // 2. Fetch ONLY the current user's data to check premium status.
      final userDoc =
          await ref.read(firestoreServiceProvider).getCurrentUserDocument();
      final isReceiverPremium = userDoc?.data()?['isPremium'] as bool? ?? false;
      debugPrint("[SplashPage] Receiver premium status: $isReceiverPremium");

      // 3. Set the image URL from the widget property.
      if (widget.initialImageUrl == null || widget.initialImageUrl!.isEmpty) {
        throw Exception("Initial image URL was not provided to SplashPage.");
      }
      _imageUrl = widget.initialImageUrl!;

      // 4. Determine if location should be shown based on the new, simple logic.
      if (locationFromNav != null && isReceiverPremium) {
        debugPrint("[SplashPage] Conditions met. Location will be shown.");
        _senderLocation = locationFromNav;
        _canShowLocation = true;
      }

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
          _errorMessage = 'Failed to load Peek.'; // Updated error message
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
              'imageUrl': _imageUrl!,
              // Conditionally pass the location data
              if (_canShowLocation) 'senderLocation': _senderLocation,
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
      content = const PeekLoadingIndicator.medium(
        logoColor: Colors.white,
        loadingText: "Preparing Peek...",
        textStyle: TextStyle(color: Colors.white70),
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
