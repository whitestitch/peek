// lib/features/peek/reaction_screen.dart

import 'dart:ui'; // Required for ImageFilter
import 'package:firebase_auth/firebase_auth.dart'; // Required for FirebaseAuth
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
  bool _isProcessingAction = false;
  // _activeAnimationAsset is no longer needed here

  // Methods relocated and adapted from PeekImageView
  Future<void> _reportThisPeek() async {
    if (widget.originalSenderUid.isEmpty) {
      debugPrint(
          "[ReactionScreen] Cannot report: Original Sender ID is missing.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cannot report this Peek: sender unknown.")));
      }
      return;
    }
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: peekSurfaceColor,
        title: const Text("Report Peek?",
            style: TextStyle(color: peekOnSurfaceColor)),
        content: const Text(
            "Are you sure you want to report this Peek for objectionable content? This action cannot be undone.",
            style: TextStyle(color: peekOnSurfaceColor)),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: peekOnSurfaceColor)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            child: Text("Report",
                style: TextStyle(color: Colors.redAccent.shade100)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final reporterId = FirebaseAuth.instance.currentUser?.uid;
        if (reporterId == null) throw Exception("Reporter not logged in");

        await firestoreService.addReport(
          peekRequestId: widget.requestId,
          reportedImageUrl: widget.imageUrl,
          reportedSenderId: widget.originalSenderUid,
          reporterId: reporterId,
          reason: "objectionable_content_from_reaction_screen",
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Peek reported. Thank you.")));
          // Decide if navigation should happen here or if user stays to react
        }
      } catch (e) {
        debugPrint("❌ Error reporting Peek: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to report Peek. Please try again.")));
        }
      }
    }
    if (mounted) setState(() => _isProcessingAction = false);
  }

  Future<void> _blockThisSender() async {
    if (widget.originalSenderUid.isEmpty) {
      debugPrint(
          "[ReactionScreen] Cannot block: Original Sender ID is missing.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cannot block this sender: sender unknown.")));
      }
      return;
    }
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: peekSurfaceColor,
        title: const Text("Block Sender?",
            style: TextStyle(color: peekOnSurfaceColor)),
        content: const Text(
            "Are you sure you want to block this sender? You will no longer receive Peeks from them.",
            style: TextStyle(color: peekOnSurfaceColor)),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: peekOnSurfaceColor)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            child: Text("Block",
                style: TextStyle(color: Colors.redAccent.shade100)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) {
          throw Exception("Current user not logged in");
        }

        await firestoreService.blockUser(
            byUserId: currentUserId, userIdToBlock: widget.originalSenderUid);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Sender blocked successfully.")));
          // After blocking, typically navigate away, e.g., to home.
          // This might happen after reaction as well, ensure flow is logical.
          context.go('/');
        }
      } catch (e) {
        debugPrint("❌ Error blocking sender: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to block sender. Please try again.")));
        }
      }
    }
    if (mounted) setState(() => _isProcessingAction = false);
  }

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
      } else if (reactionType == 'dislike') {
        debugPrint(
            "[ReactionScreen] User chose DISLIKE for Peek (requestId: ${widget.requestId}). Incrementing for sender: ${widget.originalSenderUid}");
        await firestoreService
            .incrementDislikesReceived(widget.originalSenderUid);
      } else if (reactionType == 'skip') {
        debugPrint(
            "[ReactionScreen] User chose SKIP for Peek (requestId: ${widget.requestId}).");
      }

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
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.black,
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

          // Layer 2: Blur Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  // Adjust blur intensity
                  sigmaX: 45.0,
                  sigmaY: 45.0),
              child: Container(
                color:
                    // Optional: slight dimming
                    Colors.black.withOpacity(0.55),
              ),
            ),
          ),

          // Layer 3: UI Elements (Prompt, Buttons, Menus)
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, safePadding.top + 10, 20, safePadding.bottom + 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment
                  .spaceBetween, // Pushes content to top and bottom
              children: <Widget>[
                // Top Row for Skip (X) and Report/Block (...)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Report/Block Button (Three-dots top-left)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.black.withOpacity(0.4),
                      child: PopupMenuButton<String>(
                        iconSize: 22,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        color: peekSurfaceColor,
                        onSelected: (String value) {
                          if (value == 'report') {
                            _reportThisPeek();
                          } else if (value == 'block') {
                            _blockThisSender();
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'report',
                            child: ListTile(
                              leading: Icon(Icons.flag_outlined,
                                  color: peekOnSurfaceColor),
                              title: Text('Report Peek',
                                  style: TextStyle(color: peekOnSurfaceColor)),
                            ),
                          ),
                          if (widget.originalSenderUid.isNotEmpty)
                            const PopupMenuItem<String>(
                              value: 'block',
                              child: ListTile(
                                leading: Icon(Icons.block_flipped,
                                    color: peekOnSurfaceColor),
                                title: Text('Block Sender',
                                    style:
                                        TextStyle(color: peekOnSurfaceColor)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Skip Button (X top-right)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.black.withOpacity(0.4),
                      child: IconButton(
                        tooltip: 'Skip',
                        icon: const Icon(Icons.close,
                            size: 24, color: Colors.white),
                        onPressed: (_isSubmitting || _isProcessingAction)
                            ? null
                            : () => _handleReaction('skip'),
                      ),
                    ),
                  ],
                ),

                // Spacer to push reaction elements down if needed, or adjust mainAxisAlignment
                const Spacer(),

                // Main Reaction Prompt and Buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "How was this Peek?",
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 28, // Slightly adjusted for better fit
                              shadows: [
                            const Shadow(
                                blurRadius: 2.0,
                                color: Colors.black54,
                                offset: Offset(1, 1))
                          ]),
                    ),
                    const SizedBox(height: 30), // Reduced spacing
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Like Button
                        ElevatedButton(
                          onPressed: (_isSubmitting || _isProcessingAction)
                              ? null
                              : () => _handleReaction('like'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: peekPrimaryColor,
                            shape: const CircleBorder(),
                            padding:
                                const EdgeInsets.all(22), // Adjusted padding
                            elevation: 5,
                          ),
                          child: Icon(Icons.favorite_rounded,
                              size: 30, color: peekBackgroundColor),
                        ),
                        // Dislike Button
                        ElevatedButton(
                          onPressed: (_isSubmitting || _isProcessingAction)
                              ? null
                              : () => _handleReaction('dislike'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.blueGrey.shade600, // Adjusted color
                            shape: const CircleBorder(),
                            padding:
                                const EdgeInsets.all(22), // Adjusted padding
                            elevation: 5,
                          ),
                          child: Icon(Icons.thumb_down_alt_rounded,
                              size: 30, color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(), // Pushes buttons towards center if column takes full height
              ],
            ),
          ),

          // Layer 4: Loading indicator while submitting
          if (_isSubmitting || _isProcessingAction)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.6),
                child: const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              ),
            )
        ],
      ),
    );
  }

  // _buildReactionButton is no longer needed as buttons are custom designed in build method
}
