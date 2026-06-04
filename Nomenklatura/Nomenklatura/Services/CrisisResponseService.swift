//
//  CrisisResponseService.swift
//  Nomenklatura
//
//  Single-stop "what can I do RIGHT NOW about this crisis" layer that
//  the Crisis Response Panel binds to. Consolidates fragmentary tools
//  (briefing options, bureau directives, codex prompts, sector decrees,
//  decree charges) into a curated option library per crisis.
//
//  Responsibilities:
//    * Detect active crises from current Game state via threshold rules.
//    * Score each crisis 0-100 by distance from threshold (severity).
//    * Return availability-filtered option lists per crisis.
//    * Execute a chosen option: pay costs, roll deterministically against
//      `game.rng`, apply stat changes, set flags, log a GameEvent, and
//      return a CrisisResponseResult.
//
//  Determinism note: rolls use `game.rng` (SplitMix64) via the documented
//  mutation-write-back pattern so player saves are reproducible.
//

import Foundation

@MainActor
final class CrisisResponseService {
    static let shared = CrisisResponseService()
    private init() {}

    // MARK: - Detection

    /// Every active crisis right now. Order is canonical (matches the
    /// `CrisisType` declaration order) so UI layout is stable across turns.
    /// Empty array = quiet turn.
    func activeCrises(in game: Game) -> [CrisisType] {
        CrisisType.allCases.filter { isCrisisActive($0, in: game) }
    }

    /// Turns the player gets before any crisis can fire. Without this, the
    /// uneven starting economy + strategic-resource-feedback loop can drain
    /// political stats fast enough to push 2-3 thresholds in the first turn.
    /// Playtest report: "I just started and now have 3 crises."
    private static let crisisGracePeriodTurns: Int = 4

    private func isCrisisActive(_ crisis: CrisisType, in game: Game) -> Bool {
        // Grace period: nothing fires for the first few turns. The Chairman
        // gets a chance to assess the apparatus before the apparatus assesses
        // them. After this turn the normal threshold logic takes over.
        guard game.turnNumber > Self.crisisGracePeriodTurns else { return false }

        switch crisis {
        case .stabilityCollapse:
            return game.stability < 25

        case .treasuryCrisis:
            if game.treasury < 30 { return true }
            let debtService = game.totalDebtService
            return debtService > 0 && debtService * 3 > game.treasury

        case .resourceCatastrophe:
            // Only SEVERE shortfalls count toward catastrophe. A sector at
            // 95% satisfaction is uncomfortable; one at 50% is broken. The
            // old "<100%" threshold made 3+ shortfalls trivial because the
            // starting economy never balances perfectly.
            if let result = game.lastSupplyChainResult {
                let severeShortfalls = result.shortfallBySector.values.filter { $0 < 70 }.count
                if severeShortfalls >= 3 { return true }
                // Deficits (resources at zero reserve) still count any-or-more;
                // running out of grain is a crisis even if other reserves are fine.
                if result.deficitResources.count >= 3 { return true }
            }
            return false

        case .coupRisk:
            return game.militaryLoyalty < 25

        case .diplomaticCrisis:
            if game.worldTension > 80 { return true }
            return game.foreignCountries.contains { $0.diplomaticTension > 85 }

        case .rivalDeadline:
            return game.activeRivalMoves.contains { move in
                !move.resolution.isResolved && move.deadlineTurn <= game.turnNumber + 1
            }

        case .secessionCrisis:
            // A region is drifting toward (or has reached) open secession — the
            // moment the player needs the deploy-troops / martial-law levers.
            return game.regions.contains { $0.secessionProgress > 0 && $0.status != .seceded }
        }
    }

    // MARK: - Severity

    /// 0-100 severity. Clamped at both ends. Higher = more urgent.
    func severity(for crisis: CrisisType, in game: Game) -> Int {
        let raw: Int
        switch crisis {
        case .stabilityCollapse:
            raw = 100 - (game.stability * 4)

        case .treasuryCrisis:
            raw = 100 - min(100, game.treasury * 3)

        case .coupRisk:
            raw = 100 - (game.militaryLoyalty * 4)

        case .diplomaticCrisis:
            raw = game.worldTension

        case .resourceCatastrophe:
            let count = max(
                game.lastSupplyChainResult?.shortfallBySector.count ?? 0,
                game.lastSupplyChainResult?.deficitResources.count ?? 0
            )
            raw = min(100, count * 25)

        case .rivalDeadline:
            // Find the soonest unresolved move and grade off that.
            let soonest = game.activeRivalMoves
                .filter { !$0.resolution.isResolved }
                .map { $0.deadlineTurn }
                .min() ?? (game.turnNumber + 2)
            if soonest <= game.turnNumber { raw = 100 }
            else if soonest == game.turnNumber + 1 { raw = 60 }
            else { raw = 0 }

        case .secessionCrisis:
            // Grade off the most-advanced secession (100 = about to leave).
            raw = game.regions.map { $0.secessionProgress }.max() ?? 0
        }
        return max(0, min(100, raw))
    }

    // MARK: - Option Lookup

    /// Options for the crisis filtered to those currently available given
    /// the player's AP / treasury / decree charges / stat thresholds.
    func availableOptions(for crisis: CrisisType, in game: Game) -> [CrisisResponseOption] {
        optionLibrary(for: crisis).filter { $0.isAvailable(in: game) }
    }

    // MARK: - Execution

    /// Apply costs, roll deterministically, apply effects, log a GameEvent,
    /// return the result. If `option.isAvailable(in:)` is false, returns a
    /// non-success result describing the shortage — no costs paid.
    func executeOption(_ option: CrisisResponseOption, in game: Game) -> CrisisResponseResult {
        // 1. Eligibility gate — surface a useful "why not" before charging anything.
        guard option.isAvailable(in: game) else {
            return CrisisResponseResult(
                success: false,
                crisisType: option.crisisType,
                optionId: option.id,
                narrative: ineligibilityReason(for: option, in: game),
                statChanges: [:]
            )
        }

        // 2. Pay costs.
        game.actionPoints -= option.costAP
        if option.costTreasury > 0 {
            game.applyStat("treasury", change: -option.costTreasury)
        }
        if option.requiresDecreeCharge {
            game.decreeChargesRemaining = max(0, game.decreeChargesRemaining - 1)
        }

        // 3. Roll for success against the deterministic stream.
        var rng = game.rng
        let roll = Double.random(in: 0..<1, using: &rng)
        game.rng = rng
        let didSucceed = roll < option.baseSuccessChance

        // 4. Apply stat deltas from the appropriate branch.
        let deltas = didSucceed ? option.onSuccess : option.onFailure
        for (key, change) in deltas where change != 0 {
            game.applyStat(key, change: change)
        }

        // 5. Flags fire only on success (failure shouldn't unlock things).
        if didSucceed {
            for raw in option.setsFlags {
                let resolved = raw.replacingOccurrences(of: "\\(turn)", with: "\(game.turnNumber)")
                if !game.flags.contains(resolved) {
                    game.flags.append(resolved)
                }
            }
        }

        // 5b. Side-effects that aren't pure stat deltas. The flag set in step
        // 5 records intent for the audit trail; this is where we actually
        // mutate other game state. Add new option-specific side-effects here
        // as the crisis library grows.
        if didSucceed {
            applyOptionSideEffects(option: option, game: game)
        }

        // 6. GameEvent — importance 8 so it's likely to feed AI prompt context.
        let narrative = didSucceed ? option.narrativeSuccess : option.narrativeFailure
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .crisis,
            summary: "Crisis Response (\(option.crisisType.displayName)): \(option.label) — \(didSucceed ? "succeeded" : "failed")"
        )
        event.importance = 8
        event.details = [
            "kind": "crisis_response",
            "optionId": option.id,
            "crisisType": option.crisisType.rawValue,
            "success": didSucceed ? "true" : "false"
        ]
        event.game = game
        game.events.append(event)

        // 7. Hand back the structured result.
        return CrisisResponseResult(
            success: didSucceed,
            crisisType: option.crisisType,
            optionId: option.id,
            narrative: narrative,
            statChanges: deltas
        )
    }

    /// Per-option non-stat side effects fired only on success. Keep this
    /// list short — most options should express their effect as stat
    /// deltas in `onSuccess`. This hook is for things stats can't model
    /// (mutating other persisted state, scheduling future systems, etc.).
    private func applyOptionSideEffects(option: CrisisResponseOption, game: Game) {
        switch option.id {
        case "request_extension_decree":
            // Bump the most imminent unresolved RivalMove deadline by 2
            // turns. We pick the move with the smallest deadlineTurn so the
            // extension actually helps the closest threat, not a random one.
            var moves = game.activeRivalMoves
            let pending = moves.enumerated().filter { !$0.element.resolution.isResolved }
            if let target = pending.min(by: { $0.element.deadlineTurn < $1.element.deadlineTurn }) {
                moves[target.offset].deadlineTurn += 2
                game.activeRivalMoves = moves
            }

        case "sell_strategic_reserves":
            // Liquidate ~25% of the player's three most-stockpiled resources
            // (at least 1 unit each if any stockpile exists). The treasury
            // bump from onSuccess is the abstracted sale proceeds; this
            // actually drains the pool so repeated use bites.
            var reserves = game.strategicReserves
            let top = reserves.sorted { $0.value > $1.value }.prefix(3)
            for (resource, amount) in top where amount > 0 {
                let sold = max(1, amount / 4)
                reserves[resource] = max(0, amount - sold)
            }
            game.strategicReserves = reserves

        case "requisition_decree":
            // Route to the canonical EmergencyDecree implementation so the
            // Crisis Response path and the SectorDetailView decree sheet
            // produce identical state changes. `force: true` bypasses the
            // grain ≤ 5 availability check because resourceCatastrophe gates
            // on 3+ shortfalls in general and may fire when grain itself
            // isn't the deficient resource. EmergencyDecree applies:
            // treasury -5, popularSupport -8, stability -3,
            // +30 grain / +20 coal / +15 steel, plus a logged GameEvent.
            // The Crisis Response onSuccess deltas top up to the original
            // net effect (stability +8, eliteLoyalty -5, popularSupport -10).
            //
            // `viaChargeAlreadyPaid: true` because this option's
            // `requiresDecreeCharge: true` already caused `executeOption`
            // to deduct one charge before reaching applyOptionSideEffects.
            // Without this flag, the charge would be double-counted.
            EmergencyDecreeService.shared.apply(.requisitionGrain, to: game, force: true, viaChargeAlreadyPaid: true)

        case "secession_deploy_troops":
            // Send troops into the most-at-risk region — raises military presence
            // and party control, slowing secessionProgress. The service applies the
            // treasury cost (gated by this option's treasury minStatRequirement).
            if let region = mostSecessionAtRisk(in: game) {
                RegionSecessionService.shared.deployTroops(to: region, game: game, level: .moderate)
            }

        case "secession_martial_law":
            // Force the region into martial law — the strongest counter, regressing
            // secessionProgress by 5/turn at a heavy stability/reputation cost.
            if let region = mostSecessionAtRisk(in: game) {
                RegionSecessionService.shared.imposeMartialLaw(on: region, game: game)
            }

        default:
            break
        }
    }

    /// The region furthest along toward secession (and not already gone) — the
    /// target for the deploy-troops / martial-law crisis responses.
    private func mostSecessionAtRisk(in game: Game) -> Region? {
        game.regions
            .filter { $0.secessionProgress > 0 && $0.status != .seceded }
            .max(by: { $0.secessionProgress < $1.secessionProgress })
    }

    /// Human-readable reason the option is gated. Order matters: surface
    /// the cheapest fix first (AP refresh next turn, treasury > decree >
    /// stat).
    private func ineligibilityReason(for option: CrisisResponseOption, in game: Game) -> String {
        if game.actionPoints < option.costAP {
            return "Insufficient action points (need \(option.costAP), have \(game.actionPoints))."
        }
        if option.costTreasury > 0 && game.treasury < option.costTreasury {
            return "Treasury too low (need \(option.costTreasury), have \(game.treasury))."
        }
        if option.requiresDecreeCharge && game.decreeChargesRemaining <= 0 {
            return "No decree charges remaining."
        }
        for (key, required) in option.minStatRequirements {
            return "Requires \(key) ≥ \(required)."
        }
        return "Not currently available."
    }

    // MARK: - Option Library

    private func optionLibrary(for crisis: CrisisType) -> [CrisisResponseOption] {
        switch crisis {
        case .stabilityCollapse:    return stabilityCollapseOptions
        case .treasuryCrisis:       return treasuryCrisisOptions
        case .resourceCatastrophe:  return resourceCatastropheOptions
        case .coupRisk:             return coupRiskOptions
        case .diplomaticCrisis:     return diplomaticCrisisOptions
        case .rivalDeadline:        return rivalDeadlineOptions
        case .secessionCrisis:      return secessionCrisisOptions
        }
    }

    // MARK: -- Secession Crisis Library

    /// Re-homed here from the (deleted) regional economy view: deploying troops
    /// and imposing martial law are the only mechanics that REGRESS a region's
    /// secessionProgress, and secession is a power problem, not an economy one.
    /// The actual region mutation runs in applyOptionSideEffects via
    /// RegionSecessionService; treasury is gated here and spent there.
    private let secessionCrisisOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "secession_deploy_troops",
            crisisType: .secessionCrisis,
            label: "[DEPLOY TROOPS]",
            shortDescription: "Send the army into the most restive region to slow the breakaway.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: ["treasury": 15, "militaryLoyalty": 25],
            baseSuccessChance: 0.92,
            onSuccess: [:],
            onFailure: ["stability": -3],
            setsFlags: [],
            narrativeSuccess: "Columns of troops roll into the province. Garrisons swell, party control tightens, and the secession loses momentum — for now.",
            narrativeFailure: "The deployment bogs down; local cadres stall the columns and the breakaway gathers pace."
        ),
        CrisisResponseOption(
            id: "secession_martial_law",
            crisisType: .secessionCrisis,
            label: "[MARTIAL LAW]",
            shortDescription: "Impose martial law on the breakaway region. The strongest secession counter — at a heavy cost.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: ["treasury": 20, "militaryLoyalty": 30],
            baseSuccessChance: 0.95,
            onSuccess: [:],
            onFailure: ["stability": -4, "internationalStanding": -3],
            setsFlags: [],
            narrativeSuccess: "Martial law is declared. Curfews, checkpoints, and military courts crush the autonomy movement — the secession reverses, but the world condemns the tanks in the streets.",
            narrativeFailure: "The martial-law decree is defied; the region's leaders go underground and the standoff hardens."
        )
    ]

    // MARK: -- Stability Collapse Library

    private let stabilityCollapseOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "crackdown",
            crisisType: .stabilityCollapse,
            label: "[CRACKDOWN]",
            shortDescription: "Deploy security forces to break up protests by force.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.85,
            onSuccess: ["stability": 15, "popularSupport": -5, "eliteLoyalty": 3],
            onFailure: ["stability": -3, "popularSupport": -8],
            setsFlags: [],
            narrativeSuccess: "Security forces disperse demonstrations; order returns at the cost of public goodwill.",
            narrativeFailure: "The crackdown turns ugly; cameras capture every baton swing."
        ),
        CrisisResponseOption(
            id: "emergency_welfare",
            crisisType: .stabilityCollapse,
            label: "[EMERGENCY WELFARE]",
            shortDescription: "Rush rations, subsidies, and pension top-ups into restive districts.",
            costAP: 1,
            costTreasury: 20,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.90,
            onSuccess: ["stability": 10, "popularSupport": 5],
            onFailure: ["stability": 2],
            setsFlags: [],
            narrativeSuccess: "Emergency rations and subsidies pour into restive districts. The streets quiet.",
            narrativeFailure: "Aid trucks arrive late; the gesture is noted but the anger remains."
        ),
        CrisisResponseOption(
            id: "find_scapegoat",
            crisisType: .stabilityCollapse,
            label: "[FIND SCAPEGOAT]",
            shortDescription: "Pin the disorder on a mid-level official and parade them.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: ["eliteLoyalty": 30],
            baseSuccessChance: 0.70,
            onSuccess: ["stability": 8, "eliteLoyalty": 3, "popularSupport": 2],
            onFailure: ["stability": -3, "eliteLoyalty": -5],
            setsFlags: ["scapegoat_used_turn_\\(turn)"],
            narrativeSuccess: "A minor official is identified as the source of disorder. The public has its villain.",
            narrativeFailure: "The scapegoat refuses to play the role. Whispers turn upward, toward the Chairman."
        ),
        CrisisResponseOption(
            id: "martial_law",
            crisisType: .stabilityCollapse,
            label: "[MARTIAL LAW]",
            shortDescription: "Suspend civil authority. The army restores order at any cost.",
            costAP: 2,
            costTreasury: 0,
            requiresDecreeCharge: true,
            minStatRequirements: [:],
            baseSuccessChance: 0.95,
            onSuccess: ["stability": 25, "popularSupport": -10, "internationalStanding": -10, "eliteLoyalty": -5],
            onFailure: ["stability": 5, "popularSupport": -15, "internationalStanding": -15],
            setsFlags: ["martial_law_declared_turn_\\(turn)"],
            narrativeSuccess: "Martial law declared. The republic answers to the army now.",
            narrativeFailure: "Even the army hesitates. The order is given, but enforcement is patchy."
        ),
        CrisisResponseOption(
            id: "address_nation",
            crisisType: .stabilityCollapse,
            label: "[ADDRESS NATION]",
            shortDescription: "Speak directly to the people. Calm with words, not batons.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: ["popularSupport": 50],
            baseSuccessChance: 0.60,
            onSuccess: ["stability": 8, "popularSupport": 5],
            onFailure: ["stability": 2, "popularSupport": -5],
            setsFlags: [],
            narrativeSuccess: "Chairman addresses the nation. The speech lands — for now.",
            narrativeFailure: "The address airs. Half the country mutes it; the other half mocks the cadence."
        )
    ]

    // MARK: -- Treasury Crisis Library

    private let treasuryCrisisOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "emergency_loan_bloc",
            crisisType: .treasuryCrisis,
            label: "[BLOC LOAN]",
            shortDescription: "Request emergency credit from the Socialist Bloc at favourable terms.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.90,
            onSuccess: ["treasury": 60],
            onFailure: ["treasury": 15, "patronFavor": -5],
            setsFlags: ["took_emergency_bloc_loan"],
            narrativeSuccess: "Socialist Bloc extends an emergency credit line at favourable terms.",
            narrativeFailure: "The line is offered, but the terms tighten. A token transfer arrives anyway."
        ),
        CrisisResponseOption(
            id: "austerity_decree",
            crisisType: .treasuryCrisis,
            label: "[AUSTERITY DECREE]",
            shortDescription: "Suspend capital projects, cut pensions, defer salaries.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: true,
            minStatRequirements: [:],
            baseSuccessChance: 1.0,
            onSuccess: ["treasury": 50, "popularSupport": -20, "eliteLoyalty": -5],
            onFailure: [:],
            setsFlags: ["austerity_decree_active"],
            narrativeSuccess: "Capital projects suspended, pensions cut, salaries deferred. Books balance, briefly.",
            narrativeFailure: ""
        ),
        CrisisResponseOption(
            id: "sell_strategic_reserves",
            crisisType: .treasuryCrisis,
            label: "[SELL RESERVES]",
            shortDescription: "Dump strategic reserves on world markets for hard currency.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.85,
            onSuccess: ["treasury": 35],
            onFailure: ["treasury": 10, "internationalStanding": -3],
            setsFlags: ["sold_strategic_reserves"],
            narrativeSuccess: "Strategic reserves liquidated below market rate. Cash on hand; questions later.",
            narrativeFailure: "Buyers smell desperation. The sale clears for pennies on the rouble."
        ),
        CrisisResponseOption(
            id: "suspend_projects",
            crisisType: .treasuryCrisis,
            label: "[SUSPEND PROJECTS]",
            shortDescription: "Indefinitely hold all pending capital projects.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.95,
            onSuccess: ["treasury": 30, "popularSupport": -5, "industrialOutput": -5],
            onFailure: ["treasury": 10, "industrialOutput": -3],
            setsFlags: ["projects_suspended_turn_\\(turn)"],
            narrativeSuccess: "Pending capital projects placed on indefinite hold. Site directors are not pleased.",
            narrativeFailure: "Half the projects are too far along to stop cleanly. Savings shrink to a trickle."
        ),
        CrisisResponseOption(
            id: "western_imf_loan",
            crisisType: .treasuryCrisis,
            label: "[WESTERN LOAN]",
            shortDescription: "Accept Western credit. The patron will hear about it.",
            costAP: 2,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.75,
            onSuccess: ["treasury": 80, "patronFavor": -15, "internationalStanding": 5],
            onFailure: ["treasury": 20, "patronFavor": -10],
            setsFlags: ["western_loan_taken"],
            narrativeSuccess: "Western lenders offered access. Your patron disapproves, but the wire clears.",
            narrativeFailure: "Terms collapse over conditions. A token disbursement lands; the patron noticed anyway."
        )
    ]

    // MARK: -- Resource Catastrophe Library

    private let resourceCatastropheOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "emergency_imports",
            crisisType: .resourceCatastrophe,
            label: "[EMERGENCY IMPORTS]",
            shortDescription: "Pay top dollar to rush replacement materials in from allies.",
            costAP: 1,
            costTreasury: 25,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.85,
            onSuccess: ["stability": 5, "popularSupport": 3],
            onFailure: ["popularSupport": -3],
            setsFlags: ["emergency_imports_activated"],
            narrativeSuccess: "Allied nations rush emergency shipments to plug the deficit.",
            narrativeFailure: "Convoys move slow; the gap widens before relief arrives."
        ),
        CrisisResponseOption(
            id: "requisition_decree",
            crisisType: .resourceCatastrophe,
            label: "[REQUISITION DECREE]",
            shortDescription: "Forced collection of grain and materials from the regions.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: true,
            minStatRequirements: [:],
            baseSuccessChance: 1.0,
            // Stat top-ups only. The underlying EmergencyDecree.requisitionGrain
            // applies treasury -5, popularSupport -8, stability -3 via
            // applyOptionSideEffects below — these deltas reflect the additional
            // crisis-mitigation framing (stability bump for plugging the
            // catastrophe, deeper elite/popular costs). Net effect after both
            // paths: stability +8, eliteLoyalty -5, popularSupport -10, treasury -5.
            onSuccess: ["stability": 11, "eliteLoyalty": -5, "popularSupport": -2],
            onFailure: [:],
            setsFlags: ["requisition_active"],
            narrativeSuccess: "Forced grain and material requisitions across the regions. Sirens at dawn.",
            narrativeFailure: ""
        ),
        CrisisResponseOption(
            id: "black_market_tolerance",
            crisisType: .resourceCatastrophe,
            label: "[TOLERATE BLACK MARKET]",
            shortDescription: "Look the other way while informal supply chains fill the gap.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.85,
            onSuccess: ["stability": 5, "popularSupport": 2, "corruptionEvidence": 10],
            onFailure: ["corruptionEvidence": 15],
            setsFlags: ["black_market_tolerated"],
            narrativeSuccess: "The Chairman looks the other way; goods appear from nowhere. Notebooks fill in offices.",
            narrativeFailure: "Tolerance becomes evidence. The wrong people start keeping receipts."
        ),
        CrisisResponseOption(
            id: "cross_bloc_appeal",
            crisisType: .resourceCatastrophe,
            label: "[CROSS-BLOC APPEAL]",
            shortDescription: "Public appeal to fellow socialist states for emergency aid.",
            costAP: 2,
            costTreasury: 10,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.55,
            onSuccess: ["stability": 6, "patronFavor": 5, "internationalStanding": 3],
            onFailure: ["patronFavor": -5],
            setsFlags: ["cross_bloc_appeal_made"],
            narrativeSuccess: "Diplomatic appeals to fellow socialist states bear fruit. Aid arrives with cameras.",
            narrativeFailure: "Diplomatic appeals echo unanswered. The asking is itself a kind of weakness."
        )
    ]

    // MARK: -- Coup Risk Library

    private let coupRiskOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "promote_loyalist_general",
            crisisType: .coupRisk,
            label: "[PROMOTE LOYALIST]",
            shortDescription: "Elevate a trusted general to Chief of Staff.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.80,
            onSuccess: ["militaryLoyalty": 12, "eliteLoyalty": 2],
            onFailure: ["militaryLoyalty": 3],
            setsFlags: ["loyalist_general_promoted_turn_\\(turn)"],
            narrativeSuccess: "A trusted general is elevated to Chief of Staff. The brass calibrates.",
            narrativeFailure: "The promotion is announced; the messroom commentary is less than enthusiastic."
        ),
        CrisisResponseOption(
            id: "military_pay_raise",
            crisisType: .coupRisk,
            label: "[PAY RAISE]",
            shortDescription: "Increase officer pay immediately. The message is unsubtle.",
            costAP: 1,
            costTreasury: 30,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.95,
            onSuccess: ["militaryLoyalty": 15],
            onFailure: ["militaryLoyalty": 5],
            setsFlags: ["military_pay_raise_turn_\\(turn)"],
            narrativeSuccess: "Officer pay rises immediately. The message is unsubtle and well received.",
            narrativeFailure: "The raise is announced; junior officers do the maths and conclude it isn't enough."
        ),
        CrisisResponseOption(
            id: "arrest_plotters_decree",
            crisisType: .coupRisk,
            label: "[ARREST PLOTTERS]",
            shortDescription: "Pre-dawn raids on suspected coup plotters. Risky business.",
            costAP: 2,
            costTreasury: 0,
            requiresDecreeCharge: true,
            minStatRequirements: [:],
            baseSuccessChance: 0.65,
            onSuccess: ["militaryLoyalty": 25, "internationalStanding": -5],
            onFailure: ["militaryLoyalty": -15, "eliteLoyalty": -10],
            setsFlags: ["plotters_arrested"],
            narrativeSuccess: "Pre-dawn raids on suspected coup plotters. The threat is decapitated.",
            narrativeFailure: "The raids hit empty apartments. Someone tipped them off. The barracks know."
        ),
        CrisisResponseOption(
            id: "military_parade",
            crisisType: .coupRisk,
            label: "[MILITARY PARADE]",
            shortDescription: "Massive parade celebrating the armed forces.",
            costAP: 1,
            costTreasury: 15,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.90,
            onSuccess: ["militaryLoyalty": 8, "popularSupport": 5],
            onFailure: ["militaryLoyalty": 2],
            setsFlags: ["military_parade_held_turn_\\(turn)"],
            narrativeSuccess: "Massive parade celebrates the armed forces. The brass enjoys the spotlight.",
            narrativeFailure: "The parade goes ahead; rain dampens both the boots and the message."
        ),
        CrisisResponseOption(
            id: "defense_budget_emergency",
            crisisType: .coupRisk,
            label: "[EMERGENCY DEFENSE BUDGET]",
            shortDescription: "Emergency allocation to fund modernisation programs.",
            costAP: 1,
            costTreasury: 40,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.95,
            onSuccess: ["militaryLoyalty": 15, "militaryReadiness": 5],
            onFailure: ["militaryLoyalty": 5],
            setsFlags: ["emergency_defense_budget_turn_\\(turn)"],
            narrativeSuccess: "Emergency defense allocation funds modernisation programs. Procurement officers smile.",
            narrativeFailure: "The funds land in the wrong sub-accounts; only some of the message reaches the brass."
        )
    ]

    // MARK: -- Diplomatic Crisis Library

    private let diplomaticCrisisOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "backchannel_diplomacy",
            crisisType: .diplomaticCrisis,
            label: "[BACKCHANNEL]",
            shortDescription: "Quiet meetings in third capitals to lower the temperature.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.60,
            onSuccess: ["worldTension": -15, "internationalStanding": 3],
            onFailure: ["worldTension": -5],
            setsFlags: ["backchannel_used_turn_\\(turn)"],
            narrativeSuccess: "Quiet meetings in third capitals lower the temperature.",
            narrativeFailure: "Talks happen. Nothing leaks; nothing changes."
        ),
        CrisisResponseOption(
            id: "show_of_force",
            crisisType: .diplomaticCrisis,
            label: "[SHOW OF FORCE]",
            shortDescription: "Naval deployment sends the desired signal.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: ["militaryLoyalty": 50],
            baseSuccessChance: 0.50,
            onSuccess: ["worldTension": -10, "internationalStanding": 5, "militaryLoyalty": 3],
            onFailure: ["worldTension": 10, "internationalStanding": -10],
            setsFlags: ["show_of_force_turn_\\(turn)"],
            narrativeSuccess: "Naval deployment sends the desired signal. The rivals back off.",
            narrativeFailure: "Naval deployment sends the wrong signal. The rivals deploy back."
        ),
        CrisisResponseOption(
            id: "public_condemnation",
            crisisType: .diplomaticCrisis,
            label: "[PUBLIC CONDEMNATION]",
            shortDescription: "Rhetorical broadside aimed at the rival's audience.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.80,
            onSuccess: ["popularSupport": 5, "internationalStanding": -5, "worldTension": -5],
            onFailure: ["internationalStanding": -8],
            setsFlags: ["public_condemnation_turn_\\(turn)"],
            narrativeSuccess: "Rhetorical broadside plays well at home, less so abroad.",
            narrativeFailure: "The broadside lands flat. Allies wince; rivals laugh."
        ),
        CrisisResponseOption(
            id: "propose_summit",
            crisisType: .diplomaticCrisis,
            label: "[PROPOSE SUMMIT]",
            shortDescription: "Public proposal for a head-of-state summit.",
            costAP: 2,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 0.70,
            onSuccess: ["worldTension": -20, "internationalStanding": 8],
            onFailure: ["internationalStanding": -5],
            setsFlags: ["summit_proposed_turn_\\(turn)"],
            narrativeSuccess: "A summit proposal lands. The rivals accept; cameras are warming up.",
            narrativeFailure: "The summit proposal is publicly declined. The decline is itself a message."
        )
    ]

    // MARK: -- Rival Deadline Library

    private let rivalDeadlineOptions: [CrisisResponseOption] = [
        CrisisResponseOption(
            id: "jump_to_rival_counter",
            crisisType: .rivalDeadline,
            label: "[REVIEW COUNTER OPTIONS]",
            shortDescription: "Jump to the rival's card on the Desk and choose a counter.",
            costAP: 0,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 1.0,
            onSuccess: [:],
            onFailure: [:],
            setsFlags: ["rival_counter_requested_turn_\\(turn)"],
            narrativeSuccess: "Decision time. The Chairman walks to the Desk.",
            narrativeFailure: ""
        ),
        CrisisResponseOption(
            id: "take_no_action",
            crisisType: .rivalDeadline,
            label: "[LET IT LAND]",
            shortDescription: "Allow the rival's move to resolve unopposed. The damage is calculable.",
            costAP: 0,
            costTreasury: 0,
            requiresDecreeCharge: false,
            minStatRequirements: [:],
            baseSuccessChance: 1.0,
            onSuccess: [:],
            onFailure: [:],
            setsFlags: ["rival_explicitly_ignored_turn_\\(turn)"],
            narrativeSuccess: "You let the move land. The damage is calculable.",
            narrativeFailure: ""
        ),
        CrisisResponseOption(
            id: "request_extension_decree",
            crisisType: .rivalDeadline,
            label: "[REQUEST EXTENSION]",
            shortDescription: "Decree a further review of the matter. Buys time, not victory.",
            costAP: 1,
            costTreasury: 0,
            requiresDecreeCharge: true,
            minStatRequirements: [:],
            baseSuccessChance: 0.50,
            onSuccess: [:],
            onFailure: ["eliteLoyalty": -3],
            setsFlags: ["rival_deadline_extended_turn_\\(turn)"],
            narrativeSuccess: "By order of the Chairman, the matter is reviewed further. Two more turns.",
            narrativeFailure: "The extension is announced; the committee privately notes the stall."
        )
    ]
}
