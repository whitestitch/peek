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
      onCameraInitialized: () => setState(() {}),
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
      onCountdownUpdate: (seconds) => setState(() {}),
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
    if (_captureLogic.capturedImageBytes != null) {
      // Upload existing photo
      await _captureLogic.uploadPhoto(
        requestId: widget.requestId,
        senderLocation: _currentLocation,
      );
    } else {
      // Take new photo
      await _captureLogic.takePicture(
        controller: _cameraManager.controller,
        isFrontCamera: _cameraManager.isFrontCamera,
      );
    }
  }

  /// Handle retake button press
  void _handleRetake() {
    _captureLogic.retakePicture();
    setState(() {});
  }

  /// Handle camera switch
  Future<void> _handleCameraSwitch() async {
    await _cameraManager.switchCamera();
  }

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
    context.go('/peek-timed-out?requestId=${widget.requestId}');
  }

  /// Trigger countdown start
  void _triggerCountdownStart() {
    _pulseController.repeat(reverse: true);
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

    return Positioned.fill(
      child: AspectRatio(
        aspectRatio: _cameraManager.controller!.value.aspectRatio,
        child: CameraPreview(_cameraManager.controller!),
      ),
    );
  }

  /// Build countdown overlay
  Widget _buildCountdownOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.7),
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Text(
                  '${_countdownManager.secondsRemaining}',
                  style: const TextStyle(
                    fontSize: 120,
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
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Switch camera button
            if (_cameras.length > 1)
              IconButton(
                onPressed: _handleCameraSwitch,
                icon: const Icon(Icons.switch_camera,
                    color: Colors.white, size: 32),
              ),

            // Capture/Upload button
            GestureDetector(
              onTap: _handleCapturePress,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _captureLogic.capturedImageBytes != null
                      ? peekPrimaryColor
                      : Colors.white,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Icon(
                  _captureLogic.capturedImageBytes != null
                      ? Icons.upload
                      : Icons.camera_alt,
                  color: _captureLogic.capturedImageBytes != null
                      ? Colors.white
                      : Colors.black,
                  size: 32,
                ),
              ),
            ),

            // Retake button
            if (_captureLogic.capturedImageBytes != null)
              IconButton(
                onPressed: _handleRetake,
                icon: const Icon(Icons.refresh, color: Colors.white, size: 32),
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
