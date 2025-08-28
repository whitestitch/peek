import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:peek/firebase_options.dart';
import 'package:peek/features/peek/photo_capture_page.dart';
import 'package:peek/services/notification_service.dart';

/// Handles all app initialization logic including Firebase, cameras, and system setup
class AppInitializer {
  /// Initialize all core app dependencies
  static Future<void> initialize() async {
    await _initializeFlutterBindings();
    await _initializeCameras();
    await _setupSystemConfiguration();
    await _initializeFirebase();
    await _initializeFirebaseAppCheck();
  }

  /// Initialize Flutter framework bindings
  static Future<void> _initializeFlutterBindings() async {
    WidgetsFlutterBinding.ensureInitialized();
  }

  /// Initialize camera system
  static Future<void> _initializeCameras() async {
    await initializeCameras();
  }

  /// Setup system-level configurations
  static Future<void> _setupSystemConfiguration() async {
    // Register background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Lock orientation to portrait only
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  /// Initialize Firebase Core
  static Future<void> _initializeFirebase() async {
    try {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') {
        // App already exists, just get the reference
        Firebase.app();
      } else {
        rethrow;
      }
    }
  }

  /// Initialize Firebase App Check for security
  static Future<void> _initializeFirebaseAppCheck() async {
    await FirebaseAppCheck.instance.activate(
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
      appleProvider:
          kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      androidProvider:
          kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    );
  }
}
