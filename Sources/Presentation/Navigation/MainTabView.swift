import SwiftUI

/// Main tab view container for the app
struct MainTabView: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            HomeView()
                .tabItem { Label(AppCoordinator.Tab.home.title, systemImage: AppCoordinator.Tab.home.iconName) }
                .tag(AppCoordinator.Tab.home)

            MonitorView()
                .tabItem { Label(AppCoordinator.Tab.monitor.title, systemImage: AppCoordinator.Tab.monitor.iconName) }
                .tag(AppCoordinator.Tab.monitor)

            InsightsView()
                .tabItem { Label(AppCoordinator.Tab.insights.title, systemImage: AppCoordinator.Tab.insights.iconName) }
                .tag(AppCoordinator.Tab.insights)

            HistoryView()
                .tabItem { Label(AppCoordinator.Tab.history.title, systemImage: AppCoordinator.Tab.history.iconName) }
                .tag(AppCoordinator.Tab.history)

            SettingsView()
                .tabItem { Label(AppCoordinator.Tab.settings.title, systemImage: AppCoordinator.Tab.settings.iconName) }
                .tag(AppCoordinator.Tab.settings)
        }
        .tint(AppTheme.Colors.primaryGradientStart)
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
            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppTheme.Gradients.sunrise)
                        .frame(width: 120, height: 120)
                        .shadow(color: Color.orange.opacity(0.4), radius: 20, x: 0, y: 10)

                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }

                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Good Morning!")
                        .font(AppTheme.Typography.title)
                        .foregroundColor(AppTheme.Colors.textPrimary)

                    Text("Take your 3-minute morning readiness check to see how recovered you are today.")
                        .font(AppTheme.Typography.body)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xl)
                }

                Spacer()

                VStack(spacing: AppTheme.Spacing.md) {
                    Button {
                        coordinator.startMorningReadiness()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Readiness Check")
                        }
                    }
                    .primaryStyle()

                    Button("Remind Me Later") { dismiss() }
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.xl)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
            .navigationTitle("Morning Readiness")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") { dismiss() }.foregroundColor(AppTheme.Colors.textTertiary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
