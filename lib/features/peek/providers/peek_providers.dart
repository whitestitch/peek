import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// REMOVED: import 'package:peek/features/peek/controllers/peek_controller.dart';
import '../data/peek_repository.dart';
import '../../../core/overlay_animation_service.dart';

/// ✅ Provider for PeekRepository, injecting Firestore and FirebaseAuth
final peekRepositoryProvider = Provider<PeekRepository>((ref) {
  return PeekRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  throw UnimplementedError(
      "navigatorKeyProvider must be overridden in ProviderScope with the actual GlobalKey<NavigatorState> instance from your MaterialApp.");
});

// 2. Provider for the current authenticated user's document stream (real-time updates)
final userProfileStreamProvider =
    StreamProvider.autoDispose<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    debugPrint(
        "[UserProfileStreamProvider] No authenticated user. Returning null stream.");
    return Stream.value(null);
  }
  debugPrint(
      "[UserProfileStreamProvider] Listening to user document: users/$userId");
  return FirebaseFirestore.instance.collection('users').doc(userId).snapshots();
});

// 3. Provider to store the last known reaction counts for the current user
final lastReactionCountsProvider =
    StateProvider<({int likes, int dislikes})>((ref) {
  return (likes: -1, dislikes: -1);
});

// 4. Provider for the OverlayAnimationService
final overlayAnimationServiceProvider =
    Provider<OverlayAnimationService>((ref) {
  return OverlayAnimationService(ref);
});

// 5. Provider that streams pending peek requests for the current user - CORRECTLY FIXED
final pendingPeekRequestsProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    debugPrint(
        "[pendingPeekRequestsProvider] No authenticated user. Returning empty stream.");
    return Stream.value([]);
  }

  debugPrint(
      "[pendingPeekRequestsProvider] Listening for peek requests for user: $uid");

  return FirebaseFirestore.instance
      .collection('peek_requests')
      .where('receiverUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending_acceptance')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    debugPrint(
        "[pendingPeekRequestsProvider] Snapshot received. Found ${snapshot.docs.length} pending requests for UID: $uid. Request IDs: ${snapshot.docs.map((d) => d.id).toList()}");
    return snapshot.docs;
  });
});

// 6. Helper provider to get the count of pending requests
final pendingRequestsCountProvider = Provider<int>((ref) {
  final pendingRequests = ref.watch(pendingPeekRequestsProvider);
  return pendingRequests.when(
    data: (requests) => requests.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});

// 7. Helper provider to check if there are any pending requests
final hasPendingRequestsProvider = Provider<bool>((ref) {
  final count = ref.watch(pendingRequestsCountProvider);
  return count > 0;
});

// 8. Provider for FCM token management
final fcmTokenProvider = StreamProvider.autoDispose<String?>((ref) {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) {
    debugPrint(
        "[fcmTokenProvider] No authenticated user. Returning null stream.");
    return Stream.value(null);
  }

  debugPrint("[fcmTokenProvider] Listening to FCM token for user: $userId");
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
    if (doc.exists) {
      final data = doc.data();
      return data?['fcmToken'] as String?;
    }
    return null;
  });
});

// 9. Provider to check if current user has FCM token
final hasFCMTokenProvider = Provider<bool>((ref) {
  final fcmToken = ref.watch(fcmTokenProvider);
  return fcmToken.when(
    data: (token) => token != null && token.isNotEmpty,
    loading: () => false,
    error: (_, __) => false,
  );
});

// 10. Provider for enhanced peek request status tracking
final peekRequestStatusProvider = StateProvider<Map<String, String>>((ref) {
  return <String, String>{};
});

// 11. Provider for peek request history - CORRECTLY FIXED
final peekRequestHistoryProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    debugPrint(
        "[peekRequestHistoryProvider] No authenticated user. Returning empty stream.");
    return Stream.value([]);
  }

  debugPrint(
      "[peekRequestHistoryProvider] Listening for peek request history for user: $uid");

  return FirebaseFirestore.instance
      .collection('peek_requests')
      .where('receiverUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snapshot) {
    debugPrint(
        "[peekRequestHistoryProvider] Found ${snapshot.docs.length} total requests");
    return snapshot.docs;
  });
});
