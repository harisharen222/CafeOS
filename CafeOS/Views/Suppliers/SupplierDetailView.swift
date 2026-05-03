import SwiftUI

struct SupplierDetailView: View {
    let supplier: Supplier
    @EnvironmentObject var supplierVM: SupplierViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showEditForm = false
    @State private var showDeleteAlert = false
    @State private var showMarkPaidAlert = false

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {

                    // ── Contact Info ───────────────────────────────
                    detailSection("CONTACT INFO") {
                        detailRow("Business Name", value: supplier.name)
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Contact Person", value: supplier.contactName)
                        Divider().background(Color.white.opacity(0.07))
                        // Tappable phone
                        HStack {
                            Text("Phone")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            if let url = URL(string: "tel:\(supplier.phone)") {
                                Link(supplier.phone, destination: url)
                                    .font(.subheadline)
                                    .foregroundColor(Color.dashCrimson)
                            } else {
                                Text(supplier.phone)
                                    .font(.subheadline).foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                        if !supplier.email.isEmpty {
                            Divider().background(Color.white.opacity(0.07))
                            HStack {
                                Text("Email")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                if let url = URL(string: "mailto:\(supplier.email)") {
                                    Link(supplier.email, destination: url)
                                        .font(.subheadline)
                                        .foregroundColor(Color.dashCrimson)
                                } else {
                                    Text(supplier.email)
                                        .font(.subheadline).foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    // ── Financial & Logistics ──────────────────────
                    detailSection("FINANCIAL & LOGISTICS") {
                        HStack {
                            Text("Amount Owed")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "₹%.2f", supplier.amountOwed))
                                .font(.subheadline.bold())
                                .foregroundColor(supplier.amountOwed > 0 ? Color.dashCrimson : .green)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        Divider().background(Color.white.opacity(0.07))
                        detailRow("Delivery Time", value: "\(supplier.deliveryDays) day\(supplier.deliveryDays == 1 ? "" : "s") avg. lead time")
                    }

                    // ── Items Supplied ─────────────────────────────
                    detailSection("ITEMS SUPPLIED") {
                        if supplier.itemsSupplied.isEmpty {
                            Text("No items linked yet")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        } else {
                            HStack {
                                Text("Linked Items")
                                    .font(.subheadline).foregroundColor(.secondary)
                                Spacer()
                                Text("\(supplier.itemsSupplied.count)")
                                    .font(.title2.bold()).foregroundColor(.white)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            Divider().background(Color.white.opacity(0.07))
                            ForEach(supplier.itemsSupplied, id: \.self) { itemID in
                                HStack {
                                    Image(systemName: "archivebox.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(itemID)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                            }
                        }
                    }

                    // ── Mark as Paid ───────────────────────────────
                    if supplier.amountOwed > 0 {
                        Button {
                            showMarkPaidAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Paid")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }

                    // ── Delete ─────────────────────────────────────
                    Button {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Supplier")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 32)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle(supplier.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEditForm = true }
                    .foregroundColor(Color.dashCrimson)
            }
        }
        .sheet(isPresented: $showEditForm) { SupplierFormView(mode: .edit(supplier)) }
        .alert("Mark as Paid", isPresented: $showMarkPaidAlert) {
            Button("Mark Paid") {
                Task {
                    var updated = supplier
                    updated.amountOwed = 0
                    await supplierVM.updateSupplier(updated)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set amount owed to ₹0 for \(supplier.name)?")
        }
        .alert("Delete Supplier", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await supplierVM.deleteSupplier(supplier); dismiss() }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Delete \"\(supplier.name)\"? This cannot be undone.") }
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .kerning(1.5)
                .padding(.horizontal, 20)
                .padding(.bottom, 6)
            VStack(spacing: 0) {
                content()
            }
            .background(Color.dashCard)
            .cornerRadius(12)
            .padding(.horizontal, 16)
        }
    }

    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline).foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
