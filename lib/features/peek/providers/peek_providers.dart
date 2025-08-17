import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// REMOVED: import 'package:peek/features/peek/controllers/peek_controller.dart';
import '../data/peek_repository.dart';
import '../../../core/overlay_animation_service.dart';
import 'package:peek/features/onboarding/providers/onboarding_provider.dart';

final peekAuthUidProvider = StreamProvider<String?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
});

/// ✅ Provider for PeekRepository, injecting Firestore and FirebaseAuth
final peekRepositoryProvider = Provider<PeekRepository>((ref) {
  return PeekRepository(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );
});

/// Captures the moment this ProviderScope came alive.
/// Used to ignore any "old" reaction docs on the first snapshot.
final appStartTimeProvider = Provider<DateTime>((ref) => DateTime.now());

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  throw UnimplementedError(
      "navigatorKeyProvider must be overridden in ProviderScope with the actual GlobalKey<NavigatorState> instance from your MaterialApp.");
});

// 2. Provider for the current authenticated user's document stream (real-time updates)
final userProfileStreamProvider =
    StreamProvider<DocumentSnapshot<Map<String, dynamic>>?>((ref) {
  final authState = ref.watch(peekAuthUidProvider);
  final userId = authState.value;

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
// final lastReactionCountsProvider =
//     StateProvider<({int likes, int dislikes})>((ref) {
//   return (likes: -1, dislikes: -1);
// });

// 4. Provider for the OverlayAnimationService
final overlayAnimationServiceProvider =
    Provider<OverlayAnimationService>((ref) {
  return OverlayAnimationService(ref);
});

// 5. Provider that streams pending peek requests for the current user
final pendingPeekRequestsProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  // Watch the auth state to automatically refresh when user changes
  final authState = ref.watch(peekAuthUidProvider);
  final uid = authState.value;

  if (uid == null) {
    debugPrint(
        "[peekRequestHistoryProvider] No authenticated user. Returning empty stream.");
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
      // Prevent unhandled stream errors (e.g., missing index) from crashing the app.
      .handleError((error, stackTrace) {
    debugPrint("[pendingPeekRequestsProvider] Firestore stream error: $error");
  }).map((snapshot) {
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
      .handleError((error, stackTrace) {
    debugPrint("[peekRequestHistoryProvider] Firestore stream error: $error");
  }).map((snapshot) {
    debugPrint(
        "[peekRequestHistoryProvider] Found ${snapshot.docs.length} total requests");
    return snapshot.docs;
  });
});

/// users/<me>/received_reactions
final newReactionStreamProvider = StreamProvider.autoDispose<
    List<QueryDocumentSnapshot<Map<String, dynamic>>>>((ref) {
  // Watch the auth state to be reactive.
  final authState = ref.watch(peekAuthUidProvider);
  final uid = authState.value;

  if (uid == null) {
    return Stream.value([]);
  }

  // Only consider reactions created after this app session started.
  final appStart = ref.read(appStartTimeProvider);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('received_reactions')
      // Filter out any historical/backlog docs on the initial snapshot.
      .where('timestamp', isGreaterThan: Timestamp.fromDate(appStart))
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snap) => snap.docs);
});

final pendingAnimationProvider = StateProvider<List<String>>((ref) => []);

// Provider to keep track of reaction animations that have already been shown in this session.
final processedReactionIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Listens to users/<me>/received_reactions and triggers overlay animations on NEW events.
/// Activate by reading this provider once (e.g., in a wait page or app root).
final reactionOverlayListenerProvider = Provider.autoDispose<void>((ref) {
  final overlay = ref.read(overlayAnimationServiceProvider);

  final onboardingDone = ref
      .watch(onboardingCompleteProvider)
      .maybeWhen(data: (v) => v, orElse: () => false);

  // first emission guard
  var primed = false;

  ref.listen(
    newReactionStreamProvider,
    (previous, next) {
      if (!next.hasValue) return;
      final docs = next.value!;

      // Deduplicate events per session to avoid replays.
      final processedCtl = ref.read(processedReactionIdsProvider.notifier);
      final already = {...processedCtl.state};

      // On the *first* snapshot, only animate docs created *after* app start.
      // Everything older (or missing timestamp) is "primed" without animation.
      if (!primed) {
        final appStart = ref.read(appStartTimeProvider); // defined earlier

        // If onboarding isn't done yet, or this is the first emission for this session,
        // prime all existing docs as processed WITHOUT animating.
        // We detect "first emission" by the processed set being empty.
        final isFirstEmission = already.isEmpty;
        if (!onboardingDone || isFirstEmission) {
          for (final doc in docs) {
            already.add(doc.id);
          }
          processedCtl.state = already; // ✅ prime & bail
          return;
        }

        // Subsequent emissions: animate only truly new docs.
        for (final doc in docs) {
          final id = doc.id;
          if (already.contains(id)) continue;
          final data = doc.data();
          final type = (data['reactionType'] ?? '').toString().toLowerCase();
          if (type == 'like') {
            overlay.showLikeAnimation();
          } else if (type == 'dislike') {
            overlay.showDislikeAnimation();
          }
          already.add(id);
        }
        processedCtl.state = already;
        primed = true;
        return;
      }

      // Subsequent snapshots: animate only truly new docs.
      for (final doc in docs) {
        final id = doc.id;
        if (already.contains(id)) continue;
        final data = doc.data();
        final type = (data['reactionType'] ?? '').toString().toLowerCase();
        if (type == 'like') {
          overlay.showLikeAnimation();
        } else if (type == 'dislike') {
          overlay.showDislikeAnimation();
        }
        already.add(id);
      }

      processedCtl.state = already;
    },
  );
});

// This allows us to programmatically dismiss it if the request is cancelled.
final activePeekRequestDialogProvider = StateProvider<String?>((ref) => null);
