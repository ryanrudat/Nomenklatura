//
//  DiplomaticBriefing.swift
//  Nomenklatura
//
//  Position-gated diplomatic briefings following CCP-style information hierarchy.
//  Lower ranks receive sanitized summaries, higher ranks get raw intelligence.
//

import Foundation

// MARK: - Briefing Classification

/// Security classification level for briefing content
enum BriefingClassification: String, Codable, CaseIterable, Comparable {
    case publicNews = "PUBLIC"              // Position 1+ (everyone)
    case restricted = "RESTRICTED"          // Position 3+ (department heads)
    case confidential = "CONFIDENTIAL"      // Position 4+ (senior officials)
    case secret = "SECRET"                  // Position 5+ (deputy ministers)
    case topSecret = "TOP SECRET"           // Position 6+ (ministers)
    case presidential = "EYES ONLY"         // Position 7-8 (General Secretary)

    var minimumPositionIndex: Int {
        switch self {
        case .publicNews: return 1
        case .restricted: return 3
        case .confidential: return 4
        case .secret: return 5
        case .topSecret: return 6
        case .presidential: return 7
        }
    }

    var displayColor: String {
        switch self {
        case .publicNews: return "808080"      // Gray
        case .restricted: return "2E7D32"      // Green
        case .confidential: return "1976D2"    // Blue
        case .secret: return "F57C00"          // Orange
        case .topSecret: return "C62828"       // Red
        case .presidential: return "4A148C"    // Purple
        }
    }

    static func < (lhs: BriefingClassification, rhs: BriefingClassification) -> Bool {
        lhs.minimumPositionIndex < rhs.minimumPositionIndex
    }
}

// MARK: - Briefing Category

/// Type of diplomatic briefing content
enum BriefingCategory: String, Codable, CaseIterable {
    case bilateral          // Relations with specific country
    case treaty             // Treaty status/negotiations
    case intelligence       // Espionage operations
    case crisis             // International incidents
    case trade              // Economic relations
    case military           // Defense/military matters
    case summit             // High-level meetings
    case propaganda         // International image

    var displayName: String {
        switch self {
        case .bilateral: return "Bilateral Relations"
        case .treaty: return "Treaty Affairs"
        case .intelligence: return "Intelligence"
        case .crisis: return "Crisis Alert"
        case .trade: return "Trade & Economics"
        case .military: return "Military Affairs"
        case .summit: return "Summit Diplomacy"
        case .propaganda: return "International Image"
        }
    }

    var iconName: String {
        switch self {
        case .bilateral: return "person.2.fill"
        case .treaty: return "doc.text.fill"
        case .intelligence: return "eye.fill"
        case .crisis: return "exclamationmark.triangle.fill"
        case .trade: return "chart.bar.fill"
        case .military: return "shield.fill"
        case .summit: return "building.columns.fill"
        case .propaganda: return "megaphone.fill"
        }
    }
}

// MARK: - Briefing Item

/// A single briefing item with position-gated content
struct DiplomaticBriefingItem: Codable, Identifiable {
    let id: String
    let turnNumber: Int
    let category: BriefingCategory
    let classification: BriefingClassification

    /// Country this briefing relates to (if applicable)
    let countryId: String?

    /// Headline visible at minimum classification level
    let headline: String

    /// Summary for intermediate positions (Position 3-4)
    let summary: String?

    /// Full details for senior positions (Position 5-6)
    let fullDetails: String?

    /// Raw intelligence for top positions (Position 7-8)
    let rawIntelligence: String?

    /// Numeric data (relationship scores, etc.) only visible at appropriate level
    let sensitiveData: [String: Int]?

    /// Whether this requires immediate attention
    let isUrgent: Bool

    /// Source attribution (redacted at lower levels)
    let sourceAttribution: String?

    /// Recommendations (only visible to those who can act)
    let recommendedActions: [String]?

    init(
        turnNumber: Int,
        category: BriefingCategory,
        classification: BriefingClassification,
        countryId: String? = nil,
        headline: String,
        summary: String? = nil,
        fullDetails: String? = nil,
        rawIntelligence: String? = nil,
        sensitiveData: [String: Int]? = nil,
        isUrgent: Bool = false,
        sourceAttribution: String? = nil,
        recommendedActions: [String]? = nil
    ) {
        self.id = UUID().uuidString
        self.turnNumber = turnNumber
        self.category = category
        self.classification = classification
        self.countryId = countryId
        self.headline = headline
        self.summary = summary
        self.fullDetails = fullDetails
        self.rawIntelligence = rawIntelligence
        self.sensitiveData = sensitiveData
        self.isUrgent = isUrgent
        self.sourceAttribution = sourceAttribution
        self.recommendedActions = recommendedActions
    }

    // MARK: - Position-Gated Content Access

    /// Get the appropriate content for the given position level
    func content(forPositionIndex positionIndex: Int) -> BriefingContent {
        // Check if player has access at all
        guard positionIndex >= classification.minimumPositionIndex else {
            return BriefingContent(
                headline: "[CLASSIFIED - \(classification.rawValue)]",
                body: "You do not have clearance to access this briefing.",
                showsData: false,
                showsSource: false,
                showsRecommendations: false
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

        // Add raw intelligence for Position 6+
        if positionIndex >= 6, let rawIntelligence = rawIntelligence {
            body = rawIntelligence
            showsSource = sourceAttribution != nil
        }

        // Show recommendations for Position 4+ (those who can propose actions)
        if positionIndex >= 4 {
            showsRecommendations = recommendedActions != nil && !recommendedActions!.isEmpty
        }

        return BriefingContent(
            headline: headline,
            body: body,
            showsData: showsData,
            showsSource: showsSource,
            showsRecommendations: showsRecommendations
        )
    }
}

/// Position-appropriate briefing content
struct BriefingContent {
    let headline: String
    let body: String
    let showsData: Bool
    let showsSource: Bool
    let showsRecommendations: Bool
}

// MARK: - Daily Briefing

/// Collection of briefing items for a single turn
struct DailyDiplomaticBriefing: Codable, Identifiable {
    let id: String
    let turnNumber: Int
    let dateString: String              // "March 15, 1953"
    let items: [DiplomaticBriefingItem]

    /// Priority items that should be highlighted
    var urgentItems: [DiplomaticBriefingItem] {
        items.filter { $0.isUrgent }
    }

    /// Get items visible at the given position level
    func visibleItems(forPositionIndex positionIndex: Int) -> [DiplomaticBriefingItem] {
        items.filter { $0.classification.minimumPositionIndex <= positionIndex }
    }

    /// Get items by category
    func items(inCategory category: BriefingCategory) -> [DiplomaticBriefingItem] {
        items.filter { $0.category == category }
    }

    init(turnNumber: Int, dateString: String, items: [DiplomaticBriefingItem]) {
        self.id = UUID().uuidString
        self.turnNumber = turnNumber
        self.dateString = dateString
        self.items = items
    }
}

// MARK: - Briefing Summary Statistics

/// Summary of the diplomatic situation for dashboard display
struct DiplomaticSituationSummary: Codable {
    let turnNumber: Int

    // Aggregate metrics (shown based on position)
    let allyCount: Int
    let neutralCount: Int
    let hostileCount: Int
    let averageRelationship: Int
    let maxTension: Int
    let activeTreaties: Int
    let pendingCrises: Int

    // Risk assessment
    let overallRisk: DiplomaticRisk

    // Trend indicators
    let relationshipTrend: Trend       // Improving/declining
    let tensionTrend: Trend

    enum DiplomaticRisk: String, Codable {
        case low = "LOW"
        case moderate = "MODERATE"
        case elevated = "ELEVATED"
        case high = "HIGH"
        case critical = "CRITICAL"

        var displayColor: String {
            switch self {
            case .low: return "2E7D32"        // Green
            case .moderate: return "689F38"   // Light green
            case .elevated: return "FBC02D"   // Yellow
            case .high: return "F57C00"       // Orange
            case .critical: return "C62828"   // Red
            }
        }
    }

    enum Trend: String, Codable {
        case improving = "IMPROVING"
        case stable = "STABLE"
        case declining = "DECLINING"

        var iconName: String {
            switch self {
            case .improving: return "arrow.up.right"
            case .stable: return "arrow.right"
            case .declining: return "arrow.down.right"
            }
        }
    }
}
