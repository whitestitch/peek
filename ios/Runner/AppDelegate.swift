import Flutter
import UIKit
import FirebaseCore

import FirebaseAppCheck
// A new class that provides the debug provider in debug builds
class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
  func createProvider(with app: FirebaseApp) -> AppCheckProvider? {

      // Use the debug provider for debug builds.
      return AppCheckDebugProvider(app: app)
  }
}

import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate { // MODIFIED: Removed ', UNUserNotificationCenterDelegate'

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

     // CRITICAL: FirebaseApp.configure() MUST be called before any other
    // Firebase service is configured.
    FirebaseApp.configure()

    let providerFactory = MyAppCheckProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)

    GeneratedPluginRegistrant.register(with: self)

    // Set self as the delegate for UNUserNotificationCenter
    UNUserNotificationCenter.current().delegate = self

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // iOS to show the notification using the standard system UI
    completionHandler([.alert, .badge, .sound])
  }

  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      Messaging.messaging().apnsToken = deviceToken
      super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
      _ application: UIApplication,
      didReceiveRemoteNotification userInfo: [AnyHashable : Any],
      fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
      // MODIFIED: Pass the notification to Firebase Messaging without the 'if' check
      Messaging.messaging().appDidReceiveMessage(userInfo)
      completionHandler(.newData)
  }
}
