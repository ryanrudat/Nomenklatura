//
//  AdvisorNote.swift
//  Nomenklatura
//
//  The advisor guidance layer — Sasha, the Chairman's chief of staff,
//  explaining what a control does, what it costs, and where the ripples
//  land. Notes state honest numbers (the same constants the engine uses)
//  and honest tradeoffs; they never soften outcomes.
//
//  Guidance is ON by default and the player opts out in Settings. The
//  component reads the toggle itself, so call sites just drop a note in —
//  it renders nothing when guidance is off.
//

import SwiftUI

/// Global read of the guidance toggle for non-View call sites
/// (pre-commit confirmation gating).
enum AdvisorGuidance {
    static let storageKey = "settings.advisor.enabled"
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: storageKey) as? Bool ?? true
    }
}

struct AdvisorNote: View {
    let text: String
    @AppStorage(AdvisorGuidance.storageKey) private var advisorEnabled: Bool = true
    @Environment(\.theme) var theme

    var body: some View {
        if advisorEnabled {
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(theme.accentGold.opacity(0.7))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundColor(theme.inkBlack.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— SASHA, CHIEF OF STAFF")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
