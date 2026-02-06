//
//  BureauOperation.swift
//  Nomenklatura
//
//  Unified model for tracking active bureau operations across all three core bureaus.
//

import Foundation

// MARK: - Operation Type

/// Types of operations available across the three core bureaus
enum BureauOperationType: String, Codable, CaseIterable, Sendable {
    // Security Services (BPS)
    case investigation          // Active case investigation
    case surveillance           // Ongoing surveillance operation
    case detention              // Person currently detained
    case interrogation          // Active interrogation
    case purge                  // Purge campaign in progress

    // Economic Planning (Gosplan)
    case productionQuota        // Active production target
    case resourceAllocation     // Resource distribution in progress
    case industrialProject      // Factory/infrastructure project
    case fiveYearPlanTarget     // Long-term planning objective
    case inspectionCampaign     // Quality/compliance inspection

    // Party Apparatus (CC)
    case ideologicalCampaign    // Political education campaign
    case personnelReview        // Cadre evaluation in progress
    case rectificationMovement  // Mass political movement
    case partyEducation         // Training/indoctrination program
    case factionManeuver        // Political maneuvering operation

    var displayName: String {
        switch self {
        // Security
        case .investigation: return "Investigation"
        case .surveillance: return "Surveillance"
        case .detention: return "Detention"
        case .interrogation: return "Interrogation"
        case .purge: return "Purge Campaign"
        // Economic
        case .productionQuota: return "Production Quota"
        case .resourceAllocation: return "Resource Allocation"
        case .industrialProject: return "Industrial Project"
        case .fiveYearPlanTarget: return "Five-Year Plan Target"
        case .inspectionCampaign: return "Inspection Campaign"
        // Party
        case .ideologicalCampaign: return "Ideological Campaign"
        case .personnelReview: return "Personnel Review"
        case .rectificationMovement: return "Rectification Movement"
        case .partyEducation: return "Party Education"
        case .factionManeuver: return "Political Maneuver"
        }
    }

    var iconName: String {
        switch self {
        // Security
        case .investigation: return "magnifyingglass"
        case .surveillance: return "eye.fill"
        case .detention: return "lock.fill"
        case .interrogation: return "person.fill.questionmark"
        case .purge: return "flame.fill"
        // Economic
        case .productionQuota: return "chart.bar.fill"
        case .resourceAllocation: return "shippingbox.fill"
        case .industrialProject: return "building.2.fill"
        case .fiveYearPlanTarget: return "calendar"
        case .inspectionCampaign: return "checklist"
        // Party
        case .ideologicalCampaign: return "megaphone.fill"
        case .personnelReview: return "person.text.rectangle"
        case .rectificationMovement: return "arrow.triangle.2.circlepath"
        case .partyEducation: return "book.fill"
        case .factionManeuver: return "person.3.fill"
        }
    }

    var associatedBureau: ExpandedCareerTrack {
        switch self {
        case .investigation, .surveillance, .detention, .interrogation, .purge:
            return .securityServices
        case .productionQuota, .resourceAllocation, .industrialProject, .fiveYearPlanTarget, .inspectionCampaign:
            return .economicPlanning
        case .ideologicalCampaign, .personnelReview, .rectificationMovement, .partyEducation, .factionManeuver:
            return .partyApparatus
        }
    }
}

// MARK: - Operation Status

enum OperationStatus: String, Codable, CaseIterable, Sendable {
    case pending            // Awaiting start
    case inProgress         // Currently active
    case awaitingApproval   // Needs player decision
    case awaitingResources  // Blocked on resources
    case completed          // Successfully finished
    case failed             // Did not succeed
    case cancelled          // Manually stopped

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .awaitingApproval: return "Awaiting Approval"
        case .awaitingResources: return "Awaiting Resources"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var isActive: Bool {
        switch self {
        case .pending, .inProgress, .awaitingApproval, .awaitingResources:
            return true
        case .completed, .failed, .cancelled:
            return false
        }
    }

    var iconName: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "circle.fill"
        case .awaitingApproval: return "questionmark.circle"
        case .awaitingResources: return "exclamationmark.triangle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle"
        }
    }
}

// MARK: - Risk Level

enum BureauRiskLevel: String, Codable, CaseIterable, Sendable {
    case minimal
    case low
    case moderate
    case high
    case critical

    var displayName: String {
        rawValue.capitalized
    }

    var colorHex: String {
        switch self {
        case .minimal: return "4A7C59"    // Green
        case .low: return "6B8E23"        // Olive green
        case .moderate: return "DAA520"   // Goldenrod
        case .high: return "CD853F"       // Peru/orange
        case .critical: return "8B0000"   // Dark red
        }
    }
}

// MARK: - Bureau Operation

/// Unified model for tracking an active bureau operation
struct BureauOperation: Identifiable, Codable, Sendable {
    let id: UUID
    let bureauTrack: String                    // ExpandedCareerTrack.rawValue
    let operationType: BureauOperationType
    let name: String
    let description: String

    // Timing
    let initiatedTurn: Int
    let targetCompletionTurn: Int?

    // Progress
    var progress: Int                          // 0-100
    var status: OperationStatus

    // Target information (optional depending on operation type)
    var targetCharacterId: String?
    var targetCharacterName: String?
    var targetRegionId: String?
    var targetRegionName: String?
    var targetDepartment: String?

    // Metrics
    var successChance: Int                     // 0-100
    var riskLevel: BureauRiskLevel

    // Linked data (for connecting to existing services)
    var sourceActionId: String?                // Links to SecurityAction, EconomicAction, etc.
    var sourceRecordId: UUID?                  // Links to SecurityActionRecord, etc.

    // MARK: - Computed Properties

    var bureau: ExpandedCareerTrack? {
        ExpandedCareerTrack(rawValue: bureauTrack)
    }

    var turnsElapsed: Int {
        guard let target = targetCompletionTurn else { return 0 }
        let totalTurns = max(1, target - initiatedTurn)
        let completedTurns = Int(round(Double(totalTurns) * (Double(progress) / 100.0)))
        return max(0, min(totalTurns, completedTurns))
    }

    var turnsRemaining: Int? {
        guard let target = targetCompletionTurn else { return nil }
        let totalTurns = max(1, target - initiatedTurn)
        return max(0, totalTurns - turnsElapsed)
    }

    var isActive: Bool {
        status.isActive
    }

    var iconName: String {
        operationType.iconName
    }

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        bureauTrack: String,
        operationType: BureauOperationType,
        name: String,
        description: String,
        initiatedTurn: Int,
        targetCompletionTurn: Int? = nil,
        progress: Int = 0,
        status: OperationStatus = .inProgress,
        targetCharacterId: String? = nil,
        targetCharacterName: String? = nil,
        targetRegionId: String? = nil,
        targetRegionName: String? = nil,
        targetDepartment: String? = nil,
        successChance: Int = 50,
        riskLevel: BureauRiskLevel = .moderate,
        sourceActionId: String? = nil,
        sourceRecordId: UUID? = nil
    ) {
        self.id = id
        self.bureauTrack = bureauTrack
        self.operationType = operationType
        self.name = name
        self.description = description
        self.initiatedTurn = initiatedTurn
        self.targetCompletionTurn = targetCompletionTurn
        self.progress = progress
        self.status = status
        self.targetCharacterId = targetCharacterId
        self.targetCharacterName = targetCharacterName
        self.targetRegionId = targetRegionId
        self.targetRegionName = targetRegionName
        self.targetDepartment = targetDepartment
        self.successChance = successChance
        self.riskLevel = riskLevel
        self.sourceActionId = sourceActionId
        self.sourceRecordId = sourceRecordId
    }
}
