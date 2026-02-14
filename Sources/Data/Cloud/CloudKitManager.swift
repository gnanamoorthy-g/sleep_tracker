import Foundation
import CloudKit
import os.log

/// Manages CloudKit sync for sleep data
/// Uses private database only - no sharing, Apple encryption
final class CloudKitManager: ObservableObject {

    // MARK: - Published State
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: Error?

    // MARK: - Private Properties
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let logger = Logger(subsystem: "com.sleeptracker", category: "CloudKit")

    // Record Types
    private let sleepSessionRecordType = "SleepSession"
    private let dailyHRVSummaryRecordType = "DailyHRVSummary"

    // MARK: - Initialization

    init(containerIdentifier: String = "iCloud.com.sleeptracker") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
    }

    // MARK: - Account Status

    func checkAccountStatus() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                logger.info("iCloud account available")
                return true
            case .noAccount:
                logger.warning("No iCloud account")
                return false
            case .restricted:
                logger.warning("iCloud account restricted")
                return false
            case .couldNotDetermine:
                logger.warning("Could not determine iCloud status")
                return false
            case .temporarilyUnavailable:
                logger.warning("iCloud temporarily unavailable")
                return false
            @unknown default:
                return false
            }
        } catch {
            logger.error("Failed to check account status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Save Methods

    func saveSleepSession(_ session: SleepSession) async throws {
        let record = CKRecord(recordType: sleepSessionRecordType, recordID: recordID(for: session.id))

        record["sessionId"] = session.id.uuidString
        record["startTime"] = session.startTime
        record["endTime"] = session.endTime
        record["timestamp"] = Date()

        // Encode samples as JSON data
        let encoder = JSONEncoder()
        if let samplesData = try? encoder.encode(session.samples) {
            record["samplesData"] = samplesData as CKRecordValue
        }

        try await privateDatabase.save(record)
        logger.info("Saved sleep session to CloudKit: \(session.id)")
    }

    func saveDailyHRVSummary(_ summary: DailyHRVSummary) async throws {
        let record = CKRecord(recordType: dailyHRVSummaryRecordType, recordID: recordID(for: summary.id))

        record["summaryId"] = summary.id.uuidString
        record["date"] = summary.date
        record["meanHR"] = summary.meanHR
        record["minHR"] = summary.minHR
        record["maxHR"] = summary.maxHR
        record["rmssd"] = summary.rmssd
        record["lnRMSSD"] = summary.lnRMSSD
        record["sdnn"] = summary.sdnn
        record["sleepDurationMinutes"] = summary.sleepDurationMinutes
        record["deepSleepMinutes"] = summary.deepSleepMinutes
        record["lightSleepMinutes"] = summary.lightSleepMinutes
        record["remSleepMinutes"] = summary.remSleepMinutes
        record["awakeMinutes"] = summary.awakeMinutes
        record["timestamp"] = Date()

        if let baseline7d = summary.baseline7d {
            record["baseline7d"] = baseline7d
        }
        if let baseline30d = summary.baseline30d {
            record["baseline30d"] = baseline30d
        }
        if let zScore = summary.zScore {
            record["zScore"] = zScore
        }
        if let recoveryScore = summary.recoveryScore {
            record["recoveryScore"] = recoveryScore
        }
        if let sleepScore = summary.sleepScore {
            record["sleepScore"] = sleepScore
        }

        try await privateDatabase.save(record)
        logger.info("Saved HRV summary to CloudKit: \(summary.id)")
    }

    // MARK: - Fetch Methods

    func fetchAllDailyHRVSummaries() async throws -> [DailyHRVSummary] {
        let query = CKQuery(recordType: dailyHRVSummaryRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let (results, _) = try await privateDatabase.records(matching: query)

        var summaries: [DailyHRVSummary] = []
        for (_, result) in results {
            if case .success(let record) = result {
                if let summary = dailyHRVSummary(from: record) {
                    summaries.append(summary)
                }
            }
        }

        logger.info("Fetched \(summaries.count) HRV summaries from CloudKit")
        return summaries
    }

    // MARK: - Sync Methods

    func syncAll(
        localSessions: [SleepSession],
        localSummaries: [DailyHRVSummary]
    ) async {
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }

        do {
            // Upload local data
            for session in localSessions {
                try await saveSleepSession(session)
            }

            for summary in localSummaries {
                try await saveDailyHRVSummary(summary)
            }

            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }

            logger.info("Sync completed successfully")
        } catch {
            await MainActor.run {
                syncError = error
                isSyncing = false
            }
            logger.error("Sync failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Conflict Resolution

    /// Timestamp-based conflict resolution
    /// If remote.timestamp > local.timestamp → use remote
    func resolveConflict(local: CKRecord, remote: CKRecord) -> CKRecord {
        let localTimestamp = local["timestamp"] as? Date ?? Date.distantPast
        let remoteTimestamp = remote["timestamp"] as? Date ?? Date.distantPast

        if remoteTimestamp > localTimestamp {
            logger.info("Conflict resolved: using remote record")
            return remote
        } else {
            logger.info("Conflict resolved: using local record")
            return local
        }
    }

    // MARK: - Delete Methods

    func deleteSleepSession(id: UUID) async throws {
        try await privateDatabase.deleteRecord(withID: recordID(for: id))
        logger.info("Deleted sleep session from CloudKit: \(id)")
    }

    func deleteDailyHRVSummary(id: UUID) async throws {
        try await privateDatabase.deleteRecord(withID: recordID(for: id))
        logger.info("Deleted HRV summary from CloudKit: \(id)")
    }

    // MARK: - Private Helpers

    private func recordID(for uuid: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: uuid.uuidString)
    }

    private func dailyHRVSummary(from record: CKRecord) -> DailyHRVSummary? {
        guard let date = record["date"] as? Date,
              let meanHR = record["meanHR"] as? Double,
              let minHR = record["minHR"] as? Double,
              let maxHR = record["maxHR"] as? Double,
              let rmssd = record["rmssd"] as? Double,
              let sdnn = record["sdnn"] as? Double,
              let sleepDurationMinutes = record["sleepDurationMinutes"] as? Double,
              let deepSleepMinutes = record["deepSleepMinutes"] as? Double,
              let lightSleepMinutes = record["lightSleepMinutes"] as? Double,
              let remSleepMinutes = record["remSleepMinutes"] as? Double,
              let awakeMinutes = record["awakeMinutes"] as? Double else {
            return nil
        }

        let id = UUID(uuidString: record["summaryId"] as? String ?? "") ?? UUID()

        return DailyHRVSummary(
            id: id,
            date: date,
            meanHR: meanHR,
            minHR: minHR,
            maxHR: maxHR,
            rmssd: rmssd,
            sdnn: sdnn,
            sleepDurationMinutes: sleepDurationMinutes,
            deepSleepMinutes: deepSleepMinutes,
            lightSleepMinutes: lightSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            awakeMinutes: awakeMinutes,
            baseline7d: record["baseline7d"] as? Double,
            baseline30d: record["baseline30d"] as? Double,
            zScore: record["zScore"] as? Double,
            recoveryScore: record["recoveryScore"] as? Int,
            sleepScore: record["sleepScore"] as? Int
        )
    }
}
