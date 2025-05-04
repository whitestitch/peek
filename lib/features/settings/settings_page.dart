// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:peek/features/premium/providers/premium_controller.dart';
import 'package:peek/core/firestore_service.dart'; // Import FirestoreService AND its provider
import 'package:peek/theme/colors.dart'; // Import colors

// Provider for reading preference (Placeholder - see TODO)
final locationPreferenceProvider = Provider<bool>((ref) {
  // TODO: Replace this placeholder. Read from userDataProvider or a dedicated stream/future in FirestoreService.
  return false; // Placeholder default value
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _localLocationSharingEnabled = false;
  bool _isUpdatingPreference = false;

  @override
  void initState() {
    super.initState();
    // TODO: Load initial preference state here if needed
    // Example: Read from a snapshot if userDataProvider includes the field
    // final initialPref = ref.read(userDataProvider).asData?.value?.data()?['shareLocationPreference'] ?? false;
    // _localLocationSharingEnabled = initialPref;
  }

  // Helper: Launch URL
  Future<void> _launchUrlHelper(Uri url) async {
    // Removed context dependency here
    try {
      if (await canLaunchUrl(url)) {
        // Use function from url_launcher
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication,
        ); // Use function and enum
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      debugPrint("Error launching URL $url: $e");
      if (mounted) {
        // Check mounted before using context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: ${url.toString()}')),
        );
      }
    }
  }

  // Helper: Request Review
  Future<void> _requestReview() async {
    // Removed context dependency here
    try {
      final InAppReview inAppReview =
          InAppReview.instance; // Use type and instance
      if (await inAppReview.isAvailable()) {
        debugPrint("[SettingsPage] Requesting native review...");
        await inAppReview.requestReview();
      } else {
        debugPrint(
          "[SettingsPage] Native review not available, opening store listing...",
        );
        await inAppReview.openStoreListing(
          appStoreId: 'YOUR_APP_STORE_ID',
        ); // Replace ID
      }
    } catch (e) {
      debugPrint("Error requesting review: $e");
      if (mounted) {
        // Check mounted before using context
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open rating prompt.')),
        );
      }
    }
  }

  // Helper: Update Preference
  Future<void> _updateLocationPreference(bool newValue) async {
    if (_isUpdatingPreference) return;
    setState(() {
      _localLocationSharingEnabled = newValue;
      _isUpdatingPreference = true;
    });
    try {
      await ref
          .read(firestoreServiceProvider)
          .updateUserLocationPreference(newValue);
      debugPrint(
        "[SettingsPage] Location preference update successful via FirestoreService.",
      );
    } catch (e) {
      debugPrint("❌ [SettingsPage] Failed to update location preference: $e");
      if (mounted) {
        setState(() {
          _localLocationSharingEnabled = !newValue;
        }); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save preference. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPreference = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const String logoPath = 'assets/images/peekio.png';
    final isPremium = ref
        .watch(premiumStatusProvider)
        .maybeWhen(data: (status) => status, orElse: () => false);
    final bool currentPreference =
        _localLocationSharingEnabled; // Use local state for now
    final theme = Theme.of(context);
    final listTilePadding = const EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 4.0,
    );
    final sectionDivider = Divider(
      height: 1,
      thickness: 0.5,
      color: theme.dividerColor.withOpacity(0.5),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        elevation: 0,
        // backgroundColor: peekPrimaryColor,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        children: [
          // Avatar
          Container(
            padding: const EdgeInsets.symmetric(
                vertical: 40, horizontal: 20), // Adjusted padding
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 55, // Slightly larger radius for image

              // backgroundColor: theme.colorScheme.surface
              //     .withOpacity(0.8),
              backgroundColor: peekPrimaryColor,
              child: Padding(
                // Add padding inside the circle so logo isn't edge-to-edge
                padding: const EdgeInsets.all(15.0), // Adjust padding as needed
                child: Image.asset(
                  logoPath, // Use the defined logo path
                  fit: BoxFit.contain, // Ensure logo fits well
                  // Optional: Add color if your logo needs tinting on this background
                  // color: theme.colorScheme.primary,
                  errorBuilder: (context, error, stackTrace) {
                    debugPrint(
                        "Error loading settings logo: $logoPath - $error");
                    return const Icon(Icons.error_outline,
                        size: 40, color: Colors.redAccent); // Fallback icon
                  },
                ),
              ),
              // REMOVED: child: const Text('👀', style: TextStyle(fontSize: 50)),
            ),
          ),
          // Subscription
          ListTile(
            contentPadding: listTilePadding,
            leading: Icon(
              Icons.star_rounded,
              color: isPremium
                  ? Colors.amber
                  : theme.iconTheme.color?.withOpacity(0.6),
            ),
            title: Text(isPremium ? 'Premium Active' : 'Peek Premium'),
            subtitle: Text(
              isPremium ? 'Manage subscription' : 'Unlock all features',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/premium'),
          ),
          sectionDivider,
          // Location Preference
          SwitchListTile(
            contentPadding: listTilePadding,
            secondary: Icon(
              Icons.location_on_outlined,
              color: isPremium ? theme.iconTheme.color : Colors.grey.shade600,
            ),
            title: Text(
              'Share General Location',
              style: TextStyle(color: isPremium ? null : Colors.grey.shade600),
            ),
            subtitle: Text(
              'Show city/region during Peeks (Premium Only)',
              style: TextStyle(
                color: isPremium
                    ? theme.textTheme.bodySmall?.color
                    : Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
            value: isPremium ? currentPreference : false,
            onChanged: isPremium && !_isUpdatingPreference
                ? _updateLocationPreference
                : null,
            activeColor: theme.colorScheme.primary,
            inactiveThumbColor: isPremium ? null : Colors.grey.shade700,
            inactiveTrackColor: isPremium ? null : Colors.grey.shade800,
          ),
          if (_isUpdatingPreference)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Center(
                child: SizedBox(
                  height: 15,
                  width: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          sectionDivider,
          // Rate App
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(Icons.rate_review_outlined),
            title: const Text('Rate Peek'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _requestReview,
          ),
          // Help
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('Help & Contact Us'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrlHelper(
              Uri(
                scheme: 'mailto',
                path: 'support@peekapp.example.com',
                queryParameters: {'subject': 'Peek App Support Request'},
              ),
            ),
          ),
          sectionDivider,
          // Privacy
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Privacy & Safety'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/privacy'),
          ),
          // About
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About Peek'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/info'),
          ),
          sectionDivider,
          // Version
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20.0,
              horizontal: 16.0,
            ),
            child: Text(
              'App Version: 1.0.0 (Placeholder)',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
