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

import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, MessagingDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("🚀 [AppDelegate] CUSTOM APPDELEGATE STARTED - didFinishLaunchingWithOptions called")

     // CRITICAL: FirebaseApp.configure() MUST be called before any other
    // Firebase service is configured.
    FirebaseApp.configure()

    let providerFactory = MyAppCheckProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)

    GeneratedPluginRegistrant.register(with: self)

    // Set self as the delegate for UNUserNotificationCenter
    UNUserNotificationCenter.current().delegate = self

   // With Firebase AppDelegate proxy disabled, explicitly register with APNs
    DispatchQueue.main.async {
      UIApplication.shared.registerForRemoteNotifications()
    }
    Messaging.messaging().delegate = self

    // Don't force delete FCM token immediately - let it happen after APNs registration

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)

  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // Check app state - only suppress alerts when app is actually in foreground
    if UIApplication.shared.applicationState == .active {
      // App is in foreground - let Flutter handle with custom dialogs
      // Only show badge and sound, no alert banner
      completionHandler([.badge, .sound])
    } else {
      // App is in background/inactive - show full notification
      completionHandler([.alert, .badge, .sound])
    }
  }

  // Handle notification taps when app is in background or terminated
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("📱 [AppDelegate] Notification tapped: \(response.notification.request.content.userInfo)")

    // Let Firebase Messaging handle the response for Flutter
    let userInfo = response.notification.request.content.userInfo
    Messaging.messaging().appDidReceiveMessage(userInfo)

    completionHandler()
  }

  override func application(_ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
      print("🚀 [AppDelegate] didRegisterForRemoteNotificationsWithDeviceToken CALLED")
      print("✅ [AppDelegate] APNs registration successful, token length: \(deviceToken.count)")
      Messaging.messaging().apnsToken = deviceToken
      print("✅ [AppDelegate] APNs token set to Firebase Messaging")
      super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

   // Observe refreshed/initial FCM token to verify APNs→FCM mapping
  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    guard let token = fcmToken, !token.isEmpty else { return }
    print("🔁 [AppDelegate] Refreshed FCM token: \(token)")
    // No persistence here; Flutter side already saves to Firestore
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

  override func application(_ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: Error) {
      print("❌ [AppDelegate] APNs registration failed: \(error.localizedDescription)")
      super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
