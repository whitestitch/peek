// lib/features/peek/controllers/peek_controller.dart

import 'dart:async'; // For TimeoutException
// import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// userDataProvider import
import 'package:peek/core/providers.dart';

import 'package:flutter/foundation.dart';
// import 'package:peek/features/home/home_page.dart';

import '../data/peek_repository.dart';
import '../providers/peek_providers.dart';

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

  Future<String?> _getIdTokenRobust(User user,
      {bool forceRefresh = true}) async {
    try {
      debugPrint(
          '[PeekController] Attempting getIdToken(forceRefresh: $forceRefresh) for user: ${user.uid}');

      // First attempt: Try with the requested forceRefresh value
      final token = await user.getIdToken(forceRefresh).timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Token request timed out'),
          );
      debugPrint(
          '✅ [PeekController] Successfully got token with forceRefresh: $forceRefresh');
      return token;
    } on FirebaseAuthException catch (e) {
      debugPrint(
          '❌ [PeekController] FirebaseAuthException with forceRefresh=$forceRefresh: ${e.code} - ${e.message}');

      // If forced refresh failed and we were trying to force refresh, fall back to cached token
      if (forceRefresh && e.code == 'internal-error') {
        try {
          debugPrint(
              '[PeekController] Falling back to cached token (forceRefresh: false)...');
          final cachedToken = await user.getIdToken(false).timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('Cached token request timed out'),
              );
          debugPrint(
              '✅ [PeekController] Successfully got cached token as fallback');
          return cachedToken;
        } on FirebaseAuthException catch (fallbackError) {
          debugPrint(
              '❌ [PeekController] Cached token also failed: ${fallbackError.code} - ${fallbackError.message}');

          // Final fallback for emulator: attempt re-authentication
          if (fallbackError.code == 'internal-error' && user.isAnonymous) {
            return await _handleEmulatorTokenFallback(user);
          }
        } on TimeoutException catch (_) {
          debugPrint('⏰ [PeekController] Cached token request timed out');
        }
      }

      return null;
    } on TimeoutException catch (_) {
      debugPrint('⏰ [PeekController] Token request timed out');

      // Try cached version on timeout
      if (forceRefresh) {
        try {
          debugPrint(
              '[PeekController] Timeout fallback: trying cached token...');
          final cachedToken = await user.getIdToken(false).timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException('Cached token timeout'),
              );
          debugPrint('✅ [PeekController] Got cached token after timeout');
          return cachedToken;
        } catch (e) {
          debugPrint(
              '❌ [PeekController] Cached token after timeout also failed: $e');
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [PeekController] Unexpected error during getIdToken: $e');
      return null;
    }
  }

  /// Final fallback for Firebase emulator anonymous user token issues
  Future<String?> _handleEmulatorTokenFallback(User user) async {
    try {
      debugPrint(
          '[PeekController] 🔄 Attempting emulator-specific fallback for anonymous user...');

      // Check if we're in debug mode (likely using emulator)
      if (!kDebugMode) {
        debugPrint(
            '[PeekController] Not in debug mode, skipping emulator fallback');
        return null;
      }

      // For emulator anonymous users, try to re-authenticate
      debugPrint(
          '[PeekController] Re-authenticating anonymous user for fresh token...');
      final userCredential = await _auth.signInAnonymously();

      if (userCredential.user != null) {
        debugPrint(
            '[PeekController] ✅ Re-authentication successful, attempting token retrieval...');

        // Wait a brief moment for the new auth state to settle
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          final freshToken = await userCredential.user!.getIdToken(false);
          debugPrint(
              '[PeekController] ✅ Successfully got token after re-authentication');
          return freshToken;
        } catch (tokenError) {
          debugPrint(
              '[PeekController] ❌ Token retrieval failed even after re-auth: $tokenError');
        }
      }

      return null;
    } catch (e) {
      debugPrint('[PeekController] ❌ Emulator fallback failed: $e');
      return null;
    }
  }

  Future<String?> createPeekRequestAndUpdateStats({
    required bool needsDailyReset,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
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
      String? idTokenValue;

      // --- Token Retrieval Logic (identical to your uploaded file) ---
      debugPrint("[PeekController] Current user state check:");
      debugPrint("  - User: ${currentUser.uid}");
      debugPrint("  - isAnonymous: ${currentUser.isAnonymous}");
      debugPrint("  - providerData length: ${currentUser.providerData.length}");

      if (kDebugMode) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      debugPrint(
          "[PeekController] createPeekRequestAndUpdateStats: Attempting robust token retrieval for user: $fromUserId");
      idTokenValue = await _getIdTokenRobust(currentUser, forceRefresh: true);

      if (idTokenValue == null) {
        debugPrint(
            "❌ [PeekController] Could not obtain ID token after all fallback attempts");
        if (kDebugMode && currentUser.isAnonymous) {
          debugPrint(
              "🔧 [PeekController] Debug mode detected: attempting to proceed without token refresh...");
          try {
            idTokenValue = await currentUser.getIdToken(false).timeout(
              const Duration(seconds: 3),
              onTimeout: () {
                debugPrint(
                    "⚠️ [PeekController] Final token attempt timed out, proceeding with emulator bypass");
                return null;
              },
            );
            if (idTokenValue != null) {
              debugPrint(
                  "✅ [PeekController] Got basic token for emulator, proceeding. Length: ${idTokenValue.length}");
            } else {
              debugPrint(
                  "⚠️ [PeekController] No token available, but continuing in emulator mode");
            }
          } catch (e) {
            debugPrint(
                "⚠️ [PeekController] Final token attempt failed: $e, continuing anyway in emulator mode");
          }
        }

        // If still no token and not in debug mode, fail gracefully
        if (idTokenValue == null && !kDebugMode) {
          const String errorMessage =
              "Authentication error. Please sign in again.";
          state = state.copyWith(isLoading: false, error: errorMessage);
          await _analytics.logEvent(
            name: 'peek_request_failed',
            parameters: {
              'reason': 'token_unavailable',
              'is_debug': 'false',
              'is_anonymous': currentUser.isAnonymous ? 'true' : 'false',
            },
          );
          return null;
        }

        if (kDebugMode && idTokenValue == null) {
          debugPrint(
              "🚧 [PeekController] Proceeding with emulator bypass (no token refresh)");
          await _analytics.logEvent(
            name: 'peek_request_emulator_bypass',
            parameters: {
              'reason': 'token_refresh_failed',
              'user_anonymous': 'true',
            },
          );
        }
      }

      if (idTokenValue != null) {
        debugPrint(
            "✅ [PeekController] Got ID token. Token length: ${idTokenValue.length}");
      } else {
        debugPrint(
            "🚧 [PeekController] Proceeding without fresh token (emulator mode or token fetch failed).");
      }

      // debugPrint(
      //     "[PeekController] Calling 'initiatePeekRequest' Cloud Function for user: $fromUserId");

      // In emulator mode, check if we should bypass the cloud function
      if (kDebugMode && idTokenValue == null) {
        debugPrint(
            "[PeekController] 🚧 Emulator mode: Attempting direct Firestore write fallback");

        bool directWriteSucceeded = false; // Use existing variable name
        try {
          final currentUserDocRef =
              _firestore.collection('users').doc(fromUserId);
          final currentUserDoc = await currentUserDocRef.get().timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw TimeoutException(
                  "Timeout getting current user doc for direct write fallback"));

          if (!currentUserDoc.exists) {
            debugPrint(
                "[PeekController] User $fromUserId not in Firestore. Creating document for emulator mode...");
            await currentUserDocRef.set({
              'displayName': 'Test User $fromUserId',
              'createdAt': FieldValue.serverTimestamp(),
              'isPremium': false,
              'dailyPeekCount': 0,
            }).timeout(const Duration(seconds: 15),
                onTimeout: () => throw TimeoutException(
                    "Timeout creating current user doc for direct write fallback"));
            debugPrint(
                "[PeekController] ✅ User document created for $fromUserId in emulator.");
          } else {
            debugPrint(
                "[PeekController] User document for $fromUserId already exists.");
          }

          // For emulator mode, we'll use a self-peek or create a dummy recipient
          String? recipientUid;

          // Try to find other users first
          debugPrint(
              "[PeekController] Finding recipient for direct write fallback...");
          final usersSnapshot = await _firestore
              .collection('users')
              .limit(10)
              .get()
              .timeout(const Duration(seconds: 10),
                  onTimeout: () => throw TimeoutException(
                      "Timeout getting users for recipient selection in direct write fallback"));
          debugPrint(
              "[PeekController] Fetched ${usersSnapshot.docs.length} users in emulator for recipient selection.");

          final otherUsers =
              usersSnapshot.docs.where((doc) => doc.id != fromUserId).toList();
          debugPrint(
              "[PeekController] Found ${otherUsers.length} other users (excluding current user) for direct write fallback.");

          if (otherUsers.isNotEmpty) {
            final randomIndex = DateTime.now().millisecond % otherUsers.length;
            recipientUid = otherUsers[randomIndex].id;
            debugPrint(
                "[PeekController] Selected existing user as recipient for direct write: $recipientUid");
          } else {
            recipientUid =
                'dummy_recipient_fallback_${DateTime.now().millisecondsSinceEpoch}';
            debugPrint(
                "[PeekController] No other users found, creating dummy recipient for direct write testing: $recipientUid");
            try {
              await _firestore.collection('users').doc(recipientUid).set({
                'displayName': 'Dummy Recipient Fallback',
                'createdAt': FieldValue.serverTimestamp(),
                'isPremium': false,
                'fcmToken':
                    'dummy_fcm_token_direct_write_test_v2', // Slightly different for clarity
              }).timeout(const Duration(seconds: 15),
                  onTimeout: () => throw TimeoutException(
                      "Timeout creating dummy recipient for direct write fallback"));
              debugPrint(
                  "[PeekController] ✅ Successfully created dummy recipient for direct write: $recipientUid");
            } catch (e) {
              debugPrint(
                  "[PeekController] ❌ Failed to create dummy recipient $recipientUid for direct write: $e. Cannot use this recipient.");
              recipientUid = null;
            }
          }

          debugPrint(// Consolidated duplicated log
              "[PeekController] Final recipient for emulator mode direct write: $recipientUid");

          // Your custom Firestore connection test
          // This test failed with 'unavailable' in your logs, indicating connection instability.
          // We will log its failure but proceed to attempt the main write.
          bool connectionTestPassed = false;

          // Test Firestore connection before creating peek request
          try {
            debugPrint(
                "[PeekController] Performing pre-write Firestore connection test (reading own user doc)...");
            await _firestore.collection('users').doc(fromUserId).get().timeout(
                const Duration(seconds: 7)); // Slightly longer for test
            debugPrint(
                "[PeekController] ✅ Pre-write Firestore connection test successful.");
            connectionTestPassed = true;
          } catch (testError) {
            debugPrint(
                "[PeekController] ⚠️ Pre-write Firestore connection test failed: $testError. This indicates Firestore connection is unstable for the direct write fallback.");
            // If this test fails, it's a strong sign the main write will also fail.
          }

          if (recipientUid != null) {
            final peekRequestId =
                _firestore.collection('peek_requests').doc().id;
            debugPrint(
                "[PeekController] Creating peek request document with ID for direct write: $peekRequestId");
            final peekRequestData = {
              'senderUid': fromUserId,
              'receiverUid': recipientUid,
              'status': 'pending_acceptance',
              'createdAt': FieldValue.serverTimestamp(),
              'expiresAt': Timestamp.fromDate(
                  DateTime.now().add(const Duration(hours: 1))),
            };
            debugPrint(
                "[PeekController] Peek request data prepared for direct write: $peekRequestData");

            // This is the critical write operation that was hanging.
            // Using your existing inner try-catch structure.
            debugPrint(
                "[PeekController] Attempting to WRITE peekRequest to Firestore (direct fallback): /peek_requests/$peekRequestId");
            try {
              await _firestore
                  .collection('peek_requests')
                  .doc(peekRequestId)
                  .set(peekRequestData)
                  .timeout(const Duration(seconds: 20));

              debugPrint(
                  "[PeekController] ✅ Successfully WROTE peek request directly to Firestore (emulator bypass): $peekRequestId");

              // Verification step (from your code)
              debugPrint(
                  "[PeekController] Verifying peek request creation after direct write: $peekRequestId...");
              try {
                final verifyDoc = await _firestore
                    .collection('peek_requests')
                    .doc(peekRequestId)
                    .get()
                    .timeout(const Duration(seconds: 10), onTimeout: () {
                  debugPrint(
                      "[PeekController] ⏰ Timeout during peek request verification after direct write.");
                  throw TimeoutException(
                      'Peek request verification timed out after direct write.');
                });

                if (verifyDoc.exists) {
                  debugPrint(
                      "[PeekController] ✅ Verified peek request EXISTS in Firestore after direct write. Data: ${verifyDoc.data()}");
                } else {
                  debugPrint(
                      "[PeekController] ❌ Failed to verify peek request creation (direct write) - doc does not exist after set.");
                  throw Exception(
                      "Direct write: Peek request set but not found during verification.");
                }
              } catch (verifyError) {
                debugPrint(
                    "[PeekController] ❌ Error verifying peek request after direct write: $verifyError");
                // Decide if this should be a fatal error for the direct write path
              }

              // Update user stats (your existing logic, ensure robust with timeouts)
              final userDocRef = _firestore.collection('users').doc(fromUserId);
              Map<String, dynamic> statsUpdate = {
                'lastPeekRequestTimestamp': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              };
              final userSnapshot =
                  await userDocRef.get().timeout(const Duration(seconds: 5));
              final bool isUserPremium = userSnapshot.exists &&
                  (userSnapshot.data()?['isPremium'] as bool? ?? false);
              if (!isUserPremium) {
                statsUpdate['dailyPeekCount'] = FieldValue.increment(1);
                if (needsDailyReset) {
                  statsUpdate['peekCountLastReset'] =
                      FieldValue.serverTimestamp();
                }
              }
              await userDocRef
                  .update(statsUpdate)
                  .timeout(const Duration(seconds: 10));
              debugPrint(
                  "[PeekController] ✅ Updated user stats after successful direct Firestore write.");

              state = state.copyWith(isLoading: false, error: null);
              await _analytics.logEvent(
                name: 'peek_request_created_emulator_direct_write',
                parameters: {
                  'request_id_partial': peekRequestId.length > 8
                      ? peekRequestId.substring(0, 8)
                      : peekRequestId
                },
              );
              directWriteSucceeded = true;
              return peekRequestId;
            } catch (writeError, writeStackTrace) {
              debugPrint(
                  "[PeekController] ❌ Error during Firestore SET operation for peek_requests (direct write): $writeError");
              debugPrint(
                  "[PeekController] ❌ SET operation stack trace (direct write): $writeStackTrace");
              throw writeError; // Re-throw to be caught by the outer catch of this direct write block
            }
          } else {
            // recipientUid was null
            debugPrint(
                "[PeekController] ❌ No valid recipient (even after dummy attempt), cannot perform direct Firestore write. Will attempt Cloud Function.");
          }
        } on TimeoutException catch (e, stackTrace) {
          debugPrint(
              "[PeekController] ❌ Direct Firestore write fallback path TIMED OUT (outer timeout): $e");
          debugPrint(
              "[PeekController] ❌ Stack trace for path timeout: $stackTrace");
          // If timeout here, means some Firestore op (get/set user or recipient) hung.
          // We will fall through to Cloud Function attempt. isLoading managed by finally.
        } catch (e, stackTrace) {
          // Outer catch for the entire "direct Firestore write fallback" block
          debugPrint(
              "[PeekController] ❌ Direct Firestore write fallback path FAILED (outer catch for non-timeout): $e");
          debugPrint(
              "[PeekController] ❌ Stack trace for outer catch: $stackTrace");
          // Fall through to attempt Cloud Function call. isLoading managed by finally.
        }

        if (!directWriteSucceeded) {
          debugPrint(
              "[PeekController] Direct Firestore write did not complete successfully. Proceeding to attempt Cloud Function call.");
        } else {
          // This path should have returned peekRequestId. If directWriteSucceeded is true and we are here,
          // it implies a logic flaw or an unhandled return from the success path.
          // The 'finally' block will handle isLoading.
          return null;
        }
      }

      debugPrint(
          "[PeekController] Calling 'initiatePeekRequest' Cloud Function for user: $fromUserId (Token: ${idTokenValue != null ? "Present" : "Absent - Emulator Mode"})");

      final HttpsCallable callable = _functions.httpsCallable(
        'initiatePeekRequest',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      final HttpsCallableResult result =
          await callable.call<Map<String, dynamic>>({
        'senderUid': fromUserId,
        if (kDebugMode && idTokenValue == null) 'emulatorMode': true,
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
        await _analytics.logEvent(
          name: 'peek_request_created',
          parameters: {
            'request_id_partial': peekRequestId.length > 8
                ? peekRequestId.substring(0, 8)
                : peekRequestId,
            'is_premium': isUserPremium ? 'true' : 'false',
            'needs_reset': needsDailyReset ? 'true' : 'false',
          },
        );
        return peekRequestId;
      } else {
        final String errorMessage = responseData['message'] as String? ??
            "Failed to initiate Peek via Cloud Function.";
        debugPrint(
            "[PeekController] Cloud Function returned error or no peekRequestId. Message: $errorMessage");
        state = state.copyWith(isLoading: false, error: errorMessage);
        await _analytics.logEvent(
          name: 'peek_request_failed',
          parameters: {
            'reason': 'cloud_function_error',
            'error_message': errorMessage.length > 100
                ? errorMessage.substring(0, 100)
                : errorMessage,
          },
        );
        return null;
      }
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint(
          "❌ [PeekController] FirebaseFunctionsException calling initiatePeekRequest:\n"
          "  Code: ${e.code}\n"
          "  Message: ${e.message}\n"
          "  Details: ${e.details}\n"
          "  Stack: $st");

      // Provide user-friendly error messages based on error codes
      String userFriendlyError;
      switch (e.code) {
        case 'unavailable':
          userFriendlyError =
              "Service temporarily unavailable. Please try again.";
          break;
        case 'deadline-exceeded':
          userFriendlyError = "Request timed out. Please try again.";
          break;
        case 'permission-denied':
          userFriendlyError = "Permission denied. Please sign in again.";
          break;
        case 'resource-exhausted':
          userFriendlyError = "Too many requests. Please try again later.";
          break;
        default:
          userFriendlyError = "Peek request failed. Please try again.";
      }

      state = state.copyWith(isLoading: false, error: userFriendlyError);
      await _analytics.logEvent(
        name: 'peek_request_functions_exception',
        parameters: {
          'error_code': e.code,
          'error_message': e.message != null && e.message!.length > 100
              ? e.message!.substring(0, 100)
              : e.message ?? 'unknown',
        },
      );
      return null;
    } catch (e, st) {
      debugPrint("Error in createPeekRequestAndUpdateStats: $e\nStack: $st");
      state = state.copyWith(
          isLoading: false,
          error: "An unexpected error occurred. Please try again.");
      await _analytics.logEvent(
        name: 'peek_request_unexpected_error',
        parameters: {
          'error_type': e.runtimeType.toString(),
          'error_message': e.toString().length > 100
              ? e.toString().substring(0, 100)
              : e.toString(),
        },
      );
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
      _ref.invalidate(userDataProvider);
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
      // Instead of deleting, we update the status. This is a more explicit signal
      // that other listeners (like the receiver's dialog handler) can react to.
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

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
