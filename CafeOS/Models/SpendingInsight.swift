import Foundation

// MARK: — SpendingInsight model (returned by Gemini spending analysis)

struct SpendingInsight: Codable {
    let summary: String
    let topSupplier: String?
    let topCategory: String?
    let totalSpend: Double
    let highlights: [String]
}
