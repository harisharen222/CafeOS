import Foundation
import Combine

@MainActor
class SupplierViewModel: ObservableObject {
    @Published var suppliers: [Supplier] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false

    private let service = FirestoreService()

    var totalAmountOwed: Double {
        suppliers.reduce(0) { $0 + $1.amountOwed }
    }

    func fetchSuppliers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            suppliers = (try await service.fetch(Constants.Firestore.suppliers) as [Supplier])
                .sorted { $0.name < $1.name }
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    func addSupplier(_ supplier: Supplier) async {
        do {
            try await service.add(supplier, to: Constants.Firestore.suppliers)
            await fetchSuppliers()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    func updateSupplier(_ supplier: Supplier) async {
        guard let id = supplier.id else { return }
        do {
            try await service.update(supplier, id: id, in: Constants.Firestore.suppliers)
            await fetchSuppliers()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }

    func deleteSupplier(_ supplier: Supplier) async {
        guard let id = supplier.id else { return }
        do {
            try await service.delete(id: id, from: Constants.Firestore.suppliers)
            await fetchSuppliers()
        } catch {
            errorMessage = (error as? AppError)?.errorDescription ?? error.localizedDescription
            showError = true
        }
    }
}
