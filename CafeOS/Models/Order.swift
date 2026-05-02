import Foundation
import FirebaseFirestore

enum OrderStatus: String, Codable, CaseIterable, Identifiable {
    case pending, received, cancelled
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pending:   return "Pending"
        case .received:  return "Received"
        case .cancelled: return "Cancelled"
        }
    }
    var color: String {
        switch self {
        case .pending:   return "orange"
        case .received:  return "green"
        case .cancelled: return "red"
        }
    }
}

struct Order: Identifiable, Codable {
    @DocumentID var id: String?
    var itemID: String
    var itemName: String
    var supplierID: String
    var supplierName: String
    var quantity: Double
    var unit: String
    var totalCost: Double
    var status: OrderStatus
    var orderDate: Date
    var receivedDate: Date?
    var notes: String

    init(
        id: String? = nil,
        itemID: String,
        itemName: String,
        supplierID: String,
        supplierName: String,
        quantity: Double,
        unit: String,
        totalCost: Double,
        status: OrderStatus = .pending,
        orderDate: Date = Date(),
        receivedDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.itemID = itemID
        self.itemName = itemName
        self.supplierID = supplierID
        self.supplierName = supplierName
        self.quantity = quantity
        self.unit = unit
        self.totalCost = totalCost
        self.status = status
        self.orderDate = orderDate
        self.receivedDate = receivedDate
        self.notes = notes
    }
}
