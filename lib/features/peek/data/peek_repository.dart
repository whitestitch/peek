// lib/features/peek/data/peek_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PeekRepository {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  PeekRepository({required this.firestore, required this.auth});

  String? get currentUserId => auth.currentUser?.uid;

  // --- Existing Methods ---
  Future<void> createRequest({
    required String requestId,
    required String from,
    required String to,
    required Timestamp createdAt,
    required Timestamp expiresAt,
  }) async {
    await firestore.collection('peek_requests').doc(requestId).set({
      'from': from,
      'to': to,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'status': 'pending',
      'storagePath': null,
      'imageUrl': null,
      'respondedAt': null,
    });
    print('[PeekRepository] Created peek request: $requestId');
  }

  Future<void> expireRequest(String requestId) async {
    await firestore.collection('peek_requests').doc(requestId).update({
      'status': 'expired',
    });
    print('[PeekRepository] Expired peek request: $requestId');
  }

  // --- *** OPTIMIZED METHOD *** ---
  /// Updates user stats after a successful peek request.
  Future<void> updateUserPeekStats(
    String userId, {
    bool needsDailyReset = false,
  }) async {
    final userRef = firestore.collection('users').doc(userId);
    final now = Timestamp.now();

    // Prepare data for update
    final Map<String, dynamic> updateData = {
      'lastPeekRequestTimestamp': now,
      // If resetting, set count directly to 1, otherwise increment.
      'dailyPeekCount': needsDailyReset ? 1 : FieldValue.increment(1),
    };

    if (needsDailyReset) {
      updateData['peekCountLastReset'] = now;
      print(
        '[PeekRepository] Resetting daily count to 1 and updating stats for user: $userId',
      );
    } else {
      print(
        '[PeekRepository] Incrementing daily count and updating stats for user: $userId',
      );
    }

    // Use merge: true to avoid overwriting other user fields
    await userRef.set(updateData, SetOptions(merge: true));
  }
  // --- *** END OF OPTIMIZED METHOD *** ---

  // --- *** REMOVED _getCurrentPeekCount as it's no longer needed by optimized method *** ---
  // Future<int> _getCurrentPeekCount(String userId) async { ... }
  // --- *** END OF REMOVAL *** ---

  // --- *** DEBUG METHOD (Keep as before) *** ---
  /// Resets cooldown and daily count fields in Firestore for the given user.
  /// Intended for debugging/testing purposes ONLY.
  Future<void> resetUserPeekLimits(String userId) async {
    final userRef = firestore.collection('users').doc(userId);
    // Explicitly set fields to null/zero to ensure reset
    await userRef.set({
      'lastPeekRequestTimestamp': null,
      'dailyPeekCount': 0,
      'peekCountLastReset': null,
    }, SetOptions(merge: true)); // Merge to avoid deleting other fields
    print('[PeekRepository] DEBUG: Reset peek limits for user $userId');
  }

  // --- *** END OF DEBUG METHOD *** ---
}
