// lib/features/home/home_page.dart
// lib/features/home/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart' as material;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:peek/core/feature_flags.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/features/home/providers/home_state_provider.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:peek/theme/colors.dart';
import 'package:rive/rive.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  Timer? _cooldownTimer;
  int? _secondsRemaining;

  @override
  void initState() {
    super.initState();
    material.WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkPromoModal();
        _checkIfPeekWasCancelled();
      }
    });
  }

  void _checkIfPeekWasCancelled() {
    // This method is called in initState's post-frame callback.
    final uri = GoRouterState.of(context).uri;
    if (uri.queryParameters['show'] == 'peekCancelled') {
      material.showModalBottomSheet(
        context: context,
        backgroundColor:
            material.Colors.transparent, // Make sheet background transparent
        isScrollControlled: true, // Allows custom height
        isDismissible: true, // Allow tap-to-dismiss
        builder: (context) {
          return material.Stack(
            alignment: material.Alignment.topCenter,
            children: [
              // The main content container with rounded corners
              material.Container(
                margin: const material.EdgeInsets.only(
                    top: 24), // Space for close button
                height: material.MediaQuery.of(context).size.height * 0.4,
                width: double.infinity,
                decoration: const material.BoxDecoration(
                  color: peekSurfaceColor,
                  borderRadius: material.BorderRadius.vertical(
                    top: material.Radius.circular(24),
                  ),
                ),
                padding: const material.EdgeInsets.all(24.0),
                child: const material.Column(
                  mainAxisAlignment: material.MainAxisAlignment.center,
                  children: [
                    material.Icon(
                      material.Icons.cancel_outlined,
                      size: 60,
                      color: material.Colors.white70,
                    ),
                    material.SizedBox(height: 20),
                    material.Text(
                      "Peek Canceled",
                      style: material.TextStyle(
                          fontSize: 24,
                          fontWeight: material.FontWeight.bold,
                          color: material.Colors.white),
                    ),
                    material.SizedBox(height: 8),
                    material.Text(
                      "The other user was not available to Peek.",
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                          fontSize: 16, color: material.Colors.white70),
                    ),
                  ],
                ),
              ),
              // Positioned Close Button
              material.Positioned(
                top: 24 + 8, // Position relative to the top of the Stack
                right: 12,
                child: material.IconButton(
                  icon: const material.Icon(material.Icons.close,
                      color: material.Colors.white54),
                  onPressed: () => material.Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _checkPromoModal() async {
    if (!FeatureFlags.showIntroScreens || !mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    if (currentLocation == '/terms' || currentLocation == '/onboarding') {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final bool onboardingComplete =
        prefs.getBool('onboardingComplete') ?? false;
    if (!onboardingComplete) {
      return;
    }

    final lastShown = prefs.getInt('upgradePromoLastShown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDaysInMillis = 7 * 24 * 60 * 60 * 1000;

    final bool isPremium =
        ref.read(homeStateProvider).asData?.value.isPremium ?? false;

    if ((now - lastShown > sevenDaysInMillis) && mounted && !isPremium) {
      await material.showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            const UpgradePromptDialog(reason: UpgradeReason.periodic),
      );
      if (mounted) await prefs.setInt('upgradePromoLastShown', now);
    }
  }

  Future<void> _attemptStartPeeking() async {
    ref.read(homeStateProvider.notifier).attemptStartPeeking(context);
  }

  Future<void> _debugResetLimits() async {
    ref.read(homeStateProvider.notifier).debugResetLimits();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _manageCooldownTimer(DateTime? cooldownEndTime) {
    // If a cooldown is active and no timer is running, start one.
    if (cooldownEndTime != null && cooldownEndTime.isAfter(DateTime.now())) {
      if (_cooldownTimer?.isActive ?? false) return; // Timer already running

      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final now = DateTime.now();
        if (now.isAfter(cooldownEndTime)) {
          timer.cancel();
          if (mounted) {
            setState(() => _secondsRemaining = null);
            ref.invalidate(homeStateProvider); // Refresh the state
          }
        } else {
          if (mounted) {
            setState(() {
              _secondsRemaining = cooldownEndTime.difference(now).inSeconds;
            });
          }
        }
      });
    } else {
      // If no cooldown is active, ensure any lingering timer is cancelled.
      if (_cooldownTimer != null) {
        _cooldownTimer?.cancel();
        _cooldownTimer = null;
        if (_secondsRemaining != null) {
          if (mounted) setState(() => _secondsRemaining = null);
        }
      }
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final homeStateAsync = ref.watch(homeStateProvider);
    // Note: isPeekingLoading is now handled inside the data builder for accuracy

    return material.Center(
      child: homeStateAsync.when(
        loading: () =>
            const material.CircularProgressIndicator(color: peekPrimaryColor),
        error: (e, _) => _buildErrorUI('Error loading user data.'),
        data: (state) {
          _manageCooldownTimer(state.cooldownEndTime);

          // Bridge state to local variables for UI clarity
          final isLoading = ref.watch(peekControllerProvider).isLoading;
          final isButtonEnabled = state.isButtonEnabled && !isLoading;
          final startButtonText = state.buttonText;
          final subtitleTextInBuild = state.subtitleText;
          final isPremiumForUI = state.isPremium;

          final bool isCooldownActive = state.cooldownEndTime != null;

          return material.SingleChildScrollView(
            child: material.Padding(
              padding: const material.EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 80.0,
              ),
              child: material.Column(
                mainAxisAlignment: material.MainAxisAlignment.center,
                mainAxisSize: material.MainAxisSize.min,
                children: [
                  _buildWelcomeArea(context, isPremiumForUI),
                  const material.SizedBox(height: 20),
                  material.Container(
                    height: 20,
                    alignment: material.Alignment.center,
                    child: material.Text(
                      subtitleTextInBuild,
                      textAlign: material.TextAlign.center,
                      style: material.TextStyle(
                        fontSize: 16,
                        fontWeight: material.FontWeight.w600,
                        color: isPremiumForUI
                            ? material.Colors.green.shade600
                            : material.Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.color
                                ?.withOpacity(0.9),
                      ),
                    ),
                  ),
                  const material.SizedBox(height: 10),
                  material.SizedBox(
                    width: 450,
                    height: 350,
                    child: material.Stack(
                      alignment: material.Alignment.center,
                      children: [
                        material.SizedBox(
                          width: 450,
                          height: 450,
                          child: RiveAnimation.asset(
                            'assets/animations/button_underline_effect.riv',
                            animations: const ['button_peek_effect'],
                            fit: material.BoxFit.contain,
                          ),
                        ),
                        material.SizedBox(
                          width: 230,
                          height: 230,
                          child: material.ElevatedButton(
                            onPressed:
                                isButtonEnabled ? _attemptStartPeeking : null,
                            style: material.ElevatedButton.styleFrom(
                              alignment: material.Alignment.center,
                              shape: const material.CircleBorder(),
                              padding: material.EdgeInsets.zero,
                              backgroundColor: isButtonEnabled
                                  ? peekSecondaryColor.withOpacity(0.1)
                                  : peekSurfaceColor.withOpacity(0.5),
                            ),
                            child: isLoading
                                ? const material.CircularProgressIndicator(
                                    color: material.Colors.white)
                                : isCooldownActive && _secondsRemaining != null
                                    ? material.Text(
                                        '$_secondsRemaining',
                                        key: const material.ValueKey(
                                            'cooldown_timer'),
                                        style: const material.TextStyle(
                                          fontSize: 34,
                                          fontWeight: material.FontWeight.w600,
                                        ),
                                      )
                                    : startButtonText == 'Limit Reached'
                                        ? material.Text(
                                            startButtonText,
                                            style: const material.TextStyle(
                                              fontSize: 22,
                                              fontWeight:
                                                  material.FontWeight.w600,
                                            ),
                                          )
                                        : material.Padding(
                                            padding:
                                                const material.EdgeInsets.all(
                                                    15),
                                            child: SvgPicture.asset(
                                              'assets/images/peekio_logo.svg',
                                            ),
                                          ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const material.SizedBox(height: 10),
                  if (!isPremiumForUI)
                    material.SizedBox(
                      width: double.infinity,
                      child: material.ElevatedButton.icon(
                        onPressed:
                            isLoading ? null : () => context.go('/premium'),
                        icon: const material.Icon(
                            material.Icons.star_purple500_outlined),
                        label: const material.Text('Upgrade to Premium'),
                        style: material.ElevatedButton.styleFrom(
                          backgroundColor: material.Colors.amber.shade600,
                          foregroundColor: material.Colors.black87,
                        ),
                      ),
                    ),
                  const material.SizedBox(height: 20),
                  if (kDebugMode)
                    material.Padding(
                      padding: const material.EdgeInsets.only(bottom: 20.0),
                      child: material.OutlinedButton.icon(
                        icon: const material.Icon(material.Icons.person_add,
                            color: material.Colors.greenAccent),
                        label: const material.Text("DEBUG: Create Test User",
                            style: material.TextStyle(
                                color: material.Colors.greenAccent)),
                        onPressed: () async {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({
                                'uid': user.uid,
                                'displayName':
                                    'Test User ${user.uid.substring(0, 6)}',
                                'createdAt': FieldValue.serverTimestamp(),
                                'isPremium': false,
                                'dailyPeekCount': 0,
                              });
                              material.ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const material.SnackBar(
                                  content: material.Text('Test user created!'),
                                  backgroundColor: material.Colors.green,
                                ),
                              );
                            } catch (e) {
                              material.ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                material.SnackBar(
                                  content: material.Text('Error: $e'),
                                  backgroundColor: material.Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        style: material.OutlinedButton.styleFrom(
                          side: const material.BorderSide(
                              color: material.Colors.greenAccent),
                        ),
                      ),
                    ),
                  material.SizedBox(
                    width: double.infinity,
                    child: material.OutlinedButton.icon(
                      onPressed:
                          isLoading ? null : () => context.go('/onboarding'),
                      icon: const material.Icon(material.Icons.slideshow),
                      label: const material.Text('View Tutorial'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  material.Widget _buildErrorUI(String message) {
    return material.Padding(
      padding: const material.EdgeInsets.all(30.0),
      child: material.Column(
        mainAxisAlignment: material.MainAxisAlignment.center,
        children: [
          const material.Icon(material.Icons.error_outline,
              color: material.Colors.redAccent, size: 40),
          const material.SizedBox(height: 16),
          material.Text(
            message,
            textAlign: material.TextAlign.center,
            style: const material.TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  material.Widget _buildWelcomeArea(
      material.BuildContext context, bool isPremium) {
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? true;

    if (isPremium && !isAnonymous) {
      return material.Row(
        mainAxisAlignment: material.MainAxisAlignment.center,
        children: [
          material.Text(
            'Welcome Back!',
            style: material.Theme.of(context).textTheme.headlineMedium,
          ),
          const material.SizedBox(width: 8),
          material.Chip(
            avatar: const material.Icon(material.Icons.star, size: 16),
            label: const material.Text('Premium'),
            backgroundColor: material.Colors.amber.shade600,
          ),
        ],
      );
    }

    String titleText = isPremium ? 'Welcome Back' : 'Welcome to Peekio!';
    String subtitleText = isPremium
        ? 'You\'re Browse as a premium'
        : 'You\'re Browse as a guest.';

    return material.Column(
      children: [
        material.Text(
          titleText,
          style: material.Theme.of(context).textTheme.headlineMedium,
        ),
        material.Padding(
          padding: const material.EdgeInsets.only(top: 10.0),
          child: material.Text(
            subtitleText,
            style: material.Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
