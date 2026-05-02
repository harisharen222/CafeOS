import SwiftUI

struct OrderListView: View {
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    @State private var showAddForm = false
    @State private var orderToDelete: Order? = nil
    @State private var showDeleteAlert = false
    @State private var selectedFilter: FilterOption = .all

    enum FilterOption: String, CaseIterable {
        case all = "All", pending = "Pending", received = "Received", cancelled = "Cancelled"
    }

    private var filteredOrders: [Order] {
        switch selectedFilter {
        case .all:       return orderVM.orders
        case .pending:   return orderVM.pendingOrders
        case .received:  return orderVM.receivedOrders
        case .cancelled: return orderVM.cancelledOrders
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ErrorBannerView(
                message: orderVM.errorMessage ?? "",
                onRetry: { Task { await orderVM.fetchOrders() } },
                isVisible: $orderVM.showError
            )

            Picker("Filter", selection: $selectedFilter) {
                ForEach(FilterOption.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            content
        }
        .navigationTitle("Orders")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddForm) { OrderFormView(mode: .add) }
        .alert("Delete Order", isPresented: $showDeleteAlert, presenting: orderToDelete) { order in
            Button("Delete", role: .destructive) {
                if let id = order.id { Task { await orderVM.deleteOrder(id: id) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("Delete this order? This cannot be undone.") }
        .task { await orderVM.fetchOrders() }
    }

    @ViewBuilder
    private var content: some View {
        if orderVM.isLoading && orderVM.orders.isEmpty {
            ProgressView("Loading orders…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredOrders.isEmpty {
            EmptyStateView(
                icon: "cart",
                title: "No \(selectedFilter.rawValue.lowercased()) orders",
                subtitle: selectedFilter == .all ? "Tap + to place your first order" : "No orders with this status yet"
            )
        } else {
            List {
                ForEach(filteredOrders) { order in
                    NavigationLink { OrderDetailView(order: order) } label: {
                        OrderRowView(order: order)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            orderToDelete = order; showDeleteAlert = true
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await orderVM.fetchOrders() }
        }
    }
}

private struct OrderRowView: View {
    let order: Order
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(order.itemName).font(.headline)
                Spacer()
                StatusBadge(status: order.status)
            }
            Text("Supplier: \(order.supplierName)").font(.caption).foregroundStyle(.secondary)
            HStack {
                Text("\(String(format: "%.1f", order.quantity)) \(order.unit)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "₹%.2f", order.totalCost))
                    .font(.caption.bold())
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBadge: View {
    let status: OrderStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption2).bold()
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }
    private var badgeColor: Color {
        switch status {
        case .pending:   return .orange
        case .received:  return .green
        case .cancelled: return .red
        }
    }
}
