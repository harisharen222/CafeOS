import Foundation

final class AIService {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func getReorderAdvice(items: [InventoryItem],
                          suppliers: [Supplier]) async throws -> [ReorderAdvice] {
        // Only send items that are at or below their minimum threshold
        let lowItems = items.filter { $0.isLowStock }
        guard !lowItems.isEmpty else { return [] }

        let inventoryJSON = buildInventoryJSON(lowItems: lowItems, suppliers: suppliers)
        let prompt = buildPrompt(inventoryJSON: inventoryJSON)

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 800,
            "response_format": ["type": "json_object"]   // enforces JSON object root
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Secrets.openAIKey)", forHTTPHeaderField: "Authorization")
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

        // GPT response structure: { choices: [{ message: { content: "{ recommendations: [...] }" } }] }
        let gptResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = gptResponse.choices.first?.message.content else {
            throw AppError.aiServiceFailed
        }

        guard let contentData = content.data(using: .utf8) else {
            throw AppError.aiServiceFailed
        }

        // Decode the root object — NOT a bare array
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

// MARK: — OpenAI response shape

private struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
