import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('❓ About Peek'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "What is Peek?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "Peek is a spontaneous and anonymous way to see the world through someone else’s camera.",
            ),
            SizedBox(height: 8),
            Text("Built with privacy, safety, and simplicity in mind."),
            SizedBox(height: 24),
            Text("👀 One tap to request a peek."),
            Text("📸 Real-time photos from strangers worldwide."),
            Text("⏱️ Images disappear after a few seconds."),
            SizedBox(height: 24),
            Text("Made with ❤️ by White Stitch."),
          ],
        ),
      ),
    );
  }
}
