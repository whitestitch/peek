import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages user settings for photo capture
class UserSettingsManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User settings state
  bool _isSenderPremium = false;
  bool _senderSharesLocation = false;
  bool _senderAllowsLocationReveal = false;
  String? _senderDisplayName;
  String? _senderAvatarUrl;

  // Callbacks
  final VoidCallback? onSettingsLoaded;
  final ValueChanged<String>? onError;

  UserSettingsManager({
    this.onSettingsLoaded,
    this.onError,
  });

  // Getters
  bool get isSenderPremium => _isSenderPremium;
  bool get senderSharesLocation => _senderSharesLocation;
  bool get senderAllowsLocationReveal => _senderAllowsLocationReveal;
  String? get senderDisplayName => _senderDisplayName;
  String? get senderAvatarUrl => _senderAvatarUrl;

  /// Load user settings from Firestore
  Future<void> loadUserSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      onError?.call("User not authenticated");
      return;
    }

    try {
      debugPrint("[UserSettings] Loading settings for user: ${user.uid}");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint("[UserSettings] User document does not exist");
        onError?.call("User profile not found");
        return;
      }

      final data = userDoc.data();
      if (data == null) {
        debugPrint("[UserSettings] User document has no data");
        return;
      }

      // Update settings
      _isSenderPremium = data['isPremium'] as bool? ?? false;
      _senderSharesLocation = data['shareLocationPreference'] as bool? ?? false;
      _senderDisplayName = data['displayName'] as String?;
      _senderAvatarUrl = data['avatarUrl'] as String?;

      // Location preference handling
      // _senderAllowsLocationReveal =
      //     data['seeOthersLocationPreference'] as bool? ?? false;

      debugPrint(
          "[UserSettings] Settings loaded - Premium: $_isSenderPremium, Location: $_senderSharesLocation");
      onSettingsLoaded?.call();
    } catch (e) {
      debugPrint("[UserSettings] Error loading settings: $e");
      onError?.call("Failed to load user settings: $e");
    }
  }

  /// Check if user should share location
  bool shouldShareLocation() {
    return _senderSharesLocation;
  }

  /// Check if user has premium features
  bool hasPremiumFeatures() {
    return _isSenderPremium;
  }

  /// Get display name or fallback
  String getDisplayNameOrFallback() {
    return _senderDisplayName ?? "Anonymous";
  }

  /// Reset settings
  void reset() {
    _isSenderPremium = false;
    _senderSharesLocation = false;
    _senderAllowsLocationReveal = false;
    _senderDisplayName = null;
    _senderAvatarUrl = null;
  }
}
