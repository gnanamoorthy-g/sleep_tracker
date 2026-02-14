import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionSummaryViewModel()

    var body: some View {
        List {
            if viewModel.sessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("No Sessions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Your recorded sleep sessions will appear here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.sessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowView(session: session)
                    }
                }
                .onDelete(perform: deleteSessions)
            }
        }
        .navigationTitle("Sessions")
        .toolbar {
            if !viewModel.sessions.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
        .onAppear {
            viewModel.loadSessions()
        }
        .refreshable {
            viewModel.loadSessions()
        }
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteSession(viewModel.sessions[index])
        }
    }
}

// MARK: - Session Row View
struct SessionRowView: View {
    let session: SleepSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.startTime, style: .date)
                    .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                if let avgHR = session.averageHeartRate {
                    Label(
                        String(format: "%.0f BPM", avgHR),
                        systemImage: "heart.fill"
                    )
                    .font(.caption)
                    .foregroundColor(.red)
                }

                if let avgRMSSD = session.averageRMSSD {
                    Label(
                        String(format: "%.1f ms", avgRMSSD),
                        systemImage: "waveform.path.ecg"
                    )
                    .font(.caption)
                    .foregroundColor(.blue)
                }

                Text("\(session.samples.count) samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Session Detail View
struct SessionDetailView: View {
    let session: SleepSession

    var body: some View {
        List {
            Section("Overview") {
                DetailRow(label: "Start", value: session.startTime.formatted())
                if let endTime = session.endTime {
                    DetailRow(label: "End", value: endTime.formatted())
                }
                DetailRow(label: "Duration", value: session.formattedDuration)
                DetailRow(label: "Samples", value: "\(session.samples.count)")
            }

            Section("Heart Rate") {
                if let avgHR = session.averageHeartRate {
                    DetailRow(label: "Average", value: String(format: "%.0f BPM", avgHR))
                }
                if let minHR = session.minHeartRate {
                    DetailRow(label: "Minimum", value: "\(minHR) BPM")
                }
                if let maxHR = session.maxHeartRate {
                    DetailRow(label: "Maximum", value: "\(maxHR) BPM")
                }
            }

            Section("HRV") {
                if let avgRMSSD = session.averageRMSSD {
                    DetailRow(label: "Average RMSSD", value: String(format: "%.1f ms", avgRMSSD))
                }
            }
        }
        .navigationTitle("Session Details")
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }
}

#Preview {
    NavigationStack {
        SessionHistoryView()
    }
}
