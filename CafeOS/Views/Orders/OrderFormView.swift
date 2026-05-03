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
    @State private var quantity: Double = 0
    @State private var notes: String = ""
    @State private var selectedStatus: OrderStatus = .pending
    @State private var isSaving = false

    // Quantity stepper state
    @State private var editingQty = false
    @State private var qtyEditText = ""
    @FocusState private var qtyFocused: Bool

    private let qtyPresets: [Double] = [1, 5, 10, 25, 50]

    private var isEditing: Bool { if case .edit = mode { return true }; return false }
    private var selectedItem: InventoryItem? { inventoryVM.items.first { $0.id == selectedItemID } }
    private var selectedSupplier: Supplier? { supplierVM.suppliers.first { $0.id == selectedSupplierID } }
    private var totalCost: Double { quantity * (selectedItem?.costPerUnit ?? 0) }
    private var isFormValid: Bool { !selectedItemID.isEmpty && !selectedSupplierID.isEmpty && quantity > 0 }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── Item ───────────────────────────────────
                        formSection("ITEM") {
                            Picker("Select Item", selection: $selectedItemID) {
                                Text("Choose an item").tag("")
                                ForEach(inventoryVM.items) { item in
                                    Text("\(item.name) (stock: \(String(format: "%.1f", item.quantity)) \(item.unit))")
                                        .tag(item.id ?? "")
                                }
                            }
                            .tint(Color.dashCrimson)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: selectedItemID) { _, newID in
                                if let item = inventoryVM.items.first(where: { $0.id == newID }),
                                   let sID = item.supplierID { selectedSupplierID = sID }
                            }
                            if selectedItemID.isEmpty {
                                Text("Item is required.")
                                    .font(.caption).foregroundColor(.red)
                                    .padding(.horizontal, 16).padding(.bottom, 8)
                            }
                        }

                        // ── Supplier ───────────────────────────────
                        formSection("SUPPLIER") {
                            Picker("Select Supplier", selection: $selectedSupplierID) {
                                Text("Choose a supplier").tag("")
                                ForEach(supplierVM.suppliers) { s in Text(s.name).tag(s.id ?? "") }
                            }
                            .tint(Color.dashCrimson)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            if selectedSupplierID.isEmpty {
                                Text("Supplier is required.")
                                    .font(.caption).foregroundColor(.red)
                                    .padding(.horizontal, 16).padding(.bottom, 8)
                            }
                        }

                        // ── Quantity Stepper ───────────────────────
                        formSection("QUANTITY") {
                            VStack(spacing: 12) {
                                // Preset pills
                                HStack(spacing: 8) {
                                    ForEach(qtyPresets, id: \.self) { preset in
                                        Button {
                                            quantity = preset
                                            editingQty = false
                                        } label: {
                                            Text(String(Int(preset)))
                                                .font(.subheadline.bold())
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(quantity == preset ? Color.dashCrimson : Color.white.opacity(0.08))
                                                .cornerRadius(10)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)

                                // − number + row
                                HStack(spacing: 20) {
                                    Button {
                                        if quantity > 0 { quantity = max(0, quantity - 1) }
                                        editingQty = false
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.title2.bold())
                                            .foregroundColor(quantity > 0 ? Color.dashCrimson : .secondary)
                                    }
                                    .disabled(quantity <= 0)
                                    .frame(width: 44, height: 44)

                                    Spacer()

                                    if editingQty {
                                        TextField("0", text: $qtyEditText)
                                            .focused($qtyFocused)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 40, weight: .bold))
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.white)
                                            .frame(width: 120)
                                            .onSubmit {
                                                if let v = Double(qtyEditText), v >= 0 { quantity = v }
                                                editingQty = false
                                            }
                                    } else {
                                        Button {
                                            qtyEditText = quantity.truncatingRemainder(dividingBy: 1) == 0
                                                ? String(Int(quantity)) : String(quantity)
                                            editingQty = true
                                            qtyFocused = true
                                        } label: {
                                            Text(quantity.truncatingRemainder(dividingBy: 1) == 0
                                                 ? String(Int(quantity))
                                                 : String(format: "%.1f", quantity))
                                                .font(.system(size: 40, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        quantity += 1
                                        editingQty = false
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.title2.bold())
                                            .foregroundColor(Color.dashCrimson)
                                    }
                                    .frame(width: 44, height: 44)
                                }
                                .padding(.horizontal, 16)

                                if let item = selectedItem {
                                    Divider().background(Color.white.opacity(0.07))
                                    HStack {
                                        Text("Unit")
                                            .font(.subheadline).foregroundColor(.secondary)
                                        Spacer()
                                        Text(item.unit)
                                            .font(.subheadline).foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    Divider().background(Color.white.opacity(0.07))
                                    HStack {
                                        Text("Cost / unit")
                                            .font(.subheadline).foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "₹%.2f", item.costPerUnit))
                                            .font(.subheadline).foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                    Divider().background(Color.white.opacity(0.07))
                                    HStack {
                                        Text("Total Cost")
                                            .font(.subheadline.bold()).foregroundColor(.secondary)
                                        Spacer()
                                        Text(String(format: "₹%.2f", totalCost))
                                            .font(.subheadline.bold()).foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 10)
                                }

                                if !String(quantity).isEmpty && quantity <= 0 {
                                    Text("Quantity must be greater than zero.")
                                        .font(.caption).foregroundColor(.red)
                                        .padding(.horizontal, 16).padding(.bottom, 8)
                                }
                            }
                            .padding(.vertical, 12)
                        }

                        // ── Status (edit only) ─────────────────────
                        if isEditing {
                            formSection("STATUS") {
                                Picker("Status", selection: $selectedStatus) {
                                    ForEach(OrderStatus.allCases) { Text($0.displayName).tag($0) }
                                }
                                .tint(Color.dashCrimson)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }

                        // ── Notes ──────────────────────────────────
                        formSection("NOTES (OPTIONAL)") {
                            TextField("Add notes…", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Order" : "New Order")
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

    @ViewBuilder
    private func formSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            VStack(spacing: 0) { content() }
                .background(Color.dashCard)
                .cornerRadius(12)
        }
    }

    private func populateIfEditing() {
        guard case .edit(let o) = mode else { return }
        selectedItemID = o.itemID
        selectedSupplierID = o.supplierID
        quantity = o.quantity
        notes = o.notes
        selectedStatus = o.status
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
