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

// MARK: - Bundle Extension for Version

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
