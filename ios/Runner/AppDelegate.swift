// AppDelegate.swift
import UIKit
import Flutter
import ManagedSettings
import FamilyControls
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate, ExampleViewDelegate {
    
    private var channel: FlutterMethodChannel?
    private let appMonitor = AppMonitor()

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        channel = FlutterMethodChannel(
            name: "com.sakib.onlymens/channel",
            binaryMessenger: controller.binaryMessenger
        )

        channel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "requestAuthorization":
                Task {
                    do {
                        do {
                            try await AuthorizationCenter.shared.requestAuthorization(for: .child)
                            result(true)
                        } catch {
                            result(false)
                            print("auth failed: \(error.localizedDescription)")
                        }
                            
                        result(true)
                    }
                    
//                    catch {
//                        print("❌ Child authorization failed: \(error.localizedDescription)")
//                        result(false)
//                    }
                }
            
            case "listapps":
                if #available(iOS 16.0, *) {
                    var exampleView = ExampleView()
                    exampleView.delegate = self // Set the delegate
                    let hostingController = UIHostingController(rootView: exampleView)
                    controller.present(hostingController, animated: true)
                    result(true)
                } else {
                    result(FlutterError(code: "UNSUPPORTED_OS", message: "Requires iOS 16+", details: nil))
                }

            case "unblockApps":
                self?.appMonitor.clearRestrictions()
                result(true)

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        if let data = UserDefaults.standard.data(forKey: "lastSelection"),
           let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            appMonitor.applyRestrictions(selection: selection)
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - ExampleViewDelegate
    func didUpdateSelection(selection: FamilyActivitySelection) {
        appMonitor.applyRestrictions(selection: selection)
        
        // Save selection for later use
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: "lastSelection")
        }
        
        let bundleIds = selection.applications.map { $0.bundleIdentifier }
        channel?.invokeMethod("onAppSelectionUpdated", arguments: bundleIds)
    }

}
