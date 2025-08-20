// lib/features/settings/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:peek/features/premium/providers/premium_controller.dart';
import 'package:peek/core/firestore_service.dart'; // Import FirestoreService AND its provider
import 'package:peek/theme/colors.dart'; // Import colors
import 'package:flutter_svg/flutter_svg.dart';

// Provider for reading location sharing preference
final shareLocationPreferenceProvider = Provider<bool>((ref) {
  return false; // Placeholder default value
});

final seeOthersLocationPreferenceProvider = Provider<bool>((ref) {
  // Connect to user data provider when available
  return false; // Placeholder default
});

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _localLocationSharingEnabled = false;
  bool _isUpdatingPreference = false;
  // bool _localSeeOthersLocationEnabled = false;
  // bool _isUpdatingSeeOthersPreference = false;

  String? _currentDisplayName; // To store the fetched display name
  bool _isLoadingDisplayName = true; // Flag to show loading indicator initially
  bool _isUpdatingDisplayName = false; // Flag for saving new display name
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load initial preference state
    _loadInitialPreferences();
    // Initialize from user preferences when available
    // final initialPref = ref.read(userDataProvider).asData?.value?.data()?['shareLocationPreference'] ?? false;
    // _localLocationSharingEnabled = initialPref;
  }

  Future<void> _loadInitialPreferences() async {
    // This is a simplified way to load. Ideally, this comes from a user data stream/provider.
    try {
      final userDoc =
          await ref.read(firestoreServiceProvider).getCurrentUserDocument();
      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data();
        if (mounted) {
          setState(() {
            // For existing "Share My General Location"
            _localLocationSharingEnabled =
                data?['shareLocationPreference'] as bool? ?? false;

            // // Load preference for "Location Reveal" (seeing others' locations)
            // Load see others location preference
            // _localSeeOthersLocationEnabled =
            //     data?['seeOthersLocationPreference'] as bool? ?? false;

            _currentDisplayName = data?['displayName'] as String? ??
                "Anon"; // Use fetched name or fallback
            _displayNameController.text =
                _currentDisplayName!; // Set initial text for editing
            _isLoadingDisplayName = false; // Mark display name as loaded
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading initial preferences: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not load settings. Please try later.')),
        );
      }
    }
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

  Future<void> _updateLocationPreference(bool newValue) async {
    // This is for "Share My General Location"
    if (_isUpdatingPreference) return; // Use the correct state variable
    setState(() {
      _localLocationSharingEnabled = newValue;
      _isUpdatingPreference = false;
    });
    try {
      // ASSUMPTION: Your FirestoreService has 'updateUserLocationPreference'
      await ref
          .read(firestoreServiceProvider)
          .updateUserLocationPreference(newValue);
      debugPrint("[SettingsPage] Share Location preference update successful.");
    } catch (e) {
      debugPrint(
          "❌ [SettingsPage] Failed to update Share Location preference: $e");
      if (mounted) {
        setState(() {
          _localLocationSharingEnabled = !newValue;
        }); // Revert
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to save preference. Please try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPreference = false;
        }); // Use the correct state variable
      }
    }
  }

  Future<bool> _updateDisplayName(String newName) async {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      if (mounted) {
        // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name cannot be empty.')),
        );
      }
      return false;
    }
    if (_isUpdatingDisplayName) return false;

    setState(() => _isUpdatingDisplayName = true);
    bool success = false; // Variable to track success

    try {
      await ref
          .read(firestoreServiceProvider)
          .updateUserPreference({'displayName': trimmedName});
      debugPrint("[SettingsPage] Display name updated successfully.");
      if (mounted) {
        setState(() {
          _currentDisplayName = trimmedName; // Update local state on success
        });
        // REMOVED: Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated!')),
        );
        success = true; // Mark as successful
      }
    } catch (e) {
      debugPrint("❌ [SettingsPage] Failed to update display name: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to update name. Please try again.')),
        );
      }
      success = false; // Mark as failed
    } finally {
      if (mounted) {
        setState(() => _isUpdatingDisplayName = false);
      }
    }
    return success; // Return success status
  }

  void _showEditDisplayNameDialog() {
    // Ensure the controller has the latest name when opening the dialog
    _displayNameController.text = _currentDisplayName ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: peekSurfaceColor,
          title: const Text("Edit Display Name"),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width,
            child: TextField(
              controller: _displayNameController,
              autofocus: true,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: "Enter your display name",
                counterText: "",
                // 1. Add a white border to the input field
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: peekWhiteColor, width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: peekWhiteColor, width: 1.2),
                ),
              ),
            ),
          ),
          // 2. Align "Cancel" to the left and "Save" to the right
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: _isUpdatingDisplayName
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: peekNeutralColor,
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _displayNameController,
              builder: (context, value, child) {
                final bool canSave =
                    value.text.trim().isNotEmpty && !_isUpdatingDisplayName;
                return ElevatedButton(
                  onPressed: canSave
                      ? () async {
                          final success = await _updateDisplayName(
                              _displayNameController.text);
                          if (success && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        }
                      : null,
                  child: _isUpdatingDisplayName
                      ? const SizedBox(
                          width: 20,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: peekSurfaceColor,
                          ))
                      : const Text("Save"),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const String logoPath = 'assets/images/peekio_profile.png';
    final isPremium = ref
        .watch(premiumStatusProvider)
        .maybeWhen(data: (status) => status, orElse: () => false);
    // Use local state for now
    final bool currentPreference = _localLocationSharingEnabled;
    // For "Location Reveal" toggle
    // final bool currentSeeOthersPreference = _localSeeOthersLocationEnabled;
    final String displayName = _currentDisplayName ?? "Loading...";
    final theme = Theme.of(context);
    final listTilePadding = EdgeInsets.symmetric(
      horizontal: 16.0,
      vertical: 4.0,
    );

    final subtitleStyle = TextStyle(
      color: isPremium
          ? theme.textTheme.bodySmall?.color
              ?.withOpacity(0.7) // Slightly dimmer for premium
          : Colors.grey.shade700,
      fontSize: 12,
    );

    final sectionDivider = Divider(
      height: 1,
      thickness: 0.5,
      color: theme.dividerColor.withOpacity(0.5),
    );

    return Scaffold(
      backgroundColor: peekBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
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
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            alignment: Alignment.topCenter,
            child: SvgPicture.asset(
              'assets/images/peekio_logo.svg',
              height: 50,
              errorBuilder: (context, error, stackTrace) {
                debugPrint(
                    "Error loading settings logo: assets/images/peekio_logo.svg - $error");
                return const Icon(Icons.error_outline,
                    size: 40, color: Colors.redAccent);
              },
            ),
          ),
          // Subscription
          ListTile(
            contentPadding: listTilePadding,
            leading: Icon(
              Icons.badge_outlined,
              color: !isPremium ? peekNeutralColor : peekPrimaryColor,
              // color: peekPrimaryColor,
            ),
            title: const Text('Display Name'),
            subtitle: Column(
              // Use Column to stack name and info text
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingDisplayName)
                  const Text("Loading...",
                      style: TextStyle(color: peekNeutralColor))
                else
                  Text(
                    displayName,
                    style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withOpacity(0.9)),
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4), // Spacing between name and info text
                Text(
                  // Info text
                  isPremium
                      ? "Visible to premium users you peek. Tap edit to change."
                      : "Visible to premium users you peek.", // Non-premium cannot edit
                  style: subtitleStyle, // Use defined style
                ),
              ],
            ),
            trailing: isPremium // Only show edit button for premium users
                ? IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: peekWhiteColor,
                    ),
                    tooltip: "Edit Display Name",
                    onPressed: _isLoadingDisplayName || _isUpdatingDisplayName
                        ? null
                        : _showEditDisplayNameDialog, // Disable while loading/saving
                  )
                : null, // No edit button for non-premium
          ),
          // Optional: Loading indicator specifically for display name update
          if (_isUpdatingDisplayName)
            const Padding(
              padding:
                  EdgeInsets.only(bottom: 8.0), // Add padding below indicator
              child: Center(
                  child: SizedBox(
                      height: 15, width: 15, child: LinearProgressIndicator())),
            ),

          sectionDivider,

          SwitchListTile(
            contentPadding: listTilePadding,
            secondary: const Icon(
              Icons.my_location_rounded,
              color: peekPrimaryColor,
            ),
            title: const Text(
              'Share My General Location',
              // style: TextStyle(color: null), // Default color for all users
            ),
            subtitle: Text(
              "Allow others to see your general location (city or region) when they peek you.",
              style: subtitleStyle.copyWith(
                  color: theme.textTheme.bodySmall?.color
                      ?.withOpacity(0.7) // Consistent subtitle style
                  ),
            ),
            value: currentPreference, // Uses _localLocationSharingEnabled
            onChanged: _isUpdatingPreference
                ? null
                : _updateLocationPreference, // Calls the existing update method
            activeColor: theme.colorScheme.primary,
          ),
          if (_isUpdatingPreference)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Center(
                  child: SizedBox(
                      height: 15,
                      width: 15,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),

          sectionDivider,

          // About
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(
              Icons.info_outline_rounded,
              color: peekPrimaryColor,
            ),
            title: const Text('About Peek'),
            trailing: const Icon(
              Icons.chevron_right,
            ),
            onTap: () => context.go('/info'),
          ),

          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(
              Icons.rate_review_outlined,
              color: peekPrimaryColor,
            ),
            title: const Text('Rate Peek'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _requestReview,
          ),
          // Help
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(
              Icons.help_outline_rounded,
              color: peekPrimaryColor,
            ),
            title: const Text('Help & Contact Us'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _launchUrlHelper(
              Uri(
                scheme: 'mailto',
                path: 'support@peekio.app',
                queryParameters: {'subject': 'Peek App Support Request'},
              ),
            ),
          ),
          sectionDivider,
          // Privacy
          ListTile(
            contentPadding: listTilePadding,
            leading: const Icon(
              Icons.lock_outline_rounded,
              color: peekPrimaryColor,
            ),
            title: const Text('Privacy & Safety'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/privacy'),
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
