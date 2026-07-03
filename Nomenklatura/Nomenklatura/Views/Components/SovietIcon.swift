//
//  SovietIcon.swift
//  Nomenklatura
//
//  Unified iconography system. Maps semantic names (security, party,
//  economy, …) to SF Symbol compositions with Communist-flavored bases
//  and optional red-star overlays for Constructivist accent on dramatic
//  moments (achievements, succession, headers).
//
//  Why this exists: generic iOS symbols (building.columns, globe,
//  gearshape) read as "iPhone app." Pivoting to semantically-charged
//  symbols (hammer for labor, book.closed for ideology, eye for the
//  surveillance state) makes the app read as "Communist state apparatus"
//  within seconds of opening it.
//

import SwiftUI

struct SovietIcon: View {
    let kind: Kind
    var size: CGFloat = 20
    var showStar: Bool = false
    @Environment(\.theme) var theme

    enum Kind {
        // Top-level navigation
        case desk
        case ledger
        case dossier
        case codex
        case economy

        // Headers / sheets
        case menu
        case world
        case congress

        // Bureaus
        case security
        case military
        case party
        case ministry
        case diplomacy

        // Domain icons
        case planning      // Five-Year Plan
        case treasury
        case industry      // hammer
        case agriculture   // wheat
        case state         // flag
        case revolution    // flame / fist
        case ideology      // book

        var sfSymbol: String {
            switch self {
            // Top-level — chosen for political resonance over iOS conventions
            case .desk:        return "tray.full.fill"        // In-tray of state papers
            case .ledger:      return "chart.line.flattrend.xyaxis"
            case .dossier:     return "person.text.rectangle.fill"  // Official dossier card
            case .codex:       return "book.closed.fill"      // Encyclopedia / manifesto
            case .economy:     return "hammer.fill"           // Labor / industry — iconic

            // Headers / sheets
            case .menu:        return "gearshape.fill"
            case .world:       return "globe.europe.africa.fill"
            case .congress:    return "building.columns.fill"

            // Bureaus
            case .security:    return "eye.fill"               // Surveillance state
            case .military:    return "shield.lefthalf.filled"
            case .party:       return "flag.fill"
            case .ministry:    return "building.columns.fill"
            case .diplomacy:   return "globe.europe.africa.fill"

            // Domain
            case .planning:    return "calendar.badge.checkmark"
            case .treasury:    return "dollarsign.circle.fill"
            case .industry:    return "hammer.fill"
            case .agriculture: return "leaf.fill"
            case .state:       return "flag.fill"
            case .revolution:  return "flame.fill"
            case .ideology:    return "book.closed.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: kind.sfSymbol)
                .font(.system(size: size))

            if showStar {
                RedStarBadge(size: size * 0.45)
                    .offset(x: size * 0.18, y: -size * 0.18)
            }
        }
    }
}

/// Small five-pointed red star with thin border. Used as a Constructivist
/// accent overlay on icons in dramatic contexts (state honors, achievements,
/// succession notifications).
struct RedStarBadge: View {
    var size: CGFloat = 12
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.parchmentDark)
                .frame(width: size * 1.2, height: size * 1.2)

            Image(systemName: "star.fill")
                .font(.system(size: size, weight: .black))
                .foregroundColor(theme.sovietRed)
        }
    }
}

#Preview("Soviet Icons") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Text("TAB BAR ICONS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)

            HStack(spacing: 30) {
                ForEach([SovietIcon.Kind.desk, .ledger, .dossier, .codex, .economy], id: \.self) { kind in
                    VStack {
                        SovietIcon(kind: kind, size: 24)
                        Text(String(describing: kind).uppercased())
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }

            Divider()

            Text("BUREAU ICONS")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)

            HStack(spacing: 30) {
                ForEach([SovietIcon.Kind.security, .military, .party, .ministry, .diplomacy], id: \.self) { kind in
                    VStack {
                        SovietIcon(kind: kind, size: 24)
                        Text(String(describing: kind).uppercased())
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }

            Divider()

            Text("WITH RED STAR OVERLAY (DRAMATIC MOMENTS)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2)

            HStack(spacing: 30) {
                ForEach([SovietIcon.Kind.party, .state, .revolution, .ideology], id: \.self) { kind in
                    VStack {
                        SovietIcon(kind: kind, size: 32, showStar: true)
                        Text(String(describing: kind).uppercased())
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
        }
        .padding(20)
    }
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}

extension SovietIcon.Kind: Hashable {}
