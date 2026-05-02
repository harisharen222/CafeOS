import SwiftUI

struct SupplierListView: View {
    @EnvironmentObject var supplierVM: SupplierViewModel
    @State private var showAddForm = false
    @State private var supplierToDelete: Supplier? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            ErrorBannerView(
                message: supplierVM.errorMessage ?? "",
                onRetry: { Task { await supplierVM.fetchSuppliers() } },
                isVisible: $supplierVM.showError
            )
            content
        }
        .navigationTitle("Suppliers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddForm = true } label: { Image(systemName: "plus") }
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
            ProgressView("Loading suppliers…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if supplierVM.suppliers.isEmpty {
            EmptyStateView(
                icon: "person.2",
                title: "No suppliers yet",
                subtitle: "Tap + to add your first supplier",
                actionTitle: "Add Supplier"
            ) { showAddForm = true }
        } else {
            List {
                if supplierVM.totalAmountOwed > 0 {
                    Section {
                        HStack {
                            Text("Total Owed").font(.subheadline)
                            Spacer()
                            Text(String(format: "₹%.2f", supplierVM.totalAmountOwed))
                                .bold().foregroundStyle(.orange)
                        }
                    }
                }
                ForEach(supplierVM.suppliers) { supplier in
                    NavigationLink {
                        SupplierDetailView(supplier: supplier)
                    } label: {
                        SupplierRowView(supplier: supplier)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            supplierToDelete = supplier; showDeleteAlert = true
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .refreshable { await supplierVM.fetchSuppliers() }
        }
    }
}

private struct SupplierRowView: View {
    let supplier: Supplier
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(supplier.name).font(.headline)
                Text(supplier.contactName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if supplier.amountOwed > 0 {
                Text(String(format: "₹%.2f owed", supplier.amountOwed))
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
