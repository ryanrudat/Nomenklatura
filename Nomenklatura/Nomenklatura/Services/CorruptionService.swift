//
//  CorruptionService.swift
//  Nomenklatura
//
//  Service for managing personal wealth and corruption mechanics
//

import Foundation

final class CorruptionService {
    static let shared = CorruptionService()

    private init() {}

    // MARK: - Wealth Assessment

    /// Get the player's current corruption level
    func getCorruptionLevel(for game: Game) -> CorruptionLevel {
        return CorruptionLevel.level(for: game.personalWealth)
    }

    /// Get the player's current risk level
    func getRiskLevel(for game: Game) -> CorruptionRiskLevel {
        return CorruptionRiskLevel.level(
            for: game.wealthVisibility,
            evidence: game.corruptionEvidence
        )
    }

    /// Check if player should face investigation this turn
    func shouldTriggerInvestigation(for game: Game) -> Bool {
        let riskLevel = getRiskLevel(for: game)

        switch riskLevel {
        case .safe, .cautious:
            return false
        case .exposed:
            // 5% chance per turn
            return Int.random(in: 1...100) <= 5
        case .dangerous:
            // 15% chance per turn
            return Int.random(in: 1...100) <= 15
        case .imminent:
            // 30% chance per turn
            return Int.random(in: 1...100) <= 30
        }
    }

    // MARK: - Wealth Actions

    /// Attempt to launder wealth (reduce visibility and evidence)
    func launderWealth(for game: Game) -> LaunderResult {
        // Can't launder if nothing to launder
        guard game.personalWealth > 10 else {
            return LaunderResult(success: false, message: "You have no significant wealth to launder.")
        }

        // Laundering has a cost and risk
        let visibilityReduction = Int.random(in: 15...25)
        let evidenceReduction = Int.random(in: 10...20)
        let wealthCost = Int.random(in: 5...15)  // Some wealth lost in the process

        game.applyStat("wealthVisibility", change: -visibilityReduction)
        game.applyStat("corruptionEvidence", change: -evidenceReduction)
        game.applyStat("personalWealth", change: -wealthCost)

        return LaunderResult(
            success: true,
            message: "Your family's 'agricultural enterprise' has absorbed some assets.",
            visibilityReduced: visibilityReduction,
            evidenceReduced: evidenceReduction,
            wealthLost: wealthCost
        )
    }

    /// Use wealth for influence (bribe officials, buy loyalty)
    func spendWealthForInfluence(for game: Game, amount: Int) -> SpendResult {
        guard game.personalWealth >= amount else {
            return SpendResult(success: false, message: "Insufficient personal funds.")
        }

        // Spending increases visibility but buys concrete benefits
        let visibilityGain = amount / 3
        let networkGain = amount / 4
        let standingGain = amount / 5

        game.applyStat("personalWealth", change: -amount)
        game.applyStat("wealthVisibility", change: visibilityGain)
        game.applyStat("network", change: networkGain)
        game.applyStat("standing", change: standingGain)

        return SpendResult(
            success: true,
            message: "Your generosity has made friends in useful places.",
            networkGain: networkGain,
            standingGain: standingGain,
            visibilityGain: visibilityGain
        )
    }

    // MARK: - Corruption Sources

    /// Record corruption from a decision
    func recordCorruption(
        for game: Game,
        sourceType: WealthSourceType,
        amount: Int,
        description: String
    ) {
        // Apply wealth gain
        game.applyStat("personalWealth", change: amount)

        // Apply visibility and evidence based on source type
        game.applyStat("wealthVisibility", change: sourceType.visibilityImpact)
        game.applyStat("corruptionEvidence", change: sourceType.evidenceImpact)

        // Also affects reputation
        game.applyStat("reputationLoyal", change: -2)  // Corruption is disloyalty
        game.applyStat("reputationRuthless", change: 3)  // But shows you're a player
    }

    // MARK: - Investigation Consequences

    /// Handle investigation result
    func handleInvestigation(for game: Game) -> InvestigationResult {
        let evidence = game.corruptionEvidence
        let position = game.currentPositionIndex
        let patronFavor = game.patronFavor

        // Higher position = more protection
        let protectionBonus = position * 5
        let patronProtection = patronFavor / 4

        // Roll against evidence
        let roll = Int.random(in: 1...100)
        let threshold = evidence - protectionBonus - patronProtection

        if roll > threshold {
            // Survived investigation
            // But it costs political capital
            game.applyStat("standing", change: -10)
            game.applyStat("patronFavor", change: -15)
            game.applyStat("corruptionEvidence", change: -20)  // Some evidence "disappeared"

            return InvestigationResult(
                outcome: .cleared,
                message: "The investigation found 'insufficient evidence'. Your patron's influence was helpful, but costly."
            )
        } else if roll > threshold / 2 {
            // Partial consequences
            game.applyStat("standing", change: -25)
            game.applyStat("personalWealth", change: -30)  // Assets seized
            game.applyStat("corruptionEvidence", change: -40)

            return InvestigationResult(
                outcome: .reprimanded,
                message: "You received a formal Party reprimand. Significant assets were 'returned to the state'."
            )
        } else {
            // Serious consequences
            return InvestigationResult(
                outcome: .demoted,
                message: "The investigation has cost you your position. You have been 'transferred to other work'."
            )
        }
    }

    // MARK: - Natural Visibility Decay

    /// Each turn, visibility naturally decays slightly as people forget
    func applyVisibilityDecay(for game: Game) {
        if game.wealthVisibility > 0 {
            let decay = min(3, game.wealthVisibility / 10 + 1)
            game.applyStat("wealthVisibility", change: -decay)
        }
    }
}

// MARK: - Result Types

struct LaunderResult {
    let success: Bool
    let message: String
    var visibilityReduced: Int = 0
    var evidenceReduced: Int = 0
    var wealthLost: Int = 0
}

struct SpendResult {
    let success: Bool
    let message: String
    var networkGain: Int = 0
    var standingGain: Int = 0
    var visibilityGain: Int = 0
}

struct InvestigationResult {
    enum Outcome {
        case cleared
        case reprimanded
        case demoted
        case arrested
    }

    let outcome: Outcome
    let message: String
}

// MARK: - CCDI-Style Detention System (Shuanggui)
//
// Models the off-site detention used by anti-corruption bodies
// Target is isolated, interrogated, and must confess or face trial

/// Represents an active detention/investigation
struct Detention: Codable, Identifiable {
    var id: String = UUID().uuidString
    var targetId: String              // Character template ID
    var targetName: String
    var initiatorId: String?          // Who ordered detention (if NPC)
    var playerOrdered: Bool           // Did player order this

    var phase: DetentionPhase
    var turnStarted: Int
    var durationTurns: Int            // How long detention lasts (2-4)

    var accusations: [String]         // List of accusations
    var evidenceLevel: Int            // 0-100, accumulated evidence
    var confessionObtained: Bool
    var othersImplicated: [String]    // Character IDs named in confession

    var outcome: DetentionOutcome?

    init(target: GameCharacter, turn: Int, playerOrdered: Bool, initiator: GameCharacter? = nil) {
        self.targetId = target.templateId
        self.targetName = target.name
        self.initiatorId = initiator?.templateId
        self.playerOrdered = playerOrdered
        self.phase = .detention
        self.turnStarted = turn
        self.durationTurns = Int.random(in: 2...4)
        self.accusations = []
        self.evidenceLevel = 0
        self.confessionObtained = false
        self.othersImplicated = []
    }
}

enum DetentionPhase: String, Codable {
    case detention      // Initial isolation (shuanggui)
    case interrogation  // Active questioning
    case review         // Evidence review / decision
    case completed      // Detention ended

    var displayName: String {
        switch self {
        case .detention: return "Detention"
        case .interrogation: return "Interrogation"
        case .review: return "Under Review"
        case .completed: return "Completed"
        }
    }
}

enum DetentionOutcome: String, Codable {
    case cleared        // Released, no findings
    case warned         // Released with warning, career impact
    case demoted        // Position lost, but free
    case referredToTrial // Sent to show trial (serious)
    case executed       // Died in detention (rare, dangerous)

    var displayName: String {
        switch self {
        case .cleared: return "Cleared"
        case .warned: return "Official Warning"
        case .demoted: return "Demoted"
        case .referredToTrial: return "Referred for Trial"
        case .executed: return "Died in Detention"
        }
    }
}

// MARK: - Detention Service Extension

extension CorruptionService {

    /// Initiate detention against a character
    func initiateDetention(
        target: GameCharacter,
        game: Game,
        playerOrdered: Bool,
        initiator: GameCharacter? = nil,
        accusations: [String]? = nil
    ) -> Detention {
        var detention = Detention(
            target: target,
            turn: game.turnNumber,
            playerOrdered: playerOrdered,
            initiator: initiator
        )

        // Generate accusations if not provided
        if let accusations = accusations {
            detention.accusations = accusations
        } else {
            detention.accusations = generateAccusations(for: target)
        }

        // Initial evidence based on target's corruption
        detention.evidenceLevel = min(100, target.personalityCorrupt + Int.random(in: 10...30))

        // Target is now detained
        target.status = CharacterStatus.detained.rawValue

        return detention
    }

    /// Generate plausible accusations against a character
    func generateAccusations(for character: GameCharacter) -> [String] {
        var accusations: [String] = []

        // Always include a general corruption accusation
        accusations.append("Violation of Party discipline")

        // Add based on personality/track
        if character.personalityCorrupt > 40 {
            accusations.append("Acceptance of bribes from subordinates")
        }
        if character.positionTrack == "stateMinistry" {
            accusations.append("Misappropriation of state funds")
        }
        if character.positionTrack == "economicPlanning" {
            accusations.append("Falsification of production statistics")
        }
        if character.personalityAmbitious > 60 {
            accusations.append("Unauthorized political activities")
        }

        return accusations
    }

    /// Process detention for one turn
    func processDetention(detention: inout Detention, game: Game) -> DetentionPhaseResult {
        let turnsElapsed = game.turnNumber - detention.turnStarted

        switch detention.phase {
        case .detention:
            if turnsElapsed >= 1 {
                detention.phase = .interrogation
                return DetentionPhaseResult(
                    phase: .detention,
                    narrative: "\(detention.targetName) has been isolated from all contacts. The interrogation phase begins.",
                    headline: nil,
                    effectsApplied: ["networkEffectiveness": -100]
                )
            }
            return DetentionPhaseResult(
                phase: .detention,
                narrative: "\(detention.targetName) remains in detention, cut off from the outside world.",
                headline: nil,
                effectsApplied: [:]
            )

        case .interrogation:
            if turnsElapsed < detention.durationTurns {
                // Still being interrogated
                let newEvidence = Int.random(in: 5...15)
                detention.evidenceLevel = min(100, detention.evidenceLevel + newEvidence)

                return DetentionPhaseResult(
                    phase: .interrogation,
                    narrative: "Interrogation of \(detention.targetName) continues. Evidence accumulates.",
                    headline: nil,
                    effectsApplied: [:]
                )
            }

            // Interrogation complete - determine if confession obtained
            let target = game.characters.first { $0.templateId == detention.targetId }
            let confessionChance = detention.evidenceLevel + (100 - (target?.personalityLoyal ?? 50))
            detention.confessionObtained = Int.random(in: 1...200) < confessionChance

            if detention.confessionObtained {
                // Possibly implicate others
                if Int.random(in: 1...100) < 40 {
                    detention.othersImplicated = findPotentialImplicants(target: target, game: game)
                }
            }

            detention.phase = .review
            let confessionText = detention.confessionObtained ?
                "\(detention.targetName) has confessed to the accusations." :
                "\(detention.targetName) has refused to confess despite thorough interrogation."

            return DetentionPhaseResult(
                phase: .interrogation,
                narrative: confessionText,
                headline: detention.confessionObtained ? nil : "ENEMY REFUSES TO CONFESS",
                effectsApplied: [:]
            )

        case .review:
            // Determine outcome based on evidence, confession, and politics
            detention.outcome = determineOutcome(detention: detention, game: game)
            detention.phase = .completed

            let outcomeNarrative: String
            let headline: String?

            switch detention.outcome! {
            case .cleared:
                outcomeNarrative = "The investigation found insufficient evidence. \(detention.targetName) is released."
                headline = nil
            case .warned:
                outcomeNarrative = "\(detention.targetName) received an official warning and has been placed under surveillance."
                headline = nil
            case .demoted:
                outcomeNarrative = "\(detention.targetName) has been removed from their position and transferred to lesser duties."
                headline = "\(detention.targetName.uppercased()) DEMOTED FOLLOWING INVESTIGATION"
            case .referredToTrial:
                outcomeNarrative = "The evidence warrants a public trial. \(detention.targetName) will face the People's Tribunal."
                headline = "\(detention.targetName.uppercased()) TO FACE TRIAL"
            case .executed:
                outcomeNarrative = "\(detention.targetName) died during detention. Official cause: cardiac arrest."
                headline = nil // Kept quiet
            }

            return DetentionPhaseResult(
                phase: .review,
                narrative: outcomeNarrative,
                headline: headline,
                effectsApplied: [:]
            )

        case .completed:
            return DetentionPhaseResult(
                phase: .completed,
                narrative: "The detention of \(detention.targetName) has concluded.",
                headline: nil,
                effectsApplied: [:]
            )
        }
    }

    /// Find characters who might be implicated
    private func findPotentialImplicants(target: GameCharacter?, game: Game) -> [String] {
        guard let target = target else { return [] }

        let candidates = game.characters.filter { char in
            char.templateId != target.templateId &&
            char.isAlive &&
            char.factionId == target.factionId &&
            (char.positionIndex ?? 0) <= (target.positionIndex ?? 0) + 1
        }

        let count = min(candidates.count, Int.random(in: 1...2))
        return candidates.shuffled().prefix(count).map { $0.templateId }
    }

    /// Determine detention outcome
    private func determineOutcome(detention: Detention, game: Game) -> DetentionOutcome {
        let evidenceStrength = detention.evidenceLevel
        let confessed = detention.confessionObtained

        // Very low evidence = cleared
        if evidenceStrength < 30 && !confessed {
            return .cleared
        }

        // Moderate evidence without confession = warning
        if evidenceStrength < 50 && !confessed {
            return .warned
        }

        // High evidence = demotion at minimum
        if evidenceStrength < 70 {
            return confessed ? .demoted : .warned
        }

        // Very high evidence with confession = trial
        if confessed && evidenceStrength >= 70 {
            return .referredToTrial
        }

        // High evidence, no confession, small chance of death in detention
        if !confessed && evidenceStrength >= 80 && Int.random(in: 1...100) < 10 {
            return .executed
        }

        return .demoted
    }

    /// Apply detention outcome effects
    func applyDetentionOutcome(detention: Detention, game: Game) {
        guard let target = game.characters.first(where: { $0.templateId == detention.targetId }) else { return }

        switch detention.outcome {
        case .cleared:
            target.status = CharacterStatus.active.rawValue
            // Cleared but somewhat stigmatized
            target.disposition = max(0, target.disposition - 10)

        case .warned:
            target.status = CharacterStatus.active.rawValue
            target.disposition = max(0, target.disposition - 20)
            // Position unchanged but under watch

        case .demoted:
            target.status = CharacterStatus.active.rawValue
            target.positionIndex = max(0, (target.positionIndex ?? 0) - 2)
            target.disposition = max(0, target.disposition - 30)

        case .referredToTrial:
            target.status = CharacterStatus.underInvestigation.rawValue
            // Trial will be processed by CharacterInteractionSystem

        case .executed:
            target.status = CharacterStatus.dead.rawValue
            target.positionIndex = nil
            target.positionTrack = nil

        case .none:
            break
        }

        // Mark implicated characters for investigation
        for implicatedId in detention.othersImplicated {
            if let implicated = game.characters.first(where: { $0.templateId == implicatedId }) {
                if implicated.currentStatus == .active {
                    implicated.status = CharacterStatus.underInvestigation.rawValue
                }
            }
        }

        // Stability/loyalty effects
        switch detention.outcome {
        case .referredToTrial, .executed:
            game.stability = max(0, game.stability - 5)
            game.eliteLoyalty = max(0, game.eliteLoyalty - 8)
        case .demoted:
            game.eliteLoyalty = max(0, game.eliteLoyalty - 3)
        default:
            break
        }
    }
}

/// Result of processing a detention phase
struct DetentionPhaseResult {
    let phase: DetentionPhase
    let narrative: String
    let headline: String?
    let effectsApplied: [String: Int]
}

// MARK: - Anti-Corruption Campaign System

/// Represents a major anti-corruption campaign (like China's "Tiger and Fly")
struct AntiCorruptionCampaign: Identifiable, Sendable {
    var id: String = UUID().uuidString
    var name: String
    var type: CampaignType
    var turnStarted: Int
    var turnEnded: Int?
    var isActive: Bool = true

    // Campaign scope
    var targetedTrack: String?           // If targeting specific bureau/track
    var targetedFaction: String?         // If targeting specific faction
    var minimumTargetPosition: Int       // "Tigers" start at high positions

    // Campaign results
    var charactersInvestigated: [String] // Template IDs
    var charactersConvicted: [String]
    var totalWealthSeized: Int = 0

    // Intensity
    var intensityLevel: Int = 50         // 0-100, affects investigation rate

    enum CampaignType: String, Codable, Sendable {
        case tigers        // Targeting high-ranking officials
        case flies         // Targeting lower-level corruption
        case comprehensive // Both tigers and flies
        case factional     // Targeting specific faction (purge masquerading as anti-corruption)
        case sectoral      // Targeting specific bureau/track
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, turnStarted, turnEnded, isActive
        case targetedTrack, targetedFaction, minimumTargetPosition
        case charactersInvestigated, charactersConvicted, totalWealthSeized, intensityLevel
    }
}

// MARK: - AntiCorruptionCampaign Codable Conformance (nonisolated for Swift 6 compatibility)

extension AntiCorruptionCampaign: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(CampaignType.self, forKey: .type)
        turnStarted = try container.decode(Int.self, forKey: .turnStarted)
        turnEnded = try container.decodeIfPresent(Int.self, forKey: .turnEnded)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        targetedTrack = try container.decodeIfPresent(String.self, forKey: .targetedTrack)
        targetedFaction = try container.decodeIfPresent(String.self, forKey: .targetedFaction)
        minimumTargetPosition = try container.decode(Int.self, forKey: .minimumTargetPosition)
        charactersInvestigated = try container.decode([String].self, forKey: .charactersInvestigated)
        charactersConvicted = try container.decode([String].self, forKey: .charactersConvicted)
        totalWealthSeized = try container.decodeIfPresent(Int.self, forKey: .totalWealthSeized) ?? 0
        intensityLevel = try container.decodeIfPresent(Int.self, forKey: .intensityLevel) ?? 50
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(turnStarted, forKey: .turnStarted)
        try container.encodeIfPresent(turnEnded, forKey: .turnEnded)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(targetedTrack, forKey: .targetedTrack)
        try container.encodeIfPresent(targetedFaction, forKey: .targetedFaction)
        try container.encode(minimumTargetPosition, forKey: .minimumTargetPosition)
        try container.encode(charactersInvestigated, forKey: .charactersInvestigated)
        try container.encode(charactersConvicted, forKey: .charactersConvicted)
        try container.encode(totalWealthSeized, forKey: .totalWealthSeized)
        try container.encode(intensityLevel, forKey: .intensityLevel)
    }
}

extension CorruptionService {

    // MARK: - Campaign Generation

    /// Check if conditions warrant launching an anti-corruption campaign
    func shouldLaunchCampaign(game: Game) -> Bool {
        // Only launch if no active campaign
        guard game.activeAntiCorruptionCampaign == nil else { return false }

        // Various triggers for campaign launch
        let triggers: [Bool] = [
            game.corruptionEvidence > 60,                   // Corruption too visible
            game.stability < 40 && game.popularSupport < 50, // Need to show action
            game.turnNumber % 20 == 0,                      // Periodic campaign (every 20 turns)
            game.eliteLoyalty < 40                          // Need to shake up elite
        ]

        return triggers.contains(true) && Int.random(in: 1...100) <= 25
    }

    /// Launch an anti-corruption campaign
    func launchCampaign(game: Game, type: AntiCorruptionCampaign.CampaignType? = nil) -> AntiCorruptionCampaign {
        let campaignType = type ?? determineCampaignType(game: game)
        let campaignName = generateCampaignName(type: campaignType)

        var campaign = AntiCorruptionCampaign(
            name: campaignName,
            type: campaignType,
            turnStarted: game.turnNumber,
            minimumTargetPosition: campaignType == .tigers ? 5 : 2,
            charactersInvestigated: [],
            charactersConvicted: []
        )

        // Set campaign focus based on type
        switch campaignType {
        case .tigers:
            campaign.minimumTargetPosition = 5
            campaign.intensityLevel = 70

        case .flies:
            campaign.minimumTargetPosition = 0
            campaign.intensityLevel = 50

        case .comprehensive:
            campaign.minimumTargetPosition = 0
            campaign.intensityLevel = 80

        case .factional:
            // Target a faction with low standing (purge masquerading)
            let targetFaction = game.factions
                .filter { $0.playerStanding < 40 }
                .randomElement()
            campaign.targetedFaction = targetFaction?.factionId
            campaign.intensityLevel = 90

        case .sectoral:
            // Target a track with corruption issues
            let tracks = ["economicPlanning", "stateMinistry", "foreignAffairs"]
            campaign.targetedTrack = tracks.randomElement()
            campaign.intensityLevel = 60
        }

        return campaign
    }

    private func determineCampaignType(game: Game) -> AntiCorruptionCampaign.CampaignType {
        // Weighted selection based on game state
        var weights: [AntiCorruptionCampaign.CampaignType: Int] = [
            .tigers: 20,
            .flies: 30,
            .comprehensive: 15,
            .factional: 10,
            .sectoral: 25
        ]

        // Low elite loyalty = target tigers
        if game.eliteLoyalty < 50 {
            weights[.tigers]! += 30
        }

        // Low popular support = target flies (visible action)
        if game.popularSupport < 50 {
            weights[.flies]! += 30
        }

        // Factional tensions
        if game.factions.contains(where: { $0.playerStanding < 30 }) {
            weights[.factional]! += 25
        }

        let total = weights.values.reduce(0, +)
        var roll = Int.random(in: 0..<total)

        for (type, weight) in weights {
            roll -= weight
            if roll < 0 { return type }
        }

        return .flies
    }

    private func generateCampaignName(type: AntiCorruptionCampaign.CampaignType) -> String {
        switch type {
        case .tigers:
            return ["Operation Clean Slate", "Campaign to Purify the Party", "The High-Level Rectification"][Int.random(in: 0...2)]
        case .flies:
            return ["Anti-Corruption in the Grassroots", "Cleaning the Base", "Local Rectification Campaign"][Int.random(in: 0...2)]
        case .comprehensive:
            return ["Comprehensive Anti-Corruption Movement", "Tigers and Flies Together", "The Great Cleansing"][Int.random(in: 0...2)]
        case .factional:
            return ["Campaign Against Factionalism", "Unity Through Purity", "Eliminating Cliques"][Int.random(in: 0...2)]
        case .sectoral:
            return ["Sectoral Anti-Corruption Initiative", "Ministry Rectification", "Bureau Cleansing"][Int.random(in: 0...2)]
        }
    }

    // MARK: - Campaign Progression

    /// Process anti-corruption campaign for one turn
    func processCampaign(campaign: inout AntiCorruptionCampaign, game: Game) -> CampaignTurnResult {
        guard campaign.isActive else {
            return CampaignTurnResult(narrative: "The campaign has concluded.", events: [], headline: nil)
        }

        var events: [DynamicEvent] = []

        // Check if campaign should end
        let turnsActive = game.turnNumber - campaign.turnStarted
        if turnsActive > Int.random(in: 6...12) {
            campaign.isActive = false
            campaign.turnEnded = game.turnNumber
            return CampaignTurnResult(
                narrative: "The \(campaign.name) has concluded. \(campaign.charactersConvicted.count) officials were convicted.",
                events: [],
                headline: "ANTI-CORRUPTION CAMPAIGN CONCLUDES SUCCESSFULLY"
            )
        }

        // Find potential targets
        let targets = findCampaignTargets(campaign: campaign, game: game)

        // Chance to investigate someone new each turn
        let investigationChance = Double(campaign.intensityLevel) / 100.0
        if !targets.isEmpty && Double.random(in: 0...1) < investigationChance {
            let target = targets.randomElement()!

            // Generate investigation event
            let event = generateCampaignInvestigationEvent(target: target, campaign: campaign, game: game)
            events.append(event)

            campaign.charactersInvestigated.append(target.templateId)
        }

        // Determine campaign effects on game state
        var narrative = "The \(campaign.name) continues."
        if campaign.charactersInvestigated.count > campaign.charactersConvicted.count + 2 {
            narrative += " Investigations are ongoing."
        }

        return CampaignTurnResult(narrative: narrative, events: events, headline: nil)
    }

    private func findCampaignTargets(campaign: AntiCorruptionCampaign, game: Game) -> [GameCharacter] {
        return game.characters.filter { char in
            guard char.isAlive,
                  char.currentStatus == .active,
                  !campaign.charactersInvestigated.contains(char.templateId),
                  (char.positionIndex ?? 0) >= campaign.minimumTargetPosition else {
                return false
            }

            // Check faction targeting
            if let targetFaction = campaign.targetedFaction {
                if char.factionId != targetFaction { return false }
            }

            // Check track targeting
            if let targetTrack = campaign.targetedTrack {
                if char.positionTrack != targetTrack { return false }
            }

            // Corrupt characters are more likely targets
            return char.personalityCorrupt > 30
        }
    }

    private func generateCampaignInvestigationEvent(
        target: GameCharacter,
        campaign: AntiCorruptionCampaign,
        game: Game
    ) -> DynamicEvent {
        let positionTitle = target.title ?? "official"

        let texts: [(briefText: String, detailedText: String)] = [
            (
                "The discipline inspection commission has announced an investigation into \(target.name), \(positionTitle).",
                "As part of the \(campaign.name), investigators have begun examining the affairs of \(target.name). The announcement sent ripples through the ministry corridors.\n\n\(target.name)'s colleagues have grown notably distant. No one wants to be associated with someone under investigation."
            ),
            (
                "\(target.name) has been placed under 'residential surveillance' pending investigation.",
                "In an early-morning operation, officers from the Central Discipline Inspection Commission arrived at \(target.name)'s residence. They departed with boxes of documents.\n\n\(target.name) has not been seen in the ministry since. Their subordinates are answering questions."
            ),
            (
                "The \(campaign.name) has reached \(target.name).",
                "Your network reports that \(target.name) has been summoned for 'voluntary cooperation' with Party investigators. In practice, this means isolation and intensive questioning.\n\nThe charges are said to involve violations of Party discipline and possible economic crimes."
            )
        ]

        let selected = texts.randomElement()!

        return DynamicEvent(
            eventType: .worldNews,
            priority: (target.positionIndex ?? 0) >= 6 ? .elevated : .normal,
            title: "Investigation Announced",
            briefText: selected.briefText,
            detailedText: selected.detailedText,
            flavorText: "\"The Party disciplines its own.\"",
            initiatingCharacterId: nil,
            relatedCharacterIds: [target.id],
            turnGenerated: game.turnNumber,
            expiresOnTurn: nil,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "distance",
                    text: "Distance yourself from the accused",
                    shortText: "Distance",
                    effects: ["network": -3],
                    riskLevel: .low,
                    followUpHint: "Better safe than associated."
                ),
                EventResponse(
                    id: "observe",
                    text: "Watch the investigation unfold",
                    shortText: "Observe",
                    effects: [:],
                    riskLevel: .low,
                    followUpHint: nil
                ),
                EventResponse(
                    id: "cover_tracks",
                    text: "Quietly ensure no connection to you is found",
                    shortText: "Cover Tracks",
                    effects: ["corruptionEvidence": -5, "network": -5],
                    riskLevel: .medium,
                    followUpHint: "What connections might they find?"
                )
            ]
        )
    }

    // MARK: - Player Vulnerability Assessment

    /// Check if player is vulnerable to the current campaign
    func assessPlayerVulnerability(campaign: AntiCorruptionCampaign, game: Game) -> PlayerVulnerability {
        var riskScore = 0

        // Base risk from corruption evidence
        riskScore += game.corruptionEvidence / 2

        // Position-based risk
        let playerPosition = game.currentPositionIndex
        if campaign.type == .tigers && playerPosition >= 5 {
            riskScore += 20
        }
        if campaign.type == .flies && playerPosition < 5 {
            riskScore += 15
        }

        // Faction-based risk
        if let targetFaction = campaign.targetedFaction,
           game.playerFactionId == targetFaction {
            riskScore += 30
        }

        // Track-based risk
        if let targetTrack = campaign.targetedTrack,
           game.currentTrack == targetTrack {
            riskScore += 25
        }

        // Patron protection
        riskScore -= game.patronFavor / 4

        // Determine risk level
        switch riskScore {
        case ...20: return .safe
        case 21...40: return .moderate
        case 41...60: return .elevated
        case 61...80: return .high
        default: return .critical
        }
    }
}

struct CampaignTurnResult {
    let narrative: String
    let events: [DynamicEvent]
    let headline: String?
}

enum PlayerVulnerability {
    case safe       // Low risk
    case moderate   // Should be careful
    case elevated   // Real risk of investigation
    case high       // Likely to be targeted
    case critical   // Almost certain target

    var description: String {
        switch self {
        case .safe: return "You are not a priority target."
        case .moderate: return "You should be cautious."
        case .elevated: return "The campaign poses a real threat to you."
        case .high: return "You are likely to be targeted."
        case .critical: return "You are almost certainly on the list."
        }
    }
}
