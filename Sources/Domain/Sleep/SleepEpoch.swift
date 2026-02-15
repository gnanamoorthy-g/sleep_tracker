import Foundation

struct SleepEpoch: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let endTime: Date

    let averageHR: Double
    let averageRMSSD: Double
    let hrStdDev: Double

    var phase: SleepPhase?

    // Duration in seconds (typically 30 seconds)
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        averageHR: Double,
        averageRMSSD: Double,
        hrStdDev: Double,
        phase: SleepPhase? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.averageHR = averageHR
        self.averageRMSSD = averageRMSSD
        self.hrStdDev = hrStdDev
        self.phase = phase
    }
}

// MARK: - Sleep Session Summary
struct SleepSummary: Codable {
    let totalDuration: TimeInterval
    let sleepScore: Int

    let awakeMinutes: Double
    let lightMinutes: Double
    let deepMinutes: Double
    let remMinutes: Double

    let averageHR: Double
    let minHR: Double
    let maxHR: Double

    let averageRMSSD: Double
    let hrvRecoveryRatio: Double

    let awakenings: Int

    var deepSleepPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (deepMinutes / (totalDuration / 60)) * 100
    }

    var remSleepPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (remMinutes / (totalDuration / 60)) * 100
    }

    var lightSleepPercentage: Double {
        guard totalDuration > 0 else { return 0 }
        return (lightMinutes / (totalDuration / 60)) * 100
    }

    var sleepEfficiency: Double {
        guard totalDuration > 0 else { return 0 }
        let actualSleep = lightMinutes + deepMinutes + remMinutes
        return (actualSleep / (totalDuration / 60)) * 100
    }
}
