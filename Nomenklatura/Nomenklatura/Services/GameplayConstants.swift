//
//  GameplayConstants.swift
//  Nomenklatura
//
//  Centralized gameplay constants, thresholds, and probabilities.
//  Single source of truth for game balance values.
//

import Foundation

// MARK: - Gameplay Constants

enum GameplayConstants {

    // MARK: - Patron Thresholds

    enum Patron {
        /// Patron favor below this triggers warnings
        static let lowFavorThreshold = 35

        /// Patron favor below this triggers urgent summons
        static let criticalFavorThreshold = 20

        /// Patron favor above this unlocks opportunities
        static let highFavorThreshold = 75

        /// Base chance for patron warning when favor is low
        static let baseWarningChance = 0.15

        /// Base chance for patron opportunity when favor is high
        static let baseOpportunityChance = 0.10

        /// Base chance for urgent summons when critically low
        static let baseSummonsChance = 0.40

        /// Patron favor decay per turn when not actively maintained
        static let favorDecayPerTurn = 2
    }

    // MARK: - Rival Thresholds

    enum Rival {
        /// Rival threat level that triggers aggressive action
        static let highThreatThreshold = 50

        /// Rival threat level considered critical
        static let criticalThreatThreshold = 75

        /// Base chance for rival confrontation
        static let baseConfrontationChance = 0.08

        /// Base chance for rival plot
        static let basePlotChance = 0.05

        /// Threat increase per turn when rival is active
        static let threatIncreasePerTurn = 3
    }

    // MARK: - Stability Thresholds

    enum Stability {
        /// Below this, state is in crisis
        static let criticalThreshold = 30

        /// Below this, state is unstable
        static let lowThreshold = 40

        /// Above this, state is stable
        static let stableThreshold = 60

        /// Above this, state is secure
        static let secureThreshold = 70

        /// Natural stability drift toward center per turn
        static let driftPerTurn = 1
    }

    // MARK: - Position & Power

    enum Position {
        /// Minimum position to propose non-institutional policies
        static let policyProposalMinimum = 5

        /// Minimum position to be on Standing Committee
        static let standingCommitteeMinimum = 7

        /// Position level for General Secretary
        static let generalSecretaryLevel = 8

        /// Minimum position to be considered senior
        static let seniorPositionMinimum = 4
    }

    enum Power {
        /// Power score below which GS is vulnerable
        static let vulnerableThreshold = 40

        /// Power score for stable control
        static let stableThreshold = 60

        /// Power score for dominant control
        static let dominantThreshold = 80

        /// Base power requirement to decree (bypass SC)
        static let decreeBaseRequirement = 60
    }

    // MARK: - NPC Decision Thresholds

    enum NPCDecision {
        /// Motivation + Opportunity must exceed Risk * Caution * this factor
        static let actionThresholdMultiplier = 1.0

        /// Base motivation for any action
        static let baseMotivation = 20

        /// Base risk for any action
        static let baseRisk = 20

        /// Minimum motivation to even consider acting
        static let minimumMotivation = 15

        /// Maximum caution modifier (cautious personality)
        static let maxCautionModifier = 1.5

        /// Minimum caution modifier (reckless personality)
        static let minCautionModifier = 0.5

        /// Maximum goal-driven events per turn (to avoid overwhelming player)
        static let maxGoalEventsPerTurn = 2
    }

    // MARK: - Event Probabilities

    enum EventProbability {
        /// Chance of a quiet turn (no events)
        static let quietTurnChance = 0.35

        /// Maximum events per turn in normal circumstances
        static let maxEventsPerTurnNormal = 2

        /// Maximum events per turn during crisis
        static let maxEventsPerTurnCrisis = 3

        /// Base cooldown for event types (turns)
        static let defaultEventCooldown = 3

        /// Patron events cooldown
        static let patronEventCooldown = 2

        /// Rival events cooldown
        static let rivalEventCooldown = 3

        /// World events cooldown
        static let worldEventCooldown = 1
    }

    // MARK: - Faction Standing

    enum Faction {
        /// Standing below which faction is hostile
        static let hostileThreshold = 30

        /// Standing below which faction is unfriendly
        static let unfriendlyThreshold = 40

        /// Standing above which faction is friendly
        static let friendlyThreshold = 60

        /// Standing above which faction is allied
        static let alliedThreshold = 75

        /// Faction power considered dominant
        static let dominantPowerThreshold = 70

        /// Faction power considered weak
        static let weakPowerThreshold = 30
    }

    // MARK: - Personality Impact

    enum Personality {
        /// Threshold for "high" personality trait
        static let highTraitThreshold = 70

        /// Threshold for "low" personality trait
        static let lowTraitThreshold = 30

        /// Division factor for personality → probability conversion
        static let traitToProbabilityDivisor = 100.0

        /// Division factor for personality → modifier conversion
        static let traitToModifierDivisor = 5
    }

    // MARK: - Memory & Relationship Decay

    enum Decay {
        /// Disposition decay per turn without interaction
        static let dispositionDecayPerTurn = 1

        /// Grudge decay per turn (grudges fade slowly)
        static let grudgeDecayPerTurn = 1

        /// Gratitude decay per turn (gratitude fades faster)
        static let gratitudeDecayPerTurn = 2

        /// Memory strength decay per turn
        static let memoryStrengthDecayPerTurn = 2

        /// Fear decay per turn
        static let fearDecayPerTurn = 1

        /// Trust decay per turn without interaction
        static let trustDecayPerTurn = 1
    }

    // MARK: - Goal System

    enum Goals {
        /// Turns before goal is considered stale
        static let staleGoalTurns = 20

        /// Frustration level that triggers desperation
        static let frustrationDesperation = 50

        /// Frustration level that triggers goal abandonment
        static let frustrationAbandonment = 80

        /// Priority boost when deadline is within this many turns
        static let urgentDeadlineTurns = 3

        /// Priority boost for urgent goals
        static let urgentPriorityBoost = 20

        /// Maximum goals per NPC
        static let maxGoalsPerNPC = 5
    }

    // MARK: - Need System

    enum Needs {
        /// Need level below which is critical
        static let criticalNeedThreshold = 25

        /// Need level below which is urgent
        static let urgentNeedThreshold = 40

        /// Need level considered satisfied
        static let satisfiedNeedThreshold = 60

        /// Need decay per turn
        static let needDecayPerTurn = 2

        /// Ideological commitment threshold for true believer
        static let trueBelieverbThreshold = 75

        /// Ideological commitment threshold for disillusionment
        static let disillusionedThreshold = 25
    }

    // MARK: - Political AI (GS Behavior)

    enum PoliticalAI {
        /// Chance per turn that GS will attempt an action
        static let baseGSActionChance = 10

        /// Maximum GS action chance (personality can add to this)
        static let maxGSActionChance = 30

        /// Chance per turn that SC member proposes something
        static let baseSCMemberProposalChance = 5

        /// Turns to wait before processing pending proposal
        static let proposalVotingDelay = 1

        /// Power threshold for GS to decree instead of propose
        static let decreeThreshold = 60

        /// Committee loyalty threshold for reliable majority
        static let reliableMajorityThreshold = 50
    }

    // MARK: - Espionage

    enum Espionage {
        /// Base detection probability per turn for active spies
        static let baseDetectionChance = 0.02

        /// Detection probability increase per suspicious action
        static let detectionIncreasePerAction = 0.01

        /// Security effectiveness that doubles detection chance
        static let highSecurityThreshold = 70

        /// Ideological commitment below which vulnerable to recruitment
        static let recruitmentVulnerabilityThreshold = 30
    }

    // MARK: - Ambient Activity

    enum AmbientActivity {
        /// Chance per turn per NPC to generate ambient action
        static let baseAmbientActionChance = 0.15

        /// Maximum ambient actions to track per NPC
        static let maxTrackedActionsPerNPC = 10

        /// Turns before ambient actions are pruned
        static let ambientActionRetentionTurns = 10
    }
}

// MARK: - Helper Extensions

extension GameplayConstants {

    /// Calculate caution modifier from personality traits
    static func calculateCaution(ambitious: Int, paranoid: Int, ruthless: Int) -> Double {
        // Ambitious and ruthless = less cautious
        // Paranoid = more cautious
        let baseCaution = 1.0
        let ambitiousMod = Double(ambitious) / 200.0  // 0 to 0.5
        let ruthlessMod = Double(ruthless) / 200.0    // 0 to 0.5
        let paranoidMod = Double(paranoid) / 200.0    // 0 to 0.5

        let caution = baseCaution - ambitiousMod - ruthlessMod + paranoidMod
        return max(NPCDecision.minCautionModifier, min(NPCDecision.maxCautionModifier, caution))
    }

    /// Calculate action threshold: should NPC act?
    static func shouldAct(motivation: Int, opportunity: Int, risk: Int, caution: Double) -> Bool {
        let actionScore = Double(motivation + opportunity)
        let threshold = Double(risk) * caution * NPCDecision.actionThresholdMultiplier
        return actionScore > threshold
    }

    /// Get maximum events for this turn based on game state
    static func maxEventsForTurn(stability: Int, isInCrisis: Bool) -> Int {
        if isInCrisis || stability < Stability.criticalThreshold {
            return EventProbability.maxEventsPerTurnCrisis
        }
        return EventProbability.maxEventsPerTurnNormal
    }
}
