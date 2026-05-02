import SwiftUI

struct MainTabView: View {
    @StateObject private var inventoryVM = InventoryViewModel()
    @StateObject private var supplierVM  = SupplierViewModel()

    var body: some View {
        TabView {
            InventoryListView(viewModel: inventoryVM)
                .tabItem { Label("Inventory", systemImage: "archivebox.fill") }

            SupplierListView(viewModel: supplierVM)
                .tabItem { Label("Suppliers", systemImage: "person.2.fill") }

            Text("Orders — Coming Day 2")
                .tabItem { Label("Orders", systemImage: "cart.fill") }

            Text("Dashboard — Coming Day 2")
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
        }
        .tint(.brown)
    }
}
