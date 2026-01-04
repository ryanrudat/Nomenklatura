//
//  FamilyThreatService.swift
//  Nomenklatura
//
//  Handles threats to the player's family from rivals and the security apparatus.
//  Authentic Communist-style pressure tactics:
//  - Investigation Summons: Family member "invited" to assist inquiry
//  - Work Unit Pressure: Spouse's workplace questions their loyalty
//  - Children's School: Teacher reports child's "ideological confusion"
//  - Guilt by Association: Enemy denounces your relative
//  - Confession Extraction: BPS suggests family testimony could help your case
//  - Exile Threat: "Perhaps your wife would benefit from rural reeducation"
//

import Foundation
import os.log

private let threatLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "FamilyThreat")

// MARK: - Family Threat Types

enum FamilyThreatType: String, Codable, CaseIterable {
    case investigationSummons    // Family member summoned for questioning
    case workUnitPressure        // Pressure at spouse's workplace
    case schoolReport            // Child's school raises concerns
    case guiltByAssociation      // Association with you becomes liability
    case confessionRequest       // Asked to testify against you
    case exileThreat             // Threat of rustication/exile
    case surveillanceNotice      // Family placed under observation
    case socialIsolation         // Friends and neighbors begin avoiding family

    var displayName: String {
        switch self {
        case .investigationSummons: return "Investigation Summons"
        case .workUnitPressure: return "Work Unit Pressure"
        case .schoolReport: return "School Report"
        case .guiltByAssociation: return "Guilt by Association"
        case .confessionRequest: return "Confession Request"
        case .exileThreat: return "Exile Threat"
        case .surveillanceNotice: return "Under Surveillance"
        case .socialIsolation: return "Social Isolation"
        }
    }

    var severity: Int {
        switch self {
        case .socialIsolation: return 20
        case .schoolReport: return 30
        case .workUnitPressure: return 40
        case .surveillanceNotice: return 50
        case .investigationSummons: return 60
        case .guiltByAssociation: return 70
        case .confessionRequest: return 80
        case .exileThreat: return 90
        }
    }
}

// MARK: - Family Threat

struct FamilyThreat: Codable, Identifiable {
    var id: UUID = UUID()
    var type: FamilyThreatType
    var title: String
    var narrative: String
    var turnOccurred: Int

    // Who is threatened
    var targetMemberId: UUID?
    var targetMemberName: String?

    // Source of threat
    var sourceType: ThreatSource
    var sourceCharacterId: String?
    var sourceCharacterName: String?

    // Resolution
    var isResolved: Bool = false
    var resolution: String?
    var turnResolved: Int?

    // Effects if unresolved
    var harmonyDamage: Int
    var vulnerabilityIncrease: Int
    var informantRisk: Int  // Chance family member becomes informant
}

enum ThreatSource: String, Codable {
    case rival          // Political rival targeting you
    case bps            // Security services
    case factionEnemy   // Enemy faction
    case system         // General paranoia/system pressure
    case colleague      // Someone currying favor by denouncing
}

// MARK: - Family Threat Service

@MainActor
class FamilyThreatService {
    static let shared = FamilyThreatService()

    private init() {}

    // MARK: - Check for Threats

    /// Check if a family threat should occur this turn
    func shouldTriggerThreat(family: PlayerFamily, game: Game) -> Bool {
        guard family.hasFamily else { return false }

        // Base chance depends on rival threat and player's vulnerability
        var chance = 5  // Low base chance

        // Increase with rival threat
        if game.rivalThreat >= 60 {
            chance += 10
        }
        if game.rivalThreat >= 80 {
            chance += 10
        }

        // Increase with coalition against player
        if game.coalitionStrength >= 50 {
            chance += 8
        }

        // Increase during purges/instability
        if game.stability < 30 {
            chance += 12
        }

        // Increase if already vulnerable
        if family.vulnerabilityScore >= 50 {
            chance += 10
        }

        // Check for active hostile rivals
        let hostileRivals = game.characters.filter {
            $0.isRival && $0.disposition < 30 && $0.isActive
        }
        chance += hostileRivals.count * 5

        return Int.random(in: 1...100) <= chance
    }

    // MARK: - Generate Threat

    /// Generate a family threat based on current situation
    func generateThreat(family: PlayerFamily, game: Game) -> FamilyThreat? {
        guard family.hasFamily else { return nil }

        // Select threat type based on context
        let threatType = selectThreatType(family: family, game: game)

        // Select target family member
        guard let target = selectTarget(family: family, threatType: threatType) else {
            return nil
        }

        // Determine threat source
        let source = determineSource(game: game)

        // Generate the threat
        let threat = createThreat(
            type: threatType,
            target: target,
            source: source,
            family: family,
            game: game
        )

        threatLogger.info("Generated family threat: \(threatType.rawValue) against \(target.name)")

        return threat
    }

    private func selectThreatType(family: PlayerFamily, game: Game) -> FamilyThreatType {
        var weights: [FamilyThreatType: Int] = [:]

        for type in FamilyThreatType.allCases {
            // Base weight inversely proportional to severity (milder threats more common)
            weights[type] = 100 - type.severity
        }

        // Context adjustments
        if game.stability < 30 {
            weights[.investigationSummons, default: 0] += 20
            weights[.confessionRequest, default: 0] += 15
        }

        if game.rivalThreat > 70 {
            weights[.guiltByAssociation, default: 0] += 20
        }

        if !family.children.isEmpty {
            weights[.schoolReport, default: 0] += 15
        }

        if family.spouse != nil {
            weights[.workUnitPressure, default: 0] += 10
        }

        if family.vulnerabilityScore > 60 {
            weights[.exileThreat, default: 0] += 15
            weights[.confessionRequest, default: 0] += 15
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        var roll = Int.random(in: 1...max(totalWeight, 1))

        for (type, weight) in weights {
            roll -= weight
            if roll <= 0 {
                return type
            }
        }

        return .socialIsolation
    }

    private func selectTarget(family: PlayerFamily, threatType: FamilyThreatType) -> PlayerFamilyMember? {
        switch threatType {
        case .schoolReport:
            // Must target a child
            return family.children.filter { $0.age >= 6 && $0.age <= 18 }.randomElement()

        case .workUnitPressure:
            // Target spouse
            return family.spouse

        case .confessionRequest, .exileThreat:
            // Prefer spouse, but could be adult child
            if let spouse = family.spouse {
                return spouse
            }
            return family.children.filter { $0.age >= 18 }.randomElement()

        default:
            // Any family member
            return family.allFamilyMembers.randomElement()
        }
    }

    private func determineSource(game: Game) -> (ThreatSource, String?, String?) {
        // Check for active hostile rival
        let hostileRivals = game.characters.filter {
            $0.isRival && $0.disposition < 30 && $0.isActive
        }

        if let rival = hostileRivals.randomElement(), Int.random(in: 1...100) <= 50 {
            return (.rival, rival.templateId, rival.name)
        }

        // Check for enemy faction
        let playerFaction = game.playerFactionId
        let enemyFactions = game.factions.filter {
            $0.factionId != playerFaction && $0.power >= 30
        }

        if let enemy = enemyFactions.randomElement(), Int.random(in: 1...100) <= 30 {
            return (.factionEnemy, enemy.factionId, enemy.name)
        }

        // Default to system pressure or BPS
        if game.stability < 40 {
            return (.bps, nil, "Bureau of Public Security")
        }

        return (.system, nil, nil)
    }

    private func createThreat(
        type: FamilyThreatType,
        target: PlayerFamilyMember,
        source: (ThreatSource, String?, String?),
        family: PlayerFamily,
        game: Game
    ) -> FamilyThreat {
        let (sourceType, sourceId, sourceName) = source

        let (title, narrative) = generateThreatNarrative(
            type: type,
            target: target,
            sourceName: sourceName,
            game: game
        )

        let informantRisk: Int
        switch type {
        case .confessionRequest:
            informantRisk = 40 + target.temperament.informantRisk / 2
        case .investigationSummons:
            informantRisk = 25 + target.temperament.informantRisk / 2
        case .exileThreat:
            informantRisk = 50  // Extreme pressure
        default:
            informantRisk = target.temperament.informantRisk
        }

        return FamilyThreat(
            type: type,
            title: title,
            narrative: narrative,
            turnOccurred: game.turnNumber,
            targetMemberId: target.id,
            targetMemberName: target.name,
            sourceType: sourceType,
            sourceCharacterId: sourceId,
            sourceCharacterName: sourceName,
            harmonyDamage: type.severity / 5,
            vulnerabilityIncrease: type.severity / 3,
            informantRisk: informantRisk
        )
    }

    private func generateThreatNarrative(
        type: FamilyThreatType,
        target: PlayerFamilyMember,
        sourceName: String?,
        game: Game
    ) -> (String, String) {
        let targetName = target.name

        switch type {
        case .investigationSummons:
            let narratives = [
                ("Investigation Summons",
                 "\(targetName) has been \"invited\" to assist with an ongoing investigation. The summons is politely worded, but everyone knows there's no refusing. They leave in the morning and don't return until evening, pale and unwilling to discuss what was asked."),

                ("Routine Questions",
                 "Officials arrive at your home while you're at work. They wish to speak with \(targetName) about \"certain matters.\" By the time you learn of this, the interview is over. \(targetName) assures you it was routine. Their trembling hands say otherwise.")
            ]
            return narratives.randomElement()!

        case .workUnitPressure:
            return ("Work Unit Pressure",
                    "\(targetName) comes home troubled. \"They called a criticism session today,\" they explain. \"Not for me—not directly—but my supervisor asked pointed questions about our family's political reliability. Comrades who smiled yesterday now look away.\"")

        case .schoolReport:
            return ("Concerning Report from School",
                    "A letter arrives from \(targetName)'s school. \"We have concerns about ideological development,\" it reads. \"The child shows confusion about class struggle and has made statements suggesting bourgeois influence at home. A meeting has been scheduled to discuss corrective measures.\"")

        case .guiltByAssociation:
            let source = sourceName ?? "Someone"
            return ("Guilt by Association",
                    "\(source) has raised questions about your family's connections to \"unreliable elements.\" \(targetName) finds themselves frozen out of work unit activities, passed over for assignments. The shadow of your position has fallen upon them.")

        case .confessionRequest:
            return ("Request for Testimony",
                    "Officials visit \(targetName) with a proposal: testify to certain \"facts\" about your activities, and life will become much easier for the family. Refuse, and... well, they're sure \(targetName) will make the right choice. The pressure is immense.")

        case .exileThreat:
            return ("Exile Threat",
                    "The message is delivered politely but unmistakably: unless circumstances change, \(targetName) may be \"reassigned\" to assist with development in the distant provinces. Rural reeducation, they call it. A euphemism for exile.")

        case .surveillanceNotice:
            return ("Under Observation",
                    "\(targetName) notices them first—the same faces on the street, the same car parked outside their work unit. \"We're being watched,\" they whisper. The knowledge itself is a form of pressure, a reminder that privacy is a privilege, not a right.")

        case .socialIsolation:
            return ("Social Isolation",
                    "It happens gradually. Friends stop calling. Neighbors develop urgent business when \(targetName) appears. The building committee chairwoman, once friendly, now offers only curt nods. Someone has marked your family, and everyone is taking notice.")
        }
    }

    // MARK: - Apply Threat Effects

    /// Apply the immediate effects of a threat to the family
    func applyThreatEffects(threat: FamilyThreat, family: PlayerFamily) {
        family.damageHarmony(amount: threat.harmonyDamage)
        family.vulnerabilityScore = min(100, family.vulnerabilityScore + threat.vulnerabilityIncrease)

        // Mark target as under pressure
        if let targetId = threat.targetMemberId {
            family.applyPressure(memberId: targetId)
        }

        // Check for informant conversion
        if Int.random(in: 1...100) <= threat.informantRisk {
            if let targetId = threat.targetMemberId,
               var spouse = family.spouse,
               spouse.id == targetId {
                spouse.isInformant = true
                family.spouse = spouse
                threatLogger.warning("Family member \(spouse.name) became informant under pressure")
            }

            var updatedChildren = family.children
            if let targetId = threat.targetMemberId,
               let index = updatedChildren.firstIndex(where: { $0.id == targetId }) {
                updatedChildren[index].isInformant = true
                family.children = updatedChildren
                threatLogger.warning("Family member \(updatedChildren[index].name) became informant under pressure")
            }
        }
    }

    // MARK: - Resolution Options

    /// Generate resolution options for a family threat
    func generateResolutionOptions(threat: FamilyThreat, game: Game) -> [ThreatResolutionOption] {
        var options: [ThreatResolutionOption] = []

        // Option 1: Use political capital to protect
        options.append(ThreatResolutionOption(
            id: UUID(),
            title: "Use Your Influence",
            description: "Leverage your position to make this problem go away.",
            standingCost: 15,
            networkCost: 10,
            successChance: calculateProtectionChance(game: game),
            successResult: "Your intervention resolves the immediate threat, but you've spent political capital.",
            failureResult: "Your attempt to intervene backfires, drawing more attention to your family."
        ))

        // Option 2: Accept and endure
        options.append(ThreatResolutionOption(
            id: UUID(),
            title: "Weather the Storm",
            description: "Do nothing and hope it passes. Sometimes silence is survival.",
            standingCost: 0,
            networkCost: 0,
            successChance: 50,
            successResult: "The pressure eases over time. Your family survives, shaken but intact.",
            failureResult: "Without intervention, the situation worsens. Your family's vulnerability increases."
        ))

        // Option 3: Counter-attack (if source is known rival)
        if threat.sourceType == .rival, let _ = threat.sourceCharacterId {
            options.append(ThreatResolutionOption(
                id: UUID(),
                title: "Strike Back",
                description: "Target the source of this threat. A dangerous gambit.",
                standingCost: 5,
                networkCost: 20,
                successChance: 40,
                successResult: "Your counter-attack catches your rival off-guard. They back down.",
                failureResult: "Your rival anticipated this. The conflict escalates."
            ))
        }

        // Option 4: Sacrifice (extreme)
        if threat.type == .confessionRequest || threat.type == .exileThreat {
            options.append(ThreatResolutionOption(
                id: UUID(),
                title: "Sacrifice for the Cause",
                description: "Publicly distance yourself from your family to protect your position.",
                standingCost: -10,  // Actually gains standing with hardliners
                networkCost: 0,
                successChance: 90,
                successResult: "Your family is devastated, but you demonstrate ideological commitment. Your position is secure.",
                failureResult: "Even this sacrifice is not enough. You've lost both family and standing."
            ))
        }

        return options
    }

    private func calculateProtectionChance(game: Game) -> Int {
        var chance = 50

        // Higher position = more influence
        chance += game.currentPositionIndex * 5

        // Network helps
        chance += game.network / 5

        // Standing helps
        chance += game.standing / 5

        // Patron can help
        chance += game.patronFavor / 4

        return min(90, max(20, chance))
    }

    /// Resolve a threat using the selected option
    func resolveThreat(
        threat: inout FamilyThreat,
        option: ThreatResolutionOption,
        game: Game
    ) -> ThreatResolutionResult {
        let roll = Int.random(in: 1...100)
        let success = roll <= option.successChance

        threat.isResolved = true
        threat.turnResolved = game.turnNumber
        threat.resolution = success ? option.successResult : option.failureResult

        return ThreatResolutionResult(
            success: success,
            narrative: success ? option.successResult : option.failureResult,
            standingChange: success ? -option.standingCost : -option.standingCost * 2,
            networkChange: success ? -option.networkCost : -option.networkCost,
            vulnerabilityChange: success ? -20 : 20
        )
    }
}

// MARK: - Resolution Types

struct ThreatResolutionOption: Codable, Identifiable {
    var id: UUID
    var title: String
    var description: String
    var standingCost: Int
    var networkCost: Int
    var successChance: Int
    var successResult: String
    var failureResult: String
}

struct ThreatResolutionResult: Codable {
    var success: Bool
    var narrative: String
    var standingChange: Int
    var networkChange: Int
    var vulnerabilityChange: Int
}
