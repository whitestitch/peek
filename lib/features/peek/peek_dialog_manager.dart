import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/providers/session_providers.dart';
import 'package:peek/core/router.dart';
import 'dart:async';

/// Manages peek request dialog display and user interactions
class PeekDialogManager {
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetRef ref;
  Timer? _expirationTimer;
  String? _currentRequestId;
  bool _isInitialized = false; // Track initialization status

  // 🔒 NEW: Track active dialog context for proper cleanup
  BuildContext? _activeDialogContext;

  PeekDialogManager({
    required this.navigatorKey,
    required this.ref,
  });

  /// Initialize the dialog manager
  void initialize() {
    _isInitialized = true;
    debugPrint('🎭 [PeekDialogManager] Initialized and ready to show dialogs');
  }

  /// 🔒 NEW: Dismiss active dialog if any
  void dismissActiveDialog() {
    if (_activeDialogContext != null && _activeDialogContext!.mounted) {
      debugPrint(
          '🎭 [PeekDialogManager] Dismissing active dialog due to navigation');
      Navigator.of(_activeDialogContext!, rootNavigator: true).pop();
      _activeDialogContext = null;
    }

    // Clear provider and cancel timer
    ref.read(activePeekRequestDialogProvider.notifier).state = null;
    _expirationTimer?.cancel();
    _currentRequestId = null;
  }

  /// Show peek request dialog
  Future<void> showPeekRequestDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> requestDoc) async {
    debugPrint('🎭 [PeekDialogManager] showPeekRequestDialog ENTRY');

    // Only process requests after initialization
    if (!_isInitialized) {
      debugPrint('⚠️ [PeekDialogManager] Not yet initialized, skipping dialog');
      return;
    }

    // 🔒 NEW: Check if user is in an active session
    // 🔒 ENHANCED: Force refresh session state before checking
    final sessionManager = ref.read(sessionManagerProvider);
    if (sessionManager.isInSession) {
      // 🔒 NEW: Double-check by verifying peek request status
      await sessionManager.checkPeekRequestStatus();

      // Re-check after potential cleanup
      if (sessionManager.isInSession) {
        debugPrint(
            '🔒 [PeekDialogManager] User is in active session, blocking new peek request');
        return;
      } else {
        debugPrint(
            '🔒 [PeekDialogManager] Session was stale, now cleaned up - allowing peek request');
      }
    }

    final requestId = requestDoc.id;
    debugPrint('🎭 [PeekDialogManager] Request ID: $requestId');

    debugPrint(
        '🎭 [PeekDialogManager] Attempting to show dialog for request: $requestId');

    // Cancel any existing timer
    debugPrint('🎭 [PeekDialogManager] Cancelling existing timer');
    _expirationTimer?.cancel();
    _currentRequestId = requestId;

    // Set active dialog provider
    debugPrint('🎭 [PeekDialogManager] Setting active dialog provider');
    ref.read(activePeekRequestDialogProvider.notifier).state = requestId;

    // Start expiration timer (60 seconds to match sender's countdown)
    debugPrint('🎭 [PeekDialogManager] Starting expiration timer');
    _startExpirationTimer(requestId);

    // Try to get context, with retry if needed
    debugPrint('🎭 [PeekDialogManager] Getting navigator context');
    final context = navigatorKey.currentContext;
    debugPrint('🎭 [PeekDialogManager] Context is null: ${context == null}');

    if (context == null) {
      debugPrint(
          '❌ [PeekDialogManager] Navigator context is null, will retry in 100ms');

      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        debugPrint('🎭 [PeekDialogManager] Retry attempt after 100ms delay');
        if (_currentRequestId == requestId) {
          final retryContext = navigatorKey.currentContext;
          debugPrint(
              '🎭 [PeekDialogManager] Retry context is null: ${retryContext == null}');
          if (retryContext != null && retryContext.mounted) {
            debugPrint(
                '✅ [PeekDialogManager] Retry successful, showing dialog');
            _showDialogWithContext(retryContext, requestId);
          } else {
            debugPrint(
                '❌ [PeekDialogManager] Retry failed, context still null or not mounted');
          }
        } else {
          debugPrint(
              '🎭 [PeekDialogManager] Request ID changed during retry, aborting');
        }
      });
      debugPrint('🎭 [PeekDialogManager] Returning from null context path');
      return;
    }

    debugPrint(
        '✅ [PeekDialogManager] Navigator context found, showing dialog directly');
    _showDialogWithContext(context, requestId);
    debugPrint('🎭 [PeekDialogManager] showPeekRequestDialog EXIT');
  }

  /// Show dialog with valid context
  void _showDialogWithContext(BuildContext context, String requestId) {
    debugPrint(
        '🎭 [PeekDialogManager] _showDialogWithContext called for: $requestId');
    debugPrint('🎭 [PeekDialogManager] Context mounted: ${context.mounted}');
    debugPrint('🎭 [PeekDialogManager] About to call showDialog');

    // 🔒 FIX: Store dialog context for proper cleanup
    _activeDialogContext = context;

    // 🔒 FIX: Use post-frame callback to ensure context is stable
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentRequestId == requestId && context.mounted) {
        // Show dialog immediately - no post-frame callback complexity
        // ignore: use_build_context_synchronously
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          useSafeArea: true,
          useRootNavigator: true,
          builder: (BuildContext dialogContext) {
            debugPrint('🎭 [PeekDialogManager] Dialog builder called');
            return AlertDialog(
              title: const Text(
                'New Peek Request!',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: peekWhiteColor,
                  letterSpacing: 0.5,
                  fontSize: 26,
                ),
              ),
              content: Text(
                'Someone wants to share a peek with you. Accept?',
                style: TextStyle(
                  color: peekWhiteColor.withValues(alpha: 1),
                  height: 1.55,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
              actionsAlignment: MainAxisAlignment.spaceBetween,
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        peekOnBackgroundColor.withValues(alpha: 0.7),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    debugPrint('🎭 [PeekDialogManager] Decline button pressed');
                    Navigator.of(dialogContext).pop();
                    _declinePeekRequest(requestId);
                  },
                  child: const Text('Decline'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    debugPrint('🎭 [PeekDialogManager] Accept button pressed');
                    Navigator.of(dialogContext).pop();
                    _acceptPeekRequest(requestId);
                  },
                  child: const Text('Accept'),
                ),
              ],
            );
          },
        ).then((_) {
          debugPrint('🎭 [PeekDialogManager] Dialog closed');

          // 🔒 FIX: Clear stored dialog context
          _activeDialogContext = null;

          // Clear provider when dialog closes
          final activeDialogId = ref.read(activePeekRequestDialogProvider);
          if (activeDialogId == requestId) {
            ref.read(activePeekRequestDialogProvider.notifier).state = null;
          }

          // Cancel expiration timer when dialog is manually closed
          if (_currentRequestId == requestId) {
            _expirationTimer?.cancel();
            _currentRequestId = null;
          }
        });
      }
    });

    debugPrint('✅ [PeekDialogManager] Dialog display initiated');
  }

  /// Accept peek request
  Future<void> _acceptPeekRequest(String requestId) async {
    try {
      // 🔒 NEW: Start session when accepting peek request
      final sessionManager = ref.read(sessionManagerProvider);
      await sessionManager.startSession(requestId, 'waiting_response');

      // Update session state providers
      ref.read(sessionStateProvider.notifier).state =
          sessionManager.currentState;
      ref.read(sessionRequestIdProvider.notifier).state =
          sessionManager.currentRequestId;
      ref.read(isInSessionProvider.notifier).state = sessionManager.isInSession;
      ref.read(canReceivePeeksProvider.notifier).state =
          sessionManager.canReceivePeekRequests();

      debugPrint(
          '🔒 [PeekDialogManager] Session started for accepted request: $requestId');

      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      ref
          .read(routerProvider)
          .go('/capture?requestId=$requestId&mode=response');
    } catch (e) {
      debugPrint('❌ Error in _acceptPeekRequest: $e');
      _showErrorSnackBar('Failed to accept peek: ${e.toString()}');
    }
  }

  /// Decline peek request
  Future<void> _declinePeekRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error declining peek request: $e');
      _showErrorSnackBar('Failed to decline peek: ${e.toString()}');
    }
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: peekErrorColor,
        ),
      );
    }
  }

  /// Handle dialog visibility based on pending requests
  Future<void> handlePendingRequests(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> requests) async {
    final requestIds = requests.map((req) => req.id).toSet();
    final activeDialogId = ref.read(activePeekRequestDialogProvider);

    // Close dialog if request is no longer pending
    if (activeDialogId != null && !requestIds.contains(activeDialogId)) {
      _handleRequestStatusChange(activeDialogId);
      return;
    }

    // Prevent showing on initial load with existing items: only react when list grows
    final previous = ref.read(lastPendingRequestIdsProvider);
    if (previous == null) {
      // Cache current set, do not show dialog on initial app start
      ref.read(lastPendingRequestIdsProvider.notifier).state = requestIds;
      return;
    }

    // Compute newly added requests
    final newlyAdded = requestIds.difference(previous);
    if (newlyAdded.isEmpty) {
      // Update cache and return
      ref.read(lastPendingRequestIdsProvider.notifier).state = requestIds;
      return;
    }

    // Show dialog for the first newly added request if no dialog is active
    if (ref.read(activePeekRequestDialogProvider) == null) {
      final firstNewId = newlyAdded.first;
      final firstDoc = requests.firstWhere((r) => r.id == firstNewId);
      await showPeekRequestDialog(firstDoc);
    }

    // Update cache after handling
    ref.read(lastPendingRequestIdsProvider.notifier).state = requestIds;
  }

  /// Handle request status change (cancelled, expired, etc.)
  Future<void> _handleRequestStatusChange(String requestId) async {
    try {
      // Close active dialog
      if (navigatorKey.currentContext != null &&
          Navigator.of(navigatorKey.currentContext!).canPop()) {
        Navigator.of(navigatorKey.currentContext!).pop();
      }
      ref.read(activePeekRequestDialogProvider.notifier).state = null;

      // Cancel expiration timer if this was the current request
      if (_currentRequestId == requestId) {
        _expirationTimer?.cancel();
        _currentRequestId = null;
      }

      // Note: Cancellation panels are now handled by navigation parameters
      // No need to trigger additional navigation here
    } catch (e) {
      debugPrint('❌ Error handling request status change: $e');
    }
  }

  /// Start expiration timer for the dialog
  void _startExpirationTimer(String requestId) {
    try {
      debugPrint(
          '⏰ [PeekDialogManager] _startExpirationTimer ENTRY for: $requestId');

      _expirationTimer?.cancel();

      debugPrint(
          '⏰ [PeekDialogManager] Starting backup expiration timer for request: $requestId');

      // Note: Shared timer listener removed due to ref.listen constraints
      // Backup timer will handle expiration reliably
      // Keep backup timer as safety net (60 seconds - exactly matching peek request timer)
      _expirationTimer = Timer(const Duration(seconds: 60), () {
        debugPrint(
            '⏰ [PeekDialogManager] Backup timer fired for request: $requestId');
        if (_currentRequestId == requestId &&
            ref.read(activePeekRequestDialogProvider) == requestId) {
          debugPrint('🚨 [PeekDialogManager] Backup timer handling expiration');
          _handleDialogExpiration(requestId);
        }
      });

      debugPrint('⏰ [PeekDialogManager] Backup timer set successfully');
      debugPrint(
          '⏰ [PeekDialogManager] _startExpirationTimer EXIT for: $requestId');
    } catch (e) {
      debugPrint('❌ [PeekDialogManager] Error in _startExpirationTimer: $e');
      debugPrint('❌ [PeekDialogManager] Stack trace: ${StackTrace.current}');
    }
  }

  /// Handle dialog expiration - auto-dismiss and show "Time Up!" slide panel
  void _handleDialogExpiration(String requestId) {
    debugPrint(
        '🚨 [PeekDialogManager] _handleDialogExpiration called for request: $requestId');

    // Prevent multiple expiration handlers from running simultaneously
    if (_currentRequestId != requestId) {
      debugPrint(
          '⚠️ [PeekDialogManager] Expiration already handled for request: $requestId');
      return;
    }

    // Check if dialog is still active before proceeding
    final activeDialogId = ref.read(activePeekRequestDialogProvider);
    if (activeDialogId != requestId) {
      debugPrint(
          '⚠️ [PeekDialogManager] Dialog no longer active for request: $requestId');
      return;
    }

    // Clear the active dialog provider first to prevent conflicts
    debugPrint(
        '🧹 [PeekDialogManager] Clearing activePeekRequestDialogProvider');
    ref.read(activePeekRequestDialogProvider.notifier).state = null;

    // Close the dialog if it's still open - use a more robust approach
    if (navigatorKey.currentContext != null) {
      try {
        // Check if we can pop and if there's actually a dialog to close
        if (Navigator.of(navigatorKey.currentContext!).canPop()) {
          debugPrint(
              '✅ [PeekDialogManager] Closing dialog via Navigator.pop()');
          Navigator.of(navigatorKey.currentContext!).pop();
        } else {
          debugPrint(
              '⚠️ [PeekDialogManager] Cannot pop - no dialog in navigation stack');
        }
      } catch (e) {
        debugPrint('❌ [PeekDialogManager] Error closing dialog: $e');
      }
    } else {
      debugPrint('⚠️ [PeekDialogManager] Navigator context is null');
    }

    // Add a small delay to ensure dialog is fully closed before showing panel
    Future.delayed(const Duration(milliseconds: 100), () {
      // Show "Time Up!" slide panel instead of navigating to timeout page
      debugPrint('🎭 [PeekDialogManager] Showing Time Up slide panel');
      _showTimeUpSlidePanel();
    });

    // Clean up timer state
    debugPrint('🧹 [PeekDialogManager] Cleaning up timer state');
    _expirationTimer?.cancel();
    _currentRequestId = null;
  }

  /// Show "Time Up!" slide panel
  void _showTimeUpSlidePanel() {
    if (navigatorKey.currentContext == null) return;

    showModalBottomSheet<void>(
      context: navigatorKey.currentContext!,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Container(
          width: double.infinity,
          // Increased bottom padding
          padding: const EdgeInsets.fromLTRB(30, 40, 30, 80),
          decoration: const BoxDecoration(
            color: peekBackgroundColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off_outlined,
                  size: 60, color: Colors.white70),
              const SizedBox(height: 20),
              const Text("Time's Up!",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("The peek request has expired.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: peekSecondaryColor,
                    foregroundColor: peekSurfaceColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('OK',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Dispose resources
  void dispose() {
    debugPrint('🎭 [PeekDialogManager] Disposing dialog manager');
    _expirationTimer?.cancel();
    dismissActiveDialog();
  }
}
