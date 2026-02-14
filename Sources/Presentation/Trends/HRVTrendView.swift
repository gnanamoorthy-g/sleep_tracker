import SwiftUI
import Charts

struct HRVTrendView: View {
    let summaries: [DailyHRVSummary]
    let baseline7d: Double?
    let baseline30d: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Trend")
                .font(.headline)

            if summaries.isEmpty {
                emptyStateView
            } else {
                trendChart
                    .frame(height: 200)

                legendView
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No trend data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Record multiple nights to see your HRV trend")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var trendChart: some View {
        Chart {
            // Daily RMSSD points
            ForEach(summaries) { summary in
                PointMark(
                    x: .value("Date", summary.date, unit: .day),
                    y: .value("RMSSD", summary.rmssd)
                )
                .foregroundStyle(colorForZScore(summary.zScore))
                .symbolSize(100)

                LineMark(
                    x: .value("Date", summary.date, unit: .day),
                    y: .value("RMSSD", summary.rmssd)
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
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
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
    let summaries: [DailyHRVSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Score")
                .font(.headline)

            if summaries.isEmpty {
                emptyStateView
            } else {
                recoveryChart
                    .frame(height: 150)
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
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var recoveryChart: some View {
        Chart {
            ForEach(summaries) { summary in
                if let recoveryScore = summary.recoveryScore {
                    BarMark(
                        x: .value("Date", summary.date, unit: .day),
                        y: .value("Recovery", recoveryScore)
                    )
                    .foregroundStyle(colorForRecovery(recoveryScore))
                }
            }

            // 100% line
            RuleMark(y: .value("Baseline", 100))
                .foregroundStyle(.gray.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartYScale(domain: 50...130)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7)) { value in
                AxisValueLabel(format: .dateTime.day())
            }
        }
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
