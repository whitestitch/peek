import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

class PeekImageView extends StatefulWidget {
  final String imageUrl;
  final String requestId;

  const PeekImageView({
    super.key,
    required this.imageUrl,
    required this.requestId,
  });

  @override
  State<PeekImageView> createState() => _PeekImageViewState();
}

class _PeekImageViewState extends State<PeekImageView>
    with SingleTickerProviderStateMixin {
  bool _hasStarted = false;
  bool _isPremium = false;
  bool _showReplay = false;
  int _viewDuration = 5; // fallback default

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  Timer? _viewTimer;
  Timer? _replayWindowTimer;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _initializeSession();
  }

  Future<void> _initializeSession() async {
    await _loadUserStatus();
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startViewCycle());
    }
  }

  Future<void> _loadUserStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        _isPremium = doc.data()?['isPremium'] == true;
        _viewDuration = _isPremium ? 10 : 5;
      } catch (e) {
        debugPrint('⚠️ Failed to load premium status: $e');
      }
    }
  }

  void _startViewCycle() {
    if (_hasStarted) return;
    _hasStarted = true;
    _fadeController.forward();

    _viewTimer = Timer(Duration(seconds: _viewDuration), () {
      if (!mounted) return;

      if (_isPremium) {
        setState(() => _showReplay = true);
        _replayWindowTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() => _showReplay = false);
            _cleanupSession();
          }
        });
      } else {
        Timer(const Duration(seconds: 2), () async {
          if (mounted) {
            await _cleanupSession();
            if (mounted) context.go('/');
          }
        });
      }
    });
  }

  Future<void> _replayPeek() async {
    setState(() {
      _hasStarted = false;
      _showReplay = false;
    });

    await Future.delayed(const Duration(milliseconds: 100));
    _startViewCycle();
  }

  Future<void> _cleanupSession() async {
    try {
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .delete();

      final ref = FirebaseStorage.instance.refFromURL(widget.imageUrl);
      await ref.delete();

      debugPrint('🧹 Peek session cleaned up.');
    } catch (e) {
      debugPrint('⚠️ Cleanup error: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _viewTimer?.cancel();
    _replayWindowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
                errorBuilder:
                    (context, error, stackTrace) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('❌ Could not load the Peek image'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
              ),
            ),
          ),

          if (_showReplay && _isPremium)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: _replayPeek,
                  icon: const Icon(Icons.replay),
                  label: const Text('Replay Peek'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
