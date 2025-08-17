import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Manages user permissions and settings for image viewing
class UserPermissionsManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // User state
  bool _isReceiverPremium = false;
  bool _receiverSettingsLoaded = false;
  String? _senderDisplayName;
  String? _senderAvatarUrl;
  String? _originalSenderId;

  // Callbacks
  final VoidCallback? onSettingsLoaded;
  final ValueChanged<bool>? onPremiumStatusChanged;
  final ValueChanged<String>? onError;

  UserPermissionsManager({
    this.onSettingsLoaded,
    this.onPremiumStatusChanged,
    this.onError,
  });

  // Getters
  bool get isReceiverPremium => _isReceiverPremium;
  bool get receiverSettingsLoaded => _receiverSettingsLoaded;
  String? get senderDisplayName => _senderDisplayName;
  String? get senderAvatarUrl => _senderAvatarUrl;
  String? get originalSenderId => _originalSenderId;

  /// Load receiver's settings from Firestore
  Future<void> loadReceiverSettings() async {
    if (_receiverSettingsLoaded) return;

    final user = _auth.currentUser;
    if (user == null) {
      onError?.call("User not authenticated");
      return;
    }

    try {
      debugPrint(
          "[UserPermissions] Loading receiver settings for user: ${user.uid}");

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        debugPrint("[UserPermissions] User document does not exist");
        onError?.call("User profile not found");
        return;
      }

      final data = userDoc.data();
      if (data == null) {
        debugPrint("[UserPermissions] User document has no data");
        return;
      }

      final bool wasPremium = _isReceiverPremium;
      _isReceiverPremium = data['isPremium'] as bool? ?? false;
      _receiverSettingsLoaded = true;

      debugPrint(
          "[UserPermissions] Settings loaded - Premium: $_isReceiverPremium");

      // Notify if premium status changed
      if (wasPremium != _isReceiverPremium) {
        onPremiumStatusChanged?.call(_isReceiverPremium);
      }

      onSettingsLoaded?.call();
    } catch (e) {
      debugPrint("[UserPermissions] Error loading receiver settings: $e");
      onError?.call("Failed to load user settings: $e");
    }
  }

  /// Update sender information from peek data
  void updateSenderInfo({
    String? displayName,
    String? avatarUrl,
    String? senderId,
  }) {
    _senderDisplayName = displayName;
    _senderAvatarUrl = avatarUrl;
    _originalSenderId = senderId;

    debugPrint(
        "[UserPermissions] Sender info updated - Name: $displayName, ID: $senderId");
  }

  /// Check if user has premium features
  bool hasPremiumFeatures() {
    return _isReceiverPremium;
  }

  /// Check if user can perform premium actions
  bool canPerformAction(String action) {
    switch (action.toLowerCase()) {
      case 'unlimited_view':
      case 'no_timer':
      case 'extended_features':
        return _isReceiverPremium;
      case 'basic_view':
      case 'report':
      case 'block':
        return true; // Available to all users
      default:
        return false;
    }
  }

  /// Get user display preferences
  Map<String, dynamic> getDisplayPreferences() {
    return {
      'isPremium': _isReceiverPremium,
      'showPremiumFeatures': _isReceiverPremium,
      'showTimer': !_isReceiverPremium,
      'allowUnlimitedViewing': _isReceiverPremium,
    };
  }

  /// Get sender display name or fallback
  String getSenderDisplayName() {
    return _senderDisplayName ?? 'Someone';
  }

  /// Check if sender information is available
  bool hasSenderInfo() {
    return _originalSenderId != null;
  }

  /// Reset all user data
  void reset() {
    _isReceiverPremium = false;
    _receiverSettingsLoaded = false;
    _senderDisplayName = null;
    _senderAvatarUrl = null;
    _originalSenderId = null;
    debugPrint("[UserPermissions] User permissions reset");
  }

  /// Dispose resources
  void dispose() {
    // No resources to dispose for now
    debugPrint("[UserPermissions] UserPermissionsManager disposed");
  }
}
