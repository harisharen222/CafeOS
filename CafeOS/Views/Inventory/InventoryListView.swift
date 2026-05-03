import SwiftUI

struct InventoryListView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showAddForm = false
    @State private var showCSVImport = false
    @State private var showAddOptions = false
    @State private var itemToDelete: InventoryItem? = nil
    @State private var showDeleteAlert = false

    private var categories: [String] { ["All"] + Constants.Categories.all }

    private var filteredItems: [InventoryItem] {
        let bySearch = searchText.isEmpty
            ? inventoryVM.items
            : inventoryVM.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        guard selectedCategory != "All" else { return bySearch }
        return bySearch.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ZStack {
            Color.dashBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                ErrorBannerView(
                    message: inventoryVM.errorMessage ?? "",
                    onRetry: { inventoryVM.startListening() },
                    isVisible: $inventoryVM.showError
                )

                // Category filter pill row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.caption.bold())
                                    .foregroundColor(selectedCategory == cat ? .white : .secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedCategory == cat
                                            ? Color.dashCrimson
                                            : Color.dashCard
                                    )
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }

                content
            }
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddOptions = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(Color.dashCrimson)
                }
            }
        }
        .confirmationDialog("Add Inventory Item", isPresented: $showAddOptions, titleVisibility: .visible) {
            Button("Add Manually") { showAddForm = true }
            Button("Import from CSV") { showCSVImport = true }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showAddForm) {
            InventoryFormView(mode: .add)
        }
        .sheet(isPresented: $showCSVImport) {
            CSVImportView()
        }
        .alert("Delete Item", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
            Button("Delete", role: .destructive) {
                Task { await inventoryVM.deleteItem(item) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { item in
            Text("Delete \"\(item.name)\"? This cannot be undone.")
        }
        .onAppear { inventoryVM.startListening() }
    }

    @ViewBuilder
    private var content: some View {
        if inventoryVM.isLoading && inventoryVM.items.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading inventory…").tint(Color.dashCrimson)
                Spacer()
            }
        } else if inventoryVM.items.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(
                    icon: "archivebox",
                    title: "No items yet",
                    subtitle: "Tap + to add your first inventory item",
                    actionTitle: "Add Item"
                ) { showAddForm = true }
                Spacer()
            }
        } else if filteredItems.isEmpty {
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No results")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Try a different search or category")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: InventoryDetailView(item: item)) {
                            InventoryItemCard(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
}

// MARK: — Inventory Item Card

private struct InventoryItemCard: View {
    let item: InventoryItem

    private var statusColor: Color {
        if item.quantity == 0 { return .red }
        if item.isLowStock { return .orange }
        return .green
    }

    private var statusLabel: String {
        if item.quantity == 0 { return "OUT" }
        if item.isLowStock { return "LOW" }
        return "OK"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left status bar
            Rectangle()
                .fill(statusColor)
                .frame(width: 4)
                .cornerRadius(2)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(item.category)
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.07))
                            .cornerRadius(6)
                    }
                    if let supplier = item.supplierName {
                        Text(supplier)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(item.lastUpdated.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(Color.white.opacity(0.3))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(String(format: "%.1f", item.quantity))")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text(item.unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(statusLabel)
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor)
                        .cornerRadius(4)
                }
            }
            .padding(14)
        }
        .background(Color.dashCard)
        .cornerRadius(12)
    }
}
