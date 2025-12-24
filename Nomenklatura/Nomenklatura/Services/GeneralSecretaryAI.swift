//
//  GeneralSecretaryAI.swift
//  Nomenklatura
//
//  Specialized AI for the General Secretary character.
//  Handles long-term strategy, succession planning, threat response,
//  and complex political maneuvering.
//

import Foundation
import os.log

private let gsLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "GeneralSecretaryAI")

// MARK: - General Secretary AI

class GeneralSecretaryAI {
    static let shared = GeneralSecretaryAI()

    private init() {}

    // MARK: - Strategic Assessment

    /// Assess the overall political situation from GS perspective
    func assessPoliticalSituation(gs: GameCharacter, game: Game) -> GSStrategicAssessment {
        let threats = identifyThreats(gs: gs, game: game)
        let opportunities = identifyOpportunities(gs: gs, game: game)
        let scLoyalty = assessCommitteeLoyalty(gs: gs, game: game)
        let factionBalance = assessFactionBalance(gs: gs, game: game)
        let powerStability = assessPowerStability(gs: gs, game: game)

        return GSStrategicAssessment(
            threats: threats,
            opportunities: opportunities,
            committeeLoyalty: scLoyalty,
            factionBalance: factionBalance,
            powerStability: powerStability,
            recommendedStrategy: determineStrategy(
                threats: threats,
                opportunities: opportunities,
                scLoyalty: scLoyalty,
                powerStability: powerStability,
                gs: gs
            )
        )
    }

    // MARK: - Threat Identification

    /// Identify threats to GS power
    private func identifyThreats(gs: GameCharacter, game: Game) -> [GSThreat] {
        var threats: [GSThreat] = []

        // 1. Ambitious rivals on Standing Committee
        if let committee = game.standingCommittee {
            for memberId in committee.memberIds where memberId != gs.templateId {
                guard let member = game.characters.first(where: { $0.templateId == memberId && $0.isActive }) else {
                    continue
                }

                // Ambitious + low loyalty = threat
                if member.personalityAmbitious > 70 && member.personalityLoyal < 50 {
                    let severity = (member.personalityAmbitious + (100 - member.personalityLoyal)) / 2 / 10

                    threats.append(GSThreat(
                        type: .ambitiousRival,
                        sourceCharacterId: member.templateId,
                        sourceCharacterName: member.name,
                        severity: severity,
                        description: "\(member.name) is ambitious and not fully loyal"
                    ))
                }

                // Hostile disposition = threat
                if member.disposition < 30 {
                    threats.append(GSThreat(
                        type: .hostileMember,
                        sourceCharacterId: member.templateId,
                        sourceCharacterName: member.name,
                        severity: (50 - member.disposition) / 10,
                        description: "\(member.name) harbors resentment"
                    ))
                }
            }
        }

        // 2. Faction imbalance
        let gsFactionId = gs.factionId
        for faction in game.factions where faction.factionId != gsFactionId {
            if faction.power > 70 && faction.playerStanding < 40 {
                threats.append(GSThreat(
                    type: .factionOpposition,
                    sourceFactionId: faction.factionId,
                    sourceCharacterName: faction.name,
                    severity: faction.power / 15,
                    description: "The \(faction.name) faction is powerful and hostile"
                ))
            }
        }

        // 3. Low stability
        if game.stability < 40 {
            threats.append(GSThreat(
                type: .instability,
                severity: (50 - game.stability) / 10,
                description: "Political instability threatens authority"
            ))
        }

        // 4. Military disloyalty
        if game.militaryLoyalty < 50 {
            threats.append(GSThreat(
                type: .militaryUnrest,
                severity: (60 - game.militaryLoyalty) / 10,
                description: "The military's loyalty is questionable"
            ))
        }

        // 5. Popular unrest
        if game.popularSupport < 35 {
            threats.append(GSThreat(
                type: .popularUnrest,
                severity: (50 - game.popularSupport) / 10,
                description: "Popular discontent is growing"
            ))
        }

        // Sort by severity
        return threats.sorted { $0.severity > $1.severity }
    }

    // MARK: - Opportunity Identification

    /// Identify opportunities for GS to consolidate power
    private func identifyOpportunities(gs: GameCharacter, game: Game) -> [GSOpportunity] {
        var opportunities: [GSOpportunity] = []

        // 1. Term limits can be abolished
        if let termLimits = game.policySlot(withId: "presidium_term_limits"),
           termLimits.currentOptionId != "term_limits_life_tenure" {
            opportunities.append(GSOpportunity(
                type: .policyChange,
                targetSlotId: "presidium_term_limits",
                targetOptionId: "term_limits_life_tenure",
                value: 9,
                description: "Abolish term limits to secure indefinite rule"
            ))
        }

        // 2. Emergency powers can be expanded
        if let emergencyPowers = game.policySlot(withId: "presidium_emergency_powers"),
           emergencyPowers.currentOptionId != "emergency_powers_unilateral" {
            opportunities.append(GSOpportunity(
                type: .policyChange,
                targetSlotId: "presidium_emergency_powers",
                targetOptionId: "emergency_powers_unilateral",
                value: 8,
                description: "Expand emergency powers for unilateral action"
            ))
        }

        // 3. Control succession
        if let succession = game.policySlot(withId: "presidium_succession_rules"),
           succession.currentOptionId != "succession_gs_designates" {
            opportunities.append(GSOpportunity(
                type: .policyChange,
                targetSlotId: "presidium_succession_rules",
                targetOptionId: "succession_gs_designates",
                value: 7,
                description: "Control who succeeds you"
            ))
        }

        // 4. Surveillance expansion
        if let surveillance = game.policySlot(withId: "security_surveillance_scope"),
           surveillance.currentOptionId != "surveillance_universal" {
            opportunities.append(GSOpportunity(
                type: .policyChange,
                targetSlotId: "security_surveillance_scope",
                targetOptionId: "surveillance_universal",
                value: 6,
                description: "Expand surveillance to monitor threats"
            ))
        }

        // 5. SC vacancy - opportunity to install ally
        if let committee = game.standingCommittee, committee.memberIds.count < 7 {
            opportunities.append(GSOpportunity(
                type: .appointmentOpportunity,
                value: 7,
                description: "Fill Standing Committee vacancy with a loyalist"
            ))
        }

        // 6. Weak rival - opportunity to purge
        for character in game.characters where character.isActive && !character.isPatron {
            if character.personalityCorrupt > 60 || character.disposition < 20 {
                if character.currentStatus == .underInvestigation {
                    opportunities.append(GSOpportunity(
                        type: .purgeOpportunity,
                        targetCharacterId: character.templateId,
                        targetCharacterName: character.name,
                        value: 5,
                        description: "\(character.name) is vulnerable - can be removed"
                    ))
                }
            }
        }

        return opportunities.sorted { $0.value > $1.value }
    }

    // MARK: - Committee Loyalty Assessment

    /// Assess how loyal the Standing Committee is to the GS
    private func assessCommitteeLoyalty(gs: GameCharacter, game: Game) -> CommitteeLoyaltyAssessment {
        guard let committee = game.standingCommittee else {
            return CommitteeLoyaltyAssessment(
                overallLoyalty: 50,
                loyalMembers: [],
                hostileMembers: [],
                uncommittedMembers: []
            )
        }

        var loyalMembers: [String] = []
        var hostileMembers: [String] = []
        var uncommittedMembers: [String] = []
        var totalLoyalty = 0
        var memberCount = 0

        for memberId in committee.memberIds where memberId != gs.templateId {
            guard let member = game.characters.first(where: { $0.templateId == memberId && $0.isActive }) else {
                continue
            }

            memberCount += 1

            // Calculate loyalty score
            var loyaltyScore = member.personalityLoyal

            // Same faction = bonus
            if member.factionId == gs.factionId {
                loyaltyScore += 20
            }

            // Disposition affects loyalty
            loyaltyScore += member.disposition / 4

            // Fear increases compliance
            loyaltyScore += member.fearLevel / 5

            // Grudges decrease loyalty
            loyaltyScore -= abs(min(0, member.grudgeLevel)) / 3

            loyaltyScore = max(0, min(100, loyaltyScore))
            totalLoyalty += loyaltyScore

            if loyaltyScore >= 70 {
                loyalMembers.append(memberId)
            } else if loyaltyScore < 40 {
                hostileMembers.append(memberId)
            } else {
                uncommittedMembers.append(memberId)
            }
        }

        let averageLoyalty = memberCount > 0 ? totalLoyalty / memberCount : 50

        return CommitteeLoyaltyAssessment(
            overallLoyalty: averageLoyalty,
            loyalMembers: loyalMembers,
            hostileMembers: hostileMembers,
            uncommittedMembers: uncommittedMembers
        )
    }

    // MARK: - Faction Balance Assessment

    /// Assess faction power balance relative to GS
    private func assessFactionBalance(gs: GameCharacter, game: Game) -> FactionBalanceAssessment {
        var gsFactionPower = 0
        var oppositionPower = 0
        var neutralPower = 0

        for faction in game.factions {
            if faction.factionId == gs.factionId {
                gsFactionPower = faction.power
            } else if faction.playerStanding < 40 {
                oppositionPower += faction.power
            } else {
                neutralPower += faction.power
            }
        }

        let balance: FactionBalanceState
        if gsFactionPower > oppositionPower + 20 {
            balance = .dominant
        } else if gsFactionPower < oppositionPower - 20 {
            balance = .weakened
        } else {
            balance = .contested
        }

        return FactionBalanceAssessment(
            gsFactionPower: gsFactionPower,
            oppositionPower: oppositionPower,
            neutralPower: neutralPower,
            balance: balance
        )
    }

    // MARK: - Power Stability Assessment

    /// Assess overall stability of GS power
    private func assessPowerStability(gs: GameCharacter, game: Game) -> PowerStabilityAssessment {
        var stabilityFactors: [String: Int] = [:]

        // State stability
        stabilityFactors["stateStability"] = game.stability

        // Elite loyalty
        stabilityFactors["eliteLoyalty"] = game.eliteLoyalty

        // Military support
        stabilityFactors["militaryLoyalty"] = game.militaryLoyalty

        // Faction support
        if let gsFaction = gs.factionId,
           let faction = game.factions.first(where: { $0.factionId == gsFaction }) {
            stabilityFactors["factionPower"] = faction.power
        }

        // Calculate overall
        let overall = stabilityFactors.values.reduce(0, +) / max(1, stabilityFactors.count)

        let level: StabilityLevel
        if overall >= 70 { level = .secure }
        else if overall >= 50 { level = .stable }
        else if overall >= 30 { level = .precarious }
        else { level = .critical }

        return PowerStabilityAssessment(
            overallStability: overall,
            factors: stabilityFactors,
            level: level
        )
    }

    // MARK: - Strategy Determination

    /// Determine recommended strategy based on assessment
    private func determineStrategy(
        threats: [GSThreat],
        opportunities: [GSOpportunity],
        scLoyalty: CommitteeLoyaltyAssessment,
        powerStability: PowerStabilityAssessment,
        gs: GameCharacter
    ) -> GSStrategy {
        // Critical instability = defensive mode
        if powerStability.level == .critical {
            return .stabilize
        }

        // Immediate threats require response
        if let topThreat = threats.first, topThreat.severity >= 7 {
            return .eliminateThreat
        }

        // Ambitious GS with opportunities = consolidate
        if gs.personalityAmbitious > 60 && !opportunities.isEmpty {
            return .consolidate
        }

        // Hostile committee = build support
        if scLoyalty.overallLoyalty < 50 {
            return .buildCoalition
        }

        // High stability + opportunities = expand
        if powerStability.level == .secure && !opportunities.isEmpty {
            return .expand
        }

        // Default: maintain current position
        return .maintain
    }

    // MARK: - Action Selection

    /// Select the best action for the GS this turn
    func selectAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        switch assessment.recommendedStrategy {
        case .stabilize:
            return selectStabilizationAction(assessment: assessment, gs: gs, game: game)

        case .eliminateThreat:
            return selectThreatEliminationAction(assessment: assessment, gs: gs, game: game)

        case .consolidate:
            return selectConsolidationAction(assessment: assessment, gs: gs, game: game)

        case .buildCoalition:
            return selectCoalitionAction(assessment: assessment, gs: gs, game: game)

        case .expand:
            return selectExpansionAction(assessment: assessment, gs: gs, game: game)

        case .maintain:
            return nil  // No action needed
        }
    }

    private func selectStabilizationAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        // Try to address most critical stability issue
        if let factors = assessment.powerStability?.factors {
            if let minFactor = factors.min(by: { $0.value < $1.value }) {
                switch minFactor.key {
                case "militaryLoyalty":
                    // Propose military-friendly policy
                    return GSAction(
                        type: .proposePolicy,
                        targetSlotId: "military_budget_control",
                        targetOptionId: "military_general_staff",
                        priority: 9,
                        reason: "Shore up military support"
                    )
                case "stateStability":
                    // Emergency measures
                    return GSAction(
                        type: .decree,
                        targetSlotId: "security_surveillance_scope",
                        targetOptionId: "surveillance_targeted",
                        priority: 8,
                        reason: "Stabilize through security measures"
                    )
                default:
                    break
                }
            }
        }
        return nil
    }

    private func selectThreatEliminationAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        guard let topThreat = assessment.threats.first else { return nil }

        switch topThreat.type {
        case .ambitiousRival, .hostileMember:
            // Target the rival
            return GSAction(
                type: .targetRival,
                targetCharacterId: topThreat.sourceCharacterId,
                priority: 9,
                reason: "Neutralize \(topThreat.sourceCharacterName ?? "threat")"
            )

        case .factionOpposition:
            // Propose policy to weaken opposing faction
            if let factionId = topThreat.sourceFactionId {
                let policyToHurt = findPolicyToHurtFaction(factionId: factionId, game: game)
                if let policy = policyToHurt {
                    return GSAction(
                        type: .proposePolicy,
                        targetSlotId: policy.slotId,
                        targetOptionId: policy.optionId,
                        priority: 8,
                        reason: "Weaken \(topThreat.sourceCharacterName ?? "opposing faction")"
                    )
                }
            }

        case .instability, .militaryUnrest, .popularUnrest:
            return selectStabilizationAction(assessment: assessment, gs: gs, game: game)
        }

        return nil
    }

    private func selectConsolidationAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        // Pursue highest value opportunity
        guard let opportunity = assessment.opportunities.first else { return nil }

        switch opportunity.type {
        case .policyChange:
            // High power = decree, otherwise propose
            let useDecree = game.decreesEnabled && assessment.powerStability?.level == .secure
            return GSAction(
                type: useDecree ? .decree : .proposePolicy,
                targetSlotId: opportunity.targetSlotId,
                targetOptionId: opportunity.targetOptionId,
                priority: opportunity.value,
                reason: opportunity.description
            )

        case .appointmentOpportunity:
            return GSAction(
                type: .appointLoyalist,
                priority: opportunity.value,
                reason: opportunity.description
            )

        case .purgeOpportunity:
            return GSAction(
                type: .targetRival,
                targetCharacterId: opportunity.targetCharacterId,
                priority: opportunity.value,
                reason: opportunity.description
            )
        }
    }

    private func selectCoalitionAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        // Propose policies that benefit uncommitted factions
        for faction in game.factions where faction.playerStanding >= 40 && faction.playerStanding < 60 {
            if let policyToBenefit = findPolicyToBenefitFaction(factionId: faction.factionId, game: game) {
                return GSAction(
                    type: .proposePolicy,
                    targetSlotId: policyToBenefit.slotId,
                    targetOptionId: policyToBenefit.optionId,
                    targetFactionId: faction.factionId,
                    priority: 6,
                    reason: "Win support from \(faction.name)"
                )
            }
        }
        return nil
    }

    private func selectExpansionAction(assessment: GSStrategicAssessment, gs: GameCharacter, game: Game) -> GSAction? {
        // Same as consolidation when expanding
        return selectConsolidationAction(assessment: assessment, gs: gs, game: game)
    }

    // MARK: - Policy Finding Helpers

    private func findPolicyToHurtFaction(factionId: String, game: Game) -> (slotId: String, optionId: String)? {
        for slot in game.policySlots {
            for option in slot.options where option.losers.contains(factionId) {
                if slot.currentOptionId != option.id {
                    return (slot.slotId, option.id)
                }
            }
        }
        return nil
    }

    private func findPolicyToBenefitFaction(factionId: String, game: Game) -> (slotId: String, optionId: String)? {
        for slot in game.policySlots {
            for option in slot.options where option.beneficiaries.contains(factionId) {
                if slot.currentOptionId != option.id {
                    return (slot.slotId, option.id)
                }
            }
        }
        return nil
    }

    // MARK: - Succession Planning

    /// Evaluate potential successors from GS perspective
    func evaluateSuccessors(gs: GameCharacter, game: Game) -> [SuccessorCandidate] {
        var candidates: [SuccessorCandidate] = []

        for character in game.characters where character.isActive && character.templateId != gs.templateId {
            let position = character.positionIndex ?? 0
            guard position >= 5 else { continue }  // Must be senior

            var suitability = 50

            // Same faction is preferred
            if character.factionId == gs.factionId {
                suitability += 30
            }

            // Loyalty is valued
            suitability += character.personalityLoyal / 3

            // Competence matters
            suitability += character.personalityCompetent / 4

            // Not too ambitious (might be a threat)
            if character.personalityAmbitious > 80 {
                suitability -= 20
            }

            // Good disposition toward GS
            suitability += character.disposition / 5

            candidates.append(SuccessorCandidate(
                characterId: character.templateId,
                characterName: character.name,
                suitability: max(0, min(100, suitability)),
                factionId: character.factionId,
                position: position
            ))
        }

        return candidates.sorted { $0.suitability > $1.suitability }
    }
}

// MARK: - Supporting Types

struct GSStrategicAssessment {
    let threats: [GSThreat]
    let opportunities: [GSOpportunity]
    let committeeLoyalty: CommitteeLoyaltyAssessment
    let factionBalance: FactionBalanceAssessment
    let powerStability: PowerStabilityAssessment?
    let recommendedStrategy: GSStrategy
}

struct GSThreat: Codable {
    let type: ThreatType
    var sourceCharacterId: String? = nil
    var sourceFactionId: String? = nil
    var sourceCharacterName: String? = nil
    let severity: Int  // 1-10
    let description: String

    enum ThreatType: String, Codable {
        case ambitiousRival
        case hostileMember
        case factionOpposition
        case instability
        case militaryUnrest
        case popularUnrest
    }
}

struct GSOpportunity: Codable {
    let type: OpportunityType
    var targetSlotId: String? = nil
    var targetOptionId: String? = nil
    var targetCharacterId: String? = nil
    var targetCharacterName: String? = nil
    let value: Int  // 1-10
    let description: String

    enum OpportunityType: String, Codable {
        case policyChange
        case appointmentOpportunity
        case purgeOpportunity
    }
}

struct CommitteeLoyaltyAssessment {
    let overallLoyalty: Int
    let loyalMembers: [String]
    let hostileMembers: [String]
    let uncommittedMembers: [String]

    var hasReliableMajority: Bool {
        loyalMembers.count > (loyalMembers.count + hostileMembers.count + uncommittedMembers.count) / 2
    }
}

struct FactionBalanceAssessment {
    let gsFactionPower: Int
    let oppositionPower: Int
    let neutralPower: Int
    let balance: FactionBalanceState
}

enum FactionBalanceState: String, Codable {
    case dominant
    case contested
    case weakened
}

struct PowerStabilityAssessment {
    let overallStability: Int
    let factors: [String: Int]
    let level: StabilityLevel
}

enum StabilityLevel: String, Codable {
    case secure
    case stable
    case precarious
    case critical
}

enum GSStrategy: String, Codable {
    case stabilize       // Address critical issues
    case eliminateThreat // Remove specific threat
    case consolidate     // Strengthen position
    case buildCoalition  // Gain supporters
    case expand          // Pursue opportunities
    case maintain        // Status quo
}

struct GSAction: Codable {
    let type: ActionType
    var targetSlotId: String? = nil
    var targetOptionId: String? = nil
    var targetCharacterId: String? = nil
    var targetFactionId: String? = nil
    let priority: Int
    let reason: String

    enum ActionType: String, Codable {
        case proposePolicy
        case decree
        case targetRival
        case appointLoyalist
        case buildSupport
    }
}

struct SuccessorCandidate: Codable {
    let characterId: String
    let characterName: String
    let suitability: Int  // 0-100
    let factionId: String?
    let position: Int
}
