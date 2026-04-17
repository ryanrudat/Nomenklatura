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

    private var decrees: [(decree: EmergencyDecree, available: Bool)] {
        EmergencyDecreeService.shared.decreesWithAvailability(in: game)
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

                    ForEach(decrees, id: \.decree.id) { item in
                        DecreeCard(
                            decree: item.decree,
                            isAvailable: item.available,
                            onActivate: {
                                EmergencyDecreeService.shared.apply(item.decree, to: game)
                                onDismiss()
                                dismiss()
                            }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("EMERGENCY DECREES")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundColor(theme.sovietRed)
            Text("Extraordinary Measures of the Chairman")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(theme.inkBlack)
            Rectangle()
                .fill(theme.sovietRed)
                .frame(width: 80, height: 2)
                .padding(.top, 4)
        }
    }
}

private struct DecreeCard: View {
    let decree: EmergencyDecree
    let isAvailable: Bool
    let onActivate: () -> Void

    @Environment(\.theme) var theme

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
                    Text("DECREE")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(theme.sovietRed)
                }
                .buttonStyle(.plain)
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
