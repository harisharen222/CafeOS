import Foundation
import Combine

@MainActor
final class URLExtractorViewModel: ObservableObject {
    @Published var urlText: String = ""
    @Published var extractedContent: String = ""   // displayText from pipeline
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false
    @Published var hasResult: Bool = false

    // PDF export state
    @Published var currentURL: String = ""
    @Published var jobDescription: JobDescription? = nil
    @Published var isGeneratingPDF: Bool = false
    @Published var pdfData: Data? = nil
    @Published var pdfFileURL: URL? = nil
    @Published var showShareSheet: Bool = false

    private let pipeline = ExtractionPipeline()
    private let pdfService = PDFGeneratorService()

    func extract() async {
        let trimmedURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty else {
            errorMessage = "Please paste a URL first."
            showError = true
            return
        }

        isLoading = true
        showError = false
        errorMessage = nil
        extractedContent = ""
        jobDescription = nil
        currentURL = trimmedURL
        defer { isLoading = false }

        do {
            let job = try await pipeline.run(url: trimmedURL, sourceURL: trimmedURL)
            jobDescription = job
            extractedContent = job.displayText   // structured, human-readable
            hasResult = true
        } catch {
            errorMessage = AppError.urlExtractionFailed.errorDescription
            showError = true
            hasResult = false
        }
    }

    func generatePDF() {
        guard let job = jobDescription else { return }
        isGeneratingPDF = true

        // Job is already structured by Layer 4 — no re-parsing needed
        let data = pdfService.generatePDF(from: job)
        pdfData = data

        let rawName = job.title
            .replacingOccurrences(of: "[^a-zA-Z0-9 _-]", with: "",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_")
        let safeFilename = rawName.isEmpty ? "JobDescription" : String(rawName.prefix(60))
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeFilename).pdf")
        try? data.write(to: tempURL)
        pdfFileURL = tempURL

        isGeneratingPDF = false
        showShareSheet = true
    }

    func clear() {
        urlText = ""
        extractedContent = ""
        hasResult = false
        showError = false
        errorMessage = nil
        currentURL = ""
        jobDescription = nil
        pdfData = nil
        pdfFileURL = nil
        showShareSheet = false
    }
}
