import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class PeekReceiverPage extends StatefulWidget {
  const PeekReceiverPage({super.key});

  @override
  State<PeekReceiverPage> createState() => _PeekReceiverPageState();
}

class _PeekReceiverPageState extends State<PeekReceiverPage> {
  final _auth = FirebaseAuth.instance;
  DocumentSnapshot<Map<String, dynamic>>? _currentRequest;

  @override
  void initState() {
    super.initState();
    _listenForRequests();
  }

  @override
  void dispose() {
    super.dispose();
    // _streamSub?.cancel();
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     // UI
  //   );
  // }

  void _listenForRequests() {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final doc = snapshot.docs.first;
            if (mounted) {
              setState(() {
                _currentRequest = doc;
              });
            }
          }
        });
  }

  Future<void> _respondToRequest({required bool accept}) async {
    if (_currentRequest == null) return;

    final docRef = _currentRequest!.reference;
    final uid = _auth.currentUser?.uid ?? 'anonymous';

    await docRef.update({
      'status': accept ? 'accepted' : 'rejected',
      'to': uid,
      'respondedAt': FieldValue.serverTimestamp(),
    });

    if (accept) {
      // ✅ Only receiver opens the camera
      context.go('/capture');
    } else {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Peek Requests')),
      body: Center(
        child:
            _currentRequest == null
                ? const Text('No active peek requests right now.')
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.visibility, size: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Someone is peeking you!\nDo you want to respond with a photo?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _respondToRequest(accept: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Yes'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _respondToRequest(accept: false),
                      icon: const Icon(Icons.close),
                      label: const Text('Not Now'),
                    ),
                  ],
                ),
      ),
    );
  }
}
