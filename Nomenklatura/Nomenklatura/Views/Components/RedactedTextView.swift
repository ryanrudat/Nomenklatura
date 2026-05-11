//
//  RedactedTextView.swift
//  Nomenklatura
//
//  Clearance-based text redaction component for the surveillance state aesthetic.
//  Shows blacked-out text when player lacks sufficient clearance.
//

import SwiftUI

// MARK: - Redacted Text View

/// A view that displays text with clearance-based redaction
/// Shows black bars over text when the player lacks sufficient access level
struct RedactedTextView: View {
    let originalText: String
    let isRedacted: Bool
    var revealable: Bool = false
    var requiredLevel: Int = 0
    var style: RedactionStyle = .blackBar

    @State private var isRevealed: Bool = false
    @State private var showAccessDenied: Bool = false

    enum RedactionStyle {
        case blackBar           // Solid black bar covering text
        case blackBlocks        // Individual character blocks (████████)
        case strikethrough      // Text with heavy strikethrough
        case blur               // Blurred text (iOS 17+)
        case classified         // [CLASSIFIED] replacement text
    }

    var body: some View {
        if isRedacted && !isRevealed {
            redactedContent
        } else {
            Text(originalText)
        }
    }

    @ViewBuilder
    private var redactedContent: some View {
        switch style {
        case .blackBar:
            blackBarRedaction

        case .blackBlocks:
            Text(String(repeating: "█", count: min(originalText.count, 30)))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.black)
                .onTapGesture(perform: handleTap)

        case .strikethrough:
            ZStack {
                Text(originalText)
                    .foregroundColor(.gray.opacity(0.3))
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
            }
            .onTapGesture(perform: handleTap)

        case .blur:
            Text(originalText)
                .blur(radius: 6)
                .onTapGesture(perform: handleTap)

        case .classified:
            classifiedReplacement
        }
    }

    private var blackBarRedaction: some View {
        ZStack(alignment: .leading) {
            Text(originalText)
                .foregroundColor(.clear)

            GeometryReader { geometry in
                Rectangle()
                    .fill(Color.black)
                    .frame(width: geometry.size.width, height: geometry.size.height * 0.9)
                    .offset(y: geometry.size.height * 0.05)
                    .overlay(
                        Group {
                            if revealable {
                                Text("TAP TO DECLASSIFY")
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                                    .foregroundColor(ColdWarTheme.shared.bronzeGold.opacity(0.6))
                                    .tracking(1)
                            }
                        }
                    )
            }
        }
        .onTapGesture(perform: handleTap)
        .overlay(
            Group {
                if showAccessDenied {
                    accessDeniedToast
                }
            }
        )
    }

    private var classifiedReplacement: some View {
        HStack(spacing: 4) {
            Image(systemName: revealable ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 9))
                .foregroundColor(revealable ? ColdWarTheme.shared.bronzeGold : ColdWarTheme.shared.sovietRed)

            Text("[CLASSIFIED")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(revealable ? ColdWarTheme.shared.bronzeGold : ColdWarTheme.shared.sovietRed)

            if revealable {
                Text("- TAP TO DECLASSIFY")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColdWarTheme.shared.bronzeGold.opacity(0.8))
            } else if requiredLevel > 0 {
                Text("- LEVEL \(requiredLevel) CLEARANCE REQUIRED")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(ColdWarTheme.shared.sovietRed.opacity(0.8))
            }

            Text("]")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(revealable ? ColdWarTheme.shared.bronzeGold : ColdWarTheme.shared.sovietRed)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(revealable ? ColdWarTheme.shared.bronzeGold.opacity(0.08) : Color.black.opacity(0.05))
        .cornerRadius(3)
        .onTapGesture(perform: handleTap)
    }

    private var accessDeniedToast: some View {
        VStack(spacing: 4) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 16))
                .foregroundColor(ColdWarTheme.shared.sovietRed)

            Text("ACCESS DENIED")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(ColdWarTheme.shared.sovietRed)

            if requiredLevel > 0 {
                Text("Clearance Level \(requiredLevel) Required")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(ColdWarTheme.shared.agedPaper)
        .cornerRadius(4)
        .shadow(radius: 2)
        .transition(.opacity.combined(with: .scale))
    }

    private func handleTap() {
        if revealable {
            withAnimation(.easeInOut(duration: 0.3)) {
                isRevealed = true
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showAccessDenied = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAccessDenied = false
                }
            }
        }
    }
}

// MARK: - Inline Redacted Text

/// A text view that can contain inline redacted sections
/// Usage: InlineRedactedText("Agent [REDACTED] reported from [REDACTED] station")
/// High-clearance players (level 7+) can tap redacted sections to reveal them
struct InlineRedactedText: View {
    let text: String
    let accessLevel: Int
    var redactionThreshold: Int = 5

    @State private var revealedIndices: Set<Int> = []

    var body: some View {
        parseAndRender()
    }

    @ViewBuilder
    private func parseAndRender() -> some View {
        let components = parseRedactions()

        HStack(spacing: 0) {
            ForEach(components.indices, id: \.self) { index in
                if components[index].isRedacted {
                    if accessLevel >= redactionThreshold || revealedIndices.contains(index) {
                        Text(components[index].content)
                    } else {
                        let blockText = String(repeating: "█", count: min(components[index].content.count, 12))
                        let canReveal = accessLevel >= 7
                        Text(blockText)
                            .font(Font.system(size: 14).monospaced())
                            .foregroundColor(canReveal ? ColdWarTheme.shared.bronzeGold.opacity(0.8) : .black)
                            .onTapGesture {
                                if canReveal {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        _ = revealedIndices.insert(index)
                                    }
                                }
                            }
                    }
                } else {
                    Text(components[index].content)
                }
            }
        }
    }

    private func parseRedactions() -> [(content: String, isRedacted: Bool)] {
        var results: [(content: String, isRedacted: Bool)] = []
        var currentIndex = text.startIndex

        // Pattern: [REDACTED] or [REDACTED: actual text]
        let pattern = #"\[REDACTED(?::\s*([^\]]+))?\]"#

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

            for match in matches {
                let matchRange = Range(match.range, in: text)!

                // Add text before the match
                if currentIndex < matchRange.lowerBound {
                    results.append((String(text[currentIndex..<matchRange.lowerBound]), false))
                }

                // Extract redacted content (if any)
                if match.numberOfRanges > 1, let contentRange = Range(match.range(at: 1), in: text) {
                    results.append((String(text[contentRange]), true))
                } else {
                    results.append(("REDACTED", true))
                }

                currentIndex = matchRange.upperBound
            }

            // Add remaining text
            if currentIndex < text.endIndex {
                results.append((String(text[currentIndex...]), false))
            }
        } else {
            results.append((text, false))
        }

        return results
    }
}

// MARK: - Redaction Manager

/// Utility for applying redactions based on access level
struct RedactionManager {
    let accessLevel: Int

    init(accessLevel: Int) {
        self.accessLevel = accessLevel
    }

    /// Check if content at a required level should be redacted
    func shouldRedact(requiredLevel: Int) -> Bool {
        return accessLevel < requiredLevel
    }

    /// Redact text for a given clearance requirement
    func redactForClearance(_ text: String, requiredLevel: Int) -> (text: String, isRedacted: Bool) {
        if accessLevel >= requiredLevel {
            return (text, false)
        }
        return ("[REDACTED - LEVEL \(requiredLevel) CLEARANCE REQUIRED]", true)
    }

    /// Redact sensitive patterns in text (names, locations, operations)
    func redactSensitivePatterns(_ text: String, requiredLevel: Int) -> String {
        guard shouldRedact(requiredLevel: requiredLevel) else {
            return text
        }

        var result = text

        // Redact patterns like "Agent [Name]" or "Operative [Name]"
        let agentPattern = #"(Agent|Operative|Asset)\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?"#
        if let regex = try? NSRegularExpression(pattern: agentPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1 [REDACTED]"
            )
        }

        // Redact location patterns
        let locationPattern = #"(in|at|from|to)\s+[A-Z][a-z]+(\s+[A-Z][a-z]+)?"#
        if let regex = try? NSRegularExpression(pattern: locationPattern, options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1 [REDACTED]"
            )
        }

        return result
    }

    /// Create redaction view for a piece of text
    /// At high clearance, redacted content becomes tappable to declassify
    func createRedactedView(for text: String, requiredLevel: Int, style: RedactedTextView.RedactionStyle = .blackBar) -> RedactedTextView {
        let isRedacted = shouldRedact(requiredLevel: requiredLevel)
        // General Secretary (level 8) can always tap to reveal classified content
        let canReveal = isRedacted && accessLevel >= 7
        return RedactedTextView(
            originalText: text,
            isRedacted: isRedacted,
            revealable: canReveal,
            requiredLevel: requiredLevel,
            style: style
        )
    }
}

// MARK: - Document Classification Badge

/// A badge showing the classification level of a document for redaction purposes
struct DocumentClassificationBadge: View {
    let classification: DocumentSecurityLevel
    var compact: Bool = false

    enum DocumentSecurityLevel: String, CaseIterable {
        case unclassified = "UNCLASSIFIED"
        case restricted = "RESTRICTED"
        case confidential = "CONFIDENTIAL"
        case secret = "SECRET"
        case topSecret = "TOP SECRET"
        case eyesOnly = "EYES ONLY"

        var color: Color {
            switch self {
            case .unclassified: return .gray
            case .restricted: return .blue
            case .confidential: return .orange
            case .secret: return ColdWarTheme.shared.sovietRed
            case .topSecret: return ColdWarTheme.shared.stampRedDark
            case .eyesOnly: return .black
            }
        }

        var requiredLevel: Int {
            switch self {
            case .unclassified: return 0
            case .restricted: return 2
            case .confidential: return 4
            case .secret: return 6
            case .topSecret: return 7
            case .eyesOnly: return 8
            }
        }
    }

    var body: some View {
        if compact {
            compactBadge
        } else {
            fullBadge
        }
    }

    private var fullBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))

            Text(classification.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
        }
        .foregroundColor(classification.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(classification.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(classification.color, lineWidth: 1)
        )
    }

    private var compactBadge: some View {
        Text(classification.rawValue.prefix(3))
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundColor(classification.color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(classification.color.opacity(0.15))
            .cornerRadius(2)
    }
}

// MARK: - Preview

#Preview("Redacted Text Styles") {
    VStack(spacing: 20) {
        Group {
            Text("Black Bar Style:")
                .font(.headline)
            RedactedTextView(
                originalText: "Agent Johnson reported from Berlin station",
                isRedacted: true,
                style: .blackBar
            )
        }

        Group {
            Text("Black Blocks Style:")
                .font(.headline)
            RedactedTextView(
                originalText: "Operation Nightfall",
                isRedacted: true,
                style: .blackBlocks
            )
        }

        Group {
            Text("Classified Style:")
                .font(.headline)
            RedactedTextView(
                originalText: "Meeting at safe house",
                isRedacted: true,
                requiredLevel: 6,
                style: .classified
            )
        }

        Group {
            Text("Revealable (tap to reveal):")
                .font(.headline)
            RedactedTextView(
                originalText: "Secret information",
                isRedacted: true,
                revealable: true,
                style: .blackBar
            )
        }

        Divider()

        Text("Classification Badges:")
            .font(.headline)

        HStack {
            ForEach(DocumentClassificationBadge.DocumentSecurityLevel.allCases, id: \.self) { level in
                DocumentClassificationBadge(classification: level, compact: true)
            }
        }
    }
    .padding()
    .background(ColdWarTheme.shared.agedPaper)
}
