//
//  GameOverView.swift
//  Nomenklatura
//
//  Game Over screen for win/loss states
//

import SwiftUI
import SwiftData

struct GameOverView: View {
    let game: Game
    let endReason: String
    var victoryType: VictoryType?
    let onNewGame: () -> Void
    let onMainMenu: () -> Void
    @Environment(\.theme) var theme

    private var isVictory: Bool {
        game.currentStatus == .won
    }

    private var headerTitle: String {
        if let vt = victoryType {
            return vt.displayTitle
        }
        return isVictory ? "VICTORY" : "GAME OVER"
    }

    private var headerSubtitle: String {
        if let vt = victoryType {
            return vt.subtitle
        }
        return isVictory ? "YOU HAVE TRIUMPHED" : "YOUR CAREER HAS ENDED"
    }

    var body: some View {
        ZStack {
            // Background
            (isVictory ? theme.accentGold.opacity(0.1) : theme.stampRed.opacity(0.1))
                .ignoresSafeArea()

            theme.parchment.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Header stamp
                VStack(spacing: 10) {
                    if let vt = victoryType {
                        Image(systemName: vt.iconName)
                            .font(.system(size: 28))
                            .foregroundColor(theme.accentGold)
                            .padding(.bottom, 4)
                    }

                    Text(headerTitle)
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .tracking(4)
                        .foregroundColor(isVictory ? theme.accentGold : theme.stampRed)

                    Rectangle()
                        .fill(isVictory ? theme.accentGold : theme.stampRed)
                        .frame(width: 100, height: 3)

                    Text(headerSubtitle)
                        .font(theme.labelFont)
                        .tracking(2)
                        .foregroundColor(theme.inkGray)
                }
                .padding(.bottom, 40)

                // End reason narrative
                ScrollView {
                    VStack(spacing: 20) {
                        // Narrative card
                        VStack(alignment: .leading, spacing: 15) {
                            Text(isVictory ? "THE FINAL CHAPTER" : "THE END")
                                .font(theme.labelFont)
                                .tracking(2)
                                .foregroundColor(isVictory ? theme.accentGold : theme.stampRed)

                            Rectangle()
                                .fill(theme.borderTan)
                                .frame(height: 1)

                            Text(endReason)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                                .lineSpacing(6)
                        }
                        .padding(20)
                        .background(theme.parchmentDark)
                        .overlay(
                            Rectangle()
                                .stroke(theme.borderTan, lineWidth: 1)
                        )

                        // Victory scoring breakdown (only for wins)
                        if isVictory {
                            VictoryScoringCard(game: game, victoryType: victoryType)
                        }

                        // Final stats summary
                        FinalStatsCard(game: game)

                        // Career summary
                        CareerSummaryCard(game: game)
                    }
                    .padding(20)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: onNewGame) {
                        Text("NEW CAMPAIGN")
                            .font(theme.labelFont)
                            .tracking(2)
                            .foregroundColor(theme.parchmentDark)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(isVictory ? theme.accentGold : theme.stampRed)
                    }
                    .buttonStyle(.plain)

                    Button(action: onMainMenu) {
                        Text("MAIN MENU")
                            .font(theme.labelFont)
                            .tracking(1)
                            .foregroundColor(theme.inkGray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                Rectangle()
                                    .stroke(theme.borderTan, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Victory Scoring Card

struct VictoryScoringCard: View {
    let game: Game
    let victoryType: VictoryType?
    @Environment(\.theme) var theme

    private var turnsInPower: Int {
        game.intVariable("turns_as_leader")
    }

    private var powerLevel: String {
        let score = game.powerConsolidationScore
        switch score {
        case 90...: return "Supreme Leader (\(score))"
        case 70..<90: return "Dominant (\(score))"
        case 50..<70: return "Established (\(score))"
        case 30..<50: return "Consolidating (\(score))"
        default: return "Vulnerable (\(score))"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCORING BREAKDOWN")
                .font(theme.labelFont)
                .tracking(1)
                .foregroundColor(theme.accentGold)

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            ScoringRow(label: "Turns in Power", value: "\(turnsInPower)")
            ScoringRow(label: "Power Level", value: powerLevel)
            ScoringRow(label: "Stability", value: "\(game.stability)")
            ScoringRow(label: "Popular Support", value: "\(game.popularSupport)")
            ScoringRow(label: "Industrial Output", value: "\(game.industrialOutput)")
            ScoringRow(label: "Int'l Standing", value: "\(game.internationalStanding)")

            if let vt = victoryType {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Text(victoryAchievementText(for: vt))
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.accentGold)
                    .lineSpacing(4)
            }
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.accentGold.opacity(0.5), lineWidth: 1)
        )
    }

    private func victoryAchievementText(for type: VictoryType) -> String {
        switch type {
        case .survival:
            return "Achievement: Survived \(turnsInPower) turns at the pinnacle of power. The paranoid authoritarian who outlasted them all."
        case .legacy:
            return "Achievement: Maintained national prosperity for \(game.intVariable("consecutive_high_stat_turns")) consecutive turns. The benevolent dictator who built something lasting."
        case .absolutePower:
            return "Achievement: Held absolute power for \(game.intVariable("consecutive_supreme_leader_turns")) consecutive turns. The totalitarian who crushed all opposition."
        case .reformer:
            return "Achievement: Popular Support \(game.popularSupport), International Standing \(game.internationalStanding). The enlightened despot who chose a different path."
        }
    }
}

struct ScoringRow: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            Text(label)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(theme.bodyFontSmall)
                .fontWeight(.medium)
                .foregroundColor(theme.inkBlack)
        }
    }
}

// MARK: - Final Stats Card

struct FinalStatsCard: View {
    let game: Game
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FINAL STATE OF THE NATION")
                .font(theme.labelFont)
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                FinalStatRow(label: "Stability", value: game.stability)
                FinalStatRow(label: "Popular Support", value: game.popularSupport)
                FinalStatRow(label: "Military", value: game.militaryLoyalty)
                FinalStatRow(label: "Party", value: game.eliteLoyalty)
                FinalStatRow(label: "Treasury", value: game.treasury)
                FinalStatRow(label: "Industry", value: game.industrialOutput)
                FinalStatRow(label: "Food Supply", value: game.foodSupply)
                FinalStatRow(label: "Int'l Standing", value: game.internationalStanding)
            }
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct FinalStatRow: View {
    let label: String
    let value: Int
    @Environment(\.theme) var theme

    private var valueColor: Color {
        switch value {
        case 70...: return .statHigh
        case 40..<70: return .statMedium
        default: return .statLow
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)

            Spacer()

            Text("\(value)")
                .font(theme.statFont)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
        }
    }
}

// MARK: - Career Summary Card

struct CareerSummaryCard: View {
    let game: Game
    @Environment(\.theme) var theme

    private var positionTitle: String {
        let titles = [
            "Party Official",
            "Junior Politburo Member",
            "Deputy Department Head",
            "Department Head",
            "Senior Politburo Member",
            "Deputy General Secretary",
            "General Secretary"
        ]
        return titles[safe: game.currentPositionIndex] ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CAREER")
                .font(theme.labelFont)
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            ScoringRow(label: "Highest Position", value: positionTitle)
            ScoringRow(label: "Turns Survived", value: "\(game.turnNumber)")
            ScoringRow(label: "Final Standing", value: "\(game.standing)")
            ScoringRow(label: "Network Size", value: "\(game.network)")
        }
        .padding(15)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    game.status = GameStatus.lost.rawValue
    game.turnNumber = 15
    game.standing = 12
    game.currentPositionIndex = 3
    container.mainContext.insert(game)

    return GameOverView(
        game: game,
        endReason: "Your patron has turned against you. Wallace's men arrive at dawn. Your political career—and perhaps your life—is over.",
        onNewGame: {},
        onMainMenu: {}
    )
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
