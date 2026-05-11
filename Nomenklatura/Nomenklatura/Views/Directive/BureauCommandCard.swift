//
//  BureauCommandCard.swift
//  Nomenklatura
//
//  A card displaying a single bureau's status and available directives.
//  Used in the DirectivePhaseView to present the 6 bureaus for command.
//

import SwiftUI

// MARK: - Bureau Command Card

/// Displays a bureau's status summary with head info, loyalty, active ops, and directive button.
struct BureauCommandCard: View {
    let bureau: ExpandedCareerTrack
    let head: BureauHeadInfo
    let activeOpsCount: Int
    let availableTaskCount: Int
    let isExpanded: Bool
    var urgentCrisis: Crisis? = nil
    let onTap: () -> Void

    @Environment(\.theme) var theme

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Bureau color stripe
            Rectangle()
                .fill(bureauColor)
                .frame(height: 4)

            // Main card content
            Button(action: onTap) {
                cardContent
            }
            .buttonStyle(.plain)
        }
        .background(theme.agedPaper)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isExpanded ? bureauColor : bureauColor.opacity(0.3), lineWidth: isExpanded ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        VStack(spacing: 10) {
            // Header row: emblem + bureau name + status indicator
            HStack(spacing: 10) {
                BureauEmblem(bureau: bureau, size: .small)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(bureau.shortName)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                            .foregroundColor(bureauColor)

                        if let crisis = urgentCrisis {
                            Text(crisis.label)
                                .font(.system(size: 6, weight: .black, design: .monospaced))
                                .tracking(0.3)
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(theme.sovietRed)
                                .cornerRadius(2)
                        }
                    }

                    Text(bureau.displayName.uppercased())
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                // Active operations indicator
                if activeOpsCount > 0 {
                    HStack(spacing: 3) {
                        StatusLight(.active, size: 5)
                        Text("\(activeOpsCount)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.approvedGreen)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(theme.approvedGreen.opacity(0.1))
                    .cornerRadius(3)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.carbonCopy)
            }

            // Bureau head info row
            HStack(spacing: 8) {
                // Portrait placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(bureauColor.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundColor(bureauColor.opacity(0.5))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(head.name)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.inkBlack)

                    Text(head.title)
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundColor(theme.carbonCopy)
                }

                Spacer()

                // Loyalty gauge
                loyaltyGauge
            }

            // Divider
            Rectangle()
                .fill(bureauColor.opacity(0.15))
                .frame(height: 1)

            // Bottom stats row
            HStack(spacing: 12) {
                statLabel(
                    icon: "gearshape.fill",
                    value: "\(availableTaskCount)",
                    label: "ORDERS"
                )

                Rectangle()
                    .fill(theme.carbonCopy.opacity(0.2))
                    .frame(width: 1, height: 14)

                statLabel(
                    icon: "circle.fill",
                    value: "\(activeOpsCount)",
                    label: "ACTIVE"
                )

                Rectangle()
                    .fill(theme.carbonCopy.opacity(0.2))
                    .frame(width: 1, height: 14)

                effectivenessIndicator
            }
        }
        .padding(12)
    }

    // MARK: - Loyalty Gauge

    private var loyaltyGauge: some View {
        VStack(spacing: 2) {
            // Loyalty bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(loyaltyColor)
                        .frame(width: geometry.size.width * CGFloat(head.loyalty) / 100.0)
                }
            }
            .frame(width: 50, height: 5)

            Text("LOYALTY \(head.loyalty)")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(loyaltyColor)
        }
    }

    private var loyaltyColor: Color {
        if head.loyalty >= 70 { return theme.approvedGreen }
        if head.loyalty >= 40 { return theme.bronzeGold }
        return theme.sovietRed
    }

    // MARK: - Effectiveness Indicator

    private var effectivenessIndicator: some View {
        HStack(spacing: 3) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 8))
                .foregroundColor(bureauColor)

            Text(effectivenessLabel)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(bureauColor)
        }
    }

    private var effectivenessLabel: String {
        if head.loyalty >= 70 { return "HIGH" }
        if head.loyalty >= 40 { return "MODERATE" }
        return "LOW"
    }

    // MARK: - Stat Label Helper

    private func statLabel(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 7))
                .foregroundColor(theme.carbonCopy)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkGray)
            Text(label)
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundColor(theme.carbonCopy)
        }
    }
}

// MARK: - Bureau Head Info

/// Lightweight data structure for displaying bureau head information.
struct BureauHeadInfo {
    let name: String
    let title: String
    let loyalty: Int  // 0-100
    let characterId: UUID?

    static func placeholder(for bureau: ExpandedCareerTrack) -> BureauHeadInfo {
        BureauHeadInfo(
            name: defaultName(for: bureau),
            title: defaultTitle(for: bureau),
            loyalty: 50,
            characterId: nil
        )
    }

    private static func defaultName(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices: return "Bureau Chief"
        case .economicPlanning: return "Planning Director"
        case .partyApparatus: return "Party Secretary"
        case .foreignAffairs: return "Foreign Minister"
        case .militaryPolitical: return "Defense Commissar"
        case .stateMinistry: return "State Minister"
        default: return "Official"
        }
    }

    private static func defaultTitle(for bureau: ExpandedCareerTrack) -> String {
        switch bureau {
        case .securityServices: return "Director, State Protection"
        case .economicPlanning: return "Chairman, Planning Committee"
        case .partyApparatus: return "Head, Organization Department"
        case .foreignAffairs: return "Minister, Foreign Affairs"
        case .militaryPolitical: return "Chief, Political Department"
        case .stateMinistry: return "Premier, State Council"
        default: return "Senior Official"
        }
    }
}
