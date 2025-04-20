// lib/features/peek/splash_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  final String requestId;
  final String? initialImageUrl;

  const SplashPage({super.key, required this.requestId, this.initialImageUrl});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _imageReceived = false;
  bool _isVerifying = false;
  String? _imageUrl;
  Timer? _countdownTimer;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    if (widget.initialImageUrl != null) {
      _handleReceivedImage(widget.initialImageUrl!);
    } else {
      _waitForImageUrl();
    }
  }

  void _waitForImageUrl() {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) async {
          final imageUrl = snapshot.data()?['imageUrl'];
          if (!_imageReceived && imageUrl != null) {
            _handleReceivedImage(imageUrl);
          }
        });
  }

  void _handleReceivedImage(String imageUrl) async {
    setState(() {
      _isVerifying = true;
      _imageUrl = imageUrl;
    });

    final success = await _verifyImageAccessible(imageUrl);

    if (!mounted) return;

    if (success) {
      setState(() {
        _imageReceived = true;
        _isVerifying = false;
      });
      _startCountdown();
    } else {
      debugPrint('⏳ Image not ready yet, retrying...');
      await Future.delayed(const Duration(seconds: 1));
      _handleReceivedImage(imageUrl); // retry
    }
  }

  Future<bool> _verifyImageAccessible(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _goToImage();
      }
    });
  }

  void _goToImage() {
    if (!mounted || _imageUrl == null) return;
    final uri = Uri(
      path: '/peek-image',
      queryParameters: {
        'requestId': widget.requestId,
        'imageUrl': _imageUrl!, // no encoding needed
      },
    );
    context.go(uri.toString());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            !_imageReceived || _isVerifying
                ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      "Waiting for photo...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
                : Text(
                  "Opening in $_countdown...",
                  style: const TextStyle(fontSize: 32, color: Colors.white),
                ),
      ),
    );
  }
}
