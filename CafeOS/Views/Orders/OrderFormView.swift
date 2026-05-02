import SwiftUI

enum OrderFormMode {
    case add
    case edit(Order)
}

struct OrderFormView: View {
    @EnvironmentObject var orderVM: OrderViewModel
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @EnvironmentObject var supplierVM: SupplierViewModel
    let mode: OrderFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItemID: String = ""
    @State private var selectedSupplierID: String = ""
    @State private var quantityText: String = ""
    @State private var notes: String = ""
    @State private var selectedStatus: OrderStatus = .pending
    @State private var isSaving = false

    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var selectedItem: InventoryItem? { inventoryVM.items.first { $0.id == selectedItemID } }
    private var selectedSupplier: Supplier? { supplierVM.suppliers.first { $0.id == selectedSupplierID } }
    private var quantity: Double { Double(quantityText) ?? 0 }
    private var totalCost: Double { quantity * (selectedItem?.costPerUnit ?? 0) }
    private var isFormValid: Bool { !selectedItemID.isEmpty && !selectedSupplierID.isEmpty && quantity > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    Picker("Select Item", selection: $selectedItemID) {
                        Text("Choose an item").tag("")
                        ForEach(inventoryVM.items) { item in
                            Text("\(item.name) (stock: \(String(format: "%.1f", item.quantity)) \(item.unit))")
                                .tag(item.id ?? "")
                        }
                    }
                    .onChange(of: selectedItemID) { _, newID in
                        if let item = inventoryVM.items.first(where: { $0.id == newID }),
                           let sID = item.supplierID { selectedSupplierID = sID }
                    }
                    if selectedItemID.isEmpty {
                        Text("Item is required.").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Supplier") {
                    Picker("Select Supplier", selection: $selectedSupplierID) {
                        Text("Choose a supplier").tag("")
                        ForEach(supplierVM.suppliers) { s in Text(s.name).tag(s.id ?? "") }
                    }
                    if selectedSupplierID.isEmpty {
                        Text("Supplier is required.").font(.caption).foregroundStyle(.red)
                    }
                }
                Section("Quantity") {
                    TextField("Quantity", text: $quantityText).keyboardType(.decimalPad)
                    if !quantityText.isEmpty && quantity <= 0 {
                        Text("Quantity must be greater than zero.").font(.caption).foregroundStyle(.red)
                    }
                    if let item = selectedItem {
                        LabeledContent("Unit", value: item.unit)
                        LabeledContent("Cost/unit", value: String(format: "₹%.2f", item.costPerUnit))
                        LabeledContent("Total Cost", value: String(format: "₹%.2f", totalCost)).bold()
                    }
                }
                if isEditing {
                    Section("Status") {
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(OrderStatus.allCases) { Text($0.displayName).tag($0) }
                        }
                    }
                }
                Section("Notes (Optional)") {
                    TextField("Add notes…", text: $notes, axis: .vertical).lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Order" : "New Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving { ProgressView() }
                    else { Button("Save") { save() }.disabled(!isFormValid).tint(.brown) }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard case .edit(let o) = mode else { return }
        selectedItemID = o.itemID; selectedSupplierID = o.supplierID
        quantityText = String(o.quantity); notes = o.notes; selectedStatus = o.status
    }

    private func save() {
        guard isFormValid, let item = selectedItem, let supplier = selectedSupplier else { return }
        isSaving = true
        Task {
            switch mode {
            case .add:
                let order = Order(
                    itemID: selectedItemID, itemName: item.name,
                    supplierID: selectedSupplierID, supplierName: supplier.name,
                    quantity: quantity, unit: item.unit, totalCost: totalCost,
                    status: .pending, notes: notes
                )
                await orderVM.addOrder(order, supplierID: selectedSupplierID, itemID: selectedItemID)
            case .edit(var o):
                o.itemID = selectedItemID; o.itemName = item.name
                o.supplierID = selectedSupplierID; o.supplierName = supplier.name
                o.quantity = quantity; o.unit = item.unit; o.totalCost = totalCost
                o.status = selectedStatus; o.notes = notes
                await orderVM.updateOrder(o)
            }
            isSaving = false; dismiss()
        }
    }
}
