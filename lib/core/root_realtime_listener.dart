// lib/core/root_realtime_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';

class RootRealtimeListener extends ConsumerWidget {
  // Changed to ConsumerWidget
  final Widget child; // This will be your MaterialApp.router

  const RootRealtimeListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set up the listener directly within the build method.
    // Riverpod handles the subscription management.
    // This will be called whenever this widget rebuilds, but Riverpod ensures
    // the listener itself is managed efficiently.
    ref.listen<AsyncValue<DocumentSnapshot<Map<String, dynamic>>?>>(
      userProfileStreamProvider,
      (previousAsyncValue, currentAsyncValue) async {
        // We are interested in the data state
        currentAsyncValue.when(
          data: (snapshot) async {
            // Ensure widget is still mounted before proceeding with side effects
            if (!context.mounted) return;

            if (snapshot == null || !snapshot.exists) {
              if (snapshot == null) {
                debugPrint(
                    "[RootRealtimeListener] User snapshot is null (user likely logged out or stream error).");
              } else if (!snapshot.exists) {
                debugPrint(
                    "[RootRealtimeListener] User document does not exist.");
              }
              // Reset last counts if user logs out or document disappears
              final currentLastCounts = ref.read(lastReactionCountsProvider);
              if (currentLastCounts.likes != -1 ||
                  currentLastCounts.dislikes != -1) {
                ref.read(lastReactionCountsProvider.notifier).state =
                    (likes: -1, dislikes: -1);
              }
              return;
            }

            final data = snapshot.data();
            if (data == null) {
              debugPrint("[RootRealtimeListener] Snapshot data is null.");
              return;
            }

            final newLikes = data['likesReceivedCount'] as int? ?? 0;
            final newDislikes = data['dislikesReceivedCount'] as int? ?? 0;

            final lastCounts = ref.read(lastReactionCountsProvider);
            final bool isInitialLoadOrReset =
                lastCounts.likes == -1 && lastCounts.dislikes == -1;

            if (isInitialLoadOrReset) {
              debugPrint(
                  "[RootRealtimeListener] Initial data load/reset. Storing counts: Likes=$newLikes, Dislikes=$newDislikes. No animation.");
              // Update state directly without checking for mounted, as this is part of Riverpod's state update
              ref.read(lastReactionCountsProvider.notifier).state =
                  (likes: newLikes, dislikes: newDislikes);
              return;
            }

            final overlayService = ref.read(overlayAnimationServiceProvider);
// **1) If there's a new LIKE, update our stored count immediately,
            //    then run the animation.**
            if (newLikes > lastCounts.likes) {
              debugPrint("[RootRealtimeListener] New LIKE received! "
                  "Current likes: $newLikes, Previous: ${lastCounts.likes}. "
                  "Showing animation and updating stored count.");
              // update stored count _before_ the await
              ref.read(lastReactionCountsProvider.notifier).state =
                  (likes: newLikes, dislikes: lastCounts.dislikes);
              await overlayService.showLikeAnimation();
              return;
            }

            // **2) Same for DISLIKEs.**
            if (newDislikes > lastCounts.dislikes) {
              debugPrint("[RootRealtimeListener] New DISLIKE received! "
                  "Current dislikes: $newDislikes, Previous: ${lastCounts.dislikes}. "
                  "Showing animation and updating stored count.");
              ref.read(lastReactionCountsProvider.notifier).state =
                  (likes: lastCounts.likes, dislikes: newDislikes);
              await overlayService.showDislikeAnimation();
              return;
            }

            // **3) Any other change (e.g. counts reset or manual edit)—
            //    just store the new values without animation.**
            if (newLikes != lastCounts.likes ||
                newDislikes != lastCounts.dislikes) {
              debugPrint(
                  "[RootRealtimeListener] Counts changed (no animation). "
                  "Updating stored: Likes=$newLikes, Dislikes=$newDislikes.");
              ref.read(lastReactionCountsProvider.notifier).state =
                  (likes: newLikes, dislikes: newDislikes);
            }
          },
          loading: () {
            debugPrint(
                "[RootRealtimeListener] User profile stream is loading...");
          },
          error: (error, stackTrace) {
            debugPrint(
                "❌ [RootRealtimeListener] Error in user profile stream: $error");
            if (context.mounted) {
              // Check mounted before updating state provider if it could cause issues
              ref.read(lastReactionCountsProvider.notifier).state =
                  (likes: -1, dislikes: -1);
            }
          },
        );
      },
      // Optional: Handle errors from the listen itself, though errors from the stream are handled in .when
      // onError: (error, stackTrace) {
      //   debugPrint("❌ [RootRealtimeListener] Listener error: $error");
      // },
    );

    // This widget simply renders its child (which will be your MaterialApp.router).
    return child;
  }
}
