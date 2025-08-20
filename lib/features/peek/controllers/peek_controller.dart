// lib/features/peek/controllers/peek_controller.dart

import 'dart:async'; // For TimeoutException
// import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

// userDataProvider import
import 'package:peek/core/providers.dart';
import 'package:peek/core/firestore_service.dart';

// import 'package:flutter/foundation.dart';
// import 'package:peek/features/home/home_page.dart';

import '../data/peek_repository.dart';
import '../providers/peek_providers.dart';

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
    FirebaseFunctions.instanceFor(region: "us-central1"),
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

  Future<String?> createPeekRequestAndUpdateStats({
    required bool needsDailyReset,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      state = state.copyWith(isLoading: false, error: "User not logged in.");
      return null;
    }

    // Check if user can send peeks based on reputation
    try {
      final firestoreService = _ref.read(firestoreServiceProvider);
      final canSendPeeks =
          await firestoreService.canUserSendPeeks(currentUser.uid);

      if (!canSendPeeks) {
        state = state.copyWith(
            isLoading: false,
            error:
                "Your account has been restricted due to community guidelines violations. Please contact support.");
        return null;
      }
    } catch (e) {
      debugPrint("[PeekController] Error checking user reputation: $e");
      // Continue with peek request if reputation check fails
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'initiatePeekRequest',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      // The client SDK now automatically and securely attaches the user's auth token.
      // We DO NOT pass 'senderUid' in the payload anymore.
      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({'debug': kDebugMode});

      final responseData = result.data as Map<String, dynamic>;

      if (responseData['success'] == true &&
          responseData['peekRequestId'] != null) {
        final String peekRequestId = responseData['peekRequestId'] as String;
        debugPrint(
            "[PeekController] Cloud Function success. PeekRequestId: $peekRequestId");

        // Use the repository to update stats, which is a cleaner pattern.
        await _repo.updateUserPeekStats(currentUser.uid,
            needsDailyReset: needsDailyReset);

        state = state.copyWith(isLoading: false);
        return peekRequestId;
      } else {
        final String errorMessage = responseData['message'] as String? ??
            "Failed to initiate Peek request.";
        state = state.copyWith(isLoading: false, error: errorMessage);
        return null;
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          "❌ [PeekController] FirebaseFunctionsException: ${e.code} - ${e.message}");
      state = state.copyWith(
          isLoading: false, error: "Peek request failed. Please try again.");
      return null;
    } catch (e) {
      debugPrint("❌ [PeekController] Unexpected error: $e");
      state = state.copyWith(
          isLoading: false,
          error: "An unexpected error occurred. Please try again.");
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
            .substring(0, e.toString().length > 99 ? 99 : e.toString().length)
      });
    }
  }

  Future<void> expirePeekCapture(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] expirePeekCapture: requestId is empty.");
      return;
    }
    try {
      // Update the status to a new 'expired_capture' state.
      await _firestore.collection('peek_requests').doc(requestId).update({
        'status': 'expired_capture',
      });
      debugPrint('[PeekController] Peek capture expired: $requestId');
      await _analytics
          .logEvent(name: 'peek_request_capture_expired', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId
      });
    } catch (e) {
      debugPrint(
          '[PeekController] Failed to expire peek capture $requestId: $e');
    }
  }

  Future<void> startCaptureCountdown(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] startCaptureCountdown: requestId is empty.");
      return;
    }
    try {
      await _firestore.collection('peek_requests').doc(requestId).update({
        'captureExpiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(seconds: 30)),
        ),
      });
      debugPrint(
          '[PeekController] Capture countdown started for request: $requestId');
    } catch (e) {
      debugPrint(
          '[PeekController] Failed to start capture countdown for $requestId: $e');
    }
  }

  Future<void> debugResetUserLimits() async {
    if (!kDebugMode) {
      debugPrint(
          '[PeekController] DEBUG: Reset limits only available in debug mode.');
      return;
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      debugPrint('[PeekController] DEBUG: Cannot reset limits, user is null.');
      return;
    }
    try {
      await _repo.resetUserPeekLimits(userId);
      _ref.invalidate(userDocumentProvider);
      debugPrint(
          '[PeekController] DEBUG: User limits reset successfully for $userId.');
      await _analytics.logEvent(
        name: 'debug_reset_user_limits',
        parameters: {'user_id_partial': userId.substring(0, 8)},
      );
    } catch (e) {
      debugPrint('[PeekController] DEBUG: Error resetting user limits: $e');
    }
  }

  Future<bool> cancelPeek(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] cancelPeek: requestId is empty.");
      return false;
    }

    final userId = _auth.currentUser?.uid;
    debugPrint(
        "[PeekController] User $userId is cancelling peek request $requestId");
    try {
      await _firestore.collection('peek_requests').doc(requestId).update({
        'status': 'cancelled_by_sender',
      });

      debugPrint(
          "[PeekController] Updated peek request $requestId to 'cancelled_by_sender'.");
      await _analytics
          .logEvent(name: 'peek_request_user_cancelled', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId
      });
      return true;
    } catch (e) {
      debugPrint(
          "❌ [PeekController] Failed to cancel peek request $requestId: $e");
      await _analytics
          .logEvent(name: 'peek_request_cancel_failed', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId,
        'error': e
            .toString()
            .substring(0, e.toString().length > 99 ? 99 : e.toString().length)
      });
      return false;
    }
  }

  Future<void> declinePeekByReceiver(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] declinePeekByReceiver: requestId is empty.");
      return;
    }
    try {
      await _firestore.collection('peek_requests').doc(requestId).update({
        'status': 'cancelled_by_receiver',
        'declinedAt': FieldValue.serverTimestamp(),
      });
      debugPrint(
          "[PeekController] Updated peek request $requestId to 'cancelled_by_receiver'.");
      await _analytics
          .logEvent(name: 'peek_request_receiver_cancelled', parameters: {
        'request_id_partial':
            requestId.length > 8 ? requestId.substring(0, 8) : requestId
      });
    } catch (e) {
      debugPrint(
          "❌ [PeekController] Failed to decline peek request $requestId: $e");
    }
  }

  void cancelPeekBySender(String requestId) async {
    if (requestId.isEmpty) {
      debugPrint("[PeekController] cancelPeekBySender: requestId is empty.");
      return;
    }
    try {
      // Use Cloud Function for consistent cancellation handling
      final functions = FirebaseFunctions.instanceFor(region: "us-central1");
      final callable = functions.httpsCallable('cancelPeekRequest');

      final result = await callable.call({
        'requestId': requestId,
        'reason': 'sender_cancelled',
        'debug': kDebugMode,
      });

      final responseData = result.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        debugPrint(
            "[PeekController] Peek cancelled successfully via Cloud Function: $requestId");
      } else {
        throw Exception('Cloud Function returned success: false');
      }
    } catch (e) {
      debugPrint(
          "❌ [PeekController] Failed to cancel peek request $requestId: $e");
      // Fallback to direct Firestore update if Cloud Function fails
      try {
        await _firestore.collection('peek_requests').doc(requestId).update({
          'status': 'cancelled_by_sender',
        });
        debugPrint(
            "[PeekController] Fallback: Updated peek request $requestId to 'cancelled_by_sender'.");
      } catch (fallbackError) {
        debugPrint("❌ [PeekController] Fallback also failed: $fallbackError");
      }
    }
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
