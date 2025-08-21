import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:peek/features/peek/image_view/image_display_manager.dart';
import 'package:peek/features/peek/image_view/view_timer_manager.dart';
import 'package:peek/features/peek/image_view/user_permissions_manager.dart';
import 'package:peek/features/peek/image_view/analytics_manager.dart';
// ModerationManager import removed - no longer needed for report/block actions
import 'package:peek/theme/colors.dart';

@immutable
class PeekImageView extends ConsumerStatefulWidget {
  final String requestId;
  final String imageUrl;
  final String? senderLocation;

  const PeekImageView({
    super.key,
    required this.requestId,
    required this.imageUrl,
    this.senderLocation,
  });

  @override
  ConsumerState<PeekImageView> createState() => _PeekImageViewState();
}

class _PeekImageViewState extends ConsumerState<PeekImageView> {
  // Managers
  late final ImageDisplayManager _imageManager;
  late final ViewTimerManager _timerManager;
  late final UserPermissionsManager _permissionsManager;
  late final AnalyticsManager _analyticsManager;
  // ModerationManager removed - no longer needed for report/block actions

  // State
  bool _isInitialized = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
    _loadAllData();

    // Make status bar transparent for better edge spacing
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  /// Initialize all manager components
  void _initializeManagers() {
    _imageManager = ImageDisplayManager(
      imageUrl: widget.imageUrl,
      onImageLoaded: _handleImageLoaded,
      onImageFailed: _handleImageFailed,
      onImageShown: _handleImageShown,
      onError: _handleError,
    );

    _timerManager = ViewTimerManager(
      onTimerComplete: _handleTimerComplete,
      onTimerTick: (seconds) {
        setState(() => _remainingSeconds = seconds);
      },
      onTimerStarted: () => _analyticsManager.logTimerEvent(event: 'started'),
      onTimerStopped: () => _analyticsManager.logTimerEvent(event: 'cancelled'),
    );

    _permissionsManager = UserPermissionsManager(
      onSettingsLoaded: _handleSettingsLoaded,
      onPremiumStatusChanged: _handlePremiumStatusChanged,
      onError: _handleError,
    );

    _analyticsManager = AnalyticsManager(
      requestId: widget.requestId,
      imageUrl: widget.imageUrl,
      senderLocation: widget.senderLocation,
      onError: _handleError,
    );

    // ModerationManager initialization removed - no longer needed
  }

  /// Load all necessary data
  Future<void> _loadAllData() async {
    try {
      // Load user permissions first
      await _permissionsManager.loadReceiverSettings();

      // Fetch peek data for sender information
      await _fetchPeekData();

      // Initialize image display
      _imageManager.initiateImageDisplay();

      setState(() => _isInitialized = true);
    } catch (e) {
      _handleError("Initialization failed: $e");
    }
  }

  /// Fetch peek data from Firestore
  Future<void> _fetchPeekData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (!doc.exists) {
        _handleError("Peek request not found");
        return;
      }

      final data = doc.data()!;
      // FIX: Use 'senderId' field which contains the actual photo sender's UID
      // 'senderUid' field is corrupted and contains the reporter's UID
      String? senderId = data['senderId'] as String?;

      // FALLBACK: If senderId is null or corrupted (same as current user), try other fields
      if (senderId == null || senderId.isEmpty) {
        debugPrint(
            "[PeekImageView] senderId is null/empty, trying fallback fields...");

        // Try to find the actual sender from other fields
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final senderUid = data['senderUid'] as String?;
        final requesterUid = data['requesterUid'] as String?;

        // The actual sender should NOT be the current user (reporter)
        if (senderUid != null && senderUid != currentUserId) {
          senderId = senderUid;
          debugPrint("[PeekImageView] Using fallback senderUid: $senderId");
        } else if (requesterUid != null && requesterUid != currentUserId) {
          senderId = requesterUid;
          debugPrint("[PeekImageView] Using fallback requesterUid: $senderId");
        } else {
          debugPrint(
              "[PeekImageView] ⚠️ Could not determine correct sender ID");
        }
      }

      debugPrint("[PeekImageView] Final senderId for moderation: $senderId");
      debugPrint("[PeekImageView] DEBUG - Full peek data: $data");

      // ModerationManager.updateSenderId removed - no longer needed
      debugPrint("[PeekImageView] ✅ Sender ID identified: $senderId");

      // Use sender information from peek data instead of fetching from users collection
      // This avoids permission issues and uses data we already have
      if (senderId != null) {
        final senderDisplayName = data['senderDisplayName'] as String?;
        _permissionsManager.updateSenderInfo(
          displayName: senderDisplayName,
          avatarUrl: null, // Not available in peek data
          senderId: senderId,
        );

        debugPrint(
            "[PeekImageView] ✅ Sender info set from peek data: $senderDisplayName");
      }
    } catch (e) {
      debugPrint("Error fetching peek data: $e");
      // Don't show error to user - this is non-critical data
      // Just log it and continue with basic functionality
      debugPrint(
          "[PeekImageView] ⚠️ Non-critical error, continuing with basic functionality");

      // No fallback sender info available
      debugPrint("[PeekImageView] ⚠️ No fallback sender info available");
    }
  }

  /// Handle image loaded successfully
  void _handleImageLoaded() {
    _analyticsManager.logImageLoaded();
    setState(() {});
  }

  /// Handle image load failure
  void _handleImageFailed() {
    _analyticsManager.logImageLoadFailed(error: "Network error");
    setState(() {});
  }

  /// Handle image shown
  void _handleImageShown() {
    // Start analytics tracking
    _analyticsManager.logViewStarted(
      isPremium: _permissionsManager.isReceiverPremium,
      senderDisplayName: _permissionsManager.senderDisplayName,
    );

    // Start timer for non-premium users
    _timerManager.startViewTimer();

    setState(() {});
  }

  /// Handle settings loaded
  void _handleSettingsLoaded() {
    setState(() {});
  }

  /// Handle premium status change
  void _handlePremiumStatusChanged(bool isPremium) {
    _timerManager.updatePremiumStatus(isPremium);
    setState(() {});
  }

  /// Handle timer completion
  void _handleTimerComplete() {
    _analyticsManager.logTimerEvent(event: 'completed');
    _decideNextNavigation();
  }

  /// Handle close action
  Future<void> _handleCloseAction() async {
    _analyticsManager.logViewCompleted(reason: 'user_closed');
    _decideNextNavigation();
  }

  /// Decide next navigation based on app state
  Future<void> _decideNextNavigation() async {
    if (!mounted) return;

    // Simple check: if we have the sender ID, go to reaction screen
    final originalSenderId = _permissionsManager.originalSenderId;
    debugPrint(
        "[PeekImageView] Navigation decision - originalSenderId: $originalSenderId");

    if (originalSenderId != null && originalSenderId.isNotEmpty) {
      debugPrint(
          "[PeekImageView] Navigating to Reaction Screen. RequestId: ${widget.requestId}, OriginalSenderUid: $originalSenderId");

      context.go(
          '/peek-reaction?requestId=${widget.requestId}&originalSenderUid=$originalSenderId');
    } else {
      // Fallback if sender ID couldn't be found
      debugPrint(
          "[PeekImageView] OriginalSenderId is null or empty. Navigating to home.");

      // No fallback available - go to home
      debugPrint(
          "[PeekImageView] 🚨 No fallback sender ID available, going to home");
      context.go('/');
    }
  }

  /// Handle errors
  void _handleError(String error) {
    debugPrint("PeekImageView Error: $error");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: peekErrorColor,
        ),
      );
    }
  }

  /// Handle success messages
  void _handleSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Restore default system UI
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _imageManager.dispose();
    _timerManager.dispose();
    _permissionsManager.dispose();
    _analyticsManager.dispose();
    // ModerationManager.dispose() removed - no longer needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildLoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main image display
          _buildImageDisplay(),

          // Timer overlay (for non-premium users)
          if (_timerManager.shouldShowTimer()) _buildTimerOverlay(),

          // Top controls
          _buildTopControls(),

          // Bottom controls
          _buildBottomControls(),

          // Loading overlay for actions removed - no longer needed
        ],
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  /// Build main image display
  Widget _buildImageDisplay() {
    return Positioned.fill(
      child: _imageManager.buildImageWidget(
        fit: BoxFit.contain,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  /// Build timer overlay
  Widget _buildTimerOverlay() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Time remaining: ${_remainingSeconds}s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  /// Build top controls
  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - Sender name aligned left
          if (_permissionsManager.hasSenderInfo())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person,
                    color: peekWhiteColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _permissionsManager.getSenderDisplayName(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(width: 40),

          // Close button (X) - aligned right
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.black.withOpacity(0.4),
            child: IconButton(
              onPressed: _handleCloseAction,
              icon: const Icon(Icons.close, color: Colors.white, size: 24),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 60,
      left: 0,
      right: 0,
      child: Center(
        child: _buildLocationInfo(),
      ),
    );
  }

  /// Build location information (only for premium users)
  Widget _buildLocationInfo() {
    // Only show location for premium users and if location is available
    if (!_permissionsManager.isReceiverPremium ||
        widget.senderLocation == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.senderLocation!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Action loading overlay removed - no longer needed

  // Report/Block functionality removed - users should report from Reaction Screen
  // This prevents duplicate functionality and ensures users have time to complete actions
}
