import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  final String requestId;
  const SplashPage({super.key, required this.requestId});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _imageReceived = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _listenForImage();
  }

  void _listenForImage() {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          final imageUrl = data?['imageUrl'];

          if (!_imageReceived && imageUrl != null) {
            setState(() {
              _imageReceived = true;
              _imageUrl = imageUrl;
            });
            _startCountdown();
          }
        });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _goToImageView();
      }
    });
  }

  void _goToImageView() {
    if (_imageUrl == null || !mounted) return;

    final encodedUrl = Uri.encodeComponent(_imageUrl!);
    context.go(
      '/peek-image?requestId=${widget.requestId}&imageUrl=$encodedUrl',
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_imageReceived) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Waiting for photo..."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: Text(
          "Opening in $_countdown...",
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
