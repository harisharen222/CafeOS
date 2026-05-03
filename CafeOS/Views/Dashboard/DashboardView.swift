import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @EnvironmentObject var orderVM: OrderViewModel
    
    @State private var notificationScheduled: Bool = false

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning ☕" }
        else if hour < 17 { return "Good afternoon ☕" }
        else { return "Good evening " }
    }

    private var userInitials: String {
        let email = appState.currentUserEmail ?? "U"
        let name = email.components(separatedBy: "@").first ?? "U"
        return String(name.prefix(2)).uppercased()
    }

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Greeting
                Text(greeting)
                    .font(.title.bold())
                    .padding(.horizontal)

                // 2×2 metric cards
                LazyVGrid(columns: columns, spacing: 16) {
                    MetricCard(
                        title: "Total Items",
                        value: "\(inventoryVM.items.count)",
                        icon: "archivebox.fill",
                        color: .blue
                    )
                    MetricCard(
                        title: "Low Stock",
                        value: "\(inventoryVM.lowStockCount)",
                        icon: "exclamationmark.triangle.fill",
                        color: inventoryVM.lowStockCount > 0 ? .red : .green
                    )
                    MetricCard(
                        title: "Pending Orders",
                        value: "\(orderVM.pendingOrders.count)",
                        icon: "cart.fill",
                        color: orderVM.pendingOrders.count > 0 ? .orange : .green
                    )
                    MetricCard(
                        title: "Amount Owed",
                        value: "₹\(Int(supplierVM.totalAmountOwed).formatted())",
                        icon: "indianrupeesign.circle.fill",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Low stock section
                VStack(alignment: .leading, spacing: 12) {
                    Text("🔴 Needs Attention")
                        .font(.headline)
                        .padding(.horizontal)

                    if inventoryVM.lowStockItems.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text("All items are well stocked ✓").foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(inventoryVM.lowStockItems) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name).font(.subheadline.bold())
                                        Text(item.supplierName ?? "No supplier")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(String(format: "%.1f", item.quantity)) / \(String(format: "%.1f", item.minimumThreshold)) \(item.unit)")
                                            .font(.caption.bold()).foregroundStyle(.red)
                                    }
                                }
                                .padding()
                                if item.id != inventoryVM.lowStockItems.last?.id {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                // Pending orders preview
                if !orderVM.pendingOrders.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🕐 Pending Orders")
                            .font(.headline)
                            .padding(.horizontal)
                        VStack(spacing: 0) {
                            ForEach(orderVM.pendingOrders.prefix(3)) { order in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(order.itemName).font(.subheadline.bold())
                                        Text(order.supplierName).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(String(format: "%.1f", order.quantity)) \(order.unit)")
                                        .font(.caption.bold()).foregroundStyle(.orange)
                                }
                                .padding()
                                if order.id != orderVM.pendingOrders.prefix(3).last?.id {
                                    Divider().padding(.leading)
                                }
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }

                // AI Reorder Advisor card
                NavigationLink(destination: ReorderAdvisorView()) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Smart Reorder Advisor", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Tap to get AI-powered reorder recommendations →")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding()
                    .background(Color.brown)
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Notification Badge
                if notificationScheduled {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.brown)
                        Text("Daily 8 AM low-stock alert is active")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                
                #if DEBUG
                Button("Seed Demo Data") {
                    Task {
                        await SeedData.populate(firestoreService: FirestoreService())
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                #endif
            }
            .padding(.vertical)
        }
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: ProfileView()) {
                    ZStack {
                        Circle()
                            .fill(Color.brown.opacity(0.2))
                            .frame(width: 32, height: 32)
                        Text(userInitials)
                            .font(.caption.bold())
                            .foregroundColor(.brown)
                    }
                }
            }
        }
        .task {
            inventoryVM.startListening()
            await supplierVM.fetchSuppliers()
            await orderVM.fetchOrders()
            
            NotificationService.shared.hasPendingLowStockAlert { scheduled in
                notificationScheduled = scheduled
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Spacer()
            }
            Text(value).font(.title.bold())
            Text(title).font(.caption).foregroundColor(.secondary)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
