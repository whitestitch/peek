// lib/features/home/home_page.dart
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import 'package:peek/core/feature_flags.dart';
import '../menu/drawer_menu.dart';

final userDocProvider = StreamProvider<DocumentSnapshot<Map<String, dynamic>>>((
  ref,
) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('User not signed in');
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hasHitLimit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (FeatureFlags.showIntroScreens) {
        _maybeShowPromoModal();
      }
    });
  }

  Future<void> _maybeShowPromoModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('premiumModalLastShown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDays = 7 * 24 * 60 * 60 * 1000;

    if (now - lastShown > sevenDays && mounted) {
      await showDialog(
        context: context,
        builder: (_) => const UpgradePromptDialog(),
      );
      if (mounted) {
        await prefs.setInt('premiumModalLastShown', now);
      }
    }
  }

  Future<void> _startPeeking(bool isPremium) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();

    if (!isPremium) {
      final midnight = DateTime(now.year, now.month, now.day);
      final peekQuery =
          await FirebaseFirestore.instance
              .collection('peek_requests')
              .where('from', isEqualTo: uid)
              .where(
                'createdAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(midnight),
              )
              .orderBy('createdAt', descending: true)
              .get();

      final peekCount = peekQuery.docs.length;

      // Enforce the daily limit of 3 peeks.
      if (peekCount >= 3) {
        if (!mounted) return;

        final proceed =
            await showDialog<bool>(
              context: context,
              builder: (_) => const UpgradePromptDialog(),
            ) ??
            false;

        if (!proceed && mounted) {
          setState(() => _hasHitLimit = true);
          return;
        }
      }
    }

    try {
      final controller = ref.read(peekControllerProvider.notifier);
      final requestId = await controller.createPeekRequest(uid);
      if (requestId != null && mounted) {
        // Navigate to the waiting page so that the timer and timeout logic are active.
        context.go('/wait?requestId=$requestId');
      }
    } catch (e) {
      if (mounted) {
        print('🔥 Peek creation failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send peek request')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    final isAnonymous = user?.isAnonymous ?? true;

    // Using the current time to filter "today" – resets naturally at midnight.
    final now = DateTime.now();

    // Listen to user's peek_requests today for non-premium users.
    final peekCounterWidget =
        (!isAnonymous &&
                !user!.isAnonymous &&
                !ref.watch(userDocProvider).asData!.value.data()!['isPremium'])
            ? StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection('peek_requests')
                      .where('from', isEqualTo: uid)
                      .where(
                        'createdAt',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(
                          DateTime(now.year, now.month, now.day),
                        ),
                      )
                      .snapshots(),
              builder: (context, snapshot) {
                int peekCount = 0;
                if (snapshot.hasData) {
                  peekCount = snapshot.data!.docs.length;
                }
                final remaining = 3 - peekCount;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'You have $remaining peeks left today.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            )
            : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Peek Home'),
        actions: [
          if (isAnonymous)
            IconButton(
              icon: const Icon(Icons.upgrade),
              tooltip: 'Upgrade Account',
              onPressed: () => context.go('/upgrade'),
            )
          else
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                await FirebaseAuth.instance.signInAnonymously();
              },
            ),
        ],
      ),
      drawer: const DrawerMenu(),
      body: ref
          .watch(userDocProvider)
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading user: $e')),
            data: (doc) {
              final isPremium = doc.data()?['isPremium'] == true;
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isAnonymous
                          ? 'Welcome to Peek 👀\nYou\'re browsing as a guest.'
                          : isPremium
                          ? '👑 Premium unlocked. Enjoy unlimited peeking!'
                          : 'Welcome back, ${user?.email ?? "user"}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    // Show the real-time peek counter for non-premium users.
                    if (!isPremium) peekCounterWidget,
                    const SizedBox(height: 40),
                    if (_hasHitLimit && !isPremium)
                      const Text(
                        '🚫 Free peeks used up today.\nUpgrade to unlock more!',
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _startPeeking(isPremium),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Start Peeking'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/receive'),
                      icon: const Icon(Icons.radio),
                      label: const Text('Receiver Mode'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (!isPremium)
                      ElevatedButton.icon(
                        onPressed: () => context.go('/premium'),
                        icon: const Icon(Icons.star),
                        label: const Text('Upgrade to Premium'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
    );
  }
}
