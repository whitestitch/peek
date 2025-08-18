// lib/features/peek/pages/managers/peek_response_handler.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeekResponseHandler {
  final _auth = FirebaseAuth.instance;

  Future<void> respondToRequest({
    required DocumentSnapshot<Map<String, dynamic>> request,
    required bool accept,
    required Function(String) onSuccess,
    required Function(String) onError,
  }) async {
    final docRef = request.reference;
    final requestId = request.id;
    final String? uid = _auth.currentUser?.uid;

    if (uid == null) {
      onError("User not logged in, cannot respond to peek request.");
      return;
    }

    try {
      if (accept) {
        await docRef.update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            '[PeekResponseHandler] Request $requestId accepted, status updated.');
        onSuccess(requestId);
      } else {
        await docRef.update({
          'status': 'declined',
          'declinedAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
            '[PeekResponseHandler] Request $requestId declined, status updated.');
        onSuccess(requestId);
      }
    } catch (e) {
      debugPrint('❌ [PeekResponseHandler] Error responding to request: $e');
      onError(
          "Failed to ${accept ? 'accept' : 'decline'} Peek. Please try again.");
    }
  }
}
