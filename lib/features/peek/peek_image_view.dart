// lib/features/peek/peek_image_view.dart
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:peek/core/firestore_service.dart'; // To fetch user settings
import 'package:flutter_riverpod/flutter_riverpod.dart'; // To use FirestoreService provider
import 'package:peek/theme/colors.dart'; // Assuming your color theme

@immutable
class PeekImageView extends ConsumerStatefulWidget {
  final String requestId;
  final String imageUrl;

  const PeekImageView({
    super.key,
    required this.requestId,
    required this.imageUrl,
  });

  @override
  ConsumerState<PeekImageView> createState() => _PeekImageViewState();
}

class _PeekImageViewState extends ConsumerState<PeekImageView>
    with SingleTickerProviderStateMixin {
  static const String _feedbackTimestampKey = 'feedbackLastPromptTimestamp';
  static const Duration _feedbackPromptInterval = Duration(days: 7);

  // Receiver's settings
  bool _isReceiverPremium = false;
  bool _receiverWantsLocationReveal = false;
  // bool _receiverWantsSenderInfo = false;

  // Image state
  // Controls if the image UI (or loader/error) is shown
  bool _showImage = false;
  // True when Image.network has successfully decoded the image
  bool _imageActuallyLoaded = false;
  bool _imageLoadFailed = false;

  // Timers (only for non-premium)
  Timer? _viewTimer;
  int _viewDuration = 5;

  // Data from widget
  late final String _imageUrl;

  // Analytics
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  bool _viewStartedLogged = false;

  // Location data
  String? _senderLocation;
  String? _senderDisplayName;
  String? _senderAvatarUrl;

  String? _originalSenderId;

  // Tracks if receiver's settings have been fetched
  // Tracks if sender's location has been attempted to fetch
  bool _receiverSettingsLoaded = false;
  bool _peekDataFetched = false;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.imageUrl;
    _loadAllNecessaryData();
  }

  Future<void> _loadAllNecessaryData() async {
    await _loadReceiverSettings();
    // Fetch peek data regardless to get senderId for reporting/blocking
    // The display of sensitive info like location/name/avatar is still gated by premium status later.
    await _fetchPeekData();
    if (mounted) {
      _initiateImageDisplay();
    }
  }

  Future<void> _loadReceiverSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint(
          "[PeekImageView] User not logged in for receiver settings check.");
      if (mounted) {
        setState(() {
          _isReceiverPremium = false;
          _receiverWantsLocationReveal = false;
          _viewDuration = 5;
          _receiverSettingsLoaded = true;
        });
      }
      return;
    }

    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      // ASSUMPTION: getCurrentUserDocument() exists in FirestoreService
      final userDoc = await firestoreService.getCurrentUserDocument();

      bool isPremium = false;
      bool wantsReveal = false;
      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data();
        isPremium = data?['isPremium'] as bool? ?? false;
        wantsReveal = data?['seeOthersLocationPreference'] as bool? ?? false;
      }

      if (!mounted) return;
      setState(() {
        _isReceiverPremium = isPremium;
        _receiverWantsLocationReveal = wantsReveal;
        _viewDuration =
            _isReceiverPremium ? 99999 : 5; // Effectively infinite for premium
        _receiverSettingsLoaded = true;
        debugPrint(
            "[PeekImageView] Receiver Premium: $_isReceiverPremium, Wants Location Reveal: $_receiverWantsLocationReveal");
      });
    } catch (e) {
      debugPrint('⚠️ [PeekImageView] Failed to load receiver settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not verify your settings.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _isReceiverPremium = false;
          _receiverWantsLocationReveal = false;
          _viewDuration = 5;
          _receiverSettingsLoaded =
              true; // Mark as loaded even on error to proceed
        });
      }
    }
  }

  Future<void> _fetchPeekData() async {
    // This should only be called if _isReceiverPremium is true
    // if (!_isReceiverPremium) {
    //   if (mounted)
    //     setState(() => _peekDataFetched = true);
    //   return;
    // }
    debugPrint(
        "[PeekImageView] _fetchPeekData: Attempting to fetch data for requestId: ${widget.requestId}.");
    try {
      final peekDoc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      String? location;
      String? displayName;
      String? avatarUrl;
      String? fetchedSenderId;

      if (peekDoc.exists) {
        final data = peekDoc.data();
        debugPrint(
            "[PeekImageView] _fetchPeekData: Peek request document data: $data");

        fetchedSenderId = data?['senderId'] as String?;

        debugPrint(
            "[PeekImageView] _fetchPeekData: Fetched originalSenderId: $fetchedSenderId");

        // Fetch location if receiver wants it
        if (_isReceiverPremium) {
          if (_receiverWantsLocationReveal) {
            location = data?['senderLocation'] as String?;
            debugPrint(
                "[PeekImageView] _fetchPeekData: Fetched senderLocation (premium user): $location");
          } else {
            debugPrint(
                "[PeekImageView] _fetchPeekData: Receiver is premium but doesn't want location reveal for display.");
          }
          displayName = data?['senderDisplayName'] as String?;
          avatarUrl = data?['senderAvatarUrl'] as String?;
          debugPrint(
              "[PeekImageView] _fetchPeekData: Fetched senderDisplayName (premium user): $displayName, senderAvatarUrl (premium user): ${avatarUrl != null ? 'Present' : 'null'}");
        } else {
          debugPrint(
              "[PeekImageView] _fetchPeekData: Non-premium user. Specific sender details (location, name, avatar) for display on PeekImageView will not be used.");
        }
      } else {
        debugPrint(
            "[PeekImageView] _fetchPeekData: Peek request document ${widget.requestId} not found.");
      }

      if (mounted) {
        setState(() {
          // _originalSenderId is crucial for reactions and is set for ALL users.
          _originalSenderId = fetchedSenderId;

          // These are for display ON PeekImageView and are gated by premium status.
          if (_isReceiverPremium) {
            _senderLocation = location;
            _senderDisplayName = displayName;
            _senderAvatarUrl = avatarUrl;
          } else {
            // Explicitly ensure these are null for non-premium users for PeekImageView display
            _senderLocation = null;
            _senderDisplayName = null;
            _senderAvatarUrl = null;
          }
          _peekDataFetched =
              true; // Mark peek data fetching as attempted for all
          debugPrint(
              "[PeekImageView] _fetchPeekData: State updated. _originalSenderId: $_originalSenderId, _senderLocation (for display): $_senderLocation, _senderDisplayName (for display): $_senderDisplayName, _peekDataFetched: $_peekDataFetched");
        });
      }
    } catch (e) {
      debugPrint(
          "❌ [PeekImageView] _fetchPeekData: Error fetching data for ${widget.requestId}: $e");
      if (mounted) {
        setState(() {
          _peekDataFetched =
              true; // Mark as fetched even on error to unblock UI
          // _originalSenderId might still be null if doc wasn't found or senderId was missing in doc.
          debugPrint(
              "[PeekImageView] _fetchPeekData: State updated on error. _peekDataFetched: $_peekDataFetched, _originalSenderId: $_originalSenderId");
        });
      }
    }
  }

  void _initiateImageDisplay() {
    // This function is called after attempting to load all necessary data.
    if (!mounted) return;
    setState(() {
      _showImage = true; // Trigger UI to show image or its loading/error state
    });

    // Log peek view started event (only once per view)
    if (!_viewStartedLogged) {
      try {
        _analytics.logEvent(
          name: 'peek_view_started',
          parameters: {
            'request_id_partial': widget.requestId.length >= 8
                ? widget.requestId.substring(0, 8)
                : widget.requestId,
            'viewer_is_premium': _isReceiverPremium.toString(),
          },
        );
        _viewStartedLogged = true;
        debugPrint("[PeekImageView] Logged peek_view_started event.");
      } catch (e) {
        debugPrint("Error logging peek_view_started event: $e");
      }
    }

    // Start view timer only for non-premium users
    if (!_isReceiverPremium) {
      debugPrint("[PeekImageView] Non-premium user, starting view timer.");
      _startViewTimer();
    } else {
      debugPrint(
          "[PeekImageView] Premium user, image will stay visible (no view timer).");
    }
  }

  Future<void> _decideNextNavigation() async {
    if (!mounted) return;

    // It checks if the sender's ID was successfully fetched.
    if (_originalSenderId != null && _originalSenderId!.isNotEmpty) {
      debugPrint(
          "[PeekImageView] Navigating to Reaction Screen. RequestId: ${widget.requestId}, OriginalSenderUid: $_originalSenderId");

      // MODIFIED: Removed the imageUrl from the navigation parameters.
      context.go(
          '/peek-reaction?requestId=${widget.requestId}&originalSenderUid=$_originalSenderId');
    } else {
      // This is a fallback if the sender's ID couldn't be found for some reason.
      debugPrint(
          "[PeekImageView] _originalSenderId is null or empty. Navigating to home.");
      context.go('/'); // Fallback to home
    }

    // FEEDBAK TEPORY DISABLED
    // bool shouldShowFeedback = false;
    // try {
    //   final prefs = await SharedPreferences.getInstance();
    //   final lastPromptMillis = prefs.getInt(_feedbackTimestampKey) ?? 0;
    //   final nowMillis = DateTime.now().millisecondsSinceEpoch;
    //   if ((nowMillis - lastPromptMillis) >
    //       _feedbackPromptInterval.inMilliseconds) {
    //     shouldShowFeedback = true;
    //     await prefs.setInt(_feedbackTimestampKey, nowMillis);
    //   }
    // } catch (e) {
    //   debugPrint("Error with SharedPreferences for feedback: $e");
    // }

    // if (!mounted) return;
    // try {
    //   context.go(shouldShowFeedback
    //       ? '/peek-feedback?requestId=${widget.requestId}'
    //       : '/');
    // } catch (e) {
    //   debugPrint(
    //       "⚠️ [PeekImageView] Navigation failed in _decideNextNavigation: $e. Fallback to home.");
    //   if (mounted) context.go('/'); // Fallback
    // }
  }

  void _startViewTimer() {
    if (_isReceiverPremium) return; // Should not be called for premium
    _viewTimer?.cancel();
    _viewTimer = Timer(Duration(seconds: _viewDuration), () {
      if (!mounted) return;
      debugPrint("[PeekImageView] Non-premium view timer finished.");

      // Call setState to hide the image
      setState(() {
        _showImage = false;
      });

      // Defer navigation until after the current frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _decideNextNavigation();
        }
      });
    });
  }

  Future<void> _handleCloseAction() async {
    debugPrint("[PeekImageView] Close action initiated.");
    _viewTimer?.cancel(); // Stop timer if non-premium

    bool shouldHideImage = mounted && !_isReceiverPremium;

    if (shouldHideImage) {
      setState(() {
        _showImage = false; // Hide image for non-premium on close
      });
    }

    // Defer navigation until after the current frame is built,
    // especially if setState was called.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _decideNextNavigation();
      }
    });
  }

  @override
  void dispose() {
    debugPrint("[PeekImageView] Disposing.");
    _viewTimer?.cancel();
    super.dispose();
  }

  Future<void> _reportThisPeek() async {
    if (_originalSenderId == null || _originalSenderId!.isEmpty) {
      debugPrint(
          "[PeekImageView] Cannot report: Original Sender ID is missing.");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cannot report this Peek: sender unknown.")));
      return;
    }
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: peekSurfaceColor,
        title: const Text("Report Peek?",
            style: TextStyle(color: peekOnSurfaceColor)),
        content: const Text(
            "Are you sure you want to report this Peek for objectionable content? This action cannot be undone.",
            style: TextStyle(color: peekOnSurfaceColor)),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: peekOnSurfaceColor)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            child: Text("Report",
                style: TextStyle(color: Colors.redAccent.shade100)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final reporterId = FirebaseAuth.instance.currentUser?.uid;
        if (reporterId == null) throw Exception("Reporter not logged in");

        await firestoreService.addReport(
          peekRequestId: widget.requestId,
          reportedImageUrl: _imageUrl,
          reportedSenderId: _originalSenderId!,
          reporterId: reporterId,
          reason: "objectionable_content",
        );
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Peek reported. Thank you.")));
        context.go('/'); // Navigate home after reporting
      } catch (e) {
        debugPrint("❌ Error reporting Peek: $e");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to report Peek. Please try again.")));
      }
    }
    if (mounted) setState(() => _isProcessingAction = false);
  }

  Future<void> _blockThisSender() async {
    if (_originalSenderId == null || _originalSenderId!.isEmpty) {
      debugPrint(
          "[PeekImageView] Cannot block: Original Sender ID is missing.");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Cannot block this sender: sender unknown.")));
      return;
    }
    if (_isProcessingAction) return;
    setState(() => _isProcessingAction = true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: peekSurfaceColor,
        title: const Text("Block Sender?",
            style: TextStyle(color: peekOnSurfaceColor)),
        content: const Text(
            "Are you sure you want to block this sender? You will no longer receive Peeks from them.",
            style: TextStyle(color: peekOnSurfaceColor)),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: peekOnSurfaceColor)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          TextButton(
            child: Text("Block",
                style: TextStyle(color: Colors.redAccent.shade100)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final firestoreService = ref.read(firestoreServiceProvider);
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null)
          throw Exception("Current user not logged in");

        await firestoreService.blockUser(
            byUserId: currentUserId, userIdToBlock: _originalSenderId!);

        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Sender blocked successfully.")));
        context.go('/'); // Navigate home after blocking
      } catch (e) {
        debugPrint("❌ Error blocking sender: $e");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("Failed to block sender. Please try again.")));
      }
    }
    if (mounted) setState(() => _isProcessingAction = false);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if all prerequisite data for showing content has been loaded
    bool canShowContent = _receiverSettingsLoaded &&
        (_isReceiverPremium ? _peekDataFetched : true);

    debugPrint(
        "[PeekImageView] build(): canShowContent: $canShowContent (_receiverSettingsLoaded: $_receiverSettingsLoaded, _isReceiverPremium: $_isReceiverPremium, _receiverWantsLocationReveal: $_receiverWantsLocationReveal, _peekDataFetched: $_peekDataFetched)");
    debugPrint(
        "[PeekImageView] build(): _imageLoadFailed: $_imageLoadFailed, _showImage: $_showImage");

    Widget bodyContent;

    if (!canShowContent) {
      // Still loading initial settings or location data
      bodyContent =
          const Center(child: CircularProgressIndicator(color: Colors.white));
    } else if (_imageLoadFailed) {
      // Image loading failed state
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 60, color: Colors.redAccent),
              const SizedBox(height: 16),
              const Text('❌ Failed to load Peek',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      );
    } else if (_showImage) {
      bool shouldDisplayLocation = _isReceiverPremium &&
          _receiverWantsLocationReveal &&
          _senderLocation != null &&
          _senderLocation!.isNotEmpty &&
          _imageActuallyLoaded;

      String displayNameToShow = _senderDisplayName?.isNotEmpty ?? false
          ? _senderDisplayName!
          : "Someone";
      // Determine if the container should be shown (premium user & image loaded)
      bool showSenderInfoContainer = _isReceiverPremium && _imageActuallyLoaded;
      // Determine if the avatar URL is valid
      bool hasValidAvatar =
          _senderAvatarUrl != null && _senderAvatarUrl!.isNotEmpty;

      debugPrint(
          "[PeekImageView] build() location display conditions: _isReceiverPremium: $_isReceiverPremium, _receiverWantsLocationReveal: $_receiverWantsLocationReveal, _senderLocation: $_senderLocation, _imageActuallyLoaded: $_imageActuallyLoaded. RESULT: shouldDisplayLocation: $shouldDisplayLocation");
      debugPrint(
          "[PeekImageView] build() sender info display conditions: _isReceiverPremium: $_isReceiverPremium, _senderDisplayName: $_senderDisplayName, _imageActuallyLoaded: $_imageActuallyLoaded. RESULT: showSenderInfoContainer: $showSenderInfoContainer");

      // Image is being shown (or attempting to load)
      bodyContent = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _imageUrl,
            fit: BoxFit.cover,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              final bool isImageReady = frame != null;

              // Use addPostFrameCallback to schedule the state update after the build phase
              // This avoids calling setState during build, which is disallowed.
              // It handles both synchronous and asynchronous loads correctly.
              if (isImageReady && !_imageActuallyLoaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_imageActuallyLoaded) {
                    debugPrint(
                        "[PeekImageView] frameBuilder: Image frame is ready (frame index: $frame). Setting _imageActuallyLoaded = true");
                    setState(() {
                      _imageActuallyLoaded = true;
                    });
                  }
                });
              }

              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                onEnd: () {
                  if (frame != null && mounted) {
                    debugPrint(
                        "[PeekImageView] frameBuilder AnimatedOpacity.onEnd: Animation ended, frame available. Setting _imageActuallyLoaded = true");
                    setState(() {
                      _imageActuallyLoaded = true;
                    });
                  }
                },
                child: child,
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                // Image data has been received. frameBuilder will handle display.
                return child;
              }
              return const Center(
                  child: CircularProgressIndicator(color: Colors.white));
            },
            errorBuilder: (_, error, stackTrace) {
              debugPrint(
                  '❌ [PeekImageView] Image.network errorBuilder: $error');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _imageLoadFailed = true;
                    _showImage = false; // Trigger rebuild to show error state
                  });
                }
              });
              // Return a placeholder, error state will be built on next frame
              return const Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white30, size: 60));
            },
          ),

          // Close button for premium users
          if (_isReceiverPremium)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10, // Respect safe area
              right: 15,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: IconButton(
                  tooltip: 'Close Peek',
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.white,
                  onPressed: _handleCloseAction,
                ),
              ),
            ),

          // Display Sender Info Container (conditionally) - Placed Top Left
          // Display Sender Info Container (conditionally) - Placed Top Left
          if (showSenderInfoContainer)
            Positioned(
              top: MediaQuery.of(context).padding.top +
                  10, // Align with close button
              left: 15,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withOpacity(0.6), // Semi-transparent background
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, // Keep row tight
                  children: [
                    if (hasValidAvatar)
                      CircleAvatar(
                        radius: 12, // Small avatar
                        backgroundColor:
                            Colors.grey.shade700, // Fallback background
                        backgroundImage: NetworkImage(_senderAvatarUrl!),
                        onBackgroundImageError: (exception, stackTrace) {
                          debugPrint("Error loading sender avatar: $exception");
                          // Optionally, you could set a flag here to show the fallback icon
                          // if avatar loading fails, but CircleAvatar handles it gracefully.
                        },
                      )
                    else
                      Icon(
                        // Fallback icon if no avatar or error
                        Icons.person_outline_rounded,
                        color: peekWhiteColor.withOpacity(0.8),
                        size: 16,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      displayNameToShow, // Shows actual name or "Someone"
                      style: TextStyle(
                          color: peekWhiteColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(
                                blurRadius: 1.0,
                                color: Colors.black.withOpacity(0.7),
                                offset: const Offset(1, 1)),
                          ]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

          // Display Sender Location (conditionally)
          // Display Sender Location (conditionally)
          if (_isReceiverPremium &&
                  _receiverWantsLocationReveal &&
                  _senderLocation != null &&
                  _senderLocation!.isNotEmpty &&
                  _imageActuallyLoaded // Crucial: Only show when image is actually visible
              )
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom +
                  20, // Respect safe area
              left: 0,
              right: 0,
              child: Center(
                // Center the location container
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: peekWhiteColor.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _senderLocation!,
                          style: const TextStyle(
                            color: peekWhiteColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              //   ),

              // Positioned(
              //   top: MediaQuery.of(context).padding.top + 10,
              //   // Place it on the left if close button is on right, or adjust as needed
              //   left: (_isReceiverPremium)
              //       ? 60
              //       : 15, // Offset if close button is present
              //   child: CircleAvatar(
              //     radius: 18,
              //     backgroundColor: Colors.black.withOpacity(0.5),
              //     child: PopupMenuButton<String>(
              //       icon:
              //           const Icon(Icons.more_vert, color: Colors.white, size: 20),
              //       color: peekSurfaceColor, // Themed background for dropdown
              //       onSelected: (String value) {
              //         if (value == 'report') {
              //           _reportThisPeek();
              //         } else if (value == 'block') {
              //           _blockThisSender();
              //         }
              //       },
              //       itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              //         const PopupMenuItem<String>(
              //           value: 'report',
              //           child: ListTile(
              //             leading:
              //                 Icon(Icons.flag_outlined, color: peekOnSurfaceColor),
              //             title: Text('Report Peek',
              //                 style: TextStyle(color: peekOnSurfaceColor)),
              //           ),
              //         ),
              //         if (_originalSenderId != null &&
              //             _originalSenderId!
              //                 .isNotEmpty) // Only show block if sender ID is known
              //           const PopupMenuItem<String>(
              //             value: 'block',
              //             child: ListTile(
              //               leading: Icon(Icons.block_flipped,
              //                   color:
              //                       peekOnSurfaceColor), // consider Icons.person_remove_outlined
              //               title: Text('Block Sender',
              //                   style: TextStyle(color: peekOnSurfaceColor)),
              //             ),
              //           ),
              //       ],
              //     ),
              //   ),
            ),
        ],
      );
    } else {
      // Fallback / intermediate state (e.g., after non-premium timer, before navigation)
      // Or if _showImage became false for some other reason and not an error
      bodyContent =
          const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Scaffold(backgroundColor: Colors.black, body: bodyContent);
  }
}
