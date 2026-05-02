import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Inventory — Coming Phase 7")
                .tabItem { Label("Inventory", systemImage: "archivebox.fill") }

            Text("Suppliers — Coming Phase 8")
                .tabItem { Label("Suppliers", systemImage: "person.2.fill") }

            Text("Orders — Coming Day 2")
                .tabItem { Label("Orders", systemImage: "cart.fill") }

            Text("Dashboard — Coming Day 2")
                .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
        }
        .tint(.brown)
    }
}
