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
  String? _imageUrl;
  bool _imageReady = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _errorLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _waitForImage();
  }

  void _waitForImage() {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          final url = data?['imageUrl'];

          if (url != null && !_imageReady) {
            print('📸 Image URL detected: $url');

            setState(() {
              _imageUrl = url;
            });

            // Delay to allow Storage to replicate image
            Future.delayed(const Duration(seconds: 2), () {
              _startCountdown();
            });
          }
        });
  }

  void _startCountdown() {
    setState(() {
      _imageReady = true;
      _errorLoadingImage = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _retry() {
    setState(() {
      _errorLoadingImage = false;
      _countdown = 3;
    });
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_imageUrl == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Waiting for photo..."),
            ],
          ),
        ),
      );
    }

    if (!_imageReady) {
      return Scaffold(body: Center(child: Text("Preparing to peek...")));
    }

    if (_countdown > 0) {
      return Scaffold(
        body: Center(
          child: Text(
            "Opening in $_countdown...",
            style: const TextStyle(fontSize: 32),
          ),
        ),
      );
    }

    // ⏳ Countdown finished, show image
    return Scaffold(
      body: Center(
        child:
            _errorLoadingImage
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text("Could not load the Peek image"),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Try Again"),
                    ),
                  ],
                )
                : Image.network(
                  _imageUrl!,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print("❌ Image failed to load: $error");
                    Future.delayed(Duration.zero, () {
                      if (mounted) {
                        setState(() {
                          _errorLoadingImage = true;
                        });
                      }
                    });
                    return const SizedBox();
                  },
                ),
      ),
    );
  }
}
