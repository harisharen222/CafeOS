import SwiftUI

struct SupplierDetailView: View {
    let supplier: Supplier
    @EnvironmentObject var supplierVM: SupplierViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showDeleteAlert = false

    var body: some View {
        List {
            Section("Contact Info") {
                LabeledContent("Business Name", value: supplier.name)
                LabeledContent("Contact Person", value: supplier.contactName)
                if let url = URL(string: "tel:\(supplier.phone)") {
                    Link(destination: url) { LabeledContent("Phone", value: supplier.phone) }
                } else {
                    LabeledContent("Phone", value: supplier.phone)
                }
                if !supplier.email.isEmpty, let url = URL(string: "mailto:\(supplier.email)") {
                    Link(destination: url) { LabeledContent("Email", value: supplier.email) }
                } else if !supplier.email.isEmpty {
                    LabeledContent("Email", value: supplier.email)
                }
            }

            Section("Financial & Logistics") {
                LabeledContent("Amount Owed", value: String(format: "₹%.2f", supplier.amountOwed))
                LabeledContent("Delivery Time", value: "\(supplier.deliveryDays) days avg. lead time")
            }

            Section("Items Supplied") {
                if supplier.itemsSupplied.isEmpty {
                    Text("No items linked yet").foregroundStyle(.secondary).italic()
                } else {
                    ForEach(supplier.itemsSupplied, id: \.self) { Text($0) }
                }
            }

            Section {
                Button("Delete Supplier", role: .destructive) { showDeleteAlert = true }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(supplier.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditForm = true }.tint(.brown)
            }
        }
        .sheet(isPresented: $showEditForm) { SupplierFormView(mode: .edit(supplier)) }
        .alert("Delete Supplier", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await supplierVM.deleteSupplier(supplier); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Delete \"\(supplier.name)\"? This cannot be undone.") }
    }
}
