import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camera/camera.dart';
// import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:peek/features/peek/camera/camera_controller_manager.dart';
import 'package:peek/features/peek/camera/photo_capture_logic.dart';
import 'package:peek/features/peek/camera/location_service.dart';
import 'package:peek/features/peek/camera/countdown_manager.dart';
import 'package:peek/features/peek/camera/user_settings_manager.dart';
import 'package:peek/theme/colors.dart';
import 'package:peek/core/widgets/peek_loading_indicator.dart';

// Global camera list (keeping this as is for compatibility)
List<CameraDescription> _cameras = [];
Future<void> initializeCameras() async {
  if (_cameras.isNotEmpty) return;
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint("❌ Error initializing cameras: $e");
    _cameras = [];
  }
}

class PhotoCapturePage extends ConsumerStatefulWidget {
  final String requestId;
  final String mode;

  const PhotoCapturePage({
    super.key,
    required this.requestId,
    required this.mode,
  });

  @override
  ConsumerState<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends ConsumerState<PhotoCapturePage>
    with SingleTickerProviderStateMixin {
  // Managers
  late final CameraControllerManager _cameraManager;
  late final PhotoCaptureLogic _captureLogic;
  late final LocationService _locationService;
  late final CountdownManager _countdownManager;
  late final UserSettingsManager _userSettings;

  // Analytics (for future use)
  // final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  // State
  String? _currentLocation;
  bool _isInitializing = true;
  bool _isProcessingAction = false;
  bool _isButtonPressed = false;

  @override
  void initState() {
    super.initState();
    _initializeManagers();
    _setupAnimation();
    _initializeCapture();
  }

  /// Initialize all manager components
  void _initializeManagers() {
    // Initialize with empty cameras list - will be recreated in _initializeCapture
    _cameraManager = CameraControllerManager(
      cameras: [],
      onCameraInitialized: () {
        _triggerCountdownStart();
        setState(() {});
      },
      onError: _handleError,
      onCameraChanged: () => setState(() {}),
    );

    _captureLogic = PhotoCaptureLogic(
      onCaptureStart: () => setState(() {}),
      onCaptureComplete: () => setState(() {}),
      onUploadStart: () => setState(() {}),
      onUploadComplete: () => setState(() {}),
      onError: _handleError,
      onUploadSuccess: _handleUploadSuccess,
    );

    _locationService = LocationService(
      onLocationStart: () => setState(() {}),
      onLocationComplete: () => setState(() {}),
      onError: _handleError,
      onLocationSuccess: (location) {
        _currentLocation = location;
        setState(() {});
      },
    );

    _countdownManager = CountdownManager(
      onCountdownUpdate: (seconds) {
        debugPrint(
            "[PhotoCapturePage] Countdown update: ${seconds}s remaining");
        setState(() {});
      },
      onCountdownComplete: _triggerCountdownStart,
      onTimeout: _handleTimeout,
    );

    _userSettings = UserSettingsManager(
      onSettingsLoaded: () => setState(() {}),
      onError: _handleError,
    );
  }

  /// Setup pulse animation
  void _setupAnimation() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  /// Initialize capture process
  Future<void> _initializeCapture() async {
    try {
      // Lock orientation
      await SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitUp]);

      // Initialize cameras first
      await initializeCameras();

      // Update camera manager with initialized cameras
      _cameraManager.updateCamerasList(_cameras);

      // Load user settings
      await _userSettings.loadUserSettings();

      // Get location if user shares location
      if (_userSettings.shouldShareLocation()) {
        await _locationService.getCurrentUserCity();
      }

      // Initialize camera
      await _cameraManager.initialize();

      // Start listening for countdown
      _countdownManager.listenForCaptureDeadline(widget.requestId);

      setState(() => _isInitializing = false);
    } catch (e) {
      _handleError("Initialization failed: $e");
    }
  }

  /// Handle capture button press
  Future<void> _handleCapturePress() async {
    // Prevent multiple rapid taps
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      if (_captureLogic.capturedImageBytes != null) {
        // Upload existing photo
        debugPrint("[PhotoCapturePage] Starting photo upload...");
        await _captureLogic.uploadPhoto(
          requestId: widget.requestId,
          senderLocation: _currentLocation,
          senderDisplayName: _userSettings.senderDisplayName,
          senderAvatarUrl: _userSettings.senderAvatarUrl,
        );
      } else {
        // Take new photo
        debugPrint("[PhotoCapturePage] Taking photo...");
        await _captureLogic.takePicture(
          controller: _cameraManager.controller,
        );
      }
    } catch (e) {
      debugPrint("[PhotoCapturePage] Action failed: $e");
      _handleError("Action failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  /// Handle retake button press
  void _handleRetake() {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);

    try {
      _captureLogic.retakePicture();
      setState(() {});
    } catch (e) {
      debugPrint("[PhotoCapturePage] Retake failed: $e");
      _handleError("Retake failed: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  /// Handle camera switch - REMOVED: Only back camera allowed
  // Future<void> _handleCameraSwitch() async {
  //   await _cameraManager.switchCamera();
  // }

  /// Handle upload success
  void _handleUploadSuccess(String downloadUrl) {
    debugPrint("Upload successful: $downloadUrl");
    context.go('/peek-sent-confirmation?requestId=${widget.requestId}');
  }

  /// Handle errors
  void _handleError(String error) {
    debugPrint("PhotoCapture Error: $error");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: peekErrorColor,
      ),
    );
  }

  /// Handle timeout
  void _handleTimeout() {
    if (!mounted) return;

    debugPrint("[PhotoCapturePage] Capture timeout reached - showing modal");

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        // Auto-close after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        });

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_off_outlined,
                  size: 60, color: Colors.white70),
              const SizedBox(height: 20),
              const Text("Time's Up!",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              const Text("The photo capture window has expired.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('OK',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      // After the sheet is closed (either by timer or manually), navigate home
      if (mounted) {
        context.go('/');
      }
    });
  }

  /// Trigger countdown start
  void _triggerCountdownStart() {
    // Ensure this is only called once (match original logic)
    if (!mounted) return;

    debugPrint(
        "[PhotoCapturePage] Camera is ready, triggering countdown start.");
    _pulseController.repeat(reverse: true);

    // Start the 30-second countdown manually
    _countdownManager.startManualCountdown(durationSeconds: 30);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraManager.dispose();
    _captureLogic.dispose();
    _countdownManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return _buildLoadingScreen();
    }

    if (_cameraManager.initializationError != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          _buildCameraPreview(),

          // Countdown overlay
          if (_countdownManager.secondsRemaining != null)
            _buildCountdownOverlay(),

          // Controls overlay
          _buildControlsOverlay(),

          // Upload overlay
          if (_captureLogic.uploading) _buildUploadOverlay(),
        ],
      ),
    );
  }

  /// Build loading screen
  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PeekLoadingIndicator.medium(
          logoColor: Colors.white,
          loadingText: "Initializing camera...",
        ),
      ),
    );
  }

  /// Build error screen
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              _cameraManager.initializationError!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build camera preview
  Widget _buildCameraPreview() {
    if (!_cameraManager.isCameraInitialized ||
        _cameraManager.controller == null) {
      return const Center(
        child: PeekLoadingIndicator.medium(logoColor: Colors.white),
      );
    }

    // Use FittedBox with proper dimensions like the original
    Widget cameraPreviewWidget;
    try {
      cameraPreviewWidget = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraManager.controller!.value.previewSize?.height ?? 100,
          height: _cameraManager.controller!.value.previewSize?.width ?? 100,
          child: CameraPreview(_cameraManager.controller!),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error building CameraPreview widget with FittedBox: $e");
      cameraPreviewWidget = const Center(
        child: Text("Preview Error", style: TextStyle(color: Colors.red)),
      );
    }

    return Positioned.fill(child: Center(child: cameraPreviewWidget));
  }

  /// Build countdown overlay
  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        // Show gradient background only when photo is taken (SEND button visible)
        decoration: _captureLogic.capturedImageBytes != null
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.9),
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              )
            : null,
        // No background during countdown, gradient only after photo capture
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Text(
                  '${_countdownManager.secondsRemaining}',
                  style: const TextStyle(
                    fontSize: 60,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build controls overlay
  Widget _buildControlsOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 79, // 24 + 35 + 20 = 79px total bottom padding
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main capture/upload button - centered with consistent positioning
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
                width: 80,
                height: 80,
                transform: Matrix4.identity()
                  ..scale(_isButtonPressed ? 0.95 : 1.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _captureLogic.capturedImageBytes != null
                      ? peekPrimaryColor
                      : Colors.white,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: GestureDetector(
                  onTap: _isProcessingAction ? null : _handleCapturePress,
                  onTapDown: (_) => setState(() => _isButtonPressed = true),
                  onTapUp: (_) => setState(() => _isButtonPressed = false),
                  onTapCancel: () => setState(() => _isButtonPressed = false),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(
                          opacity: animation,
                          child: child,
                        ),
                      );
                    },
                    child: _isProcessingAction
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _captureLogic.capturedImageBytes != null
                                ? Icons.send_rounded // ✅ Consistent send icon
                                : Icons.camera_alt,
                            color: _captureLogic.capturedImageBytes != null
                                ? Colors
                                    .white // ✅ Consistent white color for send
                                : Colors.black,
                            size: 32,
                            key: ValueKey(
                                _captureLogic.capturedImageBytes != null),
                          ),
                  ),
                ),
              ),
            ),

            // Retake button - always present but hidden when not needed
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _captureLogic.capturedImageBytes != null ? 56 : 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _captureLogic.capturedImageBytes != null ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _isProcessingAction ? null : _handleRetake,
                        icon: _isProcessingAction
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 32,
                              ),
                      ),
                      const Spacer(), // ✅ Push retake button to left
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build upload overlay
  Widget _buildUploadOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: const Center(
          child: PeekLoadingIndicator.medium(
            logoColor: Colors.white,
            loadingText: "Sending Peek...",
          ),
        ),
      ),
    );
  }
}
