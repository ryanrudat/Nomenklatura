//
//  LawCard.swift
//  Nomenklatura
//
//  Individual law display card for the Laws view
//

import SwiftUI
import SwiftData

struct LawCard: View {
    let law: Law
    @Bindable var game: Game
    let canPropose: Bool
    let onProposeTap: () -> Void
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    private var requirements: LawChangeRequirement {
        LawChangeRequirement.requirements(for: law, toState: .modifiedWeak)
    }

    private var canModify: Bool {
        game.powerConsolidationScore >= requirements.powerRequired && canPropose
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    // Law state indicator
                    LawStateIndicator(state: law.lawCurrentState)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(law.name)
                            .font(theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundColor(theme.inkBlack)
                            .lineLimit(2)

                        if law.hasBeenModified {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 10))
                                Text("Modified by \(law.enactedBy ?? "Unknown")")
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(theme.sovietRed.opacity(0.8))
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                }
                .padding(12)
                .background(theme.parchmentDark)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Description
                    Text(law.lawDescription)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                        .fixedSize(horizontal: false, vertical: true)

                    // Beneficiaries and Losers
                    if !law.beneficiaries.isEmpty || !law.losers.isEmpty {
                        Divider()

                        HStack(spacing: 20) {
                            if !law.beneficiaries.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.thumbsup.fill")
                                            .font(.system(size: 10))
                                        Text("BENEFITS")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.5)
                                    }
                                    .foregroundColor(.statHigh)

                                    ForEach(law.beneficiaries, id: \.self) { factionId in
                                        Text(factionDisplayName(factionId))
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.inkGray)
                                    }
                                }
                            }

                            if !law.losers.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "hand.thumbsdown.fill")
                                            .font(.system(size: 10))
                                        Text("OPPOSES")
                                            .font(.system(size: 9, weight: .bold))
                                            .tracking(0.5)
                                    }
                                    .foregroundColor(.statLow)

                                    ForEach(law.losers, id: \.self) { factionId in
                                        Text(factionDisplayName(factionId))
                                            .font(.system(size: 11))
                                            .foregroundColor(theme.inkGray)
                                    }
                                }
                            }

                            Spacer()
                        }
                    }

                    // Requirements info
                    Divider()

                    HStack(spacing: 16) {
                        // Power required
                        VStack(alignment: .leading, spacing: 2) {
                            Text("POWER REQUIRED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(theme.inkLight)

                            HStack(spacing: 4) {
                                Text("\(requirements.powerRequired)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(canModify ? .statHigh : theme.inkGray)

                                Text("/ \(game.powerConsolidationScore)")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.inkLight)
                            }
                        }

                        Spacer()

                        // Propose button
                        if canPropose {
                            Button(action: onProposeTap) {
                                HStack(spacing: 6) {
                                    Image(systemName: "doc.badge.plus")
                                    Text("PROPOSE")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(canModify ? theme.sovietRed : theme.inkGray)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                            .disabled(!canModify)
                        } else {
                            Text("SC MEMBERSHIP REQUIRED")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.5)
                                .foregroundColor(theme.inkLight)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(theme.parchmentDark)
                                .cornerRadius(4)
                        }
                    }

                    // Pending consequences warning
                    if !law.pendingConsequences.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.statLow)
                            Text("\(law.pendingConsequences.count) pending consequence(s)")
                                .font(.system(size: 11))
                                .foregroundColor(.statLow)
                        }
                        .padding(8)
                        .background(Color.statLow.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                .padding(12)
                .background(theme.parchment)
            }
        }
        .overlay(
            Rectangle()
                .stroke(law.hasBeenModified ? theme.sovietRed.opacity(0.4) : theme.borderTan, lineWidth: 1)
        )
    }

    private func factionDisplayName(_ factionId: String) -> String {
        switch factionId {
        case "youth_league": return "Youth League"
        case "princelings": return "Princelings"
        case "reformists": return "Reformists"
        case "old_guard": return "Proletariat Union"
        case "regional": return "Provincial Administration"
        default: return factionId.capitalized
        }
    }
}

// MARK: - Law State Indicator

struct LawStateIndicator: View {
    let state: LawState
    @Environment(\.theme) var theme

    private var stateColor: Color {
        switch state {
        case .defaultState: return .statHigh
        case .modifiedWeak: return .statMedium
        case .modifiedStrong: return Color(hex: "FF9800")
        case .abolished: return .statLow
        case .strengthened: return Color(hex: "9C27B0")
        }
    }

    private var stateIcon: String {
        switch state {
        case .defaultState: return "checkmark.circle.fill"
        case .modifiedWeak: return "pencil.circle.fill"
        case .modifiedStrong: return "exclamationmark.circle.fill"
        case .abolished: return "xmark.circle.fill"
        case .strengthened: return "plus.circle.fill"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: stateIcon)
                .font(.system(size: 20))
                .foregroundColor(stateColor)

            Text(state.displayName)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.3)
                .foregroundColor(stateColor)
                .lineLimit(1)
        }
        .frame(width: 60)
    }
}
