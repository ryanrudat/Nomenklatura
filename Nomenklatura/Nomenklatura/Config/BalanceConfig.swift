//
//  BalanceConfig.swift
//  Nomenklatura
//
//  Centralized, tunable balance parameters for playtesting.
//  These can be adjusted during development to find optimal game feel.
//  Defaults reference GameplayConstants for consistency.
//

import Foundation

// MARK: - Balance Configuration

/// Tunable balance parameters for game feel adjustment.
/// Use these during playtesting to find optimal values.
struct BalanceConfig {

    // MARK: - Event Pacing

    /// Base chance of a quiet turn (no dynamic events)
    static var quietTurnChance: Double = 0.35

    /// Additional quiet chance for early game (turns 1-3)
    static var earlyGameQuietBonus: Double = 0.25

    /// Penalty to quiet chance during crisis (stability < 40)
    static var crisisQuietPenalty: Double = 0.15

    /// Consecutive event turns that force a quiet turn
    static var forceQuietAfterEventTurns: Int = 2

    // MARK: - Rival Balance

    /// Base chance per turn for rival to take action
    static var rivalActionBaseChance: Double = 0.05

    /// Maximum rival action chance (cap)
    static var rivalActionMaxChance: Double = 0.35

    /// Cooldown between rival events (turns)
    static var rivalEventCooldown: Int = 5

    /// Rival threat threshold for aggressive actions
    static var rivalAggressiveThreshold: Int = 50

    // MARK: - Patron Balance

    /// Patron favor threshold for warnings
    static var patronWarningThreshold: Int = 35

    /// Patron favor threshold for urgent summons
    static var patronCriticalThreshold: Int = 20

    /// Patron favor decay per turn without maintenance
    static var patronFavorDecayPerTurn: Int = 2

    /// Cooldown between patron events (turns)
    static var patronEventCooldown: Int = 3

    // MARK: - Stat Effect Caps & Balance

    /// Maximum stat change per individual stat (national stats like stability, treasury)
    static var maxNationalStatChange: Int = 15

    /// Maximum stat change per individual stat (personal stats like standing, favor)
    static var maxPersonalStatChange: Int = 12

    /// Minimum stat change magnitude to be noticeable
    static var minNoticeableStatChange: Int = 3

    /// Maximum total positive effects per option (sum of all gains)
    static var maxTotalPositiveEffects: Int = 25

    /// Maximum total negative effects per option (sum of all losses, as positive number)
    static var maxTotalNegativeEffects: Int = 25

    /// Maximum net imbalance (positive - negative) per option
    /// Options should have trade-offs, not be pure wins/losses
    static var maxNetImbalance: Int = 10

    /// Typical effect ranges for AI guidance
    static var minorEffectMin: Int = 3
    static var minorEffectMax: Int = 6
    static var moderateEffectMin: Int = 7
    static var moderateEffectMax: Int = 10
    static var majorEffectMin: Int = 11
    static var majorEffectMax: Int = 15

    // MARK: - Game Over Thresholds

    /// Rival threat level that can trigger assassination (with low network)
    static var assassinationRivalThreat: Int = 95

    /// Network level below which assassination is possible
    static var assassinationNetworkThreshold: Int = 15

    /// Stability threshold for revolution
    static var revolutionStabilityThreshold: Int = 5

    /// Popular support threshold for revolution
    static var revolutionPopularSupportThreshold: Int = 10

    /// Military loyalty threshold for coup
    static var coupMilitaryLoyaltyThreshold: Int = 20

    /// Stability threshold for coup
    static var coupStabilityThreshold: Int = 20

    /// Number of seceded regions for territorial collapse
    static var territorialCollapseRegions: Int = 3

    // MARK: - Progression

    /// Action points per turn
    static var actionPointsPerTurn: Int = 2

    /// Maximum character interactions per turn
    static var maxInteractionsPerTurn: Int = 2

    /// Starting position index for new games
    static var startingPositionIndex: Int = 1

    // MARK: - NPC Behavior

    /// Base ambient action chance per NPC per turn
    static var npcAmbientActionChance: Double = 0.15

    /// Maximum goal-driven events per turn
    static var maxGoalEventsPerTurn: Int = 2

    /// Disposition decay per turn without interaction
    static var dispositionDecayPerTurn: Int = 1

    // MARK: - Economy

    /// Newspaper event chance modifier after major events
    static var newspaperChanceAfterMajorEvent: Double = 0.30

    /// Newspaper chance bonus if no newspaper in 5+ turns
    static var newspaperChanceStaleBonus: Double = 0.15

    /// Maximum newspaper chance cap
    static var maxNewspaperChance: Double = 0.60

    // MARK: - Debug Helpers

    /// Reset all values to defaults
    static func resetToDefaults() {
        // Event Pacing
        quietTurnChance = 0.35
        earlyGameQuietBonus = 0.25
        crisisQuietPenalty = 0.15
        forceQuietAfterEventTurns = 2

        // Rival Balance
        rivalActionBaseChance = 0.05
        rivalActionMaxChance = 0.35
        rivalEventCooldown = 5
        rivalAggressiveThreshold = 50

        // Patron Balance
        patronWarningThreshold = 35
        patronCriticalThreshold = 20
        patronFavorDecayPerTurn = 2
        patronEventCooldown = 3

        // Stat Effect Caps & Balance
        maxNationalStatChange = 15
        maxPersonalStatChange = 12
        minNoticeableStatChange = 3
        maxTotalPositiveEffects = 25
        maxTotalNegativeEffects = 25
        maxNetImbalance = 10
        minorEffectMin = 3
        minorEffectMax = 6
        moderateEffectMin = 7
        moderateEffectMax = 10
        majorEffectMin = 11
        majorEffectMax = 15

        // Game Over Thresholds
        assassinationRivalThreat = 95
        assassinationNetworkThreshold = 15
        revolutionStabilityThreshold = 5
        revolutionPopularSupportThreshold = 10
        coupMilitaryLoyaltyThreshold = 20
        coupStabilityThreshold = 20
        territorialCollapseRegions = 3

        // Progression
        actionPointsPerTurn = 2
        maxInteractionsPerTurn = 2
        startingPositionIndex = 1

        // NPC Behavior
        npcAmbientActionChance = 0.15
        maxGoalEventsPerTurn = 2
        dispositionDecayPerTurn = 1

        // Economy
        newspaperChanceAfterMajorEvent = 0.30
        newspaperChanceStaleBonus = 0.15
        maxNewspaperChance = 0.60
    }

    /// Print current configuration for debugging
    static func printCurrentConfig() {
        #if DEBUG
        print("=== Balance Configuration ===")
        print("Event Pacing:")
        print("  quietTurnChance: \(quietTurnChance)")
        print("  earlyGameQuietBonus: \(earlyGameQuietBonus)")
        print("  crisisQuietPenalty: \(crisisQuietPenalty)")
        print("")
        print("Rival Balance:")
        print("  rivalActionBaseChance: \(rivalActionBaseChance)")
        print("  rivalActionMaxChance: \(rivalActionMaxChance)")
        print("  rivalEventCooldown: \(rivalEventCooldown)")
        print("")
        print("Patron Balance:")
        print("  patronWarningThreshold: \(patronWarningThreshold)")
        print("  patronFavorDecayPerTurn: \(patronFavorDecayPerTurn)")
        print("")
        print("Game Over Thresholds:")
        print("  assassinationRivalThreat: \(assassinationRivalThreat)")
        print("  revolutionStabilityThreshold: \(revolutionStabilityThreshold)")
        print("==============================")
        #endif
    }
}
