// lib/core/root_realtime_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/features/peek/providers/peek_providers.dart';

class RootRealtimeListener extends ConsumerStatefulWidget {
  final Widget child;
  const RootRealtimeListener({super.key, required this.child});
  @override
  ConsumerState<RootRealtimeListener> createState() =>
      _RootRealtimeListenerState();
}

class _RootRealtimeListenerState extends ConsumerState<RootRealtimeListener> {
  // Keeps track of processed reaction IDs to prevent re-playing animations
  final Set<String> _processedReactionIds = {};

  @override
  Widget build(BuildContext context) {
    ref.listen(newReactionStreamProvider, (previous, next) {
      if (next.isLoading || !next.hasValue) return;

      final newReactions = next.value ?? [];

      for (final reactionDoc in newReactions) {
        // If we haven't processed this specific reaction event yet, process it.
        if (_processedReactionIds.add(reactionDoc.id)) {
          final data = reactionDoc.data();
          final type = data['reactionType'] as String?;

          debugPrint(
              "✅ [RootRealtimeListener] New reaction event detected! Type: $type. Triggering animation directly.");

          // SIMPLIFIED: Call the service directly to test the layering fix.
          if (type == 'like') {
            ref.read(overlayAnimationServiceProvider).showLikeAnimation();
          } else if (type == 'dislike') {
            ref.read(overlayAnimationServiceProvider).showDislikeAnimation();
          }
        }
      }
    });

    // Render the rest of the app tree.
    return widget.child;
  }
}
