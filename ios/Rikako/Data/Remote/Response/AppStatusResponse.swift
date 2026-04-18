import Foundation

struct AppStatusResponse: Codable {
    let minimumVersion: String
    let latestVersion: String
    let isMaintenance: Bool
    let maintenanceMessage: String
}
