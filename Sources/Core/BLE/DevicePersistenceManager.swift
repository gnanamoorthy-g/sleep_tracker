import Foundation
import os.log

/// Manages persistence of known BLE devices for auto-reconnection
final class DevicePersistenceManager {

    // MARK: - Singleton
    static let shared = DevicePersistenceManager()

    // MARK: - Constants
    private let userDefaultsKey = "com.sleeptracker.lastDevice"
    private let logger = Logger(subsystem: "com.sleeptracker", category: "DevicePersistence")

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Save device information for future auto-connect
    func saveDevice(uuid: String, name: String) {
        let device = PersistedDevice(uuid: uuid, name: name)

        do {
            let data = try JSONEncoder().encode(device)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            logger.info("Saved device: \(name) (\(uuid))")
        } catch {
            logger.error("Failed to save device: \(error.localizedDescription)")
        }
    }

    /// Load the last connected device
    func loadDevice() -> PersistedDevice? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            logger.info("No saved device found")
            return nil
        }

        do {
            let device = try JSONDecoder().decode(PersistedDevice.self, from: data)
            logger.info("Loaded device: \(device.name) (\(device.uuid))")
            return device
        } catch {
            logger.error("Failed to load device: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clear saved device (user manually disconnects)
    func clearDevice() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        logger.info("Cleared saved device")
    }

    /// Check if we have a saved device and should attempt auto-connect
    func shouldAutoConnect() -> Bool {
        return loadDevice() != nil
    }

    /// Update the last connected timestamp for existing device
    func updateLastConnected() {
        guard let device = loadDevice() else { return }
        saveDevice(uuid: device.uuid, name: device.name)
    }
}
