//
//  Theme.swift
//  Nomenklatura
//
//  Campaign-aware theming system
//

import SwiftUI
import Combine

// MARK: - Campaign Theme Protocol

protocol CampaignTheme {
    var id: String { get }

    // Colors
    var parchment: Color { get }
    var parchmentDark: Color { get }
    var inkBlack: Color { get }
    var inkGray: Color { get }
    var inkLight: Color { get }
    var borderTan: Color { get }
    var stampRed: Color { get }
    var schemeDark: Color { get }
    var schemeCard: Color { get }
    var schemeBorder: Color { get }
    var schemeText: Color { get }
    var accentGold: Color { get }

    // Soviet accent colors
    var sovietRed: Color { get }
    var heroRed: Color { get }
    var bronzeGold: Color { get }
    var concreteGray: Color { get }
    var steelBlue: Color { get }

    // Semantic palette (state colors)
    var paperGray: Color { get }
    var successGreen: Color { get }
    var warningAmber: Color { get }
    var dangerRed: Color { get }

    // Document / 1950s aesthetic palette (was FiftiesColors)
    var agedPaper: Color { get }
    var freshPaper: Color { get }
    var cardstock: Color { get }
    var manillaFolder: Color { get }
    var carbonCopy: Color { get }
    var stampRedDark: Color { get }
    var urgentRed: Color { get }
    var approvedGreen: Color { get }
    var steelGray: Color { get }
    var leatherBrown: Color { get }

    // Typography
    var headerFont: Font { get }
    var headerFontLarge: Font { get }
    var heroFont: Font { get }
    var bodyFont: Font { get }
    var bodyFontSmall: Font { get }
    var narrativeFont: Font { get }
    var narrativeFontLarge: Font { get }
    var labelFont: Font { get }
    var tagFont: Font { get }
    var statFont: Font { get }
    var stampFont: Font { get }

    // Spacing scale (Phase 0 design tokens — Phase 2 will migrate hardcoded values)
    var spacingXS: CGFloat { get }
    var spacingSM: CGFloat { get }
    var spacingBase: CGFloat { get }
    var spacingMD: CGFloat { get }
    var spacingLG: CGFloat { get }
    var spacingXL: CGFloat { get }
    var spacing2XL: CGFloat { get }

    // Corner radius — kept small for brutalist Soviet aesthetic
    var cornerRadiusSmall: CGFloat { get }
    var cornerRadiusBase: CGFloat { get }
    var cornerRadiusLarge: CGFloat { get }

    // Border widths
    var borderHairline: CGFloat { get }
    var borderStandard: CGFloat { get }
    var borderHeavy: CGFloat { get }

    // Shadow tokens
    var shadowSubtle: ShadowToken { get }
    var shadowDocument: ShadowToken { get }
}

struct ShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Cold War Theme (Soviet Brutalist)

struct ColdWarTheme: CampaignTheme {
    let id = "coldwar"

    // Colors - Document/Light Mode (Stitch-refined)
    let parchment = Color(hex: "F5F0E1")       // Newsprint paper (Stitch)
    let parchmentDark = Color(hex: "FDFBF7")   // Warmer paper for cards (Stitch)
    let inkBlack = Color(hex: "141414")        // Deeper ink (Stitch)
    let inkGray = Color(hex: "4A4A4A")         // Faded ink (Stitch)
    let inkLight = Color(hex: "757575")        // Light ink for labels
    let borderTan = Color(hex: "E0E0E0")       // Card borders (Stitch)
    let stampRed = Color(hex: "B91C1C")        // Stamp red (Stitch)

    // Soviet Reds - Bold Communist aesthetic (Stitch-refined)
    let sovietRed = Color(hex: "B82E2E")       // Primary accent red (Stitch)
    let heroRed = Color(hex: "B91C1C")         // Bright propaganda red (Stitch)

    // Colors - Dark Mode (Personal Actions)
    let schemeDark = Color(hex: "1A1A1A")      // Dark background (Stitch)
    let schemeCard = Color(hex: "2A2725")      // Dark card (Stitch)
    let schemeBorder = Color(hex: "333333")    // Dark border (Stitch)
    let schemeText = Color(hex: "E5E5E5")      // Light text on dark (Stitch)
    let accentGold = Color(hex: "C4A962")      // Soviet gold
    let bronzeGold = Color(hex: "B8860B")      // Secondary gold accent

    // Brutalist Tones
    let concreteGray = Color(hex: "4A4A4A")    // Brutalist concrete
    let steelBlue = Color(hex: "4682B4")       // Industrial accent

    // New Stitch Design Colors
    let woodDark = Color(hex: "241F1C")        // Wood desk background
    let paperWhite = Color(hex: "F5F4F0")      // Clean paper
    let stoneGray = Color(hex: "78716C")       // Stone-500 equivalent

    // Semantic palette (matches former StitchColors values for visual fidelity)
    let paperGray = Color(hex: "E8E8E8")       // Neutral panel/divider
    let successGreen = Color(hex: "15803D")    // Green-700, success/positive state
    let warningAmber = Color(hex: "D97706")    // Amber-600, warning state
    let dangerRed = Color(hex: "DC2626")       // Red-600, danger/error state

    // Document / 1950s aesthetic (matches former FiftiesColors values)
    let agedPaper = Color(hex: "F5ECD7")       // Yellowed paper
    let freshPaper = Color(hex: "F8F5EC")      // Clean paper
    let cardstock = Color(hex: "EDE8D9")       // Heavier card stock
    let manillaFolder = Color(hex: "E8D4A8")   // File folder tan
    let carbonCopy = Color(hex: "5A5A5A")      // Carbon paper gray
    let stampRedDark = Color(hex: "8B0000")    // Darker red stamp
    let urgentRed = Color(hex: "C41E3A")       // Bright urgent red
    let approvedGreen = Color(hex: "2D5A27")   // Approved stamp green
    let steelGray = Color(hex: "708090")       // Steel/metal
    let leatherBrown = Color(hex: "5C4033")    // Leather binding

    // Typography - Soviet Brutalist
    // System fonts with appropriate weights for headers
    // American Typewriter for body (bureaucratic documents)

    var headerFont: Font {
        .system(size: 20, weight: .bold, design: .default)
    }

    var headerFontLarge: Font {
        .system(size: 28, weight: .black, design: .default)
    }

    // Heroic font for dramatic moments
    var heroFont: Font {
        .system(size: 32, weight: .black, design: .default)
    }

    var bodyFont: Font {
        .custom("AmericanTypewriter", size: 15)
    }

    var bodyFontSmall: Font {
        .custom("AmericanTypewriter", size: 14)
    }

    // Narrative fonts - larger for atmosphere/immersion text
    var narrativeFont: Font {
        .custom("AmericanTypewriter", size: 17)
    }

    var narrativeFontLarge: Font {
        .custom("AmericanTypewriter", size: 19)
    }

    var labelFont: Font {
        .system(size: 12, weight: .medium, design: .default)
    }

    var tagFont: Font {
        .system(size: 10, weight: .semibold, design: .default)
    }

    var statFont: Font {
        .system(size: 14, weight: .bold, design: .monospaced)
    }

    var stampFont: Font {
        .system(size: 11, weight: .black, design: .default)
    }

    // Spacing
    var spacingXS: CGFloat { 2 }
    var spacingSM: CGFloat { 4 }
    var spacingBase: CGFloat { 8 }
    var spacingMD: CGFloat { 12 }
    var spacingLG: CGFloat { 16 }
    var spacingXL: CGFloat { 24 }
    var spacing2XL: CGFloat { 32 }

    // Corner radius
    var cornerRadiusSmall: CGFloat { 2 }
    var cornerRadiusBase: CGFloat { 4 }
    var cornerRadiusLarge: CGFloat { 8 }

    // Border widths
    var borderHairline: CGFloat { 0.5 }
    var borderStandard: CGFloat { 1 }
    var borderHeavy: CGFloat { 2 }

    // Shadows — warm tint for paper feel
    var shadowSubtle: ShadowToken {
        ShadowToken(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
    }

    var shadowDocument: ShadowToken {
        ShadowToken(color: Color(hex: "241F1C").opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Static Theme Accessor
//
// `ColdWarTheme.shared` is the single static instance used by code that
// can't access the @Environment(\.theme) injection (e.g., enum cases,
// model-layer code, deprecated wrappers like StitchColors). View code
// should still prefer @Environment(\.theme).

extension ColdWarTheme {
    static let shared = ColdWarTheme()
}

// MARK: - Bureau Helpers (replaces deprecated BureauColors struct)
//
// Per-bureau color + identity helpers. Previously lived in
// `struct BureauColors` in FiftiesStyleComponents.swift; migrated here so
// the call sites use `ColdWarTheme.shared.bureauX(for:)` consistently
// with the rest of the theme system. Logic preserved exactly.

extension ColdWarTheme {
    /// Primary color for a bureau (main accent/header).
    func bureauPrimary(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices: return stampRedDark
        case .economicPlanning: return approvedGreen
        case .partyApparatus:   return Color(hex: "CC0000")
        default:                return leatherBrown
        }
    }

    /// Secondary/accent color for a bureau.
    func bureauAccent(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices: return sovietRed
        case .economicPlanning: return Color(hex: "4A7C59")
        case .partyApparatus:   return Color(hex: "FFD700")
        default:                return bronzeGold
        }
    }

    /// Background color for bureau cards/sections.
    func bureauBackground(for bureau: ExpandedCareerTrack) -> Color {
        switch bureau {
        case .securityServices: return stampRedDark.opacity(0.08)
        case .economicPlanning: return approvedGreen.opacity(0.08)
        case .partyApparatus:   return Color(hex: "CC0000").opacity(0.08)
        default:                return cardstock
        }
    }

    /// SF Symbol name for a bureau.
    func bureauIcon(for bureau: ExpandedCareerTrack) -> String {
        bureau.iconName
    }

    /// Short code for a bureau (BPS, GOSPLAN, CC).
    func bureauCode(for bureau: ExpandedCareerTrack) -> String {
        bureau.shortName
    }

    /// Full display name for bureau header.
    func bureauHeaderTitle(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices: return "STATE PROTECTION BUREAU"
        case .economicPlanning: return "ECONOMIC PLANNING BUREAU"
        case .partyApparatus:   return "PARTY APPARATUS BUREAU"
        case .foreignAffairs:   return "FOREIGN AFFAIRS BUREAU"
        case .militaryPolitical: return "MILITARY-POLITICAL BUREAU"
        case .stateMinistry:    return "STATE MINISTRY BUREAU"
        case .regional:         return "REGIONAL ADMINISTRATION"
        case .shared:           return "GENERAL ADMINISTRATION"
        }
    }

    /// Subtitle for bureau identity.
    func bureauSubtitle(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices: return "Security Services Official"
        case .economicPlanning: return "State Plan Official"
        case .partyApparatus:   return "Central Committee Official"
        case .foreignAffairs:   return "Foreign Ministry Official"
        case .militaryPolitical: return "Military-Political Official"
        case .stateMinistry:    return "State Ministry Official"
        case .regional:         return "Regional Administrator"
        case .shared:           return "Government Official"
        }
    }
}

// MARK: - Theme Manager

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: CampaignTheme = ColdWarTheme()

    func setTheme(for campaignId: String) {
        switch campaignId {
        case "coldwar":
            currentTheme = ColdWarTheme()
        // Future campaigns:
        // case "crown":
        //     currentTheme = MedievalTheme()
        // case "ministry":
        //     currentTheme = PreWWITheme()
        // case "party":
        //     currentTheme = InterwarTheme()
        default:
            currentTheme = ColdWarTheme()
        }
    }
}

// MARK: - World Map Colors (Military Briefing Aesthetic)

extension Color {
    // Map - Political Alignments
    static let mapPSR = Color(hex: "8B0000")               // Deep red homeland
    static let mapPSRGold = Color(hex: "FFD700")           // Gold accents/border
    static let mapSocialistAlly = Color(hex: "CD5C5C")     // Indian red for USSR, Germany
    static let mapCapitalist = Color(hex: "4169E1")        // Royal blue for UK, Canada, France, Cuba
    static let mapFascist = Color(hex: "5D3A1A")           // Brown for Italy, Spain
    static let mapPacificHostile = Color(hex: "8B4513")    // Saddle brown for Japan
    static let mapNeutral = Color(hex: "696969")           // Dim gray for Mexico, China
    static let mapOccupied = Color(hex: "800000")          // Maroon for occupied territories

    // Map - Geography
    static let mapOcean = Color(hex: "1C3D5A")             // Dark navy blue
    static let mapOceanLight = Color(hex: "4A6B8A")        // Lighter ocean for contrast
    static let mapLand = Color(hex: "D4C4A8")              // Default land color
    static let mapGrid = Color(hex: "4A4A4A")              // Subtle grid lines
    static let mapBorder = Color(hex: "2F2F2F")            // Dark border between nations

    // Map - UI Elements
    static let mapLegendBg = Color(hex: "F5F0E1")          // Legend background
    static let mapStampRed = Color(hex: "8B0000")          // Classification stamps
    static let mapCompass = Color(hex: "B8860B")           // Compass rose gold
}

// MARK: - Shared Colors (Campaign-Independent)

extension Color {
    // Stat Colors
    static let statHigh = Color(hex: "28A745")
    static let statMedium = Color(hex: "FFC107")
    static let statLow = Color(hex: "DC3545")

    // Effect Tags
    static let effectPositiveBg = Color(hex: "D4EDDA")
    static let effectPositiveText = Color(hex: "155724")
    static let effectNegativeBg = Color(hex: "F8D7DA")
    static let effectNegativeText = Color(hex: "721C24")
    static let effectPersonalBg = Color(hex: "FFF3CD")
    static let effectPersonalText = Color(hex: "856404")

    // Stance Tags
    static let stanceAllyBg = Color(hex: "D4EDDA")
    static let stanceAllyText = Color(hex: "155724")
    static let stanceRivalBg = Color(hex: "F8D7DA")
    static let stanceRivalText = Color(hex: "721C24")
    static let stancePatronBg = Color(hex: "CCE5FF")
    static let stancePatronText = Color(hex: "004085")
    static let stanceNeutralBg = Color(hex: "E8E4D9")
    static let stanceNeutralText = Color(hex: "666666")
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Environment Key for Theme

struct ThemeKey: EnvironmentKey {
    static let defaultValue: CampaignTheme = ColdWarTheme()
}

extension EnvironmentValues {
    var theme: CampaignTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Typography Modifiers
//
// Phase 2 will migrate hardcoded font calls to these. Use these instead of
// raw Font calls so the entire app speaks one typographic voice:
//   .statNumber()      — monospaced digits for any numeric data
//   .documentHeader()  — all-caps spaced bold for card/section titles
//   .officialBody()    — typewriter serif for body text
//   .stampLabel()      — small bold all-caps for stamp/badge labels

extension View {
    func statNumber(size: CGFloat = 14) -> some View {
        self.font(.system(size: size, weight: .bold, design: .monospaced))
            .monospacedDigit()
    }

    func documentHeader(size: CGFloat = 14) -> some View {
        self.font(.system(size: size, weight: .heavy, design: .default))
            .textCase(.uppercase)
            .tracking(1.5)
    }

    func officialBody(size: CGFloat = 15) -> some View {
        self.font(.custom("AmericanTypewriter", size: size))
    }

    func stampLabel(size: CGFloat = 11) -> some View {
        self.font(.system(size: size, weight: .black, design: .default))
            .textCase(.uppercase)
            .tracking(2.0)
    }
}

// MARK: - Shadow Application Helper

extension View {
    func applyShadow(_ token: ShadowToken) -> some View {
        self.shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}

// MARK: - Bundle Extension for Version

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
