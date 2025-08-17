import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Manages camera initialization, switching, and lifecycle
class CameraControllerManager with WidgetsBindingObserver {
  // Camera state
  CameraController? _controller;
  bool _isCameraInitializing = false;
  bool _isCameraInitialized = false;
  bool _isChangingCamera = false;
  int _selectedCameraIndex = -1;
  String? _initializationError;

  // External dependencies
  final List<CameraDescription> cameras;
  final VoidCallback? onCameraInitialized;
  final ValueChanged<String>? onError;
  final VoidCallback? onCameraChanged;

  CameraControllerManager({
    required this.cameras,
    this.onCameraInitialized,
    this.onError,
    this.onCameraChanged,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  // Getters
  CameraController? get controller => _controller;
  bool get isCameraInitializing => _isCameraInitializing;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isChangingCamera => _isChangingCamera;
  int get selectedCameraIndex => _selectedCameraIndex;
  String? get initializationError => _initializationError;

  /// Initialize camera system
  Future<void> initialize({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
  }) async {
    if (_isChangingCamera || _isCameraInitializing) return;

    if (cameras.isEmpty) {
      _handleError("Camera unavailable on this device.");
      return;
    }

    int cameraIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == preferredDirection,
    );

    if (cameraIndex == -1) {
      cameraIndex = 0; // Fallback to first available camera
    }

    _selectedCameraIndex = cameraIndex;
    await _initializeCamera(cameras[cameraIndex]);
  }

  /// Initialize specific camera
  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    debugPrint(
        "[CameraController] Initializing camera: ${cameraDescription.name}");

    if (_isCameraInitializing) {
      debugPrint("[CameraController] Already initializing, skipping");
      return;
    }

    _isCameraInitializing = true;
    _initializationError = null;

    // Dispose existing controller if different camera
    if (_controller != null &&
        _controller!.description.name != cameraDescription.name) {
      await _disposeController();
    }

    // Skip if same camera is already initialized
    if (_controller != null &&
        _controller!.description.name == cameraDescription.name &&
        _controller!.value.isInitialized) {
      _isCameraInitializing = false;
      _isCameraInitialized = true;
      onCameraInitialized?.call();
      return;
    }

    try {
      final newController = CameraController(
        cameraDescription,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await newController.initialize();

      // Check if widget is still mounted before setting state
      _controller = newController;
      _isCameraInitialized = true;
      _initializationError = null;

      debugPrint(
          "[CameraController] Camera initialized successfully: ${cameraDescription.name}");
      onCameraInitialized?.call();
    } catch (error) {
      debugPrint("[CameraController] Camera initialization error: $error");
      _initializationError = "Camera initialization failed: $error";
      _isCameraInitialized = false;
      onError?.call(_initializationError!);
    } finally {
      _isCameraInitializing = false;
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (cameras.length < 2 || _isChangingCamera || _isCameraInitializing) {
      debugPrint("[CameraController] Switch camera blocked");
      return;
    }

    _isChangingCamera = true;

    // Find opposite camera
    final currentDirection = cameras[_selectedCameraIndex].lensDirection;
    final targetDirection = currentDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    final newCameraIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == targetDirection,
    );

    if (newCameraIndex == -1) {
      _isChangingCamera = false;
      return;
    }

    _selectedCameraIndex = newCameraIndex;
    onCameraChanged?.call();

    await _initializeCamera(cameras[newCameraIndex]);
    _isChangingCamera = false;
  }

  /// Check if current camera is front-facing
  bool get isFrontCamera {
    if (_selectedCameraIndex == -1 || _selectedCameraIndex >= cameras.length) {
      return false;
    }
    return cameras[_selectedCameraIndex].lensDirection ==
        CameraLensDirection.front;
  }

  /// Handle app lifecycle changes
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        debugPrint("[CameraController] App paused/inactive - disposing camera");
        await _disposeController();
        break;
      case AppLifecycleState.resumed:
        debugPrint("[CameraController] App resumed - reinitializing camera");
        if (_selectedCameraIndex != -1) {
          await _initializeCamera(cameras[_selectedCameraIndex]);
        }
        break;
      case AppLifecycleState.hidden:
        // No action needed for hidden state
        break;
    }
  }

  /// Dispose camera controller
  Future<void> _disposeController() async {
    if (_controller != null) {
      debugPrint("[CameraController] Disposing camera controller");
      try {
        await _controller!.dispose();
      } catch (e) {
        debugPrint("[CameraController] Error disposing controller: $e");
      }
      _controller = null;
      _isCameraInitialized = false;
    }
  }

  /// Handle errors
  void _handleError(String error) {
    _initializationError = error;
    debugPrint("[CameraController] Error: $error");
    onError?.call(error);
  }

  /// Dispose resources
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _disposeController();
  }
}
