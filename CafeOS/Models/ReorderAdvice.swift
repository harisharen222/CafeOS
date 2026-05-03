import Foundation

struct ReorderAdvice: Identifiable, Codable {
    var id: UUID = UUID()
    let itemID: String
    let itemName: String
    let urgency: String        // "critical" | "high" | "medium"
    let reason: String
    let recommendedQty: Double
    let costPerUnit: Double
    let unit: String
    let orderToday: Bool
    let supplierID: String
    let supplierName: String
    let deliveryDays: Int

    enum CodingKeys: String, CodingKey {
        case itemID, itemName, urgency, reason, recommendedQty, costPerUnit
        case unit, orderToday, supplierID, supplierName, deliveryDays
    }
}

struct ReorderResponse: Codable {
    let recommendations: [ReorderAdvice]
}
