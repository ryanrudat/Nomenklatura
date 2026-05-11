//
//  FiftiesStyleComponents.swift
//  Nomenklatura
//
//  1950s Cold War era styling components - typewriter documents, rubber stamps,
//  aged paper textures, and government dossier aesthetics
//

import SwiftUI

// MARK: - 1950s Color Palette (DEPRECATED — wraps ColdWarTheme.shared)
//
// FiftiesColors was one of three competing color systems (alongside
// StitchColors and BureauColors). All values now resolve through the
// canonical ColdWarTheme so future call-site migrations are zero-risk.
// Migration path: replace each reference with @Environment(\.theme) in
// view bodies, or ColdWarTheme.shared.X elsewhere.

@available(*, deprecated, message: "Use @Environment(\\.theme) in views or ColdWarTheme.shared elsewhere")
struct FiftiesColors {
    // Paper tones
    static var agedPaper: Color { ColdWarTheme.shared.agedPaper }
    static var freshPaper: Color { ColdWarTheme.shared.freshPaper }
    static var cardstock: Color { ColdWarTheme.shared.cardstock }
    static var manillaFolder: Color { ColdWarTheme.shared.manillaFolder }

    // Ink tones
    static var typewriterInk: Color { ColdWarTheme.shared.inkBlack }
    static var fadedInk: Color { ColdWarTheme.shared.inkGray }
    static var carbonCopy: Color { ColdWarTheme.shared.carbonCopy }

    // Stamp colors
    static var stampRed: Color { ColdWarTheme.shared.sovietRed }
    static var stampRedDark: Color { ColdWarTheme.shared.stampRedDark }
    static var urgentRed: Color { ColdWarTheme.shared.urgentRed }
    static var approvedGreen: Color { ColdWarTheme.shared.approvedGreen }
    static var deniedRed: Color { ColdWarTheme.shared.stampRedDark }

    // Accent colors
    static var brassGold: Color { ColdWarTheme.shared.bronzeGold }
    static var steelGray: Color { ColdWarTheme.shared.steelGray }
    static var leatherBrown: Color { ColdWarTheme.shared.leatherBrown }
}

// MARK: - Bureau Colors (DEPRECATED — wraps ColdWarTheme + ExpandedCareerTrack)
//
// BureauColors was a third competing color system. Logic preserved
// exactly; the per-bureau hex values stay here for now since they are
// unique to the bureau-mapping and not used elsewhere. Future cleanup
// will move these into a theme-side `bureauColor(for:)` helper.

@available(*, deprecated, message: "Use ColdWarTheme.shared bureau helpers (coming in a later sub-batch)")
struct BureauColors {

    /// Primary color for a bureau (main accent/header)
    static func primary(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices:
            return ColdWarTheme.shared.stampRedDark
        case .economicPlanning:
            return ColdWarTheme.shared.approvedGreen
        case .partyApparatus:
            return Color(hex: "CC0000")
        default:
            return ColdWarTheme.shared.leatherBrown
        }
    }

    /// Secondary/accent color for a bureau
    static func accent(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices:
            return ColdWarTheme.shared.sovietRed
        case .economicPlanning:
            return Color(hex: "4A7C59")
        case .partyApparatus:
            return Color(hex: "FFD700")
        default:
            return ColdWarTheme.shared.bronzeGold
        }
    }

    /// Background color for bureau cards/sections
    static func background(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices:
            return ColdWarTheme.shared.stampRedDark.opacity(0.08)
        case .economicPlanning:
            return ColdWarTheme.shared.approvedGreen.opacity(0.08)
        case .partyApparatus:
            return Color(hex: "CC0000").opacity(0.08)
        default:
            return ColdWarTheme.shared.cardstock
        }
    }

    /// Icon name for a bureau
    static func icon(for bureau: ExpandedCareerTrack) -> String {
        bureau.iconName
    }

    /// Short code for a bureau (BPS, GOSPLAN, CC)
    static func code(for bureau: ExpandedCareerTrack) -> String {
        bureau.shortName
    }

    /// Full display name for bureau header
    static func headerTitle(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices:
            return "STATE PROTECTION BUREAU"
        case .economicPlanning:
            return "ECONOMIC PLANNING BUREAU"
        case .partyApparatus:
            return "PARTY APPARATUS BUREAU"
        case .foreignAffairs:
            return "FOREIGN AFFAIRS BUREAU"
        case .militaryPolitical:
            return "MILITARY-POLITICAL BUREAU"
        case .stateMinistry:
            return "STATE MINISTRY BUREAU"
        case .regional:
            return "REGIONAL ADMINISTRATION"
        case .shared:
            return "GENERAL ADMINISTRATION"
        }
    }

    /// Subtitle for bureau identity
    static func subtitle(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices:
            return "Security Services Official"
        case .economicPlanning:
            return "Gosplan Official"
        case .partyApparatus:
            return "Central Committee Official"
        case .foreignAffairs:
            return "Foreign Ministry Official"
        case .militaryPolitical:
            return "Military-Political Official"
        case .stateMinistry:
            return "State Ministry Official"
        case .regional:
            return "Regional Administrator"
        case .shared:
            return "Government Official"
        }
    }
}

// MARK: - Rubber Stamp Component

/// Authentic rubber stamp effect with ink bleed and wear
struct RubberStamp: View {
    let text: String
    var stampType: StampType = .classified
    var rotation: Double = -12
    var size: StampSize = .medium

    enum StampType {
        case urgent
        case classified
        case confidential
        case topSecret
        case approved
        case denied
        case executed
        case restricted
        case priority
        case custom(color: Color)

        var color: Color {
            switch self {
            case .urgent: return ColdWarTheme.shared.urgentRed
            case .classified: return ColdWarTheme.shared.sovietRed
            case .confidential: return ColdWarTheme.shared.stampRedDark
            case .topSecret: return ColdWarTheme.shared.stampRedDark
            case .approved: return ColdWarTheme.shared.approvedGreen
            case .denied: return ColdWarTheme.shared.stampRedDark
            case .executed: return ColdWarTheme.shared.stampRedDark
            case .restricted: return ColdWarTheme.shared.sovietRed
            case .priority: return ColdWarTheme.shared.urgentRed
            case .custom(let color): return color
            }
        }
    }

    enum StampSize {
        case small, medium, large

        var fontSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 14
            case .large: return 20
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6)
            case .medium: return EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)
            case .large: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            }
        }

        var borderWidth: CGFloat {
            switch self {
            case .small: return 1.5
            case .medium: return 2.5
            case .large: return 3.5
            }
        }
    }

    var body: some View {
        ZStack {
            // Main stamp text - use system font with condensed width for authentic stamp look
            Text(text)
                .font(.system(size: size.fontSize, weight: .black, design: .default))
                .tracking(size == .large ? 3 : 2)
                .foregroundColor(stampType.color.opacity(0.85))
                .padding(size.padding)
                .overlay(
                    Rectangle()
                        .stroke(stampType.color.opacity(0.85), lineWidth: size.borderWidth)
                )
                // Ink wear/distress effect
                .overlay(
                    StampDistressOverlay(color: stampType.color)
                )
                // Ink bleed effect
                .shadow(color: stampType.color.opacity(0.2), radius: 0.5, x: 0.5, y: 0.5)
        }
        .rotationEffect(.degrees(rotation))
    }
}

/// Distress overlay for stamps to simulate wear
struct StampDistressOverlay: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            // Random gaps in ink
            ForEach(0..<Int(geo.size.width / 8), id: \.self) { i in
                ForEach(0..<Int(geo.size.height / 4), id: \.self) { j in
                    if Bool.random() && Bool.random() {
                        Circle()
                            .fill(ColdWarTheme.shared.agedPaper)
                            .frame(width: CGFloat.random(in: 1...3), height: CGFloat.random(in: 1...3))
                            .position(
                                x: CGFloat(i) * 8 + CGFloat.random(in: -2...2),
                                y: CGFloat(j) * 4 + CGFloat.random(in: -1...1)
                            )
                            .opacity(Double.random(in: 0.3...0.8))
                    }
                }
            }
        }
    }
}

// MARK: - Circular Stamp (Date/Seal)

/// Circular official seal stamp
struct CircularSeal: View {
    let text: String
    var innerText: String? = nil
    var date: String? = nil
    var color: Color = ColdWarTheme.shared.sovietRed
    var size: CGFloat = 60
    var rotation: Double = -8

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(color.opacity(0.8), lineWidth: 2)
                .frame(width: size, height: size)

            // Inner ring
            Circle()
                .stroke(color.opacity(0.8), lineWidth: 1)
                .frame(width: size - 10, height: size - 10)

            // Text around the circle
            CircularText(text: text.uppercased(), radius: size / 2 - 8, fontSize: size * 0.12)
                .foregroundColor(color.opacity(0.8))

            // Center content
            VStack(spacing: 1) {
                if let inner = innerText {
                    Text(inner)
                        .font(.system(size: size * 0.15, weight: .black))
                        .foregroundColor(color.opacity(0.8))
                }
                if let date = date {
                    Text(date)
                        .font(.system(size: size * 0.1, weight: .bold))
                        .foregroundColor(color.opacity(0.7))
                }
            }

            // Distress overlay
            Circle()
                .fill(ColdWarTheme.shared.agedPaper)
                .frame(width: size, height: size)
                .mask(
                    StampDistressOverlay(color: color)
                )
        }
        .rotationEffect(.degrees(rotation))
    }
}

/// Helper for circular text
struct CircularText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        ZStack {
            ForEach(Array(text.enumerated()), id: \.offset) { index, character in
                Text(String(character))
                    .font(.system(size: fontSize, weight: .bold))
                    .rotationEffect(.degrees(Double(index) * 360.0 / Double(text.count) - 90))
                    .offset(y: -radius)
                    .rotationEffect(.degrees(-Double(index) * 360.0 / Double(text.count)))
            }
        }
    }
}

// MARK: - Typewriter Document Frame

/// Document styled like a typewritten memo/report
struct TypewriterDocument: View {
    let title: String
    var subtitle: String? = nil
    var date: String? = nil
    var classification: String? = nil
    var documentNumber: String? = nil
    @ViewBuilder var content: () -> any View

    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Document header
            documentHeader

            // Main content area
            VStack(alignment: .leading, spacing: 12) {
                AnyView(content())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(TypewriterPaper())
        .clipShape(RoundedRectangle(cornerRadius: 2))
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 2, y: 3)
    }

    private var documentHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top bar with classification
            HStack {
                if let classification = classification {
                    RubberStamp(text: classification, stampType: .classified, rotation: 0, size: .small)
                }
                Spacer()
                if let docNum = documentNumber {
                    Text(docNum)
                        .font(.custom("AmericanTypewriter", size: 10))
                        .foregroundColor(theme.inkGray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Date line
            if let date = date {
                Text(date)
                    .font(.custom("AmericanTypewriter", size: 11))
                    .foregroundColor(theme.inkBlack)
                    .padding(.horizontal, 20)
            }

            // Title
            Text(title.uppercased())
                .font(.custom("AmericanTypewriter", size: 16))
                .fontWeight(.bold)
                .foregroundColor(theme.inkBlack)
                .tracking(1)
                .padding(.horizontal, 20)

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.custom("AmericanTypewriter", size: 12))
                    .foregroundColor(theme.inkGray)
                    .padding(.horizontal, 20)
            }

            // Divider line (typewriter style)
            Rectangle()
                .fill(theme.inkBlack)
                .frame(height: 1)
                .padding(.horizontal, 20)
                .padding(.top, 8)
        }
    }
}

/// Paper texture for typewritten documents
struct TypewriterPaper: View {
    var body: some View {
        ZStack {
            // Base paper color
            ColdWarTheme.shared.agedPaper

            // Horizontal typing guide lines (faint)
            GeometryReader { geo in
                ForEach(0..<Int(geo.size.height / 24), id: \.self) { i in
                    Rectangle()
                        .fill(Color(hex: "E0D8C8").opacity(0.3))
                        .frame(height: 0.5)
                        .offset(y: CGFloat(i) * 24 + 20)
                }
            }

            // Paper grain/fiber texture
            GeometryReader { geo in
                ForEach(0..<Int(geo.size.width / 2), id: \.self) { i in
                    Rectangle()
                        .fill(Color(hex: "D8D0C0").opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 0.5...2), height: CGFloat.random(in: 5...20))
                        .rotationEffect(.degrees(Double.random(in: -10...10)))
                        .position(
                            x: CGFloat(i) * 2 + CGFloat.random(in: -1...1),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                }
            }
            .opacity(0.6)

            // Edge yellowing
            LinearGradient(
                colors: [
                    Color(hex: "D4A574").opacity(0.08),
                    Color.clear,
                    Color.clear,
                    Color(hex: "D4A574").opacity(0.05)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Top/bottom aging
            VStack {
                LinearGradient(
                    colors: [Color(hex: "C4B090").opacity(0.15), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)

                Spacer()

                LinearGradient(
                    colors: [Color.clear, Color(hex: "C4B090").opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
            }
        }
    }
}

// MARK: - Stat Display Box

/// 1950s style stat display matching the mockups
struct StatDisplayBox: View {
    let label: String
    let value: String
    var icon: String? = nil
    var valueColor: Color = ColdWarTheme.shared.inkBlack
    var status: StatStatus = .neutral

    enum StatStatus {
        case positive, negative, neutral, critical

        var backgroundColor: Color {
            switch self {
            case .positive: return Color(hex: "D4EDDA").opacity(0.3)
            case .negative: return Color(hex: "F8D7DA").opacity(0.3)
            case .critical: return Color(hex: "F8D7DA").opacity(0.5)
            case .neutral: return ColdWarTheme.shared.cardstock
            }
        }

        var accentColor: Color {
            switch self {
            case .positive: return Color(hex: "28A745")
            case .negative: return ColdWarTheme.shared.sovietRed
            case .critical: return ColdWarTheme.shared.urgentRed
            case .neutral: return ColdWarTheme.shared.inkBlack
            }
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Label with icon
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                }
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.inkGray)
            }

            // Value
            Text(value)
                .font(.custom("AmericanTypewriter", size: 18))
                .fontWeight(.bold)
                .foregroundColor(status.accentColor)

            // Status indicator line
            if status != .neutral {
                Rectangle()
                    .fill(status.accentColor)
                    .frame(height: 2)
                    .frame(maxWidth: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(status.backgroundColor)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
        )
    }
}

// MARK: - Stat Change Badge

/// Shows stat changes like "+20" or "-15" with appropriate coloring
struct StatChangeBadge: View {
    let change: Int
    let label: String
    var status: StatDisplayBox.StatStatus = .neutral

    var body: some View {
        VStack(spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .default))
                .fontWeight(.semibold)
                .tracking(0.5)
                .foregroundColor(ColdWarTheme.shared.inkGray)

            Text(change >= 0 ? "+\(change)" : "\(change)")
                .font(.custom("AmericanTypewriter", size: 16))
                .fontWeight(.bold)
                .foregroundColor(change >= 0 ? Color(hex: "28A745") : ColdWarTheme.shared.sovietRed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ColdWarTheme.shared.cardstock)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
        )
    }
}

// MARK: - Dossier Photo Frame

/// Official dossier-style photo frame (1950s variant)
struct FiftiesDossierPhoto: View {
    let name: String
    var imageName: String? = nil
    var title: String? = nil
    var size: CGFloat = 80
    var showStaple: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Photo area
            ZStack {
                // Photo background
                Rectangle()
                    .fill(Color(hex: "2A2A2A"))
                    .frame(width: size, height: size * 1.2)

                // Photo or initials
                if let imageName = imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size - 8, height: size * 1.2 - 8)
                        .grayscale(0.8)
                        .contrast(1.1)
                        .clipped()
                } else {
                    // Stylized initials
                    VStack {
                        Text(initials(from: name))
                            .font(.system(size: size * 0.35, weight: .bold, design: .serif))
                            .foregroundColor(Color(hex: "4A4A4A"))
                    }
                }

                // Vintage photo overlay
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "8B7355").opacity(0.15),
                                Color.clear,
                                Color(hex: "8B7355").opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size * 1.2)

                // Corner wear
                VStack {
                    HStack {
                        Triangle()
                            .fill(ColdWarTheme.shared.agedPaper.opacity(0.3))
                            .frame(width: 8, height: 8)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: size, height: size * 1.2)
            }
            .clipShape(Rectangle())

            // Name label below photo
            if let title = title {
                Text(title)
                    .font(.custom("AmericanTypewriter", size: 8))
                    .foregroundColor(ColdWarTheme.shared.inkGray)
                    .lineLimit(1)
                    .frame(width: size)
                    .padding(.top, 4)
            }
        }
        .overlay(
            // Photo border
            Rectangle()
                .stroke(Color(hex: "8B7355"), lineWidth: 1)
                .frame(width: size, height: size * 1.2)
        )
        .overlay(
            // Staple effect
            Group {
                if showStaple {
                    Staple()
                        .offset(x: -size/2 + 8, y: -size * 0.6 + 5)
                }
            }
        )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

/// Triangle shape for corner effects
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Staple decoration
struct Staple: View {
    var body: some View {
        ZStack {
            // Staple body
            RoundedRectangle(cornerRadius: 1)
                .fill(ColdWarTheme.shared.steelGray)
                .frame(width: 12, height: 4)

            // Highlight
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.3))
                .frame(width: 10, height: 1)
                .offset(y: -1)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 1, x: 0, y: 1)
    }
}

// MARK: - File Tab

/// Manila folder tab for document sections
struct FileTab: View {
    let text: String
    var isActive: Bool = true
    var color: Color = ColdWarTheme.shared.manillaFolder

    var body: some View {
        ZStack {
            // Tab shape
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 6
            )
            .fill(isActive ? color : color.opacity(0.6))
            .frame(height: 28)

            // Tab text
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .default))
                .fontWeight(.semibold)
                .tracking(1)
                .foregroundColor(isActive ? ColdWarTheme.shared.leatherBrown : ColdWarTheme.shared.inkGray)
                .padding(.horizontal, 12)
        }
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 6
            )
            .stroke(Color(hex: "C4A962").opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Character Quote Card

/// Dossier-style card showing character reaction with portrait
struct CharacterQuoteCard: View {
    let name: String
    let quote: String
    var imageName: String? = nil
    var sentiment: Sentiment = .neutral

    enum Sentiment {
        case positive, negative, neutral

        var icon: String {
            switch self {
            case .positive: return "hand.thumbsup.fill"
            case .negative: return "hand.thumbsdown.fill"
            case .neutral: return "minus.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .positive: return Color(hex: "28A745")
            case .negative: return ColdWarTheme.shared.sovietRed
            case .neutral: return ColdWarTheme.shared.inkGray
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Portrait
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "2A2A2A"))
                    .frame(width: 50, height: 60)

                if let imageName = imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 46, height: 56)
                        .grayscale(0.7)
                        .clipped()
                } else {
                    Text(initials(from: name))
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "5A5A5A"))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex: "8B7355"), lineWidth: 1)
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Name and sentiment
                HStack {
                    Text(name.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .default))
                        .fontWeight(.bold)
                        .tracking(0.5)
                        .foregroundColor(ColdWarTheme.shared.inkBlack)

                    Spacer()

                    Image(systemName: sentiment.icon)
                        .font(.system(size: 12))
                        .foregroundColor(sentiment.color)
                }

                // Quote
                Text("\"\(quote)\"")
                    .font(.custom("AmericanTypewriter", size: 12))
                    .italic()
                    .foregroundColor(ColdWarTheme.shared.inkGray)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(ColdWarTheme.shared.cardstock)
        .overlay(
            Rectangle()
                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
        )
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Briefing Paper Header

/// Header component for official briefing papers
struct BriefingPaperHeader: View {
    let date: String
    let subject: String
    var from: String? = nil
    var classification: String = "CONFIDENTIAL"
    var documentId: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top classification bar
            HStack {
                // Classification stamp
                RubberStamp(text: classification, stampType: .confidential, rotation: 0, size: .small)

                Spacer()

                // Document ID
                if let docId = documentId {
                    Text(docId)
                        .font(.custom("AmericanTypewriter", size: 9))
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                }
            }
            .padding(.bottom, 12)

            // Memo header fields
            VStack(alignment: .leading, spacing: 6) {
                headerField(label: "DATE:", value: date)

                if let from = from {
                    headerField(label: "FROM:", value: from)
                }

                headerField(label: "SUBJECT:", value: subject, bold: true)
            }

            // Divider
            Rectangle()
                .fill(ColdWarTheme.shared.inkBlack)
                .frame(height: 2)
                .padding(.top, 12)
        }
        .padding(16)
        .background(ColdWarTheme.shared.agedPaper)
    }

    private func headerField(label: String, value: String, bold: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.custom("AmericanTypewriter", size: 11))
                .foregroundColor(ColdWarTheme.shared.inkGray)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.custom("AmericanTypewriter", size: 11))
                .fontWeight(bold ? .bold : .regular)
                .foregroundColor(ColdWarTheme.shared.inkBlack)
        }
    }
}

// MARK: - Action Button (1950s Style)

/// Industrial-style action button
struct FiftiesButton: View {
    let text: String
    var style: ButtonStyle = .primary
    var icon: String? = nil
    var action: () -> Void

    enum ButtonStyle {
        case primary    // Red/action
        case secondary  // Gray/neutral
        case danger     // Dark red/destructive

        var backgroundColor: Color {
            switch self {
            case .primary: return ColdWarTheme.shared.sovietRed
            case .secondary: return ColdWarTheme.shared.steelGray
            case .danger: return ColdWarTheme.shared.stampRedDark
            }
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(text.uppercased())
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .fontWeight(.bold)
                    .tracking(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(style.backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Previews

#Preview("Rubber Stamps") {
    VStack(spacing: 20) {
        RubberStamp(text: "URGENT", stampType: .urgent, size: .large)
        RubberStamp(text: "CLASSIFIED", stampType: .classified)
        RubberStamp(text: "TOP SECRET", stampType: .topSecret, rotation: -8)
        RubberStamp(text: "EXECUTED", stampType: .executed, size: .large)
        RubberStamp(text: "APPROVED", stampType: .approved, rotation: -5)
    }
    .padding(40)
    .background(ColdWarTheme.shared.agedPaper)
}

#Preview("Stat Displays") {
    HStack(spacing: 12) {
        StatDisplayBox(label: "Rations", value: "+20", icon: "shippingbox.fill", status: .positive)
        StatDisplayBox(label: "Morale", value: "-15", icon: "person.3.fill", status: .critical)
        StatDisplayBox(label: "Budget", value: "0", icon: "dollarsign.circle.fill", status: .neutral)
    }
    .padding()
    .background(ColdWarTheme.shared.agedPaper)
}

#Preview("Character Quote") {
    CharacterQuoteCard(
        name: "Gen. Carter",
        quote: "Efficient work, comrade. The state appreciates your decisiveness.",
        sentiment: .positive
    )
    .padding()
    .background(ColdWarTheme.shared.agedPaper)
}

#Preview("Briefing Paper") {
    BriefingPaperHeader(
        date: "12 OCT 1952",
        subject: "Sector 7 Unrest",
        from: "STRATEGIC COMMAND",
        classification: "URGENT",
        documentId: "ID:984-29-A"
    )
}

#Preview("Dossier Photo") {
    HStack(spacing: 20) {
        FiftiesDossierPhoto(name: "Gen. Wallace", title: "DIRECTOR")
        FiftiesDossierPhoto(name: "Col. Edwards", title: "SECURITY", showStaple: false)
    }
    .padding()
    .background(ColdWarTheme.shared.agedPaper)
}
