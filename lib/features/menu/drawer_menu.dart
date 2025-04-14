import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DrawerMenu extends StatelessWidget {
  const DrawerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.deepPurple.shade100),
              child: const Text(
                '☰ MENU',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('👑 Peek Premium'),
              onTap: () => context.go('/premium'),
            ),
            /*
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('🧭 My Stats'),
              onTap: () => context.go('/stats'),
            ),
            */
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('🔒 Privacy & Safety'),
              onTap: () => context.go('/privacy'),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('❓ About Peek'),
              onTap: () => context.go('/info'),
            ),
          ],
        ),
      ),
    );
  }
}
