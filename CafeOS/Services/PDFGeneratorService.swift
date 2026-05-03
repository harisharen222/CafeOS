import Foundation
import UIKit
import PDFKit

// MARK: — Job Description Model

struct JobDescription {
    var title: String
    var company: String
    var location: String
    var employmentType: String      // "Internship", "Full-time", etc. — empty if not found
    var aboutRole: String
    var responsibilities: [String]
    var requirements: [String]
    var additionalInfo: String      // Capped at 300 chars
    var sourceURL: String
    var extractedAt: Date

    // Computed display string shown in the scroll view
    var displayText: String {
        var parts: [String] = []

        // Header block
        var header = title
        if !company.isEmpty || !location.isEmpty {
            let meta = [company, location].filter { !$0.isEmpty }.joined(separator: " · ")
            header += "\n" + meta
        }
        if !employmentType.isEmpty { header += "\n" + employmentType }
        parts.append(header)

        // About
        if !aboutRole.isEmpty {
            parts.append("About the Role\n" + aboutRole)
        }

        // Responsibilities
        if !responsibilities.isEmpty {
            let items = responsibilities.map { "- " + $0 }.joined(separator: "\n")
            parts.append("Responsibilities\n" + items)
        }

        // Requirements
        if !requirements.isEmpty {
            let items = requirements.map { "- " + $0 }.joined(separator: "\n")
            parts.append("Requirements\n" + items)
        }

        return parts.joined(separator: "\n\n")
    }

    // Convenience for PDF: jobType field expected by generatePDF
    var jobType: String { employmentType }
}

// MARK: — PDF Generator

class PDFGeneratorService {

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
