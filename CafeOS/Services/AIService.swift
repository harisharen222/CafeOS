import Foundation

final class AIService {

    // Gemini Flash 2.0 endpoint — API key passed as query parameter
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

    func getReorderAdvice(items: [InventoryItem],
                          suppliers: [Supplier]) async throws -> [ReorderAdvice] {

        let lowItems = items.filter { $0.isLowStock }
        guard !lowItems.isEmpty else { return [] }

        let prompt = buildPrompt(lowItems: lowItems, suppliers: suppliers)

        // Build URL with API key as query param (Gemini's auth method)
        guard var components = URLComponents(string: baseURL) else {
            throw AppError.aiServiceFailed
        }
        components.queryItems = [
            URLQueryItem(name: "key", value: Secrets.geminiAPIKey)
        ]
        guard let url = components.url else {
            throw AppError.aiServiceFailed
        }

        // Gemini request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.aiServiceFailed
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("[AIService] Gemini HTTP \(http.statusCode): \(body)")
            throw AppError.aiServiceFailed
        }

        // Decode Gemini's response envelope
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            print("[AIService] Gemini returned no text content")
            throw AppError.aiServiceFailed
        }

        print("[AIService] Gemini raw text: \(text)")

        // The text IS the JSON — decode ReorderResponse from it
        guard let contentData = text.data(using: .utf8) else {
            throw AppError.aiServiceFailed
        }

        do {
            let reorderResponse = try JSONDecoder().decode(ReorderResponse.self, from: contentData)
            return reorderResponse.recommendations
        } catch {
            print("[AIService] JSON decode failed: \(error)")
            print("[AIService] Raw content was: \(text)")
            throw AppError.aiServiceFailed
        }
    }

    // MARK: — Private

    private func buildPrompt(lowItems: [InventoryItem], suppliers: [Supplier]) -> String {
        let inventoryLines = lowItems.map { item -> String in
            let supplier = suppliers.first { $0.id == item.supplierID }
            let supplierName = supplier?.name ?? item.supplierName ?? "Unknown"
            let deliveryDays = supplier?.deliveryDays ?? 3
            return """
            - name: \(item.name), category: \(item.category), \
            currentQty: \(item.quantity) \(item.unit), \
            minimumThreshold: \(item.minimumThreshold) \(item.unit), \
            costPerUnit: \(item.costPerUnit), \
            supplier: \(supplierName), deliveryDays: \(deliveryDays)
            """
        }.joined(separator: "\n")

        return """
        You are a smart inventory advisor for a small café.
        Analyze the low-stock inventory below and return reorder recommendations.

        STRICT OUTPUT RULES:
        - Return ONLY a valid JSON object. No markdown. No explanation. No code fences.
        - Root key must be "recommendations" containing an array.
        - Each object in the array must have EXACTLY these keys with these types:
          * itemName: string
          * urgency: string — ONLY one of: "critical", "high", "medium"
          * reason: string — max 20 words explaining why
          * recommendedQty: number — enough for approximately 2 weeks
          * unit: string — same unit as the input
          * orderToday: boolean — true if urgency is critical or high
          * supplierName: string
          * deliveryDays: number

        URGENCY RULES:
        - "critical" → quantity is 0 OR below 25% of minimumThreshold
        - "high"     → quantity is 25%–75% of minimumThreshold
        - "medium"   → quantity is 75%–100% of minimumThreshold

        Low-stock inventory:
        \(inventoryLines)
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
