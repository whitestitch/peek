// lib/features/peek/pages/managers/peek_request_listener.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeekRequestListener {
  StreamSubscription<QuerySnapshot>? _subscription;
  final _auth = FirebaseAuth.instance;

  void listenForRequests({
    required Function(DocumentSnapshot<Map<String, dynamic>>) onRequestReceived,
    required VoidCallback onRequestRemoved,
    required Function(String) onError,
  }) {
    _subscription = FirebaseFirestore.instance
        .collection('peek_requests')
        .where('receiverUid', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'pending_acceptance')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          onRequestReceived(doc);
        } else {
          onRequestRemoved();
        }
      },
      onError: (error) {
        onError(error.toString());
      },
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
