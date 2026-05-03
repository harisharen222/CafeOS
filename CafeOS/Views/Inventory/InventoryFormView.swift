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
    @State private var quantity: Double = 0
    @State private var unit = Constants.Units.all[0]
    @State private var threshold: Double = 0
    @State private var cost: Double = 0
    @State private var supplierID = ""
    @State private var supplierName = ""
    @State private var isSaving = false

    // Inline edit states for tappable number
    @State private var editingQuantity = false
    @State private var editingThreshold = false
    @State private var quantityEditText = ""
    @State private var thresholdEditText = ""

    @FocusState private var focusedField: FormField?
    enum FormField { case name, cost, quantityEdit, thresholdEdit }

    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantity >= 0 && threshold >= 0 && cost >= 0
    }

    private let quantityPresets: [Double] = [1, 5, 10, 25, 50]
    private let thresholdPresets: [Double] = [1, 2, 5, 10, 20]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── Item Details ───────────────────────────
                        formSection("ITEM DETAILS") {
                            darkField("Item name (required)", text: $name, field: .name)
                            Divider().background(Color.white.opacity(0.07))
                            HStack {
                                Text("Category")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("", selection: $category) {
                                    ForEach(Constants.Categories.all, id: \.self) { Text($0).tag($0) }
                                }
                                .tint(Color.dashCrimson)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // ── Quantity Stepper ───────────────────────
                        formSection("QUANTITY") {
                            stepperField(
                                label: "Current Stock",
                                value: $quantity,
                                presets: quantityPresets,
                                editing: $editingQuantity,
                                editText: $quantityEditText,
                                field: .quantityEdit
                            )
                            Divider().background(Color.white.opacity(0.07))
                            HStack {
                                Text("Unit")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("", selection: $unit) {
                                    ForEach(Constants.Units.all, id: \.self) { Text($0).tag($0) }
                                }
                                .tint(Color.dashCrimson)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // ── Minimum Threshold ──────────────────────
                        formSection("MINIMUM THRESHOLD") {
                            stepperField(
                                label: "Reorder Point",
                                value: $threshold,
                                presets: thresholdPresets,
                                editing: $editingThreshold,
                                editText: $thresholdEditText,
                                field: .thresholdEdit
                            )
                            if quantity >= 0 && threshold > 0 && quantity < threshold {
                                HStack(spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    Text("Quantity is below the reorder threshold")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }

                        // ── Pricing ────────────────────────────────
                        formSection("PRICING") {
                            HStack {
                                Text("Cost per unit (₹)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                TextField("0.00", value: $cost, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                                    .focused($focusedField, equals: .cost)
                                    .frame(width: 100)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        // ── Supplier (Optional) ────────────────────
                        formSection("SUPPLIER (OPTIONAL)") {
                            HStack {
                                Text("Supplier Name")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                TextField("—", text: $supplierName)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 160)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider().background(Color.white.opacity(0.07))
                            HStack {
                                Text("Supplier ID")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                TextField("—", text: $supplierID)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: 160)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isSaving { ProgressView().tint(Color.dashCrimson) }
                    else {
                        Button("Save") { save() }
                            .foregroundColor(isFormValid ? Color.dashCrimson : .secondary)
                            .disabled(!isFormValid)
                    }
                }
            }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: — Helpers

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.dashCard)
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private func darkField(_ placeholder: String, text: Binding<String>, field: FormField) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    @ViewBuilder
    private func stepperField(
        label: String,
        value: Binding<Double>,
        presets: [Double],
        editing: Binding<Bool>,
        editText: Binding<String>,
        field: FormField
    ) -> some View {
        VStack(spacing: 12) {
            // Preset pills
            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        value.wrappedValue = preset
                        editing.wrappedValue = false
                    } label: {
                        Text(preset.truncatingRemainder(dividingBy: 1) == 0
                             ? String(Int(preset))
                             : String(preset))
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(value.wrappedValue == preset ? Color.dashCrimson : Color.white.opacity(0.08))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 16)

            // − number + row
            HStack(spacing: 20) {
                Button {
                    if value.wrappedValue > 0 {
                        value.wrappedValue = max(0, value.wrappedValue - 1)
                    }
                    editing.wrappedValue = false
                } label: {
                    Image(systemName: "minus")
                        .font(.title2.bold())
                        .foregroundColor(value.wrappedValue > 0 ? Color.dashCrimson : .secondary)
                }
                .disabled(value.wrappedValue <= 0)
                .frame(width: 44, height: 44)

                Spacer()

                if editing.wrappedValue {
                    TextField("0", text: editText)
                        .focused($focusedField, equals: field)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 40, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white)
                        .frame(width: 120)
                        .onSubmit {
                            if let v = Double(editText.wrappedValue), v >= 0 {
                                value.wrappedValue = v
                            }
                            editing.wrappedValue = false
                        }
                } else {
                    Button {
                        editText.wrappedValue = value.wrappedValue.truncatingRemainder(dividingBy: 1) == 0
                            ? String(Int(value.wrappedValue))
                            : String(value.wrappedValue)
                        editing.wrappedValue = true
                        focusedField = field
                    } label: {
                        Text(value.wrappedValue.truncatingRemainder(dividingBy: 1) == 0
                             ? String(Int(value.wrappedValue))
                             : String(format: "%.1f", value.wrappedValue))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Spacer()

                Button {
                    value.wrappedValue += 1
                    editing.wrappedValue = false
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.bold())
                        .foregroundColor(Color.dashCrimson)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }

    private func populateIfEditing() {
        guard case .edit(let item) = mode else { return }
        name = item.name
        category = item.category
        quantity = item.quantity
        unit = item.unit
        threshold = item.minimumThreshold
        cost = item.costPerUnit
        supplierID = item.supplierID ?? ""
        supplierName = item.supplierName ?? ""
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
