import Foundation
import FamilyControls
import ManagedSettings

@objc class ScreenTimeManager: NSObject {

    private let store = ManagedSettingsStore()

    // MARK: - Request Authorization
    @objc func requestAuthorization(_ result: @escaping FlutterResult) {
        Task { @MainActor in
            do {
                try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                let status = AuthorizationCenter.shared.authorizationStatus
                result(status == .approved)
            } catch {
                print("Screen Time auth error: \(error.localizedDescription)")
                result(false)
            }
        }
    }

    // MARK: - Enable Porn Block
    @objc func enablePornBlock(_ domains: [String]) {
        Task { @MainActor in
            // Build token set from domains
            let tokens: Set<WebDomainToken> = Set(domains.compactMap {
                WebDomain(domain: $0).token
            })

            guard !tokens.isEmpty else {
                print("⚠️ No valid domains")
                return
            }

            // Block the listed domains
            store.shield.webDomains = tokens
            
            print("✅ Applied shield to \(tokens.count) domains")
        }
    }

    // MARK: - Disable Porn Block
    @objc func disablePornBlock() {
        Task { @MainActor in
            store.shield.webDomains = nil
            store.shield.webDomainCategories = nil
            print("✅ Content blocking disabled")
        }
    }

    // MARK: - Check Authorization
    @objc func checkAuthorizationStatus() -> Bool {
        AuthorizationCenter.shared.authorizationStatus == .approved
    }
}
