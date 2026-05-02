import SwiftUI

struct OrderDetailView: View {
    let order: Order
    @EnvironmentObject var orderVM: OrderViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showDeleteAlert = false
    @State private var showReceiveAlert = false
    @State private var showCancelAlert = false

    var body: some View {
        List {
            Section("Order Info") {
                LabeledContent("Item", value: order.itemName)
                LabeledContent("Supplier", value: order.supplierName)
                LabeledContent("Quantity", value: "\(String(format: "%.1f", order.quantity)) \(order.unit)")
                LabeledContent("Total Cost", value: String(format: "₹%.2f", order.totalCost))
                HStack {
                    Text("Status")
                    Spacer()
                    StatusBadge(status: order.status)
                }
                LabeledContent("Order Date", value: order.orderDate.formatted(date: .abbreviated, time: .shortened))
                if let received = order.receivedDate {
                    LabeledContent("Received on", value: received.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !order.notes.isEmpty {
                Section("Notes") {
                    Text(order.notes).foregroundStyle(.secondary)
                }
            }

            if order.status == .pending {
                Section {
                    Button {
                        showReceiveAlert = true
                    } label: {
                        Label("Mark as Received", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Button {
                        showCancelAlert = true
                    } label: {
                        Label("Cancel Order", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                Button("Delete Order", role: .destructive) { showDeleteAlert = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditForm = true }.tint(.brown)
            }
        }
        .sheet(isPresented: $showEditForm) { OrderFormView(mode: .edit(order)) }
        .alert("Mark as Received", isPresented: $showReceiveAlert) {
            Button("Confirm") {
                Task { await orderVM.markOrderReceived(order: order); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Mark this order as received? This will update your inventory quantity.")
        }
        .alert("Cancel Order", isPresented: $showCancelAlert) {
            Button("Cancel Order", role: .destructive) {
                var updated = order; updated.status = .cancelled
                Task { await orderVM.updateOrder(updated); dismiss() }
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this order?")
        }
        .alert("Delete Order", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let id = order.id {
                    Task { await orderVM.deleteOrder(id: id); dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete this order? This cannot be undone.")
        }
    }
}
