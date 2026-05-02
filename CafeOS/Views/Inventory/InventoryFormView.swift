import SwiftUI

enum InventoryFormMode {
    case add
    case edit(InventoryItem)
}

struct InventoryFormView: View {
    @ObservedObject var viewModel: InventoryViewModel
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

    // Validation
    @State private var nameError: String? = nil
    @State private var quantityError: String? = nil

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (Double(quantityText) ?? -1) >= 0 &&
        (Double(thresholdText) ?? -1) >= 0 &&
        (Double(costText) ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Item name (required)", text: $name)
                            .onChange(of: name) { _, _ in validateName() }
                        if let err = nameError {
                            Text(err).font(.caption).foregroundStyle(.red)
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
                            .onChange(of: quantityText) { _, _ in validateQuantity() }
                        if let err = quantityError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                    Picker("Unit", selection: $unit) {
                        ForEach(Constants.Units.all, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Minimum threshold", text: $thresholdText)
                        .keyboardType(.decimalPad)
                }

                Section("Pricing") {
                    TextField("Cost per unit", text: $costText)
                        .keyboardType(.decimalPad)
                }

                Section("Supplier (Optional)") {
                    TextField("Supplier name", text: $supplierName)
                    TextField("Supplier ID", text: $supplierID)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { save() }
                            .disabled(!isFormValid)
                            .tint(.brown)
                    }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: — Helpers
    private func validateName() {
        nameError = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Name is required" : nil
    }

    private func validateQuantity() {
        guard let q = Double(quantityText) else {
            quantityError = "Enter a valid number"; return
        }
        quantityError = q < 0 ? "Quantity must be 0 or more" : nil
    }

    private func populateIfEditing() {
        guard case .edit(let item) = mode else { return }
        name          = item.name
        category      = item.category
        quantityText  = String(item.quantity)
        unit          = item.unit
        thresholdText = String(item.minimumThreshold)
        costText      = String(item.costPerUnit)
        supplierID    = item.supplierID ?? ""
        supplierName  = item.supplierName ?? ""
    }

    private func save() {
        validateName(); validateQuantity()
        guard isFormValid else { return }

        isSaving = true
        let qty  = Double(quantityText) ?? 0
        let thr  = Double(thresholdText) ?? 0
        let cost = Double(costText) ?? 0

        Task {
            switch mode {
            case .add:
                let newItem = InventoryItem(
                    name: name, category: category,
                    quantity: qty, unit: unit,
                    minimumThreshold: thr,
                    supplierID: supplierID.isEmpty ? nil : supplierID,
                    supplierName: supplierName.isEmpty ? nil : supplierName,
                    costPerUnit: cost
                )
                await viewModel.addItem(newItem)
            case .edit(var item):
                item.name            = name
                item.category        = category
                item.quantity        = qty
                item.unit            = unit
                item.minimumThreshold = thr
                item.costPerUnit     = cost
                item.supplierID      = supplierID.isEmpty ? nil : supplierID
                item.supplierName    = supplierName.isEmpty ? nil : supplierName
                item.lastUpdated     = Date()
                await viewModel.updateItem(item)
            }
            isSaving = false
            dismiss()
        }
    }
}
