import SwiftUI

enum SupplierFormMode {
    case add
    case edit(Supplier)
}

struct SupplierFormView: View {
    @EnvironmentObject var supplierVM: SupplierViewModel
    let mode: SupplierFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var amountOwedText = ""
    @State private var deliveryDays = 3
    @State private var isSaving = false

    @FocusState private var focusedField: FormField?
    enum FormField { case name, phone, email }

    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 7 &&
        (amountOwedText.isEmpty || (Double(amountOwedText) ?? -1) >= 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Business Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Business Name (required)", text: $name)
                            .focused($focusedField, equals: .name)
                        if name.trimmingCharacters(in: .whitespaces).isEmpty && focusedField != .name {
                            Text("Name cannot be empty.").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Section("Contact Person") {
                    TextField("Contact Name (required)", text: $contactName)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone (required)", text: $phone)
                            .keyboardType(.phonePad)
                            .focused($focusedField, equals: .phone)
                        if phone.filter(\.isNumber).count < 7 && focusedField != .phone && !phone.isEmpty {
                            Text("Enter a valid phone number.").font(.caption).foregroundStyle(.red)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email (optional)", text: $email)
                            .keyboardType(.emailAddress).autocapitalization(.none)
                            .focused($focusedField, equals: .email)
                        if !email.isEmpty && (!email.contains("@") || !email.contains(".")) && focusedField != .email {
                            Text("Enter a valid email address.").font(.caption).foregroundStyle(.red)
                        }
                    }
                }
                Section("Financial & Logistics") {
                    TextField("Amount Owed (₹)", text: $amountOwedText).keyboardType(.decimalPad)
                    Stepper("Delivery Days: \(deliveryDays)", value: $deliveryDays, in: 1...30)
                }
            }
            .navigationTitle(isEditing ? "Edit Supplier" : "Add Supplier")
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
        guard case .edit(let s) = mode else { return }
        name = s.name; contactName = s.contactName; phone = s.phone
        email = s.email; deliveryDays = s.deliveryDays
        amountOwedText = s.amountOwed > 0 ? String(s.amountOwed) : ""
    }

    private func save() {
        guard isFormValid else { return }
        isSaving = true
        let owed = Double(amountOwedText) ?? 0
        Task {
            switch mode {
            case .add:
                let s = Supplier(name: name, contactName: contactName, phone: phone,
                                 email: email, amountOwed: owed, deliveryDays: deliveryDays)
                await supplierVM.addSupplier(s)
            case .edit(var s):
                s.name = name; s.contactName = contactName; s.phone = phone
                s.email = email; s.amountOwed = owed; s.deliveryDays = deliveryDays
                await supplierVM.updateSupplier(s)
            }
            isSaving = false; dismiss()
        }
    }
}
