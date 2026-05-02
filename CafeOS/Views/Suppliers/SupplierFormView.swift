import SwiftUI

enum SupplierFormMode {
    case add
    case edit(Supplier)
}

struct SupplierFormView: View {
    @ObservedObject var viewModel: SupplierViewModel
    let mode: SupplierFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var amountOwedText = ""
    @State private var deliveryDays = 3
    @State private var isSaving = false

    // Validation
    @State private var nameError: String? = nil
    @State private var phoneError: String? = nil

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phone.trimmingCharacters(in: .whitespaces).isEmpty &&
        (amountOwedText.isEmpty || (Double(amountOwedText) ?? -1) >= 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Business Details") {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Business Name (required)", text: $name)
                            .onChange(of: name) { _, _ in validateName() }
                        if let err = nameError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }
                }

                Section("Contact Person") {
                    TextField("Contact Name (required)", text: $contactName)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Phone (required)", text: $phone)
                            .keyboardType(.phonePad)
                            .onChange(of: phone) { _, _ in validatePhone() }
                        if let err = phoneError {
                            Text(err).font(.caption).foregroundStyle(.red)
                        }
                    }

                    TextField("Email (optional)", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }

                Section("Financial & Logistics") {
                    TextField("Amount Owed (₹)", text: $amountOwedText)
                        .keyboardType(.decimalPad)

                    Stepper("Delivery Days: \(deliveryDays)", value: $deliveryDays, in: 1...30)
                }
            }
            .navigationTitle(isEditing ? "Edit Supplier" : "Add Supplier")
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

    private func validateName() {
        nameError = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Business Name is required" : nil
    }

    private func validatePhone() {
        phoneError = phone.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Phone is required" : nil
    }

    private func populateIfEditing() {
        guard case .edit(let supplier) = mode else { return }
        name = supplier.name
        contactName = supplier.contactName
        phone = supplier.phone
        email = supplier.email
        amountOwedText = supplier.amountOwed > 0 ? String(supplier.amountOwed) : ""
        deliveryDays = supplier.deliveryDays
    }

    private func save() {
        validateName()
        validatePhone()
        guard isFormValid else { return }

        isSaving = true
        let owed = Double(amountOwedText) ?? 0

        Task {
            switch mode {
            case .add:
                let newSupplier = Supplier(
                    name: name,
                    contactName: contactName,
                    phone: phone,
                    email: email,
                    amountOwed: owed,
                    deliveryDays: deliveryDays,
                    itemsSupplied: [] // Day 2 feature
                )
                await viewModel.addSupplier(newSupplier)
            case .edit(var supplier):
                supplier.name = name
                supplier.contactName = contactName
                supplier.phone = phone
                supplier.email = email
                supplier.amountOwed = owed
                supplier.deliveryDays = deliveryDays
                await viewModel.updateSupplier(supplier)
            }
            isSaving = false
            dismiss()
        }
    }
}
