// lib/features/home/providers/home_state_provider.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:peek/core/providers.dart';

import 'package:peek/features/peek/controllers/peek_controller.dart';

import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:peek/theme/colors.dart';

/// A simple, immutable class to hold the state of the HomePage.
@immutable
class HomeState {
  final bool isPremium;
  final bool isButtonEnabled;
  final String buttonText;
  final String subtitleText;
  final DateTime? cooldownEndTime;
  final bool isRestricted;
  final DateTime? restrictionEndTime;
  final String? restrictionReason;

  const HomeState({
    required this.isPremium,
    required this.isButtonEnabled,
    required this.buttonText,
    required this.subtitleText,
    this.cooldownEndTime,
    this.isRestricted = false,
    this.restrictionEndTime,
    this.restrictionReason,
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

        return _buildStateFromData(userDoc.data()!);
      },
    );
  }

  HomeState _buildStateFromData(Map<String, dynamic> data) {
    final isPremium = (data['isPremium'] as bool? ?? false) ||
        (data['isSubscription'] as bool? ?? false);

    // 🔧 NEW: Check if user is restricted
    final reputation = data['reputation'] as Map<String, dynamic>? ?? {};
    final userStatus = reputation['status'] as String? ?? 'normal';
    final isRestricted = userStatus == 'restricted';
    final restrictionReason =
        reputation['restrictionReason'] as String? ?? 'inappropriate content';

    // 🔧 NEW: Get restriction end time for countdown
    DateTime? restrictionEndTime;
    if (isRestricted) {
      final restrictionEndTimestamp =
          reputation['restrictionEndTime'] as Timestamp?;
      if (restrictionEndTimestamp != null) {
        restrictionEndTime = restrictionEndTimestamp.toDate();
      }
    }

    // If user is restricted, return restricted state
    if (isRestricted) {
      return HomeState(
        isPremium: isPremium,
        isButtonEnabled: false,
        buttonText: 'Banned',
        subtitleText: 'You are banned for inappropriate content',
        isRestricted: true,
        restrictionReason: restrictionReason,
        restrictionEndTime: restrictionEndTime,
      );
    }

    if (isPremium) {
      return const HomeState(
        isPremium: true,
        isButtonEnabled: true,
        buttonText: 'Start Peeking',
        subtitleText: 'Unlimited peeks available!',
        isRestricted: false,
      );
    }

    const dailyLimit = 3;
    const cooldown = Duration(seconds: 60);
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
          isRestricted: false,
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
          subtitleText: '🚫 Daily peek limit reached!',
          isRestricted: false);
    }

    final remainingPeeks = dailyLimit - dailyCount;
    return HomeState(
        isPremium: false,
        isButtonEnabled: true,
        buttonText: 'Start Peeking',
        subtitleText:
            'You have $remainingPeeks peek${remainingPeeks == 1 ? '' : 's'} left today.',
        isRestricted: false);
  }

  Future<void> attemptStartPeeking(material.BuildContext context) async {
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
            Duration(seconds: 60); // Ensure this matches the provider's logic
        state = AsyncValue.data(
          HomeState(
            isPremium:
                state.value?.isPremium ?? false, // Carry over premium status
            isButtonEnabled: false,
            buttonText:
                '...', // This text will be immediately replaced by the countdown timer in the UI
            subtitleText: 'Please wait for cooldown.',
            cooldownEndTime: DateTime.now().add(cooldown),
            isRestricted: false,
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
