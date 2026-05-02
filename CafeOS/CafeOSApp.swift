import SwiftUI
import FirebaseCore

@main
struct CafeOSApp: App {
    @StateObject private var appState    = AppState()
    @StateObject private var inventoryVM = InventoryViewModel()
    @StateObject private var supplierVM  = SupplierViewModel()
    @StateObject private var orderVM     = OrderViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoadingAuth {
                    ZStack {
                        Color(.systemBackground).ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.brown)
                            ProgressView()
                                .scaleEffect(1.2)
                        }
                    }
                } else if appState.isLoggedIn {
                    MainTabView()
                        .environmentObject(appState)
                        .environmentObject(inventoryVM)
                        .environmentObject(supplierVM)
                        .environmentObject(orderVM)
                } else {
                    NavigationStack {
                        LoginView()
                    }
                    .environmentObject(appState)
                }
            }
        }
    }
}
