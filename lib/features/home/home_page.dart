import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peek/shared/upgrade_prompt_dialog.dart';
import '../menu/drawer_menu.dart';

// ✅ Riverpod stream for live user doc
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
  int _cooldownRemaining = 0;

  @override
  void initState() {
    super.initState();

    // 🧪 DEV ONLY: Force prompt for testing – REMOVE after confirming
    // SharedPreferences.getInstance().then((prefs) async {
    //   await prefs.clear(); // 💥 Clear all local keys
    // });

    _maybeShowPromoModal();
  }

  Future<void> _maybeShowPromoModal() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('premiumModalLastShown') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    const sevenDays = 7 * 24 * 60 * 60 * 1000;

    if (now - lastShown > sevenDays) {
      await showDialog(
        context: context,
        builder: (_) => const UpgradePromptDialog(),
      );
      await prefs.setInt('premiumModalLastShown', now);
    }
  }

  Future<void> _startPeeking(BuildContext context, bool isPremium) async {
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

      if (peekCount >= 3) {
        final proceed =
            await showDialog<bool>(
              context: context,
              builder: (_) => const UpgradePromptDialog(),
            ) ??
            false;

        if (!proceed) {
          setState(() => _hasHitLimit = true);
          return;
        }
      }

      final lastPeek =
          peekQuery.docs.isNotEmpty
              ? peekQuery.docs.first.data()['createdAt']?.toDate()
              : null;

      if (lastPeek != null && now.difference(lastPeek).inSeconds < 60) {
        final remaining = 60 - now.difference(lastPeek).inSeconds;
        setState(() => _cooldownRemaining = remaining);

        Future.delayed(Duration(seconds: remaining), () {
          setState(() => _cooldownRemaining = 0);
        });

        return;
      }
    }

    try {
      final expiresAt = now.add(const Duration(seconds: 10));
      final docRef = await FirebaseFirestore.instance
          .collection('peek_requests')
          .add({
            'from': uid,
            'status': 'pending',
            'createdAt': Timestamp.fromDate(now),
            'expiresAt': Timestamp.fromDate(expiresAt),
          });

      context.go('/peek/${docRef.id}');
    } catch (e) {
      print('🔥 Peek creation failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send peek request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;
    final userDocAsync = ref.watch(userDocProvider);

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
      body: userDocAsync.when(
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
                const SizedBox(height: 40),
                if (_cooldownRemaining > 0)
                  Text('⏳ Please wait $_cooldownRemaining seconds...')
                else if (_hasHitLimit && !isPremium)
                  const Text(
                    '🚫 Free peeks used up today.\nUpgrade to unlock more!',
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _startPeeking(context, isPremium),
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
