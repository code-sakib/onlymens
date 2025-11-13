// ios/Runner/AppDelegate.swift

import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    // Create a single instance of the manager
    private let screenTimeManager = ScreenTimeManager()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        // The name here MUST match the one in your Dart code
        let screenTimeChannel = FlutterMethodChannel(name: "onlymens/screentime",
                                                   binaryMessenger: controller.binaryMessenger)
        
        // Set up the handler for incoming calls from Flutter
        screenTimeChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            // Ensure we have a reference to our manager
            guard let self = self else { return }
            
            // Route calls based on the method name
            switch call.method {
            case "requestAuthorization":
                self.screenTimeManager.requestAuthorization(result)
                
            case "enablePornBlock":
                // Safely extract the arguments sent from Flutter
                guard let args = call.arguments as? [String: Any],
                      let domains = args["domains"] as? [String] else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Expected a dictionary with a 'domains' key of type [String]", details: nil))
                    return
                }
                self.screenTimeManager.enablePornBlock(domains)
                result(nil) // Indicate success with no return value
                
            case "disablePornBlock":
                self.screenTimeManager.disablePornBlock()
                result(nil) // Indicate success with no return value

            case "checkAuthorizationStatus":
                let isApproved = self.screenTimeManager.checkAuthorizationStatus()
                result(isApproved)
                
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
