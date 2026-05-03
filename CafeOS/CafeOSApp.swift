import SwiftUI
import FirebaseCore

@main
struct CafeOSApp: App {
    @StateObject private var appState    = AppState()
    @StateObject private var inventoryVM = InventoryViewModel()
    @StateObject private var supplierVM  = SupplierViewModel()
    @StateObject private var orderVM     = OrderViewModel()
    @StateObject private var aiVM        = AIViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            if appState.isLoadingAuth {
                ZStack {
                    Color(hex: "#0D0D0D").ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#A0001C"))
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    }
                }
                .preferredColorScheme(.dark)
            } else if appState.isLoggedIn {
                MainTabView()
                    .environmentObject(appState)
                    .environmentObject(inventoryVM)
                    .environmentObject(supplierVM)
                    .environmentObject(orderVM)
                    .environmentObject(aiVM)
                    .preferredColorScheme(.dark)
            } else {
                NavigationStack {
                    LoginView()
                }
                .environmentObject(appState)
                .preferredColorScheme(.dark)
            }
        }
    }
}
