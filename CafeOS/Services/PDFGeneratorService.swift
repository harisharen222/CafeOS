import Foundation
import UIKit
import PDFKit

// MARK: — Parsed Job Description Model

struct JobDescription {
    var title: String
    var company: String
    var location: String
    var jobType: String
    var aboutRole: String
    var requirements: [String]
    var responsibilities: [String]
    var sourceURL: String
    var extractedAt: Date
}

// MARK: — PDF Generator

class PDFGeneratorService {

    // MARK: — Parse markdown into structured sections
    func parse(markdown: String, sourceURL: String) -> JobDescription {
        let lines = markdown.components(separatedBy: .newlines)

        var title            = ""
        var company          = ""
        var location         = ""
        var jobType          = ""
        var aboutLines       = [String]()
        var requirements     = [String]()
        var responsibilities = [String]()

        enum Section { case none, about, requirements, responsibilities, other }
        var currentSection: Section = .none

        let requirementKeywords    = ["requirement", "qualification", "what you need",
                                      "what we're looking for", "skills", "you have",
                                      "you bring", "minimum qualification"]
        let responsibilityKeywords = ["responsibilit", "what you'll do", "what you will do",
                                      "your role", "duties", "you will", "key duties"]
        let aboutKeywords          = ["about the role", "about this role", "overview",
                                      "the role", "position overview", "job summary",
                                      "about the job", "description"]

        for (index, line) in lines.enumerated() {
            let trimmed   = line.trimmingCharacters(in: .whitespaces)
            let lower     = trimmed.lowercased()
            let isHeader  = trimmed.hasPrefix("#")
            let isBullet  = trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("•")
            let cleanLine = trimmed
                .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
                .replacingOccurrences(of: "^[-*•]\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            if cleanLine.isEmpty { continue }

            // Extract title — first H1 or H2
            if title.isEmpty && (trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ")) {
                title = cleanLine
                continue
            }

            // Extract company from "at CompanyName" or second heading
            if company.isEmpty && index < 10 {
                if let range = lower.range(of: #"\bat\s+([A-Z][^\n,|]+)"#,
                                           options: .regularExpression) {
                    let match = String(lower[range])
                    company = match.replacingOccurrences(of: "at ", with: "",
                                                        options: .caseInsensitive)
                        .trimmingCharacters(in: .whitespaces).capitalized
                }
                if company.isEmpty && trimmed.hasPrefix("## ") && !title.isEmpty {
                    company = cleanLine
                    continue
                }
            }

            // Extract location
            if location.isEmpty {
                let locationPatterns = ["remote", "hybrid", "on-site", "onsite",
                                        "bengaluru", "mumbai", "delhi", "hyderabad",
                                        "chennai", "pune", "bangalore", "india",
                                        "new york", "san francisco", "london", "singapore"]
                if locationPatterns.contains(where: { lower.contains($0) }) && index < 20 {
                    location = cleanLine
                }
            }

            // Extract job type
            if jobType.isEmpty {
                let typeKeywords = ["full-time", "part-time", "internship",
                                    "contract", "freelance", "temporary"]
                if let match = typeKeywords.first(where: { lower.contains($0) }) {
                    jobType = match.capitalized
                }
            }

            // Detect section changes from headers
            if isHeader {
                if requirementKeywords.contains(where: { lower.contains($0) }) {
                    currentSection = .requirements
                } else if responsibilityKeywords.contains(where: { lower.contains($0) }) {
                    currentSection = .responsibilities
                } else if aboutKeywords.contains(where: { lower.contains($0) }) {
                    currentSection = .about
                } else {
                    currentSection = .other
                }
                continue
            }

            // Assign content to section
            switch currentSection {
            case .requirements:
                if isBullet { requirements.append(cleanLine) }
                else if cleanLine.count > 20 { requirements.append(cleanLine) }
            case .responsibilities:
                if isBullet { responsibilities.append(cleanLine) }
                else if cleanLine.count > 20 { responsibilities.append(cleanLine) }
            case .about:
                aboutLines.append(cleanLine)
            case .none:
                if !isHeader && index > 2 { aboutLines.append(cleanLine) }
            case .other:
                break
            }
        }

        // Fallbacks
        if title.isEmpty { title = "Job Description" }
        if aboutLines.isEmpty && requirements.isEmpty {
            aboutLines = lines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
                .prefix(10)
                .map { String($0) }
        }

        return JobDescription(
            title: title,
            company: company.isEmpty ? "Company not found" : company,
            location: location.isEmpty ? "Location not specified" : location,
            jobType: jobType,
            aboutRole: aboutLines.joined(separator: "\n"),
            requirements: Array(requirements.prefix(15)),
            responsibilities: Array(responsibilities.prefix(15)),
            sourceURL: sourceURL,
            extractedAt: Date()
        )
    }

    // MARK: — Render PDF
    func generatePDF(from job: JobDescription) -> Data {
        let pageWidth:   CGFloat = 595.2
        let pageHeight:  CGFloat = 841.8
        let margin:      CGFloat = 50.0
        let contentWidth = pageWidth - (margin * 2)

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let brandColor    = UIColor(red: 0.36, green: 0.00, blue: 0.11, alpha: 1) // crimson
        let accentColor   = UIColor(red: 0.78, green: 0.53, blue: 0.06, alpha: 1) // amber
        let lightGray     = UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1)
        let textColor     = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
        let secondaryColor = UIColor.darkGray

        func titleAttrs(_ size: CGFloat, color: UIColor = textColor,
                        weight: UIFont.Weight = .bold) -> [NSAttributedString.Key: Any] {
            [.font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
        }
        func bodyAttrs(_ size: CGFloat = 10,
                       color: UIColor = textColor) -> [NSAttributedString.Key: Any] {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 3
            return [.font: UIFont.systemFont(ofSize: size, weight: .regular),
                    .foregroundColor: color,
                    .paragraphStyle: style]
        }

        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            // ── Header banner ─────────────────────────────────────────────────
            let bannerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 110)
            brandColor.setFill()
            UIRectFill(bannerRect)

            let iconRect = CGRect(x: margin, y: 20, width: 60, height: 60)
            UIColor.white.withAlphaComponent(0.15).setFill()
            UIBezierPath(ovalIn: iconRect).fill()
            "☕".draw(at: CGPoint(x: margin + 12, y: 28),
                     withAttributes: [.font: UIFont.systemFont(ofSize: 32)])

            "CafeOS".draw(
                at: CGPoint(x: margin + 72, y: 24),
                withAttributes: titleAttrs(22, color: .white, weight: .bold)
            )
            "Job Description Export".draw(
                at: CGPoint(x: margin + 72, y: 50),
                withAttributes: titleAttrs(11,
                    color: UIColor.white.withAlphaComponent(0.75), weight: .regular)
            )

            let dateStr  = "Extracted: \(job.extractedAt.formatted(date: .abbreviated, time: .shortened))"
            let dateAttrs = titleAttrs(9, color: UIColor.white.withAlphaComponent(0.65), weight: .regular)
            let dateSize  = (dateStr as NSString).size(withAttributes: dateAttrs)
            (dateStr as NSString).draw(
                at: CGPoint(x: pageWidth - margin - dateSize.width, y: 50),
                withAttributes: dateAttrs
            )

            y = 130

            // ── Job title ─────────────────────────────────────────────────────
            let titleAttrsMain = titleAttrs(20, color: brandColor, weight: .bold)
            let titleStr = job.title as NSString
            let titleRect = CGRect(x: margin, y: y, width: contentWidth, height: 200)
            titleStr.draw(in: titleRect, withAttributes: titleAttrsMain)
            let titleHeight = titleStr.boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: .usesLineFragmentOrigin,
                attributes: titleAttrsMain, context: nil
            ).height
            y += titleHeight + 8

            // ── Meta pills ────────────────────────────────────────────────────
            func drawPill(_ text: String, x: CGFloat, y: CGFloat, color: UIColor) -> CGFloat {
                let attrs    = titleAttrs(9, color: color, weight: .semibold)
                let size     = (text as NSString).size(withAttributes: attrs)
                let pillRect = CGRect(x: x, y: y, width: size.width + 20, height: size.height + 10)
                color.withAlphaComponent(0.12).setFill()
                UIBezierPath(roundedRect: pillRect, cornerRadius: 6).fill()
                color.withAlphaComponent(0.4).setStroke()
                UIBezierPath(roundedRect: pillRect, cornerRadius: 6).stroke()
                (text as NSString).draw(at: CGPoint(x: x + 10, y: y + 5), withAttributes: attrs)
                return pillRect.width + 8
            }

            var pillX = margin
            if job.company != "Company not found" {
                pillX += drawPill("🏢 \(job.company)", x: pillX, y: y, color: brandColor)
            }
            if job.location != "Location not specified" {
                pillX += drawPill("📍 \(job.location)", x: pillX, y: y, color: accentColor)
            }
            if !job.jobType.isEmpty {
                _ = drawPill("💼 \(job.jobType)", x: pillX, y: y, color: .systemBlue)
            }
            y += 32

            // ── Divider helper ────────────────────────────────────────────────
            func drawDivider(at yPos: CGFloat) {
                lightGray.setStroke()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPos))
                path.addLine(to: CGPoint(x: pageWidth - margin, y: yPos))
                path.lineWidth = 1
                path.stroke()
            }

            drawDivider(at: y)
            y += 16

            // ── Section helpers ───────────────────────────────────────────────
            func drawSectionHeader(_ title: String) {
                accentColor.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: 4, height: 18))
                (title.uppercased() as NSString).draw(
                    at: CGPoint(x: margin + 10, y: y),
                    withAttributes: titleAttrs(11, color: brandColor, weight: .bold)
                )
                y += 26
            }

            func drawBodyText(_ text: String) -> CGFloat {
                guard !text.isEmpty else { return 0 }
                let attrs = bodyAttrs()
                let rect  = (text as NSString).boundingRect(
                    with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: attrs, context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: margin, y: y, width: contentWidth, height: rect.height + 2),
                    withAttributes: attrs
                )
                return rect.height + 2
            }

            func drawBulletItem(_ text: String) {
                let bulletAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: accentColor
                ]
                "•".draw(at: CGPoint(x: margin, y: y), withAttributes: bulletAttrs)
                let indentWidth = contentWidth - 16
                let attrs = bodyAttrs()
                let rect  = (text as NSString).boundingRect(
                    with: CGSize(width: indentWidth, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin, attributes: attrs, context: nil
                )
                (text as NSString).draw(
                    in: CGRect(x: margin + 16, y: y, width: indentWidth, height: rect.height + 2),
                    withAttributes: attrs
                )
                y += rect.height + 8
            }

            func checkAndAddPage() {
                if y > pageHeight - 80 {
                    ctx.beginPage()
                    y = margin
                }
            }

            // ── About the Role ────────────────────────────────────────────────
            if !job.aboutRole.isEmpty {
                checkAndAddPage()
                drawSectionHeader("About the Role")
                let h = drawBodyText(job.aboutRole)
                y += h + 20
                drawDivider(at: y)
                y += 16
            }

            // ── Responsibilities ──────────────────────────────────────────────
            if !job.responsibilities.isEmpty {
                checkAndAddPage()
                drawSectionHeader("Responsibilities")
                for item in job.responsibilities {
                    checkAndAddPage()
                    drawBulletItem(item)
                }
                y += 12
                drawDivider(at: y)
                y += 16
            }

            // ── Requirements ──────────────────────────────────────────────────
            if !job.requirements.isEmpty {
                checkAndAddPage()
                drawSectionHeader("Requirements & Qualifications")
                for item in job.requirements {
                    checkAndAddPage()
                    drawBulletItem(item)
                }
                y += 12
                drawDivider(at: y)
                y += 16
            }

            // ── Source URL ────────────────────────────────────────────────────
            checkAndAddPage()
            drawSectionHeader("Source")
            let urlAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9, weight: .regular),
                .foregroundColor: UIColor.systemBlue
            ]
            (job.sourceURL as NSString).draw(
                in: CGRect(x: margin, y: y, width: contentWidth, height: 30),
                withAttributes: urlAttrs
            )
            y += 20

            // ── Footer ────────────────────────────────────────────────────────
            let footerY    = pageHeight - 35
            drawDivider(at: footerY - 6)
            let footerText = "Generated by CafeOS  •  \(job.extractedAt.formatted(date: .complete, time: .omitted))"
            let footerAttrs = titleAttrs(8, color: secondaryColor, weight: .regular)
            let footerSize  = (footerText as NSString).size(withAttributes: footerAttrs)
            (footerText as NSString).draw(
                at: CGPoint(x: (pageWidth - footerSize.width) / 2, y: footerY),
                withAttributes: footerAttrs
            )
        }

        return data
    }
}
