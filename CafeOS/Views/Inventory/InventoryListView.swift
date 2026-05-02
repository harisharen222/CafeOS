import SwiftUI

struct InventoryListView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showAddForm = false
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
        VStack(spacing: 0) {
            ErrorBannerView(
                message: inventoryVM.errorMessage ?? "",
                onRetry: { inventoryVM.startListening() },
                isVisible: $inventoryVM.showError
            )
            content
        }
        .navigationTitle("Inventory")
        .searchable(text: $searchText, prompt: "Search items")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddForm) {
            InventoryFormView(mode: .add)
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
            ProgressView("Loading inventory…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if inventoryVM.items.isEmpty {
            EmptyStateView(
                icon: "archivebox",
                title: "No items yet",
                subtitle: "Tap + to add your first inventory item",
                actionTitle: "Add Item"
            ) { showAddForm = true }
        } else {
            inventoryList
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddForm = true } label: { Image(systemName: "plus") }
        }
        ToolbarItem(placement: .topBarLeading) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu).tint(.brown)
        }
    }

    private var inventoryList: some View {
        List {
            ForEach(filteredItems) { item in
                NavigationLink {
                    InventoryDetailView(item: item)
                } label: {
                    InventoryRowView(item: item)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        itemToDelete = item; showDeleteAlert = true
                    } label: { Label("Delete", systemImage: "trash") }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct InventoryRowView: View {
    let item: InventoryItem
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text("\(String(format: "%.1f", item.quantity)) \(item.unit) · \(item.category)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if item.isLowStock {
                Text("Low Stock")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.red.opacity(0.15))
                    .foregroundStyle(.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}
