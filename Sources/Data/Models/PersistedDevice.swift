import Foundation

/// Model for persisting device information across app launches
struct PersistedDevice: Codable, Equatable {
    let uuid: String
    let name: String
    let lastConnected: Date

    init(uuid: String, name: String, lastConnected: Date = Date()) {
        self.uuid = uuid
        self.name = name
        self.lastConnected = lastConnected
    }
}
