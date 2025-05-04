// lib/features/peek/photo_capture_page.dart
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import 'dart:typed_data'; // Needed for image manipulation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img; // Import with a prefix

// --- Global Camera List & Initialization (Keep As Is) ---
List<CameraDescription> _cameras = [];
Future<void> initializeCameras() async {
  // ... (Keep existing initializeCameras code) ...
  if (_cameras.isNotEmpty) return;
  try {
    _cameras = await availableCameras();
    debugPrint("[CameraInit] Available cameras: ${_cameras.length}");
    if (_cameras.isEmpty) debugPrint("⚠️ [CameraInit] No cameras found.");
  } catch (e) {
    debugPrint("❌ Error initializing cameras: $e");
    _cameras = [];
  }
}
// ---------------------------------------------------

class PhotoCapturePage extends StatefulWidget {
  final String requestId;
  const PhotoCapturePage({super.key, required this.requestId});
  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends State<PhotoCapturePage>
    with WidgetsBindingObserver {
  // --- State Variables (Keep As Is) ---
  CameraController? _controller;
  bool _isCameraInitializing = false;
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  bool _uploading = false;
  Uint8List? _capturedImageBytes;
  File? _tempProcessedFile;
  int _selectedCameraIndex = -1;
  bool _isChangingCamera = false;
  String? _initializationError;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // --- initState (Keep As Is) ---
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]).then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _findAndInitializeCamera();
      });
    });
  }

  // --- _findAndInitializeCamera (Keep As Is) ---
  void _findAndInitializeCamera({
    CameraLensDirection preferredDirection = CameraLensDirection.back,
  }) {
    // ... (Keep existing code) ...
    if (_isChangingCamera || _isCameraInitializing) return;
    if (_cameras.isEmpty) {
      _showErrorAndGoHome("Camera unavailable on this device.");
      return;
    }
    int cameraIndex = _cameras.indexWhere(
      (cam) => cam.lensDirection == preferredDirection,
    );
    if (cameraIndex == -1)
      cameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection != preferredDirection,
      );
    if (cameraIndex == -1) cameraIndex = 0;
    if (cameraIndex == -1) {
      _showErrorAndGoHome("No suitable camera found.");
      return;
    }
    if (_selectedCameraIndex == cameraIndex &&
        _controller != null &&
        _controller!.value.isInitialized) {
      debugPrint(
        "[PhotoCapturePage] Camera index $cameraIndex already selected and initialized.",
      );
      return;
    }
    setState(() {
      _selectedCameraIndex = cameraIndex;
    });
    _initializeCamera(_cameras[cameraIndex]);
  }

  // --- _initializeCamera (Keep As Is) ---
  Future<void> _initializeCamera(CameraDescription cameraDescription) async {
    // ... (Keep existing code) ...
    debugPrint(
      "[PhotoCapturePage] Preparing to initialize camera: ${cameraDescription.name}",
    );
    if (_isCameraInitializing) {
      debugPrint(
        "[PhotoCapturePage] Already initializing a camera, ignoring call.",
      );
      return;
    }
    final currentController = _controller;
    setState(() {
      _isCameraInitializing = true;
      _isCameraInitialized = false;
      _controller = null;
      _initializationError = null;
    });
    if (currentController != null) {
      debugPrint("[PhotoCapturePage] Disposing previous controller (await)...");
      try {
        await currentController.dispose();
        debugPrint("[PhotoCapturePage] Previous controller disposed.");
      } catch (e) {
        debugPrint("⚠️ Error disposing previous controller: $e");
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _controller = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _controller!.initialize();
      if (!mounted) {
        await _controller?.dispose();
        return;
      }
      setState(() {
        _isCameraInitialized = true;
        _isCameraInitializing = false;
      });
      debugPrint(
        "[PhotoCapturePage] Camera initialized successfully: ${cameraDescription.name}",
      );
    } catch (error) {
      debugPrint(
        "❌ [PhotoCapturePage] Camera initialization error for ${cameraDescription.name}: $error",
      );
      if (mounted) {
        String errorMessage = "Couldn't access camera. Please try again.";
        if (error is CameraException)
          if (error.code == 'CameraAccessDenied') {
            errorMessage =
                "Camera permission denied. Please enable it in settings.";
          }
        setState(() {
          _initializationError =
              "Init Error: $error"; // Keep technical error for state if needed
          _isCameraInitialized = false;
          _isCameraInitializing = false;
          _controller = null;
        });
        _showErrorSnackbar(errorMessage);
      }
    } finally {
      if (_isChangingCamera && mounted) {
        setState(() {
          _isChangingCamera = false;
        });
        debugPrint("[PhotoCapturePage] Camera changing finished.");
      }
    }
  }

  // --- didChangeAppLifecycleState (Keep As Is) ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ... (Keep existing code) ...
    debugPrint("[PhotoCapturePage] AppLifecycleState changed: $state");
    final CameraController? cameraController = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (cameraController != null && cameraController.value.isInitialized) {
        debugPrint(
          "[PhotoCapturePage] App inactive/paused. Disposing camera controller...",
        );
        if (mounted) {
          setState(() {
            _isCameraInitializing = false;
            _isCameraInitialized = false;
            _controller = null;
          });
        }
        cameraController.dispose().catchError((e) {
          debugPrint("⚠️ Error during lifecycle dispose: $e");
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("[PhotoCapturePage] App resumed.");
      if (_controller == null && !_isCameraInitializing) {
        debugPrint(
          "[PhotoCapturePage] Controller is null on resume. Re-initializing camera...",
        );
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        if (_selectedCameraIndex != -1 &&
            _selectedCameraIndex < _cameras.length) {
          _initializeCamera(_cameras[_selectedCameraIndex]);
        } else {
          _findAndInitializeCamera();
        }
      } else if (_controller != null) {
        debugPrint(
          "[PhotoCapturePage] Controller exists on resume. Ensuring orientation.",
        );
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      }
    }
  }

  // --- _switchCamera (Keep As Is) ---
  void _switchCamera() async {
    // ... (Keep existing code) ...
    if (_cameras.length < 2 || _isChangingCamera || _isCameraInitializing) {
      debugPrint(
        "[PhotoCapturePage] Switch camera blocked: Changing:$_isChangingCamera, Initializing:$_isCameraInitializing",
      );
      return;
    }
    debugPrint("[PhotoCapturePage] Attempting to switch camera...");
    setState(() => _isChangingCamera = true);
    final currentLensDirection = _cameras[_selectedCameraIndex].lensDirection;
    int newCameraIndex = _cameras.indexWhere(
      (cam) => cam.lensDirection != currentLensDirection,
    );
    if (newCameraIndex == -1) newCameraIndex = 0;
    setState(() {
      _selectedCameraIndex = newCameraIndex;
    });
    _initializeCamera(_cameras[newCameraIndex]);
  }

  // --- _takePicture (Keep As Is - already includes flip logic) ---
  Future<void> _takePicture() async {
    // ... (Keep existing code) ...
    if (_isTakingPicture ||
        !_isCameraInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized)
      return;
    setState(() => _isTakingPicture = true);
    try {
      final XFile imageFile = await _controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? capturedImage = img.decodeImage(imageBytes);
      if (capturedImage == null) {
        throw Exception("Failed to decode captured image.");
      }
      bool isFrontCamera =
          _cameras[_selectedCameraIndex].lensDirection ==
          CameraLensDirection.front;
      if (isFrontCamera) {
        debugPrint(
          "[PhotoCapturePage] Front camera detected. Flipping image horizontally.",
        );
        capturedImage = img.flipHorizontal(capturedImage);
      }
      final Uint8List processedBytes = Uint8List.fromList(
        img.encodeJpg(capturedImage, quality: 90),
      );
      await _deleteTempFile();
      if (!mounted) return;
      setState(() {
        _capturedImageBytes = processedBytes;
        _isTakingPicture = false;
      });
    } catch (e) {
      debugPrint("❌ [PhotoCapturePage] Error taking or processing picture: $e");
      if (mounted) {
        _showErrorSnackbar("Couldn't capture photo. Please try again.");
        setState(() => _isTakingPicture = false);
      }
    }
  }

  // --- _uploadPhoto (Keep As Is - already uses bytes) ---
  Future<void> _uploadPhoto() async {
    // ... (Keep existing code) ...
    if (_capturedImageBytes == null || _uploading || !mounted) return;
    setState(() => _uploading = true);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'peeks/${widget.requestId}/$timestamp.jpg';
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    final firestoreRef = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId);
    try {
      await storageRef.putData(
        _capturedImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      debugPrint("[PhotoCapturePage] Image bytes uploaded directly.");
      final downloadUrl = await storageRef.getDownloadURL();
      await firestoreRef.update({
        'status': 'accepted',
        'storagePath': storagePath,
        'imageUrl': downloadUrl,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      // Log successful peek send event
      try {
        // Optional: wrap analytics in its own try-catch
        final imageSizeKb = (_capturedImageBytes!.lengthInBytes / 1024).round();
        final cameraUsed =
            _selectedCameraIndex != -1 && _selectedCameraIndex < _cameras.length
                ? (_cameras[_selectedCameraIndex].lensDirection ==
                        CameraLensDirection.front
                    ? 'front'
                    : 'back')
                : 'unknown';

        await _analytics.logEvent(
          name: 'peek_sent',
          parameters: {
            'request_id_partial': widget.requestId.substring(0, 8),
            'image_size_kb': imageSizeKb,
            'camera_used': cameraUsed,
          },
        );
        debugPrint("[PhotoCapturePage] Logged peek_sent event.");
      } catch (analyticsError) {
        debugPrint("Error logging peek_sent event: $analyticsError");
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Peek Sent!'),
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/');
    } catch (e) {
      debugPrint("❌ [PhotoCapturePage] Error uploading photo: $e");
      // Log peek send error event
      try {
        // Optional: wrap analytics in its own try-catch
        await _analytics.logEvent(
          name: 'peek_send_failed',
          parameters: {
            'request_id_partial': widget.requestId.substring(0, 8),
            'error': e.toString().substring(
              0,
              99 < e.toString().length ? 99 : e.toString().length,
            ),
          },
        );
        debugPrint("[PhotoCapturePage] Logged peek_send_failed event.");
      } catch (analyticsError) {
        debugPrint("Error logging peek_send_failed event: $analyticsError");
      }
      if (mounted) {
        setState(() => _uploading = false);
        _showErrorSnackbar(
          "Failed to send Peek. Check connection and try again.",
        );
        // _showErrorSnackbar("⚠️ Failed to send Peek: ${e.toString()}");
      }
    }
  }

  // --- _retakePicture (Keep As Is - already clears bytes) ---
  void _retakePicture() {
    // ... (Keep existing code) ...
    if (_uploading) return;
    setState(() {
      _capturedImageBytes = null;
      _isTakingPicture = false;
    });
    _deleteTempFile();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (_controller == null || !_controller!.value.isInitialized) {
      if (_selectedCameraIndex != -1) {
        _initializeCamera(_cameras[_selectedCameraIndex]);
      } else {
        _findAndInitializeCamera();
      }
    }
  }

  // --- _deleteTempFile (Keep As Is) ---
  Future<void> _deleteTempFile() async {
    // ... (Keep existing code) ...
    if (_tempProcessedFile != null && await _tempProcessedFile!.exists()) {
      try {
        await _tempProcessedFile!.delete();
        debugPrint(
          "[PhotoCapturePage] Deleted temp file: ${_tempProcessedFile?.path}",
        );
      } catch (e) {
        debugPrint("⚠️ Error deleting temp file: $e");
      } finally {
        _tempProcessedFile = null;
      }
    }
  }

  // --- _showErrorSnackbar (Keep As Is) ---
  void _showErrorSnackbar(String message) {
    // ... (Keep existing code) ...
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // --- _showErrorAndGoHome (Keep As Is) ---
  void _showErrorAndGoHome(String message) {
    // ... (Keep existing code) ...
    if (!mounted) return;
    _showErrorSnackbar(message);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  // --- dispose (Keep As Is) ---
  @override
  void dispose() {
    // ... (Keep existing code) ...
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _deleteTempFile();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    debugPrint("[PhotoCapturePage] Disposed.");
    super.dispose();
  }

  // --- build (Modified AppBar, calls modified _buildCameraView) ---
  @override
  Widget build(BuildContext context) {
    // State 1: Uploading (Keep As Is)
    if (_uploading) {
      /* ... uploading UI ... */
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text("Sending Peek...", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // State 2: Image captured preview (Keep As Is)
    if (_capturedImageBytes != null) {
      /* ... preview UI ... */
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              _capturedImageBytes!,
              fit: BoxFit.cover,
              errorBuilder: (c, e, s) {
                debugPrint("❌ Error displaying preview image from bytes: $e");
                return const Center(
                  child: Icon(Icons.broken_image, color: Colors.red, size: 60),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(context).padding.bottom + 20,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: const [0.0, 0.5],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      iconSize: 35,
                      padding: const EdgeInsets.all(15),
                      tooltip: 'Retake',
                      icon: const Icon(Icons.refresh_rounded),
                      color: Colors.white,
                      onPressed: _retakePicture,
                    ),
                    IconButton(
                      iconSize: 35,
                      padding: const EdgeInsets.all(15),
                      tooltip: 'Send Peek',
                      icon: const Icon(Icons.send_rounded),
                      color: Colors.greenAccent,
                      onPressed: _uploadPhoto,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // State 3: Camera View
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        // --- MODIFICATION: AppBar simplified ---
        automaticallyImplyLeading: false, // Remove back button if not desired
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // No shadow
        actions: [
          // Close button moved to actions for standard placement
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: () {
              SystemChrome.setPreferredOrientations(
                DeviceOrientation.values,
              ); // Unlock orientation
              context.go('/'); // Navigate home
            },
            color: Colors.white, // Ensure icon is visible
          ),
          const SizedBox(width: 10), // Padding on the right
        ],
        // --- END MODIFICATION ---
      ),
      // Make AppBar background extend behind the status bar
      extendBodyBehindAppBar: true,
      // Call the modified _buildCameraView
      body: _buildCameraView(),
    );
  }
  // --- END MODIFIED build ---

  // --- *** MODIFIED: _buildCameraView (UI Changes for Bottom Bar) *** ---
  Widget _buildCameraView() {
    final controller = _controller;

    // Error/Loading checks (Keep As Is)
    if (_initializationError != null) {
      /* ... error UI ... */
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Text(
            'Camera Error:\n$_initializationError',
            style: const TextStyle(color: Colors.redAccent, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_isCameraInitializing ||
        controller == null ||
        !_isCameraInitialized ||
        !controller.value.isInitialized) {
      /* ... loading UI ... */
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Build Camera Preview (Keep As Is - using FittedBox)
    Widget cameraPreviewWidget;
    try {
      cameraPreviewWidget = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 100,
          height: controller.value.previewSize?.width ?? 100,
          child: CameraPreview(controller),
        ),
      );
    } catch (e) {
      debugPrint("❌ Error building CameraPreview widget with FittedBox: $e");
      cameraPreviewWidget = const Center(
        child: Text("Preview Error", style: TextStyle(color: Colors.red)),
      );
    }

    // --- Build UI with Stack: Preview + Bottom Controls ---
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera Preview (fills the stack)
        Center(child: cameraPreviewWidget),

        // --- MODIFIED: Bottom Control Bar ---
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            // Semi-transparent background
            color: Colors.black.withOpacity(0.5),
            // Padding includes safe area
            padding: EdgeInsets.only(
              top: 15.0,
              bottom:
                  MediaQuery.of(context).padding.bottom +
                  25.0, // More bottom padding
              left: 20.0,
              right: 20.0,
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween, // Space items out
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Placeholder on left for balance (can be gallery icon later)
                const SizedBox(
                  width: 60.0,
                  height: 40.0,
                ), // Match approx size of right icon button
                // Center Shutter Button (Keep As Is)
                GestureDetector(
                  onTap: _isTakingPicture ? null : _takePicture,
                  child: Container(
                    width: 70, // Slightly smaller shutter
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(
                          _isTakingPicture ? 0.3 : 0.9,
                        ),
                        width: 4,
                      ),
                    ), // Thicker border
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(
                            _isTakingPicture ? 0.5 : 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Right-aligned Switch Camera Button
                if (_cameras.length > 1) // Only show if multiple cameras exist
                  IconButton(
                    iconSize: 30.0, // Adjust size as needed
                    padding:
                        EdgeInsets.zero, // Remove default padding if needed
                    constraints:
                        const BoxConstraints(), // Remove default constraints
                    tooltip: 'Switch Camera',
                    icon: const Icon(
                      Icons.flip_camera_ios_outlined,
                    ), // Apple-style icon
                    color: Colors.white, // Ensure visibility
                    onPressed:
                        _isChangingCamera || _isCameraInitializing
                            ? null
                            : _switchCamera, // Disable logic
                  )
                else // Show placeholder if only one camera
                  const SizedBox(
                    width: 60.0,
                    height: 40.0,
                  ), // Match approx size
              ],
            ),
          ),
        ),

        // --- END MODIFIED Bottom Control Bar ---
      ],
    );
  } // End _buildCameraView

  // --- *** END OF MODIFIED _buildCameraView *** ---
} // End _PhotoCapturePageState
