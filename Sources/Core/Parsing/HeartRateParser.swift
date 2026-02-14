import Foundation
import os.log

/// Pure parsing logic for BLE Heart Rate Measurement characteristic (2A37)
/// No BLE code here - only data parsing
struct HeartRateParser {

    private static let logger = Logger(subsystem: "com.sleeptracker", category: "Parser")

    /// Parse raw BLE data from Heart Rate Measurement characteristic
    /// - Parameter data: Raw data from 2A37 characteristic
    /// - Returns: Parsed HeartRatePacket or nil if parsing fails
    static func parse(_ data: Data) -> HeartRatePacket? {
        let bytes = [UInt8](data)

        guard !bytes.isEmpty else {
            logger.warning("Empty data received")
            return nil
        }

        // Log raw bytes for debugging
        let hexString = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        logger.debug("Raw data: \(hexString)")

        let flags = bytes[0]
        var index = 1

        // Bit 0: Heart Rate Value Format
        // 0 = UINT8, 1 = UINT16
        let isHeartRate16Bit = (flags & 0x01) != 0

        // Parse Heart Rate
        let heartRate: Int
        if isHeartRate16Bit {
            guard bytes.count >= 3 else {
                logger.warning("Insufficient bytes for 16-bit HR")
                return nil
            }
            heartRate = Int(bytes[1]) | (Int(bytes[2]) << 8)
            index = 3
        } else {
            guard bytes.count >= 2 else {
                logger.warning("Insufficient bytes for 8-bit HR")
                return nil
            }
            heartRate = Int(bytes[1])
            index = 2
        }

        // Bit 1-2: Sensor Contact Status
        // 00 = not supported, 01 = not supported, 10 = not detected, 11 = detected
        let sensorContactSupported = (flags & 0x04) != 0
        let sensorContactDetected = (flags & 0x02) != 0

        if sensorContactSupported && !sensorContactDetected {
            logger.debug("Sensor contact not detected")
        }

        // Bit 3: Energy Expended Present
        let isEnergyExpendedPresent = (flags & 0x08) != 0
        if isEnergyExpendedPresent {
            index += 2  // Skip 2 bytes for energy expended
        }

        // Bit 4: RR-Interval Present
        let isRRIntervalPresent = (flags & 0x10) != 0

        // Parse RR Intervals
        var rrIntervals: [Double] = []

        if isRRIntervalPresent {
            while index + 1 < bytes.count {
                // RR intervals are 16-bit little-endian, in 1/1024 seconds
                let rrRaw = UInt16(bytes[index]) | (UInt16(bytes[index + 1]) << 8)

                // Convert to milliseconds: rr_ms = rrRaw * (1000 / 1024)
                let rrMs = Double(rrRaw) * (1000.0 / 1024.0)

                // Validate RR interval (typically 300-2000ms for normal HR)
                if rrMs >= 200 && rrMs <= 2500 {
                    rrIntervals.append(rrMs)
                } else {
                    logger.warning("Invalid RR interval: \(rrMs)ms - skipping")
                }

                index += 2
            }
        }

        logger.debug("HR: \(heartRate) BPM, RR intervals: \(rrIntervals.count)")

        return HeartRatePacket(
            heartRate: heartRate,
            rrIntervals: rrIntervals,
            timestamp: Date()
        )
    }
}
