import SwiftUI
import Firebase

@main
struct CafeOSApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            // Day 2: replace with auth-gated routing
            // For now route directly to tab view for development
            MainTabView()
                .environmentObject(appState)
        }
    }
}
