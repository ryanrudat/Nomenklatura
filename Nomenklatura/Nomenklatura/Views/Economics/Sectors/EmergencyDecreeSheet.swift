//
//  EmergencyDecreeSheet.swift
//  Nomenklatura
//
//  Phase 3.8: presented when the player taps "EMERGENCY DECREES" on
//  a sector experiencing a supply shortfall. Lists all decrees with
//  available ones highlighted and locked ones explained.
//

import SwiftUI

struct EmergencyDecreeSheet: View {
    @Bindable var game: Game
    let onDismiss: () -> Void

    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var pendingDecree: EmergencyDecree? = nil
    @State private var showingLastChargeConfirm = false

    private var decrees: [(decree: EmergencyDecree, available: Bool)] {
        EmergencyDecreeService.shared.decreesWithAvailability(in: game)
    }

    private var hasCharges: Bool {
        game.decreeChargesRemaining > 0
    }

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    Text("The Apparatus is breaking. The Chairman may issue any of the following extraordinary measures. Each carries a political cost.")
                        .font(.system(size: 13))
                        .foregroundColor(theme.inkGray)
                        .padding(.bottom, 6)

                    // Surface a depleted-pool banner when no charges remain.
                    // Decree cards still render (so the player sees the menu),
                    // but the DECREE button hides on every card.
                    if !hasCharges {
                        depletedBanner
                    }

                    ForEach(decrees, id: \.decree.id) { item in
                        DecreeCard(
                            decree: item.decree,
                            isAvailable: item.available,
                            hasCharges: hasCharges,
                            onActivate: { activate(item.decree) }
                        )
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("DISMISS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(theme.inkGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.parchmentDark)
                            .overlay(Rectangle().stroke(theme.inkGray, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .alert("Last Decree Charge", isPresented: $showingLastChargeConfirm) {
            Button("CANCEL", role: .cancel) {
                pendingDecree = nil
            }
            Button("ISSUE DECREE", role: .destructive) {
                if let d = pendingDecree {
                    commit(d)
                }
                pendingDecree = nil
            }
        } message: {
            if let d = pendingDecree {
                Text("\(d.displayName) will consume your final decree charge.\n\n" + (decreeLastChargeWarning(for: game) ?? ""))
            } else {
                Text(decreeLastChargeWarning(for: game) ?? "")
            }
        }
    }

    /// Routes a card tap. If this would spend the last charge, show a
    /// confirmation alert first (mirrors SecurityPortal / Directive
    /// pattern). Otherwise commit immediately to preserve the
    /// existing fire-on-tap UX for decrees 2/3 of 3.
    private func activate(_ decree: EmergencyDecree) {
        guard hasCharges else { return }
        if game.decreeChargesRemaining == 1 {
            pendingDecree = decree
            showingLastChargeConfirm = true
        } else {
            commit(decree)
        }
    }

    /// Applies the decree via the service. The service is the single
    /// source of truth for charge deduction — if it returns false (no
    /// charges, or unavailable), we just abort silently rather than
    /// dismissing, so the player can pick a different decree.
    private func commit(_ decree: EmergencyDecree) {
        let applied = EmergencyDecreeService.shared.apply(decree, to: game)
        guard applied else { return }
        onDismiss()
        dismiss()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text("EMERGENCY DECREES")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2.5)
                    .foregroundColor(theme.sovietRed)

                Spacer()

                // Shared decree-charge counter — surfaced for awareness so the
                // player can see at a glance how many decrees remain across
                // surfaces. As of 2026-05-12 EmergencyDecreeService.apply
                // deducts one charge from this counter on each invocation, so
                // the pill ticks down live when the player issues a decree.
                DecreeChargesCounter(game: game)
            }
            Text("Extraordinary Measures of the Chairman")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(theme.inkBlack)
            Rectangle()
                .fill(theme.sovietRed)
                .frame(width: 80, height: 2)
                .padding(.top, 4)
        }
    }

    /// Shown when the shared decree pool is exhausted. Reuses the
    /// same copy as the SecurityPortal / Directive ineligibility line.
    private var depletedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 14))
                .foregroundColor(theme.sovietRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("DECREE POOL DEPLETED")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.sovietRed)
                Text("No charges remain. The Chairman's pool regenerates 1 per \(game.chairmanshipTier.decreeRegenInterval) turns and is shared across Security, Directives, Crisis Response, and Emergency surfaces.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)
            }
        }
        .padding(10)
        .background(theme.parchmentDark.opacity(0.7))
        .overlay(Rectangle().stroke(theme.sovietRed.opacity(0.5), lineWidth: 1))
    }
}

private struct DecreeCard: View {
    let decree: EmergencyDecree
    let isAvailable: Bool
    /// Whether the shared Chairman decree pool has any charges left.
    /// Even if `isAvailable` (per-decree gate) is true, we must hide
    /// the DECREE button when the pool is empty — the sheet's banner
    /// already explains why.
    let hasCharges: Bool
    let onActivate: () -> Void

    @Environment(\.theme) var theme

    /// True only when the decree both passes its own availability gate
    /// AND the shared charge pool has at least one charge.
    private var canFire: Bool { isAvailable && hasCharges }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(decree.displayName.uppercased())
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(isAvailable ? theme.inkBlack : theme.inkLight)
                Spacer()
                if !isAvailable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkLight)
                }
            }

            Text(decree.description)
                .font(.system(size: 12))
                .foregroundColor(isAvailable ? theme.inkGray : theme.inkLight)
                .lineSpacing(2)

            if isAvailable {
                effectsRow
            } else {
                Text(decree.lockReason)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(theme.inkLight)
                    .italic()
            }

            if isAvailable {
                Button(action: onActivate) {
                    Text(canFire ? "DECREE" : "NO CHARGES")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(canFire ? .white : theme.inkLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(canFire ? theme.sovietRed : theme.parchmentDark.opacity(0.5))
                        .overlay(
                            Rectangle()
                                .stroke(canFire ? Color.clear : theme.inkLight.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canFire)
            }
        }
        .padding(12)
        .background(isAvailable ? theme.parchmentDark : theme.parchmentDark.opacity(0.4))
        .overlay(
            Rectangle()
                .stroke(isAvailable ? theme.sovietRed.opacity(0.4) : theme.inkLight.opacity(0.3),
                        lineWidth: isAvailable ? 1.5 : 1)
        )
    }

    private var effectsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !decree.resourceEffects.isEmpty {
                HStack(spacing: 8) {
                    Text("RESOURCES:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.inkLight)
                    ForEach(Array(decree.resourceEffects.keys.sorted { $0.displayName < $1.displayName }), id: \.self) { resource in
                        let amount = decree.resourceEffects[resource] ?? 0
                        HStack(spacing: 2) {
                            Image(systemName: resource.iconName)
                                .font(.system(size: 9))
                            Text(amount > 0 ? "+\(amount)" : "\(amount)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(amount > 0 ? theme.successGreen : theme.sovietRed)
                    }
                }
            }
            if !decree.statEffects.isEmpty {
                HStack(spacing: 8) {
                    Text("POLITICAL:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.inkLight)
                    ForEach(decree.statEffects.sorted(by: { $0.key < $1.key }), id: \.key) { stat, change in
                        Text("\(stat) \(change > 0 ? "+\(change)" : "\(change)")")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(change > 0 ? theme.successGreen : theme.sovietRed)
                    }
                }
            }
            if decree.treasuryCost != 0 {
                Text("TREASURY: \(decree.treasuryCost > 0 ? "+\(decree.treasuryCost)" : "\(decree.treasuryCost)")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(decree.treasuryCost > 0 ? theme.successGreen : theme.sovietRed)
            }
        }
    }
}
