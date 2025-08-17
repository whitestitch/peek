import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:peek/features/peek/image_view/image_display_manager.dart';
import 'package:peek/features/peek/image_view/view_timer_manager.dart';
import 'package:peek/features/peek/image_view/user_permissions_manager.dart';
import 'package:peek/features/peek/image_view/analytics_manager.dart';
import 'package:peek/features/peek/image_view/moderation_manager.dart';
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
  late final ModerationManager _moderationManager;

  // State
  bool _isInitialized = false;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
    _loadAllData();
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

    _moderationManager = ModerationManager(
      requestId: widget.requestId,
      onActionStarted: () => setState(() {}),
      onActionCompleted: () => setState(() {}),
      onError: _handleError,
      onSuccess: _handleSuccess,
    );
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
      final senderId = data['senderId'] as String?;

      _moderationManager.updateSenderId(senderId);

      // Fetch sender information if available
      if (senderId != null) {
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(senderId)
            .get();

        if (senderDoc.exists) {
          final senderData = senderDoc.data()!;
          _permissionsManager.updateSenderInfo(
            displayName: senderData['displayName'] as String?,
            avatarUrl: senderData['avatarUrl'] as String?,
            senderId: senderId,
          );
        }
      }
    } catch (e) {
      debugPrint("Error fetching peek data: $e");
      _handleError("Failed to load peek information");
    }
  }

  /// Handle image loaded successfully
  void _handleImageLoaded() {
    _analyticsManager.logImageLoaded();

    // Start analytics tracking
    _analyticsManager.logViewStarted(
      isPremium: _permissionsManager.isReceiverPremium,
      senderDisplayName: _permissionsManager.senderDisplayName,
    );

    // Start timer for non-premium users
    _timerManager.startViewTimer();

    setState(() {});
  }

  /// Handle image load failure
  void _handleImageFailed() {
    _analyticsManager.logImageLoadFailed(error: "Network error");
    setState(() {});
  }

  /// Handle image shown
  void _handleImageShown() {
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
    try {
      // Check if there are pending peek requests
      final pendingRequests = await FirebaseFirestore.instance
          .collection('peek_requests')
          .where('receiverId',
              isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (pendingRequests.docs.isNotEmpty && mounted) {
        // There are pending requests, go to home
        context.go('/');
      } else if (mounted) {
        // No pending requests, check for reaction screen
        final originalSenderId = _permissionsManager.originalSenderId;
        if (originalSenderId != null) {
          context.go(
              '/peek-reaction?requestId=${widget.requestId}&originalSenderUid=$originalSenderId');
        } else {
          context.go('/');
        }
      }
    } catch (e) {
      debugPrint("Error in navigation decision: $e");
      if (mounted) context.go('/');
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
    _imageManager.dispose();
    _timerManager.dispose();
    _permissionsManager.dispose();
    _analyticsManager.dispose();
    _moderationManager.dispose();
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

          // Loading overlay for actions
          if (_moderationManager.isProcessingAction)
            _buildActionLoadingOverlay(),
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
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          IconButton(
            onPressed: _handleCloseAction,
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
          ),

          // Sender info
          if (_permissionsManager.hasSenderInfo())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'From ${_permissionsManager.getSenderDisplayName()}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

          // More options
          IconButton(
            onPressed: () => _showMoreOptions(context),
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  /// Build bottom controls
  Widget _buildBottomControls() {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: _handleCloseAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Text(
              'Tap to continue',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build action loading overlay
  Widget _buildActionLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  /// Show more options menu
  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report, color: Colors.orange),
              title: const Text('Report Content',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _moderationManager.showReportDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _moderationManager.showBlockDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
