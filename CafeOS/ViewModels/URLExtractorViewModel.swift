import Foundation
import Combine

@MainActor
final class URLExtractorViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var extractedContent: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var hasResult: Bool = false

    private let service = URLExtractorService()

    func extract() async {
        guard !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please paste a URL first."
            showError = true
            return
        }

        isLoading = true
        showError = false
        errorMessage = nil
        extractedContent = ""
        defer { isLoading = false }

        do {
            extractedContent = try await service.extract(from: urlText)
            hasResult = true
        } catch {
            errorMessage = AppError.urlExtractionFailed.errorDescription
            showError = true
            hasResult = false
        }
    }

    func clear() {
        urlText = ""
        extractedContent = ""
        hasResult = false
        showError = false
        errorMessage = nil
    }
}
