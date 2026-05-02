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

    // Exclude `id` from Codable — it is not in the GPT response
    enum CodingKeys: String, CodingKey {
        case itemName, urgency, reason, recommendedQty, unit, orderToday, supplierName, deliveryDays
    }
}

// Wrapper that matches the root JSON object GPT returns
struct ReorderResponse: Codable {
    let recommendations: [ReorderAdvice]
}
