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
    enum FormField { case name, contactName, phone, email, amountOwed }

    private var isEditing: Bool { if case .edit = mode { return true }; return false }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !contactName.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 7 &&
        (amountOwedText.isEmpty || (Double(amountOwedText) ?? -1) >= 0)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {

                        // ── Business Details ───────────────────────
                        formSection("BUSINESS DETAILS") {
                            formField("Business Name (required)", text: $name, field: .name)
                            if name.trimmingCharacters(in: .whitespaces).isEmpty && focusedField != .name {
                                validationNote("Name cannot be empty.")
                            }
                        }

                        // ── Contact Person ─────────────────────────
                        formSection("CONTACT PERSON") {
                            formField("Contact Name (required)", text: $contactName, field: .contactName)
                            Divider().background(Color.white.opacity(0.07))
                            formField("Phone (required)", text: $phone, field: .phone,
                                      keyboard: .phonePad)
                            if !phone.isEmpty && phone.filter(\.isNumber).count < 7 && focusedField != .phone {
                                validationNote("Enter a valid phone number.")
                            }
                            Divider().background(Color.white.opacity(0.07))
                            formField("Email (optional)", text: $email, field: .email,
                                      keyboard: .emailAddress)
                            if !email.isEmpty && (!email.contains("@") || !email.contains(".")) && focusedField != .email {
                                validationNote("Enter a valid email address.")
                            }
                        }

                        // ── Financial & Logistics ──────────────────
                        formSection("FINANCIAL & LOGISTICS") {
                            // Amount Owed
                            HStack {
                                Text("Amount Owed (₹)")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                TextField("0", text: $amountOwedText)
                                    .keyboardType(.decimalPad)
                                    .focused($focusedField, equals: .amountOwed)
                                    .multilineTextAlignment(.trailing)
                                    .foregroundColor(.white)
                                    .frame(width: 100)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().background(Color.white.opacity(0.07))

                            // Delivery Days stepper
                            VStack(spacing: 8) {
                                HStack {
                                    Text("Delivery Days")
                                        .font(.subheadline).foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(deliveryDays) day\(deliveryDays == 1 ? "" : "s")")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 12)

                                HStack(spacing: 20) {
                                    Button {
                                        if deliveryDays > 1 { deliveryDays -= 1 }
                                    } label: {
                                        Image(systemName: "minus")
                                            .font(.title2.bold())
                                            .foregroundColor(deliveryDays > 1 ? Color.dashCrimson : .secondary)
                                    }
                                    .disabled(deliveryDays <= 1)
                                    .frame(width: 44, height: 44)

                                    Spacer()

                                    Text("\(deliveryDays)")
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Button {
                                        if deliveryDays < 30 { deliveryDays += 1 }
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.title2.bold())
                                            .foregroundColor(deliveryDays < 30 ? Color.dashCrimson : .secondary)
                                    }
                                    .disabled(deliveryDays >= 30)
                                    .frame(width: 44, height: 44)
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(isEditing ? "Edit Supplier" : "Add Supplier")
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
    private func formField(
        _ placeholder: String,
        text: Binding<String>,
        field: FormField,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .keyboardType(keyboard)
            .autocapitalization(keyboard == .emailAddress ? .none : .words)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private func validationNote(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
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
