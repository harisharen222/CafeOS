import SwiftUI

struct InventoryDetailView: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            if item.isLowStock {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Stock is running low. Consider reordering soon.")
                            .font(.subheadline)
                    }
                }
                .listRowBackground(Color.orange.opacity(0.1))
            }

            Section("Stock Info") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Category", value: item.category)
                LabeledContent("Quantity", value: String(format: "%.2f %@", item.quantity, item.unit))
                LabeledContent("Min Threshold", value: String(format: "%.2f %@", item.minimumThreshold, item.unit))
            }

            Section("Pricing & Supplier") {
                LabeledContent("Cost per Unit", value: String(format: "₹%.2f", item.costPerUnit))
                LabeledContent("Supplier", value: item.supplierName ?? "No supplier linked")
            }

            Section("Metadata") {
                LabeledContent("Last Updated", value: item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
            }

            Section {
                Button("Delete Item", role: .destructive) {
                    showDeleteAlert = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditForm = true }
                    .tint(.brown)
            }
        }
        .sheet(isPresented: $showEditForm) {
            InventoryFormView(viewModel: viewModel, mode: .edit(item))
        }
        .alert("Delete Item", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteItem(item)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete \"\(item.name)\"? This cannot be undone.")
        }
    }
}
