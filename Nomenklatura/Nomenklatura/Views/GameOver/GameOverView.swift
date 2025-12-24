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
    let onNewGame: () -> Void
    let onMainMenu: () -> Void
    @Environment(\.theme) var theme

    private var isVictory: Bool {
        game.currentStatus == .won
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
                    Text(isVictory ? "VICTORY" : "GAME OVER")
                        .font(.system(size: 36, weight: .black, design: .serif))
                        .tracking(4)
                        .foregroundColor(isVictory ? theme.accentGold : theme.stampRed)

                    Rectangle()
                        .fill(isVictory ? theme.accentGold : theme.stampRed)
                        .frame(width: 100, height: 3)

                    Text(isVictory ? "YOU HAVE TRIUMPHED" : "YOUR CAREER HAS ENDED")
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

            HStack {
                Text("Highest Position:")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text(positionTitle)
                    .font(theme.bodyFontSmall)
                    .fontWeight(.medium)
                    .foregroundColor(theme.inkBlack)
            }

            HStack {
                Text("Turns Survived:")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text("\(game.turnNumber)")
                    .font(theme.bodyFontSmall)
                    .fontWeight(.medium)
                    .foregroundColor(theme.inkBlack)
            }

            HStack {
                Text("Final Standing:")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text("\(game.standing)")
                    .font(theme.bodyFontSmall)
                    .fontWeight(.medium)
                    .foregroundColor(game.standing >= 50 ? .statHigh : .statLow)
            }

            HStack {
                Text("Network Size:")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text("\(game.network)")
                    .font(theme.bodyFontSmall)
                    .fontWeight(.medium)
                    .foregroundColor(theme.inkBlack)
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
