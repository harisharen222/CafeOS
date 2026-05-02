import Foundation
import Combine
import FirebaseFirestore

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false

    private let service = FirestoreService()
    private var listener: ListenerRegistration?

    // MARK: — Real-time listener (guard prevents duplicate listeners)
    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = service.listen(Constants.Firestore.inventory) { [weak self] (fetched: [InventoryItem]) in
            guard let self else { return }
            self.items = fetched.sorted { $0.name < $1.name }
            self.isLoading = false
            self.handleLowStockNotifications(for: fetched)
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    deinit { listener?.remove() }

    // MARK: — Computed
    var lowStockItems: [InventoryItem] { items.filter { $0.isLowStock } }
    var lowStockCount: Int { lowStockItems.count }

    // MARK: — CRUD
    func addItem(_ item: InventoryItem) async {
        do {
            try await service.add(item, to: Constants.Firestore.inventory)
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    func updateItem(_ item: InventoryItem) async {
        guard let id = item.id else { return }
        do {
            try await service.update(item, id: id, in: Constants.Firestore.inventory)
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    func deleteItem(_ item: InventoryItem) async {
        guard let id = item.id else { return }
        do {
            try await service.delete(id: id, from: Constants.Firestore.inventory)
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    // MARK: — Notification stub (Day 3)
    private func handleLowStockNotifications(for items: [InventoryItem]) {
        let low = items.filter { $0.isLowStock }
        if !low.isEmpty {
            print("[CafeOS] Low stock: \(low.map { $0.name }.joined(separator: ", "))")
        }
    }
}
