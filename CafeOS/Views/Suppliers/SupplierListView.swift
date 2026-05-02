import SwiftUI

struct SupplierListView: View {
    @ObservedObject var viewModel: SupplierViewModel
    @State private var showAddForm = false
    @State private var supplierToDelete: Supplier? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.suppliers.isEmpty {
                    ProgressView("Loading suppliers…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.suppliers.isEmpty {
                    emptyStateView
                } else {
                    supplierList
                }
            }
            .navigationTitle("Suppliers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddForm = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddForm) {
                SupplierFormView(viewModel: viewModel, mode: .add)
            }
            .alert("Delete Supplier", isPresented: $showDeleteAlert, presenting: supplierToDelete) { supplier in
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteSupplier(supplier) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { supplier in
                Text("Delete \"\(supplier.name)\"? This cannot be undone.")
            }
            .task {
                await viewModel.fetchSuppliers()
            }
        }
    }

    private var supplierList: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
            
            if viewModel.totalAmountOwed > 0 {
                Section {
                    HStack {
                        Text("Total Owed")
                            .font(.subheadline)
                        Spacer()
                        Text(String(format: "₹%.2f", viewModel.totalAmountOwed))
                            .bold()
                            .foregroundStyle(.orange)
                    }
                }
            }

            ForEach(viewModel.suppliers) { supplier in
                NavigationLink {
                    SupplierDetailView(supplier: supplier, viewModel: viewModel)
                } label: {
                    SupplierRowView(supplier: supplier)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        supplierToDelete = supplier
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await viewModel.fetchSuppliers()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2")
                .font(.system(size: 48))
                .foregroundStyle(.brown.opacity(0.4))
            Text("No suppliers yet")
                .font(.title3).bold()
            Text("Add your first supplier to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Supplier") { showAddForm = true }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SupplierRowView: View {
    let supplier: Supplier
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(supplier.name).font(.headline)
                Text(supplier.contactName)
                    .font(.caption).foregroundStyle(.secondary)
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
