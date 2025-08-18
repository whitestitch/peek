// lib/features/peek/pages/managers/peek_accepted_navigation_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

class PeekAcceptedNavigationManager {
  final String requestId;
  final VoidCallback onNavigationComplete;

  Timer? _navigationTimer;

  PeekAcceptedNavigationManager({
    required this.requestId,
    required this.onNavigationComplete,
  });

  void startNavigationTimer() {
    // After 3 seconds, trigger navigation
    _navigationTimer = Timer(const Duration(seconds: 3), () {
      debugPrint(
        "[PeekAcceptedNavigationManager] Celebration finished. Navigating to sender wait page.",
      );
      onNavigationComplete();
    });
  }

  void cancelNavigationTimer() {
    _navigationTimer?.cancel();
  }

  void dispose() {
    _navigationTimer?.cancel();
  }
}
