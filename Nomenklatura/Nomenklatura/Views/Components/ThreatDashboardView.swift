//
//  ThreatDashboardView.swift
//  Nomenklatura
//
//  DEFCON-style threat dashboard showing 5 threat vectors.
//  Displays real-time threat levels computed from game stats
//  so the player can see dangers approaching before game-over strikes.
//

import SwiftUI

// MARK: - Threat Level Model

/// Represents a single threat vector with its current danger level.
struct ThreatLevel: Identifiable {
    let id: String
    let name: String
    let icon: String
    /// 0.0 (safe) to 1.0 (game-over imminent)
    let severity: Double
    let statusLabel: String
    let detail: String

    var category: ThreatCategory {
        switch severity {
        case 0..<0.25: return .stable
        case 0.25..<0.50: return .elevated
        case 0.50..<0.75: return .high
        default: return .critical
        }
    }

    enum ThreatCategory: String {
        case stable = "STABLE"
        case elevated = "ELEVATED"
        case high = "HIGH"
        case critical = "CRITICAL"

        var color: Color {
            switch self {
            case .stable: return ColdWarTheme.shared.approvedGreen
            case .elevated: return ColdWarTheme.shared.bronzeGold
            case .high: return Color(hex: "CC7000")
            case .critical: return ColdWarTheme.shared.urgentRed
            }
        }
    }
}

// MARK: - Threat Calculator

/// Computes threat levels from game state without triggering game-over.
/// Mirrors the logic in GameOverChecker and GameEngine.checkLossConditions
/// but returns normalized severity values for display.
enum ThreatCalculator {

    static func getThreatLevels(game: Game) -> [ThreatLevel] {
        [
            militaryCoupThreat(game: game),
            revolutionThreat(game: game),
            assassinationThreat(game: game),
            stateCollapseThreat(game: game),
            scRevoltThreat(game: game)
        ]
    }

    private static func militaryCoupThreat(game: Game) -> ThreatLevel {
        let milLoyalty = game.militaryLoyalty
        let stability = game.stability

        let safeZone = 60
        let milThreshold = BalanceConfig.coupMilitaryLoyaltyThreshold
        let stabThreshold = BalanceConfig.coupStabilityThreshold

        let milSeverity = inverseLerp(value: milLoyalty, safe: safeZone, danger: milThreshold)
        let stabSeverity = inverseLerp(value: stability, safe: safeZone, danger: stabThreshold)

        let severity = (milSeverity + stabSeverity) / 2.0

        let detail: String
        if milLoyalty <= milThreshold + 10 {
            detail = "Military officers expressing open discontent"
        } else if milLoyalty <= 40 {
            detail = "Generals unhappy with civilian leadership"
        } else {
            detail = "Armed forces remain under Party control"
        }

        return ThreatLevel(
            id: "military_coup",
            name: "MILITARY COUP",
            icon: "shield.lefthalf.filled",
            severity: severity,
            statusLabel: "MIL: \(milLoyalty) / STAB: \(stability)",
            detail: detail
        )
    }

    private static func revolutionThreat(game: Game) -> ThreatLevel {
        let popSupport = game.popularSupport
        let stability = game.stability

        let safeZone = 60
        let popThreshold = BalanceConfig.revolutionPopularSupportThreshold
        let stabThreshold = BalanceConfig.revolutionStabilityThreshold

        let popSeverity = inverseLerp(value: popSupport, safe: safeZone, danger: popThreshold)
        let stabSeverity = inverseLerp(value: stability, safe: safeZone, danger: stabThreshold)

        let severity = (popSeverity + stabSeverity) / 2.0

        let detail: String
        if popSupport <= popThreshold + 10 {
            detail = "Underground opposition organizing mass protests"
        } else if popSupport <= 35 {
            detail = "Growing unrest in urban centres"
        } else {
            detail = "Population remains compliant"
        }

        return ThreatLevel(
            id: "revolution",
            name: "POPULAR REVOLT",
            icon: "flame.fill",
            severity: severity,
            statusLabel: "POP: \(popSupport) / STAB: \(stability)",
            detail: detail
        )
    }

    private static func assassinationThreat(game: Game) -> ThreatLevel {
        let rivalThreat = game.rivalThreat
        let network = game.network

        let rivalSeverity = inverseLerp(value: rivalThreat, safe: 30, danger: BalanceConfig.assassinationRivalThreat)
        let networkSeverity = inverseLerp(value: network, safe: 60, danger: BalanceConfig.assassinationNetworkThreshold)

        // Rival threat is the primary factor; low network compounds it
        let severity = rivalSeverity * 0.6 + networkSeverity * 0.4

        let detail: String
        if rivalThreat >= 80 {
            detail = "Your rival is consolidating power against you"
        } else if rivalThreat >= 60 {
            detail = "Rival faction gaining influence"
        } else {
            detail = "No immediate personal threat detected"
        }

        return ThreatLevel(
            id: "assassination",
            name: "ASSASSINATION",
            icon: "target",
            severity: severity,
            statusLabel: "RIVAL: \(rivalThreat) / NET: \(network)",
            detail: detail
        )
    }

    private static func stateCollapseThreat(game: Game) -> ThreatLevel {
        let stats = [
            ("Stability", game.stability),
            ("Pop. Support", game.popularSupport),
            ("Food Supply", game.foodSupply)
        ]

        let criticalCount = stats.filter { $0.1 < 10 }.count
        let warningCount = stats.filter { $0.1 < 20 }.count

        let severity: Double
        if criticalCount >= 2 {
            severity = 1.0
        } else if criticalCount == 1 {
            severity = 0.6 + Double(warningCount - 1) * 0.1
        } else if warningCount >= 2 {
            severity = 0.4
        } else if warningCount == 1 {
            severity = 0.2
        } else {
            let lowest = stats.map(\.1).sorted().first ?? 50
            severity = inverseLerp(value: lowest, safe: 40, danger: 15)
        }

        let failingNames = stats.filter { $0.1 < 20 }.map(\.0).joined(separator: ", ")
        let detail: String
        if criticalCount >= 2 {
            detail = "Multiple systems in collapse: \(failingNames)"
        } else if warningCount >= 1 {
            detail = "Strain on: \(failingNames)"
        } else {
            detail = "State systems functioning within parameters"
        }

        return ThreatLevel(
            id: "state_collapse",
            name: "STATE COLLAPSE",
            icon: "building.columns",
            severity: min(severity, 1.0),
            statusLabel: stats.map { "\($0.0.prefix(3).uppercased()): \($0.1)" }.joined(separator: " / "),
            detail: detail
        )
    }

    private static func scRevoltThreat(game: Game) -> ThreatLevel {
        let eliteLoyalty = game.eliteLoyalty
        let patronFavor = game.patronFavor
        let standing = game.standing

        let eliteSeverity = inverseLerp(value: eliteLoyalty, safe: 60, danger: 20)
        let patronSeverity = inverseLerp(value: patronFavor, safe: 50, danger: 10)
        let standingSeverity = inverseLerp(value: standing, safe: 50, danger: 10)

        let severity = eliteSeverity * 0.4 + patronSeverity * 0.35 + standingSeverity * 0.25

        let detail: String
        if eliteLoyalty <= 25 {
            detail = "Party elites discussing your removal"
        } else if patronFavor <= 25 {
            detail = "Your patron's support is wavering dangerously"
        } else {
            detail = "Establishment support holds"
        }

        return ThreatLevel(
            id: "sc_revolt",
            name: "PARTY PURGE",
            icon: "person.3.sequence.fill",
            severity: severity,
            statusLabel: "ELITE: \(eliteLoyalty) / PATRON: \(patronFavor)",
            detail: detail
        )
    }

    // MARK: - Helpers

    /// Returns 0.0 when value is at the safe end, 1.0 when at the danger end.
    /// Handles both directions: safe > danger (most stats) and safe < danger (rivalThreat).
    private static func inverseLerp(value: Int, safe: Int, danger: Int) -> Double {
        if safe == danger { return value <= danger ? 1.0 : 0.0 }
        let clamped = min(max(Double(value), Double(min(safe, danger))), Double(max(safe, danger)))
        if safe > danger {
            return max(0, min(1, (Double(safe) - clamped) / Double(safe - danger)))
        } else {
            return max(0, min(1, (clamped - Double(safe)) / Double(danger - safe)))
        }
    }
}

// MARK: - Threat Dashboard View

/// A compact, DEFCON-style threat dashboard showing five threat vectors.
/// Soviet bureaucratic aesthetic with monospaced fonts and red-tone gauges.
struct ThreatDashboardView: View {
    @Bindable var game: Game
    @State private var isExpanded = false

    private var threats: [ThreatLevel] {
        ThreatCalculator.getThreatLevels(game: game)
    }

    var body: some View {
        let currentThreats = threats
        let topThreat = currentThreats.max(by: { $0.severity < $1.severity })

        VStack(spacing: 0) {
            headerBar(topThreat: topThreat)
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                }

            if isExpanded {
                expandedContent(currentThreats)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(borderColor(for: topThreat), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Subviews

    private func headerBar(topThreat: ThreatLevel?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(topThreat?.category.color ?? ColdWarTheme.shared.approvedGreen)

            Text("THREAT ASSESSMENT")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(ColdWarTheme.shared.agedPaper)

            Spacer()

            if let top = topThreat {
                Text(top.category.rawValue)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(top.category.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(top.category.color.opacity(0.15))
                    )
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(ColdWarTheme.shared.agedPaper.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func expandedContent(_ threats: [ThreatLevel]) -> some View {
        VStack(spacing: 6) {
            Rectangle()
                .fill(ColdWarTheme.shared.agedPaper.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 8)

            ForEach(threats) { threat in
                threatRow(threat)
            }

            Text("CLASSIFIED // EYES ONLY // GENERAL SECRETARY")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(ColdWarTheme.shared.agedPaper.opacity(0.3))
                .padding(.top, 4)
                .padding(.bottom, 6)
        }
    }

    private func threatRow(_ threat: ThreatLevel) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: threat.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(threat.category.color)
                    .frame(width: 16)

                Text(threat.name)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.agedPaper)

                Spacer()

                Text(threat.category.rawValue)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(threat.category.color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ColdWarTheme.shared.agedPaper.opacity(0.1))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(gaugeGradient(for: threat))
                        .frame(width: geo.size.width * min(CGFloat(threat.severity), 1.0), height: 4)
                }
            }
            .frame(height: 4)

            Text(threat.detail)
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(ColdWarTheme.shared.agedPaper.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func gaugeGradient(for threat: ThreatLevel) -> LinearGradient {
        let color = threat.category.color
        return LinearGradient(
            colors: [color.opacity(0.6), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func borderColor(for topThreat: ThreatLevel?) -> Color {
        guard let top = topThreat else { return ColdWarTheme.shared.agedPaper.opacity(0.2) }
        switch top.category {
        case .stable: return ColdWarTheme.shared.agedPaper.opacity(0.2)
        case .elevated: return top.category.color.opacity(0.3)
        case .high: return top.category.color.opacity(0.4)
        case .critical: return top.category.color.opacity(0.5)
        }
    }
}

// MARK: - Preview

//#Preview {
//    let config = ModelConfiguration(isStoredInMemoryOnly: true)
//    let container = try! ModelContainer(for: Game.self, configurations: config)
//    let game = Game(campaignId: "coldwar")
//    game.militaryLoyalty = 25
//    game.stability = 30
//    game.popularSupport = 40
//    game.rivalThreat = 75
//    game.network = 25
//    container.mainContext.insert(game)
//
//    return VStack(spacing: 20) {
//        ThreatDashboardView(game: game)
//            .padding(.horizontal, 16)
//    }
//    .background(Color.black)
//    .modelContainer(container)
//}
