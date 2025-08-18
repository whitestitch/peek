// lib/features/peek/pages/managers/peek_sender_wait_listener.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class PeekStatusUpdate {
  final String status;
  final String? imageUrl;
  final String? senderLocation;
  final DateTime? captureExpiresAt;

  PeekStatusUpdate({
    required this.status,
    this.imageUrl,
    this.senderLocation,
    this.captureExpiresAt,
  });
}

class PeekSenderWaitListener {
  StreamSubscription<DocumentSnapshot>? _subscription;
  final String requestId;

  PeekSenderWaitListener({required this.requestId});

  void listenForUpdates({
    required Function(PeekStatusUpdate) onStatusUpdate,
    required Function(String) onError,
  }) {
    _subscription = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(requestId)
        .snapshots()
        .listen(
      (snap) {
        if (!snap.exists) return;

        final data = snap.data();
        if (data == null) return;

        final status = data['status'] as String?;
        final imageUrl = data['imageUrl'] as String?;
        final expiresAt = data['captureExpiresAt'] as Timestamp?;
        final senderLocation = data['senderLocation'] as String?;

        if (status != null) {
          final update = PeekStatusUpdate(
            status: status,
            imageUrl: imageUrl,
            senderLocation: senderLocation,
            captureExpiresAt: expiresAt?.toDate(),
          );

          onStatusUpdate(update);
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
