//
//  DeskView+TurnManagement.swift
//  Nomenklatura
//
//  Turn advancement, document consequences, treasury briefing, nav actions
//

import SwiftUI

extension DeskView {

    // MARK: - Turn Advancement

    /// Process end of turn with consequences for unhandled documents
    func processEndTurnWithConsequences() {
        // Apply consequences for pending documents
        let pendingDocs = documentQueue.getActiveDocuments(for: game).filter { $0.requiresDecision }
        for doc in pendingDocs {
            applyDocumentConsequence(doc)
        }

        // The day's central decision was left unsigned. Ducking the dilemma
        // is itself a decision — the apparatus notices indecision at the top.
        // Sting is deliberately milder than most bad option outcomes.
        if let scenario = currentScenario, scenario.requiresDecision {
            game.applyStat("standing", change: -3)
            game.applyStat("patronFavor", change: -2)

            let event = GameEvent(
                turnNumber: game.turnNumber,
                eventType: .decision,
                summary: "Left unsigned: the matter raised by \(scenario.presenterName) went unanswered. The apparatus notes the Chairman's silence."
            )
            event.importance = 5
            event.game = game
            game.events.append(event)
        }

        // Clear current scenario/newspaper state
        currentScenario = nil
        currentNewspaper = nil
        currentSamizdat = nil

        // Use the proper end turn flow through game phases
        if let onEndTurn = onEndTurn {
            onEndTurn()
        } else {
            assertionFailure("DeskView.onEndTurn callback must be provided by the parent view")
        }
    }

    /// Apply negative consequence for not acting on a document
    func applyDocumentConsequence(_ document: DeskDocument) {
        // Mark document as expired/ignored
        document.status = DocumentStatus.expired.rawValue

        // Apply stat penalties based on document urgency and type
        let penalty: Int
        switch document.urgencyEnum {
        case .critical:
            penalty = -8
            game.applyStat("standing", change: -5)  // Standing hit for ignoring critical items
        case .urgent:
            penalty = -5
            game.applyStat("standing", change: -2)
        case .priority:
            penalty = -3
        case .routine:
            penalty = -1
        }

        // Apply the penalty to relevant stats based on document category
        switch document.categoryEnum {
        case .political:
            game.applyStat("eliteLoyalty", change: penalty)
        case .economic:
            game.applyStat("treasury", change: penalty * 10)
        case .security:
            game.applyStat("stability", change: penalty)
        case .diplomatic:
            game.applyStat("internationalStanding", change: penalty)
        case .military:
            game.applyStat("militaryLoyalty", change: penalty)
        case .personnel:
            game.applyStat("network", change: penalty / 2)
        case .crisis:
            game.applyStat("stability", change: penalty)
            game.applyStat("standing", change: -3)  // Crisis neglect hurts standing
        case .personal:
            game.applyStat("patronFavor", change: penalty)
        }

        // Log the consequence
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .decision,
            summary: "Failed to act on: \(document.title)"
        )
        event.game = game
        game.events.append(event)
    }

    // MARK: - Navigation Actions

    func openPatronSheet() {
        if let patron = game.patron {
            NotificationCenter.default.post(
                name: .showCharacterSheet,
                object: patron.name
            )
        }
    }

    func openRivalSheet() {
        // Find active rival character
        if let rival = game.characters.first(where: { $0.isRival && $0.isActive }) {
            NotificationCenter.default.post(
                name: .showCharacterSheet,
                object: rival.name
            )
        }
    }

    // MARK: - Rival Moves Section (Wave 5 / Audit "deep-politics")

    /// Renders one `RivalMoveCard` per pending RivalMove on the game.
    /// Empty when no moves are pending — takes zero vertical space so
    /// quiet turns don't pad the scroll stack. Section header uses
    /// tracked monospace and only appears when there is at least one
    /// card to label.
    @ViewBuilder
    var rivalMovesSection: some View {
        let pending = game.activeRivalMoves.filter { !$0.resolution.isResolved }
        if !pending.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("PENDING THREATS")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(ColdWarTheme.shared.stampRed)
                    Rectangle()
                        .fill(ColdWarTheme.shared.stampRed.opacity(0.4))
                        .frame(height: 1)
                }
                .padding(.horizontal, 2)

                ForEach(pending) { move in
                    RivalMoveCard(
                        game: game,
                        move: move,
                        onSelectCounter: { option in
                            presentedCounterContext = RivalCounterPresentation(
                                move: move,
                                option: option
                            )
                        },
                        onTakeNoAction: {
                            handleRivalMoveIgnored(move)
                        }
                    )
                }
            }
        }
    }

    /// Mark a RivalMove as `.ignored`. Pending damage still triggers
    /// at the deadline — this just records the player's stance and
    /// removes the card from the Desk so they aren't stuck staring
    /// at a brief they've already decided to take on the chin.
    func handleRivalMoveIgnored(_ move: RivalMove) {
        // "Take no action" applies base pendingEffect damage (multiplier 1.0).
        // Distinct from .expired (deadline passed without input), which
        // applies 1.5× as a caught-unaware penalty. Rewards the player for
        // engaging — even a deliberate "pass" hurts less than forgetting.
        RivalMoveGenerator.shared.applyExpiredMove(move, to: game, multiplier: 1.0)
        var moves = game.activeRivalMoves
        guard let idx = moves.firstIndex(where: { $0.id == move.id }) else { return }
        moves[idx].resolution = .ignored
        game.activeRivalMoves = moves
    }

    // MARK: - Content Section

    @ViewBuilder
    var contentSection: some View {
        VStack(spacing: 16) {
            // Document stack section (always show if documents exist)
            let visibleDocuments = documentQueue.getVisibleDocuments(for: game)
            if !visibleDocuments.isEmpty {
                documentStackSection(documents: visibleDocuments)
            }

            // Loading/Scenario/Newspaper section
            if isTransitioning || loadingState.isLoading {
                // Immersive loading with manila folder, photos, and CLASSIFIED stamp
                immersiveLoadingSection
            } else if let newspaper = currentNewspaper {
                physicalNewspaperCard(newspaper: newspaper)
            } else if let scenario = currentScenario {
                physicalScenarioCards(scenario: scenario)
            } else if visibleDocuments.isEmpty && !hasDisplayedContentForTurn {
                // If the desk is still resolving this turn, keep the loading state visible.
                immersiveLoadingSection
            } else {
                // No scenario/newspaper is active, so the player can wrap the turn from the desk.
                endTurnSection
            }
        }
    }

    // MARK: - End Turn Section

    @ViewBuilder
    var endTurnSection: some View {
        VStack(spacing: 12) {
            // Explanation
            Text("All documents processed for this turn.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(ColdWarTheme.shared.leatherBrown.opacity(0.7))
                .multilineTextAlignment(.center)

            // End Turn button styled like 1950s office
            Button {
                processEndTurnWithConsequences()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text("END TURN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(2)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(ColdWarTheme.shared.leatherBrown)
                )
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColdWarTheme.shared.agedPaper.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColdWarTheme.shared.leatherBrown.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Treasury Briefing

    @ViewBuilder
    func treasuryBriefingSection(report: EconomyService.EconomicReport) -> some View {
        let primaryLines = Array(report.breakdown.sorted { abs($0.1) > abs($1.1) }.prefix(3))
        // report.netChange is a gross activity model; the actual treasury move is recorded separately
        let actualDelta = game.intVariable("last_economy_treasury_delta")

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TREASURY BRIEFING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.leatherBrown)

                Spacer()

                Text("LAST TURN")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.inkGray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ColdWarTheme.shared.manillaFolder.opacity(0.6))
                    )
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NET")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                    Text(signedValue(actualDelta))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(colorForDelta(actualDelta))
                }

                Rectangle()
                    .fill(ColdWarTheme.shared.leatherBrown.opacity(0.2))
                    .frame(width: 1, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT TREASURY")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                    Text("\(game.treasury)")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(ColdWarTheme.shared.inkBlack)
                }
            }

            if !primaryLines.isEmpty {
                Rectangle()
                    .fill(ColdWarTheme.shared.leatherBrown.opacity(0.15))
                    .frame(height: 1)

                Text("GROSS ACTIVITY (reference)")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.inkGray)

                VStack(spacing: 4) {
                    ForEach(Array(primaryLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 8) {
                            Text(line.0)
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundColor(ColdWarTheme.shared.inkGray)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(signedValue(line.1))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(colorForDelta(line.1))
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(ColdWarTheme.shared.agedPaper.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(ColdWarTheme.shared.leatherBrown.opacity(0.22), lineWidth: 1)
                )
        )
    }

    func signedValue(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        return "\(value)"
    }

    func colorForDelta(_ value: Int) -> Color {
        if value > 0 { return ColdWarTheme.shared.approvedGreen }
        if value < 0 { return ColdWarTheme.shared.urgentRed }
        return ColdWarTheme.shared.inkGray
    }

}
