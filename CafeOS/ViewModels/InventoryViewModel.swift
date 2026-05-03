import Foundation
import Combine
import FirebaseFirestore

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false

    // CSV import state
    @Published var importProgress: Double = 0.0
    @Published var importResult: String? = nil

    private let service = FirestoreService()
    private var listener: ListenerRegistration?

    // MARK: — Real-time listener
    func startListening() {
        guard listener == nil else { return }
        isLoading = true
        listener = service.listen(Constants.Firestore.inventory) { [weak self] (fetched: [InventoryItem]) in
            guard let self else { return }
            self.items = fetched.sorted { $0.name < $1.name }
            self.isLoading = false
            let lowItems = self.items.filter { $0.isLowStock }
            NotificationService.shared.scheduleLowStockAlert(for: lowItems)
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

    // MARK: — Bulk Import (CSV)
    func bulkImport(items importItems: [InventoryItem]) async {
        guard !importItems.isEmpty else { return }
        importProgress = 0.0
        importResult = nil
        var successCount = 0
        var failCount = 0

        for (index, item) in importItems.enumerated() {
            do {
                try await service.add(item, to: Constants.Firestore.inventory)
                successCount += 1
            } catch {
                failCount += 1
            }
            importProgress = Double(index + 1) / Double(importItems.count)
        }

        if failCount == 0 {
            importResult = "\(successCount) item\(successCount == 1 ? "" : "s") imported successfully"
        } else {
            importResult = "\(successCount) imported, \(failCount) failed"
            if failCount > 0 {
                errorMessage = "\(failCount) item\(failCount == 1 ? "" : "s") failed to import"
                showError = true
            }
        }
    }

    // MARK: — CSV Parser
    struct CSVParseResult {
        let item: InventoryItem?
        let errorReason: String?
        let rawName: String
        var isValid: Bool { item != nil }
    }

    func parseCSV(_ text: String) -> [CSVParseResult] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return [] }

        // Skip header row
        let dataLines = lines.dropFirst()
        guard !dataLines.isEmpty else { return [] }

        return dataLines.map { line -> CSVParseResult in
            let cols = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let name = cols.count > 0 ? cols[0] : ""
            guard !name.isEmpty else {
                return CSVParseResult(item: nil, errorReason: "Name is required", rawName: line)
            }
            let categoryRaw = cols.count > 1 ? cols[1] : ""
            let category = Constants.Categories.all.contains(categoryRaw) ? categoryRaw : "Other"
            guard let quantity = cols.count > 2 ? Double(cols[2]) : nil, quantity >= 0 else {
                return CSVParseResult(item: nil, errorReason: "Invalid quantity", rawName: name)
            }
            let unit = cols.count > 3 && !cols[3].isEmpty ? cols[3] : "pcs"
            guard let threshold = cols.count > 4 ? Double(cols[4]) : nil, threshold >= 0 else {
                return CSVParseResult(item: nil, errorReason: "Invalid threshold", rawName: name)
            }
            guard let cost = cols.count > 5 ? Double(cols[5]) : nil, cost >= 0 else {
                return CSVParseResult(item: nil, errorReason: "Invalid cost", rawName: name)
            }
            let item = InventoryItem(
                name: name, category: category, quantity: quantity,
                unit: unit, minimumThreshold: threshold,
                supplierID: nil, supplierName: nil, costPerUnit: cost
            )
            return CSVParseResult(item: item, errorReason: nil, rawName: name)
        }
    }
}
