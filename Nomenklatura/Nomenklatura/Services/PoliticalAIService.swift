//
//  PoliticalAIService.swift
//  Nomenklatura
//
//  NPC Political AI for autonomous policy changes and political behavior.
//  Creates a living political simulation where NPCs pursue their faction interests.
//

import Foundation
import os.log

private let politicalLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "PoliticalAI")

// MARK: - Political AI Service

@MainActor
class PoliticalAIService {
    static let shared = PoliticalAIService()

    private init() {}

    // MARK: - Main Turn Processing

    /// Process all NPC political activity for this turn
    /// Call this from GameEngine.endTurnUpdates()
    func processPoliticalActivity(game: Game) -> [PoliticalEvent] {
        var events: [PoliticalEvent] = []

        // 1. Process General Secretary behavior
        if let gsEvents = processGeneralSecretaryBehavior(game: game) {
            events.append(contentsOf: gsEvents)
        }

        // 2. Process Standing Committee member proposals
        if let scEvents = processStandingCommitteeProposals(game: game) {
            events.append(contentsOf: scEvents)
        }

        // 3. Process faction-driven political pressure
        if let factionEvents = processFactionPolitics(game: game) {
            events.append(contentsOf: factionEvents)
        }

        // 4. Process Foreign Affairs NPC proposals
        if let foreignEvents = processForeignAffairsProposals(game: game) {
            events.append(contentsOf: foreignEvents)
        }

        // 5. Process pending policy proposals (vote simulation)
        if let voteEvents = processPendingProposals(game: game) {
            events.append(contentsOf: voteEvents)
        }

        politicalLogger.info("Processed \(events.count) political events for turn \(game.turnNumber)")

        return events
    }

    // MARK: - General Secretary Behavior

    /// Process what the General Secretary does this turn
    /// Now integrates with GeneralSecretaryAI for strategic assessment
    private func processGeneralSecretaryBehavior(game: Game) -> [PoliticalEvent]? {
        // Find the GS character
        guard let gs = findGeneralSecretary(game: game) else {
            return nil
        }

        // Player is GS - they make their own decisions
        if game.currentPositionIndex >= GameplayConstants.Position.generalSecretaryLevel {
            return nil
        }

        var events: [PoliticalEvent] = []

        // Use GeneralSecretaryAI for strategic assessment
        let gsAI = GeneralSecretaryAI.shared
        let strategicAssessment = gsAI.assessPoliticalSituation(gs: gs, game: game)

        politicalLogger.info("GS \(gs.name) strategy: \(strategicAssessment.recommendedStrategy.rawValue)")

        // Get action from strategic AI
        if let gsAction = gsAI.selectAction(assessment: strategicAssessment, gs: gs, game: game) {
            // Execute the action based on type
            switch gsAction.type {
            case .proposePolicy:
                if let slotId = gsAction.targetSlotId, let optionId = gsAction.targetOptionId {
                    let target = PolicyChangeTarget(slotId: slotId, targetOptionId: optionId, priority: gsAction.priority)
                    let proposal = submitGSProposal(gs: gs, policy: target, game: game)
                    events.append(proposal)
                    politicalLogger.info("GS proposed policy: \(slotId) -> \(optionId)")
                }

            case .decree:
                if let slotId = gsAction.targetSlotId, let optionId = gsAction.targetOptionId {
                    let target = PolicyChangeTarget(slotId: slotId, targetOptionId: optionId, priority: gsAction.priority)
                    let result = executeGSDecree(gs: gs, policy: target, game: game)
                    events.append(result)
                    politicalLogger.info("GS decreed policy: \(slotId) -> \(optionId)")
                }

            case .targetRival:
                // Generate a political event targeting a rival
                if let targetId = gsAction.targetCharacterId {
                    let event = generateRivalTargetingEvent(gs: gs, targetId: targetId, game: game)
                    events.append(event)
                    politicalLogger.info("GS targeting rival: \(targetId)")
                }

            case .appointLoyalist:
                // Handle appointment opportunity
                let event = generateAppointmentEvent(gs: gs, game: game)
                events.append(event)
                politicalLogger.info("GS filling appointment")

            case .buildSupport:
                // Coalition building doesn't generate visible events immediately
                politicalLogger.info("GS building support - internal action")
            }
        } else {
            // Fall back to agenda-based policy selection if no strategic action
            let gsAgenda = determineGSAgenda(gs: gs, game: game)

            if let policyTarget = selectPolicyTarget(for: gsAgenda, gs: gs, game: game) {
                let shouldDecree = shouldGSDecree(gs: gs, policy: policyTarget, game: game)

                if shouldDecree {
                    let result = executeGSDecree(gs: gs, policy: policyTarget, game: game)
                    events.append(result)
                } else {
                    let proposal = submitGSProposal(gs: gs, policy: policyTarget, game: game)
                    events.append(proposal)
                }
            }
        }

        return events.isEmpty ? nil : events
    }

    /// Generate event for GS targeting a rival
    private func generateRivalTargetingEvent(gs: GameCharacter, targetId: String, game: Game) -> PoliticalEvent {
        let targetName = game.characters.first { $0.templateId == targetId }?.name ?? "Unknown"

        return PoliticalEvent(
            eventType: .politicalCrisis,
            characterId: gs.templateId,
            characterName: gs.name,
            slotId: nil,
            optionId: nil,
            narrative: "The General Secretary has initiated an investigation into \(targetName). Whispers suggest this is politically motivated.",
            consequences: [],
            turn: game.turnNumber
        )
    }

    /// Generate event for GS making an appointment
    private func generateAppointmentEvent(gs: GameCharacter, game: Game) -> PoliticalEvent {
        return PoliticalEvent(
            eventType: .proposalPassed,
            characterId: gs.templateId,
            characterName: gs.name,
            slotId: nil,
            optionId: nil,
            narrative: "\(gs.name) has appointed a loyal supporter to a key position, strengthening their control.",
            consequences: [],
            turn: game.turnNumber
        )
    }

    /// Find the current General Secretary
    private func findGeneralSecretary(game: Game) -> GameCharacter? {
        // First try to find by committee chair
        if let committee = game.standingCommittee,
           let chairId = committee.chairId {
            return game.characters.first { $0.templateId == chairId && $0.isActive }
        }

        // Otherwise find highest position character
        return game.characters
            .filter { $0.isActive && ($0.positionIndex ?? 0) >= 8 }
            .sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }
            .first
    }

    /// Determine what the GS wants based on personality and faction
    private func determineGSAgenda(gs: GameCharacter, game: Game) -> GSAgenda {
        var policyPreferences: [String: PolicyPreference] = [:]

        // Ambitious GS wants power consolidation
        if gs.personalityAmbitious > 70 {
            policyPreferences["presidium_term_limits"] = PolicyPreference(
                desiredOptionId: "term_limits_life_tenure",
                priority: 10
            )
            policyPreferences["presidium_emergency_powers"] = PolicyPreference(
                desiredOptionId: "emergency_powers_unilateral",
                priority: 8
            )
            policyPreferences["presidium_succession_rules"] = PolicyPreference(
                desiredOptionId: "succession_gs_designates",
                priority: 7
            )
        }

        // Paranoid GS wants security control
        if gs.personalityParanoid > 60 {
            policyPreferences["security_surveillance_scope"] = PolicyPreference(
                desiredOptionId: "surveillance_universal",
                priority: 9
            )
            policyPreferences["security_arrest_authority"] = PolicyPreference(
                desiredOptionId: "arrest_extrajudicial",
                priority: 8
            )
        }

        // Ruthless GS enables purges
        if gs.personalityRuthless > 70 {
            policyPreferences["security_arrest_authority"] = PolicyPreference(
                desiredOptionId: "arrest_extrajudicial",
                priority: 9
            )
        }

        // Competent GS may want economic reforms
        if gs.personalityCompetent > 70 {
            policyPreferences["economy_enterprise_management"] = PolicyPreference(
                desiredOptionId: "enterprise_manager_autonomy",
                priority: 6
            )
        }

        // Faction-based preferences
        if let factionId = gs.factionId {
            let factionPrefs = getFactionPolicyPreferences(factionId: factionId)
            for (slotId, pref) in factionPrefs {
                // Don't override higher priority preferences
                if let existing = policyPreferences[slotId], existing.priority >= pref.priority {
                    continue
                }
                policyPreferences[slotId] = pref
            }
        }

        return GSAgenda(
            gsCharacterId: gs.templateId,
            policyPreferences: policyPreferences,
            decreeThreshold: calculateDecreeThreshold(gs: gs, game: game),
            currentFocus: determineCurrentFocus(gs: gs, game: game)
        )
    }

    /// Get policy preferences based on faction ideology
    private func getFactionPolicyPreferences(factionId: String) -> [String: PolicyPreference] {
        var preferences: [String: PolicyPreference] = [:]

        switch factionId {
        case "old_guard":
            preferences["economy_enterprise_management"] = PolicyPreference(
                desiredOptionId: "enterprise_central_quotas",
                priority: 7
            )
            preferences["economy_private_enterprise"] = PolicyPreference(
                desiredOptionId: "private_enterprise_prohibited",
                priority: 8
            )
            preferences["propaganda_press_control"] = PolicyPreference(
                desiredOptionId: "press_total_control",
                priority: 6
            )
            preferences["propaganda_religious_policy"] = PolicyPreference(
                desiredOptionId: "religion_suppression",
                priority: 5
            )

        case "reformists":
            preferences["economy_enterprise_management"] = PolicyPreference(
                desiredOptionId: "enterprise_manager_autonomy",
                priority: 7
            )
            preferences["economy_private_enterprise"] = PolicyPreference(
                desiredOptionId: "private_enterprise_licensed",
                priority: 8
            )
            preferences["economy_foreign_trade"] = PolicyPreference(
                desiredOptionId: "trade_joint_ventures",
                priority: 6
            )
            preferences["propaganda_press_control"] = PolicyPreference(
                desiredOptionId: "press_limited_freedom",
                priority: 5
            )

        case "princelings":
            preferences["presidium_succession_rules"] = PolicyPreference(
                desiredOptionId: "succession_gs_designates",
                priority: 6
            )
            preferences["military_budget_control"] = PolicyPreference(
                desiredOptionId: "military_general_staff",
                priority: 7
            )
            preferences["economy_foreign_trade"] = PolicyPreference(
                desiredOptionId: "trade_open_zones",
                priority: 5
            )

        case "youth_league":
            preferences["congress_delegate_selection"] = PolicyPreference(
                desiredOptionId: "delegates_elected",
                priority: 7
            )
            preferences["congress_legislative_power"] = PolicyPreference(
                desiredOptionId: "legislative_genuine_input",
                priority: 6
            )
            preferences["regions_governor_appointment"] = PolicyPreference(
                desiredOptionId: "governors_regional_election",
                priority: 5
            )

        case "regional":
            preferences["regions_regional_autonomy"] = PolicyPreference(
                desiredOptionId: "autonomy_economic",
                priority: 9
            )
            preferences["regions_resource_revenue"] = PolicyPreference(
                desiredOptionId: "revenue_regional_retention",
                priority: 8
            )
            preferences["regions_governor_appointment"] = PolicyPreference(
                desiredOptionId: "governors_local_nomination",
                priority: 7
            )

        default:
            break
        }

        return preferences
    }

    /// Calculate how likely GS is to use decrees vs proposals
    private func calculateDecreeThreshold(gs: GameCharacter, game: Game) -> Int {
        var threshold = 60  // Base: need 60+ power to decree

        // Ambitious GS decrees more readily
        if gs.personalityAmbitious > 70 {
            threshold -= 15
        }

        // Cautious/loyal personalities avoid decrees
        if gs.personalityLoyal > 60 {
            threshold += 10
        }

        // High stability = less need for decrees
        if game.stability > 70 {
            threshold += 10
        }

        // Low stability = more emergency action
        if game.stability < 40 {
            threshold -= 15
        }

        return max(40, min(80, threshold))
    }

    /// Determine what the GS is currently focused on
    private func determineCurrentFocus(gs: GameCharacter, game: Game) -> GSFocus {
        // Crisis handling takes priority
        if game.stability < 30 {
            return .stabilization
        }

        // Ambitious GS focuses on consolidation
        if gs.personalityAmbitious > 70 && game.powerConsolidationScore < 70 {
            return .powerConsolidation
        }

        // Competent GS focuses on reforms when stable
        if gs.personalityCompetent > 60 && game.stability > 60 {
            return .economicReform
        }

        // Paranoid GS focuses on security
        if gs.personalityParanoid > 60 {
            return .securityControl
        }

        // Default: maintain status quo
        return .maintenance
    }

    /// Select a policy the GS wants to change
    private func selectPolicyTarget(for agenda: GSAgenda, gs: GameCharacter, game: Game) -> PolicyChangeTarget? {
        // Roll chance to act this turn (not every turn)
        let actChance = min(30, 10 + gs.personalityAmbitious / 5)
        guard Int.random(in: 1...100) <= actChance else {
            return nil
        }

        // Filter preferences to those that aren't already active
        let actionable = agenda.policyPreferences.compactMap { (slotId, pref) -> (String, PolicyPreference)? in
            guard let slot = game.policySlot(withId: slotId) else { return nil }
            guard slot.currentOptionId != pref.desiredOptionId else { return nil }

            // Check if GS can actually make this change
            let factionStandings = getFactionStandings(game: game)
            let (canChange, _) = slot.canChange(
                to: pref.desiredOptionId,
                playerPower: 80,  // GS has high effective power
                playerPosition: 8,
                factionStandings: factionStandings
            )

            return canChange ? (slotId, pref) : nil
        }

        guard !actionable.isEmpty else { return nil }

        // Select highest priority actionable preference
        let sorted = actionable.sorted { $0.1.priority > $1.1.priority }
        guard let (slotId, pref) = sorted.first else { return nil }

        return PolicyChangeTarget(
            slotId: slotId,
            targetOptionId: pref.desiredOptionId,
            priority: pref.priority
        )
    }

    /// Decide if GS should decree (bypass SC) or propose normally
    private func shouldGSDecree(gs: GameCharacter, policy: PolicyChangeTarget, game: Game) -> Bool {
        // Can't decree institutional changes
        if let slot = game.policySlot(withId: policy.slotId),
           slot.category == .institutional {
            return false
        }

        // Check if decrees are enabled
        guard game.decreesEnabled else { return false }

        // Calculate GS power
        let gsPower = calculateGSPower(gs: gs, game: game)
        let decreeThreshold = calculateDecreeThreshold(gs: gs, game: game)

        // High priority + high power = decree
        if policy.priority >= 8 && gsPower > decreeThreshold {
            return true
        }

        // Low stability + urgent policy = decree
        if game.stability < 40 && policy.priority >= 7 {
            return gsPower > (decreeThreshold - 10)
        }

        return false
    }

    /// Calculate GS's effective political power
    private func calculateGSPower(gs: GameCharacter, game: Game) -> Int {
        var power = 50  // Base

        // Position gives power
        power += 30

        // Faction support
        if let factionId = gs.factionId,
           let faction = game.factions.first(where: { $0.factionId == factionId }) {
            power += faction.power / 3
        }

        // Committee support
        if let committee = game.standingCommittee {
            let factionBalance = committee.factionBalance
            if let gsFaction = gs.factionId,
               let factionSeats = factionBalance[gsFaction] {
                power += factionSeats * 5
            }
        }

        // Stability affects GS power
        power += (game.stability - 50) / 5

        return max(30, min(100, power))
    }

    /// Execute a GS decree (bypass Standing Committee)
    private func executeGSDecree(gs: GameCharacter, policy: PolicyChangeTarget, game: Game) -> PoliticalEvent {
        let result = PolicyService.shared.changePolicy(
            game: game,
            slotId: policy.slotId,
            toOptionId: policy.targetOptionId,
            byCharacterId: gs.templateId,
            byPlayer: false,
            asDecree: true
        )

        politicalLogger.info("GS \(gs.name) decreed policy change: \(result.message)")

        return PoliticalEvent(
            eventType: .gsDecree,
            characterId: gs.templateId,
            characterName: gs.name,
            slotId: policy.slotId,
            optionId: policy.targetOptionId,
            narrative: "The General Secretary has issued a decree: \(result.message)",
            consequences: result.consequences,
            turn: game.turnNumber
        )
    }

    /// Submit a proposal from GS to the Standing Committee
    private func submitGSProposal(gs: GameCharacter, policy: PolicyChangeTarget, game: Game) -> PoliticalEvent {
        guard let slot = game.policySlot(withId: policy.slotId) else {
            return PoliticalEvent(
                eventType: .proposalSubmitted,
                characterId: gs.templateId,
                characterName: gs.name,
                slotId: policy.slotId,
                optionId: policy.targetOptionId,
                narrative: "Policy proposal failed - slot not found",
                consequences: [],
                turn: game.turnNumber
            )
        }

        slot.proposeChange(
            optionId: policy.targetOptionId,
            characterId: gs.templateId,
            turn: game.turnNumber
        )

        let optionName = slot.option(withId: policy.targetOptionId)?.name ?? "Unknown Policy"

        politicalLogger.info("GS \(gs.name) proposed policy change: \(optionName)")

        return PoliticalEvent(
            eventType: .proposalSubmitted,
            characterId: gs.templateId,
            characterName: gs.name,
            slotId: policy.slotId,
            optionId: policy.targetOptionId,
            narrative: "\(gs.name) has proposed changing \(slot.name) to \(optionName). The Standing Committee will vote.",
            consequences: [],
            turn: game.turnNumber
        )
    }

    // MARK: - Standing Committee Member Proposals

    /// Process proposals from SC members (not GS)
    private func processStandingCommitteeProposals(game: Game) -> [PoliticalEvent]? {
        guard let committee = game.standingCommittee else { return nil }

        var events: [PoliticalEvent] = []

        // Each SC member has a small chance to propose something
        for memberId in committee.memberIds {
            // Skip the GS (handled separately)
            if memberId == committee.chairId { continue }

            guard let member = game.characters.first(where: { $0.templateId == memberId && $0.isActive }) else {
                continue
            }

            // Low chance per member per turn
            let proposeChance = 5 + member.personalityAmbitious / 10
            guard Int.random(in: 1...100) <= proposeChance else { continue }

            // Find a policy this member's faction would like
            if let factionId = member.factionId,
               let proposal = selectFactionPolicy(factionId: factionId, member: member, game: game) {

                guard let slot = game.policySlot(withId: proposal.slotId) else { continue }

                slot.proposeChange(
                    optionId: proposal.targetOptionId,
                    characterId: member.templateId,
                    turn: game.turnNumber
                )

                let optionName = slot.option(withId: proposal.targetOptionId)?.name ?? "Unknown"

                events.append(PoliticalEvent(
                    eventType: .proposalSubmitted,
                    characterId: member.templateId,
                    characterName: member.name,
                    slotId: proposal.slotId,
                    optionId: proposal.targetOptionId,
                    narrative: "\(member.name) has submitted a proposal to the Standing Committee: change \(slot.name) to \(optionName).",
                    consequences: [],
                    turn: game.turnNumber
                ))

                politicalLogger.info("SC member \(member.name) proposed: \(optionName)")
            }
        }

        return events.isEmpty ? nil : events
    }

    /// Select a policy for a faction member to propose
    private func selectFactionPolicy(factionId: String, member: GameCharacter, game: Game) -> PolicyChangeTarget? {
        let factionPrefs = getFactionPolicyPreferences(factionId: factionId)

        let actionable = factionPrefs.compactMap { (slotId, pref) -> PolicyChangeTarget? in
            guard let slot = game.policySlot(withId: slotId) else { return nil }
            guard slot.currentOptionId != pref.desiredOptionId else { return nil }

            // Don't propose if already pending
            guard !slot.hasPendingProposal else { return nil }

            // SC members can't propose institutional changes
            if slot.category == .institutional { return nil }

            return PolicyChangeTarget(
                slotId: slotId,
                targetOptionId: pref.desiredOptionId,
                priority: pref.priority
            )
        }

        // Return highest priority actionable
        return actionable.sorted { $0.priority > $1.priority }.first
    }

    // MARK: - Faction Politics

    /// Process faction-level political pressure and maneuvering
    private func processFactionPolitics(game: Game) -> [PoliticalEvent]? {
        var events: [PoliticalEvent] = []

        for faction in game.factions {
            // Strong factions may pressure for policy changes
            if faction.power >= 60 {
                if let event = processFactionPressure(faction: faction, game: game) {
                    events.append(event)
                }
            }

            // Weak factions may form coalitions
            if faction.power < 40 {
                processCoalitionBuilding(faction: faction, game: game)
            }
        }

        return events.isEmpty ? nil : events
    }

    /// A powerful faction pressures for policy changes
    private func processFactionPressure(faction: GameFaction, game: Game) -> PoliticalEvent? {
        // Low chance per turn
        guard Int.random(in: 1...100) <= 5 else { return nil }

        let factionPrefs = getFactionPolicyPreferences(factionId: faction.factionId)

        // Find a policy they want that isn't currently active
        for (slotId, pref) in factionPrefs {
            guard let slot = game.policySlot(withId: slotId) else { continue }
            guard slot.currentOptionId != pref.desiredOptionId else { continue }

            let optionName = slot.option(withId: pref.desiredOptionId)?.name ?? "Unknown"

            return PoliticalEvent(
                eventType: .factionPressure,
                characterId: nil,
                characterName: faction.name,
                slotId: slotId,
                optionId: pref.desiredOptionId,
                narrative: "The \(faction.name) faction is pushing for \(optionName). Their influence in the corridors of power grows.",
                consequences: [],
                turn: game.turnNumber
            )
        }

        return nil
    }

    /// Weak factions try to build coalitions
    private func processCoalitionBuilding(faction: GameFaction, game: Game) {
        // This affects voting behavior but doesn't generate events
        // Coalition state is tracked implicitly through faction standings
    }

    // MARK: - Foreign Affairs NPC Proposals

    /// Process proposals from Foreign Affairs track NPCs
    /// These officials can propose foreign policy changes and submit diplomatic agenda items
    private func processForeignAffairsProposals(game: Game) -> [PoliticalEvent]? {
        var events: [PoliticalEvent] = []

        // Find Foreign Affairs track officials
        let foreignAffairsOfficials = game.characters.filter { character in
            guard character.isActive else { return false }
            let track = character.positionTrack ?? ""
            return track == "foreignAffairs" || track == "diplomatic"
        }

        for official in foreignAffairsOfficials {
            let positionIndex = official.positionIndex ?? 0

            // Only Position 5+ officials can propose foreign policy changes
            guard positionIndex >= 5 else { continue }

            // Check if this official has the proposeForeignPolicy goal
            let hasForeignPolicyGoal = official.npcGoals.contains {
                $0.goalType == .proposeForeignPolicy && $0.isActive
            }

            // Base proposal chance
            var proposeChance = 5 + official.personalityAmbitious / 10

            // Higher chance if they have the goal
            if hasForeignPolicyGoal {
                proposeChance += 15
            }

            // Lower chance if already pending proposals
            if game.policySlots.contains(where: { $0.hasPendingProposal && $0.pendingProposalCharacterId == official.templateId }) {
                proposeChance = 0  // Don't propose if they already have one pending
            }

            guard Int.random(in: 1...100) <= proposeChance else { continue }

            // Determine what type of proposal to make
            if let proposal = selectForeignPolicyProposal(official: official, game: game) {
                let event = submitForeignPolicyProposal(official: official, proposal: proposal, game: game)
                events.append(event)

                politicalLogger.info("Foreign Affairs official \(official.name) proposed: \(proposal.type)")

                // Update goal progress if they have the foreign policy goal
                if hasForeignPolicyGoal,
                   let goalId = official.npcGoals.first(where: { $0.goalType == .proposeForeignPolicy })?.id {
                    official.updateGoalProgress(goalId: goalId, progress: 50, attempt: true, currentTurn: game.turnNumber)
                }
            }
        }

        // Also check for diplomatic agenda items (treaty proposals, etc.)
        if let agendaEvents = processDiplomaticAgendaItems(game: game) {
            events.append(contentsOf: agendaEvents)
        }

        return events.isEmpty ? nil : events
    }

    /// Select a foreign policy proposal for an official to make
    private func selectForeignPolicyProposal(official: GameCharacter, game: Game) -> ForeignPolicyProposal? {
        var proposals: [ForeignPolicyProposal] = []

        // Check current international situation
        let hasHighTension = game.foreignCountries.contains { $0.diplomaticTension > 60 }
        let hasWeakAllies = game.foreignCountries.contains {
            $0.politicalBloc == .socialist && $0.relationshipScore < 50
        }
        let hasTradeOpportunities = game.foreignCountries.contains {
            $0.politicalBloc != .capitalist && $0.relationshipScore > 40
        }

        // Policy slot proposals (foreign policy slots)
        for slot in game.policySlots where slot.institution == .foreign {
            // Skip if already at desired state
            if let desiredOption = selectDesiredForeignOption(slot: slot, official: official, game: game),
               slot.currentOptionId != desiredOption {

                let factionStandings = getFactionStandings(game: game)
                let (canChange, _) = slot.canChange(
                    to: desiredOption,
                    playerPower: 60,  // Senior officials have moderate power
                    playerPosition: official.positionIndex ?? 5,
                    factionStandings: factionStandings
                )

                if canChange && !slot.hasPendingProposal {
                    let optionName = slot.option(withId: desiredOption)?.name ?? "Unknown"
                    proposals.append(ForeignPolicyProposal(
                        type: .policyChange,
                        slotId: slot.slotId,
                        optionId: desiredOption,
                        targetCountryId: nil,
                        priority: 6,
                        description: "Change \(slot.name) to \(optionName)"
                    ))
                }
            }
        }

        // Treaty proposals (submit to Standing Committee agenda)
        if hasWeakAllies {
            if let ally = game.foreignCountries.first(where: {
                $0.politicalBloc == .socialist && $0.relationshipScore < 50
            }) {
                proposals.append(ForeignPolicyProposal(
                    type: .treatyProposal,
                    slotId: nil,
                    optionId: nil,
                    targetCountryId: ally.countryId,
                    priority: 7,
                    description: "Strengthen alliance with \(ally.name)"
                ))
            }
        }

        // Crisis response proposals
        if hasHighTension {
            if let crisisCountry = game.foreignCountries.first(where: { $0.diplomaticTension > 60 }) {
                proposals.append(ForeignPolicyProposal(
                    type: .crisisResponse,
                    slotId: nil,
                    optionId: nil,
                    targetCountryId: crisisCountry.countryId,
                    priority: 8,
                    description: "Address tensions with \(crisisCountry.name)"
                ))
            }
        }

        // Trade initiative proposals
        if hasTradeOpportunities {
            if let partner = game.foreignCountries.first(where: {
                $0.politicalBloc != .capitalist && $0.relationshipScore > 40
            }) {
                proposals.append(ForeignPolicyProposal(
                    type: .tradeInitiative,
                    slotId: nil,
                    optionId: nil,
                    targetCountryId: partner.countryId,
                    priority: 5,
                    description: "Expand trade with \(partner.name)"
                ))
            }
        }

        // Select highest priority proposal
        return proposals.sorted { $0.priority > $1.priority }.first
    }

    /// Select the desired foreign policy option based on official's faction and goals
    private func selectDesiredForeignOption(slot: PolicySlot, official: GameCharacter, game: Game) -> String? {
        let factionId = official.factionId ?? ""

        // Faction-based preferences for foreign policy
        switch factionId {
        case "old_guard":
            // Old guard wants strict socialist alignment
            if slot.slotId.contains("alliance") {
                return slot.options.first { $0.id.contains("bloc") || $0.id.contains("leadership") }?.id
            }
            if slot.slotId.contains("border") {
                return slot.options.first { $0.id.contains("closed") || $0.id.contains("controlled") }?.id
            }

        case "reformists":
            // Reformists want more open foreign policy
            if slot.slotId.contains("trade") || slot.slotId.contains("economic") {
                return slot.options.first { $0.id.contains("joint") || $0.id.contains("open") }?.id
            }
            if slot.slotId.contains("border") {
                return slot.options.first { $0.id.contains("selective") || $0.id.contains("allies") }?.id
            }

        case "princelings":
            // Princelings want strong military stance
            if slot.slotId.contains("military") || slot.slotId.contains("defense") {
                return slot.options.first { $0.id.contains("active") || $0.id.contains("leadership") }?.id
            }

        default:
            break
        }

        // Default: look for equal partnership or pragmatic options
        return slot.options.first { $0.id.contains("equal") || $0.id.contains("partnership") }?.id
    }

    /// Submit a foreign policy proposal
    private func submitForeignPolicyProposal(
        official: GameCharacter,
        proposal: ForeignPolicyProposal,
        game: Game
    ) -> PoliticalEvent {
        switch proposal.type {
        case .policyChange:
            // Submit to policy slot
            if let slotId = proposal.slotId,
               let optionId = proposal.optionId,
               let slot = game.policySlot(withId: slotId) {

                slot.proposeChange(
                    optionId: optionId,
                    characterId: official.templateId,
                    turn: game.turnNumber
                )

                let optionName = slot.option(withId: optionId)?.name ?? "Unknown"

                return PoliticalEvent(
                    eventType: .proposalSubmitted,
                    characterId: official.templateId,
                    characterName: official.name,
                    slotId: slotId,
                    optionId: optionId,
                    narrative: "\(official.name), the \(official.title ?? "Foreign Affairs Official"), has proposed changing \(slot.name) to \(optionName).",
                    consequences: [],
                    turn: game.turnNumber
                )
            }

        case .treatyProposal, .crisisResponse, .tradeInitiative:
            // Submit to Standing Committee agenda
            if let committee = game.standingCommittee {
                let category: CommitteeAgendaItem.AgendaCategory = proposal.type == .crisisResponse ? .crisis : .foreign
                let priority: CommitteeAgendaItem.AgendaPriority = proposal.type == .crisisResponse ? .urgent : .important

                StandingCommitteeService.shared.submitAgendaItem(
                    to: committee,
                    title: proposal.description,
                    description: "Proposed by \(official.name): \(proposal.description)",
                    category: category,
                    priority: priority,
                    sponsor: official,
                    game: game
                )

                return PoliticalEvent(
                    eventType: .proposalSubmitted,
                    characterId: official.templateId,
                    characterName: official.name,
                    slotId: nil,
                    optionId: nil,
                    narrative: "\(official.name) has submitted a diplomatic proposal to the Standing Committee: \(proposal.description)",
                    consequences: [],
                    turn: game.turnNumber
                )
            }
        }

        // Fallback
        return PoliticalEvent(
            eventType: .proposalSubmitted,
            characterId: official.templateId,
            characterName: official.name,
            slotId: nil,
            optionId: nil,
            narrative: "\(official.name) proposed: \(proposal.description)",
            consequences: [],
            turn: game.turnNumber
        )
    }

    /// Process diplomatic agenda items that need Standing Committee attention
    private func processDiplomaticAgendaItems(game: Game) -> [PoliticalEvent]? {
        guard let committee = game.standingCommittee else { return nil }

        var events: [PoliticalEvent] = []

        // Check for automatic diplomatic agenda items based on world state
        let pendingAgendaCategories = Set(committee.pendingAgenda.map { $0.category })

        // High tension with any country should generate crisis agenda
        for country in game.foreignCountries where country.diplomaticTension > 80 {
            if !pendingAgendaCategories.contains(.crisis) {
                // Find the Foreign Minister to sponsor this
                let foreignMinister = game.characters.first {
                    $0.isActive && ($0.positionTrack == "foreignAffairs" || $0.positionTrack == "diplomatic") &&
                    ($0.positionIndex ?? 0) >= 6
                }

                StandingCommitteeService.shared.submitAgendaItem(
                    to: committee,
                    title: "Crisis: \(country.name) Tensions at Critical Level",
                    description: "Diplomatic tensions with \(country.name) have reached dangerous levels. The Committee must decide on a response.",
                    category: .crisis,
                    priority: .critical,
                    sponsor: foreignMinister,
                    game: game
                )

                events.append(PoliticalEvent(
                    eventType: .politicalCrisis,
                    characterId: foreignMinister?.templateId,
                    characterName: foreignMinister?.name ?? "Foreign Ministry",
                    slotId: nil,
                    optionId: nil,
                    narrative: "A diplomatic crisis with \(country.name) has been escalated to the Standing Committee for immediate action.",
                    consequences: [],
                    turn: game.turnNumber
                ))

                politicalLogger.info("Crisis agenda item created for \(country.name)")
                break  // Only one crisis per turn
            }
        }

        return events.isEmpty ? nil : events
    }

    // MARK: - Process Pending Proposals

    /// Process all pending policy proposals (vote simulation)
    private func processPendingProposals(game: Game) -> [PoliticalEvent]? {
        var events: [PoliticalEvent] = []

        for slot in game.policySlots where slot.hasPendingProposal {
            guard let proposalOptionId = slot.pendingProposalOptionId,
                  let proposalCharacterId = slot.pendingProposalCharacterId,
                  let proposalTurn = slot.pendingProposalTurn else { continue }

            // Proposals are voted on 1 turn after submission
            guard game.turnNumber > proposalTurn else { continue }

            let proposer = game.characters.first { $0.templateId == proposalCharacterId }

            // Execute the vote
            let result = PolicyService.shared.changePolicy(
                game: game,
                slotId: slot.slotId,
                toOptionId: proposalOptionId,
                byCharacterId: proposalCharacterId,
                byPlayer: false,
                asDecree: false
            )

            let proposerName = proposer?.name ?? "Unknown"

            events.append(PoliticalEvent(
                eventType: result.success ? .proposalPassed : .proposalRejected,
                characterId: proposalCharacterId,
                characterName: proposerName,
                slotId: slot.slotId,
                optionId: proposalOptionId,
                narrative: result.message,
                consequences: result.consequences,
                turn: game.turnNumber,
                voteResult: result.voteResult
            ))

            politicalLogger.info("Proposal vote: \(result.success ? "PASSED" : "REJECTED") - \(result.message)")
        }

        return events.isEmpty ? nil : events
    }

    // MARK: - Helpers

    /// Get faction standings as dictionary
    private func getFactionStandings(game: Game) -> [String: Int] {
        var standings: [String: Int] = [:]
        for faction in game.factions {
            standings[faction.factionId] = faction.playerStanding
        }
        return standings
    }
}

// MARK: - Supporting Types

struct PolicyPreference: Codable {
    let desiredOptionId: String
    let priority: Int  // 1-10, higher = more important
}

struct GSAgenda: Codable {
    let gsCharacterId: String
    var policyPreferences: [String: PolicyPreference]
    var decreeThreshold: Int
    var currentFocus: GSFocus
}

enum GSFocus: String, Codable {
    case powerConsolidation   // Consolidating authority
    case economicReform       // Economic changes
    case securityControl      // Security apparatus
    case stabilization        // Crisis management
    case maintenance          // Status quo
}

struct PolicyChangeTarget: Codable {
    let slotId: String
    let targetOptionId: String
    let priority: Int
}

struct PoliticalEvent: Codable {
    let eventType: PoliticalEventType
    let characterId: String?
    let characterName: String
    let slotId: String?
    let optionId: String?
    let narrative: String
    var consequences: [PolicyConsequence]
    let turn: Int
    var voteResult: PolicyChangeRecord.VoteResult? = nil
}

enum PoliticalEventType: String, Codable {
    case gsDecree           // GS issued decree
    case proposalSubmitted  // Proposal submitted to SC
    case proposalPassed     // SC approved proposal
    case proposalRejected   // SC rejected proposal
    case factionPressure    // Faction pushing for change
    case coalitionFormed    // Factions allied
    case politicalCrisis    // Major political event
}

// MARK: - Foreign Policy Proposal Types

struct ForeignPolicyProposal {
    let type: ForeignPolicyProposalType
    let slotId: String?
    let optionId: String?
    let targetCountryId: String?
    let priority: Int
    let description: String
}

enum ForeignPolicyProposalType: String, CustomStringConvertible {
    case policyChange      // Change a foreign policy slot
    case treatyProposal    // Propose a treaty with another country
    case crisisResponse    // Respond to a diplomatic crisis
    case tradeInitiative   // Propose trade agreements

    var description: String { rawValue }
}

// MARK: - Integration with Game Events

extension PoliticalAIService {

    /// Convert political events to game events for display
    func generateGameEvents(from politicalEvents: [PoliticalEvent], game: Game) -> [GameEvent] {
        return politicalEvents.map { event in
            let gameEvent = GameEvent(
                turnNumber: event.turn,
                eventType: .decision,
                summary: event.narrative
            )
            gameEvent.importance = importanceFor(event: event)
            gameEvent.game = game
            return gameEvent
        }
    }

    private func importanceFor(event: PoliticalEvent) -> Int {
        switch event.eventType {
        case .gsDecree: return 9
        case .proposalPassed: return 7
        case .proposalRejected: return 5
        case .proposalSubmitted: return 4
        case .factionPressure: return 6
        case .coalitionFormed: return 6
        case .politicalCrisis: return 10
        }
    }

    /// Generate dynamic event for player briefing
    func generateDynamicEvent(from politicalEvent: PoliticalEvent, game: Game) -> DynamicEvent? {
        let priority: EventPriority
        let isUrgent: Bool

        switch politicalEvent.eventType {
        case .gsDecree:
            priority = .elevated
            isUrgent = true
        case .proposalPassed, .proposalRejected:
            priority = .normal
            isUrgent = false
        case .factionPressure:
            priority = .background
            isUrgent = false
        case .politicalCrisis:
            priority = .urgent
            isUrgent = true
        default:
            priority = .background
            isUrgent = false
        }

        // Only show significant events
        guard importanceFor(event: politicalEvent) >= 5 else { return nil }

        let title: String
        switch politicalEvent.eventType {
        case .gsDecree:
            title = "General Secretary Decree"
        case .proposalPassed:
            title = "Policy Change Approved"
        case .proposalRejected:
            title = "Proposal Rejected"
        case .factionPressure:
            title = "Faction Maneuvering"
        case .politicalCrisis:
            title = "Political Crisis"
        default:
            title = "Political Development"
        }

        return DynamicEvent(
            eventType: .worldNews,
            priority: priority,
            title: title,
            briefText: politicalEvent.narrative,
            initiatingCharacterName: politicalEvent.characterName,
            turnGenerated: politicalEvent.turn,
            isUrgent: isUrgent,
            responseOptions: [
                EventResponse(
                    id: "note",
                    text: "Note this development",
                    shortText: "Note",
                    effects: [:]
                )
            ],
            iconName: "building.columns.fill"
        )
    }
}
