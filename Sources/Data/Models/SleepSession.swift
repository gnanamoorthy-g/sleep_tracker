import Foundation

struct SleepSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var samples: [HRVSample]

    var isActive: Bool {
        endTime == nil
    }

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }

    var averageHeartRate: Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0) { $0 + $1.heartRate }
        return Double(total) / Double(samples.count)
    }

    var averageRMSSD: Double? {
        let validRMSSD = samples.compactMap { $0.rmssd }
        guard !validRMSSD.isEmpty else { return nil }
        return validRMSSD.reduce(0, +) / Double(validRMSSD.count)
    }

    var minHeartRate: Int? {
        samples.map { $0.heartRate }.min()
    }

    var maxHeartRate: Int? {
        samples.map { $0.heartRate }.max()
    }

    init(id: UUID = UUID(), startTime: Date = Date()) {
        self.id = id
        self.startTime = startTime
        self.endTime = nil
        self.samples = []
    }

    mutating func addSample(_ sample: HRVSample) {
        samples.append(sample)
    }

    mutating func end() {
        endTime = Date()
    }
}
