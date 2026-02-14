import Foundation

struct HRVSample: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let heartRate: Int
    let rrIntervals: [Double]
    let rmssd: Double?

    init(timestamp: Date = Date(),
         heartRate: Int,
         rrIntervals: [Double],
         rmssd: Double? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.rrIntervals = rrIntervals
        self.rmssd = rmssd
    }

    init(from packet: HeartRatePacket, rmssd: Double? = nil) {
        self.id = UUID()
        self.timestamp = packet.timestamp
        self.heartRate = packet.heartRate
        self.rrIntervals = packet.rrIntervals
        self.rmssd = rmssd
    }
}
