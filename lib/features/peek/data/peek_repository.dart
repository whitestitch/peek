import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeekRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  PeekRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> createRequest({
    required String requestId,
    required String from,
    required String to,
    required Timestamp createdAt,
    required Timestamp expiresAt,
  }) async {
    await _firestore.collection('peek_requests').doc(requestId).set({
      'from': from,
      'to': to,
      'status': 'pending',
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'timeout': false,
    });
  }

  Future<void> expireRequest(String requestId) async {
    int retries = 0;
    const int maxRetries = 3;
    while (retries < maxRetries) {
      try {
        await _firestore.collection('peek_requests').doc(requestId).update({
          'status': 'timeout',
          'timeout': true,
          'expiredAt': Timestamp.now(),
        });
        print(
          '[PeekRepository] Successfully updated peek request $requestId to "timeout".',
        );
        return; // Successfully updated, exit the loop.
      } catch (e) {
        print(
          '[PeekRepository] Error updating peek request $requestId (attempt ${retries + 1}): $e',
        );
        if (e.toString().contains('Unavailable')) {
          retries++;
          await Future.delayed(
            const Duration(seconds: 2),
          ); // Wait before retrying.
        } else {
          rethrow;
        }
      }
    }
    throw Exception(
      'Failed to update peek request $requestId after $maxRetries retries.',
    );
  }
}
