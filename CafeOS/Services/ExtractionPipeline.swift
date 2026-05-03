import Foundation

// MARK: — 4-Layer Content Extraction Pipeline
//
// Layer 1 — FETCH:    Direct GET → Jina fallback
// Layer 2 — WINDOW:   Slice out the job content region
// Layer 3 — CLEAN:    Strip markdown artifacts from the slice
// Layer 4 — STRUCTURE: Parse clean text into a typed JobDescription

final class ExtractionPipeline {

    // MARK: — Public entry point

    func run(url: String, sourceURL: String) async throws -> JobDescription {
        let raw      = try await fetchRaw(url: url)
        let window   = detectWindow(in: raw)
        let clean    = cleanWindow(window)
        return structureContent(clean, sourceURL: sourceURL)
    }

    // MARK: ─────────────────────────────────────────────────
    // LAYER 1 — FETCH
    // Responsibility: Get raw markdown/HTML from a URL.
    // Tries a direct browser-spoofed GET first; falls back to Jina Reader.
    // ─────────────────────────────────────────────────

    private func fetchRaw(url: String) async throws -> String {
        let trimmed    = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"

        guard URL(string: normalized) != nil else {
            throw AppError.urlExtractionFailed
        }

        // Attempt 1 — Direct GET with realistic browser headers (10 s timeout)
        if let directURL = URL(string: normalized) {
            var req = URLRequest(url: directURL)
            req.httpMethod = "GET"
            req.timeoutInterval = 10
            req.setValue(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) " +
                "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                forHTTPHeaderField: "User-Agent"
            )
            req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                         forHTTPHeaderField: "Accept")
            req.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")

            if let (data, response) = try? await URLSession.shared.data(for: req),
               let http = response as? HTTPURLResponse,
               http.statusCode == 200,
               let body = String(data: data, encoding: .utf8),
               body.trimmingCharacters(in: .whitespacesAndNewlines).count > 500,
               !body.lowercased().contains("<!doctype"),
               !body.lowercased().contains("<html"),
               !body.lowercased().contains("<!--->") {
                return body
            }
        }

        // Attempt 2 — Jina Reader API (20 s timeout)
        guard let jinaURL = URL(string: "https://r.jina.ai/\(normalized)") else {
            throw AppError.urlExtractionFailed
        }
        var jinaReq = URLRequest(url: jinaURL)
        jinaReq.httpMethod = "GET"
        jinaReq.timeoutInterval = 20

        if !Secrets.jinaAPIKey.isEmpty && Secrets.jinaAPIKey != "YOUR_JINA_KEY_HERE" {
            jinaReq.setValue("Bearer \(Secrets.jinaAPIKey)",
                             forHTTPHeaderField: "Authorization")
        }
        jinaReq.setValue("application/json", forHTTPHeaderField: "Accept")
        jinaReq.setValue("no-image",         forHTTPHeaderField: "X-No-Image")

        let (jinaData, jinaResponse) = try await URLSession.shared.data(for: jinaReq)

        guard let jinaHTTP = jinaResponse as? HTTPURLResponse,
              jinaHTTP.statusCode == 200 else {
            throw AppError.urlExtractionFailed
        }

        // Unwrap Jina JSON envelope → data.content
        if let json = try? JSONSerialization.jsonObject(with: jinaData) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let content = dataObj["content"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content
        }

        // Plain text fallback
        let rawString = String(data: jinaData, encoding: .utf8) ?? ""
        if !rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return rawString
        }

        throw AppError.urlExtractionFailed
    }

    // MARK: ─────────────────────────────────────────────────
    // LAYER 2 — WINDOW DETECTION
    // Responsibility: Find START and END of the actual job content.
    // Returns only the job region slice — navigation above and footer below are gone.
    // ─────────────────────────────────────────────────

    private func detectWindow(in raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)

        // ── Fix 1: skip past LinkedIn sign-in modal ───────────────────────────
        // Scan for the LAST occurrence of known modal footer lines and discard
        // everything up to and including that line. Signal A/B/C then operate
        // on post-modal content only, so the window never starts inside the modal.
        let modalMarkers: [String] = [
            "by clicking continue to join or sign in",
            "cookie policy.",
            "agree & join linkedin"
        ]
        var modalCutIndex = -1
        for (i, line) in lines.enumerated() {
            let lowerLine = line.lowercased()
            if modalMarkers.contains(where: { lowerLine.contains($0) }) {
                modalCutIndex = i   // keep updating — we want the LAST match
            }
        }
        let postModal = modalCutIndex >= 0
            ? Array(lines[(modalCutIndex + 1)...])
            : lines

        // ── END boundary — first line that matches a stop marker ──────────────
        let stopMarkers: [String] = [
            "similar jobs", "people also viewed", "people also searched",
            "referrals increase", "more searches", "explore top content",
            "linkedin©", "show more jobs", "© linkedin"
        ]
        var endIndex = postModal.count
        for (i, line) in postModal.enumerated() {
            let lower = line.lowercased()
            if stopMarkers.contains(where: { lower.contains($0) }) {
                endIndex = i
                break
            }
        }
        let bounded = Array(postModal[0..<endIndex])


        // ── START boundary ────────────────────────────────────────────────────
        var startIndex = 0
        var h1Count    = 0

        // Signal A — second H1/H2 heading (first is usually page title echo)
        for (i, line) in bounded.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") {
                h1Count += 1
                if h1Count == 2 {
                    // Start from the second heading itself so we keep the job title
                    startIndex = i
                    break
                }
            }
        }

        // Signal B — if Signal A found nothing (h1Count < 2), find first substantial prose
        if h1Count < 2 {
            for (i, line) in bounded.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("[")
                    && !trimmed.hasPrefix("#")
                    && !trimmed.hasPrefix("!")
                    && trimmed.count > 80
                    && !trimmed.contains("https://") {
                    startIndex = max(0, i - 2)
                    break
                }
            }
        }

        // Signal C — known job content anchors (fallback)
        if startIndex == 0 && h1Count < 2 {
            let anchors = ["job description", "about the role", "about this role",
                           "about the job", "key responsibilities", "what you'll do"]
            for (i, line) in bounded.enumerated() {
                let lower = line.lowercased()
                if anchors.contains(where: { lower.contains($0) }) {
                    startIndex = i
                    break
                }
            }
        }

        // Safety cap: never take more than 300 lines from start
        let sliceEnd = min(startIndex + 300, bounded.count)
        return bounded[startIndex..<sliceEnd].joined(separator: "\n")
    }

    // MARK: ─────────────────────────────────────────────────
    // LAYER 3 — CLEAN
    // Responsibility: Strip markdown formatting artifacts from the window slice.
    // Input is already bounded to the job region. This layer only strips syntax noise.
    // ─────────────────────────────────────────────────

    private func cleanWindow(_ window: String) -> String {
        let lines  = window.components(separatedBy: .newlines)
        let mdLink = try? NSRegularExpression(pattern: #"\[([^\]]+)\]\([^)]+\)"#)
        let bold   = try? NSRegularExpression(pattern: #"\*\*([^*]+)\*\*"#)
        let italic = try? NSRegularExpression(pattern: #"\*([^*]+)\*"#)

        var result: [String] = []
        var consecutiveEmpty = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // ── REMOVE ────────────────────────────────────────────────────────
            if trimmed.hasPrefix("![")                   { continue }   // image tag
            if trimmed.count < 3                          { /* fall through to empty collapse */ }
            let lower = trimmed.lowercased()
            if lower.contains("trk=")                    { continue }   // tracking URLs
            if lower.contains("licdn.com")               { continue }   // CDN links
            if lower.contains("static.licdn")            { continue }
            // Pure markdown link-only line
            let linkOnly = #"^\[.*\]\(https?://.*\)$"#
            if trimmed.range(of: linkOnly, options: .regularExpression) != nil { continue }
            // HR dividers
            if !trimmed.isEmpty
               && trimmed.allSatisfy({ $0 == "*" || $0 == "-" || $0 == "=" || $0 == " " })
               && trimmed.count > 1 { continue }

            // ── EMPTY LINE — collapse 3+ into 1 ──────────────────────────────
            if trimmed.isEmpty {
                consecutiveEmpty += 1
                if consecutiveEmpty <= 2 { result.append("") }
                continue
            }
            consecutiveEmpty = 0

            // ── TRANSFORM ─────────────────────────────────────────────────────
            var clean = trimmed

            // Strip leading heading markers but keep the text
            clean = clean.replacingOccurrences(of: #"^#{1,6}\s*"#, with: "",
                                               options: .regularExpression)

            // [text](url) → text
            if let re = mdLink {
                let r = NSRange(clean.startIndex..., in: clean)
                clean = re.stringByReplacingMatches(in: clean, range: r, withTemplate: "$1")
            }
            // **bold** → bold
            if let re = bold {
                let r = NSRange(clean.startIndex..., in: clean)
                clean = re.stringByReplacingMatches(in: clean, range: r, withTemplate: "$1")
            }
            // *italic* → italic
            if let re = italic {
                let r = NSRange(clean.startIndex..., in: clean)
                clean = re.stringByReplacingMatches(in: clean, range: r, withTemplate: "$1")
            }
            // Remove residual image syntax
            clean = clean.replacingOccurrences(of: #"!\[.*?\]\(.*?\)"#, with: "",
                                               options: .regularExpression)
                         .trimmingCharacters(in: .whitespaces)

            if !clean.isEmpty {
                result.append(clean)
            }
        }

        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: ─────────────────────────────────────────────────
    // LAYER 4 — STRUCTURE
    // Responsibility: Parse clean text into a typed JobDescription.
    // Single-pass state machine. No AI. Pure text analysis.
    // ─────────────────────────────────────────────────

    private func structureContent(_ clean: String, sourceURL: String) -> JobDescription {
        let lines = clean.components(separatedBy: .newlines)

        var title           = ""
        var company         = ""
        var location        = ""
        var employmentType  = ""
        var aboutLines      = [String]()
        var responsibilities = [String]()
        var requirements    = [String]()
        var additionalLines = [String]()

        enum State { case header, about, responsibilities, requirements, additional, done }
        var state: State = .header

        // Helpers
        let bulletPrefixes = ["-", "*", "•", "–"]
        func isBullet(_ line: String) -> Bool {
            bulletPrefixes.contains(where: { line.hasPrefix($0 + " ") || line.hasPrefix($0 + "\t") })
        }
        func bulletText(_ line: String) -> String {
            var s = line
            for p in bulletPrefixes { if s.hasPrefix(p) { s = String(s.dropFirst(p.count)) } }
            return s.trimmingCharacters(in: .whitespaces)
        }

        for (idx, rawLine) in lines.enumerated() {
            let line    = rawLine.trimmingCharacters(in: .whitespaces)
            let lower   = line.lowercased()
            if line.isEmpty { continue }

            // ── TITLE ──────────────────────────────────────────────────────────
            if title.isEmpty {
                // Fix 1: skip sign-in / join CTA lines — they are not job titles
                let isTitleNoise = lower.contains("sign in") ||
                                   lower.contains("join or") ||
                                   lower.contains("join to apply")
                if !isTitleNoise && !line.hasPrefix("http") && !line.hasPrefix("[") && line.count > 3 {
                    // LinkedIn pattern: "Job Title | Company | LinkedIn" → take first segment
                    if line.contains(" | ") {
                        title = line.components(separatedBy: " | ").first?
                                   .trimmingCharacters(in: .whitespaces) ?? line
                    } else {
                        title = line
                    }
                }
                continue
            }

            // ── COMPANY ────────────────────────────────────────────────────────
            if company.isEmpty && idx < 8 {
                // "Title at Company" pattern
                if let atRange = lower.range(of: #"(?<=\bat\s)\S.*"#,
                                             options: .regularExpression) {
                    company = String(line[atRange])
                        .components(separatedBy: CharacterSet(charactersIn: ",|·•"))
                        .first?.trimmingCharacters(in: .whitespaces) ?? ""
                }
                // Short standalone line after title is usually company name
                if company.isEmpty && line.count < 50
                   && !line.contains("http")
                   && !lower.contains("intern") {
                    company = line
                    continue
                }
            }

            // ── LOCATION ───────────────────────────────────────────────────────
            if location.isEmpty && idx < 12 {
                let locationHints = ["remote", "hybrid", "on-site", "onsite",
                                     "bengaluru", "bangalore", "mumbai", "delhi",
                                     "hyderabad", "chennai", "pune", "india",
                                     "new york", "san francisco", "london",
                                     "singapore", "berlin", "toronto"]
                if locationHints.contains(where: { lower.contains($0) })
                   && line.count < 70 && !line.hasPrefix("-") {
                    location = line
                        .replacingOccurrences(of: "·", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
            }

            // ── EMPLOYMENT TYPE ─────────────────────────────────────────────────
            if employmentType.isEmpty {
                let types = ["internship", "full-time", "part-time",
                             "contract", "freelance", "temporary"]
                if let match = types.first(where: { lower.contains($0) }) {
                    employmentType = match.capitalized
                }
            }

            // ── SECTION HEADER DETECTION ────────────────────────────────────────
            let isLikelySectionHeader = (line.count < 60 &&
                !isBullet(line) && !line.hasPrefix("http"))

            if isLikelySectionHeader {
                if lower.contains("about") || lower.contains("overview")
                   || lower.contains("the role") || lower.contains("job description")
                   || lower.contains("position summary") || lower.contains("role summary") {
                    state = .about; continue
                }
                if lower.contains("responsibilit") || lower.contains("what you'll do")
                   || lower.contains("what you will do") || lower.contains("your role")
                   || lower.contains("duties") || lower.contains("key responsibilit") {
                    state = .responsibilities; continue
                }
                if lower.contains("qualif") || lower.contains("requirement")
                   || lower.contains("what you need") || lower.contains("what we're looking")
                   || lower.contains("skills") || lower.contains("you bring")
                   || lower.contains("you have") || lower.contains("minimum qualif") {
                    state = .requirements; continue
                }
                if lower.contains("additional") || lower.contains("notice")
                   || lower.contains("equal opportunity") || lower.contains("diversity") {
                    state = .additional; continue
                }
            }

            if state == .done { break }

            // ── CONTENT ASSIGNMENT ──────────────────────────────────────────────
            switch state {
            case .header:
                // Before any section — treat as about/intro if substantial
                // Also apply the same CTA noise filter as the ABOUT state
                let isHeaderNoise = lower.contains("join to apply") ||
                                    lower.contains("sign in to") ||
                                    lower.contains("select your language preference")
                if line.count > 40 && !line.hasPrefix("http") && !isHeaderNoise {
                    aboutLines.append(line)
                }
            case .about:
                // Fix 2: skip LinkedIn CTA lines that leak through window detection
                let isAboutNoise = lower.contains("join to apply") ||
                                   lower.contains("select your language preference") ||
                                   lower.contains("sign in to")
                if !isAboutNoise { aboutLines.append(line) }
            case .responsibilities:
                if isBullet(line) {
                    responsibilities.append(bulletText(line))
                } else if line.count > 30 {
                    responsibilities.append(line)
                }
            case .requirements:
                if isBullet(line) {
                    let bt = bulletText(line)
                    // Fix 3: skip LinkedIn metadata bullets (### Seniority level, etc.)
                    let isMetadata = bt.hasPrefix("###") ||
                                     bt.lowercased().contains("seniority level") ||
                                     bt.lowercased().contains("employment type") ||
                                     bt.lowercased().contains("job function") ||
                                     bt.lowercased().contains("industries")
                    if !isMetadata { requirements.append(bt) }
                } else if line.count > 30 {
                    // Fix 3: also drop LinkedIn industry/function tag value lines
                    let isIndustryTag = lower.contains("engineering and information technology") ||
                                        lower.contains("computer hardware") ||
                                        lower.contains("semiconductor") ||
                                        lower.contains("information technology")
                    if !isIndustryTag { requirements.append(line) }
                }
            case .additional:
                additionalLines.append(line)
            case .done:
                break
            }
        }

        // ── FALLBACKS ───────────────────────────────────────────────────────────
        if title.isEmpty { title = "Job Description" }
        if company.isEmpty { company = "" }
        if location.isEmpty { location = "" }

        // If we never hit a structured section, use all substantial lines as aboutRole
        if aboutLines.isEmpty && responsibilities.isEmpty && requirements.isEmpty {
            aboutLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).count > 40 }
                              .prefix(8).map { String($0) }
        }

        // Cap collections
        let additionalStr = additionalLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = additionalStr.count > 300
            ? String(additionalStr.prefix(300)) + "…"
            : additionalStr

        return JobDescription(
            title: title,
            company: company,
            location: location,
            employmentType: employmentType,
            aboutRole: aboutLines.joined(separator: "\n"),
            responsibilities: Array(responsibilities.prefix(15)),
            requirements: Array(requirements.prefix(15)),
            additionalInfo: capped,
            sourceURL: sourceURL,
            extractedAt: Date()
        )
    }
}
