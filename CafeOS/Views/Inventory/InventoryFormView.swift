import SwiftUI

enum InventoryFormMode {
    case add
    case edit(InventoryItem)
}

struct InventoryFormView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    let mode: InventoryFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var category = Constants.Categories.all[0]
    @State private var quantityText = ""
    @State private var unit = Constants.Units.all[0]
    @State private var thresholdText = ""
    @State private var costText = ""
    @State private var supplierID = ""
    @State private var supplierName = ""
    @State private var isSaving = false

    @FocusState private var focusedField: FormField?
    enum FormField { case name, quantity, threshold, cost }

    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    private var quantity: Double { Double(quantityText) ?? -1 }
    private var threshold: Double { Double(thresholdText) ?? -1 }
    private var cost: Double { Double(costText) ?? -1 }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        quantity >= 0 && threshold >= 0 && cost >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Item name (required)", text: $name)
                            .focused($focusedField, equals: .name)
                        if name.trimmingCharacters(in: .whitespaces).isEmpty && focusedField != .name {
                            Text("Name cannot be empty.").font(.caption).foregroundStyle(.red)
                        }
                    }
                    Picker("Category", selection: $category) {
                        ForEach(Constants.Categories.all, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("Stock") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Current quantity", text: $quantityText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .quantity)
                        if quantity < 0 && focusedField != .quantity {
                            Text("Quantity must be 0 or greater.").font(.caption).foregroundStyle(.red)
                        }
                        if quantity >= 0 && threshold >= 0 && quantity < threshold {
                            Text("⚠️ Quantity is below the reorder threshold.")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(Constants.Units.all, id: \.self) { Text($0).tag($0) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Minimum threshold", text: $thresholdText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .threshold)
                        if threshold < 0 && focusedField != .threshold {
                            Text("Threshold cannot be negative.").font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section("Pricing") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Cost per unit", text: $costText)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .cost)
                        if cost < 0 && focusedField != .cost {
                            Text("Cost cannot be negative.").font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section("Supplier (Optional)") {
                    TextField("Supplier name", text: $supplierName)
                    TextField("Supplier ID", text: $supplierID)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving { ProgressView() }
                    else {
                        Button("Save") { save() }
                            .disabled(!isFormValid).tint(.brown)
                    }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    private func populateIfEditing() {
        guard case .edit(let item) = mode else { return }
        name = item.name; category = item.category
        quantityText = String(item.quantity); unit = item.unit
        thresholdText = String(item.minimumThreshold)
        costText = String(item.costPerUnit)
        supplierID = item.supplierID ?? ""; supplierName = item.supplierName ?? ""
    }

    private func save() {
        guard isFormValid else { return }
        isSaving = true
        Task {
            switch mode {
            case .add:
                let newItem = InventoryItem(
                    name: name, category: category, quantity: quantity,
                    unit: unit, minimumThreshold: threshold,
                    supplierID: supplierID.isEmpty ? nil : supplierID,
                    supplierName: supplierName.isEmpty ? nil : supplierName,
                    costPerUnit: cost
                )
                await inventoryVM.addItem(newItem)
            case .edit(var item):
                item.name = name; item.category = category; item.quantity = quantity
                item.unit = unit; item.minimumThreshold = threshold; item.costPerUnit = cost
                item.supplierID = supplierID.isEmpty ? nil : supplierID
                item.supplierName = supplierName.isEmpty ? nil : supplierName
                item.lastUpdated = Date()
                await inventoryVM.updateItem(item)
            }
            isSaving = false; dismiss()
        }
    }
}
