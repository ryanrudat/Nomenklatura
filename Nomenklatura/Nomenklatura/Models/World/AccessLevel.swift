//
//  AccessLevel.swift
//  Nomenklatura
//
//  Access control system for position-based feature gating
//

import Foundation

// MARK: - Feature Category

/// Categories of features for access control purposes
enum FeatureCategory: String, Codable, CaseIterable {
    case general        // Basic features available to all
    case diplomatic     // Embassy, foreign relations, treaties
    case economic       // Economic data, trade flows, budget
    case intelligence   // Classified info, espionage, covert ops
    case military       // Defense data, troop movements
    case administrative // Internal Party affairs, personnel

    var displayName: String {
        switch self {
        case .general: return "General"
        case .diplomatic: return "Diplomatic"
        case .economic: return "Economic"
        case .intelligence: return "Intelligence"
        case .military: return "Military"
        case .administrative: return "Administrative"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "doc.text.fill"
        case .diplomatic: return "globe"
        case .economic: return "chart.bar.fill"
        case .intelligence: return "eye.fill"
        case .military: return "shield.fill"
        case .administrative: return "building.columns.fill"
        }
    }
}

// MARK: - Access Level

/// Calculates effective access level based on position and career track
struct AccessLevel {
    let basePosition: Int
    let track: ExpandedCareerTrack
    let trackAffinities: TrackAffinityScores

    /// Initialize from a Game instance
    init(game: Game) {
        self.basePosition = game.currentPositionIndex
        self.track = game.currentCommittedTrack ?? .shared
        self.trackAffinities = game.trackAffinityScores
    }

    /// Initialize with explicit values
    init(basePosition: Int, track: ExpandedCareerTrack, trackAffinities: TrackAffinityScores = TrackAffinityScores()) {
        self.basePosition = basePosition
        self.track = track
        self.trackAffinities = trackAffinities
    }

    /// Calculate effective access level for a specific feature category
    /// Career track provides bonuses to relevant categories
    func effectiveLevel(for category: FeatureCategory) -> Int {
        var level = basePosition

        switch category {
        case .diplomatic:
            // Foreign Affairs track gets +2, Security gets +1 (intelligence overlap)
            if track == .foreignAffairs { level += 2 }
            else if track == .securityServices { level += 1 }

        case .economic:
            // Economic Planning gets +2, State Ministry gets +1 (budget overlap)
            if track == .economicPlanning { level += 2 }
            else if track == .stateMinistry { level += 1 }

        case .intelligence:
            // Security Services gets +2, Foreign Affairs gets +1 (foreign intel)
            if track == .securityServices { level += 2 }
            else if track == .foreignAffairs { level += 1 }

        case .military:
            // Military-Political gets +2, Security gets +1 (internal troops)
            if track == .militaryPolitical { level += 2 }
            else if track == .securityServices { level += 1 }

        case .administrative:
            // Party Apparatus gets +2, State Ministry gets +1
            if track == .partyApparatus { level += 2 }
            else if track == .stateMinistry { level += 1 }

        case .general:
            // No track bonuses for general features
            break
        }

        // Add small bonus from track affinity if high enough
        let relevantAffinity = affinityBonus(for: category)
        level += relevantAffinity

        // Cap at 8 (Politburo Standing Committee level)
        return min(level, 8)
    }

    /// Small bonus from track affinity (representing expertise even without commitment)
    private func affinityBonus(for category: FeatureCategory) -> Int {
        let relevantTrack: ExpandedCareerTrack?

        switch category {
        case .diplomatic: relevantTrack = .foreignAffairs
        case .economic: relevantTrack = .economicPlanning
        case .intelligence: relevantTrack = .securityServices
        case .military: relevantTrack = .militaryPolitical
        case .administrative: relevantTrack = .partyApparatus
        case .general: relevantTrack = nil
        }

        guard let track = relevantTrack else { return 0 }
        let affinity = trackAffinities.score(for: track)

        // High affinity (25+) gives +1 bonus
        if affinity >= 25 { return 1 }
        return 0
    }

    /// Check if player has access to a feature requiring a specific level
    func hasAccess(requiredLevel: Int, category: FeatureCategory = .general) -> Bool {
        effectiveLevel(for: category) >= requiredLevel
    }

    /// Whether player has Politburo-level access (sees everything)
    var isPolitburoLevel: Bool {
        basePosition >= 8
    }

    /// Description of current access level
    var accessDescription: String {
        switch basePosition {
        case 8: return "Politburo Standing Committee - Full Access"
        case 7: return "General Secretary - Full Access"
        case 6: return "Deputy General Secretary - High Clearance"
        case 5: return "Politburo Member - Senior Clearance"
        case 4: return "Candidate Politburo Member - Elevated Clearance"
        case 3: return "Central Committee Secretary - Standard Clearance"
        case 2: return "Department Head - Limited Clearance"
        case 1: return "Party Official - Basic Clearance"
        default: return "Entry Level - Minimal Clearance"
        }
    }
}

// MARK: - Access Requirement

/// Defines access requirements for a specific feature or piece of information
struct AccessRequirement {
    let minLevel: Int
    let category: FeatureCategory
    let showWhenLocked: Bool  // Whether to show locked state or hide completely
    let unlockMessage: String

    init(
        minLevel: Int,
        category: FeatureCategory = .general,
        showWhenLocked: Bool = true,
        unlockMessage: String? = nil
    ) {
        self.minLevel = minLevel
        self.category = category
        self.showWhenLocked = showWhenLocked
        self.unlockMessage = unlockMessage ?? "Requires Position Level \(minLevel)"
    }

    /// Check if access is granted for the given access level
    func isGranted(for accessLevel: AccessLevel) -> Bool {
        accessLevel.effectiveLevel(for: category) >= minLevel
    }

    /// Static factory methods for common requirements

    /// Basic info available to all
    static let publicInfo = AccessRequirement(minLevel: 0)

    /// Relationship scores (Position 4+)
    static let relationshipData = AccessRequirement(
        minLevel: 4,
        category: .diplomatic,
        unlockMessage: "Relationship data requires Candidate Politburo rank"
    )

    /// Treaty details (Position 4+)
    static let treatyDetails = AccessRequirement(
        minLevel: 4,
        category: .diplomatic,
        unlockMessage: "Treaty details require Candidate Politburo rank"
    )

    /// Intelligence reports (Position 6+)
    static let intelligenceReports = AccessRequirement(
        minLevel: 6,
        category: .intelligence,
        unlockMessage: "Intelligence reports require Deputy General Secretary rank"
    )

    /// Classified cables (Position 8 only)
    static let classifiedCables = AccessRequirement(
        minLevel: 8,
        category: .intelligence,
        showWhenLocked: false,  // Hidden until Politburo level
        unlockMessage: "Classified cables require Politburo Standing Committee membership"
    )

    /// Covert operations (Position 8 only)
    static let covertOperations = AccessRequirement(
        minLevel: 8,
        category: .intelligence,
        showWhenLocked: false,
        unlockMessage: "Covert operations require Politburo Standing Committee membership"
    )

    /// Economic breakdowns (Position 4+)
    static let economicDetails = AccessRequirement(
        minLevel: 4,
        category: .economic,
        unlockMessage: "Economic details require Candidate Politburo rank"
    )

    /// Economic trends (Position 2+)
    static let economicTrends = AccessRequirement(
        minLevel: 2,
        category: .economic,
        unlockMessage: "Economic trend data requires Department Head rank"
    )

    /// Regional economics (Position 6+)
    static let regionalEconomics = AccessRequirement(
        minLevel: 6,
        category: .economic,
        unlockMessage: "Regional economic data requires Deputy General Secretary rank"
    )

    /// Budget details (Position 6+)
    static let budgetDetails = AccessRequirement(
        minLevel: 6,
        category: .economic,
        unlockMessage: "Budget details require Deputy General Secretary rank"
    )

    /// Classified projections (Position 8 only)
    static let classifiedProjections = AccessRequirement(
        minLevel: 8,
        category: .economic,
        showWhenLocked: false,
        unlockMessage: "Classified projections require Politburo Standing Committee membership"
    )
}

// MARK: - Diplomatic Action Clearance

/// Determines what diplomatic actions player can take at their access level
struct DiplomaticActionClearance {
    let accessLevel: AccessLevel

    /// Full diplomatic actions (Position 8)
    var canTakeFullActions: Bool {
        accessLevel.effectiveLevel(for: .diplomatic) >= 8
    }

    /// Limited diplomatic actions (Position 6-7)
    var canTakeLimitedActions: Bool {
        let level = accessLevel.effectiveLevel(for: .diplomatic)
        return level >= 6 && level < 8
    }

    /// View-only diplomatic info (Position 4+)
    var canViewDiplomaticDetails: Bool {
        accessLevel.effectiveLevel(for: .diplomatic) >= 4
    }

    /// Available action types based on clearance
    var availableActionTypes: [DiplomaticActionType] {
        let level = accessLevel.effectiveLevel(for: .diplomatic)

        if level >= 8 {
            // Full access - all actions
            return DiplomaticActionType.allCases
        } else if level >= 6 {
            // Limited - non-covert actions only
            return DiplomaticActionType.allCases.filter { !$0.isCovert }
        } else {
            // No actions available
            return []
        }
    }
}

// MARK: - Position-Aware Authority Language

/// Generates position-appropriate language for documents and scenarios
struct AuthorityLanguage {
    let positionIndex: Int
    let track: ExpandedCareerTrack
    private let resolvedPositionTitle: String

    init(positionIndex: Int, track: ExpandedCareerTrack = .shared, positionTitle: String? = nil) {
        self.positionIndex = positionIndex
        self.track = track
        self.resolvedPositionTitle = positionTitle ?? Self.fallbackPositionTitle(for: positionIndex, track: track)
    }

    init(game: Game) {
        self.positionIndex = game.currentPositionIndex
        self.track = game.effectiveOfficeTrack
        self.resolvedPositionTitle = game.currentPositionName
    }

    // MARK: - Authority Thresholds

    /// Can make unilateral decisions on routine matters
    var hasRoutineAuthority: Bool { positionIndex >= 2 }

    /// Can make decisions affecting personnel
    var hasPersonnelAuthority: Bool {
        positionIndex >= 7 || (
            positionIndex >= 3 &&
            [.partyApparatus, .stateMinistry, .regional, .militaryPolitical, .economicPlanning].contains(track)
        )
    }

    /// Can authorize arrests (with oversight)
    var hasArrestAuthority: Bool { positionIndex >= 8 || (track == .securityServices && positionIndex >= 4) }

    /// Can make unilateral arrest decisions
    var hasUnilateralArrestAuthority: Bool { positionIndex >= 8 || (track == .securityServices && positionIndex >= 6) }

    /// Can allocate strategic resources
    var hasStrategicResourceAuthority: Bool {
        positionIndex >= 8 || ([.economicPlanning, .stateMinistry, .regional].contains(track) && positionIndex >= 4)
    }

    /// Can direct intelligence operations
    var hasIntelligenceAuthority: Bool { positionIndex >= 8 || (track == .securityServices && positionIndex >= 5) }

    /// Is part of the senior leadership tier beneath the General Secretary
    var isPolitburoMember: Bool { positionIndex >= 6 }

    /// Is General Secretary or Deputy
    var isTopLeadership: Bool { positionIndex >= 7 }

    // MARK: - Decision Language

    /// Returns appropriate verb for making a decision
    /// Position 7+: "You authorize" / Position 5-6: "You approve" / Lower: "You recommend"
    var decisionVerb: String {
        switch positionIndex {
        case 7...8: return "authorize"
        case 5...6: return "approve"
        case 3...4: return "endorse"
        default: return "recommend"
        }
    }

    /// Past tense decision verb
    var decisionVerbPast: String {
        switch positionIndex {
        case 7...8: return "authorized"
        case 5...6: return "approved"
        case 3...4: return "endorsed"
        default: return "recommended"
        }
    }

    /// Returns appropriate phrasing for authorization
    /// "You authorize..." vs "You recommend for approval..."
    func authorizationPhrase(action: String) -> String {
        switch positionIndex {
        case 7...8:
            return "You \(decisionVerb) \(action)."
        case 5...6:
            return "You \(decisionVerb) \(action), pending General Secretary review."
        case 3...4:
            return "You \(decisionVerb) \(action) to the Politburo."
        default:
            return "You \(decisionVerb) \(action) to your superiors."
        }
    }

    // MARK: - Approval Chain Context

    /// Returns the approval chain for the player's position
    var approvalChain: String {
        switch positionIndex {
        case 8: return "Your decision is final."
        case 7: return "Subject to Politburo Standing Committee review if challenged."
        case 6: return "Requires General Secretary approval for implementation."
        case 5: return "Requires Politburo vote for final authorization."
        case 4: return "Must be forwarded to full Politburo for consideration."
        case 3: return "Requires Central Committee Secretary endorsement."
        case 2: return "Must be approved by your department superior."
        default: return "Requires approval from Party officials above you."
        }
    }

    /// Returns who the player reports to
    var reportsTo: String {
        switch positionIndex {
        case 8: return "the Politburo Standing Committee"
        case 7: return "the General Secretary"
        case 6: return "the Deputy General Secretary"
        case 5: return "the Politburo"
        case 4: return "senior Politburo members"
        case 3: return "the Central Committee"
        case 2: return "your department head"
        default: return "your superiors"
        }
    }

    // MARK: - Document Signature Lines

    /// Appropriate signature line based on authority
    func signatureLine(for documentType: String) -> String {
        switch positionIndex {
        case 7...8:
            return "AUTHORIZED BY: ________________________________"
        case 5...6:
            return "APPROVED BY: ________________________________\n(Pending final authorization)"
        case 3...4:
            return "ENDORSED BY: ________________________________\n(Forwarded to \(reportsTo))"
        default:
            return "REVIEWED BY: ________________________________\n(Recommendation attached)"
        }
    }

    // MARK: - Arrest-Specific Language

    /// Language for arrest authorization documents
    var arrestAuthorizationLanguage: (header: String, action: String, footer: String) {
        switch positionIndex {
        case 8:
            return (
                header: "ARREST AUTHORIZATION",
                action: "Your signature authorizes immediate detention.",
                footer: "BY ORDER OF THE GENERAL SECRETARY"
            )
        case 7:
            return (
                header: "ARREST AUTHORIZATION REVIEW",
                action: "Your approval forwards this for immediate General Secretary confirmation.",
                footer: "LEADERSHIP REVIEW PENDING"
            )
        case 5...6:
            return (
                header: "ARREST RECOMMENDATION",
                action: "Your approval forwards this to senior leadership for authorization.",
                footer: "PENDING FINAL AUTHORIZATION"
            )
        case 4:
            return (
                header: "DETENTION REQUEST REVIEW",
                action: "Your endorsement adds your recommendation to the file.",
                footer: "FORWARDED TO SENIOR LEADERSHIP FOR REVIEW"
            )
        default:
            return (
                header: "SECURITY CONCERN REPORT",
                action: "Your review notes have been recorded.",
                footer: "FORWARDED TO SECURITY SERVICES"
            )
        }
    }

    // MARK: - Resource Allocation Language

    /// Language for resource allocation documents
    func resourceAllocationLanguage(resource: String, amount: String) -> (header: String, action: String) {
        switch positionIndex {
        case 8:
            return (
                header: "RESOURCE ALLOCATION DIRECTIVE",
                action: "You direct the distribution of \(amount) of \(resource)."
            )
        case 7:
            return (
                header: "RESOURCE ALLOCATION REVIEW",
                action: "You set the leadership recommendation for distributing \(amount) of \(resource)."
            )
        case 5...6:
            return (
                header: "RESOURCE ALLOCATION PROPOSAL",
                action: "You propose the distribution of \(amount) of \(resource), subject to senior leadership approval."
            )
        case 3...4:
            return (
                header: "RESOURCE ALLOCATION REQUEST",
                action: "You recommend how \(amount) of \(resource) should be distributed. Leadership will decide."
            )
        default:
            return (
                header: "RESOURCE REQUIREMENT REPORT",
                action: "You report on your department's need for \(resource). Allocation decisions are made above your level."
            )
        }
    }

    // MARK: - Intelligence Language

    /// Language for intelligence documents
    var intelligenceDocumentLanguage: (header: String, context: String) {
        switch positionIndex {
        case 8:
            return (
                header: "TOP SECRET - EYES ONLY",
                context: "As General Secretary, you directly oversee intelligence operations."
            )
        case 7:
            return (
                header: "TOP SECRET - LEADERSHIP CIRCULATION",
                context: "You receive this briefing as Deputy General Secretary. Your direction carries exceptional weight, but final authority remains with the General Secretary."
            )
        case 6 where track == .securityServices:
            return (
                header: "SECRET - DIRECTORATE EYES ONLY",
                context: "You oversee state protection directly. Operational details are provided in full."
            )
        case 5 where track == .securityServices:
            return (
                header: "SECRET - DIRECTORATE CIRCULATION",
                context: "You receive this briefing as a senior security leader. You may shape the response, but major escalations require higher approval."
            )
        case 5...6:
            return (
                header: "SECRET - LIMITED DISTRIBUTION",
                context: "You receive this as a senior bureau chief. You may advise but not directly command intelligence operations outside your portfolio."
            )
        case 4:
            return (
                header: "CONFIDENTIAL - NEED TO KNOW",
                context: "You receive a summary briefing. Full operational details are above your clearance."
            )
        default:
            return (
                header: "RESTRICTED",
                context: "You receive only information relevant to your departmental duties."
            )
        }
    }

    // MARK: - Position Title Context

    /// Returns appropriate framing for the player's position
    var positionFraming: String {
        "As \(resolvedPositionTitle)"
    }

    /// Short version for document headers
    var positionTitle: String {
        resolvedPositionTitle
    }

    private static func fallbackPositionTitle(for positionIndex: Int, track: ExpandedCareerTrack) -> String {
        switch (track, positionIndex) {
        case (.partyApparatus, 2): return "Instructor of the Central Committee"
        case (.partyApparatus, 3): return "Deputy Head of Central Committee Department"
        case (.partyApparatus, 4): return "Head of Central Committee Department"
        case (.partyApparatus, 5): return "Secretary of the Central Committee"
        case (.partyApparatus, 6): return "Second Secretary of the Central Committee"
        case (.stateMinistry, 2): return "Deputy Minister"
        case (.stateMinistry, 3): return "First Deputy Minister"
        case (.stateMinistry, 4): return "Minister"
        case (.stateMinistry, 5): return "Deputy Chairman of the Council of Ministers"
        case (.stateMinistry, 6): return "First Deputy Chairman of the Council of Ministers"
        case (.securityServices, 2): return "Senior Investigator"
        case (.securityServices, 3): return "Deputy Directorate Chief"
        case (.securityServices, 4): return "Directorate Chief"
        case (.securityServices, 5): return "First Deputy Director of State Protection"
        case (.securityServices, 6): return "Director of State Protection"
        case (.foreignAffairs, 2): return "Embassy Counselor"
        case (.foreignAffairs, 3): return "Ambassador"
        case (.foreignAffairs, 4): return "Deputy Minister of Foreign Affairs"
        case (.foreignAffairs, 5): return "First Deputy Minister of Foreign Affairs"
        case (.foreignAffairs, 6): return "Minister of Foreign Affairs"
        case (.economicPlanning, 2): return "Senior Economist"
        case (.economicPlanning, 3): return "Department Head of Planning Commission"
        case (.economicPlanning, 4): return "Deputy Chairman of the State Planning Commission"
        case (.economicPlanning, 5): return "First Deputy Chairman of Planning Commission"
        case (.economicPlanning, 6): return "Chairman of the State Planning Commission"
        case (.militaryPolitical, 2): return "Regimental Political Officer"
        case (.militaryPolitical, 3): return "Divisional Political Commissar"
        case (.militaryPolitical, 4): return "Deputy Head of Main Political Directorate"
        case (.militaryPolitical, 5): return "First Deputy Head of Main Political Directorate"
        case (.militaryPolitical, 6): return "Head of the Main Political Directorate"
        case (.regional, 2): return "Provincial Party Secretary"
        case (.regional, 3): return "Provincial First Secretary"
        case (.regional, 4): return "Republic First Secretary"
        case (_, 8): return "General Secretary"
        case (_, 7): return "Deputy General Secretary"
        case (_, 1): return "Junior Party Official"
        default: return "Party Official"
        }
    }
}
