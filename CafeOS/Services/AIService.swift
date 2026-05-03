import Foundation

final class AIService {

    // Gemini Flash 2.5 endpoint — API key passed as query parameter
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    func getReorderAdvice(items: [InventoryItem],
                          suppliers: [Supplier]) async throws -> [ReorderAdvice] {

        let lowItems = items.filter { $0.isLowStock }
        guard !lowItems.isEmpty else { return [] }

        let prompt = buildReorderPrompt(lowItems: lowItems, suppliers: suppliers)
        return try await callGeminiJSON(prompt: prompt, decoding: ReorderResponse.self).recommendations
    }

    // MARK: — Spending Insights

    func getSpendingInsights(orders: [Order], suppliers: [Supplier]) async throws -> SpendingInsight {
        let delivered = orders.filter { $0.status == .received }
        guard !delivered.isEmpty else {
            return SpendingInsight(summary: "No delivered orders yet to analyse.",
                                   topSupplier: nil,
                                   topCategory: nil,
                                   totalSpend: 0,
                                   highlights: [])
        }

        let prompt = buildSpendingPrompt(orders: delivered, suppliers: suppliers)
        return try await callGeminiJSON(prompt: prompt, decoding: SpendingInsight.self)
    }

    // MARK: — Generic Gemini caller (JSON response)

    private func callGeminiJSON<T: Decodable>(prompt: String, decoding type: T.Type) async throws -> T {
        guard var components = URLComponents(string: baseURL) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base URL."])
        }
        components.queryItems = [URLQueryItem(name: "key", value: Secrets.geminiAPIKey)]
        guard let url = components.url else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to construct URL with API key."])
        }

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.3
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[AIService] Gemini error (\(code)): \(body)")
            throw NSError(domain: "AIService", code: code, userInfo: [NSLocalizedDescriptionKey: "API Error (\(code)): \(body)"])
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No text in Gemini response."])
        }
        var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanText.hasPrefix("```json") {
            cleanText = String(cleanText.dropFirst(7))
        } else if cleanText.hasPrefix("```") {
            cleanText = String(cleanText.dropFirst(3))
        }
        if cleanText.hasSuffix("```") {
            cleanText = String(cleanText.dropLast(3))
        }
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let contentData = cleanText.data(using: .utf8) else {
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode cleaned text to data."])
        }

        do {
            return try JSONDecoder().decode(type, from: contentData)
        } catch {
            print("[AIService] Decode failed for \(type): \(error)\nRaw: \(cleanText)")
            throw NSError(domain: "AIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Decode failed: \(error.localizedDescription)"])
        }
    }

    // MARK: — Prompts

    private func buildReorderPrompt(lowItems: [InventoryItem], suppliers: [Supplier]) -> String {
        let inventoryLines = lowItems.map { item -> String in
            let supplier = suppliers.first { $0.id == item.supplierID }
            let supplierName = supplier?.name ?? item.supplierName ?? "Unknown"
            let deliveryDays = supplier?.deliveryDays ?? 3
            return """
            - itemID: \(item.id ?? ""), name: \(item.name), category: \(item.category), \
            currentQty: \(item.quantity) \(item.unit), \
            minimumThreshold: \(item.minimumThreshold) \(item.unit), \
            costPerUnit: \(item.costPerUnit), \
            supplierID: \(supplier?.id ?? ""), supplier: \(supplierName), deliveryDays: \(deliveryDays)
            """
        }.joined(separator: "\n")

        return """
        You are a smart inventory advisor for a small café.
        Analyze the low-stock inventory below and return reorder recommendations.

        STRICT OUTPUT RULES:
        - Return ONLY a valid JSON object. No markdown. No explanation. No code fences.
        - Root key must be "recommendations" containing an array.
        - Each object in the array must have EXACTLY these keys with these types:
          * itemID: string
          * itemName: string
          * urgency: string — ONLY one of: "critical", "high", "medium"
          * reason: string — max 20 words explaining why
          * recommendedQty: number — enough for approximately 2 weeks
          * costPerUnit: number
          * unit: string — same unit as the input
          * orderToday: boolean — true if urgency is critical or high
          * supplierID: string
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

    private func buildSpendingPrompt(orders: [Order], suppliers: [Supplier]) -> String {
        // Aggregate spend by supplier
        var supplierSpend: [String: Double] = [:]
        var categorySpend: [String: Double] = [:]
        var totalSpend: Double = 0

        for order in orders {
            supplierSpend[order.supplierName, default: 0] += order.totalCost
            totalSpend += order.totalCost
        }

        // Match item category from supplier itemsSupplied where possible — use supplierName as proxy
        // Build per-order lines
        let orderLines = orders.map { o in
            "- item: \(o.itemName), supplier: \(o.supplierName), qty: \(o.quantity) \(o.unit), cost: ₹\(Int(o.totalCost)), date: \(formatted(o.orderDate))"
        }.joined(separator: "\n")

        let supplierBreakdown = supplierSpend
            .sorted { $0.value > $1.value }
            .map { "- \($0.key): ₹\(Int($0.value))" }
            .joined(separator: "\n")

        return """
        You are a spending analyst for a small café. Analyze the purchase history below.

        STRICT OUTPUT RULES:
        - Return ONLY a valid JSON object. No markdown. No explanation. No code fences.
        - The JSON must have EXACTLY these keys:
          * summary: string — 2-3 sentence plain English summary of spending patterns, mentioning the biggest cost driver and any notable trends. No technical jargon.
          * topSupplier: string — name of supplier with highest spend
          * topCategory: string — the item category or type that accounts for the most spend (infer from item names)
          * totalSpend: number — total rupees spent across all orders
          * highlights: array of strings — exactly 3 short bullet-point observations (max 12 words each)

        Total orders: \(orders.count)
        Total spend: ₹\(Int(totalSpend))

        Supplier breakdown:
        \(supplierBreakdown)

        All delivered orders:
        \(orderLines)
        """
    }

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
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
