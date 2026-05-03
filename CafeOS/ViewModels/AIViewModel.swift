import Foundation
import Combine

@MainActor
final class AIViewModel: ObservableObject {
    @Published var recommendations: [ReorderAdvice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var hasLoaded: Bool = false   // prevents auto-refresh on every appear

    private let service = AIService()

    func fetchRecommendations(items: [InventoryItem], suppliers: [Supplier]) async {
        isLoading = true
        showError = false
        errorMessage = nil
        defer { isLoading = false }

        do {
            recommendations = try await service.getReorderAdvice(items: items, suppliers: suppliers)
            hasLoaded = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: — Spending Insights

    @Published var spendingInsight: SpendingInsight? = nil
    @Published var isLoadingInsights: Bool = false
    @Published var hasLoadedInsights: Bool = false

    func fetchSpendingInsights(orders: [Order], suppliers: [Supplier]) async {
        isLoadingInsights = true
        showError = false
        errorMessage = nil
        defer { isLoadingInsights = false }

        do {
            spendingInsight = try await service.getSpendingInsights(orders: orders, suppliers: suppliers)
            hasLoadedInsights = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    func clear() {
        recommendations = []
        hasLoaded = false
        spendingInsight = nil
        hasLoadedInsights = false
        showError = false
        errorMessage = nil
    }

    // Urgency sort: critical first, then high, then medium
    var sortedRecommendations: [ReorderAdvice] {
        recommendations.sorted {
            urgencyRank($0.urgency) < urgencyRank($1.urgency)
        }
    }

    private func urgencyRank(_ urgency: String) -> Int {
        switch urgency {
        case "critical": return 0
        case "high":     return 1
        default:         return 2
        }
    }
}
