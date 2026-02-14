import SwiftUI
import Charts

struct SleepGraphView: View {
    let epochs: [SleepEpoch]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Stages")
                .font(.headline)

            if epochs.isEmpty {
                emptyStateView
            } else {
                sleepChart
                    .frame(height: 150)

                legendView
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No sleep data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
    }

    private var sleepChart: some View {
        Chart {
            ForEach(epochs) { epoch in
                if let phase = epoch.phase {
                    RectangleMark(
                        xStart: .value("Start", epoch.startTime),
                        xEnd: .value("End", epoch.endTime),
                        y: .value("Phase", phase.displayOrder)
                    )
                    .foregroundStyle(phase.color)
                }
            }
        }
        .chartYScale(domain: -0.5...3.5)
        .chartYAxis {
            AxisMarks(values: [0, 1, 2, 3]) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self) {
                        Text(phaseLabel(for: index))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }

    private var legendView: some View {
        HStack(spacing: 16) {
            ForEach(SleepPhase.allCases, id: \.self) { phase in
                HStack(spacing: 4) {
                    Circle()
                        .fill(phase.color)
                        .frame(width: 8, height: 8)
                    Text(phase.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func phaseLabel(for index: Int) -> String {
        switch index {
        case 0: return "W"
        case 1: return "R"
        case 2: return "L"
        case 3: return "D"
        default: return ""
        }
    }
}

// MARK: - HR/RMSSD Line Chart
struct HRLineChartView: View {
    let epochs: [SleepEpoch]
    let showRMSSD: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Heart Rate")
                .font(.headline)

            if epochs.isEmpty {
                emptyStateView
            } else {
                hrChart
                    .frame(height: 120)
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
            Text("No HR data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private var hrChart: some View {
        Chart {
            ForEach(epochs) { epoch in
                LineMark(
                    x: .value("Time", epoch.startTime),
                    y: .value("HR", epoch.averageHR)
                )
                .foregroundStyle(.red)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            if showRMSSD {
                ForEach(epochs) { epoch in
                    LineMark(
                        x: .value("Time", epoch.startTime),
                        y: .value("RMSSD", epoch.averageRMSSD)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

// MARK: - Sleep Score Ring
struct SleepScoreView: View {
    let score: Int

    private var scoreColor: Color {
        switch score {
        case 85...:
            return .green
        case 70..<85:
            return .blue
        case 50..<70:
            return .orange
        default:
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: CGFloat(score) / 100)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text("Sleep Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 120, height: 120)
        }
    }
}

// MARK: - Sleep Summary Card
struct SleepSummaryCard: View {
    let summary: SleepSummary

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                SleepScoreView(score: summary.sleepScore)

                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(
                        icon: "clock",
                        label: "Duration",
                        value: formatDuration(summary.totalDuration)
                    )
                    SummaryRow(
                        icon: "heart.fill",
                        label: "Avg HR",
                        value: String(format: "%.0f BPM", summary.averageHR)
                    )
                    SummaryRow(
                        icon: "waveform.path.ecg",
                        label: "Avg RMSSD",
                        value: String(format: "%.1f ms", summary.averageRMSSD)
                    )
                }

                Spacer()
            }

            // Phase breakdown
            HStack(spacing: 12) {
                PhaseTimeView(phase: .deep, minutes: summary.deepMinutes)
                PhaseTimeView(phase: .light, minutes: summary.lightMinutes)
                PhaseTimeView(phase: .rem, minutes: summary.remMinutes)
                PhaseTimeView(phase: .awake, minutes: summary.awakeMinutes)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct SummaryRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct PhaseTimeView: View {
    let phase: SleepPhase
    let minutes: Double

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(phase.color)
                .frame(width: 8, height: 8)

            Text(formatMinutes(minutes))
                .font(.caption)
                .fontWeight(.medium)

            Text(phase.shortName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatMinutes(_ mins: Double) -> String {
        let hours = Int(mins) / 60
        let minutes = Int(mins) % 60
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    VStack(spacing: 16) {
        SleepGraphView(epochs: [])

        SleepSummaryCard(summary: SleepSummary(
            totalDuration: 7.5 * 3600,
            sleepScore: 85,
            awakeMinutes: 15,
            lightMinutes: 180,
            deepMinutes: 90,
            remMinutes: 100,
            averageHR: 58,
            minHR: 48,
            maxHR: 72,
            averageRMSSD: 45,
            hrvRecoveryRatio: 1.15,
            awakenings: 2
        ))
    }
    .padding()
}
