//
//  RivalMoveCard.swift
//  Nomenklatura
//
//  Wave 5 / Audit "deep-politics" — the Desk surface for a single
//  pending RivalMove. Renders a brief, the threatened stat, a
//  deadline-coded urgency border, and the counter options the
//  Chairman can authorize. Tap any counter button (or "TAKE NO
//  ACTION") to open the counter sheet for confirmation.
//
//  Visual language matches BriefingPaperView (doc number header,
//  classification stripe, paper grain) so the card reads as another
//  Politburo document on the Chairman's desk.
//

import SwiftUI
import SwiftData

struct RivalMoveCard: View {
    @Bindable var game: Game
    let move: RivalMove

    /// Parent passes a closure to open the counter sheet — the card
    /// itself doesn't present sheets so DeskView can keep all sheet
    /// state in one place (consistent with the existing pattern).
    var onSelectCounter: (RivalCounterOption) -> Void
    var onTakeNoAction: () -> Void

    @Environment(\.theme) var theme

    // MARK: - Derived

    /// Turns remaining until the deadline triggers `pendingEffect`.
    /// Negative values would only appear briefly between the turn
    /// boundary and the next `processTurn` call, but treat them as 0.
    private var turnsUntilDeadline: Int {
        max(0, move.deadlineTurn - game.turnNumber)
    }

    /// Urgency tier for border color + label. Three buckets keep the
    /// signal readable at-a-glance.
    private enum Urgency {
        case ample      // 2+ turns left — paper gray
        case soon       // 1 turn left — amber
        case immediate  // 0 turns — stamp red (this turn or already overdue)
    }

    private var urgency: Urgency {
        switch turnsUntilDeadline {
        case 0:  return .immediate
        case 1:  return .soon
        default: return .ample
        }
    }

    private var urgencyColor: Color {
        switch urgency {
        case .ample:     return theme.paperGray
        case .soon:      return theme.warningAmber
        case .immediate: return theme.stampRed
        }
    }

    private var urgencyLabel: String {
        switch urgency {
        case .ample:     return "DEADLINE: T+\(turnsUntilDeadline)"
        case .soon:      return "DEADLINE NEXT TURN"
        case .immediate: return "DEADLINE: THIS TURN"
        }
    }

    /// Pseudo-document number — stable per move id so the card
    /// always looks like the same filed paper. Avoids the appearance
    /// of jittery state when SwiftUI re-renders the row.
    private var documentNumber: String {
        // Use a stable hash from the move id so the same move always
        // displays the same number; 5 digits keeps it visually tight.
        let raw = abs(move.id.uuidString.hashValue) % 100_000
        return String(format: "INT-BR/%05d", raw)
    }

    private var pendingMagnitudeAbs: Int {
        Int(abs(move.pendingEffect.magnitude).rounded())
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBlock
            divider
            bodyBlock
            divider
            pendingEffectBlock
            divider
            counterOptionsBlock
            takeNoActionButton
        }
        .padding(14)
        .background(theme.parchmentDark)
        .overlay(
            // Brutalist border whose color signals urgency.
            Rectangle()
                .stroke(urgencyColor, lineWidth: urgency == .immediate ? 2.0 : 1.0)
        )
        .paperGrain(intensity: 0.06)
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }

    // MARK: - Header

    private var headerBlock: some View {
        HStack(alignment: .top, spacing: 10) {
            // Red classification stripe on the left edge of the header.
            Rectangle()
                .fill(urgencyColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                // Document number + classification tier.
                HStack(spacing: 10) {
                    Text(documentNumber)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(theme.inkBlack)
                    Rectangle()
                        .fill(theme.inkGray.opacity(0.4))
                        .frame(width: 0.5, height: 10)
                    Text("CLASSIFIED — EYES ONLY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(theme.urgentRed.opacity(0.85))
                }

                // Headline — the "INTELLIGENCE BRIEF — Volkov" line.
                Text("INTELLIGENCE BRIEF — \(move.rivalName.uppercased())")
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.stampRed)
                    .lineLimit(2)

                // Urgency label sits under the headline so the player
                // never has to scan the whole card to find the deadline.
                Text(urgencyLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(urgencyColor)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.bottom, 8)
    }

    // MARK: - Divider

    private var divider: some View {
        Text(String(repeating: "=", count: 42))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(theme.inkGray.opacity(0.3))
            .padding(.vertical, 6)
    }

    // MARK: - Body block (headline + body narrative)

    private var bodyBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The move's one-line headline reads as a sub-headline
            // (the title above is the document header).
            Text(move.headline)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(theme.inkBlack)
                .lineSpacing(3)

            // The narrative body.
            Text(move.body)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(theme.inkBlack.opacity(0.85))
                .lineSpacing(4)
        }
    }

    // MARK: - Pending effect block

    private var pendingEffectBlock: some View {
        HStack(spacing: 8) {
            // Warning bar on the left edge of this row reinforces "this
            // is the cost of doing nothing".
            Rectangle()
                .fill(theme.stampRed)
                .frame(width: 3, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("IF UNANSWERED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.stampRed.opacity(0.85))

                Text("\(move.kind.threatStatDisplay) -\(pendingMagnitudeAbs)  (T+\(turnsUntilDeadline))")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(theme.inkBlack)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Counter options block

    private var counterOptionsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUTHORIZED RESPONSES")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.8)
                .foregroundColor(theme.inkGray)
                .padding(.bottom, 2)

            ForEach(move.counterOptions) { option in
                counterButton(option: option)
            }
        }
        .padding(.bottom, 6)
    }

    private func counterButton(option: RivalCounterOption) -> some View {
        let percent = Int((option.outcome.successChance * 100).rounded())
        let costSummary = formatCost(option.cost)
        let canAfford = canAffordCost(option.cost)

        return Button {
            onSelectCounter(option)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(canAfford ? theme.inkBlack : theme.inkGray)

                    Text(costSummary)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(canAfford ? theme.inkGray : theme.stampRed)
                }

                Spacer(minLength: 4)

                // Success percent badge — small but readable.
                Text("\(percent)%")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundColor(theme.parchmentDark)
                    .background(percentBadgeColor(percent))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.parchment.opacity(canAfford ? 1.0 : 0.5))
            .overlay(
                Rectangle()
                    .stroke(theme.inkGray.opacity(canAfford ? 0.6 : 0.3), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        // Always tappable — affordability is enforced in the counter
        // sheet so the player can still inspect a too-costly option.
    }

    private func percentBadgeColor(_ percent: Int) -> Color {
        if percent >= 65 { return theme.successGreen }
        if percent >= 50 { return theme.warningAmber }
        return theme.stampRed
    }

    // MARK: - Take-no-action button

    private var takeNoActionButton: some View {
        Button {
            onTakeNoAction()
        } label: {
            Text("[TAKE NO ACTION]")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(theme.inkGray)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .stroke(theme.inkGray.opacity(0.4), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Cost helpers

    private func canAffordCost(_ cost: CounterCost) -> Bool {
        game.actionPoints >= cost.actionPoints
            && game.network >= cost.network
            && game.treasury >= cost.treasury
    }

    private func formatCost(_ cost: CounterCost) -> String {
        var parts: [String] = []
        if cost.actionPoints > 0 { parts.append("\(cost.actionPoints) AP") }
        if cost.network > 0      { parts.append("\(cost.network) net") }
        if cost.treasury > 0     { parts.append("\(cost.treasury) treas") }
        if parts.isEmpty { return "free" }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    let move = RivalMove(
        rivalCharacterId: UUID(),
        rivalName: "Volkov",
        kind: .factionWhisperCampaign,
        headline: "Minister Volkov is scheduling private meetings.",
        body: "Three senior Politburo members are listed on his calendar tonight. The agenda is unstated.",
        createdTurn: game.turnNumber,
        deadlineTurn: game.turnNumber + 2,
        pendingEffect: PendingEffect(stat: "eliteLoyalty", magnitude: -6),
        counterOptions: [
            RivalCounterOption(
                label: "[SURVEIL]",
                description: "Have State Security shadow him.",
                cost: CounterCost(actionPoints: 1, network: 15, treasury: 0),
                outcome: CounterOutcome(
                    successChance: 0.65,
                    onSuccess: [StatDelta(stat: "eliteLoyalty", delta: 4)],
                    onFailure: [StatDelta(stat: "eliteLoyalty", delta: -2)]
                )
            ),
            RivalCounterOption(
                label: "[CONFRONT]",
                description: "Summon him publicly.",
                cost: CounterCost(actionPoints: 1, network: 5, treasury: 0),
                outcome: CounterOutcome(
                    successChance: 0.45,
                    onSuccess: [StatDelta(stat: "standing", delta: 5)],
                    onFailure: [StatDelta(stat: "standing", delta: -4)]
                )
            )
        ]
    )

    return ScrollView {
        RivalMoveCard(
            game: game,
            move: move,
            onSelectCounter: { _ in },
            onTakeNoAction: { }
        )
        .padding()
    }
    .background(Color(hex: "F5F0E1"))
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
