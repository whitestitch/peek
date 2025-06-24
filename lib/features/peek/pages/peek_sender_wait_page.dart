// lib/features/peek/pages/peek_sender_wait_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  late final material.AnimationController _animationController;

  static const String _backgroundImagePath = 'assets/images/wait_peek_bg.jpg';
  static const String _logoPath = 'assets/images/peekio_logo.svg';

  @override
  void initState() {
    super.initState();
    material.debugPrint(
        "[PeekSenderWaitPage] Initialized for request ${widget.requestId}.");

    _animationController = material.AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Adjust rotation speed here
    )..repeat();

    _listenForUpdates();
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

      if (status == 'responded_with_image' &&
          imageUrl != null &&
          imageUrl.isNotEmpty) {
        material.debugPrint(
            "[PeekSenderWaitPage] Received image response. Navigating to splash.");
        _navigateToNext(
            '/splash?requestId=${widget.requestId}&initialImageUrl=${Uri.encodeComponent(imageUrl)}');
      } else if (status == 'cancelled_by_receiver' || status == 'declined') {
        material.debugPrint(
            "[PeekSenderWaitPage] Peek was cancelled or declined by receiver. Navigating home.");
        // Pass a query parameter to tell HomePage to show the cancellation modal.
        _navigateToNext('/?show=peekCancelled');
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
    _sub?.cancel();
    super.dispose();
  }

  @override
  material.Widget build(material.BuildContext context) {
    return material.Scaffold(
      backgroundColor: peekBackgroundColor,
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
                  const material.SizedBox(
                      height: 48), // Space between logo and text
                  // "Get Ready!" Title
                  material.Text(
                    'Get Ready!',
                    style: material.Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                          color: peekWhiteColor,
                          fontWeight: material.FontWeight.bold,
                        ),
                  ),
                  const material.SizedBox(height: 12),
                  // Subtitle
                  material.Text(
                    'Your Peek is on its way...',
                    style: material.Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: peekWhiteColor.withOpacity(0.85)),
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
