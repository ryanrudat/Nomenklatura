//
//  TestScenario.swift
//  Nomenklatura
//
//  Test scenario definitions for debug testing of different game states.
//
//  ============================================================================
//  DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
//  This entire file should be removed before production release.
//  All code is wrapped in #if DEBUG to prevent accidental inclusion.
//  ============================================================================
//

import Foundation

#if DEBUG

// MARK: - Test Scenario Model

/// A complete test scenario configuration for jumping to specific game states.
/// Used only in DEBUG builds for testing different bureau positions, crisis situations, etc.
struct TestScenario: Identifiable, Codable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: TestScenarioCategory

    // Game state configuration
    let positionConfig: TestPositionConfig
    let statsConfig: TestStatsConfig
    let relationshipConfig: TestRelationshipConfig
    let crisisConfig: TestCrisisConfig?
    let npcOverrides: [TestNPCOverride]?
    let flagsToSet: [String]?
    let trackAffinityOverride: TestTrackAffinityConfig?
    let turnNumber: Int

    init(
        id: String,
        name: String,
        description: String,
        category: TestScenarioCategory,
        positionConfig: TestPositionConfig,
        statsConfig: TestStatsConfig = TestStatsConfig(),
        relationshipConfig: TestRelationshipConfig = TestRelationshipConfig(),
        crisisConfig: TestCrisisConfig? = nil,
        npcOverrides: [TestNPCOverride]? = nil,
        flagsToSet: [String]? = nil,
        trackAffinityOverride: TestTrackAffinityConfig? = nil,
        turnNumber: Int = 10
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.positionConfig = positionConfig
        self.statsConfig = statsConfig
        self.relationshipConfig = relationshipConfig
        self.crisisConfig = crisisConfig
        self.npcOverrides = npcOverrides
        self.flagsToSet = flagsToSet
        self.trackAffinityOverride = trackAffinityOverride
        self.turnNumber = turnNumber
    }
}

// MARK: - Scenario Category

enum TestScenarioCategory: String, Codable, CaseIterable, Sendable {
    case bureauPositions    // Testing different tracks
    case careerLevels       // Testing progression stages
    case crisisSituations   // Testing danger states
    case relationships      // Testing NPC dynamics
    case combined           // Complex multi-factor scenarios

    var displayName: String {
        switch self {
        case .bureauPositions: return "Bureau Positions"
        case .careerLevels: return "Career Levels"
        case .crisisSituations: return "Crisis"
        case .relationships: return "Relationships"
        case .combined: return "Combined"
        }
    }

    var iconName: String {
        switch self {
        case .bureauPositions: return "building.columns.fill"
        case .careerLevels: return "ladder.up"
        case .crisisSituations: return "exclamationmark.triangle.fill"
        case .relationships: return "person.2.fill"
        case .combined: return "square.stack.3d.up.fill"
        }
    }
}

// MARK: - Position Config

struct TestPositionConfig: Codable, Sendable {
    let positionIndex: Int
    let expandedTrack: String  // ExpandedCareerTrack.rawValue
    let turnsInPosition: Int?
    let turnsAsGeneralSecretary: Int?

    init(
        positionIndex: Int,
        expandedTrack: String,
        turnsInPosition: Int? = nil,
        turnsAsGeneralSecretary: Int? = nil
    ) {
        self.positionIndex = positionIndex
        self.expandedTrack = expandedTrack
        self.turnsInPosition = turnsInPosition
        self.turnsAsGeneralSecretary = turnsAsGeneralSecretary
    }
}

// MARK: - Stats Config

struct TestStatsConfig: Codable, Sendable {
    // National stats (optional - nil means use defaults)
    let stability: Int?
    let popularSupport: Int?
    let militaryLoyalty: Int?
    let eliteLoyalty: Int?
    let treasury: Int?
    let industrialOutput: Int?
    let foodSupply: Int?
    let internationalStanding: Int?

    // Personal stats
    let standing: Int?
    let patronFavor: Int?
    let rivalThreat: Int?
    let network: Int?

    // Reputation
    let reputationCompetent: Int?
    let reputationLoyal: Int?
    let reputationCunning: Int?
    let reputationRuthless: Int?

    // Wealth/Corruption
    let personalWealth: Int?
    let corruptionEvidence: Int?

    init(
        stability: Int? = nil,
        popularSupport: Int? = nil,
        militaryLoyalty: Int? = nil,
        eliteLoyalty: Int? = nil,
        treasury: Int? = nil,
        industrialOutput: Int? = nil,
        foodSupply: Int? = nil,
        internationalStanding: Int? = nil,
        standing: Int? = nil,
        patronFavor: Int? = nil,
        rivalThreat: Int? = nil,
        network: Int? = nil,
        reputationCompetent: Int? = nil,
        reputationLoyal: Int? = nil,
        reputationCunning: Int? = nil,
        reputationRuthless: Int? = nil,
        personalWealth: Int? = nil,
        corruptionEvidence: Int? = nil
    ) {
        self.stability = stability
        self.popularSupport = popularSupport
        self.militaryLoyalty = militaryLoyalty
        self.eliteLoyalty = eliteLoyalty
        self.treasury = treasury
        self.industrialOutput = industrialOutput
        self.foodSupply = foodSupply
        self.internationalStanding = internationalStanding
        self.standing = standing
        self.patronFavor = patronFavor
        self.rivalThreat = rivalThreat
        self.network = network
        self.reputationCompetent = reputationCompetent
        self.reputationLoyal = reputationLoyal
        self.reputationCunning = reputationCunning
        self.reputationRuthless = reputationRuthless
        self.personalWealth = personalWealth
        self.corruptionEvidence = corruptionEvidence
    }
}

// MARK: - Relationship Config

struct TestRelationshipConfig: Codable, Sendable {
    let patronDisposition: Int?
    let patronIsActive: Bool
    let rivalDisposition: Int?
    let rivalThreatLevel: Int?
    let rivalIsActive: Bool
    let createAdditionalAllies: Int?
    let createAdditionalRivals: Int?

    init(
        patronDisposition: Int? = nil,
        patronIsActive: Bool = true,
        rivalDisposition: Int? = nil,
        rivalThreatLevel: Int? = nil,
        rivalIsActive: Bool = true,
        createAdditionalAllies: Int? = nil,
        createAdditionalRivals: Int? = nil
    ) {
        self.patronDisposition = patronDisposition
        self.patronIsActive = patronIsActive
        self.rivalDisposition = rivalDisposition
        self.rivalThreatLevel = rivalThreatLevel
        self.rivalIsActive = rivalIsActive
        self.createAdditionalAllies = createAdditionalAllies
        self.createAdditionalRivals = createAdditionalRivals
    }
}

// MARK: - Crisis Config

struct TestCrisisConfig: Codable, Sendable {
    let resistanceAccumulation: Int?
    let coalitionStrength: Int?
    let policiesForced: Int?
    let activeShowTrialCount: Int?
    let activePurgeCampaign: Bool?

    init(
        resistanceAccumulation: Int? = nil,
        coalitionStrength: Int? = nil,
        policiesForced: Int? = nil,
        activeShowTrialCount: Int? = nil,
        activePurgeCampaign: Bool? = nil
    ) {
        self.resistanceAccumulation = resistanceAccumulation
        self.coalitionStrength = coalitionStrength
        self.policiesForced = policiesForced
        self.activeShowTrialCount = activeShowTrialCount
        self.activePurgeCampaign = activePurgeCampaign
    }
}

// MARK: - NPC Override

struct TestNPCOverride: Codable, Sendable {
    let templateId: String
    let disposition: Int?
    let isPatron: Bool?
    let isRival: Bool?
    let status: String?  // CharacterStatus.rawValue
    let positionIndex: Int?
    let positionTrack: String?
    let grudgeLevel: Int?
    let fearLevel: Int?
    let trustLevel: Int?

    init(
        templateId: String,
        disposition: Int? = nil,
        isPatron: Bool? = nil,
        isRival: Bool? = nil,
        status: String? = nil,
        positionIndex: Int? = nil,
        positionTrack: String? = nil,
        grudgeLevel: Int? = nil,
        fearLevel: Int? = nil,
        trustLevel: Int? = nil
    ) {
        self.templateId = templateId
        self.disposition = disposition
        self.isPatron = isPatron
        self.isRival = isRival
        self.status = status
        self.positionIndex = positionIndex
        self.positionTrack = positionTrack
        self.grudgeLevel = grudgeLevel
        self.fearLevel = fearLevel
        self.trustLevel = trustLevel
    }
}

// MARK: - Track Affinity Config

struct TestTrackAffinityConfig: Codable, Sendable {
    let partyApparatus: Int
    let stateMinistry: Int
    let securityServices: Int
    let foreignAffairs: Int
    let economicPlanning: Int
    let militaryPolitical: Int

    init(
        partyApparatus: Int = 0,
        stateMinistry: Int = 0,
        securityServices: Int = 0,
        foreignAffairs: Int = 0,
        economicPlanning: Int = 0,
        militaryPolitical: Int = 0
    ) {
        self.partyApparatus = partyApparatus
        self.stateMinistry = stateMinistry
        self.securityServices = securityServices
        self.foreignAffairs = foreignAffairs
        self.economicPlanning = economicPlanning
        self.militaryPolitical = militaryPolitical
    }

    /// Convert to game's TrackAffinityScores
    func toTrackAffinityScores() -> TrackAffinityScores {
        var scores = TrackAffinityScores()
        scores.partyApparatus = partyApparatus
        scores.stateMinistry = stateMinistry
        scores.securityServices = securityServices
        scores.foreignAffairs = foreignAffairs
        scores.economicPlanning = economicPlanning
        scores.militaryPolitical = militaryPolitical
        return scores
    }
}

#endif
