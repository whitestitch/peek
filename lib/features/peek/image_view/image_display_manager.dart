import 'package:flutter/material.dart';

/// Manages image loading, display states, and error handling
class ImageDisplayManager {
  // Image state
  bool _showImage = false;
  bool _imageActuallyLoaded = false;
  bool _imageLoadFailed = false;

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
  }) : _imageUrl = imageUrl;

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

  /// Handle image load failure
  void handleImageFailed(String error) {
    _imageLoadFailed = true;
    _imageActuallyLoaded = false;

    debugPrint("[ImageDisplay] Image failed to load: $error");
    onImageFailed?.call();
    onError?.call("Failed to load image: $error");
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

    return Image.network(
      _imageUrl,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          // Image loaded successfully
          WidgetsBinding.instance.addPostFrameCallback((_) {
            handleImageLoaded();
          });
          return child;
        }

        // Still loading
        return loadingWidget ??
            Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          handleImageFailed(error.toString());
        });

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
