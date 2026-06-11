import Flutter
import UIKit
import Firebase
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self

        GeneratedPluginRegistrant.register(with: self)

        // Register native audio recorder plugin
        if let controller = window?.rootViewController as? FlutterViewController {
            AudioRecorderPlugin.register(
                with: controller.registrar(forPlugin: "AudioRecorderPlugin")!
            )
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // Show notifications when app is in foreground
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .badge, .sound])
        } else {
            completionHandler([.alert, .badge, .sound])
        }
    }
}
