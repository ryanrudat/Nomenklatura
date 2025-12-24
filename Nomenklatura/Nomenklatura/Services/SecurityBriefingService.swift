//
//  SecurityBriefingService.swift
//  Nomenklatura
//
//  Generates position-gated security briefings following CCP-style information hierarchy.
//  Integrates with CorruptionService, ShowTrialService, and IntelligenceLeakService.
//

import Foundation
import SwiftData

/// Service for generating and managing security briefings
class SecurityBriefingService {
    static let shared = SecurityBriefingService()

    private init() {}

    // MARK: - Daily Briefing Generation

    /// Generate the daily security briefing for a turn
    func generateDailyBriefing(for game: Game, modelContext: ModelContext) -> DailySecurityBriefing {
        var items: [SecurityBriefingItem] = []

        // Generate briefing items from various sources
        items.append(contentsOf: generateInvestigationBriefings(for: game))
        items.append(contentsOf: generateDetentionBriefings(for: game))
        items.append(contentsOf: generateFactionActivityBriefings(for: game))
        items.append(contentsOf: generateCorruptionBriefings(for: game))
        items.append(contentsOf: generateThreatAssessments(for: game))
        items.append(contentsOf: generateCounterIntelligenceBriefings(for: game))

        // Sort by urgency and classification
        items.sort { item1, item2 in
            if item1.isUrgent != item2.isUrgent {
                return item1.isUrgent
            }
            return item1.classification > item2.classification
        }

        // Generate date string based on turn number (game starts March 1953, each turn = ~2 weeks)
        let dateString = "Turn \(game.turnNumber)"

        return DailySecurityBriefing(
            turnNumber: game.turnNumber,
            dateString: dateString,
            items: items
        )
    }

    // MARK: - Investigation Briefings

    private func generateInvestigationBriefings(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Get active investigations from SecurityActionService
        let pendingActions = getPendingSecurityActions(for: game)

        for action in pendingActions where action.status == .inProgress {
            guard let targetId = action.targetCharacterId,
                  let target = game.characters.first(where: { $0.id.uuidString == targetId }) else {
                continue
            }

            let targetPosition = target.positionIndex ?? 0
            let classification = classificationForTargetPosition(targetPosition)

            items.append(SecurityBriefingItem(
                turnNumber: game.turnNumber,
                category: .corruptionWatch,
                classification: classification,
                relatedCharacterId: targetId,
                relatedCharacterName: target.name,
                headline: "Investigation ongoing: \(target.name)",
                summary: "Case File #\(action.id.uuidString.prefix(8)): Formal investigation of \(target.name) (Position \(targetPosition)) continues. Evidence gathering in progress.",
                fullDetails: "Investigation of \(target.name) initiated on Turn \(action.initiatedTurn). Current evidence level: \(action.successChance)%. Subject holding Position \(targetPosition) in \(target.positionTrack ?? "government"). Completion expected Turn \(action.completionTurn).",
                rawIntelligence: "CASE STATUS: Active investigation of \(target.name). Initiated by security services Turn \(action.initiatedTurn). Success probability: \(action.successChance)%. Target position: \(targetPosition). Factional affiliation: \(target.factionId ?? "unknown"). Recommended approach: standard CCDI procedures.",
                sensitiveData: ["evidence_level": action.successChance, "target_position": targetPosition],
                isUrgent: targetPosition >= 5,
                reliabilityRating: "B",
                recommendedActions: targetPosition < 4 ? ["Proceed with formal charges", "Request shuanggui authorization"] : ["Seek Standing Committee approval", "Prepare case documentation"]
            ))
        }

        return items
    }

    // MARK: - Detention Briefings

    private func generateDetentionBriefings(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Get active detentions
        let detentions = getActiveDetentions(for: game)

        for detention in detentions {
            let classification: SecurityClassification = detention.targetPosition >= 5 ? .topSecret : .confidential

            items.append(SecurityBriefingItem(
                turnNumber: game.turnNumber,
                category: .detentionStatus,
                classification: classification,
                relatedCharacterId: detention.targetCharacterId,
                relatedCharacterName: detention.targetName,
                headline: "Shuanggui: \(detention.targetName) - \(detention.phase.displayName)",
                summary: "\(detention.targetName) remains in shuanggui detention. Phase: \(detention.phase.displayName). \(detention.turnsInDetention) weeks in custody.",
                fullDetails: "Subject \(detention.targetName) detained at \(detention.location.displayName) since Turn \(detention.initiatedTurn). Current phase: \(detention.phase.displayName). Evidence accumulated: \(detention.evidenceAccumulated)%. Confession status: \(detention.confessionObtained ? "OBTAINED" : "NOT YET"). Suicide watch: ACTIVE. Lawyer access: DENIED.",
                rawIntelligence: "SHUANGGUI REPORT: \(detention.targetName) (Pos \(detention.targetPosition)) under double designation at \(detention.location.displayName). Initiated by \(detention.initiatedByName). Duration: \(detention.turnsInDetention) weeks. Guards: \(detention.accompanyingProtectors). Evidence: \(detention.evidenceAccumulated)%. Confession: \(detention.confessionObtained). Implicated others: \(detention.implicatedCharacterIds.count). Refer to trial: \(detention.referredToTrial ? "YES" : "PENDING").",
                sensitiveData: ["evidence": detention.evidenceAccumulated, "duration_weeks": detention.turnsInDetention * 2],
                isUrgent: detention.turnsInDetention >= 10,
                reliabilityRating: "A",
                recommendedActions: detention.confessionObtained ?
                    ["Refer to show trial", "Document implicated parties"] :
                    ["Continue interrogation", "Apply additional pressure"]
            ))
        }

        return items
    }

    // MARK: - Faction Activity Briefings

    private func generateFactionActivityBriefings(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Check for faction movements and scheming
        let factions = game.factions

        for faction in factions {
            // Look for suspicious faction activity
            let factionMembers = game.characters.filter { $0.factionId == faction.factionId && $0.isAlive }
            let seniorMembers = factionMembers.filter { ($0.positionIndex ?? 0) >= 4 }

            if seniorMembers.count >= 2 {
                let classification: SecurityClassification = seniorMembers.contains(where: { ($0.positionIndex ?? 0) >= 6 }) ? .secret : .restricted

                items.append(SecurityBriefingItem(
                    turnNumber: game.turnNumber,
                    category: .factionActivity,
                    classification: classification,
                    relatedFactionId: faction.factionId,
                    headline: "\(faction.name) faction activity detected",
                    summary: "Surveillance indicates coordination among \(faction.name) faction members. \(seniorMembers.count) senior officials identified.",
                    fullDetails: "\(faction.name) faction shows signs of organized activity. Key figures: \(seniorMembers.prefix(3).map { $0.name }.joined(separator: ", ")). Total membership in government: \(factionMembers.count). Monitoring continues.",
                    rawIntelligence: "FACTION INTELLIGENCE: \(faction.name) bloc analysis. Total members: \(factionMembers.count). Senior positions (4+): \(seniorMembers.count). Known leader: \(seniorMembers.first?.name ?? "Unknown"). Assessment: \(faction.power > 60 ? "HIGH POWER - potential threat to stability" : "Normal political activity").",
                    sensitiveData: ["member_count": factionMembers.count, "senior_count": seniorMembers.count],
                    isUrgent: faction.power > 70,
                    reliabilityRating: "B"
                ))
            }
        }

        return items
    }

    // MARK: - Corruption Briefings

    private func generateCorruptionBriefings(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Find characters with high corruption indicators
        let corruptOfficials = game.characters.filter { character in
            character.isAlive &&
            character.personality.corrupt > 60 &&
            (character.positionIndex ?? 0) >= 3
        }

        for official in corruptOfficials.prefix(3) {
            let position = official.positionIndex ?? 0
            let classification = classificationForTargetPosition(position)

            items.append(SecurityBriefingItem(
                turnNumber: game.turnNumber,
                category: .corruptionWatch,
                classification: classification,
                relatedCharacterId: official.id.uuidString,
                relatedCharacterName: official.name,
                headline: "Corruption indicators: \(official.name)",
                summary: "Discipline inspection has flagged \(official.name) for potential violations. Further investigation recommended.",
                fullDetails: "Subject: \(official.name), Position Level \(position). Corruption assessment: \(official.personality.corrupt)%. Loyalty rating: \(official.personality.loyal)%. Track: \(official.positionTrack ?? "unknown").",
                rawIntelligence: "CCDI WATCHLIST: \(official.name) (Pos \(position)) shows elevated corruption markers. Personality profile - Corrupt: \(official.personality.corrupt), Ambitious: \(official.personality.ambitious), Loyal: \(official.personality.loyal). Faction: \(official.factionId ?? "none"). Recommend: \(position >= 5 ? "Seek SC approval for investigation" : "Initiate preliminary review").",
                sensitiveData: ["corruption_level": official.personality.corrupt, "position": position],
                isUrgent: official.personality.corrupt > 80,
                reliabilityRating: "B",
                recommendedActions: ["Open preliminary investigation", "Conduct surveillance"]
            ))
        }

        return items
    }

    // MARK: - Threat Assessments

    private func generateThreatAssessments(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Overall stability assessment
        let stability = game.stability
        let eliteLoyalty = game.eliteLoyalty
        let popularSupport = game.popularSupport
        let internationalStanding = game.internationalStanding

        if stability < 50 {
            items.append(SecurityBriefingItem(
                turnNumber: game.turnNumber,
                category: .domesticThreats,
                classification: .confidential,
                headline: "Stability Alert: Elevated domestic tensions",
                summary: "Internal stability indicators show concerning trends. Enhanced vigilance recommended.",
                fullDetails: "Current stability index: \(stability). Elite loyalty: \(eliteLoyalty). Popular support: \(popularSupport). Assessment: \(stability < 30 ? "CRITICAL - immediate action required" : "CONCERNING - enhanced monitoring").",
                rawIntelligence: "DOMESTIC SITUATION ASSESSMENT: Stability \(stability)/100. Elite loyalty \(eliteLoyalty)/100. Popular support \(popularSupport)/100. International standing \(internationalStanding)/100. Risk matrix indicates \(stability < 30 ? "high probability of unrest" : "manageable situation with proper oversight").",
                isUrgent: stability < 30,
                reliabilityRating: "A",
                recommendedActions: stability < 30 ?
                    ["Increase security presence", "Preemptive detention of known agitators", "Media control measures"] :
                    ["Continue monitoring", "Report any unusual activity"]
            ))
        }

        return items
    }

    // MARK: - Counter-Intelligence Briefings

    private func generateCounterIntelligenceBriefings(for game: Game) -> [SecurityBriefingItem] {
        var items: [SecurityBriefingItem] = []

        // Check for characters with spy goals
        let potentialSpies = game.characters.filter { character in
            character.isAlive &&
            (character.goals ?? []).contains { goal in
                goal.goalType == .spyForForeignPower ||
                goal.goalType == .recruitAssets ||
                goal.goalType == .sabotageFromWithin
            }
        }

        for spy in potentialSpies.prefix(2) {
            items.append(SecurityBriefingItem(
                turnNumber: game.turnNumber,
                category: .counterIntelligence,
                classification: .topSecret,
                relatedCharacterId: spy.id.uuidString,
                relatedCharacterName: spy.name,
                headline: "Counter-Intel: Suspicious activity detected",
                summary: "MSS has identified unusual patterns in communications and behavior of certain officials.",
                fullDetails: "Counter-intelligence has flagged potential foreign intelligence activity within the apparatus. Details restricted to Director level.",
                rawIntelligence: "COUNTERINTEL ALERT: Subject \(spy.name) (Pos \(spy.positionIndex ?? 0)) displays patterns consistent with foreign asset. Track: \(spy.positionTrack ?? "unknown"). Faction: \(spy.factionId ?? "none"). Goals analysis indicates hostile intent. Recommend: Intensive surveillance, possible extraction for questioning.",
                isUrgent: true,
                reliabilityRating: "B",
                recommendedActions: ["Initiate intensive surveillance", "Document all contacts", "Prepare extraction plan"]
            ))
        }

        return items
    }

    // MARK: - Helper Methods

    private func classificationForTargetPosition(_ position: Int) -> SecurityClassification {
        switch position {
        case 0...2: return .restricted
        case 3...4: return .confidential
        case 5: return .secret
        case 6: return .topSecret
        default: return .directorsEyes
        }
    }

    /// Get pending security actions from storage
    private func getPendingSecurityActions(for game: Game) -> [SecurityActionRecord] {
        guard let data = game.variables["security_pending_actions"],
              let jsonData = data.data(using: .utf8),
              let actions = try? JSONDecoder().decode([SecurityActionRecord].self, from: jsonData) else {
            return []
        }
        return actions
    }

    /// Get active shuanggui detentions from storage
    private func getActiveDetentions(for game: Game) -> [ShuangguiDetention] {
        guard let data = game.variables["security_active_detentions"],
              let jsonData = data.data(using: .utf8),
              let detentions = try? JSONDecoder().decode([ShuangguiDetention].self, from: jsonData) else {
            return []
        }
        return detentions
    }

    // MARK: - Situation Summary

    /// Generate a security situation summary for the dashboard
    func generateSituationSummary(for game: Game) -> SecuritySituationSummary {
        let pendingActions = getPendingSecurityActions(for: game)
        let detentions = getActiveDetentions(for: game)

        // Count active operations
        let activeInvestigations = pendingActions.filter { $0.status == .inProgress }.count
        let activeDetentions = detentions.count
        let pendingTrials = detentions.filter { $0.referredToTrial }.count

        // Calculate threat levels based on game state
        let stability = game.stability
        let eliteLoyalty = game.eliteLoyalty
        let internationalStanding = game.internationalStanding

        let domesticThreat: SecuritySituationSummary.ThreatLevel = {
            if stability < 20 { return .critical }
            if stability < 40 { return .high }
            if stability < 60 { return .moderate }
            if stability < 80 { return .low }
            return .minimal
        }()

        let factionThreat: SecuritySituationSummary.ThreatLevel = {
            if eliteLoyalty < 30 { return .critical }
            if eliteLoyalty < 50 { return .elevated }
            if eliteLoyalty < 70 { return .moderate }
            return .low
        }()

        // Overall rating
        let overallRating: SecuritySituationSummary.SecurityRating = {
            if stability < 30 || eliteLoyalty < 30 { return .critical }
            if stability < 50 || eliteLoyalty < 50 { return .alert }
            if stability < 70 { return .concerned }
            if stability < 85 { return .watchful }
            return .stable
        }()

        return SecuritySituationSummary(
            turnNumber: game.turnNumber,
            activeInvestigations: activeInvestigations,
            activeDetentions: activeDetentions,
            pendingTrials: pendingTrials,
            recentExecutions: 0,
            foreignSpyThreat: internationalStanding < 50 ? .elevated : .low,
            domesticUnrestThreat: domesticThreat,
            factionIntrigueThreat: factionThreat,
            corruptionThreat: .moderate,
            overallSecurityRating: overallRating,
            trendDirection: .stable
        )
    }
}
