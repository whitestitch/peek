import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Handles location services for photo capture
class LocationService {
  bool _isFetchingLocation = false;

  // Callbacks
  final VoidCallback? onLocationStart;
  final VoidCallback? onLocationComplete;
  final ValueChanged<String>? onError;
  final ValueChanged<String>? onLocationSuccess;

  LocationService({
    this.onLocationStart,
    this.onLocationComplete,
    this.onError,
    this.onLocationSuccess,
  });

  // Getters
  bool get isFetchingLocation => _isFetchingLocation;

  /// Get current user's city
  Future<String?> getCurrentUserCity() async {
    if (_isFetchingLocation) return null;

    _isFetchingLocation = true;
    onLocationStart?.call();

    try {
      debugPrint("[LocationService] Requesting location permission...");

      // Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      debugPrint("[LocationService] Getting current position...");

      // Get current position with timeout
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
          "[LocationService] Position: ${position.latitude}, ${position.longitude}");

      // Reverse geocode to get city
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String city =
            place.locality ?? place.subAdministrativeArea ?? 'Unknown';

        debugPrint("[LocationService] City found: $city");
        onLocationSuccess?.call(city);
        return city;
      } else {
        throw Exception('No location information found');
      }
    } catch (e) {
      debugPrint("[LocationService] Error getting location: $e");
      onError?.call("Location error: $e");
      return null;
    } finally {
      _isFetchingLocation = false;
      onLocationComplete?.call();
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint("[LocationService] Error checking location service: $e");
      return false;
    }
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      debugPrint("[LocationService] Error checking permission: $e");
      return LocationPermission.denied;
    }
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      debugPrint("[LocationService] Error requesting permission: $e");
      return LocationPermission.denied;
    }
  }
}
