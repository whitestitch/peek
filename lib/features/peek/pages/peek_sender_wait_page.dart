// lib/features/peek/pages/peek_sender_wait_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/theme/colors.dart';

class PeekSenderWaitPage extends ConsumerStatefulWidget {
  final String requestId;
  const PeekSenderWaitPage({super.key, required this.requestId});

  @override
  ConsumerState<PeekSenderWaitPage> createState() => _PeekSenderWaitPageState();
}

class _PeekSenderWaitPageState extends ConsumerState<PeekSenderWaitPage>
    with material.SingleTickerProviderStateMixin {
  StreamSubscription<DocumentSnapshot>? _sub;
  bool _navigated = false;

  Timer? _countdownTimer;
  Timer? _watchdogTimer;
  int? _secondsRemaining;

  late final material.AnimationController _animationController;

  static const String _backgroundImagePath = 'assets/images/wait_peek_bg.jpg';
  static const String _logoPath = 'assets/images/peekio_eye.svg';

  @override
  void initState() {
    super.initState();
    material.debugPrint(
        "[PeekSenderWaitPage] Initialized for request ${widget.requestId}.");

    _secondsRemaining = null;

    _animationController = material.AnimationController(
      vsync: this,
      // Rotation speed here
      duration: const Duration(seconds: 2),
    )..repeat();

    _listenForUpdates();

    // Start a watchdog timer. If the official countdown doesn't start
    // within 35s, timeout gracefully. This prevents getting stuck.
    _watchdogTimer = Timer(const Duration(seconds: 35), () {
      material.debugPrint(
          "[PeekSenderWaitPage] Watchdog timer fired. Forcing timeout.");
      _showTimeoutDialogAndNavigate();
    });
  }

  void _listenForUpdates() {
    if (!mounted) return;
    _sub = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists || _navigated) return;

      final data = snap.data();
      final status = data?['status'] as String?;
      final imageUrl = data?['imageUrl'] as String?;
      final expiresAt = data?['captureExpiresAt'] as Timestamp?;
      final senderLocation = data?['senderLocation'] as String?;

      // Start countdown if deadline exists
      if (expiresAt != null && _countdownTimer == null) {
        _watchdogTimer?.cancel();
        _startCountdown(expiresAt.toDate());
      }

      if (status == 'responded_with_image' &&
          imageUrl != null &&
          imageUrl.isNotEmpty) {
        material.debugPrint(
            "[PeekSenderWaitPage] Received image response. Starting final countdown before showing image.");

        // Cancel the existing countdown and start final 3-second countdown
        _countdownTimer?.cancel();
        _startFinalCountdown(imageUrl, senderLocation);
      } else if (status == 'cancelled_by_receiver' || status == 'declined') {
        material.debugPrint(
            "[PeekSenderWaitPage] Peek was cancelled or declined by receiver. Navigating home.");
        // Pass a query parameter to tell HomePage to show the cancellation modal.
        _navigateToNext('/?show=peekCancelled');
      } else if (status == 'expired_capture') {
        // ADDED: Handle the new timeout status
        _countdownTimer?.cancel();
        _showTimeoutDialogAndNavigate();
      }
    });
  }

  // Add the new timer logic methods to the class
  void _startCountdown(DateTime deadline) {
    if (!mounted || (_countdownTimer?.isActive ?? false)) return;

    // Corrects the initial '30' to the actual current value seamlessly.
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        final initialRemaining = deadline.difference(now).inSeconds;
        _secondsRemaining = initialRemaining > 0 ? initialRemaining : 0;
      });
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final remaining = (deadline.difference(now).inMilliseconds / 1000).ceil();

      if (remaining < 0) {
        timer.cancel();
        _showTimeoutDialogAndNavigate();
      } else {
        setState(() {
          _secondsRemaining = remaining;
        });
      }
    });
  }

  void _startFinalCountdown(String imageUrl, String? senderLocation) {
    if (!mounted) return;

    // Set initial countdown to 3 seconds
    setState(() {
      _secondsRemaining = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_secondsRemaining! <= 1) {
        timer.cancel();

        // Navigate directly to image view, skipping the black splash screen
        material.debugPrint(
            "[PeekSenderWaitPage] Final countdown finished. Navigating directly to image view.");

        if (mounted) {
          context.go(
            '/peek-image',
            extra: {
              'requestId': widget.requestId,
              'imageUrl': imageUrl,
              if (senderLocation != null) 'senderLocation': senderLocation,
            },
          );
        }
      } else {
        setState(() {
          _secondsRemaining = _secondsRemaining! - 1;
        });
      }
    });
  }

  void _showTimeoutDialogAndNavigate() {
    if (_navigated) return;
    _navigated = true;
    _sub?.cancel();
    _countdownTimer?.cancel();
    if (!mounted) return;

    material
        .showModalBottomSheet(
      context: context,
      backgroundColor: material.Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            material.Navigator.of(ctx).pop();
          }
        });

        return material.Stack(
          alignment: material.Alignment.topCenter,
          children: [
            material.Container(
              margin: const material.EdgeInsets.only(top: 24),
              width: double.infinity,
              decoration: const material.BoxDecoration(
                color: peekBackgroundColor,
                borderRadius: material.BorderRadius.vertical(
                    top: material.Radius.circular(24)),
              ),
              padding: const material.EdgeInsets.fromLTRB(
                48,
                48,
                24,
                100,
              ),
              child: material.Column(
                mainAxisSize: material.MainAxisSize.min,
                mainAxisAlignment: material.MainAxisAlignment.center,
                children: [
                  const material.Icon(material.Icons.timer_off_outlined,
                      size: 60, color: material.Colors.white70),
                  const material.SizedBox(height: 20),
                  const material.Text("Time's Up!",
                      style: material.TextStyle(
                          fontSize: 24, fontWeight: material.FontWeight.bold)),
                  const material.SizedBox(height: 8),
                  const material.Text(
                      "The other user didn't take a photo in time.",
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                          fontSize: 16, color: material.Colors.white70)),

                  // NEW "OK" BUTTON
                  const material.SizedBox(height: 32),
                  material.ElevatedButton(
                    onPressed: () => material.Navigator.of(ctx).pop(),
                    style: material.ElevatedButton.styleFrom(
                      backgroundColor: peekSecondaryColor,
                      foregroundColor: material.Colors.black,
                      minimumSize: const material.Size(double.infinity, 50),
                      shape: material.RoundedRectangleBorder(
                        borderRadius: material.BorderRadius.circular(30),
                      ),
                    ),
                    child: const material.Text('OK',
                        style: material.TextStyle(
                            fontSize: 16,
                            fontWeight: material.FontWeight.bold)),
                  ),
                ],
              ),
            ),
            material.Positioned(
              top: 24 + 8,
              right: 12,
              child: material.IconButton(
                icon: const material.Icon(material.Icons.close,
                    color: material.Colors.white54),
                onPressed: () => material.Navigator.of(ctx).pop(),
              ),
            ),
          ],
        );
      },
    )
        .then((_) {
      // After the sheet is closed, navigate home.
      if (mounted) {
        context.go('/');
      }
    });
  }

  void _navigateToNext(String route) {
    if (_navigated) return;
    _navigated = true;
    _sub?.cancel();
    if (mounted) {
      context.go(route);
    }
  }

  @override
  void dispose() {
    material.debugPrint(
        "[PeekSenderWaitPage] Disposing for request ${widget.requestId}.");
    _animationController.dispose();
    _watchdogTimer?.cancel();
    _countdownTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    ref.watch(reactionOverlayListenerProvider);

    return material.Scaffold(
      backgroundColor: peekBackgroundColor,

      // 'X' BUTTON
      appBar: material.AppBar(
        backgroundColor: material.Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          material.IconButton(
            icon: const material.Icon(material.Icons.close,
                color: material.Colors.white), // Explicitly set color
            tooltip: 'Cancel Peek',
            onPressed: () {
              // This is the crucial step: update the status in Firestore
              ref
                  .read(peekControllerProvider.notifier)
                  .cancelPeekBySender(widget.requestId);

              // This navigation now includes the query parameter to trigger the modal on the home page.
              context.go('/?show=peekCancelled');
            },
          ),
        ],
      ),

      extendBodyBehindAppBar: true,

      body: material.Stack(
        fit: material.StackFit.expand,
        alignment: material.Alignment.center,
        children: [
          // Layer 1: Background Image
          material.Image.asset(
            _backgroundImagePath,
            fit: material.BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return material.Container(color: peekBackgroundColor);
            },
          ),
          // Layer 2: All centered content
          material.Center(
            child: material.Padding(
              padding: const material.EdgeInsets.all(30.0),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                children: [
                  // Spinning Logo - now part of the column
                  material.RotationTransition(
                    turns: _animationController,
                    child: SvgPicture.asset(
                      _logoPath,
                      width: 120, // Reduced size
                      height: 120, // Reduced size
                    ),
                  ),

                  // const material.SizedBox(height: 48),

                  const material.SizedBox(height: 32),

                  material.Text(
                    'Get Ready!',
                    style: material.Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          fontSize: 32,
                          color: peekWhiteColor,
                          fontWeight: material.FontWeight.bold,
                        ),
                  ),

                  const material.SizedBox(height: 15),
                  // Subtitle
                  material.Text(
                    'Your Peek is on its way...',
                    style: material.Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: peekWhiteColor.withOpacity(0.85)),
                  ),

                  const material.SizedBox(height: 15),

                  if (_secondsRemaining != null)
                    material.Container(
                      padding: const material.EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: material.BoxDecoration(
                        color: material.Colors.black.withOpacity(0.5),
                        borderRadius: material.BorderRadius.circular(20),
                      ),
                      child: material.Text(
                        '$_secondsRemaining',
                        style: material.Theme.of(context)
                            .textTheme
                            .displaySmall
                            ?.copyWith(
                              color: peekWhiteColor,
                              fontWeight: material.FontWeight.bold,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
