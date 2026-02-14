import Foundation
import os.log

/// Thread-safe circular buffer for continuous HRV data during 24/7 monitoring
/// Prevents memory growth by keeping only recent data in memory
final class ContinuousDataBuffer<T> {

    // MARK: - Configuration
    private let maxCapacity: Int
    private let flushThreshold: Double  // Flush when buffer reaches this % of capacity

    // MARK: - Storage
    private var buffer: [T] = []
    private let queue = DispatchQueue(label: "com.sleeptracker.databuffer", attributes: .concurrent)
    private let logger = Logger(subsystem: "com.sleeptracker", category: "DataBuffer")

    // MARK: - Callbacks
    var onFlush: (([T]) -> Void)?

    // MARK: - Initialization

    /// Initialize buffer with capacity
    /// - Parameters:
    ///   - maxCapacity: Maximum number of items to keep in memory
    ///   - flushThreshold: Percentage (0.0-1.0) at which to trigger flush callback
    init(maxCapacity: Int = 600, flushThreshold: Double = 0.8) {
        self.maxCapacity = maxCapacity
        self.flushThreshold = flushThreshold
        buffer.reserveCapacity(maxCapacity)
    }

    // MARK: - Public Methods

    /// Add a new item to the buffer
    func append(_ item: T) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.buffer.append(item)

            // Check if we need to trigger flush
            let fillLevel = Double(self.buffer.count) / Double(self.maxCapacity)
            if fillLevel >= self.flushThreshold {
                self.triggerFlush()
            }

            // Remove oldest items if over capacity
            if self.buffer.count > self.maxCapacity {
                let overflow = self.buffer.count - self.maxCapacity
                self.buffer.removeFirst(overflow)
            }
        }
    }

    /// Add multiple items to the buffer
    func append(contentsOf items: [T]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.buffer.append(contentsOf: items)

            // Trim if over capacity
            if self.buffer.count > self.maxCapacity {
                let overflow = self.buffer.count - self.maxCapacity
                self.buffer.removeFirst(overflow)
            }

            // Check flush threshold
            let fillLevel = Double(self.buffer.count) / Double(self.maxCapacity)
            if fillLevel >= self.flushThreshold {
                self.triggerFlush()
            }
        }
    }

    /// Get all items currently in buffer (thread-safe copy)
    var items: [T] {
        queue.sync {
            return buffer
        }
    }

    /// Get the most recent N items
    func last(_ count: Int) -> [T] {
        queue.sync {
            return Array(buffer.suffix(count))
        }
    }

    /// Get items within a time window (requires T to have a timestamp)
    func items(since date: Date) -> [T] where T: Timestamped {
        queue.sync {
            return buffer.filter { $0.timestamp >= date }
        }
    }

    /// Current buffer size
    var count: Int {
        queue.sync {
            return buffer.count
        }
    }

    /// Whether buffer is empty
    var isEmpty: Bool {
        queue.sync {
            return buffer.isEmpty
        }
    }

    /// Current fill percentage
    var fillLevel: Double {
        queue.sync {
            return Double(buffer.count) / Double(maxCapacity)
        }
    }

    /// Clear all items from buffer
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            self?.buffer.removeAll(keepingCapacity: true)
        }
    }

    /// Force flush (e.g., when app enters background)
    func forceFlush() {
        queue.async(flags: .barrier) { [weak self] in
            self?.triggerFlush()
        }
    }

    // MARK: - Private Methods

    private func triggerFlush() {
        guard !buffer.isEmpty else { return }

        let itemsToFlush = buffer
        logger.info("Flushing \(itemsToFlush.count) items from buffer")

        // Call flush handler on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onFlush?(itemsToFlush)
        }
    }
}

// MARK: - Timestamped Protocol

protocol Timestamped {
    var timestamp: Date { get }
}

// MARK: - HRVSample Extension

extension HRVSample: Timestamped {}
