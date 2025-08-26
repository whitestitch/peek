import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

/// Callback type for session state changes
typedef SessionStateCallback = void Function(
    String state, String? requestId, bool isInSession, bool canReceivePeeks);

/// Manages user session state to prevent multiple concurrent peek requests
class SessionManager {
  static const String _sessionKey = 'peek_session_state';
  static const String _sessionStartKey = 'peek_session_start';
  static const String _sessionRequestIdKey = 'peek_session_request_id';

  // Session states
  static const String _stateIdle = 'idle';
  static const String _stateWaitingResponse = 'waiting_response';
  static const String _statePhotoCapture = 'photo_capture';
  static const String _stateViewingImage = 'viewing_image';
  static const String _stateReaction = 'reaction';

  // Maximum session duration (30 minutes) to prevent stuck sessions
  static const Duration _maxSessionDuration = Duration(minutes: 30);

  // 🔒 REMOVED: Fixed 5-minute timeout - now using immediate cleanup
  // static const Duration _sessionTimeout = Duration(minutes: 5);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Current session state
  String _currentState = _stateIdle;
  String? _currentRequestId;
  DateTime? _sessionStartTime;

  // 🔒 NEW: Periodic validation timer (reduced frequency for immediate cleanup)
  Timer? _validationTimer;

  // 🔒 NEW: Callback for state changes
  SessionStateCallback? _onStateChanged;

  // Getters
  String get currentState => _currentState;
  String? get currentRequestId => _currentRequestId;
  bool get isInSession => _currentState != _stateIdle;
  bool get isWaitingResponse => _currentState == _stateWaitingResponse;
  bool get isPhotoCapture => _currentState == _statePhotoCapture;
  bool get isViewingImage => _currentState == _stateViewingImage;
  bool get isReaction => _currentState == _stateReaction;

  /// 🔒 NEW: Set callback for state changes
  void setStateChangeCallback(SessionStateCallback callback) {
    _onStateChanged = callback;
  }

  /// 🔒 NEW: Notify state change to callback
  void _notifyStateChanged() {
    if (_onStateChanged != null) {
      _onStateChanged!(_currentState, _currentRequestId, isInSession,
          canReceivePeekRequests());
    }
  }

  /// Initialize session manager and restore state from storage
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedState = prefs.getString(_sessionKey) ?? _stateIdle;
      final savedRequestId = prefs.getString(_sessionRequestIdKey);
      final savedStartTime = prefs.getInt(_sessionStartKey);

      // Restore state
      _currentState = savedState;
      _currentRequestId = savedRequestId;
      _sessionStartTime = savedStartTime != null
          ? DateTime.fromMillisecondsSinceEpoch(savedStartTime)
          : null;

      // Enhanced validation and cleanup
      await _validateAndCleanupSession();

      // 🔒 NEW: Additional check: if session is still active after validation, verify it's valid
      if (isInSession) {
        await _verifySessionIntegrity();
      }

      // 🔒 FIX: Additional safety - check for stale sessions that should be cleaned up immediately
      if (isInSession &&
          (_currentState == 'photo_capture' ||
              _currentState == 'waiting_for_response')) {
        debugPrint(
            '🔒 [SessionManager] Detected potentially stale session state: $_currentState - forcing cleanup');
        await _forceCleanupSession();
      }

      // 🔒 NEW: Start periodic validation if session is active
      _startPeriodicValidation();

      debugPrint('🔒 [SessionManager] Initialized with state: $_currentState');
    } catch (e) {
      debugPrint('❌ [SessionManager] Error initializing: $e');
      _resetSession();
    }
  }

  /// 🔒 NEW: Start periodic session validation
  void _startPeriodicValidation() {
    _validationTimer?.cancel();

    if (isInSession) {
      // 🔒 UPDATED: Check every 30 seconds for immediate cleanup (instead of 2 minutes)
      _validationTimer =
          Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!isInSession) {
          timer.cancel();
          return;
        }

        debugPrint('🔒 [SessionManager] Periodic validation check');

        // 🔒 NEW: Use immediate cleanup instead of timeout-based cleanup
        await checkPeekRequestStatus();

        // If session was cleaned up, stop the timer
        if (!isInSession) {
          timer.cancel();
        }
      });
    }
  }

  /// 🔒 NEW: Stop periodic validation
  void _stopPeriodicValidation() {
    _validationTimer?.cancel();
    _validationTimer = null;
  }

  /// Start a new peek session
  Future<void> startSession(String requestId, String state) async {
    if (isInSession) {
      debugPrint(
          '⚠️ [SessionManager] Cannot start session: already in session $_currentState');
      return;
    }

    _currentState = state;
    _currentRequestId = requestId;
    _sessionStartTime = DateTime.now();

    await _persistState();

    // 🔒 NEW: Sync session state to Firestore for Cloud Functions
    await _syncSessionToFirestore();

    // 🔒 NEW: Start periodic validation for new session
    _startPeriodicValidation();

    // 🔒 NEW: Notify state change
    _notifyStateChanged();

    debugPrint(
        '🔒 [SessionManager] Session started: $state for request: $requestId');
  }

  /// Update session state
  Future<void> updateSessionState(String newState) async {
    if (!isInSession) {
      debugPrint('⚠️ [SessionManager] Cannot update state: not in session');
      return;
    }

    _currentState = newState;
    await _persistState();

    // 🔒 NEW: Sync updated session state to Firestore
    await _syncSessionToFirestore();

    // 🔒 NEW: Notify state change
    _notifyStateChanged();

    debugPrint('🔒 [SessionManager] Session state updated to: $newState');
  }

  /// End current session
  Future<void> endSession() async {
    if (!isInSession) {
      debugPrint('⚠️ [SessionManager] Cannot end session: not in session');
      return;
    }

    debugPrint('🔒 [SessionManager] Ending session: $_currentState');

    // 🔒 NEW: Stop periodic validation
    _stopPeriodicValidation();

    _resetSession();
    await _persistState();

    // 🔒 NEW: Clear session state from Firestore
    await _clearSessionFromFirestore();

    // 🔒 NEW: Notify state change
    _notifyStateChanged();
  }

  /// 🔒 NEW: Force reset session (for debugging/testing)
  Future<void> forceResetSession() async {
    debugPrint('🔒 [SessionManager] Force reset requested');

    // 🔒 NEW: Stop periodic validation
    _stopPeriodicValidation();

    _resetSession();
    await _persistState();
    await _clearSessionFromFirestore();

    // 🔒 NEW: Notify state change
    _notifyStateChanged();
  }

  /// Check if user can receive new peek requests
  bool canReceivePeekRequests() {
    // Cannot receive if in any active session state
    if (isInSession) {
      debugPrint(
          '🔒 [SessionManager] Cannot receive peeks: in session $_currentState');
      return false;
    }

    // Check if session is stuck (exceeded max duration)
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      if (sessionDuration > _maxSessionDuration) {
        debugPrint(
            '⚠️ [SessionManager] Session exceeded max duration, forcing cleanup');
        _resetSession();
        return true;
      }
    }

    return true;
  }

  /// Get current session info for debugging
  Map<String, dynamic> getSessionInfo() {
    return {
      'state': _currentState,
      'requestId': _currentRequestId,
      'sessionStartTime': _sessionStartTime?.toIso8601String(),
      'isInSession': isInSession,
      'canReceivePeeks': canReceivePeekRequests(),
      'sessionAge': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMinutes
          : 0,
      'timeoutMinutes': _maxSessionDuration.inMinutes,
    };
  }

  /// Validate and cleanup stuck sessions
  Future<void> _validateAndCleanupSession() async {
    if (!isInSession ||
        _currentRequestId == null ||
        _sessionStartTime == null) {
      return;
    }

    try {
      // 🔒 UPDATED: Use immediate cleanup instead of timeout-based cleanup
      await checkPeekRequestStatus();

      // If session was cleaned up by checkPeekRequestStatus, exit early
      if (!isInSession) return;

      // Check if session is too old (fallback for stuck sessions)
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      if (sessionDuration > _maxSessionDuration) {
        debugPrint(
            '🔒 [SessionManager] Session exceeded max duration, auto-cleaning');
        await _forceCleanupSession();
        return;
      }
    } catch (e) {
      debugPrint('❌ [SessionManager] Error validating session: $e');
      // On error, reset session to be safe
      await _forceCleanupSession();
    }
  }

  /// 🔒 NEW: Verify session integrity on app start
  Future<void> _verifySessionIntegrity() async {
    try {
      if (_currentRequestId == null) return;

      final requestDoc = await _firestore
          .collection('peek_requests')
          .doc(_currentRequestId!)
          .get();

      if (!requestDoc.exists) {
        debugPrint(
            '🔒 [SessionManager] Session integrity check failed, cleaning up');
        _resetSession();
        await _persistState();
        await _clearSessionFromFirestore();
        return;
      }

      final requestData = requestDoc.data();
      final status = requestData?['status'] as String?;

      // If request is in a state that should have ended the session, clean up
      if (status == 'responded_with_image' ||
          status == 'completed' ||
          status == 'expired' ||
          status == 'cancelled') {
        debugPrint(
            '🔒 [SessionManager] Session integrity check: request completed, cleaning up');
        _resetSession();
        await _persistState();
        await _clearSessionFromFirestore();
      }
    } catch (e) {
      debugPrint('❌ [SessionManager] Error in session integrity check: $e');
    }
  }

  /// Reset session to idle state
  void _resetSession() {
    _currentState = _stateIdle;
    _currentRequestId = null;
    _sessionStartTime = null;

    // 🔒 NEW: Stop periodic validation
    _stopPeriodicValidation();

    // 🔒 NEW: Notify state change
    _notifyStateChanged();
  }

  /// Persist current state to storage
  Future<void> _persistState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, _currentState);
      await prefs.setString(_sessionRequestIdKey, _currentRequestId ?? '');
      await prefs.setInt(
          _sessionStartKey, _sessionStartTime?.millisecondsSinceEpoch ?? 0);
    } catch (e) {
      debugPrint('❌ [SessionManager] Error persisting state: $e');
    }
  }

  /// Clear all session data (for logout, etc.)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
      await prefs.remove(_sessionRequestIdKey);
      await prefs.remove(_sessionStartKey);

      _resetSession();
      debugPrint('🔒 [SessionManager] All session data cleared');
    } catch (e) {
      debugPrint('❌ [SessionManager] Error clearing data: $e');
    }
  }

  /// 🔒 NEW: Dispose method for cleanup
  void dispose() {
    _stopPeriodicValidation();
    debugPrint('🔒 [SessionManager] Disposed');
  }

  /// Sync session state to Firestore for Cloud Functions
  Future<void> _syncSessionToFirestore() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'activePeekSession': {
          'isActive': true,
          'requestId': _currentRequestId,
          'state': _currentState,
          'startTime': _sessionStartTime != null
              ? Timestamp.fromDate(_sessionStartTime!)
              : FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      });

      debugPrint('🔒 [SessionManager] Session state synced to Firestore');
    } catch (e) {
      debugPrint('❌ [SessionManager] Error syncing session to Firestore: $e');
    }
  }

  /// Clear session state from Firestore
  Future<void> _clearSessionFromFirestore() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      await _firestore.collection('users').doc(currentUser.uid).update({
        'activePeekSession': null,
      });

      debugPrint('🔒 [SessionManager] Session state cleared from Firestore');
    } catch (e) {
      debugPrint(
          '❌ [SessionManager] Error clearing session from Firestore: $e');
    }
  }

  /// 🔒 NEW: Check if peek request has completed and clean up session immediately
  Future<void> checkPeekRequestStatus() async {
    if (!isInSession || _currentRequestId == null) return;

    try {
      final requestDoc = await _firestore
          .collection('peek_requests')
          .doc(_currentRequestId!)
          .get();

      if (!requestDoc.exists) {
        debugPrint(
            '🔒 [SessionManager] Request document not found, cleaning up session');
        await _forceCleanupSession();
        return;
      }

      final requestData = requestDoc.data();
      final status = requestData?['status'] as String?;

      // 🔒 NEW: Immediate cleanup on natural flow completion
      if (status == 'responded_with_image' ||
          status == 'completed' ||
          status == 'expired' ||
          status == 'cancelled' ||
          status == 'timeout' ||
          status == 'cancelled_by_sender' ||
          status ==
              'cancelled_by_receiver' || // 🔒 FIX: Missing cancellation status
          status == 'declined') {
        debugPrint(
            '🔒 [SessionManager] Peek flow completed (status: $status), cleaning up session immediately');
        await _forceCleanupSession();
        return;
      }
    } catch (e) {
      debugPrint('❌ [SessionManager] Error checking peek status: $e');
    }
  }

  /// 🔒 NEW: Force cleanup session (for immediate reset)
  Future<void> _forceCleanupSession() async {
    debugPrint('🔒 [SessionManager] Force cleaning up session');

    // Stop periodic validation
    _stopPeriodicValidation();

    // Reset session state
    _resetSession();

    // Persist and clear from Firestore
    await _persistState();
    await _clearSessionFromFirestore();

    // Notify state change
    _notifyStateChanged();
  }

  /// 🔒 NEW: Force clear Firestore session state (for stuck sessions)
  Future<void> forceClearFirestoreSession() async {
    debugPrint('🔒 [SessionManager] Force clearing Firestore session state');

    try {
      await _clearSessionFromFirestore();
      debugPrint(
          '🔒 [SessionManager] Firestore session state cleared successfully');
    } catch (e) {
      debugPrint('❌ [SessionManager] Error clearing Firestore session: $e');
    }
  }
}
