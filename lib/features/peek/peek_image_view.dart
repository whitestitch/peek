// lib/features/peek/peek_image_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:go_router/go_router.dart';

class PeekImageView extends StatefulWidget {
  final String requestId;
  const PeekImageView({super.key, required this.requestId});

  @override
  State<PeekImageView> createState() => _PeekImageViewState();
}

class _PeekImageViewState extends State<PeekImageView>
    with SingleTickerProviderStateMixin {
  String? _signedUrl;
  String? _storagePath;
  bool _isPremium = false;
  bool _showReplay = false;
  bool _hasStarted = false;
  int _viewDuration = 5;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;
  Timer? _viewTimer, _replayTimer;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    _loadPremiumStatus();
    _fetchSignedUrlAndStart();
  }

  Future<void> _loadPremiumStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final premium = doc.data()?['isPremium'] == true;
      setState(() {
        _isPremium = premium;
        _viewDuration = premium ? 10 : 5;
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load premium status: $e');
    }
  }

  Future<void> _fetchSignedUrlAndStart() async {
    final snap =
        await FirebaseFirestore.instance
            .collection('peek_requests')
            .doc(widget.requestId)
            .get();
    final path = snap.data()?['storagePath'] as String?;
    if (path == null) {
      debugPrint('❌ No storagePath found');
      return;
    }
    _storagePath = path;

    // small buffer for metadata
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final url = await FirebaseStorage.instance.ref(path).getDownloadURL();
      setState(() => _signedUrl = url);
      _startViewCycle();
    } catch (e) {
      debugPrint('❌ Failed to fetch downloadURL: $e');
    }
  }

  void _startViewCycle() {
    if (_hasStarted || _signedUrl == null) return;
    _hasStarted = true;
    _fadeCtrl.forward();
    _viewTimer = Timer(Duration(seconds: _viewDuration), () {
      if (!mounted) return;
      if (_isPremium) {
        setState(() => _showReplay = true);
        _replayTimer = Timer(const Duration(seconds: 5), _cleanupAndExit);
      } else {
        Timer(const Duration(seconds: 2), _cleanupAndExit);
      }
    });
  }

  Future<void> _cleanupAndExit() async {
    // Delete Firestore document
    await FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .delete();

    // Delete storage file defensively
    if (_storagePath != null) {
      final ref = FirebaseStorage.instance.ref(_storagePath!);
      try {
        await ref.delete();
        debugPrint('✅ Deleted storage file: $_storagePath');
      } on FirebaseException catch (e) {
        if (e.code == 'object-not-found') {
          debugPrint('⚠️ File already removed: $_storagePath');
        } else {
          debugPrint('❌ Delete error: ${e.code} - ${e.message}');
        }
      }
    }

    if (mounted) GoRouter.of(context).go('/');
  }

  @override
  void dispose() {
    _viewTimer?.cancel();
    _replayTimer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_signedUrl == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                _signedUrl!,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const Center(
                      child: Text(
                        '❌ Could not load image',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
              ),
            ),
            if (_showReplay)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasStarted = false;
                        _showReplay = false;
                      });
                      _startViewCycle();
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Replay Peek'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
