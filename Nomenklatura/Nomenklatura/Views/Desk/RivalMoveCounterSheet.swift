//
//  RivalMoveCounterSheet.swift
//  Nomenklatura
//
//  Wave 5 / Audit "deep-politics" — confirmation sheet for one
//  RivalCounterOption. Shows the full description, cost breakdown,
//  and success/failure outcome rows; gates the [AUTHORIZE] button on
//  affordability; runs `RivalMoveGenerator.resolve` on confirm and
//  flashes a stamp overlay (.approved / .rejected) before dismiss.
//

import SwiftUI
import SwiftData

struct RivalMoveCounterSheet: View {
    @Bindable var game: Game
    let move: RivalMove
    let option: RivalCounterOption

    /// Called after the resolve roll completes — parent dismisses
    /// the sheet and (typically) re-renders the Desk so the move's
    /// new resolution state reflects on the card.
    var onDismiss: () -> Void

    @Environment(\.theme) var theme

    // Local state for the post-AUTHORIZE flash. Once non-nil, we
    // disable interaction and show the stamp overlay for ~0.8s before
    // calling onDismiss.
    @State private var resolvedSuccess: Bool? = nil

    // MARK: - Derived

    private var canAfford: Bool {
        game.actionPoints >= option.cost.actionPoints
            && game.network >= option.cost.network
            && game.treasury >= option.cost.treasury
    }

    private var affordabilityReason: String? {
        var missing: [String] = []
        if game.actionPoints < option.cost.actionPoints {
            missing.append("Action Points (have \(game.actionPoints), need \(option.cost.actionPoints))")
        }
        if game.network < option.cost.network {
            missing.append("Network (have \(game.network), need \(option.cost.network))")
        }
        if game.treasury < option.cost.treasury {
            missing.append("Treasury (have \(game.treasury), need \(option.cost.treasury))")
        }
        guard !missing.isEmpty else { return nil }
        return "INSUFFICIENT: " + missing.joined(separator: " · ")
    }

    private var successPercent: Int {
        Int((option.outcome.successChance * 100).rounded())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Newsprint paper background fills the sheet.
            theme.parchment.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerBlock
                    divider
                    descriptionBlock
                    divider
                    costBlock
                    divider
                    outcomeBlock
                    divider
                    affordabilityBanner
                    actionButtons
                }
                .padding(20)
            }
            .disabled(resolvedSuccess != nil)

            // Post-AUTHORIZE stamp flash.
            if let success = resolvedSuccess {
                Color.black.opacity(0.0001) // Capture touches during flash
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            Spacer()
                            Text(success ? "APPROVED" : "REJECTED")
                                .font(.system(size: 38, weight: .black))
                                .tracking(3)
                                .foregroundColor(
                                    (success ? theme.successGreen : theme.stampRed).opacity(0.9)
                                )
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .overlay(
                                    Rectangle()
                                        .stroke(success ? theme.successGreen : theme.stampRed,
                                                lineWidth: 4)
                                )
                                .rotationEffect(.degrees(success ? -5 : 6))
                                .opacity(0.95)
                            Spacer()
                        }
                    )
            }
        }
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ORDER OF AUTHORIZATION")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundColor(theme.urgentRed.opacity(0.85))

            Text(option.label)
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(theme.inkBlack)

            Text("RE: \(move.rivalName.uppercased())'s \(move.kind.shortLabel)".uppercased())
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(theme.inkGray)
        }
    }

    // MARK: - Divider

    private var divider: some View {
        Text(String(repeating: "=", count: 45))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(theme.inkGray.opacity(0.3))
    }

    // MARK: - Description

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("PROPOSED ACTION")

            Text(option.description)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(theme.inkBlack)
                .lineSpacing(4)
        }
    }

    // MARK: - Cost breakdown

    private var costBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("COST")

            VStack(spacing: 4) {
                if option.cost.actionPoints > 0 {
                    costRow(label: "ACTION POINTS",
                            need: option.cost.actionPoints,
                            have: game.actionPoints)
                }
                if option.cost.network > 0 {
                    costRow(label: "NETWORK",
                            need: option.cost.network,
                            have: game.network)
                }
                if option.cost.treasury > 0 {
                    costRow(label: "TREASURY",
                            need: option.cost.treasury,
                            have: game.treasury)
                }
                if option.cost.actionPoints == 0 &&
                   option.cost.network == 0 &&
                   option.cost.treasury == 0 {
                    Text("NO COST.")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundColor(theme.inkGray)
                }
            }
        }
    }

    private func costRow(label: String, need: Int, have: Int) -> some View {
        let sufficient = have >= need
        return HStack {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(theme.inkBlack)
            Spacer()
            Text("\(need) / \(have) AVAILABLE")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(sufficient ? theme.successGreen : theme.stampRed)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Outcome

    private var outcomeBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("PROJECTED OUTCOME")

            // Success rate banner.
            HStack {
                Text("SUCCESS RATE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text("\(successPercent)%")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .tracking(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .foregroundColor(theme.parchmentDark)
                    .background(percentColor(successPercent))
            }

            // On-success deltas.
            if !option.outcome.onSuccess.isEmpty {
                outcomeList(
                    label: "ON SUCCESS",
                    deltas: option.outcome.onSuccess,
                    accent: theme.successGreen
                )
            }

            // On-failure deltas.
            if !option.outcome.onFailure.isEmpty {
                outcomeList(
                    label: "ON FAILURE",
                    deltas: option.outcome.onFailure,
                    accent: theme.stampRed
                )
            }
        }
    }

    private func outcomeList(label: String, deltas: [StatDelta], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(2)
                .foregroundColor(accent.opacity(0.85))

            ForEach(Array(deltas.enumerated()), id: \.offset) { _, delta in
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(accent.opacity(0.6))
                        .frame(width: 2, height: 12)
                    Text("\(delta.displayStat)  \(formatDelta(delta.delta))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                }
            }
        }
        .padding(.leading, 4)
    }

    private func formatDelta(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        if rounded > 0 { return "+\(rounded)" }
        return "\(rounded)"
    }

    private func percentColor(_ percent: Int) -> Color {
        if percent >= 65 { return theme.successGreen }
        if percent >= 50 { return theme.warningAmber }
        return theme.stampRed
    }

    // MARK: - Affordability banner

    @ViewBuilder
    private var affordabilityBanner: some View {
        if let reason = affordabilityReason {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(theme.stampRed)
                    .frame(width: 3, height: 28)
                Text(reason)
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(theme.stampRed)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onDismiss()
            } label: {
                Text("[CANCEL]")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.inkBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .overlay(
                        Rectangle()
                            .stroke(theme.inkBlack, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Button {
                authorizeCounter()
            } label: {
                Text("[AUTHORIZE]")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.parchmentDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canAfford ? theme.stampRed : theme.inkGray)
            }
            .buttonStyle(.plain)
            .disabled(!canAfford || resolvedSuccess != nil)
        }
        .padding(.top, 8)
    }

    // MARK: - Resolve action

    private func authorizeCounter() {
        guard canAfford else { return }

        // Deduct cost first — applyStat clamps so we don't drop below 0
        // even on unusual configurations.
        if option.cost.actionPoints > 0 {
            game.actionPoints = max(0, game.actionPoints - option.cost.actionPoints)
        }
        if option.cost.network > 0 {
            game.applyStat("network", change: -option.cost.network)
        }
        if option.cost.treasury > 0 {
            game.applyStat("treasury", change: -option.cost.treasury)
        }

        // Resolve via the generator. The resolver internally rolls
        // success and applies the appropriate StatDelta set.
        RivalMoveGenerator.shared.resolve(move: move, with: option, in: game)

        // Inspect the resolution to know which stamp to flash.
        let success: Bool = {
            if let resolved = game.activeRivalMoves.first(where: { $0.id == move.id }),
               case .countered(_, let s, _) = resolved.resolution {
                return s
            }
            // Safe default if resolution didn't land (shouldn't happen).
            return false
        }()

        withAnimation(.easeOut(duration: 0.18)) {
            resolvedSuccess = success
        }

        // Dismiss after a brief flash so the player sees the stamp.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            onDismiss()
        }
    }

    // MARK: - Small helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(2)
            .foregroundColor(theme.inkBlack)
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
        body: "Three senior Politburo members are listed on his calendar tonight.",
        createdTurn: game.turnNumber,
        deadlineTurn: game.turnNumber + 2,
        pendingEffect: PendingEffect(stat: "eliteLoyalty", magnitude: -6),
        counterOptions: []
    )

    let option = RivalCounterOption(
        label: "[SURVEIL]",
        description: "Have State Security shadow him. If we catch a misstep it's leverage; if not we have a paper trail.",
        cost: CounterCost(actionPoints: 1, network: 15, treasury: 0),
        outcome: CounterOutcome(
            successChance: 0.65,
            onSuccess: [StatDelta(stat: "eliteLoyalty", delta: 4),
                        StatDelta(stat: "rivalThreat", delta: -5)],
            onFailure: [StatDelta(stat: "eliteLoyalty", delta: -2)]
        )
    )

    return RivalMoveCounterSheet(
        game: game,
        move: move,
        option: option,
        onDismiss: { print("dismissed") }
    )
    .modelContainer(container)
    .environment(\.theme, ColdWarTheme())
}
