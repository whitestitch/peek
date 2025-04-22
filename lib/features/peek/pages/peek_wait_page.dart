import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';

/// Waits for acceptance; on accept, routes into SplashPage for the 3‑second countdown.
class PeekWaitPage extends ConsumerStatefulWidget {
  final String requestId;
  const PeekWaitPage({super.key, required this.requestId});

  @override
  ConsumerState<PeekWaitPage> createState() => _PeekWaitPageState();
}

class _PeekWaitPageState extends ConsumerState<PeekWaitPage> {
  StreamSubscription<DocumentSnapshot>? _sub;
  Timer? _timeoutTimer;
  bool _hasTimedOut = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Fallback after 30s
    _timeoutTimer = Timer(const Duration(seconds: 30), _onTimeout);
    _listenForPeek();
  }

  void _listenForPeek() {
    _sub = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (snap) {
            final data = snap.data();
            if (data == null || _navigated) return;

            final status = data['status'] as String?;
            final imageUrl = data['imageUrl'] as String?;

            if (status == 'timeout') {
              _onTimeout();
            } else if (status == 'accepted' && imageUrl != null) {
              _goToSplash(imageUrl);
            } else if (status == 'rejected') {
              _onRejected();
            }
          },
          onError: (e) {
            debugPrint('PeekWaitPage listener error: $e');
          },
        );
  }

  void _onTimeout() {
    if (_hasTimedOut || _navigated) return;
    setState(() => _hasTimedOut = true);

    // mark expired
    ref
        .read(peekControllerProvider.notifier)
        .expirePeek(widget.requestId)
        .catchError((e) => debugPrint('expirePeek error: $e'));

    _cancelAll();

    // show message then back home
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_navigated) {
        _navigated = true;
        context.go('/');
      }
    });
  }

  void _goToSplash(String imageUrl) {
    if (_navigated) return;
    _navigated = true;
    _cancelAll();

    // Let GoRouter build the URI, no manual encoding of %2F
    final uri = Uri(
      path: '/splash',
      queryParameters: {
        'requestId': widget.requestId,
        'initialImageUrl': Uri.encodeFull(imageUrl),
      },
    );
    context.go(uri.toString());
  }

  void _onRejected() {
    if (_navigated) return;
    _navigated = true;
    _cancelAll();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User was not ready to Peek.')),
    );
    context.go('/');
  }

  void _cancelAll() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
  }

  @override
  void dispose() {
    _cancelAll();
    super.dispose();
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
                      '👀 Waiting for someone to Peek…',
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
