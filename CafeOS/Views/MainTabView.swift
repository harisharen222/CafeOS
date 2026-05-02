import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

            NavigationStack {
                InventoryListView()
            }
            .tabItem { Label("Inventory", systemImage: "archivebox.fill") }

            NavigationStack {
                SupplierListView()
            }
            .tabItem { Label("Suppliers", systemImage: "person.2.fill") }

            NavigationStack {
                OrderListView()
            }
            .tabItem { Label("Orders", systemImage: "cart.fill") }
        }
        .accentColor(.brown)
        .task {
            // Request notification permission on first launch after login
            _ = await NotificationService.shared.requestPermission()
        }
    }
}
