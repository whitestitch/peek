import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

/// Handles photo capture, processing, and upload logic
class PhotoCaptureLogic {
  // State
  bool _isTakingPicture = false;
  bool _uploading = false;
  Uint8List? _capturedImageBytes;
  File? _tempProcessedFile;

  // Callbacks
  final VoidCallback? onCaptureStart;
  final VoidCallback? onCaptureComplete;
  final VoidCallback? onUploadStart;
  final VoidCallback? onUploadComplete;
  final ValueChanged<String>? onError;
  final ValueChanged<String>? onUploadSuccess;

  PhotoCaptureLogic({
    this.onCaptureStart,
    this.onCaptureComplete,
    this.onUploadStart,
    this.onUploadComplete,
    this.onError,
    this.onUploadSuccess,
  });

  // Getters
  bool get isTakingPicture => _isTakingPicture;
  bool get uploading => _uploading;
  Uint8List? get capturedImageBytes => _capturedImageBytes;
  File? get tempProcessedFile => _tempProcessedFile;

  /// Capture photo with flip logic for front camera
  Future<void> takePicture({
    required CameraController? controller,
    required bool isFrontCamera,
  }) async {
    if (_isTakingPicture ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    _isTakingPicture = true;
    onCaptureStart?.call();

    try {
      debugPrint("[PhotoCapture] Taking picture...");
      final XFile imageFile = await controller.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Process image (flip if front camera)
      Uint8List processedBytes = imageBytes;
      if (isFrontCamera) {
        processedBytes = await _flipImageHorizontally(imageBytes);
      }

      _capturedImageBytes = processedBytes;
      debugPrint("[PhotoCapture] Picture captured successfully");
      onCaptureComplete?.call();
    } catch (e) {
      debugPrint("[PhotoCapture] Error taking picture: $e");
      onError?.call("Failed to capture photo: $e");
    } finally {
      _isTakingPicture = false;
    }
  }

  /// Flip image horizontally for front camera
  Future<Uint8List> _flipImageHorizontally(Uint8List imageBytes) async {
    try {
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        debugPrint("[PhotoCapture] Failed to decode image for flipping");
        return imageBytes; // Return original if decode fails
      }

      final img.Image flippedImage = img.flipHorizontal(originalImage);
      final Uint8List flippedBytes =
          Uint8List.fromList(img.encodeJpg(flippedImage));

      debugPrint("[PhotoCapture] Image flipped successfully");
      return flippedBytes;
    } catch (e) {
      debugPrint("[PhotoCapture] Error flipping image: $e");
      return imageBytes; // Return original if flip fails
    }
  }

  /// Upload photo to Firebase Storage
  Future<void> uploadPhoto({
    required String requestId,
    String? senderLocation,
  }) async {
    if (_capturedImageBytes == null || _uploading) return;

    _uploading = true;
    onUploadStart?.call();

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'peeks/$requestId/$timestamp.jpg';

      debugPrint("[PhotoCapture] Uploading to: $storagePath");

      // Upload to Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      final uploadTask = ref.putData(
        _capturedImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint("[PhotoCapture] Upload successful: $downloadUrl");

      // Update Firestore with image URL and location
      await _updateFirestoreWithImage(
        requestId: requestId,
        imageUrl: downloadUrl,
        senderLocation: senderLocation,
      );

      onUploadSuccess?.call(downloadUrl);
    } catch (e) {
      debugPrint("[PhotoCapture] Upload failed: $e");
      onError?.call("Upload failed: $e");
    } finally {
      _uploading = false;
      onUploadComplete?.call();
    }
  }

  /// Update Firestore with image URL and metadata
  Future<void> _updateFirestoreWithImage({
    required String requestId,
    required String imageUrl,
    String? senderLocation,
  }) async {
    try {
      final updateData = {
        'status': 'responded_with_image',
        'imageUrl': imageUrl,
        'respondedAt': FieldValue.serverTimestamp(),
      };

      // Add location if provided
      if (senderLocation != null && senderLocation.isNotEmpty) {
        updateData['senderLocation'] = senderLocation;
      }

      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update(updateData);

      debugPrint("[PhotoCapture] Firestore updated successfully");
    } catch (e) {
      debugPrint("[PhotoCapture] Firestore update failed: $e");
      throw Exception("Failed to update request status: $e");
    }
  }

  /// Retake picture (clear current capture)
  void retakePicture() {
    _capturedImageBytes = null;
    _deleteTempFile();
    debugPrint("[PhotoCapture] Picture cleared for retake");
  }

  /// Delete temporary processed file
  Future<void> _deleteTempFile() async {
    if (_tempProcessedFile != null && await _tempProcessedFile!.exists()) {
      try {
        await _tempProcessedFile!.delete();
        debugPrint("[PhotoCapture] Temporary file deleted");
      } catch (e) {
        debugPrint("[PhotoCapture] Error deleting temp file: $e");
      }
      _tempProcessedFile = null;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _deleteTempFile();
    _capturedImageBytes = null;
  }
}
