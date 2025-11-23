import 'dart:async'; // 🔧 APPLE REVIEW FIX: For TimeoutException
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  /// Capture photo - back camera only (no flip needed)
  Future<void> takePicture({
    required CameraController? controller,
  }) async {
    if (_isTakingPicture ||
        controller == null ||
        !controller.value.isInitialized) {
      debugPrint(
          "[PhotoCapture] Take picture blocked: _isTakingPicture=$_isTakingPicture, controller=${controller != null}, initialized=${controller?.value.isInitialized}");
      return;
    }

    _isTakingPicture = true;
    onCaptureStart?.call();

    try {
      debugPrint("[PhotoCapture] Taking picture...");
      final XFile imageFile = await controller.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      // No flip needed for back camera
      _capturedImageBytes = imageBytes;
      debugPrint("[PhotoCapture] Picture captured successfully");
      onCaptureComplete?.call();
    } catch (e) {
      debugPrint("[PhotoCapture] Error taking picture: $e");
      onError?.call("Failed to capture photo: $e");
      // Reset state on error
      _capturedImageBytes = null;
    } finally {
      _isTakingPicture = false;
    }
  }

  /// Flip image horizontally for front camera - REMOVED: Only back camera allowed
  // Future<Uint8List> _flipImageHorizontally(Uint8List imageBytes) async {
  //   try {
  //     final img.Image? originalImage = img.decodeImage(imageBytes);
  //     if (originalImage == null) {
  //       debugPrint("[PhotoCapture] Failed to decode image for flipping");
  //       return imageBytes; // Return original if decode fails
  //     }

  //     final img.Image flippedImage = img.flipHorizontal(originalImage);
  //     final Uint8List flippedBytes =
  //         Uint8List.fromList(img.encodeJpt(flippedImage));

  //     debugPrint("[PhotoCapture] Image flipped successfully");
  //     return flippedBytes;
  //   } catch (e) {
  //       debugPrint("[PhotoCapture] Error flipping image: $e");
  //       return imageBytes; // Return original if flip fails
  //     }
  // }

  /// Upload photo to Firebase Storage
  /// 🔧 APPLE REVIEW FIX: Added timeout protection and retry logic
  Future<void> uploadPhoto({
    required String requestId,
    required String senderUid, // Add required senderUid parameter
    String? senderLocation,
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) async {
    if (_capturedImageBytes == null || _uploading) {
      debugPrint(
          "[PhotoCapture] Upload blocked: _capturedImageBytes=${_capturedImageBytes != null}, _uploading=$_uploading");
      return;
    }

    _uploading = true;
    onUploadStart?.call();

    // 🔧 APPLE REVIEW FIX: Retry logic for image upload
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        debugPrint(
            "[PhotoCapture] Upload attempt ${retryCount + 1}/${maxRetries + 1}");

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = 'peeks/$requestId/$timestamp.jpg';

        debugPrint("[PhotoCapture] Uploading to: $storagePath");

        // Upload to Firebase Storage with timeout protection
        final ref = FirebaseStorage.instance.ref().child(storagePath);
        final uploadTask = ref.putData(
          _capturedImageBytes!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        // 🔧 APPLE REVIEW FIX: Add timeout to upload operation (90 seconds)
        final snapshot = await uploadTask.timeout(
          const Duration(seconds: 90),
          onTimeout: () {
            debugPrint("[PhotoCapture] Upload timed out after 90 seconds");
            throw TimeoutException('Upload timed out');
          },
        );

        final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            debugPrint("[PhotoCapture] Getting download URL timed out");
            throw TimeoutException('Getting download URL timed out');
          },
        );

        debugPrint("[PhotoCapture] Upload successful: $downloadUrl");

        // Update Firestore with image URL and location
        await _updateFirestoreWithImage(
          requestId: requestId,
          imageUrl: downloadUrl,
          senderUid: senderUid, // Pass senderUid to the update method
          senderLocation: senderLocation,
          senderDisplayName: senderDisplayName,
          senderAvatarUrl: senderAvatarUrl,
        );

        onUploadSuccess?.call(downloadUrl);
        _uploading = false;
        onUploadComplete?.call();
        return; // Success - exit the retry loop

      } on TimeoutException catch (e) {
        debugPrint(
            "[PhotoCapture] Timeout on attempt ${retryCount + 1}: $e");

        // 🔧 APPLE REVIEW FIX: Retry on timeout
        if (retryCount < maxRetries) {
          retryCount++;
          debugPrint(
              "[PhotoCapture] Retrying upload (attempt $retryCount/$maxRetries)...");
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }

        onError?.call("Upload is taking longer than expected. Please try again.");
      } on FirebaseException catch (e) {
        debugPrint(
            "[PhotoCapture] Firebase error on attempt ${retryCount + 1}: ${e.code} - ${e.message}");

        // 🔧 APPLE REVIEW FIX: Retry on network errors
        if ((e.code == 'unavailable' ||
             e.code == 'deadline-exceeded' ||
             e.code == 'cancelled') &&
            retryCount < maxRetries) {
          retryCount++;
          debugPrint(
              "[PhotoCapture] Retrying after network error (attempt $retryCount/$maxRetries)...");
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }

        onError?.call("Upload failed. Please check your connection and try again.");
      } catch (e) {
        debugPrint("[PhotoCapture] Upload error on attempt ${retryCount + 1}: $e");

        // 🔧 APPLE REVIEW FIX: Retry on general errors
        if (retryCount < maxRetries) {
          retryCount++;
          debugPrint(
              "[PhotoCapture] Retrying upload (attempt $retryCount/$maxRetries)...");
          await Future.delayed(Duration(seconds: retryCount * 2));
          continue;
        }

        onError?.call("Upload failed: $e");
      }
    }

    // If we get here, all retries failed
    _uploading = false;
    onUploadComplete?.call();
  }

  /// Update Firestore with image URL and metadata
  Future<void> _updateFirestoreWithImage({
    required String requestId,
    required String imageUrl,
    required String senderUid, // Add required senderUid parameter
    String? senderLocation,
    String? senderDisplayName,
    String? senderAvatarUrl,
  }) async {
    try {
      final updateData = {
        'status': 'responded_with_image',
        'imageUrl': imageUrl,
        'respondedAt': FieldValue.serverTimestamp(),
        'senderId':
            senderUid, // Add the senderId field that Cloud Function needs
      };

      // Add sender information if provided
      if (senderDisplayName != null && senderDisplayName.isNotEmpty) {
        updateData['senderDisplayName'] = senderDisplayName;
      }

      if (senderAvatarUrl != null && senderAvatarUrl.isNotEmpty) {
        updateData['senderAvatarUrl'] = senderAvatarUrl;
      }

      // Add location if provided
      if (senderLocation != null && senderLocation.isNotEmpty) {
        updateData['senderLocation'] = senderLocation;
      }

      await FirebaseFirestore.instance
          .collection('peek_requests')
          .doc(requestId)
          .update(updateData);

      debugPrint(
          "[PhotoCapture] Firestore updated successfully with sender info: $senderDisplayName");
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
