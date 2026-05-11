//
//  BureauEmblem.swift
//  Nomenklatura
//
//  Visual emblems and seals for the three core bureaus.
//  Soviet-inspired official government aesthetics.
//

import SwiftUI

// MARK: - Bureau Emblem

/// Visual emblem/seal for a bureau - used in credentials, cards, and headers
struct BureauEmblem: View {
    let bureau: ExpandedCareerTrack
    let size: EmblemSize

    enum EmblemSize {
        case small   // 40pt - for inline use
        case medium  // 60pt - for cards
        case large   // 90pt - for headers/credentials

        var dimension: CGFloat {
            switch self {
            case .small: return 40
            case .medium: return 60
            case .large: return 90
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 26
            case .large: return 38
            }
        }

        var ringWidth: CGFloat {
            switch self {
            case .small: return 2
            case .medium: return 3
            case .large: return 4
            }
        }

        var starSize: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 12
            }
        }
    }

    private var primaryColor: Color {
        ColdWarTheme.shared.bureauPrimary(for: bureau)
    }

    private var accentColor: Color {
        ColdWarTheme.shared.bureauAccent(for: bureau)
    }

    var body: some View {
        ZStack {
            // Outer decorative ring
            Circle()
                .stroke(primaryColor.opacity(0.3), lineWidth: size.ringWidth)
                .frame(width: size.dimension, height: size.dimension)

            // Middle ring with pattern
            Circle()
                .stroke(primaryColor, lineWidth: size.ringWidth * 0.7)
                .frame(width: size.dimension - size.ringWidth * 3, height: size.dimension - size.ringWidth * 3)

            // Inner filled circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [primaryColor.opacity(0.15), primaryColor.opacity(0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.dimension / 2
                    )
                )
                .frame(width: size.dimension - size.ringWidth * 6, height: size.dimension - size.ringWidth * 6)

            // Bureau-specific emblem content
            bureauEmblemContent

            // Decorative stars (top)
            if size != .small {
                starsDecoration
            }
        }
        .frame(width: size.dimension, height: size.dimension)
    }

    @ViewBuilder
    private var bureauEmblemContent: some View {
        switch bureau {
        case .securityServices:
            securityEmblem
        case .economicPlanning:
            economicEmblem
        case .partyApparatus:
            partyEmblem
        default:
            genericEmblem
        }
    }

    // MARK: - Security Services Emblem (Shield with eye)

    private var securityEmblem: some View {
        ZStack {
            // Shield background
            Image(systemName: "shield.fill")
                .font(.system(size: size.iconSize * 1.2, weight: .bold))
                .foregroundColor(primaryColor.opacity(0.2))

            // Eye icon
            Image(systemName: "eye.fill")
                .font(.system(size: size.iconSize * 0.7, weight: .semibold))
                .foregroundColor(primaryColor)
        }
    }

    // MARK: - Economic Planning Emblem (Gear with chart)

    private var economicEmblem: some View {
        ZStack {
            // Gear background
            Image(systemName: "gearshape.fill")
                .font(.system(size: size.iconSize * 1.1, weight: .bold))
                .foregroundColor(primaryColor.opacity(0.2))

            // Chart icon
            Image(systemName: "chart.bar.fill")
                .font(.system(size: size.iconSize * 0.6, weight: .semibold))
                .foregroundColor(primaryColor)
        }
    }

    // MARK: - Party Apparatus Emblem (Star with fist)

    private var partyEmblem: some View {
        ZStack {
            // Star background
            Image(systemName: "star.fill")
                .font(.system(size: size.iconSize * 1.2, weight: .bold))
                .foregroundColor(accentColor.opacity(0.3))

            // Raised fist or hammer
            Image(systemName: "hand.raised.fill")
                .font(.system(size: size.iconSize * 0.6, weight: .semibold))
                .foregroundColor(primaryColor)
        }
    }

    private var genericEmblem: some View {
        Image(systemName: "building.columns.fill")
            .font(.system(size: size.iconSize, weight: .semibold))
            .foregroundColor(primaryColor)
    }

    // MARK: - Decorative Stars

    private var starsDecoration: some View {
        VStack {
            HStack(spacing: size.starSize * 0.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: size.starSize))
                        .foregroundColor(accentColor)
                }
            }
            .offset(y: -size.dimension * 0.35)

            Spacer()
        }
        .frame(height: size.dimension)
    }
}

// MARK: - Bureau Stamp

/// Official-looking stamp for credentials and documents
struct BureauStamp: View {
    let text: String
    let color: Color
    let rotation: Double

    init(_ text: String, color: Color = .red, rotation: Double = -12) {
        self.text = text
        self.color = color
        self.rotation = rotation
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(2)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .stroke(color, lineWidth: 2)
            )
            .rotationEffect(.degrees(rotation))
            .opacity(0.8)
    }
}

// MARK: - Clearance Level Badge

/// Visual clearance level indicator
struct ClearanceBadge: View {
    let level: Int
    let maxLevel: Int
    let color: Color

    init(level: Int, maxLevel: Int = 8, color: Color = .red) {
        self.level = level
        self.maxLevel = maxLevel
        self.color = color
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...maxLevel, id: \.self) { i in
                Rectangle()
                    .fill(i <= level ? color : color.opacity(0.2))
                    .frame(width: 6, height: 12)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.05))
        .cornerRadius(2)
    }
}

// MARK: - Status Light

/// Visual status indicator light
struct StatusLight: View {
    let status: Status
    let size: CGFloat

    enum Status {
        case active, warning, critical, inactive

        var color: Color {
            switch self {
            case .active: return Color(hex: "22C55E")
            case .warning: return Color(hex: "F59E0B")
            case .critical: return Color(hex: "EF4444")
            case .inactive: return Color(hex: "6B7280")
            }
        }
    }

    init(_ status: Status, size: CGFloat = 8) {
        self.status = status
        self.size = size
    }

    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(status.color.opacity(0.3))
                .frame(width: size * 2, height: size * 2)
                .blur(radius: size * 0.5)

            // Main light
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)

            // Highlight
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: size * 0.4, height: size * 0.4)
                .offset(x: -size * 0.15, y: -size * 0.15)
        }
    }
}

// MARK: - Circular Progress Gauge

/// Visual circular gauge for progress/stats
struct CircularGauge: View {
    let value: Double  // 0-100
    let label: String
    let color: Color
    let size: CGFloat

    init(value: Double, label: String, color: Color = .blue, size: CGFloat = 60) {
        self.value = value
        self.label = label
        self.color = color
        self.size = size
    }

    private var progress: Double {
        min(max(value / 100, 0), 1)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background track
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: size * 0.1)
                    .frame(width: size, height: size)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                // Center value
                Text("\(Int(value))")
                    .font(.system(size: size * 0.28, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
            }

            // Label
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(ColdWarTheme.shared.carbonCopy)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        // Emblems
        HStack(spacing: 20) {
            BureauEmblem(bureau: .securityServices, size: .large)
            BureauEmblem(bureau: .economicPlanning, size: .large)
            BureauEmblem(bureau: .partyApparatus, size: .large)
        }

        // Stamps
        HStack(spacing: 20) {
            BureauStamp("AUTHORIZED", color: ColdWarTheme.shared.bureauPrimary(for: .securityServices))
            BureauStamp("APPROVED", color: ColdWarTheme.shared.bureauPrimary(for: .economicPlanning))
        }

        // Clearance
        ClearanceBadge(level: 5, color: ColdWarTheme.shared.bureauPrimary(for: .securityServices))

        // Status lights
        HStack(spacing: 20) {
            StatusLight(.active)
            StatusLight(.warning)
            StatusLight(.critical)
            StatusLight(.inactive)
        }

        // Gauges
        HStack(spacing: 20) {
            CircularGauge(value: 75, label: "Progress", color: ColdWarTheme.shared.bureauPrimary(for: .securityServices))
            CircularGauge(value: 45, label: "Success", color: ColdWarTheme.shared.bureauPrimary(for: .economicPlanning))
        }
    }
    .padding()
    .background(ColdWarTheme.shared.agedPaper)
}
