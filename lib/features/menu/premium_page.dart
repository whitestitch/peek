import 'package:flutter/material.dart';

class PeekPremiumPage extends StatelessWidget {
  const PeekPremiumPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('👑 Peek Premium')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upgrade to Peek Premium",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text("Unlock exclusive features:"),
            const SizedBox(height: 12),
            const ListTile(
              leading: Icon(Icons.bolt),
              title: Text("Peek without cooldown"),
            ),
            const ListTile(
              leading: Icon(Icons.remove_red_eye),
              title: Text("More peeks per day"),
            ),
            const ListTile(
              leading: Icon(Icons.timer),
              title: Text("Longer view duration"),
            ),
            const ListTile(
              leading: Icon(Icons.location_pin),
              title: Text("See location of peeks"),
            ),
            const ListTile(
              leading: Icon(Icons.chat),
              title: Text("Temporary chat (coming soon)"),
            ),
            const ListTile(
              leading: Icon(Icons.visibility_off),
              title: Text("See who peeked (optional)"),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  // TODO: Integrate subscription logic
                },
                icon: const Icon(Icons.workspace_premium),
                label: const Text("Upgrade to Premium"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
