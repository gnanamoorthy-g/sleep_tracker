import Foundation

enum BLEError: Error, LocalizedError {
    case bluetoothUnavailable
    case bluetoothUnauthorized
    case deviceNotFound
    case connectionFailed(Error?)
    case serviceNotFound
    case characteristicNotFound
    case notificationFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .bluetoothUnavailable:
            return "Bluetooth is not available on this device"
        case .bluetoothUnauthorized:
            return "Bluetooth access is not authorized"
        case .deviceNotFound:
            return "Heart rate monitor not found"
        case .connectionFailed(let error):
            return "Connection failed: \(error?.localizedDescription ?? "Unknown error")"
        case .serviceNotFound:
            return "Heart Rate Service not found on device"
        case .characteristicNotFound:
            return "Heart Rate Measurement characteristic not found"
        case .notificationFailed(let error):
            return "Failed to enable notifications: \(error?.localizedDescription ?? "Unknown error")"
        }
    }
}
