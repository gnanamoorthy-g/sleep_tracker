import SwiftUI

@main
struct SleepTrackerApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(coordinator)
                .onAppear {
                    // Request notification permissions
                    NotificationManager.shared.requestPermissions()

                    // Initialize app-wide settings
                    coordinator.onAppBecomeActive()
                }
        }
    }
}
