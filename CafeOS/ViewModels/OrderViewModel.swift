import Foundation
import Combine

@MainActor
final class OrderViewModel: ObservableObject {
    @Published var orders: [Order] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false

    private let service = FirestoreService()

    // MARK: — Fetch
    func fetchOrders() async {
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await service.fetch(Constants.Firestore.orders)
            orders.sort { $0.orderDate > $1.orderDate }
        } catch {
            errorMessage = AppError.firestoreFetchFailed.errorDescription
            showError = true
        }
    }

    // MARK: — Add + sync supplier itemsSupplied
    func addOrder(_ order: Order, supplierID: String, itemID: String) async {
        do {
            try await service.add(order, to: Constants.Firestore.orders)
            try await service.addItemToSupplier(supplierID: supplierID, itemID: itemID)
            await fetchOrders()
        } catch {
            errorMessage = AppError.firestoreWriteFailed.errorDescription
            showError = true
        }
    }

    // MARK: — Update
    func updateOrder(_ order: Order) async {
        guard let id = order.id else { return }
        do {
            try await service.update(order, id: id, in: Constants.Firestore.orders)
            await fetchOrders()
        } catch {
            errorMessage = AppError.firestoreWriteFailed.errorDescription
            showError = true
        }
    }

    // MARK: — Delete
    func deleteOrder(id: String) async {
        do {
            try await service.delete(id: id, from: Constants.Firestore.orders)
            orders.removeAll { $0.id == id }
        } catch {
            errorMessage = AppError.firestoreDeleteFailed.errorDescription
            showError = true
        }
    }

    // MARK: — Mark Received (Firestore Transaction)
    func markOrderReceived(order: Order) async {
        guard let orderID = order.id else { return }
        do {
            try await service.markOrderReceived(
                orderID: orderID,
                itemID: order.itemID,
                quantity: order.quantity
            )
            await fetchOrders()
        } catch {
            errorMessage = AppError.transactionFailed.errorDescription
            showError = true
        }
    }

    // MARK: — Filtered helpers
    var pendingOrders: [Order]   { orders.filter { $0.status == .pending } }
    var receivedOrders: [Order]  { orders.filter { $0.status == .received } }
    var cancelledOrders: [Order] { orders.filter { $0.status == .cancelled } }
    var totalSpend: Double       { orders.filter { $0.status == .received }.reduce(0) { $0 + $1.totalCost } }
}
