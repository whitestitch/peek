// lib/features/peek/pages/managers/peek_sender_wait_timer_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';

class PeekSenderWaitTimerManager {
  Timer? _countdownTimer;
  Timer? _watchdogTimer;
  late final AnimationController _animationController;

  final TickerProvider vsync;
  final Function(int) onCountdownUpdate;
  final VoidCallback onTimeout;
  final Function(String, String?) onFinalCountdownComplete;

  PeekSenderWaitTimerManager({
    required this.vsync,
    required this.onCountdownUpdate,
    required this.onTimeout,
    required this.onFinalCountdownComplete,
  }) {
    _animationController = AnimationController(
      vsync: vsync,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  AnimationController get animationController => _animationController;

  void startManualCountdown() {
    if (_countdownTimer?.isActive ?? false) return;

    debugPrint(
        "[PeekSenderWaitTimerManager] Starting manual 30-second countdown");

    // Set initial countdown to 30 seconds
    onCountdownUpdate(30);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentSeconds = _countdownTimer?.tick ?? 0;
      final remaining = 30 - currentSeconds;

      if (remaining <= 0) {
        timer.cancel();
        debugPrint("[PeekSenderWaitTimerManager] Manual countdown finished");
      } else {
        onCountdownUpdate(remaining);
      }
    });
  }

  void startCountdown(DateTime deadline) {
    if (_countdownTimer?.isActive ?? false) return;

    // Cancel watchdog timer when official countdown starts
    _watchdogTimer?.cancel();

    // Set initial countdown value
    final now = DateTime.now();
    final initialRemaining = deadline.difference(now).inSeconds;
    final remaining = initialRemaining > 0 ? initialRemaining : 0;

    debugPrint(
        "[PeekSenderWaitTimerManager] Starting countdown with deadline: $deadline");
    debugPrint(
        "[PeekSenderWaitTimerManager] Initial remaining seconds: $remaining");

    onCountdownUpdate(remaining);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = deadline.difference(now).inSeconds;

      if (remaining <= 0) {
        timer.cancel();
        debugPrint(
            "[PeekSenderWaitTimerManager] Countdown finished, calling timeout");
        onTimeout();
      } else {
        debugPrint(
            "[PeekSenderWaitTimerManager] Countdown update: ${remaining}s remaining");
        onCountdownUpdate(remaining);
      }
    });
  }

  void startFinalCountdown(String imageUrl, String? senderLocation) {
    _countdownTimer?.cancel();

    // Set initial countdown to 3 seconds
    onCountdownUpdate(3);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentSeconds = _countdownTimer?.tick ?? 0;
      final remaining = 3 - currentSeconds;

      if (remaining <= 1) {
        timer.cancel();
        debugPrint("[PeekSenderWaitTimerManager] Final countdown finished");
        onFinalCountdownComplete(imageUrl, senderLocation);
      } else {
        onCountdownUpdate(remaining);
      }
    });
  }

  void startWatchdogTimer() {
    _watchdogTimer = Timer(const Duration(seconds: 70), () {
      debugPrint(
          "[PeekSenderWaitTimerManager] Watchdog timer fired. Forcing timeout.");
      onTimeout();
    });
  }

  void dispose() {
    _countdownTimer?.cancel();
    _watchdogTimer?.cancel();
    _animationController.dispose();
  }
}
