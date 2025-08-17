import 'dart:async';
import 'package:flutter/material.dart';

/// Manages view timers for premium vs free users
class ViewTimerManager {
  Timer? _viewTimer;
  int _viewDuration = 5; // Default 5 seconds for free users
  bool _isReceiverPremium = false;

  // Callbacks
  final VoidCallback? onTimerComplete;
  final ValueChanged<int>? onTimerTick;
  final VoidCallback? onTimerStarted;
  final VoidCallback? onTimerStopped;

  ViewTimerManager({
    this.onTimerComplete,
    this.onTimerTick,
    this.onTimerStarted,
    this.onTimerStopped,
  });

  // Getters
  bool get hasActiveTimer => _viewTimer?.isActive ?? false;
  int get viewDuration => _viewDuration;
  bool get isReceiverPremium => _isReceiverPremium;

  /// Update user premium status
  void updatePremiumStatus(bool isPremium) {
    _isReceiverPremium = isPremium;

    if (isPremium) {
      // Premium users get unlimited viewing time
      _stopTimer();
      debugPrint("[ViewTimer] Premium user detected - unlimited viewing time");
    } else {
      debugPrint(
          "[ViewTimer] Free user detected - ${_viewDuration}s viewing limit");
    }
  }

  /// Start view timer (only for non-premium users)
  void startViewTimer() {
    if (_isReceiverPremium) {
      debugPrint("[ViewTimer] Skipping timer for premium user");
      return;
    }

    if (_viewTimer?.isActive ?? false) {
      debugPrint("[ViewTimer] Timer already active");
      return;
    }

    debugPrint("[ViewTimer] Starting ${_viewDuration}s view timer");
    onTimerStarted?.call();

    int remainingSeconds = _viewDuration;
    onTimerTick?.call(remainingSeconds);

    _viewTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingSeconds--;
      onTimerTick?.call(remainingSeconds);

      if (remainingSeconds <= 0) {
        timer.cancel();
        debugPrint("[ViewTimer] View timer completed");
        onTimerComplete?.call();
      }
    });
  }

  /// Stop/cancel the view timer
  void _stopTimer() {
    if (_viewTimer?.isActive ?? false) {
      _viewTimer!.cancel();
      debugPrint("[ViewTimer] View timer stopped");
      onTimerStopped?.call();
    }
    _viewTimer = null;
  }

  /// Pause timer (for premium users or special cases)
  void pauseTimer() {
    _stopTimer();
    debugPrint("[ViewTimer] View timer paused");
  }

  /// Resume timer (if not premium)
  void resumeTimer() {
    if (!_isReceiverPremium && !hasActiveTimer) {
      startViewTimer();
      debugPrint("[ViewTimer] View timer resumed");
    }
  }

  /// Set custom view duration (for testing or special cases)
  void setViewDuration(int seconds) {
    if (seconds > 0) {
      _viewDuration = seconds;
      debugPrint("[ViewTimer] View duration set to ${_viewDuration}s");
    }
  }

  /// Check if timer should be shown in UI
  bool shouldShowTimer() {
    return !_isReceiverPremium && hasActiveTimer;
  }

  /// Get remaining time for UI display
  int getRemainingTime() {
    // This would need to be updated by the timer tick callback
    // For now, return the full duration as a fallback
    return _viewDuration;
  }

  /// Dispose resources
  void dispose() {
    _stopTimer();
    debugPrint("[ViewTimer] ViewTimerManager disposed");
  }
}
