//
//  PersistentStatBar.swift
//  Nomenklatura
//
//  Phase 2.6: always-visible critical stats banner. The audit's
//  #4 UX issue was that treasury/stability/popular support live
//  buried in the Ledger tab — the player has to leave the active
//  Desk view to check them, breaking decision flow. This bar sticks
//  to the top of the Desk so the Chairman can always read the room.
//

import SwiftUI

struct PersistentStatBar: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            statCell(label: "TRES", value: game.treasury, icon: "rublesign.circle.fill", critical: 25, low: 40)
            divider
            statCell(label: "STAB", value: game.stability, icon: "shield.fill", critical: 25, low: 40)
            divider
            statCell(label: "POP", value: game.popularSupport, icon: "person.3.fill", critical: 30, low: 50)
            divider
            statCell(label: "MIL", value: game.militaryLoyalty, icon: "shield.checkered", critical: 30, low: 50)
            divider
            apCell
        }
        .padding(.vertical, 8)
        .background(theme.schemeCard)
        .overlay(
            Rectangle()
                .fill(theme.sovietRed)
                .frame(height: 2),
            alignment: .top
        )
    }

    private func statCell(label: String, value: Int, icon: String, critical: Int, low: Int) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(color(for: value, critical: critical, low: low))
                Text(label)
                    .font(.system(size: 8, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.schemeText.opacity(0.6))
            }
            Text("\(value)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(color(for: value, critical: critical, low: low))
        }
        .frame(maxWidth: .infinity)
    }

    private var apCell: some View {
        VStack(spacing: 2) {
            Text("AP")
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(theme.accentGold.opacity(0.7))
            Text("\(game.actionPoints)")
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(theme.accentGold)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.schemeBorder)
            .frame(width: 1, height: 24)
    }

    private func color(for value: Int, critical: Int, low: Int) -> Color {
        if value <= critical { return theme.sovietRed }
        if value <= low      { return theme.warningAmber }
        return theme.successGreen
    }
}
