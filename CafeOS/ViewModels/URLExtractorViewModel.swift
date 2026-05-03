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

    // PDF export state
    @Published var currentURL: String = ""
    @Published var jobDescription: JobDescription? = nil
    @Published var isGeneratingPDF: Bool = false
    @Published var pdfData: Data? = nil
    @Published var pdfFileURL: URL? = nil
    @Published var showShareSheet: Bool = false

    private let service = URLExtractorService()
    private let pdfService = PDFGeneratorService()

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
        currentURL = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        defer { isLoading = false }

        do {
            let raw = try await service.extract(from: urlText)
            extractedContent = cleanContent(raw)   // Fix A: strip UI noise before display
            hasResult = true
        } catch {
            errorMessage = AppError.urlExtractionFailed.errorDescription
            showError = true
            hasResult = false
        }
    }

    func generatePDF() {
        guard !extractedContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        isGeneratingPDF = true

        // extractedContent is already cleaned — pass it directly
        let job = pdfService.parse(markdown: extractedContent, sourceURL: currentURL)
        jobDescription = job
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

    // MARK: — Content Cleaning

    private func cleanContent(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)
        var cleaned: [String] = []
        var capturing = false
        var consecutiveEmptyLines = 0

        let noisePatterns: [String] = [
            "skip to main content",
            "sign in to",
            "join now",
            "join or sign in",
            "forgot password",
            "new to linkedin",
            "by clicking continue",
            "user agreement",
            "privacy policy",
            "cookie policy",
            "expand search",
            "this button displays",
            "when expanded it provides",
            "clear text",
            "similar jobs",
            "people also viewed",
            "people also searched",
            "similar searches",
            "show more jobs",
            "show fewer",
            "show more",
            "show less",
            "get notified about",
            "sign in to create",
            "referrals increase",
            "see who you know",
            "see who",
            "use ai to assess",
            "am i a good fit",
            "tailor my resume",
            "get ai-powered",
            "explore top content",
            "view top content",
            "more searches",
            "linkedin©",
            "about accessibility",
            "©",
            "trk=",
            "licdn.com",
            "static.licdn",
            "media.licdn",
            "!\\[image",
            "\\[image",
            "over 200 applicants",
            "over 100 applicants",
            "applicants",
            "weeks ago",
            "days ago",
            "months ago",
            "hours ago",
            "seniority level",
            "employment type",
            "job function",
            "industries",
            "computer hardware manufacturing",
            "العربية",
            "বাংলা",
            "čeština",
            "agree & join",
        ]

        let stopMarkers: [String] = [
            "similar jobs",
            "people also viewed",
            "people also searched",
            "similar searches",
            "more searches",
            "explore top content",
            "linkedin©",
            "## sign in",
            "sign in to see who",
            "## join or sign in",
        ]

        let startMarkers: [String] = [
            "# intern",
            "# software",
            "# data",
            "# product",
            "# engineer",
            "# analyst",
            "# manager",
            "# developer",
            "## intern",
            "## software",
            "## data",
            "at western digital",
            "at google",
            "at apple",
            "at microsoft",
            "job description",
            "about the role",
            "about this role",
            "about the job",
            "key responsibilities",
            "responsibilities",
            "qualifications",
            "requirements",
            "what you",
            "we are looking",
            "we're looking",
            "the role",
            "position overview",
            "role overview",
        ]

        let mdLinkRegex = try? NSRegularExpression(
            pattern: #"\[([^\]]+)\]\([^)]+\)"#
        )

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower   = trimmed.lowercased()

            // Stop markers — done capturing
            if stopMarkers.contains(where: { lower.contains($0) }) { break }

            // Start capturing when a real content signal is seen
            if !capturing {
                if startMarkers.contains(where: { lower.contains($0) }) {
                    capturing = true
                } else {
                    continue
                }
            }

            // Skip noise lines
            if noisePatterns.contains(where: { lower.contains($0) }) { continue }

            // Skip pure markdown link-only lines: [text](url)
            let linkOnlyPattern = #"^\[.*\]\(https?://.*\)$"#
            if trimmed.range(of: linkOnlyPattern, options: .regularExpression) != nil {
                continue
            }

            // Skip HR-like divider lines (only asterisks/dashes/spaces)
            if !trimmed.isEmpty && trimmed.allSatisfy({ $0 == "*" || $0 == "-" || $0 == " " }) {
                continue
            }

            // Collapse consecutive empty lines
            if trimmed.isEmpty {
                consecutiveEmptyLines += 1
                if consecutiveEmptyLines <= 1 { cleaned.append("") }
                continue
            }
            consecutiveEmptyLines = 0

            // Clean: convert [text](url) → text, remove image tags
            var cleanLine = trimmed
            if let regex = mdLinkRegex {
                let range = NSRange(cleanLine.startIndex..., in: cleanLine)
                cleanLine = regex.stringByReplacingMatches(
                    in: cleanLine, range: range, withTemplate: "$1"
                )
            }
            cleanLine = cleanLine
                .replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "",
                                      options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            if !cleanLine.isEmpty {
                cleaned.append(cleanLine)
            }
        }

        let result = cleaned
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If cleaning stripped too much, fall back to raw
        return result.count > 100 ? result : raw
    }
}
