// lib/core/overlay_animation_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/core/router.dart' show shellNavigatorKey;
import 'package:peek/theme/colors.dart';

// Define Gradients
// const
// Color.
Gradient _likeGradient = LinearGradient(
  // Color(0xEEA8FF78),
  // Color(0xEE78FFD6)
  colors: [
    peekPrimaryColor.withOpacity(0.8),
    peekPrimaryColor.withOpacity(0.5)
  ],
  // begin: Alignment.bottomCenter,
  // end: Alignment.topCenter,
);

const Gradient _dislikeGradient = LinearGradient(
  colors: [
    Color(0xEEFF758C),
    Color(0xEEFF7EB3)
  ], // Reddish/Pinkish, inspired by a.png (adjust opacity and colors)
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Internal StatefulWidget for animated overlay content
class _AnimatedOverlayContent extends StatefulWidget {
  final String lottieAssetPath;
  final Gradient gradient;
  final Key lottieKey; // Use ValueKey for Lottie to re-trigger if needed

  const _AnimatedOverlayContent({
    // Key for the StatefulWidget itself is implicitly handled by Flutter
    required this.lottieAssetPath,
    required this.gradient,
    required this.lottieKey,
  });

  @override
  _AnimatedOverlayContentState createState() => _AnimatedOverlayContentState();
}

class _AnimatedOverlayContentState extends State<_AnimatedOverlayContent> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    // Trigger fade-in after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _show = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400), // Fade-in duration
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: widget.gradient),
        child: Center(
          child: Lottie.asset(
            widget.lottieAssetPath,
            key: widget.lottieKey, // Use the passed key for Lottie
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.height * 0.75,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              debugPrint(
                  "✅ [OverlayAnimationService] Lottie loaded in _AnimatedOverlayContent: ${composition.duration}");
            },
            errorBuilder: (ctx, error, stackTrace) {
              debugPrint(
                  "❌ [OverlayAnimationService] Lottie load error for '${widget.lottieAssetPath}': $error");
              // Using ctx from errorBuilder's context
              return Container(
                width: MediaQuery.of(ctx).size.width * 0.75,
                height: MediaQuery.of(ctx).size.height * 0.75,
                color: Colors.red.withOpacity(0.5),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  child: Text(
                    "Lottie Error:\nAsset: ${widget.lottieAssetPath}\nError: $error",
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
  }
}

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
    required Gradient gradient,
    Duration duration = const Duration(milliseconds: 2500),
  }) async {
    debugPrint(
        "[OverlayAnimationService] _showRootAnimation CALLED for: $lottieAssetPath");

    hideCurrentAnimation();

    BuildContext? navigatorContext;
    OverlayState? overlayState;
    // OverlayState? overlayState;

    try {
      await Future.delayed(
          const Duration(milliseconds: 50)); // Diagnostic delay
      debugPrint("[OverlayAnimationService] Post-diagnostic delay.");

      // Define lottieValueKey here, within the try block, before it's used.
      final Key lottieValueKey = ValueKey(
          lottieAssetPath + DateTime.now().microsecondsSinceEpoch.toString());

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
          // Use Material for basic text direction, theming for error text if any.
          // IgnorePointer makes the whole overlay non-interactive.
          return Material(
            type: MaterialType.transparency,
            child: IgnorePointer(
              child: _AnimatedOverlayContent(
                lottieAssetPath: lottieAssetPath,
                gradient: gradient,
                lottieKey: lottieValueKey,
              ),
            ),
          );

          // return Material(
          //   type: MaterialType.transparency,
          //   child: IgnorePointer(
          //     child: Center(
          //       child: Lottie.asset(
          //         lottieAssetPath,
          //         key: ValueKey(lottieAssetPath + DateTime.now().toString()),
          //         width: MediaQuery.of(ctx).size.width * 0.75,
          //         height: MediaQuery.of(ctx).size.height * 0.75,
          //         fit: BoxFit.contain,
          //         onLoaded: (composition) {
          //           debugPrint(
          //               "✅ [OverlayAnimationService] Lottie loaded: ${composition.duration}");
          //         },
          //         // Error builder
          //         errorBuilder: (context, error, stackTrace) {
          //           debugPrint(
          //               "❌ [OverlayAnimationService] Lottie load error for '$lottieAssetPath': $error");
          //           debugPrintStack(
          //               stackTrace: stackTrace,
          //               label: "Lottie Load Error for $lottieAssetPath");
          //           return Container(
          //             width: MediaQuery.of(ctx).size.width * 0.75,
          //             height: MediaQuery.of(ctx).size.height * 0.75,
          //             color: Colors.red.withOpacity(0.5),
          //             padding: const EdgeInsets.all(10),
          //             child: SingleChildScrollView(
          //               child: Text(
          //                 "Lottie Error:\nAsset: $lottieAssetPath\nError: $error",
          //                 textAlign: TextAlign.center,
          //                 style: const TextStyle(
          //                     color: Colors.white,
          //                     fontSize: 10,
          //                     decoration: TextDecoration.none,
          //                     fontWeight: FontWeight.normal),
          //                 textDirection: TextDirection.ltr,
          //               ),
          //             ),
          //           );
          //         },
          //       ),
          //     ),
          //   ),
          // );
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
        lottieAssetPath: 'assets/animations/lottie/like_animation.json',
        gradient: _likeGradient);
  }

  Future<void> showDislikeAnimation() async {
    debugPrint(
        "[OverlayAnimationService] Public showDislikeAnimation() called.");
    await _showRootAnimation(
        lottieAssetPath: 'assets/animations/lottie/dislike_animation.json',
        gradient: _dislikeGradient);
  }
}
