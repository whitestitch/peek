// lib/features/peek/pages/managers/peek_receiver_ui.dart
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:peek/theme/colors.dart';

class PeekReceiverUI {
  PreferredSizeWidget buildAppBar() {
    return AppBar(
      title: const Text('Incoming Peek Requests'),
      backgroundColor: peekBackgroundColor.withValues(alpha: 0.8),
      elevation: 0,
      foregroundColor: peekWhiteColor,
    );
  }

  Widget buildBackgroundImage() {
    return Image.asset(
      'assets/images/onboarding_bg_02.jpg',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint("[PeekReceiverUI] Error loading background: $error");
        return Container(color: peekBackgroundColor);
      },
    );
  }

  Widget buildMainContent({
    required DocumentSnapshot<Map<String, dynamic>>? currentRequest,
    required bool isProcessing,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    return Center(
      child: currentRequest == null
          ? _buildNoRequestsState()
          : _buildRequestState(
              isProcessing: isProcessing,
              onAccept: onAccept,
              onDecline: onDecline,
            ),
    );
  }

  Widget _buildNoRequestsState() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Text(
        'No active peek requests right now.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: peekWhiteColor.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildRequestState({
    required bool isProcessing,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.flash_auto,
            size: 120,
            color: peekWhiteColor.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Someone is Peeking you!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: peekWhiteColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Do you want to respond with a photo?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: peekWhiteColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: peekPrimaryColor,
              foregroundColor: peekSurfaceColor,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: isProcessing ? null : onAccept,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.blur_on),
            label: Text(isProcessing ? 'Processing...' : 'Accept & Take Photo'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: peekWhiteColor.withValues(alpha: 0.7)),
              foregroundColor: peekWhiteColor.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
            ),
            onPressed: isProcessing ? null : onDecline,
            icon: isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.close),
            label: Text(isProcessing ? 'Processing...' : 'Decline'),
          ),
        ],
      ),
    );
  }
}
