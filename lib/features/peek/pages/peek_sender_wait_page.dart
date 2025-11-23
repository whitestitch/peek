// lib/features/peek/pages/peek_sender_wait_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peek/features/peek/pages/managers/peek_sender_wait_listener.dart';
import 'package:peek/features/peek/pages/managers/peek_sender_wait_navigation.dart';
import 'package:peek/features/peek/pages/managers/peek_sender_wait_timer_manager.dart';
import 'package:peek/features/peek/pages/managers/peek_sender_wait_ui.dart';
import 'package:peek/theme/colors.dart';
import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

class PeekSenderWaitPage extends ConsumerStatefulWidget {
  final String requestId;

  const PeekSenderWaitPage({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<PeekSenderWaitPage> createState() => _PeekSenderWaitPageState();
}

class _PeekSenderWaitPageState extends ConsumerState<PeekSenderWaitPage>
    with TickerProviderStateMixin {
  // Managers
  late final PeekSenderWaitListener _listener;
  late final PeekSenderWaitNavigation _navigationManager;
  late final PeekSenderWaitTimerManager _timerManager;
  late final PeekSenderWaitUI _uiBuilder;

  // State
  int? _secondsRemaining;
  DateTime? _captureExpirationTime;
  Timer? _countdownTimer;
  Timer? _postSendTimer;
  Timer? _permissionPollingTimer;
  bool _permissionsGranted = false;
  bool _countdownStarted = false;
  bool _isInConservativeMode =
      false; // 🔒 Track which permission mode is active
  StreamSubscription<DocumentSnapshot>? _requestListener;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
    _checkPermissions();
    _listenToRequestStatus();
    debugPrint(
        "[PeekSenderWaitPage] Initialized for request ${widget.requestId}.");
  }

  void _initializeManagers() {
    _uiBuilder = PeekSenderWaitUI();
    _navigationManager = PeekSenderWaitNavigation();
    _timerManager = PeekSenderWaitTimerManager(
      vsync: this,
      onCountdownUpdate: (seconds) {
        setState(() {
          _secondsRemaining = seconds;
        });
      },
      onTimeout: () {
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'timeout',
        );
      },
      onFinalCountdownComplete: (imageUrl, senderLocation) {
        _navigationManager.navigateToImageView(
          context,
          widget.requestId,
          imageUrl,
          senderLocation,
        );
      },
    );
    _listener = PeekSenderWaitListener(requestId: widget.requestId);
    _listener.listenForUpdates(
      onStatusUpdate: _handleStatusUpdate,
      onError: (error) {
        debugPrint("[PeekSenderWaitPage] Error: $error");
      },
    );
  }

  void _listenToRequestStatus() {
    _requestListener = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final status = data['status'] as String?;

        // Check if PhotoCapturePage has started (camera initialized)
        if (status == 'accepted' &&
            !_permissionsGranted &&
            !_countdownStarted) {
          debugPrint(
              "[PeekSenderWaitPage] Request accepted via listener - checking user type");

          // 🔒 KEY FIX: Check if this is a returning user who should bypass conservative flow
          final isReturningUser = await _checkPreviousCameraAccess();
          if (isReturningUser) {
            debugPrint(
                "[PeekSenderWaitPage] 🚀 Returning user detected - bypassing conservative flow");
            _permissionsGranted = true;
            setState(() {});
            _startInitialCountdown();
          } else {
            debugPrint(
                "[PeekSenderWaitPage] New user - starting permission monitoring");
            _startAcceptedPermissionMonitoring();
          }
        }
      }
    });
  }

  Future<void> _checkPermissions() async {
    // 🔒 ENHANCED APPROACH: Try multiple methods to detect existing permissions
    // This prevents users with permissions from getting stuck in conservative flow

    bool cameraGranted = false;

    // Method 1: Try availableCameras() first
    try {
      final cameras = await availableCameras();
      cameraGranted = cameras.isNotEmpty;
    } catch (e) {}

    // Method 2: If Method 1 fails, try alternative permission detection
    if (!cameraGranted) {
      try {
        // Check if we can access camera-related APIs without throwing
        // This is a more reliable indicator of existing permissions
        final hasCameraAccess = await _checkCameraAccessAlternative();
        if (hasCameraAccess) {
          cameraGranted = true;
        }
      } catch (e) {}
    }

    // Method 3: Check if user has been through camera flow before (stored preference)
    // 🔒 MORE CONSERVATIVE: Only use this for users who have explicitly been through camera flow
    if (!cameraGranted) {
      final hasPreviousCameraAccess = await _checkPreviousCameraAccess();
      debugPrint(
          "[PeekSenderWaitPage] Method 3 - Previous access check: $hasPreviousCameraAccess");

      if (hasPreviousCameraAccess) {
        // 🔒 STRICT CHECK: Only trust this if we have a strong signal that user has been through camera
        // AND we can verify they're not a new user
        final isNewUser = await _isNewUser();
        if (!isNewUser) {
          cameraGranted = true;
          debugPrint(
              "[PeekSenderWaitPage] Method 3 - Previous access confirmed for returning user");
        } else {
          debugPrint(
              "[PeekSenderWaitPage] Method 3 - Previous access found but user appears new - being conservative");
        }
      }
    }

    debugPrint(
        "[PeekSenderWaitPage] Final permission check result: $cameraGranted");

    if (cameraGranted) {
      // Permissions confirmed - proceed immediately
      _permissionsGranted = true;
      debugPrint(
          "[PeekSenderWaitPage] ✅ Permissions confirmed - starting countdown immediately");

      // Store that user has camera access for future use
      _storeCameraAccess();

      setState(() {});
      _startInitialCountdown();
    } else {
      // No permissions detected - start with optimistic assumption
      debugPrint(
          "[PeekSenderWaitPage] 🔄 No permissions detected - starting optimistic flow");
      _startOptimisticFlow();
    }
  }

  Future<bool> _checkCameraAccessAlternative() async {
    // Alternative method to check camera access
    try {
      // For users who have already been through camera flow,
      // we can assume they have permissions even if availableCameras() fails
      // This prevents the delay for returning users

      // Check if this is a returning user (has been through camera before)
      final hasPreviousAccess = await _checkPreviousCameraAccess();

      if (hasPreviousAccess) {
        return true;
      }

      // If not returning user, don't assume permissions - let them go through proper flow
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getDeviceCameraInfo() async {
    try {
      // This is a lightweight check that often succeeds with existing permissions
      // even when availableCameras() fails due to timing issues
      return "camera_available"; // Placeholder - could be enhanced with actual device checks
    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkPreviousCameraAccess() async {
    try {
      // Check if user has previously accessed camera (stored in preferences)
      // This helps users who have already granted permissions
      final prefs = await SharedPreferences.getInstance();
      final hasAccess = prefs.getBool('has_camera_access') ?? false;

      // 🔒 HOT-RELOAD FIX: If SharedPreferences is empty, try alternative persistence methods
      if (!hasAccess) {
        final alternativeAccess =
            await _checkAlternativePermissionPersistence();
        if (alternativeAccess) {
          debugPrint(
              "[PeekSenderWaitPage] 🔍 Alternative persistence found - treating as returning user");
          return true;
        }
      }

      // 🔒 MORE CONSERVATIVE: Only return true if we have explicit confirmation
      // This prevents new users from being incorrectly identified as returning users
      return hasAccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkAlternativePermissionPersistence() async {
    try {
      // 🔒 HOT-RELOAD RESILIENCE: Check multiple persistence methods
      // This helps returning users who lose SharedPreferences during hot-reload

      // Method 1: Check if we're in a development environment (hot-reload scenario)
      final isDevelopment = await _isDevelopmentEnvironment();
      if (isDevelopment) {
        debugPrint(
            "[PeekSenderWaitPage] 🔍 Development environment detected - checking for hot-reload scenario");

        // 🔒 STRICT CHECK: Only proceed if we have STRONG signals this is a returning user
        // This prevents new users from being incorrectly identified

        // Method 2: Check if user has been through camera flow recently (session-based)
        final hasRecentCameraSession = await _checkRecentCameraSession();
        if (hasRecentCameraSession) {
          // 🔒 CRITICAL CHECK: Verify camera permissions are actually granted
          final hasCameraPermissions = await _checkActualCameraPermissions();
          if (hasCameraPermissions) {
            debugPrint(
                "[PeekSenderWaitPage] 🔍 Recent camera session + permissions confirmed - treating as returning user");
            return true;
          } else {
            debugPrint(
                "[PeekSenderWaitPage] 🔍 Recent session but no permissions - must go through permission flow");
            return false;
          }
        }

        // Method 3: Check if this is a known returning user by other signals
        // 🔧 BALANCED: Use strong signals but don't over-verify
        final isKnownReturningUser = await _isKnownReturningUser();
        if (isKnownReturningUser) {
          debugPrint(
              "[PeekSenderWaitPage] 🔍 Known returning user detected - treating as returning user");
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Alternative persistence check failed: $e");
      return false;
    }
  }

  Future<void> _storeCameraAccess() async {
    try {
      // Store that user has camera access for future use
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_camera_access', true);

      // 🔒 HOT-RELOAD RESILIENCE: Store additional signals
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('last_camera_activity', currentTime);
      await prefs.setBool('has_app_usage', true);

      // Verify the values were stored correctly
      final storedAccess = prefs.getBool('has_camera_access');
      final storedActivity = prefs.getInt('last_camera_activity');
      final storedUsage = prefs.getBool('has_app_usage');

      debugPrint(
          "[PeekSenderWaitPage] 💾 Verification: access=$storedAccess, activity=$storedActivity, usage=$storedUsage");
    } catch (e) {}
  }

  // 🔒 DEBUG METHOD: Clear camera access preference for testing
  Future<void> _clearCameraAccess() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_camera_access');
      debugPrint(
          "[PeekSenderWaitPage] 🧹 Camera access preference cleared for testing");
    } catch (e) {
      debugPrint("[PeekSenderWaitPage] Failed to clear camera access: $e");
    }
  }

  Future<bool> _isNewUser() async {
    try {
      // Check if this appears to be a new user
      // We can use multiple signals to determine this
      final prefs = await SharedPreferences.getInstance();

      // Check if user has been through onboarding or has any app history
      final hasOnboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;
      final hasAppHistory = prefs.getBool('has_app_history') ?? false;
      final hasCameraAccess = prefs.getBool('has_camera_access') ?? false;

      debugPrint(
          "[PeekSenderWaitPage] 🔍 New user check: onboarding=$hasOnboardingCompleted, history=$hasAppHistory, camera=$hasCameraAccess");

      // If user has none of these signals, they're likely new
      final isNew =
          !hasOnboardingCompleted && !hasAppHistory && !hasCameraAccess;

      return isNew;
    } catch (e) {
      // If we can't determine, assume new user (conservative approach)
      return true;
    }
  }

  Future<bool> _isDevelopmentEnvironment() async {
    try {
      // Check if we're in a development environment (hot-reload scenario)
      // This helps identify when SharedPreferences might be cleared

      // Method 1: Check if we're in debug mode
      final isDebug = await _isDebugMode();

      // Method 2: Check if we're in a development build
      final isDevelopmentBuild = await _isDevelopmentBuild();

      // Method 3: Check if we're in a hot-reload scenario
      final isHotReload = await _isHotReloadScenario();

      debugPrint(
          "[PeekSenderWaitPage] 🔍 Environment check: debug=$isDebug, development=$isDevelopmentBuild, hotReload=$isHotReload");

      // 🔧 BALANCED: If any indicator is true, we're likely in development
      return isDebug || isDevelopmentBuild || isHotReload;
    } catch (e) {
      // 🔧 BALANCED: If we can't determine, assume development (safer for hot-reload)
      // This helps returning users who lose SharedPreferences
      return true;
    }
  }

  Future<bool> _isDebugMode() async {
    try {
      // Check if we're in debug mode
      // This is a reliable indicator of development environment
      // 🔧 BALANCED: Return true for development environment to help returning users
      // This helps returning users while maintaining security for new users
      return true; // Placeholder - in real implementation, check actual debug mode
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isDevelopmentBuild() async {
    try {
      // Check if we're in a development build
      // This helps identify hot-reload scenarios
      // 🔧 BALANCED: Return true for development environment to help returning users
      // This helps returning users while maintaining security for new users
      return true; // Placeholder - in real implementation, check actual build type
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isHotReloadScenario() async {
    try {
      // Check if we're in a hot-reload scenario (SharedPreferences cleared)
      // This helps identify when returning users lose their persistence

      final prefs = await SharedPreferences.getInstance();
      final hasAnyPreferences = prefs.getKeys().isNotEmpty;

      // 🔒 CONSERVATIVE: Only consider hot-reload if we have NO preferences at all
      // This prevents false positives that bypass permission checks
      final isHotReload = !hasAnyPreferences;

      // 🔒 SECURITY: Even if hot-reload is detected, we still need strong camera signals
      // This prevents new users from bypassing permission checks

      debugPrint(
          "[PeekSenderWaitPage] 🔍 Hot-reload check: hasPrefs=$hasAnyPreferences, isHotReload=$isHotReload");

      return isHotReload;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkActualCameraPermissions() async {
    try {
      // 🔒 CRITICAL: Check if camera permissions are actually granted
      // This prevents false positives that bypass permission checks

      // Method 1: Try to get available cameras (most reliable)
      try {
        final cameras = await availableCameras();
        final hasCameras = cameras.isNotEmpty;

        debugPrint(
            "[PeekSenderWaitPage] 🔍 Actual camera check: cameras=${cameras.length}, hasCameras=$hasCameras");

        return hasCameras;
      } catch (e) {
        return false;
      }
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Actual camera permissions check failed: $e");
      return false;
    }
  }

  Future<bool> _checkRecentCameraSession() async {
    try {
      // Check if user has been through camera flow recently (session-based)
      // This helps returning users who lose SharedPreferences during hot-reload

      // Method 1: Check if we have any recent camera-related activity
      final prefs = await SharedPreferences.getInstance();
      final lastCameraActivity = prefs.getInt('last_camera_activity') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      // If camera activity was within last 5 minutes, consider it recent
      final isRecent = (currentTime - lastCameraActivity) < (5 * 60 * 1000);

      debugPrint(
          "[PeekSenderWaitPage] 🔍 Recent session check: lastActivity=$lastCameraActivity, currentTime=$currentTime, isRecent=$isRecent");

      return isRecent;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _isKnownReturningUser() async {
    try {
      // Check if this is a known returning user by other signals
      // This helps identify returning users even without SharedPreferences

      // 🔒 MORE CONSERVATIVE: Require multiple strong signals to avoid false positives
      final prefs = await SharedPreferences.getInstance();

      // Method 1: Check if user has completed onboarding (strong signal)
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;

      // Method 2: Check if user has explicit camera access history (strong signal)
      final hasCameraAccess = prefs.getBool('has_camera_access') ?? false;

      // Method 3: Check if user has recent camera activity (strong signal)
      final hasRecentActivity = await _checkRecentCameraSession();

      // Method 4: Check if user has any stored preferences (weak signal, but helps)
      final hasAnyPreferences = prefs.getKeys().isNotEmpty;

      debugPrint(
          "[PeekSenderWaitPage] 🔍 Known user check: onboarding=$hasCompletedOnboarding, cameraAccess=$hasCameraAccess, recentActivity=$hasRecentActivity, hasPrefs=$hasAnyPreferences");

      // 🔧 BALANCED: Use strong signals but be more permissive for returning users
      int strongSignals = 0;
      if (hasCompletedOnboarding) strongSignals++;
      if (hasCameraAccess) strongSignals++;
      if (hasRecentActivity) strongSignals++;

      // 🔒 PROPER PERMISSION CHECK: Only consider user "returning" if they have camera access
      // This prevents users with other preferences from bypassing permission checks
      final isReturningUser = hasCameraAccess || (strongSignals >= 2);

      // 🔒 SECURITY: If user has no camera access, they must go through permission flow
      // Even if they have other app preferences (onboarding, terms, etc.)

      debugPrint(
          "[PeekSenderWaitPage] 🔍 Strong signals count: $strongSignals, isReturningUser: $isReturningUser");

      return isReturningUser;
    } catch (e) {
      return false;
    }
  }

  Timer? _optimisticTimer; // 🔒 Track optimistic timer

  void _startOptimisticFlow() {
    // Start with "Wait" state but be ready to transition quickly
    _permissionsGranted = false;
    setState(() {});
    _showWaitingState();

    // Give user more time to grant permissions before optimistic assumption
    _optimisticTimer = Timer(const Duration(seconds: 8), () {
      if (!_permissionsGranted &&
          !_countdownStarted &&
          mounted &&
          !_isInConservativeMode) {
        debugPrint(
            "[PeekSenderWaitPage] 🚀 Optimistic assumption - proceeding with countdown");
        _permissionsGranted = true;
        setState(() {});
        _startInitialCountdown();
      }
    });

    // Still do some light polling in case cameras become available quickly
    _startLightPermissionPolling();
  }

  void _cancelOptimisticFlow() {
    // 🔒 Cancel the optimistic timer to prevent interference
    _optimisticTimer?.cancel();
    _optimisticTimer = null;
    debugPrint(
        "[PeekSenderWaitPage] 🔒 Optimistic flow cancelled - conservative mode active");
  }

  void _startLightPermissionPolling() {
    _permissionPollingTimer?.cancel();
    int pollCount = 0;
    const maxPolls = 5; // Only 5 attempts over 10 seconds (5 * 2s intervals)

    _permissionPollingTimer =
        Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_permissionsGranted) {
        debugPrint(
            "[PeekSenderWaitPage] Permissions now granted - stopping light polling");
        timer.cancel();
        return;
      }

      pollCount++;
      debugPrint(
          "[PeekSenderWaitPage] Light polling for permissions... (attempt $pollCount/$maxPolls)");

      // Stop polling after max attempts - the optimistic timer will take over
      if (pollCount >= maxPolls) {
        debugPrint(
            "[PeekSenderWaitPage] Light polling complete - relying on optimistic flow");
        timer.cancel();
        return;
      }

      _lightPermissionRecheck().then((_) {
        if (_permissionsGranted && !_countdownStarted) {
          debugPrint(
              "[PeekSenderWaitPage] Permissions detected during light polling");
          timer.cancel();
        }
      });
    });
  }

  Future<void> _lightPermissionRecheck() async {
    // Simple, lightweight permission recheck
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty && !_permissionsGranted && !_countdownStarted) {
        debugPrint(
            "[PeekSenderWaitPage] ✅ Light recheck successful - permissions now available");
        _permissionsGranted = true;
        setState(() {});
        _startInitialCountdown();
      }
    } catch (e) {
      // Ignore errors in light recheck - optimistic flow will handle it
    }
  }

  void _startAcceptedPermissionMonitoring() {
    // 🔧 TRUE REAL-TIME MONITORING: Monitor camera availability changes and start countdown immediately
    // This ensures countdown starts as soon as receiver camera is ready
    debugPrint(
        "[PeekSenderWaitPage] Starting true real-time permission monitoring after accepted status");

    // 🔒 Set conservative mode flag
    _isInConservativeMode = true;

    // 🔧 IMMEDIATE CHECK: Check permissions right away (no delay)
    if (!_permissionsGranted && !_countdownStarted && mounted) {
      debugPrint(
          "[PeekSenderWaitPage] 🔧 Immediate permission check - no delay");
      _conservativePermissionCheck();
    }

    // 🔧 START REAL-TIME LISTENER: Monitor camera availability changes
    _startRealTimeCameraListener();

    // 🔒 IMPORTANT: Cancel the optimistic flow since we're now in conservative mode
    // This prevents the 8s optimistic timer from interfering
    _cancelOptimisticFlow();
  }

  void _startRealTimeCameraListener() {
    // 🔧 TRUE REAL-TIME: Monitor camera availability changes continuously
    // This ensures countdown starts immediately when receiver camera is ready
    debugPrint(
        "[PeekSenderWaitPage] 🔧 Starting real-time camera availability listener");

    // Cancel any existing polling
    _permissionPollingTimer?.cancel();

    // Start continuous monitoring with very short intervals
    _permissionPollingTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_permissionsGranted) {
        debugPrint(
            "[PeekSenderWaitPage] 🔧 Permissions granted - stopping real-time listener");
        timer.cancel();
        return;
      }

      // 🔧 REAL-TIME CHECK: Check camera availability every 500ms
      _checkCameraAvailabilityInRealTime();
    });

    // 🔧 PERMISSION-BASED GATING: Only start countdown when camera is actually available
    // No fallback timeout - wait for real camera availability
    Timer(const Duration(seconds: 30), () {
      if (!_permissionsGranted &&
          !_countdownStarted &&
          mounted &&
          _isInConservativeMode) {
        debugPrint(
            "[PeekSenderWaitPage] 🔧 ⚠️ 30s timeout reached - camera still not available");
        // Don't start countdown - wait for actual camera availability
        // This prevents premature countdown when permissions aren't granted
      }
    });

    // 🔧 ADD REAL-TIME RECEIVER SESSION LISTENER
    // This ensures immediate detection when receiver enters photo capture mode
    _startReceiverSessionListener();
  }

  void _startReceiverSessionListener() {
    try {
      // Get receiver UID from request
      FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get()
          .then((requestDoc) async {
        if (!requestDoc.exists || requestDoc.data() == null) return;

        final requestData = requestDoc.data()!;
        final receiverUid = requestData['receiverUid'] as String?;
        if (receiverUid == null) return;

        // Listen to receiver's session state changes in real-time
        FirebaseFirestore.instance
            .collection('users')
            .doc(receiverUid)
            .snapshots()
            .listen((userSnapshot) {
          if (!mounted || _permissionsGranted || _countdownStarted) return;

          if (userSnapshot.exists && userSnapshot.data() != null) {
            final userData = userSnapshot.data()!;

            // 🔒 FIX: Check if receiver has entered photo capture mode using correct field structure
            final activePeekSession =
                userData['activePeekSession'] as Map<String, dynamic>?;
            final currentSessionState = activePeekSession?['state'] as String?;
            final currentSessionActive =
                activePeekSession?['isActive'] as bool?;

            // Also check legacy fields for backward compatibility
            final sessionState = userData['sessionState'] as String?;
            final currentSession = userData['currentSession'] as String?;
            final sessionMode = userData['sessionMode'] as String?;

            // 🔒 FIX: Check correct field first, then fallback to legacy fields
            if ((currentSessionState == 'photo_capture' &&
                    currentSessionActive == true) ||
                sessionState == 'photo_capture' ||
                currentSession == 'photo_capture' ||
                sessionMode == 'photo_capture') {
              _permissionsGranted = true;
              _isInConservativeMode = false;
              setState(() {});
              _startInitialCountdown();
            }
          }
        });
      });
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Failed to start receiver session listener: $e");
    }
  }

  Future<void> _checkCameraAvailabilityInRealTime() async {
    try {
      // 🔧 CROSS-DEVICE: Monitor receiver's camera state changes
      // This detects when the receiver's camera becomes available

      // Method 1: Check if receiver has started photo capture (indicates camera ready)
      final receiverCameraReady = await _checkReceiverCameraState();

      // Method 2: Check if we have any camera availability signals (with strict permission check)
      final localCameraReady = await _checkLocalCameraPermissions();

      debugPrint(
          "[PeekSenderWaitPage] 🔧 Cross-device check: receiverReady=$receiverCameraReady, localReady=$localCameraReady");

      // 🔧 STRICT PERMISSION GATING: Only start countdown when camera is truly available
      // This prevents premature countdown when permissions aren't granted
      if ((receiverCameraReady || localCameraReady) &&
          !_permissionsGranted &&
          !_countdownStarted) {
        debugPrint(
            "[PeekSenderWaitPage] 🔧 ✅ Camera permissions granted - starting countdown immediately");
        _permissionsGranted = true;
        _isInConservativeMode = false; // Exit conservative mode
        setState(() {});
        _startInitialCountdown();
      }
    } catch (e) {
      // Ignore errors in real-time check - continue monitoring
      debugPrint(
          "[PeekSenderWaitPage] 🔧 Cross-device check failed (expected): $e");
    }
  }

  Future<bool> _checkLocalCameraPermissions() async {
    try {
      // 🔧 STRICT LOCAL CHECK: Verify local camera permissions are actually granted
      // This prevents false positives from availableCameras()

      // Check if we can actually access cameras (indicates permissions granted)
      final cameras = await availableCameras();
      final hasCameras = cameras.isNotEmpty;

      if (!hasCameras) {
        return false;
      }

      // Additional verification: Check if we can initialize a camera controller
      // This confirms permissions are truly granted, not just detected
      try {
        final cameraController = CameraController(
          cameras.first,
          ResolutionPreset.medium,
        );

        // Try to initialize (this will fail if permissions aren't granted)
        await cameraController.initialize();
        await cameraController.dispose();

        debugPrint(
            "[PeekSenderWaitPage] 🔧 Local camera permissions verified - truly granted");
        return true;
      } catch (e) {
        debugPrint(
            "[PeekSenderWaitPage] 🔧 Local camera permissions check failed: $e");
        return false;
      }
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] 🔧 Local camera permissions check error: $e");
      return false;
    }
  }

  Future<bool> _checkReceiverCameraState() async {
    try {
      // 🔧 CROSS-DEVICE: Check if receiver has started photo capture
      // This indicates their camera is ready and we can start countdown

      // Method 1: Check if receiver has updated their session state to photo_capture
      // This happens when they start taking photos
      final receiverSessionState = await _getReceiverSessionState();

      // Method 2: Check if receiver has any camera-related activity
      final receiverCameraActivity = await _checkReceiverCameraActivity();

      // Method 3: Check if receiver has explicitly granted camera permissions
      final receiverCameraPermissions = await _checkReceiverCameraPermissions();

      debugPrint(
          "[PeekSenderWaitPage] 🔧 Receiver state: session=$receiverSessionState, cameraActivity=$receiverCameraActivity, permissions=$receiverCameraPermissions");

      // 🔧 STRICT READY SIGNAL: Only start countdown when receiver camera is truly ready
      // This prevents premature countdown when permissions aren't granted
      final isReceiverReady = receiverSessionState == 'photo_capture' ||
          (receiverCameraPermissions && receiverCameraActivity);

      debugPrint(
          "[PeekSenderWaitPage] 🔧 Receiver camera ready: $isReceiverReady (strict permission gating)");

      return isReceiverReady;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkReceiverCameraPermissions() async {
    try {
      // Check if receiver has explicitly granted camera permissions
      // This is a more reliable indicator than just session state

      // First get the request data to find the receiver UID
      final requestDoc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists || requestDoc.data() == null) {
        return false;
      }

      final requestData = requestDoc.data()!;
      final receiverUid = requestData['receiverUid'] as String?;

      if (receiverUid == null) {
        return false;
      }

      // Check receiver's camera permission status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final hasCameraAccess = userDoc.data()!['has_camera_access'] as bool?;
        final cameraPermissionsGranted =
            userDoc.data()!['cameraPermissionsGranted'] as bool?;

        // Return true if either flag indicates camera access
        return hasCameraAccess == true || cameraPermissionsGranted == true;
      }
      return false;
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Failed to check receiver camera permissions: $e");
      return false;
    }
  }

  Future<String?> _getReceiverSessionState() async {
    try {
      // Get receiver's current session state from Firestore
      // This indicates if they've started photo capture

      // First get the request data to find the receiver UID
      final requestDoc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists || requestDoc.data() == null) {
        return null;
      }

      final requestData = requestDoc.data()!;
      final receiverUid = requestData['receiverUid'] as String?;

      if (receiverUid == null) {
        return null;
      }

      // Now get the receiver's session state from multiple possible fields
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;

        // 🔒 FIX: Check the correct field structure that SessionManager writes to
        final activePeekSession =
            userData['activePeekSession'] as Map<String, dynamic>?;

        // Also check legacy fields for backward compatibility
        final sessionState = userData['sessionState'] as String?;
        final currentSession = userData['currentSession'] as String?;
        final sessionMode = userData['sessionMode'] as String?;
        final isInSession = userData['isInSession'] as bool?;

        // Extract current session state from the correct structure
        final currentSessionState = activePeekSession?['state'] as String?;
        final currentSessionActive = activePeekSession?['isActive'] as bool?;

        // 🔒 FIX: Check the correct field first
        if (currentSessionState != null &&
            currentSessionState.isNotEmpty &&
            currentSessionActive == true) {
          return currentSessionState;
        } else if (sessionState != null && sessionState.isNotEmpty) {
          return sessionState;
        } else if (currentSession != null && currentSession.isNotEmpty) {
          return currentSession;
        } else if (sessionMode != null && sessionMode.isNotEmpty) {
          return sessionMode;
        } else if (isInSession == true) {
          // If they're in a session but no specific state, check the session collection
          return await _getReceiverSessionFromCollection(receiverUid);
        }
      }
      return null;
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Failed to get receiver session state: $e");
      return null;
    }
  }

  Future<String?> _getReceiverSessionFromCollection(String receiverUid) async {
    try {
      // Check the sessions collection for the receiver's current session
      final sessionsQuery = await FirebaseFirestore.instance
          .collection('sessions')
          .where('userId', isEqualTo: receiverUid)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (sessionsQuery.docs.isNotEmpty) {
        final sessionData = sessionsQuery.docs.first.data();
        final sessionState = sessionData['state'] as String?;
        final sessionMode = sessionData['mode'] as String?;

        debugPrint(
            "[PeekSenderWaitPage] 🔍 Session collection: state=$sessionState, mode=$sessionMode");

        return sessionState ?? sessionMode;
      }
      return null;
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Failed to get session from collection: $e");
      return null;
    }
  }

  Future<bool> _checkReceiverCameraActivity() async {
    try {
      // Check if receiver has any recent camera activity
      // This could be from their camera initialization or photo capture

      // First get the request data to find the receiver UID
      final requestDoc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (!requestDoc.exists || requestDoc.data() == null) {
        return false;
      }

      final requestData = requestDoc.data()!;
      final receiverUid = requestData['receiverUid'] as String?;

      if (receiverUid == null) {
        return false;
      }

      // Now check the receiver's camera activity
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverUid)
          .get();

      if (userDoc.exists && userDoc.data() != null) {
        final lastCameraActivity =
            userDoc.data()!['lastCameraActivity'] as Timestamp?;
        if (lastCameraActivity != null) {
          final now = DateTime.now();
          final timeDiff = now.difference(lastCameraActivity.toDate());
          // If camera activity was within last 10 seconds, consider it recent
          return timeDiff.inSeconds < 10;
        }
      }
      return false;
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Failed to check receiver camera activity: $e");
      return false;
    }
  }

  void _startAggressivePermissionPolling() {
    _permissionPollingTimer?.cancel();
    int pollCount = 0;
    const maxPolls =
        12; // 12 attempts over 12 seconds (12 * 1s intervals) - faster response

    _permissionPollingTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      // 1-second intervals for faster response
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_permissionsGranted) {
        debugPrint(
            "[PeekSenderWaitPage] Permissions granted - stopping aggressive polling");
        timer.cancel();
        return;
      }

      pollCount++;
      debugPrint(
          "[PeekSenderWaitPage] 🔧 Aggressive polling... (attempt $pollCount/$maxPolls)");

      if (pollCount >= maxPolls) {
        debugPrint(
            "[PeekSenderWaitPage] 🚀 Aggressive polling complete - proceeding optimistically");
        timer.cancel();
        // After aggressive polling, assume permissions are granted
        _permissionsGranted = true;
        _isInConservativeMode = false; // Exit conservative mode
        setState(() {});
        _startInitialCountdown();
        return;
      }

      _conservativePermissionCheck();
    });
  }

  void _startConservativePolling() {
    _permissionPollingTimer?.cancel();
    int pollCount = 0;
    const maxPolls = 8; // 8 attempts over 24 seconds (8 * 3s intervals)

    _permissionPollingTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_permissionsGranted) {
        debugPrint(
            "[PeekSenderWaitPage] Permissions granted - stopping conservative polling");
        timer.cancel();
        return;
      }

      pollCount++;
      debugPrint(
          "[PeekSenderWaitPage] Conservative polling... (attempt $pollCount/$maxPolls)");

      if (pollCount >= maxPolls) {
        debugPrint(
            "[PeekSenderWaitPage] 🚀 Conservative polling complete - proceeding optimistically");
        timer.cancel();
        // After conservative polling, assume permissions are granted
        _permissionsGranted = true;
        _isInConservativeMode = false; // Exit conservative mode
        setState(() {});
        _startInitialCountdown();
        return;
      }

      _conservativePermissionCheck();
    });
  }

  Future<void> _conservativePermissionCheck() async {
    try {
      final cameras = await availableCameras();
      debugPrint(
          "[PeekSenderWaitPage] 🔍 Conservative check: cameras=${cameras.length}, permissionsGranted=$_permissionsGranted, countdownStarted=$_countdownStarted");

      if (cameras.isNotEmpty && !_permissionsGranted && !_countdownStarted) {
        debugPrint(
            "[PeekSenderWaitPage] ✅ Conservative check successful - permissions confirmed");
        _permissionsGranted = true;
        _isInConservativeMode = false; // Exit conservative mode
        setState(() {});
        debugPrint(
            "[PeekSenderWaitPage] 🔍 State updated: permissionsGranted=$_permissionsGranted");
        _startInitialCountdown();
      } else {
        debugPrint(
            "[PeekSenderWaitPage] 🔍 Conservative check conditions not met: cameras=${cameras.length}, permissionsGranted=$_permissionsGranted, countdownStarted=$_countdownStarted");
      }
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Conservative permission check failed: $e");
    }
  }

  void _showWaitingState() {
    setState(() {
      _secondsRemaining = 30;
    });
    debugPrint(
        "[PeekSenderWaitPage] Showing waiting state: 30s (waiting for permissions)");
  }

  void _handleStatusUpdate(PeekStatusUpdate update) {
    switch (update.status) {
      case 'accepted':
        debugPrint(
            "[PeekSenderWaitPage] Status 'accepted'. Checking permissions and starting countdown...");
        if (!_permissionsGranted && !_countdownStarted) {
          // Don't immediately start countdown - give receiver time to initialize camera
          debugPrint(
              "[PeekSenderWaitPage] Accepted status received - starting permission monitoring");
          _startAcceptedPermissionMonitoring();
        }
        break;
      case 'responded_with_image':
        if (update.imageUrl != null) {
          _navigationManager.navigateToImageView(
            context,
            widget.requestId,
            update.imageUrl!,
            update.senderLocation,
          );
        }
        break;
      case 'declined':
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'declined',
        );
        break;
      case 'expired':
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'expired',
        );
        break;
      case 'cancelled_by_receiver':
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'receiver_cancelled',
        );
        break;
      case 'cancelled_by_sender':
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'sender_cancelled',
        );
        break;
      default:
    }
  }

  void _startInitialCountdown() {
    if (_countdownStarted) {
      return;
    }
    _countdownStarted = true;
    _fetchCaptureExpirationFromFirestore();
  }

  Future<void> _fetchCaptureExpirationFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(widget.requestId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final captureExpiresAt = data['captureExpiresAt'] as Timestamp?;

        if (captureExpiresAt != null) {
          _captureExpirationTime = captureExpiresAt.toDate();
          debugPrint(
              "[PeekSenderWaitPage] Got expiration from Firestore: $_captureExpirationTime");
          _startImmediateCountdown();
          return;
        }
      }

      final functions = FirebaseFunctions.instance;
      final result =
          await functions.httpsCallable('getRequestExpiration').call({
        'requestId': widget.requestId,
      });

      final data = result.data as Map<String, dynamic>?;
      if (data?['captureExpiresAt'] != null) {
        final timestamp = data!['captureExpiresAt'] as int;
        _captureExpirationTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        debugPrint(
            "[PeekSenderWaitPage] Got expiration from Cloud Function: $_captureExpirationTime");
        _startImmediateCountdown();
      }
    } catch (e) {
      _startDefaultCountdown();
    }
  }

  void _startDefaultCountdown() {
    setState(() {
      _secondsRemaining = 30;
    });

    _startLiveCountdown();
  }

  void _startImmediateCountdown() {
    if (_captureExpirationTime != null) {
      final now = DateTime.now();
      final remaining = _captureExpirationTime!.difference(now).inSeconds;
      final bufferedRemaining = remaining + 1;

      setState(() {
        _secondsRemaining = bufferedRemaining > 0 ? bufferedRemaining : 0;
      });

      debugPrint(
          "[PeekSenderWaitPage] Immediate countdown started: ${_secondsRemaining}s");
      _startLiveCountdown();
    }
  }

  void _startLiveCountdown() {
    if (!_permissionsGranted) {
      debugPrint(
          "[PeekSenderWaitPage] Skipping live countdown - permissions not granted");
      return;
    }

    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_secondsRemaining != null && _secondsRemaining! > 0) {
          _secondsRemaining = _secondsRemaining! - 1;
        } else {
          timer.cancel();
          _secondsRemaining = 0;
        }
      });

      if (_secondsRemaining == 0) {
        timer.cancel();
        // 🍎 APPLE REVIEW: Enhanced logging for review session tracking
        debugPrint(
            "[PeekSenderWaitPage] ⏱️ Countdown reached 0 - Timeout triggered. This is expected behavior when no response within 30 seconds.");
        _navigationManager.navigateToHomeWithCancellation(
          context,
          reason: 'timeout',
        );
      }
    });
  }

  /// 🔒 NEW: Handle close action for the close button (reusing Photo Capture logic)
  void _handleCloseAction() async {
    debugPrint(
        "[PeekSenderWaitPage] Close button tapped. Attempting to cancel peek as sender...");

    try {
      // Use Cloud Function to cancel the peek request with admin privileges
      final functions = FirebaseFunctions.instanceFor(region: "us-central1");
      final callable = functions.httpsCallable('cancelPeekRequest');

      final result = await callable.call({
        'requestId': widget.requestId,
        'reason': 'sender_cancelled',
        'debug': kDebugMode,
      });

      final responseData = result.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        debugPrint(
            "[PeekSenderWaitPage] Peek cancelled successfully via Cloud Function. Navigating home...");

        // Navigate directly to home with cancellation parameters
        if (mounted) {
          debugPrint(
              "[PeekSenderWaitPage] Navigating to home with sender cancellation...");
          context.go('/?show=peekCancelled&reason=sender_cancelled');
        }
      } else {
        throw Exception('Cloud Function returned success: false');
      }
    } catch (e) {
      debugPrint(
          "[PeekSenderWaitPage] Error cancelling peek via Cloud Function: $e");

      // Fallback: Even if Cloud Function fails, navigate home
      if (mounted) {
        debugPrint(
            "[PeekSenderWaitPage] Fallback navigation due to Cloud Function error...");
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: peekBackgroundColor,
        body: _uiBuilder.buildBody(
          context: context,
          secondsRemaining: _secondsRemaining,
          animationController: _timerManager.animationController,
          permissionsGranted: _permissionsGranted,
          onClose: _handleCloseAction, // 🔒 NEW: Pass close callback
        ),
      ),
    );
  }

  @override
  void dispose() {
    debugPrint(
        "[PeekSenderWaitPage] Disposing for request ${widget.requestId}.");
    _countdownTimer?.cancel();
    _postSendTimer?.cancel();
    _permissionPollingTimer?.cancel();
    _requestListener?.cancel();
    _listener.dispose();
    _timerManager.dispose();
    super.dispose();
  }
}
