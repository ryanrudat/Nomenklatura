//
//  BureauActivityLog.swift
//  Nomenklatura
//
//  Activity feed entries for bureau operations - tracks recent events, decisions, and outcomes.
//

import Foundation

// MARK: - Activity Entry Type

/// Types of activity entries that can appear in the bureau feed
enum ActivityEntryType: String, Codable, CaseIterable, Sendable {
    // Operation lifecycle
    case operationStarted
    case operationProgress
    case operationCompleted
    case operationFailed
    case operationCancelled

    // Player decisions
    case decisionMade
    case approvalGranted
    case approvalDenied
    case resourceAllocated

    // Consequences and outcomes
    case consequenceApplied
    case targetArrested
    case targetReleased
    case targetEliminated

    // Economic specific
    case quotaMet
    case quotaMissed
    case productionReport
    case resourceShortage

    // Party specific
    case campaignLaunched
    case campaignCompleted
    case personnelPromoted
    case personnelDemoted

    // General
    case alert
    case warning
    case intelligence
    case characterAction          // NPC did something relevant

    var displayName: String {
        switch self {
        case .operationStarted: return "Operation Started"
        case .operationProgress: return "Progress Update"
        case .operationCompleted: return "Operation Completed"
        case .operationFailed: return "Operation Failed"
        case .operationCancelled: return "Operation Cancelled"
        case .decisionMade: return "Decision Made"
        case .approvalGranted: return "Approval Granted"
        case .approvalDenied: return "Approval Denied"
        case .resourceAllocated: return "Resource Allocated"
        case .consequenceApplied: return "Consequence Applied"
        case .targetArrested: return "Arrest Made"
        case .targetReleased: return "Release Ordered"
        case .targetEliminated: return "Target Eliminated"
        case .quotaMet: return "Quota Met"
        case .quotaMissed: return "Quota Missed"
        case .productionReport: return "Production Report"
        case .resourceShortage: return "Resource Shortage"
        case .campaignLaunched: return "Campaign Launched"
        case .campaignCompleted: return "Campaign Completed"
        case .personnelPromoted: return "Personnel Promoted"
        case .personnelDemoted: return "Personnel Demoted"
        case .alert: return "Alert"
        case .warning: return "Warning"
        case .intelligence: return "Intelligence"
        case .characterAction: return "Character Action"
        }
    }

    var iconName: String {
        switch self {
        case .operationStarted: return "play.circle.fill"
        case .operationProgress: return "arrow.right.circle"
        case .operationCompleted: return "checkmark.circle.fill"
        case .operationFailed: return "xmark.circle.fill"
        case .operationCancelled: return "minus.circle"
        case .decisionMade: return "hand.point.right.fill"
        case .approvalGranted: return "checkmark.seal.fill"
        case .approvalDenied: return "xmark.seal.fill"
        case .resourceAllocated: return "shippingbox.fill"
        case .consequenceApplied: return "exclamationmark.triangle.fill"
        case .targetArrested: return "lock.fill"
        case .targetReleased: return "lock.open.fill"
        case .targetEliminated: return "xmark.square.fill"
        case .quotaMet: return "chart.line.uptrend.xyaxis"
        case .quotaMissed: return "chart.line.downtrend.xyaxis"
        case .productionReport: return "doc.text.fill"
        case .resourceShortage: return "exclamationmark.triangle"
        case .campaignLaunched: return "megaphone.fill"
        case .campaignCompleted: return "flag.checkered"
        case .personnelPromoted: return "arrow.up.circle.fill"
        case .personnelDemoted: return "arrow.down.circle.fill"
        case .alert: return "bell.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .intelligence: return "eye.fill"
        case .characterAction: return "person.fill"
        }
    }

    var isPositive: Bool? {
        switch self {
        case .operationCompleted, .approvalGranted, .quotaMet, .campaignCompleted, .personnelPromoted:
            return true
        case .operationFailed, .approvalDenied, .quotaMissed, .resourceShortage, .personnelDemoted:
            return false
        default:
            return nil  // Neutral
        }
    }
}

// MARK: - Bureau Activity Entry

/// A single entry in the bureau activity feed
struct BureauActivityEntry: Identifiable, Codable, Sendable {
    let id: UUID
    let bureauTrack: String                    // ExpandedCareerTrack.rawValue
    let turn: Int
    let timestamp: Date

    let entryType: ActivityEntryType
    let title: String
    let description: String
    let iconName: String

    // Related entities (optional)
    var relatedOperationId: UUID?
    var relatedCharacterName: String?
    var relatedDecisionId: String?
    var relatedRegionName: String?

    // Outcome effects (for displaying consequences)
    var statChanges: [String: Int]?            // e.g., ["stability": -5, "network": 3]
    var wasSuccess: Bool?

    // Importance for sorting/filtering
    var importance: Int                        // 1-10, higher = more significant

    // MARK: - Computed Properties

    var bureau: ExpandedCareerTrack? {
        ExpandedCareerTrack(rawValue: bureauTrack)
    }

    var isPositive: Bool? {
        wasSuccess ?? entryType.isPositive
    }

    var hasStatChanges: Bool {
        guard let changes = statChanges else { return false }
        return !changes.isEmpty
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        bureauTrack: String,
        turn: Int,
        timestamp: Date = Date(),
        entryType: ActivityEntryType,
        title: String,
        description: String,
        iconName: String? = nil,
        relatedOperationId: UUID? = nil,
        relatedCharacterName: String? = nil,
        relatedDecisionId: String? = nil,
        relatedRegionName: String? = nil,
        statChanges: [String: Int]? = nil,
        wasSuccess: Bool? = nil,
        importance: Int = 5
    ) {
        self.id = id
        self.bureauTrack = bureauTrack
        self.turn = turn
        self.timestamp = timestamp
        self.entryType = entryType
        self.title = title
        self.description = description
        self.iconName = iconName ?? entryType.iconName
        self.relatedOperationId = relatedOperationId
        self.relatedCharacterName = relatedCharacterName
        self.relatedDecisionId = relatedDecisionId
        self.relatedRegionName = relatedRegionName
        self.statChanges = statChanges
        self.wasSuccess = wasSuccess
        self.importance = importance
    }

    // MARK: - Factory Methods

    /// Create an entry for an operation starting
    static func operationStarted(
        bureauTrack: String,
        turn: Int,
        operationName: String,
        operationType: BureauOperationType,
        operationId: UUID
    ) -> BureauActivityEntry {
        BureauActivityEntry(
            bureauTrack: bureauTrack,
            turn: turn,
            entryType: .operationStarted,
            title: "\(operationType.displayName) Initiated",
            description: operationName,
            relatedOperationId: operationId,
            importance: 6
        )
    }

    /// Create an entry for an operation completing
    static func operationCompleted(
        bureauTrack: String,
        turn: Int,
        operationName: String,
        operationId: UUID,
        success: Bool,
        statChanges: [String: Int]? = nil
    ) -> BureauActivityEntry {
        BureauActivityEntry(
            bureauTrack: bureauTrack,
            turn: turn,
            entryType: success ? .operationCompleted : .operationFailed,
            title: success ? "Operation Successful" : "Operation Failed",
            description: operationName,
            relatedOperationId: operationId,
            statChanges: statChanges,
            wasSuccess: success,
            importance: 8
        )
    }

    /// Create an entry for a player decision
    static func decisionMade(
        bureauTrack: String,
        turn: Int,
        decisionTitle: String,
        decisionDescription: String,
        statChanges: [String: Int]? = nil
    ) -> BureauActivityEntry {
        BureauActivityEntry(
            bureauTrack: bureauTrack,
            turn: turn,
            entryType: .decisionMade,
            title: decisionTitle,
            description: decisionDescription,
            statChanges: statChanges,
            importance: 7
        )
    }

    /// Create an alert entry
    static func alert(
        bureauTrack: String,
        turn: Int,
        title: String,
        description: String
    ) -> BureauActivityEntry {
        BureauActivityEntry(
            bureauTrack: bureauTrack,
            turn: turn,
            entryType: .alert,
            title: title,
            description: description,
            importance: 9
        )
    }
}
