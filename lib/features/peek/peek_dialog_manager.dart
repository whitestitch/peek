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

  // 🔒 ENHANCED: Use OverlayEntry for navigation-independent dialogs
  OverlayEntry? _activeDialogOverlay;
  bool _isDialogShowing = false;

  PeekDialogManager({
    required this.navigatorKey,
    required this.ref,
  });

  /// Initialize the dialog manager
  void initialize() {
    _isInitialized = true;
  }

  /// 🔒 ENHANCED: Dismiss active dialog overlay
  void dismissActiveDialog() {
    if (_activeDialogOverlay != null && _isDialogShowing) {
      try {
        _activeDialogOverlay!.remove();
      } catch (e) {
        debugPrint('⚠️ [PeekDialogManager] Error removing overlay: $e');
      }
      _activeDialogOverlay = null;
      _isDialogShowing = false;
    }

    // Clear provider and cancel timer
    ref.read(activePeekRequestDialogProvider.notifier).state = null;
    _expirationTimer?.cancel();
    _currentRequestId = null;
  }

  /// Show peek request dialog
  Future<void> showPeekRequestDialog(
      QueryDocumentSnapshot<Map<String, dynamic>> requestDoc) async {
    // Only process requests after initialization
    if (!_isInitialized) {
      debugPrint('⚠️ [PeekDialogManager] Not yet initialized, skipping dialog');
      return;
    }

    // 🔒 ENHANCED: Strict session exclusivity check
    final sessionManager = ref.read(sessionManagerProvider);
    final canReceivePeeks = ref.read(canReceivePeeksProvider);

    // Double-check session state with both SessionManager and provider
    if (sessionManager.isInSession || !canReceivePeeks) {
      debugPrint(
          '🔒 [PeekDialogManager] User is in active session (manager: ${sessionManager.isInSession}, canReceive: $canReceivePeeks), blocking new peek request');

      // Force refresh session state to clean up any stale sessions
      await sessionManager.checkPeekRequestStatus();

      // Re-check after cleanup - if still in session, block the request
      if (sessionManager.isInSession || !ref.read(canReceivePeeksProvider)) {
        debugPrint(
            '🔒 [PeekDialogManager] Session check confirmed - blocking peek request');
        return;
      } else {
        debugPrint(
            '🔒 [PeekDialogManager] Session was stale, now cleaned up - allowing peek request');
      }
    }

    // 🔒 ENHANCED: Check if dialog is already showing
    if (_isDialogShowing || _activeDialogOverlay != null) {
      debugPrint(
          '🔒 [PeekDialogManager] Dialog already showing, blocking duplicate request');
      return;
    }

    final requestId = requestDoc.id;

    debugPrint(
        '🎭 [PeekDialogManager] Attempting to show dialog for request: $requestId');

    // Cancel any existing timer

    _expirationTimer?.cancel();
    _currentRequestId = requestId;

    // Set active dialog provider

    ref.read(activePeekRequestDialogProvider.notifier).state = requestId;

    // Start expiration timer (60 seconds to match sender's countdown)

    _startExpirationTimer(requestId);

    // 🔒 ENHANCED: Use OverlayEntry for navigation-independent dialog
    debugPrint(
        '🎭 [PeekDialogManager] Creating navigation-independent dialog overlay');
    _showDialogOverlay(requestId);
  }

  /// 🔒 ENHANCED: Show dialog as navigation-independent overlay
  void _showDialogOverlay(String requestId) {
    debugPrint(
        '🎭 [PeekDialogManager] _showDialogOverlay called for: $requestId');

    // Get the overlay state from the navigator
    final NavigatorState? navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      debugPrint(
          '❌ [PeekDialogManager] Navigator state is null, cannot show overlay');
      return;
    }

    final OverlayState overlayState = navigatorState.overlay!;

    // Create the overlay entry
    _activeDialogOverlay = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return _buildDialogContent(requestId);
      },
    );

    // Insert the overlay
    overlayState.insert(_activeDialogOverlay!);
    _isDialogShowing = true;

    debugPrint('✅ [PeekDialogManager] Dialog overlay displayed successfully');
  }

  /// Build the dialog content widget - fixed z-index and context issues
  Widget _buildDialogContent(String requestId) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black54, // Barrier color
        child: Center(
          child: Container(
            // ✅ FIX: Match Reactions dialog width and styling
            margin: const EdgeInsets.fromLTRB(24, 40, 24, 80),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 600),
              tween: Tween<double>(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                // 🔒 FIX: Clamp opacity value to prevent assertion errors
                final clampedValue = value.clamp(0.0, 1.0);

                return Transform.scale(
                  scale: 0.8 + (0.2 * clampedValue),
                  child: Opacity(
                    opacity: clampedValue,
                    child: Container(
                      padding: const EdgeInsets.all(30),
                      decoration: BoxDecoration(
                        // ✅ MATCH: Beautiful gradient background matching Reaction dialog style
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            peekBackgroundColor,
                            peekBackgroundColor.withValues(alpha: 0.95),
                            peekSurfaceColor.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        // ✅ MATCH: Subtle shadow for depth
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ MATCH: Animated title with slide-in effect
                          Transform.translate(
                            offset: Offset(0, 15 * (1 - clampedValue)),
                            child: const Text(
                              'New Peek Request!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 24,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ✅ MATCH: Animated content with slide-in effect
                          Transform.translate(
                            offset: Offset(0, 10 * (1 - clampedValue)),
                            child: Text(
                              'Someone wants to share a peek with you. Accept?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.90),
                                fontSize: 16,
                                height: 1.4,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // ✅ MATCH: Animated buttons with slide-in effect
                          Transform.translate(
                            offset: Offset(0, 25 * (1 - clampedValue)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // ✅ KEEP: Decline button (left, no bg)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        Colors.white.withValues(alpha: 0.8),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  onPressed: () {
                                    _closeDialogOverlay();
                                    _declinePeekRequest(requestId);
                                  },
                                  child: const Text('Decline'),
                                ),
                                // ✅ KEEP: Accept button (right, with bg)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: peekPrimaryColor,
                                    foregroundColor: peekSurfaceColor,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  onPressed: () {
                                    _closeDialogOverlay();
                                    _acceptPeekRequest(requestId);
                                  },
                                  child: const Text('Accept'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Close the dialog overlay
  void _closeDialogOverlay() {
    if (_activeDialogOverlay != null && _isDialogShowing) {
      try {
        _activeDialogOverlay!.remove();
      } catch (e) {
        debugPrint('⚠️ [PeekDialogManager] Error removing overlay: $e');
      }
      _activeDialogOverlay = null;
      _isDialogShowing = false;

      // Clear provider when dialog closes
      final activeDialogId = ref.read(activePeekRequestDialogProvider);
      if (activeDialogId == _currentRequestId) {
        ref.read(activePeekRequestDialogProvider.notifier).state = null;
      }

      // Cancel expiration timer when dialog is manually closed
      if (_currentRequestId != null) {
        _expirationTimer?.cancel();
        _currentRequestId = null;
      }
    }
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
      // 🔒 ENHANCED: Check the actual status to determine what happened
      DocumentSnapshot? requestDoc;
      try {
        requestDoc = await FirebaseFirestore.instance
            .collection('peek_requests')
            .doc(requestId)
            .get();
      } catch (e) {
        debugPrint('🎭 [PeekDialogManager] Error fetching request status: $e');
      }

      final status = requestDoc?.data() is Map<String, dynamic>
          ? (requestDoc!.data() as Map<String, dynamic>)['status'] as String?
          : null;

      debugPrint(
          '🎭 [PeekDialogManager] Request $requestId status changed to: $status');

      // Close active dialog overlay
      if (_isDialogShowing && _activeDialogOverlay != null) {
        debugPrint(
            '🎭 [PeekDialogManager] Closing dialog due to status change');
        _closeDialogOverlay();
      }

      ref.read(activePeekRequestDialogProvider.notifier).state = null;

      // Cancel expiration timer if this was the current request
      if (_currentRequestId == requestId) {
        _expirationTimer?.cancel();
        _currentRequestId = null;
      }

      // 🔒 ENHANCED: Show appropriate panel based on status
      if (status == 'cancelled_by_sender') {
        debugPrint(
            '🔒 [PeekDialogManager] Request was cancelled by sender, showing cancellation panel');
        _showCancellationPanel();
      } else if (status == 'expired' ||
          status == 'timeout' ||
          status == 'timed_out') {
        debugPrint(
            '🔒 [PeekDialogManager] Request expired/timed out (status: $status), showing timeout panel');
        _showTimeUpSlidePanel();
      } else {
        debugPrint(
            '🔒 [PeekDialogManager] Request status changed to: $status (no panel needed)');
      }
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
          '⏰ [PeekDialogManager] Starting 5s expiration timer for request: $requestId');

      // 🎯 SYNC FIX: Use 5 seconds for receiver (testing phase - will be 60s later)
      _expirationTimer = Timer(const Duration(seconds: 60), () {
        debugPrint(
            '⏰ [PeekDialogManager] 5s timer fired for request: $requestId');
        if (_currentRequestId == requestId &&
            ref.read(activePeekRequestDialogProvider) == requestId) {
          _handleDialogExpiration(requestId);
        }
      });

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

    // 🔒 ENHANCED: Close the dialog overlay if it's still open
    if (_isDialogShowing && _activeDialogOverlay != null) {
      _closeDialogOverlay();
    } else {}

    // Add a small delay to ensure dialog is fully closed before showing panel
    Future.delayed(const Duration(milliseconds: 100), () {
      // Show "Time Up!" slide panel instead of navigating to timeout page

      _showTimeUpSlidePanel();
    });

    // Clean up timer state

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

  /// 🔒 ENHANCED: Show "Peekio Stopped" cancellation panel
  void _showCancellationPanel() {
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
              const Icon(Icons.cancel_outlined,
                  size: 60, color: Colors.white70),
              const SizedBox(height: 20),
              const Text("Peekio Stopped",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("The sender stopped the Peekio request.",
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
    _expirationTimer?.cancel();
    dismissActiveDialog();
  }
}
