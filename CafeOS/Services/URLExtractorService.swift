import Foundation

final class URLExtractorService {

    func extract(from urlString: String) async throws -> String {
        // Validate the input URL
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AppError.urlExtractionFailed
        }

        // Ensure it has a scheme — Jina requires https://
        let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"

        guard URL(string: normalized) != nil else {
            throw AppError.urlExtractionFailed
        }

        // Jina Reader API: prepend r.jina.ai/ to any URL
        // Docs: https://jina.ai/reader/
        guard let jinaURL = URL(string: "https://r.jina.ai/\(normalized)") else {
            throw AppError.urlExtractionFailed
        }

        var request = URLRequest(url: jinaURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 30

        // Auth header — free tier works without key, but key gives higher rate limits
        if !Secrets.jinaAPIKey.isEmpty &&
           Secrets.jinaAPIKey != "YOUR_JINA_KEY_HERE" {
            request.setValue("Bearer \(Secrets.jinaAPIKey)",
                             forHTTPHeaderField: "Authorization")
        }

        // Jina returns cleaner markdown with this header
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Disable Jina image alt-text generation to keep output clean
        request.setValue("no-image", forHTTPHeaderField: "X-No-Image")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AppError.urlExtractionFailed
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            print("[URLExtractorService] HTTP \(http.statusCode): \(body)")
            throw AppError.urlExtractionFailed
        }

        let rawString = String(data: data, encoding: .utf8) ?? ""

        // Attempt to unwrap Jina JSON envelope: { "data": { "content": "..." } }
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObject = jsonObject["data"] as? [String: Any],
           let content = dataObject["content"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        // Fallback: return raw string if non-empty
        if !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawString
        }

        throw AppError.urlExtractionFailed
    }
}
