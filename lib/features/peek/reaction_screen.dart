// lib/features/peek/reaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Lottie import is no longer needed here as this screen won't play the animation
// import 'package:lottie/lottie.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/core/firestore_service.dart';

class ReactionScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String originalSenderUid;
  final String imageUrl; // Keeping imageUrl for background display

  const ReactionScreen({
    super.key,
    required this.requestId,
    required this.originalSenderUid,
    required this.imageUrl,
  });

  @override
  ConsumerState<ReactionScreen> createState() => _ReactionScreenState();
}

class _ReactionScreenState extends ConsumerState<ReactionScreen> {
  bool _isSubmitting = false;
  // _activeAnimationAsset is no longer needed here

  Future<void> _handleReaction(String reactionType) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      if (reactionType == 'like') {
        debugPrint(
            "[ReactionScreen] User chose LIKE for Peek (requestId: ${widget.requestId}). Incrementing for sender: ${widget.originalSenderUid}");
        await firestoreService.incrementLikesReceived(widget.originalSenderUid);
        // No local animation display here
      } else if (reactionType == 'dislike') {
        debugPrint(
            "[ReactionScreen] User chose DISLIKE for Peek (requestId: ${widget.requestId}). Incrementing for sender: ${widget.originalSenderUid}");
        await firestoreService
            .incrementDislikesReceived(widget.originalSenderUid);
        // No local animation display here
      } else if (reactionType == 'skip') {
        debugPrint(
            "[ReactionScreen] User chose SKIP for Peek (requestId: ${widget.requestId}).");
        // No Firestore update for skip
      }

      // After processing the reaction (or skip), navigate home.
      // The animation for the SENDER will be triggered on their device by listening to Firestore changes.
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint("❌ [ReactionScreen] Error processing reaction: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not submit reaction. Please try again.'),
              backgroundColor: Colors.redAccent),
        );
        // Reset submitting state on error if not navigating away immediately
        setState(() {
          _isSubmitting = false;
        });
      }
    }
    // The 'finally' block that navigated home is removed because navigation
    // now happens directly after successful processing or for skip.
    // If an error occurs, the user stays on the screen with _isSubmitting reset.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Full black background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Background Image (the Peek itself)
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (context, error, stackTrace) {
              debugPrint(
                  "Error loading background image in ReactionScreen: $error");
              return Container(
                color: Colors.grey.shade800,
                child: const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.white54, size: 100)),
              );
            },
          ),

          // Layer 2: Semi-transparent overlay to dim the image
          Container(
            color: Colors.black.withOpacity(0.5),
          ),

          // Layer 3: Reaction UI (Prompt and Buttons)
          // This is always visible now, as there's no local animation state to hide it.
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    "How was this Peek?",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 32,
                          // shadows: [
                          //   const Shadow(
                          //       blurRadius: 3.0,
                          //       color: Colors.black87,
                          //       offset: Offset(1, 1))
                          // ]
                        ),
                  ),
                  const SizedBox(height: 40),
                  _buildReactionButton(
                    context: context,
                    iconData: Icons.favorite_rounded,
                    label: "Like",
                    buttonBackgroundColor: peekPrimaryColor
                        .withOpacity(0.95), // Use your theme's primary color
                    iconColor: peekBackgroundColor,
                    labelColor: peekBackgroundColor,
                    onPressed:
                        _isSubmitting ? null : () => _handleReaction('like'),
                  ),
                  const SizedBox(height: 20),
                  _buildReactionButton(
                    context: context,
                    iconData: Icons.thumb_down_alt_rounded,
                    label: "Dislike",
                    buttonBackgroundColor:
                        Colors.blueGrey.shade700, // Darker, distinct color
                    iconColor: Colors.white.withOpacity(0.85),
                    labelColor: Colors.white.withOpacity(0.85),
                    onPressed:
                        _isSubmitting ? null : () => _handleReaction('dislike'),
                  ),
                  const SizedBox(height: 20),
                  _buildReactionButton(
                    context: context,
                    iconData: Icons.skip_next_rounded,
                    label: "Skip",
                    buttonBackgroundColor: Colors.white.withOpacity(0.85),
                    iconColor: Colors.black87,
                    labelColor: Colors.black87,
                    onPressed:
                        _isSubmitting ? null : () => _handleReaction('skip'),
                  ),
                ],
              ),
            ),
          ),

          // Layer 4: Loading indicator while submitting
          if (_isSubmitting)
            Positioned.fill(
                child: Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                  child: CircularProgressIndicator(color: Colors.white)),
            ))
        ],
      ),
    );
  }

  // Method signature updated to accept specific styling parameters
  Widget _buildReactionButton({
    required BuildContext context,
    required IconData iconData,
    required String label,
    required Color buttonBackgroundColor,
    Color? iconColor,
    Color? labelColor,
    Color defaultContentColor =
        Colors.white, // Fallback for icon/label if specific colors not provided
    required VoidCallback? onPressed,
  }) {
    final effectiveIconColor = iconColor ?? defaultContentColor;
    final effectiveLabelColor = labelColor ?? defaultContentColor;

    return ElevatedButton.icon(
      icon: Icon(iconData,
          size: 28,
          color: onPressed == null
              ? effectiveIconColor.withOpacity(0.7)
              : effectiveIconColor),
      label: Text(label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: onPressed == null
                ? effectiveLabelColor.withOpacity(0.7)
                : effectiveLabelColor,
          )),
      onPressed: onPressed,
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith<Color?>(
          (Set<MaterialState> states) {
            if (states.contains(MaterialState.disabled)) {
              return buttonBackgroundColor.withOpacity(0.5);
            }
            return buttonBackgroundColor;
          },
        ),
        // foregroundColor is for ripple and can be a general fallback if text/icon colors aren't set
        foregroundColor: MaterialStateProperty.all<Color>(
            effectiveLabelColor.withOpacity(0.8)),
        minimumSize: MaterialStateProperty.all<Size>(
          const Size(double.infinity, 60),
        ),
        padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
          const EdgeInsets.symmetric(vertical: 15),
        ),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        elevation: MaterialStateProperty.all<double>(
            onPressed == null ? 1 : 3), // Less elevation when disabled
        shadowColor: MaterialStateProperty.all<Color>(
            buttonBackgroundColor.withOpacity(0.5)),
      ),
    );
  }
}
