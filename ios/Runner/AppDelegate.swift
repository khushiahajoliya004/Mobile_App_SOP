import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        // Register native audio recorder plugin
        if let controller = window?.rootViewController as? FlutterViewController {
            AudioRecorderPlugin.register(
                with: controller.registrar(forPlugin: "AudioRecorderPlugin")!
            )
        }
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
