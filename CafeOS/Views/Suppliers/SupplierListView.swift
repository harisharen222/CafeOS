import SwiftUI

struct SupplierListView: View {
    @EnvironmentObject var supplierVM: SupplierViewModel
    @State private var showAddForm = false
    @State private var supplierToDelete: Supplier? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ErrorBannerView(
                    message: supplierVM.errorMessage ?? "",
                    onRetry: { Task { await supplierVM.fetchSuppliers() } },
                    isVisible: $supplierVM.showError
                )
                content
            }
        }
        .navigationTitle("Suppliers")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddForm = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Color.dashCrimson)
                }
            }
        }
        .sheet(isPresented: $showAddForm) { SupplierFormView(mode: .add) }
        .alert("Delete Supplier", isPresented: $showDeleteAlert, presenting: supplierToDelete) { s in
            Button("Delete", role: .destructive) { Task { await supplierVM.deleteSupplier(s) } }
            Button("Cancel", role: .cancel) {}
        } message: { s in Text("Delete \"\(s.name)\"? This cannot be undone.") }
        .task { await supplierVM.fetchSuppliers() }
    }

    @ViewBuilder
    private var content: some View {
        if supplierVM.isLoading && supplierVM.suppliers.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading suppliers…").tint(Color.dashCrimson)
                Spacer()
            }
        } else if supplierVM.suppliers.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(
                    icon: "person.2",
                    title: "No suppliers yet",
                    subtitle: "Tap + to add your first supplier",
                    actionTitle: "Add Supplier"
                ) { showAddForm = true }
                Spacer()
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // Summary banner
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(supplierVM.suppliers.count)")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("Suppliers")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("₹\(Int(supplierVM.totalAmountOwed).formattedWithCommas)")
                                .font(.title2.bold())
                                .foregroundColor(supplierVM.totalAmountOwed > 0 ? Color.dashCrimson : .green)
                            Text("Total Owed")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(16)
                    .background(Color.dashCard)
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                    // Supplier cards
                    ForEach(supplierVM.suppliers) { supplier in
                        NavigationLink(destination: SupplierDetailView(supplier: supplier)) {
                            SupplierCard(supplier: supplier)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                supplierToDelete = supplier
                                showDeleteAlert = true
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task {
                                    var updated = supplier
                                    updated.amountOwed = 0
                                    await supplierVM.updateSupplier(updated)
                                }
                            } label: {
                                Label("Mark Paid", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await supplierVM.fetchSuppliers() }
        }
    }
}

// MARK: — Supplier Card

private struct SupplierCard: View {
    let supplier: Supplier

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + owed badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(supplier.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(supplier.contactName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if supplier.amountOwed > 0 {
                    Text("₹\(Int(supplier.amountOwed).formattedWithCommas) owed")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.dashCrimson)
                        .cornerRadius(10)
                } else {
                    Text("Cleared ✓")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }

            // Chip row
            HStack(spacing: 8) {
                chip(icon: "phone.fill", label: supplier.phone)
                chip(icon: "clock.fill", label: "\(supplier.deliveryDays)d lead")
                chip(icon: "archivebox.fill", label: "\(supplier.itemsSupplied.count) items")
            }
        }
        .padding(16)
        .background(Color.dashCard)
        .cornerRadius(16)
    }

    private func chip(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}
