import SwiftUI

/// Main tab view container for the app
struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView()
                .tabItem {
                    Label(
                        AppCoordinator.Tab.home.title,
                        systemImage: AppCoordinator.Tab.home.iconName
                    )
                }
                .tag(AppCoordinator.Tab.home)

            MonitorView()
                .tabItem {
                    Label(
                        AppCoordinator.Tab.monitor.title,
                        systemImage: AppCoordinator.Tab.monitor.iconName
                    )
                }
                .tag(AppCoordinator.Tab.monitor)

            HistoryView()
                .tabItem {
                    Label(
                        AppCoordinator.Tab.history.title,
                        systemImage: AppCoordinator.Tab.history.iconName
                    )
                }
                .tag(AppCoordinator.Tab.history)

            SettingsView()
                .tabItem {
                    Label(
                        AppCoordinator.Tab.settings.title,
                        systemImage: AppCoordinator.Tab.settings.iconName
                    )
                }
                .tag(AppCoordinator.Tab.settings)
        }
        .sheet(isPresented: $coordinator.showMorningReadinessPrompt) {
            MorningReadinessPromptView()
        }
    }
}

// MARK: - Morning Readiness Prompt

struct MorningReadinessPromptView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "sun.horizon.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text("Good Morning!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Take your 3-minute morning readiness check to see how recovered you are today.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        coordinator.startMorningReadiness()
                        dismiss()
                    } label: {
                        Label("Start Readiness Check", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Remind Me Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Morning Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
