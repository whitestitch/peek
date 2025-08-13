// lib/features/peek/reaction_screen.dart

import 'dart:ui'; // Required for ImageFilter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  const ReactionScreen({
    super.key,
    required this.requestId,
    required this.originalSenderUid,
  });

  @override
  ConsumerState<ReactionScreen> createState() => _ReactionScreenState();
}

class _ReactionScreenState extends ConsumerState<ReactionScreen> {
  String? _selfFetchedImageUrl;
  bool _isLoading = true;
  String? _loadError;

  // Use the real bucket where SEND uploads land (new Firebase default).
  // Keeps this screen working regardless of app-default bucket config.
  final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://peekio-db.firebasestorage.app',
  );

  bool _isSubmitting = false;
  bool _isProcessingAction = false;
  bool _reactionSubmitted = false;

  @override
  void initState() {
    super.initState();
    _fetchPeekData(); // NEW: Call the fetch method on init
  }

  // NEW: Method to fetch peek data and generate a fresh URL
  Future<void> _fetchPeekData() async {
    // DEBUG
    // DEBUG
    // DEBUG
    // DEV MODE: If a test ID is used, load dummy data and skip Firestore.

    if (widget.requestId == 'test-request-id') {
      if (mounted) {
        setState(() {
          // Use a placeholder image from the web for testing
          _selfFetchedImageUrl = 'https://picsum.photos/seed/peekio/400/800';
          _isLoading = false;
        });
      }
      return; // Exit here to prevent the real database call
    }

    // END DEBUG
    // END DEBUG
    // END DEBUG
    try {
      final peekDoc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (!peekDoc.exists) {
        throw Exception("Peek document not found.");
      }

      final data = peekDoc.data();

      // Prefer persisted URL if present; otherwise resolve from Storage.
      final String? persistedUrl = (data?['imageUrl'] as String?)?.trim();
      String freshImageUrl;
      if (persistedUrl != null && persistedUrl.isNotEmpty) {
        freshImageUrl = persistedUrl;
      } else {
        final String? storagePath = (data?['storagePath'] as String?)?.trim();
        if (storagePath == null || storagePath.isEmpty) {
          throw Exception("Storage path is missing from the peek document.");
        }
        // Resolve from the correct bucket (firebasestorage.app)
        freshImageUrl = await _storage.ref(storagePath).getDownloadURL();
      }

      if (mounted) {
        setState(() {
          _selfFetchedImageUrl = freshImageUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [ReactionScreen] Failed to fetch peek data: $e");
      if (mounted) {
        setState(() {
          _loadError = "Could not load Peek. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

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
          reportedImageUrl: _selfFetchedImageUrl ?? '',
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

    // STEP 1: LOG THAT THE PROCESS IS STARTING
    debugPrint("[ReactionScreen] Submitting reaction: $reactionType...");

    final firestoreService = ref.read(firestoreServiceProvider);

    try {
      await firestoreService.addReactionToPeek(widget.requestId, reactionType);

      // "skip" requires no database action

      // STEP 2: LOG SUCCESS AND UPDATE UI
      debugPrint(
          "[ReactionScreen] Database update successful! Showing confirmation UI...");
      if (mounted) {
        setState(() {
          _reactionSubmitted = true;
          _isSubmitting = false;
        });

        // STEP 3: LOG THE DELAY
        debugPrint(
            "[ReactionScreen] Starting 2.5 second delay before navigating home...");
        await Future.delayed(
            const Duration(milliseconds: 2500)); // Increased delay

        // STEP 4: LOG THE FINAL NAVIGATION
        if (mounted) {
          debugPrint(
              "[ReactionScreen] Delay finished. Navigating to home ('/').");
          context.go('/');
        }
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
          _isSubmitting = false; // Reset on error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePadding = MediaQuery.of(context).padding;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_loadError != null || _selfFetchedImageUrl == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _loadError ?? "An unknown error occurred.",
              style: const TextStyle(color: Colors.redAccent, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Layer 1: Background Image (the Peek itself)
          Image.network(
            _selfFetchedImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (context, error, stackTrace) {
              // This error should now be much rarer
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
                        // Navigate home immediately
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
                            : () => context.go('/'),
                      ),
                    ),
                  ],
                ),

                // Spacer to push reaction elements down if needed, or adjust mainAxisAlignment
                const Spacer(),

                // Main Reaction Prompt and Buttons
                if (_reactionSubmitted)
                  // This is the confirmation UI
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.white, size: 70),
                      SizedBox(height: 20),
                      Text(
                        "Thanks for your feedback!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  )
                else
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Peekio Love?",
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                                color: peekWhiteColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 42,
                                shadows: [
                              const Shadow(
                                  blurRadius: 4.0,
                                  color: peekSurfaceColor,
                                  offset: Offset(1, 1))
                            ]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Your feedback is anonymous.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 16,
                        ),
                      ),
                      // SPACE
                      const SizedBox(height: 30),
                      // SPACE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Dislike Button
                          ElevatedButton(
                            onPressed: (_isSubmitting || _isProcessingAction)
                                ? null
                                : () => _handleReaction('dislike'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: peekErrorColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 34,
                                vertical: 16,
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.2),
                            ),
                            child: const Icon(
                              // Icons.heart_broken,
                              Icons.thumb_down,
                              size: 24,
                              color: peekWhiteColor,
                              // color: peekBackgroundColor,
                            ),
                          ),

                          // Like Button
                          ElevatedButton(
                            onPressed: (_isSubmitting || _isProcessingAction)
                                ? null
                                : () => _handleReaction('like'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: peekPrimaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 34, vertical: 16),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 24,
                              color: peekBackgroundColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                // Pushes buttons towards center if column takes full height
                const Spacer(),
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
