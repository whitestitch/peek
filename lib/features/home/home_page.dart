import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? true;

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isAnonymous
                  ? 'Welcome to Peek 👀\nYou\'re browsing as a guest.'
                  : 'Welcome back, ${user?.email ?? "user"} 👑',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;

                try {
                  final now = DateTime.now(); // ✅ current timestamp
                  final expiresAt = now.add(
                    const Duration(seconds: 10),
                  ); // 10 seconds later

                  final docRef = await FirebaseFirestore.instance
                      .collection('peek_requests')
                      .add({
                        'from': uid,
                        'status': 'pending',
                        // Save readable timestamp
                        'createdAt': Timestamp.fromDate(now),
                        // Add expiry
                        'expiresAt': Timestamp.fromDate(expiresAt),
                      });

                  final requestId = docRef.id;

                  // Navigate to peeking page with requestId
                  context.go('/peek/$requestId');
                } catch (e) {
                  print('🔥 Peek creation failed: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to send peek request'),
                    ),
                  );
                }
              },
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
          ],
        ),
      ),
    );
  }
}
