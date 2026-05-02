import Foundation
import FirebaseFirestore

struct InventoryItem: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var category: String
    var quantity: Double
    var unit: String
    var minimumThreshold: Double
    var supplierID: String?
    var supplierName: String?
    var costPerUnit: Double
    var lastUpdated: Date

    init(
        id: String? = nil,
        name: String,
        category: String,
        quantity: Double,
        unit: String,
        minimumThreshold: Double,
        supplierID: String? = nil,
        supplierName: String? = nil,
        costPerUnit: Double,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.minimumThreshold = minimumThreshold
        self.supplierID = supplierID
        self.supplierName = supplierName
        self.costPerUnit = costPerUnit
        self.lastUpdated = lastUpdated
    }

    var isLowStock: Bool { quantity <= minimumThreshold }
}
