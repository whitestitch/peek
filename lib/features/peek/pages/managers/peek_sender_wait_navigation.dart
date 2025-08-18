// lib/features/peek/pages/managers/peek_sender_wait_navigation.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PeekSenderWaitNavigation {
  void navigateToImageView(
    BuildContext context,
    String requestId,
    String imageUrl,
    String? senderLocation,
  ) {
    context.go(
      '/peek-image',
      extra: {
        'requestId': requestId,
        'imageUrl': imageUrl,
        if (senderLocation != null) 'senderLocation': senderLocation,
      },
    );
  }

  void navigateToHome(BuildContext context) {
    context.go('/');
  }

  void navigateToHomeWithCancellation(BuildContext context) {
    context.go('/?show=peekCancelled');
  }
}
