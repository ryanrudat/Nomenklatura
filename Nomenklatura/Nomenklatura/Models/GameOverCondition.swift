//
//  GameOverCondition.swift
//  Nomenklatura
//
//  Game over conditions - the game ends only when the dynasty fails
//

import Foundation

// MARK: - Game Over Type

enum GameOverType: String, Codable, CaseIterable {
    // Personal Defeats
    case assassinationNoHeir       // Player killed, no heir to continue
    case deathNoHeir               // Natural death, illness, accident without successor
    case purgedNoHeir              // Removed by rivals, no heir
    case dynastyExtinct            // All potential heirs eliminated
    case corruptionExposed         // Corruption scandal leads to arrest/execution

    // Party Collapse
    case revolutionOverthrow       // Government overthrown by popular uprising
    case militaryCoup              // Army seizes power, Party swept aside

    // State Dissolution
    case territorialDisintegration // Multiple regions secede, union collapses
    case capitalFalls              // Washington falls to rebels or foreign power
    case foreignInvasion           // Military defeat by foreign power

    // Nuclear Catastrophe
    case nuclearWar                // Escalation leads to mutual destruction

    var displayTitle: String {
        switch self {
        case .assassinationNoHeir:
            return "ASSASSINATED"
        case .revolutionOverthrow:
            return "OVERTHROWN"
        case .deathNoHeir:
            return "PERISHED"
        case .purgedNoHeir:
            return "PURGED"
        case .dynastyExtinct:
            return "DYNASTY EXTINCT"
        case .corruptionExposed:
            return "EXPOSED"
        case .militaryCoup:
            return "COUP D'ÉTAT"
        case .territorialDisintegration:
            return "UNION DISSOLVED"
        case .capitalFalls:
            return "CAPITAL LOST"
        case .foreignInvasion:
            return "DEFEATED"
        case .nuclearWar:
            return "ANNIHILATION"
        }
    }

    var epitaph: String {
        switch self {
        case .assassinationNoHeir:
            return "Your enemies struck from the shadows. With no heir to carry on your legacy, your line ends here."
        case .revolutionOverthrow:
            return "The people rose against the Party. You faced the firing squad as the old order crumbled."
        case .deathNoHeir:
            return "Time claims all comrades eventually. Without a successor to continue your work, your influence dies with you."
        case .purgedNoHeir:
            return "Your rivals finally succeeded. Stripped of power and dignity, you vanish into the camps."
        case .dynastyExtinct:
            return "One by one, those who carried your banner fell. The last of your line has perished."
        case .corruptionExposed:
            return "The evidence was undeniable. Your corruption was laid bare for all to see. The Party makes examples of such betrayals."
        case .militaryCoup:
            return "The generals decided they could rule better than the Party. Tanks rolled through Washington, and the old guard was swept away in a night."
        case .territorialDisintegration:
            return "The union has fallen apart. Region after region declared independence until nothing remained but a rump state. The socialist experiment has ended."
        case .capitalFalls:
            return "Washington has fallen. Whether to rebels or invaders, the heart of the state has stopped beating. There is nothing left to rule."
        case .foreignInvasion:
            return "The armies of the enemy have prevailed. The People's Socialist Republic exists no more, its leaders fled or captured."
        case .nuclearWar:
            return "The missiles flew. In thirty minutes, centuries of civilization ended. There are no victors in nuclear war—only degrees of losing."
        }
    }

    var iconName: String {
        switch self {
        case .assassinationNoHeir: return "target"
        case .revolutionOverthrow: return "flame.fill"
        case .deathNoHeir: return "moon.zzz.fill"
        case .purgedNoHeir: return "xmark.seal.fill"
        case .dynastyExtinct: return "person.3.sequence.fill"
        case .corruptionExposed: return "doc.text.magnifyingglass"
        case .militaryCoup: return "shield.lefthalf.filled"
        case .territorialDisintegration: return "map"
        case .capitalFalls: return "building.columns"
        case .foreignInvasion: return "airplane"
        case .nuclearWar: return "bolt.fill"
        }
    }

    /// Whether this game over could have been prevented with an heir
    var couldHaveBeenPrevented: Bool {
        switch self {
        case .revolutionOverthrow, .militaryCoup, .territorialDisintegration,
             .capitalFalls, .foreignInvasion, .nuclearWar:
            return false  // System-level failures destroy everything
        default:
            return true   // Personal failures could continue with heir
        }
    }

    /// Category of defeat for scoring/statistics
    var category: GameOverCategory {
        switch self {
        case .assassinationNoHeir, .deathNoHeir, .purgedNoHeir,
             .dynastyExtinct, .corruptionExposed:
            return .personalDefeat
        case .revolutionOverthrow, .militaryCoup:
            return .partyCollapse
        case .territorialDisintegration, .capitalFalls, .foreignInvasion:
            return .stateDisintegration
        case .nuclearWar:
            return .globalCatastrophe
        }
    }
}

enum GameOverCategory: String, Codable, CaseIterable {
    case personalDefeat         // Player removed, but system might survive
    case partyCollapse          // Party loses power to other forces
    case stateDisintegration    // The nation itself ceases to exist
    case globalCatastrophe      // Everyone loses

    var displayName: String {
        switch self {
        case .personalDefeat: return "Personal Defeat"
        case .partyCollapse: return "Party Collapse"
        case .stateDisintegration: return "State Dissolution"
        case .globalCatastrophe: return "Global Catastrophe"
        }
    }
}

// MARK: - Game Over Condition

struct GameOverCondition: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: GameOverType
    var turnOccurred: Int
    var cause: String                    // Specific narrative cause
    var finalPosition: String            // Position held at game over
    var dynastyLength: Int               // Total turns dynasty survived
    var heirsLost: Int                   // Number of heirs who also fell
    var badgesEarned: [String]           // Badges earned during this run

    /// Summary statistics for the run
    var stats: GameOverStats
}

struct GameOverStats: Codable {
    var turnsPlayed: Int
    var highestPosition: String
    var highestPositionIndex: Int
    var tracksExplored: [String]         // Tracks the player had affinity in
    var charactersInfluenced: Int
    var rivalsDefeated: Int
    var patronsServed: Int
    var majorDecisions: Int
    var assassinationsSurvived: Int
    var successfulSuccessions: Int       // How many times dynasty passed to heir
}

// MARK: - Game Over Checker

class GameOverChecker {

    /// Check if any game over condition is met
    static func checkGameOver(game: Game) -> GameOverCondition? {
        // Check system-level catastrophes first (cannot be prevented)
        if let nuclearEnd = checkNuclearWar(game: game) {
            return nuclearEnd
        }

        if let territorialEnd = checkTerritorialDisintegration(game: game) {
            return territorialEnd
        }

        if let capitalEnd = checkCapitalFalls(game: game) {
            return capitalEnd
        }

        if let invasionEnd = checkForeignInvasion(game: game) {
            return invasionEnd
        }

        // Check Party-level failures
        if let revolutionEnd = checkRevolution(game: game) {
            return revolutionEnd
        }

        if let coupEnd = checkMilitaryCoup(game: game) {
            return coupEnd
        }

        // Check personal failures (can be prevented with heir)
        if let corruptionEnd = checkCorruptionExposed(game: game) {
            return corruptionEnd
        }

        if let assassinationEnd = checkAssassination(game: game) {
            return assassinationEnd
        }

        if let deathEnd = checkDeath(game: game) {
            return deathEnd
        }

        if let purgeEnd = checkPurge(game: game) {
            return purgeEnd
        }

        return nil
    }

    // MARK: - System-Level Checks (Cannot be prevented)

    private static func checkNuclearWar(game: Game) -> GameOverCondition? {
        // Nuclear war triggered by extreme world tension and crisis escalation
        guard game.variables["world_tension"] != nil else { return nil }
        let tension = Int(game.variables["world_tension"] ?? "0") ?? 0

        // Check for nuclear escalation flag from international crisis
        if game.flags.contains("nuclear_escalation") || tension >= 100 {
            return createGameOver(
                type: .nuclearWar,
                game: game,
                cause: "Nuclear exchange with enemy superpower"
            )
        }

        return nil
    }

    private static func checkTerritorialDisintegration(game: Game) -> GameOverCondition? {
        // Check for territorial collapse
        if game.variables["game_over_reason"] == "territorial_disintegration" {
            return createGameOver(
                type: .territorialDisintegration,
                game: game,
                cause: "Multiple regions successfully seceded from the union"
            )
        }

        if game.variables["game_over_reason"] == "economic_collapse_secession" {
            return createGameOver(
                type: .territorialDisintegration,
                game: game,
                cause: "Economic collapse following regional secessions"
            )
        }

        // Direct check on regions (threshold configurable via BalanceConfig)
        let secededRegions = game.regions.filter { $0.status == .seceded }
        if secededRegions.count >= BalanceConfig.territorialCollapseRegions {
            return createGameOver(
                type: .territorialDisintegration,
                game: game,
                cause: "Union dissolved as \(secededRegions.count) regions declared independence"
            )
        }

        return nil
    }

    private static func checkCapitalFalls(game: Game) -> GameOverCondition? {
        // Check for capital secession
        if game.variables["game_over_reason"] == "capital_seceded" {
            return createGameOver(
                type: .capitalFalls,
                game: game,
                cause: "The capital region has been lost"
            )
        }

        // Check if capital region exists and its status
        if let capitalRegion = game.regions.first(where: { $0.regionType == RegionType.capital.rawValue }) {
            if capitalRegion.status == .seceded {
                return createGameOver(
                    type: .capitalFalls,
                    game: game,
                    cause: "Washington has fallen to rebel forces"
                )
            }
        }

        // Check for flag from foreign invasion
        if game.flags.contains("capital_captured") {
            return createGameOver(
                type: .capitalFalls,
                game: game,
                cause: "Enemy forces have captured the capital"
            )
        }

        return nil
    }

    private static func checkForeignInvasion(game: Game) -> GameOverCondition? {
        // Check for invasion defeat flag
        if game.flags.contains("invasion_defeat") {
            let invader = game.variables["invading_power"] ?? "foreign forces"
            return createGameOver(
                type: .foreignInvasion,
                game: game,
                cause: "Military defeat by \(invader)"
            )
        }

        // Check for multiple border regions under foreign control
        let borderRegions = game.regions.filter { $0.regionType == RegionType.border.rawValue }
        let lostBorders = borderRegions.filter { $0.status == .seceded }
        if lostBorders.count >= 2 && game.variables["foreign_occupation"] == "true" {
            return createGameOver(
                type: .foreignInvasion,
                game: game,
                cause: "Enemy occupation of critical territories"
            )
        }

        return nil
    }

    // MARK: - Party-Level Checks

    private static func checkMilitaryCoup(game: Game) -> GameOverCondition? {
        // Military coup triggered by combination of factors:
        // - Very low stability
        // - Military loyalty collapsed
        // - Strong military figures opposing player
        // Thresholds are configurable via BalanceConfig

        guard game.stability <= BalanceConfig.coupStabilityThreshold else { return nil }

        // Check military loyalty (from variables)
        let militaryLoyalty = Int(game.variables["military_loyalty"] ?? "50") ?? 50
        guard militaryLoyalty <= BalanceConfig.coupMilitaryLoyaltyThreshold else { return nil }

        // Check for coup flag
        if game.flags.contains("military_coup") {
            return createGameOver(
                type: .militaryCoup,
                game: game,
                cause: "The People's Army seized power"
            )
        }

        // Check for powerful Princeling (red aristocracy with military ties) characters aligned against player
        let hostileMilitary = game.characters.filter {
            $0.factionId == "princelings" &&
            $0.disposition < 30 &&
            $0.status == CharacterStatus.active.rawValue &&
            ($0.positionIndex ?? 0) >= 6
        }

        if hostileMilitary.count >= 2 {
            // Coup probability
            let coupRoll = Int.random(in: 1...100)
            let coupChance = (100 - game.stability) / 2 + (100 - militaryLoyalty) / 2
            if coupRoll <= coupChance {
                return createGameOver(
                    type: .militaryCoup,
                    game: game,
                    cause: "General \(hostileMilitary.first?.name ?? "Unknown") led a military takeover"
                )
            }
        }

        return nil
    }

    private static func checkCorruptionExposed(game: Game) -> GameOverCondition? {
        // Corruption exposure - triggered by investigations or rival action
        guard game.flags.contains("corruption_exposed") else { return nil }

        // High corruption + low protection = arrest
        let corruptionLevel = Int(game.variables["corruption_level"] ?? "0") ?? 0
        let protectionLevel = game.patronFavor + game.standing

        if corruptionLevel >= 70 && protectionLevel < 50 {
            if hasViableHeir(game: game) {
                return nil // Heir can escape
            }

            return createGameOver(
                type: .corruptionExposed,
                game: game,
                cause: "Corruption scandal led to arrest and trial"
            )
        }

        return nil
    }

    // MARK: - Individual Checks

    private static func checkRevolution(game: Game) -> GameOverCondition? {
        // Revolution triggers if stability AND popular support both collapse
        // Thresholds are configurable via BalanceConfig
        guard game.stability <= BalanceConfig.revolutionStabilityThreshold &&
              game.popularSupport <= BalanceConfig.revolutionPopularSupportThreshold else { return nil }

        // Revolution cannot be prevented by heir - it destroys the system
        return createGameOver(
            type: .revolutionOverthrow,
            game: game,
            cause: "Popular uprising and regime collapse"
        )
    }

    private static func checkAssassination(game: Game) -> GameOverCondition? {
        // Assassination check - high rival threat + low network (no protection)
        // Thresholds are configurable via BalanceConfig
        guard game.rivalThreat >= BalanceConfig.assassinationRivalThreat &&
              game.network <= BalanceConfig.assassinationNetworkThreshold else { return nil }

        // Check for heir
        if hasViableHeir(game: game) {
            // Heir takes over - don't end game, trigger succession
            return nil
        }

        return createGameOver(
            type: .assassinationNoHeir,
            game: game,
            cause: "Rival-orchestrated assassination"
        )
    }

    private static func checkDeath(game: Game) -> GameOverCondition? {
        // Natural death - checked via flag set by events (illness, accident, age)
        guard game.flags.contains("player_death_imminent") else { return nil }

        if hasViableHeir(game: game) {
            return nil
        }

        return createGameOver(
            type: .deathNoHeir,
            game: game,
            cause: game.variables["death_cause"] ?? "Natural causes"
        )
    }

    private static func checkPurge(game: Game) -> GameOverCondition? {
        // Purge - patron favor collapses + standing destroyed
        guard game.patronFavor <= 5 && game.standing <= 10 else { return nil }

        // Additional check - powerful enemies aligned against player
        guard game.coalitionStrength >= 80 else { return nil }

        if hasViableHeir(game: game) {
            return nil
        }

        return createGameOver(
            type: .purgedNoHeir,
            game: game,
            cause: "Political purge by rival faction"
        )
    }

    // MARK: - Helpers

    private static func hasViableHeir(game: Game) -> Bool {
        // Check if player has designated an heir who is still viable
        guard let heirId = game.variables["designated_heir_id"] else {
            return false
        }

        // Find heir in characters
        guard let heir = game.characters.first(where: { $0.id.uuidString == heirId }) else {
            return false
        }

        // Heir must be active (not purged, dead, etc.)
        guard heir.status == CharacterStatus.active.rawValue else {
            return false
        }

        // Heir must have reasonable standing to take over
        guard heir.disposition >= 50 else {
            return false
        }

        return true
    }

    private static func createGameOver(
        type: GameOverType,
        game: Game,
        cause: String
    ) -> GameOverCondition {
        // Get current position title
        let config = CampaignLoader.shared.getColdWarCampaign()
        let currentPosition = config.ladder.first(where: { $0.index == game.currentPositionIndex })
        let positionTitle = currentPosition?.title ?? "Unknown Position"

        // Find highest position achieved
        var highestIndex = game.currentPositionIndex
        var highestTitle = positionTitle
        for holder in game.positionHistory where holder.wasPlayer {
            if holder.positionIndex > highestIndex {
                highestIndex = holder.positionIndex
                if let pos = config.ladder.first(where: { $0.index == holder.positionIndex }) {
                    highestTitle = pos.title
                }
            }
        }

        // Calculate stats
        let stats = GameOverStats(
            turnsPlayed: game.turnNumber,
            highestPosition: highestTitle,
            highestPositionIndex: highestIndex,
            tracksExplored: [], // Would be populated from affinity data
            charactersInfluenced: game.characters.filter { $0.disposition >= 60 }.count,
            rivalsDefeated: game.characters.filter { $0.isRival && $0.status != CharacterStatus.active.rawValue }.count,
            patronsServed: game.characters.filter { $0.isPatron }.count,
            majorDecisions: game.events.filter { $0.eventType == EventType.decision.rawValue }.count,
            assassinationsSurvived: game.flags.filter { $0.hasPrefix("survived_assassination_") }.count,
            successfulSuccessions: game.flags.filter { $0.hasPrefix("succession_") }.count
        )

        // Get earned badges (would be populated from badge system)
        let earnedBadges: [String] = [] // To be populated when badge system is integrated

        return GameOverCondition(
            type: type,
            turnOccurred: game.turnNumber,
            cause: cause,
            finalPosition: positionTitle,
            dynastyLength: game.turnNumber,
            heirsLost: game.flags.filter { $0.hasPrefix("heir_lost_") }.count,
            badgesEarned: earnedBadges,
            stats: stats
        )
    }
}

// MARK: - Heir Designation

struct HeirDesignation: Codable, Identifiable {
    var id: String = UUID().uuidString
    var heirCharacterId: UUID
    var heirName: String
    var relationship: HeirRelationship
    var designatedTurn: Int
    var inheritanceBonus: Int            // Percentage of standing/network inherited

    var isViable: Bool = true            // Can be invalidated if heir is purged/killed
}

enum HeirRelationship: String, Codable, CaseIterable {
    case child           // Family member - highest inheritance
    case protege         // Political protege - good inheritance
    case ally            // Trusted ally - moderate inheritance
    case lieutenant      // Loyal subordinate - lower inheritance

    var inheritanceMultiplier: Double {
        switch self {
        case .child: return 0.75        // Inherits 75% of standing/network
        case .protege: return 0.60      // Inherits 60%
        case .ally: return 0.45         // Inherits 45%
        case .lieutenant: return 0.30   // Inherits 30%
        }
    }

    var displayName: String {
        switch self {
        case .child: return "Family Member"
        case .protege: return "Political Protege"
        case .ally: return "Trusted Ally"
        case .lieutenant: return "Loyal Lieutenant"
        }
    }

    var description: String {
        switch self {
        case .child:
            return "Blood ties ensure the strongest inheritance of your political capital"
        case .protege:
            return "Years of mentorship create a natural successor"
        case .ally:
            return "A proven ally can continue your work, though some connections will be lost"
        case .lieutenant:
            return "A loyal subordinate can pick up the mantle, but must rebuild much"
        }
    }
}
