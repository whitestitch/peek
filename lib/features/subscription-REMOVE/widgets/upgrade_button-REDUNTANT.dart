import 'package:flutter/material.dart';
import '../subscription_service.dart';

class UpgradeButton extends StatefulWidget {
  const UpgradeButton({super.key});

  @override
  State<UpgradeButton> createState() => _UpgradeButtonState();
}

class _UpgradeButtonState extends State<UpgradeButton> {
  bool _loading = false;

  Future<void> _upgrade() async {
    setState(() => _loading = true);
    try {
      await SubscriptionService().upgradeToPremium();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("🎉 Upgraded to Premium!")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("❌ Failed: $e")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _loading ? null : _upgrade,
      child:
          _loading
              ? const CircularProgressIndicator()
              : const Text("Upgrade to Premium"),
    );
  }
}
