import Foundation

final class AIService {
    func getReorderAdvice(items: [InventoryItem],
                          suppliers: [Supplier]) async throws -> [ReorderAdvice] {
        // Only send items that are at or below their minimum threshold
        let lowItems = items.filter { $0.isLowStock }
        guard !lowItems.isEmpty else { return [] }

        let inventoryJSON = buildInventoryJSON(lowItems: lowItems, suppliers: suppliers)
        let prompt = buildPrompt(inventoryJSON: inventoryJSON)

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]

        // Using Gemini API endpoint
        let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(Secrets.openAIKey)")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.aiServiceFailed
        }
        guard http.statusCode == 200 else {
            // Log the error body for debugging — do not crash
            let errorBody = String(data: data, encoding: .utf8) ?? "no body"
            print("[AIService] HTTP \(http.statusCode): \(errorBody)")
            throw AppError.aiServiceFailed
        }

        let gptResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let content = gptResponse.candidates.first?.content.parts.first?.text else {
            throw AppError.aiServiceFailed
        }

        guard let contentData = content.data(using: .utf8) else {
            throw AppError.aiServiceFailed
        }

        // Decode the root object
        let reorderResponse = try JSONDecoder().decode(ReorderResponse.self, from: contentData)
        return reorderResponse.recommendations
    }

    // MARK: — Private helpers

    private func buildInventoryJSON(lowItems: [InventoryItem], suppliers: [Supplier]) -> String {
        let enriched = lowItems.map { item -> [String: Any] in
            let supplier = suppliers.first { $0.id == item.supplierID }
            return [
                "name": item.name,
                "category": item.category,
                "currentQty": item.quantity,
                "unit": item.unit,
                "minimumThreshold": item.minimumThreshold,
                "costPerUnit": item.costPerUnit,
                "supplierName": supplier?.name ?? item.supplierName ?? "Unknown",
                "deliveryDays": supplier?.deliveryDays ?? 3
            ]
        }
        let data = (try? JSONSerialization.data(withJSONObject: enriched, options: .prettyPrinted)) ?? Data()
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func buildPrompt(inventoryJSON: String) -> String {
        """
        You are a smart inventory advisor for a small café.
        Analyze the low-stock inventory data below and return reorder recommendations.

        RULES:
        - Return ONLY a valid JSON object with a single key "recommendations" containing an array.
        - Do not include any explanation, markdown, or text outside the JSON.
        - Each recommendation object must have EXACTLY these keys:
          itemName (string), urgency ("critical"|"high"|"medium"), reason (string, max 20 words),
          recommendedQty (number), unit (string), orderToday (boolean),
          supplierName (string), deliveryDays (number)
        - urgency = "critical" if quantity is 0 or below 25% of threshold
        - urgency = "high" if quantity is 25–75% of threshold
        - urgency = "medium" if quantity is 75–100% of threshold
        - recommendedQty should be enough stock for approximately 2 weeks based on the threshold

        Low-stock inventory:
        \(inventoryJSON)
        """
    }
}

// MARK: — Gemini response shape

private struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}
