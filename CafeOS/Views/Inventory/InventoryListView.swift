import SwiftUI

struct InventoryListView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showAddForm = false
    @State private var itemToDelete: InventoryItem? = nil
    @State private var showDeleteAlert = false

    private var categories: [String] { ["All"] + Constants.Categories.all }

    private var filteredItems: [InventoryItem] {
        let bySearch = searchText.isEmpty
            ? viewModel.items
            : viewModel.items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        guard selectedCategory != "All" else { return bySearch }
        return bySearch.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Inventory")
                .searchable(text: $searchText, prompt: "Search items")
                .toolbar { toolbarContent }
                .sheet(isPresented: $showAddForm) {
                    InventoryFormView(viewModel: viewModel, mode: .add)
                }
                .alert("Delete Item", isPresented: $showDeleteAlert, presenting: itemToDelete) { item in
                    Button("Delete", role: .destructive) {
                        Task { await viewModel.deleteItem(item) }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: { item in
                    Text("Delete \"\(item.name)\"? This cannot be undone.")
                }
                .onAppear { viewModel.startListening() }
                .onDisappear { viewModel.stopListening() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView("Loading inventory…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.items.isEmpty {
            emptyStateView
        } else {
            inventoryList
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { showAddForm = true } label: {
                Image(systemName: "plus")
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Picker("Category", selection: $selectedCategory) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(.brown)
        }
    }

    private var inventoryList: some View {
        List {
            if let error = viewModel.errorMessage {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
            ForEach(filteredItems) { item in
                NavigationLink {
                    InventoryDetailView(item: item, viewModel: viewModel)
                } label: {
                    InventoryRowView(item: item)
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
        .listStyle(.insetGrouped)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundStyle(.brown.opacity(0.4))
            Text("No items yet")
                .font(.title3).bold()
            Text("Add your first inventory item to get started.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Add Item") { showAddForm = true }
                .buttonStyle(.borderedProminent)
                .tint(.brown)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: — Row subview
private struct InventoryRowView: View {
    let item: InventoryItem
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                Text("\(item.quantity, specifier: "%.1f") \(item.unit) · \(item.category)")
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
