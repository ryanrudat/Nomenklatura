//
//  FiftiesStyleComponents.swift
//  Nomenklatura
//
//  1950s Cold War era styling components - typewriter documents, rubber stamps,
//  aged paper textures, and government dossier aesthetics
//

import SwiftUI

// MARK: - 1950s Color Palette

struct FiftiesColors {
    // Paper tones
    static let agedPaper = Color(hex: "F5ECD7")        // Yellowed paper
    static let freshPaper = Color(hex: "F8F5EC")       // Clean paper
    static let cardstock = Color(hex: "EDE8D9")        // Heavier card stock
    static let manillaFolder = Color(hex: "E8D4A8")    // File folder tan

    // Ink tones
    static let typewriterInk = Color(hex: "1C1C1C")    // Fresh ribbon ink
    static let fadedInk = Color(hex: "3D3D3D")         // Worn ribbon ink
    static let carbonCopy = Color(hex: "5A5A5A")       // Carbon paper gray

    // Stamp colors
    static let stampRed = Color(hex: "B82E2E")         // Official red stamp
    static let stampRedDark = Color(hex: "8B0000")     // Darker red stamp
    static let urgentRed = Color(hex: "C41E3A")        // Bright urgent red
    static let approvedGreen = Color(hex: "2D5A27")    // Approved stamp green
    static let deniedRed = Color(hex: "8B0000")        // Denied stamp

    // Accent colors
    static let brassGold = Color(hex: "B8860B")        // Brass fixtures
    static let steelGray = Color(hex: "708090")        // Steel/metal
    static let leatherBrown = Color(hex: "5C4033")     // Leather binding
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
            case .urgent: return FiftiesColors.urgentRed
            case .classified: return FiftiesColors.stampRed
            case .confidential: return FiftiesColors.stampRedDark
            case .topSecret: return FiftiesColors.stampRedDark
            case .approved: return FiftiesColors.approvedGreen
            case .denied: return FiftiesColors.deniedRed
            case .executed: return FiftiesColors.stampRedDark
            case .restricted: return FiftiesColors.stampRed
            case .priority: return FiftiesColors.urgentRed
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
                            .fill(FiftiesColors.agedPaper)
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
    var color: Color = FiftiesColors.stampRed
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
                .fill(FiftiesColors.agedPaper)
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
                        .foregroundColor(FiftiesColors.fadedInk)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Date line
            if let date = date {
                Text(date)
                    .font(.custom("AmericanTypewriter", size: 11))
                    .foregroundColor(FiftiesColors.typewriterInk)
                    .padding(.horizontal, 20)
            }

            // Title
            Text(title.uppercased())
                .font(.custom("AmericanTypewriter", size: 16))
                .fontWeight(.bold)
                .foregroundColor(FiftiesColors.typewriterInk)
                .tracking(1)
                .padding(.horizontal, 20)

            // Subtitle
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.custom("AmericanTypewriter", size: 12))
                    .foregroundColor(FiftiesColors.fadedInk)
                    .padding(.horizontal, 20)
            }

            // Divider line (typewriter style)
            Rectangle()
                .fill(FiftiesColors.typewriterInk)
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
            FiftiesColors.agedPaper

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
    var valueColor: Color = FiftiesColors.typewriterInk
    var status: StatStatus = .neutral

    enum StatStatus {
        case positive, negative, neutral, critical

        var backgroundColor: Color {
            switch self {
            case .positive: return Color(hex: "D4EDDA").opacity(0.3)
            case .negative: return Color(hex: "F8D7DA").opacity(0.3)
            case .critical: return Color(hex: "F8D7DA").opacity(0.5)
            case .neutral: return FiftiesColors.cardstock
            }
        }

        var accentColor: Color {
            switch self {
            case .positive: return Color(hex: "28A745")
            case .negative: return FiftiesColors.stampRed
            case .critical: return FiftiesColors.urgentRed
            case .neutral: return FiftiesColors.typewriterInk
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
                        .foregroundColor(FiftiesColors.fadedInk)
                }
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .default))
                    .fontWeight(.semibold)
                    .tracking(1)
                    .foregroundColor(FiftiesColors.fadedInk)
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
                .foregroundColor(FiftiesColors.fadedInk)

            Text(change >= 0 ? "+\(change)" : "\(change)")
                .font(.custom("AmericanTypewriter", size: 16))
                .fontWeight(.bold)
                .foregroundColor(change >= 0 ? Color(hex: "28A745") : FiftiesColors.stampRed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(FiftiesColors.cardstock)
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
                            .fill(FiftiesColors.agedPaper.opacity(0.3))
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
                    .foregroundColor(FiftiesColors.fadedInk)
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
                .fill(FiftiesColors.steelGray)
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
    var color: Color = FiftiesColors.manillaFolder

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
                .foregroundColor(isActive ? FiftiesColors.leatherBrown : FiftiesColors.fadedInk)
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
            case .negative: return FiftiesColors.stampRed
            case .neutral: return FiftiesColors.fadedInk
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
                        .foregroundColor(FiftiesColors.typewriterInk)

                    Spacer()

                    Image(systemName: sentiment.icon)
                        .font(.system(size: 12))
                        .foregroundColor(sentiment.color)
                }

                // Quote
                Text("\"\(quote)\"")
                    .font(.custom("AmericanTypewriter", size: 12))
                    .italic()
                    .foregroundColor(FiftiesColors.fadedInk)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
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
                        .foregroundColor(FiftiesColors.fadedInk)
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
                .fill(FiftiesColors.typewriterInk)
                .frame(height: 2)
                .padding(.top, 12)
        }
        .padding(16)
        .background(FiftiesColors.agedPaper)
    }

    private func headerField(label: String, value: String, bold: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.custom("AmericanTypewriter", size: 11))
                .foregroundColor(FiftiesColors.fadedInk)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.custom("AmericanTypewriter", size: 11))
                .fontWeight(bold ? .bold : .regular)
                .foregroundColor(FiftiesColors.typewriterInk)
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
            case .primary: return FiftiesColors.stampRed
            case .secondary: return FiftiesColors.steelGray
            case .danger: return FiftiesColors.stampRedDark
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
    .background(FiftiesColors.agedPaper)
}

#Preview("Stat Displays") {
    HStack(spacing: 12) {
        StatDisplayBox(label: "Rations", value: "+20", icon: "shippingbox.fill", status: .positive)
        StatDisplayBox(label: "Morale", value: "-15", icon: "person.3.fill", status: .critical)
        StatDisplayBox(label: "Budget", value: "0", icon: "dollarsign.circle.fill", status: .neutral)
    }
    .padding()
    .background(FiftiesColors.agedPaper)
}

#Preview("Character Quote") {
    CharacterQuoteCard(
        name: "Gen. Carter",
        quote: "Efficient work, comrade. The state appreciates your decisiveness.",
        sentiment: .positive
    )
    .padding()
    .background(FiftiesColors.agedPaper)
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
    .background(FiftiesColors.agedPaper)
}
