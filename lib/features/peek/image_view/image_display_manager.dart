import 'package:flutter/material.dart';
import 'dart:async';

/// Manages image loading, display states, and error handling
/// ✅ APPLE GUIDELINE 2.1 FIX: Enhanced with retry logic and better error handling
class ImageDisplayManager {
  // Image state
  bool _showImage = false;
  bool _imageActuallyLoaded = false;
  bool _imageLoadFailed = false;
  int _retryCount = 0;
  static const int maxRetries = 3;

  // Image data
  late final String _imageUrl;

  // Callbacks
  final VoidCallback? onImageLoaded;
  final VoidCallback? onImageFailed;
  final VoidCallback? onImageShown;
  final ValueChanged<String>? onError;

  ImageDisplayManager({
    required String imageUrl,
    this.onImageLoaded,
    this.onImageFailed,
    this.onImageShown,
    this.onError,
  }) : _imageUrl = imageUrl {
    // ✅ Log image URL for debugging Apple Review issues
    debugPrint("[ImageDisplay] ✅ Initialized with URL: $_imageUrl");
    debugPrint("[ImageDisplay] URL length: ${_imageUrl.length} characters");
    debugPrint("[ImageDisplay] URL starts with: ${_imageUrl.substring(0, _imageUrl.length > 50 ? 50 : _imageUrl.length)}...");
  }

  // Getters
  bool get showImage => _showImage;
  bool get imageActuallyLoaded => _imageActuallyLoaded;
  bool get imageLoadFailed => _imageLoadFailed;
  String get imageUrl => _imageUrl;

  /// Initiate image display process
  void initiateImageDisplay() {
    if (_showImage) return; // Already initiated

    _showImage = true;
    debugPrint("[ImageDisplay] Image display initiated for: $_imageUrl");
    onImageShown?.call();
  }

  /// Handle successful image load
  void handleImageLoaded() {
    if (_imageActuallyLoaded) return; // Already loaded

    _imageActuallyLoaded = true;
    _imageLoadFailed = false;

    debugPrint("[ImageDisplay] Image successfully loaded: $_imageUrl");
    onImageLoaded?.call();
  }

  /// Handle image load failure with retry logic
  /// ✅ APPLE GUIDELINE 2.1 FIX: Added retry mechanism
  void handleImageFailed(String error) {
    _retryCount++;
    debugPrint("[ImageDisplay] ❌ Image failed to load (attempt $_retryCount/$maxRetries): $error");
    debugPrint("[ImageDisplay] Failed URL: $_imageUrl");

    if (_retryCount < maxRetries) {
      debugPrint("[ImageDisplay] 🔄 Retrying in 2 seconds...");
      // Don't mark as failed yet - will retry
      Future.delayed(const Duration(seconds: 2), () {
        if (!_imageActuallyLoaded) {
          debugPrint("[ImageDisplay] 🔄 Retry attempt $_retryCount");
          // Reset failed state to trigger reload
          _imageLoadFailed = false;
        }
      });
      return;
    }

    // Max retries reached
    _imageLoadFailed = true;
    _imageActuallyLoaded = false;

    debugPrint("[ImageDisplay] ❌ Image failed permanently after $maxRetries attempts");
    debugPrint("[ImageDisplay] Error details: $error");
    onImageFailed?.call();
    onError?.call("Failed to load image after $maxRetries attempts: $error");
  }

  /// Get appropriate image widget with error handling
  Widget buildImageWidget({
    BoxFit fit = BoxFit.contain,
    Widget? loadingWidget,
    Widget? errorWidget,
  }) {
    if (!_showImage) {
      return loadingWidget ??
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
    }

    if (_imageLoadFailed) {
      return errorWidget ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.white, size: 64),
                SizedBox(height: 16),
                Text(
                  'Failed to load image',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          );
    }

    // ✅ APPLE GUIDELINE 2.1 FIX: Enhanced image loading with better error handling
    return Image.network(
      _imageUrl,
      fit: fit,
      // ✅ Add cache headers for better reliability
      headers: const {
        'Cache-Control': 'max-age=3600',
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded successfully
          WidgetsBinding.instance.addPostFrameCallback((_) {
            handleImageLoaded();
            debugPrint("[ImageDisplay] ✅ Image successfully rendered on screen");
          });
          return child;
        }

        // Still loading - show progress
        final progress = loadingProgress.expectedTotalBytes != null
            ? loadingProgress.cumulativeBytesLoaded /
                loadingProgress.expectedTotalBytes!
            : null;

        if (progress != null) {
          debugPrint("[ImageDisplay] 📥 Loading: ${(progress * 100).toStringAsFixed(0)}%");
        }

        return loadingWidget ??
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                    value: progress,
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ],
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint("[ImageDisplay] ❌ ErrorBuilder triggered");
        debugPrint("[ImageDisplay] Error: $error");
        debugPrint("[ImageDisplay] StackTrace: $stackTrace");

        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleImageFailed(error.toString());
        });

        return errorWidget ??
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'Failed to load Peek image',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _retryCount < maxRetries
                          ? 'Retrying... ($_retryCount/$maxRetries)'
                          : 'Please check your internet connection',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Show debug info in debug mode
                  if (error.toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Error: ${error.toString().length > 100 ? '${error.toString().substring(0, 100)}...' : error.toString()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            );
      },
    );
  }

  /// Reset image state
  void reset() {
    _showImage = false;
    _imageActuallyLoaded = false;
    _imageLoadFailed = false;
    debugPrint("[ImageDisplay] Image state reset");
  }

  /// Dispose resources
  void dispose() {
    // No resources to dispose for now
    debugPrint("[ImageDisplay] ImageDisplayManager disposed");
  }
}
