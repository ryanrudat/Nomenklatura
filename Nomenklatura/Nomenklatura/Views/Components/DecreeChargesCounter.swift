//
//  DecreeChargesCounter.swift
//  Nomenklatura
//
//  Small "DECREES n/cap" pill surfaced on every UI that can spend a
//  Chairman's decree charge. The Chairman shares one decree pool
//  across four surfaces (SecurityPortal, DirectivePhase, Crisis,
//  EmergencyDecree); without this counter, the player can strand
//  themselves by spending every charge in one menu before realizing
//  none remain for another. The cap and regen cadence scale with
//  ChairmanshipTier (cap 3→8, regen every 50→18 turns).
//
//  Aesthetic mirrors the inline charge badge embedded in the EXECUTE BY
//  DECREE buttons: gold seal icon, monospaced tracking, parchment-dark fill.
//

import SwiftUI

struct DecreeChargesCounter: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    /// When true, low-charge state (0 or 1 remaining) drains the pill
    /// toward red so the player notices it across the screen. Default
    /// on — call sites can opt out for already-loud contexts.
    var emphasizeLowCharges: Bool = true

    private var charges: Int { game.decreeChargesRemaining }
    private var cap: Int { game.chairmanshipTier.decreeMax }

    private var tint: Color {
        guard emphasizeLowCharges else { return theme.accentGold }
        switch charges {
        case 0: return theme.sovietRed
        case 1: return theme.accentGold        // last-charge — still gold but warning copy fires in alerts
        default: return theme.accentGold
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "seal.fill")
                .font(.system(size: 11))
                .foregroundColor(tint.opacity(0.85))

            Text("DECREES \(charges)/\(cap)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundColor(tint.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(theme.parchmentDark.opacity(0.6))
        )
        .overlay(
            Capsule().stroke(tint.opacity(0.35), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Decree charges remaining")
        .accessibilityValue("\(charges) of \(cap)")
    }
}

// MARK: - Last-charge warning helper

/// Returns the "last charge" warning line to append to a confirmation
/// alert when the player is about to spend their final decree charge.
/// Centralised here so all four surfaces show identical phrasing.
///
/// If `lastDecreeRegenTurn` is set (>0), we compute the precise turn
/// the next charge will regenerate; otherwise we fall back to the
/// "in N turns" copy. The interval is tier-scaled (50 → 18 turns) and
/// must mirror GameEngine's regenerateDecreeCharges step — both read
/// ChairmanshipTier.decreeRegenInterval.
func decreeLastChargeWarning(for game: Game) -> String? {
    guard game.decreeChargesRemaining == 1 else { return nil }
    let interval = game.chairmanshipTier.decreeRegenInterval
    if game.lastDecreeRegenTurn > 0 {
        let nextTurn = game.lastDecreeRegenTurn + interval
        return "\u{26A0} This is your last decree charge. Next regenerates around turn \(nextTurn)."
    } else {
        return "\u{26A0} This is your last decree charge. Next regenerates in \(interval) turns."
    }
}

#Preview("DecreeChargesCounter") {
    VStack(spacing: 12) {
        // 3 charges (default)
        DecreeChargesCounter(game: previewGame(charges: 3))
        // 1 charge — last-charge state
        DecreeChargesCounter(game: previewGame(charges: 1))
        // 0 charges — depleted
        DecreeChargesCounter(game: previewGame(charges: 0))
    }
    .padding()
    .background(Color(hex: "F5EFDF"))
    .environment(\.theme, ColdWarTheme())
}

private func previewGame(charges: Int) -> Game {
    let g = Game(campaignId: "coldwar")
    g.decreeChargesRemaining = charges
    return g
}
