import SwiftUI
import Charts

struct HRVTrendView: View {
    let dataPoints: [DailyHRVDataPoint]
    let baseline7d: Double?
    let baseline30d: Double?

    @State private var selectedRange: TimeRange = .week
    @State private var hourlyData: [ContinuousHRVData] = []

    private let continuousRepository = ContinuousHRVDataRepository()

    private var filteredDataPoints: [DailyHRVDataPoint] {
        dataPoints.filtered(by: selectedRange)
    }

    private var xAxisDomain: ClosedRange<Date> {
        let end = selectedRange.endDate
        let start = selectedRange.startDate() ?? Calendar.current.date(byAdding: .year, value: -1, to: end)!
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HRV Trend")
                    .font(.headline)
                Spacer()
                if selectedRange.isIntraday {
                    Text("Hourly")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                } else if let latest = filteredDataPoints.last {
                    Text(latest.source.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            TimeRangePicker(selectedRange: $selectedRange)

            if selectedRange.isIntraday {
                if hourlyData.isEmpty {
                    intradayEmptyStateView
                } else {
                    intradayChart
                        .frame(height: 200)
                }
            } else {
                if filteredDataPoints.isEmpty {
                    emptyStateView
                } else {
                    trendChart
                        .frame(height: 200)

                    legendView
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onChange(of: selectedRange) { newValue in
            if newValue.isIntraday {
                loadHourlyData()
            }
        }
        .onAppear {
            if selectedRange.isIntraday {
                loadHourlyData()
            }
        }
    }

    private func loadHourlyData() {
        hourlyData = continuousRepository.loadForDate(Date())
            .sorted { $0.hourOfDay < $1.hourOfDay }
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No trend data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Take morning readiness checks or snapshots to see your HRV trend")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var intradayEmptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No hourly data today")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Enable continuous monitoring to see hourly HRV variation")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var intradayChart: some View {
        Chart {
            ForEach(hourlyData) { entry in
                // Create a proper date for this hour
                let hourDate = Calendar.current.date(
                    bySettingHour: entry.hourOfDay,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date()

                LineMark(
                    x: .value("Hour", hourDate),
                    y: .value("RMSSD", entry.averageRMSSD)
                )
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))

                PointMark(
                    x: .value("Hour", hourDate),
                    y: .value("RMSSD", entry.averageRMSSD)
                )
                .foregroundStyle(Color.blue)
                .symbolSize(60)
            }

            // Show baseline if available
            if let baseline7d = baseline7d {
                RuleMark(y: .value("Baseline", baseline7d))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("7d avg")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
            }
        }
        .chartXScale(domain: xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                AxisValueLabel(format: .dateTime.hour())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var trendChart: some View {
        Chart {
            // Daily RMSSD points
            ForEach(filteredDataPoints) { point in
                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("RMSSD", point.rmssd)
                )
                .foregroundStyle(colorForZScore(point.zScore))
                .symbol(symbolForSource(point.source))
                .symbolSize(100)

                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("RMSSD", point.rmssd)
                )
                .foregroundStyle(Color.blue.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // 7-day baseline line
            if let baseline7d = baseline7d {
                RuleMark(y: .value("7d Baseline", baseline7d))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("7d")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
            }

            // 30-day baseline line
            if let baseline30d = baseline30d {
                RuleMark(y: .value("30d Baseline", baseline30d))
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .bottom, alignment: .trailing) {
                        Text("30d")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
            }
        }
        .chartXScale(domain: xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.desiredAxisMarks)) { _ in
                AxisValueLabel(format: selectedRange.dateFormat)
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }

    private var legendView: some View {
        HStack(spacing: 16) {
            LegendItem(color: .green, label: "Above Normal (Z > 1)")
            LegendItem(color: .blue, label: "Normal")
            LegendItem(color: .red, label: "Stressed (Z < -1.5)")
        }
        .font(.caption2)
    }

    private func colorForZScore(_ zScore: Double?) -> Color {
        guard let z = zScore else { return .blue }

        switch z {
        case 1.0...:
            return .green
        case -1.5..<1.0:
            return .blue
        default:
            return .red
        }
    }

    private func symbolForSource(_ source: DailyHRVDataPoint.DataSource) -> BasicChartSymbolShape {
        switch source {
        case .morningReadiness:
            return .circle
        case .sleepSession:
            return .square
        case .combined:
            return .diamond
        case .continuous:
            return .triangle
        case .snapshot:
            return .pentagon
        }
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Recovery Trend View

struct RecoveryTrendView: View {
    let dataPoints: [DailyHRVDataPoint]

    @State private var selectedRange: TimeRange = .week

    // Only show points that have recovery score calculated
    private var pointsWithRecovery: [DailyHRVDataPoint] {
        dataPoints.filtered(by: selectedRange).filter { $0.recoveryScore != nil }
    }

    private var xAxisDomain: ClosedRange<Date> {
        let end = selectedRange.endDate
        let start = selectedRange.startDate() ?? Calendar.current.date(byAdding: .year, value: -1, to: end)!
        return start...end
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recovery Score")
                    .font(.headline)
                Spacer()
                Text("% of 7d baseline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            TimeRangePicker(selectedRange: $selectedRange)

            if pointsWithRecovery.isEmpty {
                emptyStateView
            } else {
                recoveryChart
                    .frame(height: 150)

                recoveryLegend
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No recovery data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Take measurements for at least 7 days to see recovery trends")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var recoveryChart: some View {
        Chart {
            ForEach(pointsWithRecovery) { point in
                if let recoveryScore = point.recoveryScore {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Recovery", recoveryScore)
                    )
                    .foregroundStyle(colorForRecovery(recoveryScore))
                    .annotation(position: .top) {
                        if point.hasSleepData && point.hasMorningReadiness {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.green)
                        }
                    }
                }
            }

            // 100% line (baseline)
            RuleMark(y: .value("Baseline", 100))
                .foregroundStyle(.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 50...130)
        .chartXScale(domain: xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.desiredAxisMarks)) { _ in
                AxisValueLabel(format: selectedRange.dateFormat)
                AxisGridLine()
            }
        }
    }

    private var recoveryLegend: some View {
        HStack(spacing: 12) {
            LegendItem(color: .green, label: "Optimal (>105%)")
            LegendItem(color: .blue, label: "Normal (95-105%)")
            LegendItem(color: .orange, label: "Low (85-95%)")
            LegendItem(color: .red, label: "Very Low (<85%)")
        }
        .font(.caption2)
    }

    private func colorForRecovery(_ score: Int) -> Color {
        switch score {
        case 105...:
            return .green
        case 95..<105:
            return .blue
        case 85..<95:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Sleep Score Breakdown View

struct SleepScoreBreakdownView: View {
    let durationScore: Int
    let deepScore: Int
    let hrvScore: Int
    let continuityScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Breakdown")
                .font(.headline)

            VStack(spacing: 8) {
                ScoreComponentRow(
                    label: "Duration",
                    score: durationScore,
                    weight: "30%",
                    color: .blue
                )
                ScoreComponentRow(
                    label: "Deep Sleep",
                    score: deepScore,
                    weight: "25%",
                    color: .indigo
                )
                ScoreComponentRow(
                    label: "HRV Recovery",
                    score: hrvScore,
                    weight: "25%",
                    color: .purple
                )
                ScoreComponentRow(
                    label: "Continuity",
                    score: continuityScore,
                    weight: "20%",
                    color: .green
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct ScoreComponentRow: View {
    let label: String
    let score: Int
    let weight: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(weight)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 35)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 8)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: CGFloat(score), height: 8)
            }

            Text("\(score)")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 35, alignment: .trailing)
        }
    }
}

// MARK: - Sleep Trend View

struct SleepTrendView: View {
    let dataPoints: [DailyHRVDataPoint]

    @State private var selectedMetric: SleepMetric = .duration
    @State private var selectedRange: TimeRange = .week

    private var filteredDataPoints: [DailyHRVDataPoint] {
        dataPoints.filtered(by: selectedRange)
    }

    private var xAxisDomain: ClosedRange<Date> {
        let end = selectedRange.endDate
        let start = selectedRange.startDate() ?? Calendar.current.date(byAdding: .year, value: -1, to: end)!
        return start...end
    }

    enum SleepMetric: String, CaseIterable {
        case duration = "Duration"
        case score = "Score"
        case stages = "Stages"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Trend")
                    .font(.headline)

                Spacer()

                Picker("Metric", selection: $selectedMetric) {
                    ForEach(SleepMetric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            TimeRangePicker(selectedRange: $selectedRange)

            if filteredDataPoints.isEmpty {
                emptyStateView
            } else {
                Group {
                    switch selectedMetric {
                    case .duration:
                        durationChart
                    case .score:
                        scoreChart
                    case .stages:
                        stagesChart
                    }
                }
                .frame(height: 180)

                if selectedMetric == .duration {
                    durationStats
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No sleep data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Complete sleep sessions to see your trends")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }

    // MARK: - Duration Chart

    private var durationChart: some View {
        Chart {
            ForEach(filteredDataPoints) { point in
                if let duration = point.sleepDurationMinutes {
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", duration / 60)
                    )
                    .foregroundStyle(colorForDuration(duration))
                }
            }

            // Target line (7-9 hours)
            RuleMark(y: .value("Target Min", 7))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

            RuleMark(y: .value("Target Max", 9))
                .foregroundStyle(.green.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
        }
        .chartYScale(domain: 0...12)
        .chartXScale(domain: xAxisDomain)
        .chartYAxis {
            AxisMarks(values: [0, 3, 6, 9, 12]) { value in
                AxisValueLabel {
                    if let hours = value.as(Double.self) {
                        Text("\(Int(hours))h")
                    }
                }
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.desiredAxisMarks)) { _ in
                AxisValueLabel(format: selectedRange.dateFormat)
                AxisGridLine()
            }
        }
    }

    // MARK: - Score Chart

    private var scoreChart: some View {
        Chart {
            ForEach(filteredDataPoints) { point in
                if let score = point.sleepScore {
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(Color.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(colorForScore(score))
                    .symbolSize(80)
                }
            }

            // Good sleep threshold
            RuleMark(y: .value("Good", 85))
                .foregroundStyle(.green.opacity(0.3))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.desiredAxisMarks)) { _ in
                AxisValueLabel(format: selectedRange.dateFormat)
                AxisGridLine()
            }
        }
    }

    // MARK: - Stages Chart (Stacked)

    private var stagesChart: some View {
        Chart {
            ForEach(filteredDataPoints) { point in
                // Deep sleep
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Minutes", point.deepSleepMinutes ?? 0)
                )
                .foregroundStyle(by: .value("Stage", "Deep"))

                // Light sleep
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Minutes", point.lightSleepMinutes ?? 0)
                )
                .foregroundStyle(by: .value("Stage", "Light"))

                // REM sleep
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Minutes", point.remSleepMinutes ?? 0)
                )
                .foregroundStyle(by: .value("Stage", "REM"))

                // Awake
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Minutes", point.awakeMinutes ?? 0)
                )
                .foregroundStyle(by: .value("Stage", "Awake"))
            }
        }
        .chartForegroundStyleScale([
            "Deep": Color.indigo,
            "Light": Color.blue,
            "REM": Color.purple,
            "Awake": Color.orange.opacity(0.6)
        ])
        .chartXScale(domain: xAxisDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: selectedRange.desiredAxisMarks)) { _ in
                AxisValueLabel(format: selectedRange.dateFormat)
                AxisGridLine()
            }
        }
        .chartLegend(position: .bottom, spacing: 16)
    }

    // MARK: - Duration Stats

    private var durationStats: some View {
        HStack(spacing: 16) {
            let durations = filteredDataPoints.compactMap { $0.sleepDurationMinutes }
            let avgDuration = durations.isEmpty ? 0 : durations.reduce(0, +) / Double(durations.count)

            let deepValues = filteredDataPoints.compactMap { $0.deepSleepMinutes }
            let avgDeep = deepValues.isEmpty ? 0 : deepValues.reduce(0, +) / Double(deepValues.count)

            SleepStatItem(
                label: "Avg Duration",
                value: formatDuration(avgDuration),
                color: colorForDuration(avgDuration)
            )

            SleepStatItem(
                label: "Avg Deep",
                value: formatDuration(avgDeep),
                color: .indigo
            )

            if let avgScore = averageSleepScore {
                SleepStatItem(
                    label: "Avg Score",
                    value: "\(avgScore)",
                    color: colorForScore(avgScore)
                )
            }
        }
    }

    private var averageSleepScore: Int? {
        let scores = filteredDataPoints.compactMap { $0.sleepScore }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private func formatDuration(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        return "\(hours)h \(mins)m"
    }

    private func colorForDuration(_ minutes: Double) -> Color {
        let hours = minutes / 60
        switch hours {
        case 7...9: return .green
        case 6..<7, 9..<10: return .yellow
        default: return .orange
        }
    }

    private func colorForScore(_ score: Int) -> Color {
        switch score {
        case 85...: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}

struct SleepStatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
