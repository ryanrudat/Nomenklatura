//
//  SecurityBriefing.swift
//  Nomenklatura
//
//  Position-gated security intelligence briefings following CCP-style information hierarchy.
//  Lower ranks receive sanitized summaries, higher ranks get raw intelligence and source identities.
//
//  Based on CCDI (Central Commission for Discipline Inspection) internal reporting structure.
//

import Foundation

// MARK: - Security Classification

/// Security classification level for briefing content (CCP-style hierarchy)
enum SecurityClassification: String, Codable, CaseIterable, Comparable {
    case routine = "ROUTINE"                    // Position 1+ (all security personnel)
    case restricted = "RESTRICTED"              // Position 3+ (case officers)
    case confidential = "CONFIDENTIAL"          // Position 4+ (directorate)
    case secret = "SECRET"                      // Position 5+ (command level)
    case topSecret = "TOP SECRET"               // Position 6+ (senior command)
    case directorsEyes = "DIRECTOR'S EYES"      // Position 7+ (BPS Director only)

    var minimumPositionIndex: Int {
        switch self {
        case .routine: return 1
        case .restricted: return 3
        case .confidential: return 4
        case .secret: return 5
        case .topSecret: return 6
        case .directorsEyes: return 7
        }
    }

    var displayColor: String {
        switch self {
        case .routine: return "808080"          // Gray
        case .restricted: return "2E7D32"       // Green
        case .confidential: return "1976D2"     // Blue
        case .secret: return "F57C00"           // Orange
        case .topSecret: return "C62828"        // Red
        case .directorsEyes: return "4A148C"    // Purple
        }
    }

    static func < (lhs: SecurityClassification, rhs: SecurityClassification) -> Bool {
        lhs.minimumPositionIndex < rhs.minimumPositionIndex
    }
}

// MARK: - Briefing Category

/// Type of security briefing content (CCDI/MSS domains)
enum SecurityBriefingCategory: String, Codable, CaseIterable {
    case counterIntelligence    // Foreign spy activity (MSS domain)
    case domesticThreats        // Internal enemies, dissidents
    case factionActivity        // Faction scheming, power plays
    case corruptionWatch        // Economic crimes (CCDI primary mission)
    case disciplineViolation    // Party rule violations
    case patronNetworks         // Guanxi mapping, connection analysis
    case personalSecurity       // Threats to player or senior officials
    case detentionStatus        // Shuanggui progress reports
    case trialPreparation       // Show trial developments
    case massMovement           // Popular unrest, protests

    var displayName: String {
        switch self {
        case .counterIntelligence: return "Counter-Intelligence"
        case .domesticThreats: return "Domestic Threats"
        case .factionActivity: return "Faction Activity"
        case .corruptionWatch: return "Corruption Watch"
        case .disciplineViolation: return "Discipline Violations"
        case .patronNetworks: return "Patron Networks"
        case .personalSecurity: return "Personal Security"
        case .detentionStatus: return "Detention Status"
        case .trialPreparation: return "Trial Preparation"
        case .massMovement: return "Mass Movement"
        }
    }

    var iconName: String {
        switch self {
        case .counterIntelligence: return "eye.trianglebadge.exclamationmark.fill"
        case .domesticThreats: return "exclamationmark.shield.fill"
        case .factionActivity: return "person.3.fill"
        case .corruptionWatch: return "banknote.fill"
        case .disciplineViolation: return "book.closed.fill"
        case .patronNetworks: return "network"
        case .personalSecurity: return "person.badge.shield.checkmark.fill"
        case .detentionStatus: return "lock.fill"
        case .trialPreparation: return "building.columns.fill"
        case .massMovement: return "megaphone.fill"
        }
    }

    /// Whether this category relates to CCDI (internal discipline) vs MSS (external threats)
    var isCCDIDomain: Bool {
        switch self {
        case .corruptionWatch, .disciplineViolation, .factionActivity,
             .patronNetworks, .detentionStatus, .trialPreparation:
            return true
        case .counterIntelligence, .domesticThreats, .personalSecurity, .massMovement:
            return false
        }
    }
}

// MARK: - Security Briefing Item

/// A single security briefing item with position-gated content
struct SecurityBriefingItem: Codable, Identifiable {
    let id: String
    let turnNumber: Int
    let category: SecurityBriefingCategory
    let classification: SecurityClassification

    /// Character this briefing relates to (if applicable)
    let relatedCharacterId: String?
    let relatedCharacterName: String?

    /// Faction this briefing relates to (if applicable)
    let relatedFactionId: String?

    /// Headline visible at minimum classification level
    let headline: String

    /// Summary for intermediate positions (Position 3-4)
    let summary: String?

    /// Full details for senior positions (Position 5-6)
    let fullDetails: String?

    /// Raw intelligence for top positions (Position 7+)
    let rawIntelligence: String?

    /// Numeric data (evidence level, threat assessment, etc.) - sensitive
    let sensitiveData: [String: Int]?

    /// Source identity (extremely sensitive - Position 7+ only)
    let sourceIdentity: String?

    /// Whether this requires immediate attention
    let isUrgent: Bool

    /// Reliability rating (A = most reliable, F = unverified)
    let reliabilityRating: String?

    /// Recommended actions (only visible to those who can act)
    let recommendedActions: [String]?

    init(
        turnNumber: Int,
        category: SecurityBriefingCategory,
        classification: SecurityClassification,
        relatedCharacterId: String? = nil,
        relatedCharacterName: String? = nil,
        relatedFactionId: String? = nil,
        headline: String,
        summary: String? = nil,
        fullDetails: String? = nil,
        rawIntelligence: String? = nil,
        sensitiveData: [String: Int]? = nil,
        sourceIdentity: String? = nil,
        isUrgent: Bool = false,
        reliabilityRating: String? = nil,
        recommendedActions: [String]? = nil
    ) {
        self.id = UUID().uuidString
        self.turnNumber = turnNumber
        self.category = category
        self.classification = classification
        self.relatedCharacterId = relatedCharacterId
        self.relatedCharacterName = relatedCharacterName
        self.relatedFactionId = relatedFactionId
        self.headline = headline
        self.summary = summary
        self.fullDetails = fullDetails
        self.rawIntelligence = rawIntelligence
        self.sensitiveData = sensitiveData
        self.sourceIdentity = sourceIdentity
        self.isUrgent = isUrgent
        self.reliabilityRating = reliabilityRating
        self.recommendedActions = recommendedActions
    }

    // MARK: - Position-Gated Content Access

    /// Get the appropriate content for the given position level
    func content(forPositionIndex positionIndex: Int) -> SecurityBriefingContent {
        // Check if player has access at all
        guard positionIndex >= classification.minimumPositionIndex else {
            return SecurityBriefingContent(
                headline: "[CLASSIFIED - \(classification.rawValue)]",
                body: "You do not have clearance to access this briefing.",
                showsData: false,
                showsSource: false,
                showsRecommendations: false,
                reliabilityRating: nil
            )
        }

        var body = headline
        var showsData = false
        var showsSource = false
        var showsRecommendations = false

        // Add summary for Position 3+
        if positionIndex >= 3, let summary = summary {
            body = summary
        }

        // Add full details for Position 5+
        if positionIndex >= 5, let fullDetails = fullDetails {
            body = fullDetails
            showsData = sensitiveData != nil
        }

        // Add raw intelligence for Position 7+
        if positionIndex >= 7, let rawIntelligence = rawIntelligence {
            body = rawIntelligence
            showsSource = sourceIdentity != nil
        }

        // Show recommendations for Position 4+ (those who can propose actions)
        if positionIndex >= 4 {
            showsRecommendations = recommendedActions != nil && !recommendedActions!.isEmpty
        }

        return SecurityBriefingContent(
            headline: headline,
            body: body,
            showsData: showsData,
            showsSource: showsSource,
            showsRecommendations: showsRecommendations,
            reliabilityRating: positionIndex >= 4 ? reliabilityRating : nil
        )
    }
}

/// Position-appropriate security briefing content
struct SecurityBriefingContent {
    let headline: String
    let body: String
    let showsData: Bool
    let showsSource: Bool
    let showsRecommendations: Bool
    let reliabilityRating: String?
}

// MARK: - Daily Security Briefing

/// Collection of security briefing items for a single turn
struct DailySecurityBriefing: Codable, Identifiable {
    let id: String
    let turnNumber: Int
    let dateString: String              // "March 15, 1953"
    let items: [SecurityBriefingItem]

    /// Priority items that should be highlighted
    var urgentItems: [SecurityBriefingItem] {
        items.filter { $0.isUrgent }
    }

    /// Get items visible at the given position level
    func visibleItems(forPositionIndex positionIndex: Int) -> [SecurityBriefingItem] {
        items.filter { $0.classification.minimumPositionIndex <= positionIndex }
    }

    /// Get items by category
    func items(inCategory category: SecurityBriefingCategory) -> [SecurityBriefingItem] {
        items.filter { $0.category == category }
    }

    /// CCDI-domain items only (internal party discipline)
    func ccdiItems(forPositionIndex positionIndex: Int) -> [SecurityBriefingItem] {
        visibleItems(forPositionIndex: positionIndex).filter { $0.category.isCCDIDomain }
    }

    /// MSS-domain items only (external threats)
    func mssItems(forPositionIndex positionIndex: Int) -> [SecurityBriefingItem] {
        visibleItems(forPositionIndex: positionIndex).filter { !$0.category.isCCDIDomain }
    }

    init(turnNumber: Int, dateString: String, items: [SecurityBriefingItem]) {
        self.id = UUID().uuidString
        self.turnNumber = turnNumber
        self.dateString = dateString
        self.items = items
    }
}

// MARK: - Security Situation Summary

/// Summary of the security situation for dashboard display
struct SecuritySituationSummary: Codable {
    let turnNumber: Int

    // Active operations (position-gated visibility)
    let activeInvestigations: Int
    let activeDetentions: Int
    let pendingTrials: Int
    let recentExecutions: Int

    // Threat assessment
    let foreignSpyThreat: ThreatLevel
    let domesticUnrestThreat: ThreatLevel
    let factionIntrigueThreat: ThreatLevel
    let corruptionThreat: ThreatLevel

    // Overall assessment
    let overallSecurityRating: SecurityRating
    let trendDirection: Trend

    enum ThreatLevel: String, Codable {
        case minimal = "MINIMAL"
        case low = "LOW"
        case moderate = "MODERATE"
        case elevated = "ELEVATED"
        case high = "HIGH"
        case critical = "CRITICAL"

        var displayColor: String {
            switch self {
            case .minimal: return "2E7D32"      // Green
            case .low: return "689F38"          // Light green
            case .moderate: return "FBC02D"     // Yellow
            case .elevated: return "FF9800"     // Orange
            case .high: return "F57C00"         // Dark orange
            case .critical: return "C62828"     // Red
            }
        }
    }

    enum SecurityRating: String, Codable {
        case stable = "STABLE"
        case watchful = "WATCHFUL"
        case concerned = "CONCERNED"
        case alert = "ALERT"
        case critical = "CRITICAL"

        var displayColor: String {
            switch self {
            case .stable: return "2E7D32"
            case .watchful: return "689F38"
            case .concerned: return "FBC02D"
            case .alert: return "F57C00"
            case .critical: return "C62828"
            }
        }
    }

    enum Trend: String, Codable {
        case improving = "IMPROVING"
        case stable = "STABLE"
        case deteriorating = "DETERIORATING"

        var iconName: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .deteriorating: return "arrow.down.right"
            }
        }
    }
}

// MARK: - Investigation Status (for briefings)

/// Status of an active investigation for briefing purposes
struct InvestigationBriefingStatus: Codable, Identifiable {
    let id: String
    let targetName: String
    let targetPosition: Int
    let caseOfficer: String
    let phase: InvestigationPhase
    let evidenceLevel: Int          // 0-100
    let turnsActive: Int
    let projectedOutcome: String?   // Senior positions only

    enum InvestigationPhase: String, Codable {
        case preliminary
        case formal
        case detention
        case prosecution
        case concluded

        var displayName: String {
            switch self {
            case .preliminary: return "Preliminary Review"
            case .formal: return "Formal Investigation"
            case .detention: return "Shuanggui Detention"
            case .prosecution: return "Prosecution Pending"
            case .concluded: return "Case Concluded"
            }
        }
    }
}
