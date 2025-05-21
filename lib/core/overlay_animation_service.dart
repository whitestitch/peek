// lib/core/overlay_animation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/router.dart' show shellNavigatorKey;

final overlayAnimationServiceProvider =
    Provider<OverlayAnimationService>((ref) {
  return OverlayAnimationService(ref);
});

class OverlayAnimationService {
  final Ref _ref;
  OverlayEntry? _currentOverlayEntry;

  OverlayAnimationService(this._ref);

  Future<void> _showRootAnimation({
    required String lottieAssetPath,
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    debugPrint(
        "[OverlayAnimationService] _showRootAnimation CALLED for: $lottieAssetPath");

    hideCurrentAnimation();

    BuildContext? navigatorContext;
    OverlayState? overlayState;

    try {
      await Future.delayed(
          const Duration(milliseconds: 50)); // Diagnostic delay
      debugPrint("[OverlayAnimationService] Post-diagnostic delay.");

      final GlobalKey<NavigatorState> navigatorKey =
          _ref.read(navigatorKeyProvider);
      navigatorContext = navigatorKey.currentContext;

      if (navigatorContext == null) {
        debugPrint(
            "❌ [OverlayAnimationService] Root navigator context is NULL (after diagnostic delay). Cannot show global animation for '$lottieAssetPath'.");
        return;
      }
      debugPrint(
          "✅ [OverlayAnimationService] Got navigatorContext (after diagnostic delay): $navigatorContext for '$lottieAssetPath'");

      debugPrint(
          "[OverlayAnimationService] STEP 1: Checking if navigatorContext is mounted for '$lottieAssetPath'.");
      if (!navigatorContext.mounted) {
        debugPrint(
            "❌ [OverlayAnimationService] STEP 1 FAILED: navigatorContext is NOT MOUNTED. Cannot show animation for '$lottieAssetPath'. Returning.");
        return;
      }
      debugPrint(
          "✅ [OverlayAnimationService] STEP 1 PASSED: navigatorContext IS MOUNTED for '$lottieAssetPath'.");

      // More detailed check for navigatorKey.currentState
      final NavigatorState? navigatorState = shellNavigatorKey.currentState;
      if (navigatorState == null) {
        debugPrint(
            "❌ [OverlayAnimationService] shellNavigatorKey.currentState is null. Aborting animation.");
        return;
      }

      // Pull its OverlayState
      final OverlayState? overlayState = navigatorState.overlay;
      if (overlayState == null) {
        debugPrint(
            "❌ [OverlayAnimationService] shell Navigator's overlay is null. Aborting animation.");
        return;
      }

      // try {
      //   debugPrint(
      //       "[OverlayAnimationService] Inserting into shell overlay for '$lottieAssetPath'");

      //   overlayState = Overlay.of(navigatorContext, rootOverlay: true);
      //   debugPrint(
      //       "✅ [OverlayAnimationService] STEP 2 COMPLETED: Overlay.of(rootOverlay: true) called for '$lottieAssetPath'. Result: ${overlayState == null ? 'NULL' : 'NOT NULL'}.");
      // } catch (e, s) {
      //   debugPrint(
      //       "❌❌❌ [OverlayAnimationService] STEP 2 EXCEPTION during Overlay.of(rootOverlay: true): $e");
      //   debugPrintStack(
      //       stackTrace: s, label: "Exception in Overlay.of(rootOverlay: true)");

      //   if (potentialOverlayFromNavigatorState != null) {
      //     debugPrint(
      //         "[OverlayAnimationService] FALLBACK: Using overlay from navigatorKey.currentState.overlay because Overlay.of() failed.");
      //     overlayState = potentialOverlayFromNavigatorState;
      //   } else {
      //     debugPrint(
      //         "❌ [OverlayAnimationService] FALLBACK FAILED: navigatorKey.currentState.overlay is also null after Overlay.of() exception.");
      //     return;
      //   }
      // }

      if (overlayState == null) {
        // This means Overlay.of() returned null and the fallback (potentialOverlayFromNavigatorState) was also null.
        debugPrint(
            "❌ [OverlayAnimationService] STEP 2 FAILED (Post-check): OverlayState is NULL even after trying Overlay.of and fallback. Cannot show animation for '$lottieAssetPath'. Returning.");
        return;
      }

      debugPrint(
          "[OverlayAnimationService] STEP 3: Checking if overlayState is mounted for '$lottieAssetPath'.");
      if (!overlayState.mounted) {
        debugPrint(
            "❌ [OverlayAnimationService] STEP 3 FAILED: overlayState is NOT MOUNTED. Cannot show animation for '$lottieAssetPath'. Returning.");
        return;
      }
      debugPrint(
          "✅ [OverlayAnimationService] STEP 3 PASSED: overlayState IS MOUNTED for '$lottieAssetPath'.");

      debugPrint(
          "[OverlayAnimationService] Creating OverlayEntry for '$lottieAssetPath'.");
      _currentOverlayEntry = OverlayEntry(
        builder: (ctx) {
          return Material(
            type: MaterialType.transparency,
            child: IgnorePointer(
              child: Center(
                child: Lottie.asset(
                  lottieAssetPath,
                  key: ValueKey(lottieAssetPath + DateTime.now().toString()),
                  width: MediaQuery.of(ctx).size.width * 0.75,
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  fit: BoxFit.contain,
                  onLoaded: (composition) {
                    debugPrint(
                        "✅ [OverlayAnimationService] Lottie loaded: ${composition.duration}");
                  },
                  // Error builder
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                        "❌ [OverlayAnimationService] Lottie load error for '$lottieAssetPath': $error");
                    debugPrintStack(
                        stackTrace: stackTrace,
                        label: "Lottie Load Error for $lottieAssetPath");
                    return Container(
                      width: MediaQuery.of(ctx).size.width * 0.75,
                      height: MediaQuery.of(ctx).size.height * 0.75,
                      color: Colors.red.withOpacity(0.5),
                      padding: const EdgeInsets.all(10),
                      child: SingleChildScrollView(
                        child: Text(
                          "Lottie Error:\nAsset: $lottieAssetPath\nError: $error",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.normal),
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      );

      if (_currentOverlayEntry == null) {
        debugPrint(
            "❌ [OverlayAnimationService] _currentOverlayEntry is null AFTER creation. Cannot insert.");
        return;
      }

      debugPrint(
          "[OverlayAnimationService] Attempting to insert overlay for '$lottieAssetPath'. OverlayState isMounted: ${overlayState.mounted}");

      overlayState.insert(_currentOverlayEntry!);
      debugPrint(
          "[OverlayAnimationService] OverlayEntry inserted for '$lottieAssetPath'");

      debugPrint(
          "[OverlayAnimationService] Starting delay of ${duration.inMilliseconds}ms for '$lottieAssetPath'.");

      await Future.delayed(duration);
      debugPrint(
          "[OverlayAnimationService] Duration elapsed, hiding '$lottieAssetPath'");
      hideCurrentAnimation();

      this.hideCurrentAnimation();
    } catch (e, s) {
      debugPrint(
          "❌❌❌ [OverlayAnimationService] OVERALL EXCEPTION in _showRootAnimation for '$lottieAssetPath': $e");
      debugPrintStack(
          stackTrace: s, label: "Overall Exception in _showRootAnimation");
      this.hideCurrentAnimation();
    } finally {
      debugPrint(
          "[OverlayAnimationService] _showRootAnimation execution path COMPLETED for '$lottieAssetPath'. NavigatorContext was: $navigatorContext, Final OverlayState was: $overlayState");
    }
  }

  void hideCurrentAnimation() {
    if (_currentOverlayEntry != null) {
      debugPrint(
          "[OverlayAnimationService] Attempting to remove overlay. Current entry: $_currentOverlayEntry");
      try {
        _currentOverlayEntry!.remove();
        debugPrint(
            "[OverlayAnimationService] Overlay remove() called successfully.");
      } catch (e) {
        debugPrint(
            "ℹ️ [OverlayAnimationService] Info/Error removing overlay entry: $e. It might have already been removed or disposed.");
      }
      _currentOverlayEntry = null;
      debugPrint(
          "[OverlayAnimationService] _currentOverlayEntry set to null after hide attempt.");
    }
  }

  Future<void> showLikeAnimation() async {
    debugPrint("[OverlayAnimationService] Public showLikeAnimation() called.");
    await _showRootAnimation(
        lottieAssetPath: 'assets/animations/lottie/like_animation.json');
  }

  Future<void> showDislikeAnimation() async {
    debugPrint(
        "[OverlayAnimationService] Public showDislikeAnimation() called.");
    await _showRootAnimation(
        lottieAssetPath: 'assets/animations/lottie/dislike_animation.json');
  }
}
