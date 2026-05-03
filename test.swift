import Foundation

struct ReorderAdvice: Identifiable, Codable {
    var id: UUID = UUID()
    let itemID: String
    let itemName: String
    let urgency: String
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

let json = """
{
    "recommendations": [
        {
            "itemID": "123",
            "itemName": "Coffee",
            "urgency": "high",
            "reason": "low",
            "recommendedQty": 10.5,
            "costPerUnit": 5.0,
            "unit": "kg",
            "orderToday": true,
            "supplierID": "abc",
            "supplierName": "Supplier",
            "deliveryDays": 3
        }
    ]
}
"""

do {
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ReorderResponse.self, from: data)
    print("Success: \(decoded)")
} catch {
    print("Error: \(error)")
}
