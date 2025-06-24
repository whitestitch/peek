import Flutter
import UIKit
import FirebaseCore
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate { // MODIFIED: Removed ', UNUserNotificationCenterDelegate'

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
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
    // By calling the completion handler with an empty array, we tell iOS to
    // suppress the system notification, allowing our Flutter UI to handle it.
    completionHandler([])
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