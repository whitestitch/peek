import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UpgradePromptDialog extends StatelessWidget {
  const UpgradePromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('🎉 Unlock Peek Premium'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Upgrade to enjoy:'),
          SizedBox(height: 12),
          _Bullet(text: '✅ Unlimited Peeking'),
          _Bullet(text: '✅ No Cooldowns'),
          _Bullet(text: '✅ Longer Peek Duration'),
          _Bullet(text: '✅ Replay Feature'),
          _Bullet(text: '✅ And more...'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Maybe Later'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.star),
          label: const Text('Upgrade Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () {
            Navigator.of(context).pop(); // close dialog
            context.go('/premium'); // navigate to upgrade
          },
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text),
    );
  }
}
