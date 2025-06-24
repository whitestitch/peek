// lib/features/peek/photo_capture_page.dart
import 'dart:async';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:peek/features/peek/controllers/peek_controller.dart';
import 'package:peek/theme/colors.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:peek/core/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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

class PhotoCapturePage extends ConsumerStatefulWidget {
  final String requestId;
  const PhotoCapturePage({super.key, required this.requestId});
  @override
  ConsumerState<PhotoCapturePage> createState() => _PhotoCapturePageState();
}

class _PhotoCapturePageState extends ConsumerState<PhotoCapturePage>
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSenderPremium = false;
  bool _senderSharesLocation = false;
  bool _senderAllowsLocationReveal = false;
  bool _isFetchingLocation = false;
  String? _senderDisplayName;
  String? _senderAvatarUrl;

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
        if (mounted) {
          _findAndInitializeCamera();
          _loadUserSettings();
        }
      });
    });
  }

  Future<void> _loadUserSettings() async {
    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      // ASSUMPTION: FirestoreService has getCurrentUserDocument()
      final userDoc = await firestoreService.getCurrentUserDocument();
      if (mounted && userDoc != null && userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _isSenderPremium = data?['isPremium'] as bool? ?? false;
          _senderSharesLocation =
              data?['shareLocationPreference'] as bool? ?? false;
          // ?????????????????????????
          // _senderAllowsLocationReveal =
          //     data?['seeOthersLocationPreference'] as bool? ?? false;
          _senderDisplayName =
              data?['displayName'] as String?; // Assuming 'displayName' field
          _senderAvatarUrl =
              data?['avatarUrl'] as String?; // Assuming 'avatarUrl' field
          debugPrint(
              "[PhotoCapturePage] Sender Settings Loaded - Premium: $_isSenderPremium, Shares Own Location: $_senderSharesLocation, Allows Reveal: $_senderAllowsLocationReveal, Name: $_senderDisplayName");
        });
      } else {
        debugPrint(
            "[PhotoCapturePage] Could not load user settings or document does not exist for sender.");
        if (mounted) {
          setState(() {
            // Default to false if settings can't be loaded
            _isSenderPremium = false;
            _senderSharesLocation = false;
            _senderAllowsLocationReveal = false; // Default
          });
        }
      }
    } catch (e) {
      debugPrint(
          "❌ [PhotoCapturePage] Error loading user settings for sender: $e");
      if (mounted) {
        // Default to false on error
        setState(() {
          _isSenderPremium = false;
          _senderSharesLocation = false;
          _senderAllowsLocationReveal = false; // Default
        });
      }
    }
  }

  /// Handles permissions and errors. Returns null if conditions aren't met or location fails.
  Future<String?> _getCurrentUserCity() async {
    // 1. Check conditions (Premium user + Setting enabled)
    if (!_senderSharesLocation) {
      debugPrint(
          "[PhotoCapturePage] _getCurrentUserCity: Condition NOT met (SharesOwnLocation: $_senderSharesLocation). Not fetching location.");
      return null;
    }

    // 2. Prevent multiple simultaneous fetches
    if (_isFetchingLocation) {
      debugPrint(
          "[PhotoCapturePage] _getCurrentUserCity: Already fetching location.");
      return null; // Or return a previously fetched value if available
    }
    setState(() => _isFetchingLocation = true);
    debugPrint(
        "[PhotoCapturePage] _getCurrentUserCity: Conditions met, attempting to fetch location.");

    try {
      // 3. Check Location Service Enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint(
            "[PhotoCapturePage] _getCurrentUserCity: Location services are disabled.");
        if (mounted)
          _showErrorSnackbar("Location services are disabled."); // Inform user
        return null;
      }

      // 4. Check and Request Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint(
            "[PhotoCapturePage] _getCurrentUserCity: Location permission denied, requesting...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint(
              "[PhotoCapturePage] _getCurrentUserCity: Location permission denied by user.");
          if (mounted)
            _showErrorSnackbar("Location permission needed to share location.");
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
            "[PhotoCapturePage] _getCurrentUserCity: Location permission denied forever.");
        if (mounted)
          _showErrorSnackbar(
              "Location permission permanently denied. Enable in settings.");
        // Optionally, open app settings: await Geolocator.openAppSettings();
        return null;
      }

      // 5. Get Current Position (with timeout)
      debugPrint(
          "[PhotoCapturePage] _getCurrentUserCity: Permissions granted, fetching position...");
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy:
              LocationAccuracy.medium, // City/Region doesn't need high accuracy
          timeLimit: const Duration(seconds: 10) // Add a timeout
          );
      debugPrint(
          "[PhotoCapturePage] _getCurrentUserCity: Position fetched: ${position.latitude}, ${position.longitude}");

      // 6. Reverse Geocode to get Placemark
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? ""; // City
        String region = place.administrativeArea ?? ""; // State/Province/Region

        String locationString;
        if (city.isNotEmpty && region.isNotEmpty) {
          locationString = "$city, $region";
        } else if (city.isNotEmpty) {
          locationString = city;
        } else if (region.isNotEmpty) {
          locationString = region; // Fallback to region
        } else {
          locationString =
              place.country ?? "Unknown Location"; // Further fallback
        }
        debugPrint(
            "[PhotoCapturePage] _getCurrentUserCity: Determined location: $locationString");
        return locationString;
      } else {
        debugPrint(
            "[PhotoCapturePage] _getCurrentUserCity: No placemarks found for coordinates.");
        return null;
      }
    } catch (e) {
      debugPrint(
          "❌ [PhotoCapturePage] _getCurrentUserCity: Error getting location/geocoding: $e");
      if (mounted) _showErrorSnackbar("Could not determine location.");
      return null;
    } finally {
      if (mounted) {
        setState(() => _isFetchingLocation = false);
      }
    }
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
    debugPrint(
        "[PhotoCapturePage] Attempting to initialize camera: ${cameraDescription.name}");

    if (_isCameraInitializing) {
      debugPrint(
          "[PhotoCapturePage] Initialization already in progress. Aborting.");
      return;
    }

    // If the requested camera is already active and initialized, do nothing.
    if (_controller != null &&
        _controller!.value.isInitialized &&
        _controller!.description == cameraDescription) {
      debugPrint(
          "[PhotoCapturePage] Camera ${cameraDescription.name} is already initialized and active.");
      if (mounted) {
        // Ensure flags are correct
        setState(() {
          _isCameraInitialized = true;
          _isCameraInitializing = false;
        });
      }
      return;
    }

    setState(() {
      _isCameraInitializing = true;
      _isCameraInitialized =
          false; // Mark as not initialized during the process
      _initializationError = null;
    });

    // Dispose of the existing controller *only if it's different* from the one we are about to initialize
    // or if it's the same but wasn't initialized (e.g. previous attempt failed).
    // The app lifecycle's didChangeAppLifecycleState should handle disposing and nullifying _controller
    // when the app goes to background.
    if (_controller != null) {
      debugPrint(
          "[PhotoCapturePage] Disposing existing controller before initializing new one: ${_controller?.description.name}");
      try {
        await _controller!.dispose();
        debugPrint(
            "[PhotoCapturePage] Existing controller disposed successfully.");
      } catch (e) {
        debugPrint(
            "⚠️ Error disposing existing controller in _initializeCamera: $e");
      }
      // No need to setState _controller to null here, as it will be replaced or nulled in error case.
    }

    // Create and initialize the new controller
    final newController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      if (!mounted) {
        debugPrint(
            "[PhotoCapturePage] Unmounted during camera initialization. Disposing new controller.");
        await newController.dispose();
        return;
      }
      setState(() {
        _controller =
            newController; // Assign the successfully initialized controller
        _isCameraInitialized = true;
        _isCameraInitializing = false;
      });
      debugPrint(
          "[PhotoCapturePage] Camera initialized successfully: ${newController.description.name}");
    } catch (error) {
      debugPrint(
          "❌ [PhotoCapturePage] Camera initialization error for ${newController.description.name}: $error");
      // Attempt to dispose the new controller if its initialization failed
      try {
        await newController.dispose();
        debugPrint(
            "[PhotoCapturePage] Disposed new controller after initialization failure.");
      } catch (disposeError) {
        debugPrint(
            "⚠️ Error disposing new controller after init failure: $disposeError");
      }
      if (mounted) {
        String errorMessage = "Couldn't access camera. Please try again.";
        if (error is CameraException) {
          if (error.code == 'CameraAccessDenied') {
            errorMessage =
                "Camera permission denied. Please enable it in settings.";
          }
        }
        setState(() {
          _initializationError = "Init Error: $error";
          _isCameraInitialized = false;
          _isCameraInitializing = false;
          _controller = null; // Ensure controller is null on error
        });
        _showErrorSnackbar(errorMessage);
      }
    } finally {
      // If _isCameraInitializing is still true here, it means init didn't complete successfully
      // nor threw to the catch block that resets it. Reset it to allow future attempts.
      if (mounted && _isCameraInitializing && !_isCameraInitialized) {
        setState(() => _isCameraInitializing = false);
        debugPrint(
            "[PhotoCapturePage] Reset _isCameraInitializing in finally block.");
      }
      // This was for _isChangingCamera, ensure it's still relevant or remove if handled elsewhere
      if (_isChangingCamera && mounted) {
        setState(() {
          _isChangingCamera = false;
        });
        debugPrint(
            "[PhotoCapturePage] Camera changing finished (from _initializeCamera finally).");
      }
    }
  }

  // --- didChangeAppLifecycleState (Keep As Is) ---
  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state); // Call super
    debugPrint("[PhotoCapturePage] AppLifecycleState changed: $state");

    final CameraController? currentCameraController =
        _controller; // Capture instance

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (currentCameraController != null) {
        // Check if there is a controller to dispose
        debugPrint(
            "[PhotoCapturePage] App inactive/paused. Current controller: ${currentCameraController.description.name}, isInitialized: ${currentCameraController.value.isInitialized}");
        if (mounted) {
          setState(() {
            // Mark as not initialized immediately to prevent usage.
            // _controller will be nulled after dispose confirmation.
            _isCameraInitialized = false;
            // If we are initializing when app goes inactive, stop it.
            if (_isCameraInitializing) _isCameraInitializing = false;
          });
        }
        try {
          await currentCameraController.dispose();
          debugPrint(
              "[PhotoCapturePage] Camera controller successfully disposed on lifecycle event.");
        } catch (e) {
          debugPrint(
              "⚠️ Error disposing camera controller on lifecycle event: $e");
        } finally {
          // Ensure _controller is nulled if it was the one we disposed
          if (mounted && _controller == currentCameraController) {
            setState(() {
              _controller = null;
            });
          }
        }
      } else if (mounted) {
        // If no controller, still ensure flags are correct
        setState(() {
          _isCameraInitialized = false;
          _isCameraInitializing = false;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint("[PhotoCapturePage] App resumed.");
      // Only re-initialize if controller is null AND we are not already trying to initialize.
      if (_controller == null && !_isCameraInitializing) {
        debugPrint(
            "[PhotoCapturePage] Controller is null on resume. Re-initializing camera...");
        // Add a small delay before re-initializing, can help on some platforms
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted && _controller == null && !_isCameraInitializing) {
          // Double check condition after delay
          SystemChrome.setPreferredOrientations(
              [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
          if (_selectedCameraIndex != -1 &&
              _selectedCameraIndex < _cameras.length) {
            _initializeCamera(_cameras[_selectedCameraIndex]);
          } else {
            _findAndInitializeCamera();
          }
        }
      } else if (_controller != null && _controller!.value.isInitialized) {
        debugPrint(
            "[PhotoCapturePage] Controller exists and is initialized on resume. Ensuring orientation.");
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else if (_controller != null &&
          !_controller!.value.isInitialized &&
          !_isCameraInitializing) {
        debugPrint(
            "[PhotoCapturePage] Controller exists but not initialized, and not initializing. Attempting re-init.");
        // This case might happen if a previous initialization failed partway.
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
        !_controller!.value.isInitialized) return;
    setState(() => _isTakingPicture = true);
    try {
      final XFile imageFile = await _controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? capturedImage = img.decodeImage(imageBytes);
      if (capturedImage == null) {
        throw Exception("Failed to decode captured image.");
      }
      bool isFrontCamera = _cameras[_selectedCameraIndex].lensDirection ==
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

      Map<String, dynamic> peekData = {
        'status': 'responded_with_image', // MODIFIED: More descriptive status
        'storagePath': storagePath,
        'imageUrl': downloadUrl,
        'respondedAt': FieldValue.serverTimestamp(),
        'senderId': _auth.currentUser?.uid,
        'senderDisplayName': _senderDisplayName ?? "Anon",
        if (_senderAvatarUrl != null && _senderAvatarUrl!.isNotEmpty)
          'senderAvatarUrl': _senderAvatarUrl,
      };

      // Conditionally add sender's location
      if (_senderSharesLocation) {
        // Only check if the sender agreed to share.
        String? cityRegion =
            await _getCurrentUserCity(); // This function now correctly gates on _senderSharesLocation
        if (cityRegion != null && cityRegion.isNotEmpty) {
          peekData['senderLocation'] = cityRegion;
          debugPrint(
              "[PhotoCapturePage] Adding senderLocation to Peek: $cityRegion (SenderSharesLocation: $_senderSharesLocation)");
        } else {
          debugPrint(
              "[PhotoCapturePage] senderLocation is null or empty (returned by _getCurrentUserCity), not adding to Peek. (SenderSharesLocation: $_senderSharesLocation)");
        }
      } else {
        debugPrint(
            "[PhotoCapturePage] Sender has not consented to share location (SharesOwnLocation: $_senderSharesLocation). Not adding senderLocation.");
      }

      debugPrint(
          "[PhotoCapturePage] Data to be saved to Firestore for Peek Request: $peekData");

      await firestoreRef.update(peekData);

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
            'location_shared':
                peekData.containsKey('senderLocation').toString(),
            'sender_info_shared': (peekData.containsKey('senderDisplayName') ||
                    peekData.containsKey('senderAvatarUrl'))
                .toString(),
          },
        );
        debugPrint("[PhotoCapturePage] Logged peek_sent event.");
      } catch (analyticsError) {
        debugPrint("Error logging peek_sent event: $analyticsError");
      }

      if (!mounted) return;
      // Navigate to the new full-screen confirmation page
      context.go('/peek-sent-confirmation');
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
      backgroundColor: peekBackgroundColor,
      appBar: AppBar(
        // Remove back button if not desired
        automaticallyImplyLeading: false,

        // Make AppBar transparent
        backgroundColor: peekBackgroundColor,
        // backgroundColor: Colors.transparent,
        // No shadow
        elevation: 0,
        actions: [
          // Close button moved to actions for standard placement
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: () {
              // Signal to the sender that the peek was cancelled by the receiver.
              ref
                  .read(peekControllerProvider.notifier)
                  .declinePeekByReceiver(widget.requestId);

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
            // color: Colors.black.withOpacity(0.5),
            color: peekBackgroundColor,
            // Padding includes safe area
            padding: EdgeInsets.only(
              top: 15.0,
              bottom: MediaQuery.of(context).padding.bottom +
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
                    onPressed: _isChangingCamera || _isCameraInitializing
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
