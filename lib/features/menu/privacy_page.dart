import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Safety'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '🔒 Peek respects your privacy. '
          'All interactions are anonymous, and images are deleted automatically after viewing.\n\n'
          'We never store or share your personal data.\n\n'
          'Enjoy the real-time magic, safely.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
