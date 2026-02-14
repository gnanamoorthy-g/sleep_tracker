import Foundation

struct HeartRatePacket {
    let heartRate: Int
    let rrIntervals: [Double]
    let timestamp: Date

    var hasRRIntervals: Bool {
        !rrIntervals.isEmpty
    }

    var latestRRInterval: Double? {
        rrIntervals.last
    }
}
