// lib/core/location_permission_helper.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:peek/core/firestore_service.dart';
import 'package:peek/theme/colors.dart';

/// Helper class for requesting location permission with proper context
/// Follows Apple's recommended just-in-time permission pattern
class LocationPermissionHelper {
  /// Show contextual location permission dialog before system prompt
  /// This is Apple-compliant as it:
  /// 1. Shows clear explanation of why permission is needed
  /// 2. Has "Continue" button (not "Enable")
  /// 3. No "Later" button - users proceed to system dialog
  /// 4. Users can still deny in the iOS system dialog
  static Future<bool> requestLocationPermissionWithContext({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    // Check if permission is already granted
    final currentPermission = await Geolocator.checkPermission();
    if (currentPermission == LocationPermission.whileInUse ||
        currentPermission == LocationPermission.always) {
      return true;
    }

    // Show contextual explanation modal
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: true, // User can tap outside to dismiss
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  peekBackgroundColor,
                  peekBackgroundColor.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: peekPrimaryColor.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: peekPrimaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 48,
                    color: peekPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  'Share Your Location',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: peekWhiteColor,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'When you send a Peek, your city will be visible to premium users. This helps them see where the glimpse comes from.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: peekWhiteColor.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: peekPrimaryColor,
                      foregroundColor: peekSurfaceColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Not Now Button (subtle)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: peekWhiteColor.withValues(alpha: 0.6),
                  ),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // If user dismissed or tapped "Not Now", return false
    if (shouldProceed != true) {
      return false;
    }

    // User tapped "Continue" - show system permission dialog
    try {
      final permission = await Geolocator.requestPermission();
      final locationEnabled = permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      // Update user's location preference in Firestore
      if (context.mounted) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserLocationPreference(locationEnabled);
      }

      return locationEnabled;
    } catch (e) {
      debugPrint(
          '❌ [LocationPermissionHelper] Error requesting permission: $e');
      return false;
    }
  }

  /// Check if location permission has been requested before
  static Future<bool> shouldShowLocationPermissionRequest() async {
    final permission = await Geolocator.checkPermission();
    // Show request if permission is not determined or denied (not permanently)
    return permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever;
  }
}
