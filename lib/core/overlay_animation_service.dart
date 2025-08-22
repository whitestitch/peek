// lib/core/overlay_animation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/theme/colors.dart';

// --- (Gradient definitions are kept but will be unused in this test) ---
Gradient _likeGradient = LinearGradient(colors: [
  peekPrimaryColor.withValues(alpha: 0.8),
  peekPrimaryColor.withValues(alpha: 0.5)
]);
const Gradient _dislikeGradient = LinearGradient(
    colors: [Color(0xEEFF758C), Color(0xEEFF7EB3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight);

class OverlayAnimationService {
  final Ref _ref;
  OverlayEntry? _currentOverlayEntry;

  OverlayAnimationService(this._ref);

  Future<void> showLikeAnimation() async {
    debugPrint("[OVERLAY-SERVICE] showLikeAnimation() called.");
    await _showRootAnimation(
      lottieAssetPath: 'assets/animations/lottie/like_animation.json',
      gradient: _likeGradient,
    );
  }

  Future<void> showDislikeAnimation() async {
    debugPrint("[OVERLAY-SERVICE] showDislikeAnimation() called.");
    await _showRootAnimation(
      lottieAssetPath: 'assets/animations/lottie/dislike_animation.json',
      gradient: _dislikeGradient,
    );
  }

  void hideCurrentAnimation() {
    if (_currentOverlayEntry != null) {
      debugPrint("[OVERLAY-SERVICE] Hiding current animation overlay.");
      try {
        _currentOverlayEntry!.remove();
      } catch (e) {
        debugPrint(
            "ℹ️ [OVERLAY-SERVICE] Info removing overlay: $e. (May have already been removed).");
      }
      _currentOverlayEntry = null;
    }
  }

  Future<void> _showRootAnimation({
    required String lottieAssetPath,
    required Gradient gradient,
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    debugPrint(
        "[OVERLAY-SERVICE] Starting _showRootAnimation for: $lottieAssetPath");
    hideCurrentAnimation();

    try {
      final GlobalKey<NavigatorState> navigatorKey =
          _ref.read(navigatorKeyProvider);

      final BuildContext? navigatorContext = navigatorKey.currentContext;

      if (navigatorContext == null || !navigatorContext.mounted) {
        debugPrint(
            "  -> ❌ FAILED: Cannot show overlay, navigator context is invalid.");
        return;
      }

      // ROBUST FIX: Get the OverlayState directly from the NavigatorState
      // instead of searching the context, which can fail during transitions.
      final NavigatorState? navigatorState = navigatorKey.currentState;
      if (navigatorState == null) {
        debugPrint(
            "  -> ❌ FAILED: navigatorKey.currentState is NULL. Aborting animation.");
        return;
      }
      final OverlayState overlayState = navigatorState.overlay!;
      debugPrint(
          "  -> ✅ SUCCESS: Got valid OverlayState directly from Navigator.");

      _currentOverlayEntry = OverlayEntry(
        builder: (ctx) => Material(
          type: MaterialType.transparency,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(gradient: gradient),
              child: Lottie.asset(lottieAssetPath, fit: BoxFit.contain),
            ),
          ),
        ),
      );

      overlayState.insert(_currentOverlayEntry!);
      debugPrint(
          "✅ [OVERLAY-SERVICE] OverlayEntry INSERTED into OverlayState.");

      await Future.delayed(duration);
      hideCurrentAnimation();
    } catch (e, s) {
      debugPrint(
          "❌❌❌ [OVERLAY-SERVICE] CATASTROPHIC ERROR in _showRootAnimation: $e");
      debugPrintStack(stackTrace: s, label: "Overlay Service Exception");
      hideCurrentAnimation();
    }
  }
}
