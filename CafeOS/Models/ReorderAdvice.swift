import Foundation

struct ReorderAdvice: Identifiable, Codable {
    var id: UUID = UUID()
    let itemName: String
    let urgency: String        // "critical" | "high" | "medium"
    let reason: String
    let recommendedQty: Double
    let unit: String
    let orderToday: Bool
    let supplierName: String
    let deliveryDays: Int

    enum CodingKeys: String, CodingKey {
        case itemName, urgency, reason, recommendedQty
        case unit, orderToday, supplierName, deliveryDays
    }
}

struct ReorderResponse: Codable {
    let recommendations: [ReorderAdvice]
}
