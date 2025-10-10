import Foundation
import ManagedSettings
import DeviceActivity
import FamilyControls

// Ensure this extension is part of both targets!
extension DeviceActivityName {
    static let blockApps = Self("blockApps")
}

class AppMonitor {
    private let managedSettingsStore = ManagedSettingsStore()
    private let deviceActivityCenter = DeviceActivityCenter()
    
    func applyRestrictions(selection: FamilyActivitySelection) {
        // FIX: Use .applicationTokens
        let applicationTokens = selection.applicationTokens
        
        if applicationTokens.isEmpty {
            managedSettingsStore.shield.applications = []
            deviceActivityCenter.stopMonitoring()
        } else {
            managedSettingsStore.shield.applications = applicationTokens
            print("here")
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: 0, minute: 0),
                intervalEnd: DateComponents(hour: 23, minute: 59),
                repeats: true
            )
            print("here2")
            do {
                // FIX: Referencing the shared static member
                try deviceActivityCenter.startMonitoring(.blockApps, during: schedule)
            } catch {
                print("Error monitoring activity: \(error)")
            }
        }
    }
    
    func clearRestrictions() {
        managedSettingsStore.shield.applications = []
        deviceActivityCenter.stopMonitoring()
    }
}
