// lib/features/peek/controllers/peek_controller.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:uuid/uuid.dart'; // Uuid is no longer used here if Cloud Function generates ID

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart'; // For debugPrint

// Import for userDataProvider
import 'package:peek/features/home/home_page.dart';

import '../data/peek_repository.dart';
import '../providers/peek_providers.dart'; // Assuming peekRepositoryProvider is defined here

@immutable
class PeekControllerState {
  final bool isLoading;
  final String? error;

  const PeekControllerState({this.isLoading = false, this.error});

  PeekControllerState copyWith({bool? isLoading, String? error}) {
    return PeekControllerState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final peekControllerProvider =
    StateNotifierProvider<PeekController, PeekControllerState>((ref) {
  return PeekController(
    ref.read(peekRepositoryProvider),
    FirebaseAuth.instance,
    FirebaseFunctions.instanceFor(
        region: "us-central1"), // Match your function's region
    ref,
    FirebaseFirestore.instance,
  );
});

class PeekController extends StateNotifier<PeekControllerState> {
  final PeekRepository _repo;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final Ref _ref;
  final FirebaseFirestore _firestore;

  PeekController(
    this._repo,
    this._auth,
    this._functions,
    this._ref,
    this._firestore,
  ) : super(const PeekControllerState());

  // build method from AsyncNotifier is not typically used in StateNotifier
  // unless for specific initial async setup.
  @override
  Future<void> build() async {
    // For StateNotifier, this method isn't standard unless for specific patterns.
  }

  Future<String?> createPeekRequestAndUpdateStats({
    required bool needsDailyReset,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    // final fromUserId = _auth.currentUser?.uid;
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      debugPrint('❌ [PeekController] Error: User not logged in.');
      state = state.copyWith(isLoading: false, error: "User not logged in.");
      await _analytics.logEvent(
        name: 'peek_request_failed',
        parameters: {'reason': 'user_not_logged_in'},
      );
      return null;
    }
    final fromUserId = currentUser.uid;

    try {
      debugPrint(
          "[PeekController] Attempting to refresh ID token for user: $fromUserId");
      await currentUser.getIdToken(true); // true forces a refresh
      debugPrint("[PeekController] ID token refreshed successfully.");

      debugPrint(
          "[PeekController] Calling 'initiatePeekRequest' Cloud Function for user: $fromUserId");
      final HttpsCallable callable =
          _functions.httpsCallable('initiatePeekRequest');

      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        // Pass any client-side data if your function expects it.
        // If it only needs the authenticated user, the data map can be empty,
        // as senderUid is derived from context.auth in the Cloud Function.
      });

      final Map<String, dynamic> responseData =
          result.data as Map<String, dynamic>;

      if (responseData['success'] == true &&
          responseData['peekRequestId'] != null) {
        final String peekRequestId = responseData['peekRequestId'] as String;

        debugPrint(
            "[PeekController] Cloud Function success. PeekRequestId: $peekRequestId. Updating sender stats.");

        final userDocRef = _firestore.collection('users').doc(fromUserId);
        Map<String, dynamic> statsUpdate = {
          'lastPeekRequestTimestamp': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final userSnapshot = await userDocRef.get();
        // Ensure isPremium check is robust
        final bool isUserPremium = userSnapshot.exists &&
            (userSnapshot.data()?['isPremium'] as bool? ?? false);

        if (!isUserPremium) {
          statsUpdate['dailyPeekCount'] = FieldValue.increment(1);
          if (needsDailyReset) {
            statsUpdate['peekCountLastReset'] = FieldValue.serverTimestamp();
          }
        }
        await userDocRef.update(statsUpdate);
        debugPrint(
            "[PeekController] Sender stats updated for user: $fromUserId");

        state = state.copyWith(isLoading: false);
        return peekRequestId;
      } else {
        final String errorMessage = responseData['message'] as String? ??
            "Failed to initiate Peek via Cloud Function.";
        debugPrint(
            "[PeekController] Cloud Function returned error or no peekRequestId. Message: $errorMessage");
        state = state.copyWith(isLoading: false, error: errorMessage);
        return null;
      }
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint(
          "FirebaseFunctionsException calling initiatePeekRequest: ${e.code} - ${e.message}\nStack: $st");
      state = state.copyWith(
          isLoading: false,
          error: e.message ?? "Cloud function error. Please try again.");
      return null;
    } catch (e, st) {
      debugPrint("Error in createPeekRequestAndUpdateStats: $e\nStack: $st");
      state = state.copyWith(
          isLoading: false,
          error: "An unexpected error occurred while initiating Peek.");
      return null;
    }
  }

  Future<void> expirePeek(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] expirePeek: requestId is empty.");
      return;
    }
    try {
      await _repo.expireRequest(requestId);
      debugPrint('[PeekController] Peek expired via controller: $requestId');
      await _analytics
          .logEvent(name: 'peek_request_expired_client', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId
      });
    } catch (e) {
      debugPrint('[PeekController] Failed to expire peek $requestId: $e');
      await _analytics
          .logEvent(name: 'peek_request_expire_failed_client', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId,
        'error': e
            .toString()
            .substring(0, (e.toString().length > 99 ? 99 : e.toString().length))
      });
    }
  }

  Future<void> debugResetUserLimits() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('[PeekController] DEBUG: Cannot reset limits, user is null.');
      return;
    }
    try {
      await _repo.resetUserPeekLimits(userId);
      _ref.invalidate(userDataProvider);
      debugPrint(
          '[PeekController] DEBUG: User limits reset successfully for $userId.');
    } catch (e) {
      debugPrint('[PeekController] DEBUG: Error resetting user limits: $e');
    }
  }

  Future<void> cancelPeek(String requestId) async {
    final userId = _auth.currentUser?.uid;
    debugPrint(
        "[PeekController] Received request to cancel peek $requestId for user $userId");
    try {
      await _repo.deleteRequest(requestId);
      debugPrint("[PeekController] Deleted peek request $requestId.");
      await _analytics
          .logEvent(name: 'peek_request_user_cancelled', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId
      });
    } catch (e) {
      debugPrint(
          "❌ [PeekController] Failed to cancel peek request $requestId: $e");
    }
  }
}
