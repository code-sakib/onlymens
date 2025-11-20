import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    private let screenTimeManager = ScreenTimeManager()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        
        // ⚠️ IMPORTANT: This name must match your Dart code exactly!
        // Change to "cleanmind/screentime" if that's what you use in Dart
        let screenTimeChannel = FlutterMethodChannel(
            name: "cleanmind/screentime",  // ✅ Updated to match Dart
            binaryMessenger: controller.binaryMessenger
        )
        
        screenTimeChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            guard let self = self else {
                result(FlutterError(code: "INTERNAL_ERROR",
                                  message: "Self reference lost",
                                  details: nil))
                return
            }
            
            switch call.method {
            case "requestAuthorization":
                self.screenTimeManager.requestAuthorization(result)
                
            case "enablePornBlock":
                guard let args = call.arguments as? [String: Any],
                      let domains = args["domains"] as? [String] else {
                    result(FlutterError(
                        code: "INVALID_ARGUMENTS",
                        message: "Expected dictionary with 'domains' key of type [String]",
                        details: nil
                    ))
                    return
                }
                self.screenTimeManager.enablePornBlock(domains, result: result)
                
            case "disablePornBlock":
                self.screenTimeManager.disablePornBlock(result: result)

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
