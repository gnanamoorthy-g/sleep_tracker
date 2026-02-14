import Foundation

struct HRVMetrics {
    /// Root Mean Square of Successive Differences (in milliseconds)
    /// Primary measure of parasympathetic (vagal) activity
    let rmssd: Double

    /// Standard Deviation of NN intervals (in milliseconds)
    /// Overall HRV measure
    let sdnn: Double?

    /// Percentage of successive RR intervals differing by more than 50ms
    let pnn50: Double?

    /// Number of RR intervals used in calculation
    let sampleCount: Int

    /// Time window of the calculation
    let windowDuration: TimeInterval

    init(rmssd: Double, sdnn: Double? = nil, pnn50: Double? = nil,
         sampleCount: Int, windowDuration: TimeInterval) {
        self.rmssd = rmssd
        self.sdnn = sdnn
        self.pnn50 = pnn50
        self.sampleCount = sampleCount
        self.windowDuration = windowDuration
    }
}

extension HRVMetrics: CustomStringConvertible {
    var description: String {
        "RMSSD: \(String(format: "%.1f", rmssd))ms (n=\(sampleCount))"
    }
}
