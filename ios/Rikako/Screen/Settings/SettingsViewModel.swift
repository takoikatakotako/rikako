import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

enum UserPreferencesKey {
    static let soundEnabled = "soundEnabled"
    static let hapticEnabled = "hapticEnabled"
}
