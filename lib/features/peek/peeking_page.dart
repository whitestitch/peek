import 'dart:async'; // Needed for Timer
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class PeekingPage extends StatefulWidget {
  final String requestId;

  const PeekingPage({super.key, required this.requestId});

  @override
  State<PeekingPage> createState() => _PeekingPageState();
}

class _PeekingPageState extends State<PeekingPage> {
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();

    _startTimeoutChecker(); // Starts countdown

    FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((doc) {
          final data = doc.data();
          if (data == null) return;

          final status = data['status'];
          print('📡 Firestore status: $status');

          if (status == 'accepted') {
            _timeoutTimer?.cancel();
            context.go('/');
          } else if (status == 'rejected') {
            _timeoutTimer?.cancel();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User was not ready to Peek.')),
            );
            context.go('/');
          } else if (status == 'expired') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No one was available to Peek.')),
            );
            context.go('/');
          }
        });
  }

  void _startTimeoutChecker() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('peek_requests')
            .doc(widget.requestId)
            .get();

    final data = doc.data();
    if (data == null) return;

    final status = data['status'];
    final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
    if (status != 'pending' || expiresAt == null) return;

    print('🧭 Starting countdown loop...');

    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final now = DateTime.now();
      print('⏱️ Timer check: now = $now | expiresAt = $expiresAt');

      if (now.isAfter(expiresAt)) {
        timer.cancel();
        print('⏰ Expired! Updating Firestore status...');
        try {
          await FirebaseFirestore.instance
              .collection('peek_requests')
              .doc(widget.requestId)
              .update({'status': 'expired'});
          print('✅ Status updated to expired');
        } catch (e) {
          print('🔥 Failed to update Firestore: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Waiting for someone to respond...'),
          ],
        ),
      ),
    );
  }
}
