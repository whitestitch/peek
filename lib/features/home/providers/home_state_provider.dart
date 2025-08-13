// lib/features/home/providers/home_state_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/providers.dart';

import 'package:peek/features/peek/providers/peek_providers.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';

import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:peek/theme/colors.dart';

/// A simple, immutable class to hold the state of the HomePage.
@immutable
class HomeState {
  final bool isPremium;
  final bool isButtonEnabled;
  final String buttonText;
  final String subtitleText;
  final DateTime? cooldownEndTime;

  const HomeState({
    required this.isPremium,
    required this.isButtonEnabled,
    required this.buttonText,
    required this.subtitleText,
    this.cooldownEndTime,
  });
}

class HomeStateNotifier extends AutoDisposeAsyncNotifier<HomeState> {
  // Timer? _cooldownTimer;

  @override
  Future<HomeState> build() async {
    // Watch the real-time stream of the user's profile document. This will
    // automatically re-run the build method whenever the document is created
    // or changes.
    final userProfileAsyncValue = ref.watch(userDocumentProvider);

    // Use .when() to gracefully handle the different states of the stream.
    return userProfileAsyncValue.when(
      loading: () {
        // While the stream is initializing, keep the provider in a loading state.
        // We do this by returning a Future that never completes. The UI will show a spinner.
        debugPrint("[HomeState] Waiting for user profile stream to connect...");
        return Completer<HomeState>().future;
      },
      error: (err, stack) {
        // If the stream itself has an error, propagate it.
        debugPrint("[HomeState] Error from user profile stream: $err");
        throw err;
      },
      data: (userDoc) {
        // The stream has emitted data. Now we check if the document exists.
        if (userDoc == null || !userDoc.exists) {
          // This is the key part of the fix. If the document doesn't exist
          // yet, we don't throw an error. We wait patiently by keeping the
          // provider in a loading state. The stream will emit a new value
          // once the document is created, and this code will run again.
          debugPrint(
              "[HomeState] User document not yet available in stream. Waiting for creation...");
          return Completer<HomeState>().future;
        }

        // Success! The document exists. We can now build the real state.
        debugPrint("[HomeState] User document found. Building state.");
        return _buildStateFromData(userDoc.data()!);
      },
    );
  }

  HomeState _buildStateFromData(Map<String, dynamic> data) {
    final isPremium = (data['isPremium'] as bool? ?? false) ||
        (data['isSubscription'] as bool? ?? false);

    if (isPremium) {
      return const HomeState(
        isPremium: true,
        isButtonEnabled: true,
        buttonText: 'Start Peeking',
        subtitleText: 'Unlimited peeks available!',
      );
    }

    const dailyLimit = 3;
    const cooldown = Duration(seconds: 5);
    final now = DateTime.now();

    final lastPeekTime =
        (data['lastPeekRequestTimestamp'] as Timestamp?)?.toDate();
    if (lastPeekTime != null) {
      final cooldownEnd = lastPeekTime.add(cooldown);
      if (now.isBefore(cooldownEnd)) {
        // The provider's job is done. It just provides the end time.
        // The UI will handle the countdown animation.
        return HomeState(
          isPremium: false,
          isButtonEnabled: false,
          buttonText: '...', // The UI will show the countdown
          subtitleText: 'Please wait for cooldown.',
          cooldownEndTime: cooldownEnd, // Pass the end time
        );
      }
    }

    final lastResetTime = (data['peekCountLastReset'] as Timestamp?)?.toDate();
    final startOfToday = DateTime(now.year, now.month, now.day);
    int dailyCount = data['dailyPeekCount'] as int? ?? 0;
    if (lastResetTime == null || lastResetTime.isBefore(startOfToday)) {
      dailyCount = 0;
    }

    if (dailyCount >= dailyLimit) {
      return const HomeState(
          isPremium: false,
          isButtonEnabled: false,
          buttonText: 'Limit Reached',
          subtitleText: '🚫 Daily peek limit reached!');
    }

    final remainingPeeks = dailyLimit - dailyCount;
    return HomeState(
        isPremium: false,
        isButtonEnabled: true,
        buttonText: 'Start Peeking',
        subtitleText:
            'You have $remainingPeeks peek${remainingPeeks == 1 ? '' : 's'} left today.');
  }

  Future<void> attemptStartPeeking(material.BuildContext context) async {
    // DEBUG
    // DEBUG
    // DEBUG
    // THE FOLLOWING BLOCK IS BEING DELETED TO ALLOW ANONYMOUS USERS TO PROCEED.
    /*
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && currentUser.isAnonymous) {
      debugPrint(
          "[HomeState] Anonymous user attempted to peek. Showing upgrade prompt.");
      await material.showDialog(
        context: context,
        builder: (_) => const UpgradePromptDialog(
          // Using a specific reason for anonymous users.
          reason: UpgradeReason.anonymous,
        ),
      );
      return; // Stop execution here for anonymous users.
    }
    */

    // END DEBUG
    // END DEBUG
    // END DEBUG

    final userDoc = ref.read(userDocumentProvider).value;

    if (userDoc == null) {
      _showErrorSnackbar(context, 'User data not ready.');
      return;
    }

    if (state.value?.isPremium == false &&
        state.value?.buttonText == 'Limit Reached') {
      await material.showDialog(
          context: context,
          builder: (_) => const UpgradePromptDialog(
              reason: UpgradeReason.dailyLimitReached));
      return;
    }

    final needsReset = (userDoc.data()?['peekCountLastReset'] as Timestamp?)
            ?.toDate()
            ?.isBefore(DateTime(DateTime.now().year, DateTime.now().month,
                DateTime.now().day)) ??
        true;

    try {
      final requestId = await ref
          .read(peekControllerProvider.notifier)
          .createPeekRequestAndUpdateStats(needsDailyReset: needsReset);
      if (context.mounted && requestId != null) {
        // OPTIMISTIC UI UPDATE: Immediately set the state to cooldown
        // to prevent a flicker of the old state upon returning to this page.
        const cooldown =
            Duration(seconds: 5); // Ensure this matches the provider's logic
        state = AsyncValue.data(
          HomeState(
            isPremium:
                state.value?.isPremium ?? false, // Carry over premium status
            isButtonEnabled: false,
            buttonText:
                '...', // This text will be immediately replaced by the countdown timer in the UI
            subtitleText: 'Please wait for cooldown.',
            cooldownEndTime: DateTime.now().add(cooldown),
          ),
        );

        context.go('/wait?requestId=$requestId');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'An unexpected error occurred.');
    }
  }

  void _showErrorSnackbar(material.BuildContext context, String message) {
    if (!context.mounted) return;
    material.ScaffoldMessenger.of(context).removeCurrentSnackBar();
    material.ScaffoldMessenger.of(context).showSnackBar(
      material.SnackBar(
          content: material.Text(message), backgroundColor: peekErrorColor),
    );
  }

  Future<void> debugResetLimits() async {
    await ref.read(peekControllerProvider.notifier).debugResetUserLimits();
    ref.invalidate(userDocumentProvider);
  }
}

final homeStateProvider =
    AutoDisposeAsyncNotifierProvider<HomeStateNotifier, HomeState>(
  HomeStateNotifier.new,
);
