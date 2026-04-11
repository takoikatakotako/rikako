import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    let versionText = "1.0.0"

    func answeredText(totalAnswered: Int) -> String {
        "\(totalAnswered)問"
    }
}
