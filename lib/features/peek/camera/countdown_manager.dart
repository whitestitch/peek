import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages countdown timer for photo capture
class CountdownManager {
  Timer? _countdownTimer;
  int? _secondsRemaining;
  bool _countdownHasBeenTriggered = false;
  bool _isTimeoutHandled = false;

  // Callbacks
  final ValueChanged<int>? onCountdownUpdate;
  final VoidCallback? onCountdownComplete;
  final VoidCallback? onTimeout;

  CountdownManager({
    this.onCountdownUpdate,
    this.onCountdownComplete,
    this.onTimeout,
  });

  // Getters
  int? get secondsRemaining => _secondsRemaining;
  bool get countdownHasBeenTriggered => _countdownHasBeenTriggered;
  bool get isTimeoutHandled => _isTimeoutHandled;

  /// Listen for capture deadline from Firestore
  void listenForCaptureDeadline(String requestId) {
    FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(requestId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      // Check for capture deadline
      final captureExpiresAt = data['captureExpiresAt'] as Timestamp?;
      if (captureExpiresAt != null && !_countdownHasBeenTriggered) {
        _countdownHasBeenTriggered = true;
        _startCountdown(captureExpiresAt.toDate());
      }
    });
  }

  /// Start countdown manually (when camera is ready)
  void startManualCountdown({int durationSeconds = 30}) {
    if (_countdownHasBeenTriggered) return;

    _countdownHasBeenTriggered = true;
    final deadline = DateTime.now().add(Duration(seconds: durationSeconds));
    _startCountdown(deadline);
    debugPrint(
        "[CountdownManager] Manual countdown started: ${durationSeconds}s");
  }

  /// Start countdown timer
  void _startCountdown(DateTime deadline) {
    if (_countdownTimer?.isActive ?? false) return;

    // Set initial countdown value
    final now = DateTime.now();
    final initialRemaining = deadline.difference(now).inSeconds;
    _secondsRemaining = initialRemaining > 0 ? initialRemaining : 0;
    onCountdownUpdate?.call(_secondsRemaining!);

    debugPrint(
        "[CountdownManager] Starting countdown with deadline: $deadline");
    debugPrint(
        "[CountdownManager] Initial remaining seconds: ${_secondsRemaining}s");

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = deadline.difference(now).inSeconds;

      if (remaining <= 0) {
        timer.cancel();
        debugPrint("[CountdownManager] Countdown finished, calling timeout");
        _handleTimeout();
      } else {
        _secondsRemaining = remaining;
        onCountdownUpdate?.call(_secondsRemaining!);
      }
    });

    debugPrint("[CountdownManager] Countdown started: ${_secondsRemaining}s");
  }

  /// Handle timeout
  void _handleTimeout() {
    if (_isTimeoutHandled) return;

    _isTimeoutHandled = true;
    _secondsRemaining = 0;

    debugPrint("[CountdownManager] Countdown timeout reached");
    onTimeout?.call();
  }

  /// Trigger countdown start manually
  void triggerCountdownStart() {
    if (!_countdownHasBeenTriggered) {
      _countdownHasBeenTriggered = true;
      onCountdownComplete?.call();
      debugPrint("[CountdownManager] Countdown manually triggered");
    }
  }

  /// Cancel countdown
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    debugPrint("[CountdownManager] Countdown cancelled");
  }

  /// Reset countdown state
  void reset() {
    cancelCountdown();
    _secondsRemaining = null;
    _countdownHasBeenTriggered = false;
    _isTimeoutHandled = false;
    debugPrint("[CountdownManager] Countdown reset");
  }

  /// Dispose resources
  void dispose() {
    cancelCountdown();
  }
}
