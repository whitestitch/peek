import 'dart:io'; // For File handling
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // For camera access
import 'package:firebase_storage/firebase_storage.dart'; // Correct Firebase Storage import
import 'package:cloud_firestore/cloud_firestore.dart'; // For Firestore updates
import 'package:go_router/go_router.dart'; // For navigation

// --- StatefulWidget Definition ---
class PhotoCapturePage extends StatefulWidget {
  final String requestId; // ID of the peek request being responded to

  const PhotoCapturePage({super.key, required this.requestId});

  @override
  State<PhotoCapturePage> createState() => _PhotoCapturePageState();
}
// --- End of StatefulWidget Definition ---

// --- State Class Definition ---
class _PhotoCapturePageState extends State<PhotoCapturePage> {
  // --- State Variables ---
  File? _imageFile; // Holds the captured image file path
  bool _uploading = false; // Tracks if an upload is in progress
  bool _cameraOpened = false; // Prevents multiple simultaneous camera openings
  final _picker = ImagePicker(); // Instance of the image picker utility
  // --- End of State Variables ---

  @override
  void initState() {
    super.initState();
    // Open the camera automatically after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _openCamera();
      }
    });
  }

  /// Opens the device camera to capture an image.
  Future<void> _openCamera() async {
    // Prevent re-opening if already opened or if the widget is disposed
    if (_cameraOpened || !mounted) return;
    _cameraOpened = true; // Set flag to prevent re-entry

    try {
      // Use image_picker to open the camera
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        // Consider adding preferredCameraDevice if needed (e.g., CameraDevice.front)
      );

      // Check if the widget is still mounted after the await call
      if (!mounted) return;

      if (picked == null) {
        // User likely cancelled the camera operation
        debugPrint('Camera cancelled by user.');
        // Navigate back home if the user cancels
        context.go('/');
        return;
      }

      // If an image was picked, create a File object
      final file = File(picked.path);

      // Update the state to store the image file reference
      setState(() => _imageFile = file);
    } catch (e) {
      // Handle potential errors during camera access (e.g., permissions)
      if (!mounted) return;
      debugPrint('📸 Camera error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('📸 Camera error: ${e.toString()}')),
      );
      // Navigate home if there's a camera error
      context.go('/');
    }
  }

  /// Uploads the captured photo to Firebase Storage and updates Firestore.
  Future<void> _uploadPhoto() async {
    // Guard clauses: ensure an image exists, not already uploading, and widget is mounted
    if (_imageFile == null || _uploading || !mounted) return;

    // Set uploading state to true to show progress indicator
    setState(() => _uploading = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Define the path in Firebase Storage (e.g., peeks/<requestId>/<timestamp>.jpg)
    final storagePath = 'peeks/${widget.requestId}/$timestamp.jpg';
    final storageRef = FirebaseStorage.instance.ref(storagePath);
    final firestoreRef = FirebaseFirestore.instance
        .collection('peek_requests')
        .doc(widget.requestId);

    try {
      // 1. Upload the image file to Firebase Storage
      await storageRef.putFile(_imageFile!);
      debugPrint('Image uploaded to: $storagePath');

      // 2. Get the public download URL for the uploaded image
      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint('Got download URL: $downloadUrl');

      // 3. Update the corresponding Firestore document
      await firestoreRef.update({
        'status':
            'accepted', // Mark the request as accepted (triggers receiver)
        'storagePath': storagePath, // Store path for potential future cleanup
        'imageUrl': downloadUrl, // Provide URL for the receiver to view
        'respondedAt': FieldValue.serverTimestamp(), // Record response time
      });
      debugPrint('Firestore updated for request: ${widget.requestId}');

      // --- FIX FOR SENDER EXPERIENCE (Issue 2) ---
      // 4. Show confirmation and navigate HOME immediately after sending.
      // This user (who just took the photo) doesn't see the countdown/image view.
      if (!mounted) return; // Double-check mounted status

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Peek Sent!'),
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate directly to the home screen ('/')
      context.go('/');
      // --- End of Fix ---
    } catch (e) {
      // Handle errors during upload or Firestore update
      debugPrint('❌ Upload or Firestore update failed: $e');
      if (mounted) {
        // Reset uploading state so the user can potentially retry
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Failed to send Peek: ${e.toString()}')),
        );
      }
    }
    // No need to reset _uploading to false on success, as navigation removes the widget.
  }

  @override
  Widget build(BuildContext context) {
    // --- Build Logic based on State ---

    // State 1: Uploading is in progress
    if (_uploading) {
      return const Scaffold(
        backgroundColor: Colors.black, // Consistent background
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Sending Peek...",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // State 2: Image has been captured, show preview and send button
    if (_imageFile != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Confirm Peek'), // Clearer title
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            // Allow user to cancel after taking photo, go home
            onPressed: () => context.go('/'),
          ),
          backgroundColor: Colors.black87, // Themed AppBar
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.black, // Consistent background
        body: Column(
          children: [
            // Expanded widget ensures Image takes available vertical space
            Expanded(
              child: Image.file(
                _imageFile!,
                fit: BoxFit.cover, // Cover ensures the image fills the area
                width: double.infinity, // Take full width
              ),
            ),
            // Padding for the send button area
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16.0,
                16.0,
                16.0,
                32.0,
              ), // Add bottom safe space
              child: SizedBox(
                width: double.infinity, // Button takes full width
                child: ElevatedButton.icon(
                  onPressed: _uploadPhoto, // Trigger the upload process
                  icon: const Icon(Icons.send),
                  label: const Text('SEND PEEK'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ), // Taller button
                    backgroundColor:
                        Theme.of(
                          context,
                        ).colorScheme.primary, // Use theme color
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // State 3: Initial state - waiting for camera, camera opening, or user cancelled
    // Show a loading indicator while the camera is initializing.
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text("Opening Camera...", style: TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  // --- End of Build Logic ---
}
// --- End of State Class Definition ---