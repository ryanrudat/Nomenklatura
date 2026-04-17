//
//  LockToast.swift
//  Nomenklatura
//
//  Transient feedback shown when the player taps a locked section.
//  Brutalist stamp-style — reinforces that gating is a deliberate
//  game state, not a broken UI.
//

import SwiftUI

struct LockToast: View {
    let message: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.sovietRed)

            Text(message.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkBlack)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.parchmentDark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.sovietRed, lineWidth: 1.5)
        )
        .shadow(color: theme.inkBlack.opacity(0.2), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack {
        LockToast(message: "Trade — Requires Economic Access 4 (you have 2)")
            .padding(.top, 50)
        Spacer()
    }
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
