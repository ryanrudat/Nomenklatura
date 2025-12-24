//
//  StitchDesignComponents.swift
//  Nomenklatura
//
//  Reusable UI components inspired by Stitch designs
//  Soviet bureaucratic aesthetic with modern polish
//

import SwiftUI

// MARK: - Design System Colors

enum StitchColors {
    // Paper & Backgrounds
    static let paper = Color(hex: "F5F0E1")
    static let paperWarm = Color(hex: "FDFBF7")
    static let paperDark = Color(hex: "E8E8E8")

    // Ink & Text
    static let ink = Color(hex: "141414")
    static let inkFaded = Color(hex: "4A4A4A")
    static let inkLight = Color(hex: "757575")

    // Accents
    static let stampRed = Color(hex: "B91C1C")
    static let sovietRed = Color(hex: "B82E2E")
    static let gold = Color(hex: "C4A962")

    // Dark Mode
    static let darkBg = Color(hex: "1A1A1A")
    static let darkCard = Color(hex: "2A2725")
    static let darkBorder = Color(hex: "333333")
    static let lightText = Color(hex: "E5E5E5")

    // Status Colors
    static let positive = Color(hex: "15803D")  // Green-700
    static let warning = Color(hex: "D97706")   // Amber-600
    static let danger = Color(hex: "DC2626")    // Red-600
}

// MARK: - Circular Stat Gauge (Stitch Dossier Style)

struct CircularStatGauge: View {
    let label: String
    let value: Int
    let maxValue: Int
    var showDanger: Bool = false

    private var percentage: Double {
        Double(value) / Double(maxValue)
    }

    private var strokeColor: Color {
        if showDanger && value < 40 {
            return StitchColors.stampRed
        }
        return StitchColors.ink
    }

    var body: some View {
        VStack(spacing: 4) {
            // Label badge
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(StitchColors.ink)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(StitchColors.paper)
                .overlay(
                    Rectangle()
                        .stroke(StitchColors.ink, lineWidth: 1)
                )

            // Circular gauge
            ZStack {
                // Background track
                Circle()
                    .stroke(StitchColors.ink.opacity(0.1), lineWidth: 4)

                // Progress arc
                Circle()
                    .trim(from: 0, to: percentage)
                    .stroke(strokeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: percentage)

                // Value text
                Text("\(value)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(StitchColors.ink)
            }
            .frame(width: 48, height: 48)
        }
        .padding(12)
        .background(StitchColors.paperDark)
        .overlay(
            Rectangle()
                .stroke(StitchColors.ink, lineWidth: 1)
        )
    }
}

// MARK: - Redacted Text (Stitch Dossier Style)

struct RedactedText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(StitchColors.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(StitchColors.ink.opacity(0.9))
            .cornerRadius(2)
    }
}

// View modifier for inline redaction
struct RedactedModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundColor(StitchColors.ink)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(StitchColors.ink.opacity(0.9))
            .cornerRadius(2)
    }
}

extension View {
    func redacted() -> some View {
        modifier(RedactedModifier())
    }
}

// MARK: - Classification Stamp (Stitch Style)

struct ClassificationStamp: View {
    enum Level: String {
        case confidential = "CONFIDENTIAL"
        case secret = "SECRET"
        case topSecret = "TOP SECRET"

        var color: Color {
            switch self {
            case .confidential: return StitchColors.inkFaded
            case .secret: return StitchColors.sovietRed
            case .topSecret: return StitchColors.stampRed
            }
        }
    }

    let level: Level
    var rotation: Double = 12

    var body: some View {
        Text(level.rawValue)
            .font(.system(size: 16, weight: .black))
            .tracking(2)
            .foregroundColor(level.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                Rectangle()
                    .stroke(level.color, lineWidth: 3)
            )
            .rotationEffect(.degrees(rotation))
            .opacity(0.85)
    }
}

// MARK: - Paper Card (Stitch Style)

struct PaperCard<Content: View>: View {
    let content: Content
    var hasClip: Bool = false
    var rotation: Double = 0

    init(hasClip: Bool = false, rotation: Double = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasClip = hasClip
        self.rotation = rotation
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Paper clip decoration
            if hasClip {
                Image(systemName: "paperclip")
                    .font(.system(size: 32))
                    .foregroundColor(StitchColors.inkLight)
                    .rotationEffect(.degrees(15))
                    .offset(x: 80, y: -8)
            }

            // Card content
            VStack(alignment: .leading) {
                content
            }
            .padding(16)
            .background(StitchColors.paperWarm)
            .overlay(
                Rectangle()
                    .stroke(StitchColors.ink.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Industrial Button (Stitch Style)

struct IndustrialButton: View {
    enum Style {
        case primary
        case secondary
        case danger
    }

    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void

    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                }
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: style == .secondary ? 2 : 0)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return StitchColors.ink
        case .secondary: return StitchColors.paper
        case .danger: return StitchColors.stampRed
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return StitchColors.lightText
        case .secondary: return StitchColors.ink
        case .danger: return .white
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return .clear
        case .secondary: return StitchColors.ink.opacity(0.3)
        case .danger: return .clear
        }
    }
}

// MARK: - Risk Assessment Bar (Stitch Action Card Style)

struct RiskAssessmentBar: View {
    let risk: Double // 0.0 to 1.0
    var label: String = "RISK ASSESSMENT"

    private var riskLevel: String {
        switch risk {
        case 0..<0.33: return "LOW RISK"
        case 0.33..<0.66: return "MODERATE"
        default: return "HIGH RISK"
        }
    }

    private var riskColor: Color {
        switch risk {
        case 0..<0.33: return StitchColors.positive
        case 0.33..<0.66: return StitchColors.warning
        default: return StitchColors.danger
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(StitchColors.inkFaded)
                Spacer()
                Text(riskLevel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(riskColor)
            }

            // Segmented bar
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let isActive = Double(index) / 3.0 < risk
                    Rectangle()
                        .fill(isActive ? segmentColor(for: index) : StitchColors.ink.opacity(0.15))
                        .frame(height: 8)
                        .cornerRadius(index == 0 ? 2 : (index == 2 ? 2 : 0), corners: cornerSet(for: index))
                }
            }

            // Failure probability
            Text("Failure probability: \(Int(risk * 100))%")
                .font(.system(size: 10))
                .italic()
                .foregroundColor(StitchColors.inkLight)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func segmentColor(for index: Int) -> Color {
        switch index {
        case 0: return StitchColors.ink.opacity(0.3)
        case 1: return StitchColors.ink.opacity(0.3)
        case 2: return StitchColors.danger
        default: return StitchColors.ink.opacity(0.3)
        }
    }

    private func cornerSet(for index: Int) -> UIRectCorner {
        switch index {
        case 0: return [.topLeft, .bottomLeft]
        case 2: return [.topRight, .bottomRight]
        default: return []
        }
    }
}

// Helper for corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Severity Badge (Stitch Briefing Style)

struct SeverityBadge: View {
    enum Level: String {
        case minor = "MINOR"
        case moderate = "MODERATE"
        case significant = "SIGNIFICANT"
        case major = "MAJOR"
        case critical = "CRITICAL"

        var color: Color {
            switch self {
            case .minor: return StitchColors.inkLight
            case .moderate: return StitchColors.warning
            case .significant: return StitchColors.gold
            case .major: return Color.orange
            case .critical: return StitchColors.stampRed
            }
        }
    }

    let level: Level

    var body: some View {
        Text(level.rawValue)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.5)
            .foregroundColor(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.15))
            .overlay(
                Rectangle()
                    .stroke(level.color.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Outcome Chip (Stitch Action Card Style)

struct OutcomeChip: View {
    let icon: String
    let text: String
    let isPositive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
            Text(text.uppercased())
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(isPositive ? StitchColors.positive : StitchColors.danger)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            (isPositive ? Color.green : Color.red).opacity(0.08)
        )
        .overlay(
            Rectangle()
                .stroke((isPositive ? Color.green : Color.red).opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - File Header (Stitch Dossier Style)

struct FileHeader: View {
    let fileNumber: String
    let classification: ClassificationStamp.Level?

    var body: some View {
        HStack {
            Text("FILE #\(fileNumber)")
                .font(.system(size: 16, weight: .black))
                .tracking(2)
                .foregroundColor(StitchColors.ink)

            Spacer()

            if let classification = classification {
                Text(classification.rawValue)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(classification.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        Rectangle()
                            .stroke(classification.color, lineWidth: 1)
                    )
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchColors.ink.opacity(0.2))
                .frame(height: 1)
        }
    }
}

// MARK: - Photo Frame (Stitch Dossier Style)

struct DossierPhotoFrame<Content: View>: View {
    let content: Content
    var levelBadge: Int?

    init(levelBadge: Int? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.levelBadge = levelBadge
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Photo container with polaroid-style border
            VStack(spacing: 0) {
                content
                    .frame(width: 96, height: 128)
                    .grayscale(1.0)
                    .contrast(1.25)
            }
            .padding(4)
            .background(.white)
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            .rotationEffect(.degrees(-1))

            // Level badge
            if let level = levelBadge {
                Text("LEVEL \(level)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(StitchColors.stampRed)
                    .rotationEffect(.degrees(-5))
                    .offset(x: 8, y: 8)
            }
        }
    }
}

// MARK: - Tab Bar (Stitch Dossier Style)

struct StitchTabBar: View {
    let tabs: [String]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = index
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(tab.uppercased())
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundColor(index == selectedIndex ? StitchColors.ink : StitchColors.inkLight)
                            .padding(.vertical, 12)

                        Rectangle()
                            .fill(index == selectedIndex ? StitchColors.ink : Color.clear)
                            .frame(height: 3)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .background(StitchColors.paper)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(StitchColors.ink.opacity(0.15))
                .frame(height: 2)
        }
    }
}

// MARK: - Previews

#Preview("Circular Gauges") {
    HStack(spacing: 12) {
        CircularStatGauge(label: "Loyalty", value: 85, maxValue: 100)
        CircularStatGauge(label: "Ambition", value: 40, maxValue: 100, showDanger: true)
        CircularStatGauge(label: "Skill", value: 92, maxValue: 100)
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Classification Stamps") {
    VStack(spacing: 20) {
        ClassificationStamp(level: .confidential)
        ClassificationStamp(level: .secret, rotation: -8)
        ClassificationStamp(level: .topSecret, rotation: 15)
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Buttons") {
    VStack(spacing: 12) {
        IndustrialButton("Execute Order", icon: "checkmark", style: .primary) {}
        IndustrialButton("Dismiss", icon: "xmark", style: .secondary) {}
        IndustrialButton("Denounce", icon: "exclamationmark.triangle", style: .danger) {}
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Risk Bar") {
    VStack(spacing: 20) {
        RiskAssessmentBar(risk: 0.25)
        RiskAssessmentBar(risk: 0.55)
        RiskAssessmentBar(risk: 0.75)
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Severity Badges") {
    HStack(spacing: 8) {
        SeverityBadge(level: .minor)
        SeverityBadge(level: .moderate)
        SeverityBadge(level: .critical)
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Outcome Chips") {
    HStack(spacing: 8) {
        OutcomeChip(icon: "heart.fill", text: "+20 Loyalty", isPositive: true)
        OutcomeChip(icon: "exclamationmark.triangle", text: "-15 Stability", isPositive: false)
    }
    .padding()
    .background(StitchColors.paper)
}

#Preview("Tab Bar") {
    @Previewable @State var selectedTab = 0
    StitchTabBar(tabs: ["Bio", "Intel", "Relations", "Assets"], selectedIndex: $selectedTab)
}
