import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';

class PeekWaitPage extends ConsumerStatefulWidget {
  final String requestId;
  const PeekWaitPage({super.key, required this.requestId});

  @override
  ConsumerState<PeekWaitPage> createState() => _PeekWaitPageState();
}

class _PeekWaitPageState extends ConsumerState<PeekWaitPage> {
  StreamSubscription<DocumentSnapshot>? _subscription;
  Timer? _localTimer;
  bool _hasTimedOut = false;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    // Start a local 30-second timer (the designated peek duration)
    _localTimer = Timer(const Duration(seconds: 30), () {
      print('[PeekWaitPage] 30-second local timer expired.');
      _handleTimeout();
    });
    print(
      '[PeekWaitPage] initState: Starting snapshot listener for requestId: ${widget.requestId}',
    );
    _listenToRequest();
  }

  void _listenToRequest() {
    _subscription = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (snapshot) {
            print('[PeekWaitPage] Snapshot received: ${snapshot.data()}');
            if (!snapshot.exists || _hasNavigated) return;

            final data = snapshot.data();
            final status = data?['status'];
            final imageUrl = data?['imageUrl'];

            // If the document is marked as "timeout", trigger the timeout logic.
            if (status == 'timeout') {
              print('[PeekWaitPage] Document status is "timeout".');
              _handleTimeout();
              return;
            }

            // If the peek was accepted and an image URL is available, navigate to the image page.
            if (status == 'accepted' && imageUrl != null) {
              print('[PeekWaitPage] Peek accepted; imageUrl found.');
              _navigateToImage(imageUrl);
              return;
            }

            // If the peek was rejected, show an appropriate message.
            if (status == 'rejected') {
              print('[PeekWaitPage] Peek request was rejected.');
              _showRejected();
              return;
            }

            // Optionally log the current status.
            print('[PeekWaitPage] Current status is "$status". Waiting...');
          },
          onError: (error) {
            print('[PeekWaitPage] Firestore listener error: $error');
          },
        );
  }

  void _handleTimeout() {
    if (_hasTimedOut || _hasNavigated) return;
    setState(() => _hasTimedOut = true);
    print('[PeekWaitPage] _handleTimeout() fired. Initiating document update.');

    // Trigger the update without awaiting to ensure the UI thread isn’t blocked.
    ref
        .read(peekControllerProvider.notifier)
        .expirePeek(widget.requestId)
        .then((_) {
          print('[PeekWaitPage] expirePeek() completed successfully.');
        })
        .catchError((error) {
          print('[PeekWaitPage] expirePeek() encountered an error: $error');
        });

    _cancelAll(); // Cancel timer and subscription.

    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || _hasNavigated) return;
      _hasNavigated = true;
      print('[PeekWaitPage] Redirecting to home after timeout.');
      context.go('/');
    });
  }

  void _navigateToImage(String imageUrl) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _cancelAll();
    print('[PeekWaitPage] Navigating to image page with URL: $imageUrl');
    context.go('/peek-image?requestId=${widget.requestId}&imageUrl=$imageUrl');
  }

  void _showRejected() {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;
    _cancelAll();
    print(
      '[PeekWaitPage] Peek was rejected; showing notification and returning home.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User was not ready to Peek.')),
    );
    context.go('/');
  }

  void _cancelAll() {
    _subscription?.cancel();
    _localTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
    print('[PeekWaitPage] Disposed.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child:
            _hasTimedOut
                ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    '😔 No one is available to Peek right now.\nTry again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                )
                : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 24),
                    Text(
                      '👀 Waiting for someone to Peek...',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
      ),
    );
  }
}
