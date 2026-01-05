//
//  TestScenarios.swift
//  Nomenklatura
//
//  Predefined test scenarios for common testing needs.
//
//  ============================================================================
//  DEBUG/DEVELOPMENT CODE - REMOVE BEFORE APP STORE RELEASE
//  This entire file should be removed before production release.
//  All code is wrapped in #if DEBUG to prevent accidental inclusion.
//  ============================================================================
//

import Foundation

#if DEBUG

/// Collection of predefined test scenarios for development and QA testing.
/// Access scenarios via TestScenarios.allScenarios or TestScenarios.scenario(withId:)
struct TestScenarios {

    // MARK: - Bureau Position Scenarios

    // Party Apparatus Track
    static let partyJunior = TestScenario(
        id: "party_junior",
        name: "Party Apparatus - Junior",
        description: "Central Committee Instructor, early career in ideology and personnel",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 2,
            expandedTrack: "partyApparatus",
            turnsInPosition: 3
        ),
        statsConfig: TestStatsConfig(
            standing: 35, patronFavor: 50, rivalThreat: 20, network: 25,
            reputationLoyal: 55
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 60, patronIsActive: true,
            rivalDisposition: -20, rivalThreatLevel: 25, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 15)
    )

    static let partySenior = TestScenario(
        id: "party_senior",
        name: "Party Apparatus - Senior",
        description: "CC Department Head, significant influence over cadre selection",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "partyApparatus",
            turnsInPosition: 6
        ),
        statsConfig: TestStatsConfig(
            eliteLoyalty: 60,
            standing: 65, patronFavor: 55, rivalThreat: 45, network: 50,
            reputationCompetent: 60, reputationLoyal: 65
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 55, patronIsActive: true,
            rivalDisposition: -35, rivalThreatLevel: 50, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 40, stateMinistry: 10),
        turnNumber: 25
    )

    static let partyApex = TestScenario(
        id: "party_apex",
        name: "Party Apparatus - Apex",
        description: "Head of Organization Department, one step from the top",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 6,
            expandedTrack: "partyApparatus",
            turnsInPosition: 8
        ),
        statsConfig: TestStatsConfig(
            eliteLoyalty: 75,
            standing: 85, patronFavor: 70, rivalThreat: 55, network: 70,
            reputationCompetent: 75, reputationLoyal: 70, reputationCunning: 60
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 70, patronIsActive: true,
            rivalDisposition: -50, rivalThreatLevel: 55, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 60, stateMinistry: 15, securityServices: 10),
        turnNumber: 40
    )

    // Security Services Track
    static let securityJunior = TestScenario(
        id: "security_junior",
        name: "Security Services - Junior",
        description: "BPS Section Chief, beginning surveillance career",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 2,
            expandedTrack: "securityServices",
            turnsInPosition: 4
        ),
        statsConfig: TestStatsConfig(
            standing: 40, patronFavor: 45, rivalThreat: 30, network: 35,
            reputationRuthless: 45
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 55, patronIsActive: true,
            rivalDisposition: -30, rivalThreatLevel: 35, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(securityServices: 20)
    )

    static let securitySenior = TestScenario(
        id: "security_senior",
        name: "Security Services - Senior",
        description: "Directorate Chief with surveillance authority",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "securityServices",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            standing: 70, patronFavor: 60, rivalThreat: 50, network: 60,
            reputationCunning: 55, reputationRuthless: 65
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 60, patronIsActive: true,
            rivalDisposition: -45, rivalThreatLevel: 55, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 10, securityServices: 50),
        turnNumber: 28
    )

    static let securityApex = TestScenario(
        id: "security_apex",
        name: "Security Services - Apex",
        description: "BPS Director, controls state security apparatus",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 6,
            expandedTrack: "securityServices",
            turnsInPosition: 7
        ),
        statsConfig: TestStatsConfig(
            standing: 88, patronFavor: 65, rivalThreat: 60, network: 80,
            reputationCompetent: 70, reputationCunning: 75, reputationRuthless: 80
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 65, patronIsActive: true,
            rivalDisposition: -60, rivalThreatLevel: 60, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 15, securityServices: 70),
        turnNumber: 45
    )

    // Foreign Affairs Track
    static let foreignJunior = TestScenario(
        id: "foreign_junior",
        name: "Foreign Affairs - Junior",
        description: "Embassy Attaché, beginning diplomatic career",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 2,
            expandedTrack: "foreignAffairs",
            turnsInPosition: 3
        ),
        statsConfig: TestStatsConfig(
            internationalStanding: 55,
            standing: 35, patronFavor: 50, rivalThreat: 15, network: 30
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 60, patronIsActive: true,
            rivalDisposition: -15, rivalThreatLevel: 20, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(foreignAffairs: 18)
    )

    static let foreignSenior = TestScenario(
        id: "foreign_senior",
        name: "Foreign Affairs - Senior",
        description: "Deputy Foreign Minister, negotiates treaties",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "foreignAffairs",
            turnsInPosition: 6
        ),
        statsConfig: TestStatsConfig(
            internationalStanding: 70,
            standing: 65, patronFavor: 60, rivalThreat: 35, network: 55
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 65, patronIsActive: true,
            rivalDisposition: -30, rivalThreatLevel: 40, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(stateMinistry: 12, foreignAffairs: 45),
        turnNumber: 30
    )

    static let foreignApex = TestScenario(
        id: "foreign_apex",
        name: "Foreign Affairs - Apex",
        description: "Foreign Minister, voice of the nation abroad",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 6,
            expandedTrack: "foreignAffairs",
            turnsInPosition: 8
        ),
        statsConfig: TestStatsConfig(
            internationalStanding: 85,
            standing: 90, patronFavor: 75, rivalThreat: 50, network: 75,
            reputationCompetent: 80
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 75, patronIsActive: true,
            rivalDisposition: -45, rivalThreatLevel: 50, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 10, stateMinistry: 15, foreignAffairs: 65),
        turnNumber: 48
    )

    // State Ministry Track
    static let stateSenior = TestScenario(
        id: "state_senior",
        name: "State Ministry - Senior",
        description: "Deputy Minister of Production, governance specialist",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "stateMinistry",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            stability: 60,
            standing: 60, patronFavor: 55, rivalThreat: 40, network: 45,
            reputationCompetent: 65
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 58, patronIsActive: true,
            rivalDisposition: -35, rivalThreatLevel: 45, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(stateMinistry: 45, economicPlanning: 15),
        turnNumber: 26
    )

    // Economic Planning Track
    static let economicSenior = TestScenario(
        id: "economic_senior",
        name: "Economic Planning - Senior",
        description: "Gosplan Deputy Chairman, manages quotas and production",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "economicPlanning",
            turnsInPosition: 6
        ),
        statsConfig: TestStatsConfig(
            treasury: 55, industrialOutput: 65,
            standing: 62, patronFavor: 58, rivalThreat: 38, network: 50,
            reputationCompetent: 70
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 60, patronIsActive: true,
            rivalDisposition: -32, rivalThreatLevel: 42, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(stateMinistry: 12, economicPlanning: 48),
        turnNumber: 27
    )

    // Military-Political Track
    static let militarySenior = TestScenario(
        id: "military_senior",
        name: "Military-Political - Senior",
        description: "MPA Deputy Director, political control of the army",
        category: .bureauPositions,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "militaryPolitical",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            militaryLoyalty: 70,
            standing: 65, patronFavor: 55, rivalThreat: 45, network: 50,
            reputationLoyal: 70
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 55, patronIsActive: true,
            rivalDisposition: -40, rivalThreatLevel: 50, rivalIsActive: true
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 12, militaryPolitical: 50),
        turnNumber: 28
    )

    // MARK: - Crisis Scenarios

    static let nearPurge = TestScenario(
        id: "near_purge",
        name: "Near-Purge Crisis",
        description: "Under investigation, patron wavering, rival ascendant",
        category: .crisisSituations,
        positionConfig: TestPositionConfig(
            positionIndex: 3,
            expandedTrack: "stateMinistry",
            turnsInPosition: 4
        ),
        statsConfig: TestStatsConfig(
            stability: 42,
            standing: 32, patronFavor: 22, rivalThreat: 88, network: 28,
            reputationLoyal: 30,
            corruptionEvidence: 65
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 28, patronIsActive: true,
            rivalDisposition: -75, rivalThreatLevel: 90, rivalIsActive: true
        ),
        crisisConfig: TestCrisisConfig(
            resistanceAccumulation: 75,
            coalitionStrength: 70
        ),
        flagsToSet: ["under_investigation", "patron_wavering"],
        turnNumber: 22
    )

    static let lowStability = TestScenario(
        id: "low_stability",
        name: "National Crisis",
        description: "Nation on brink of collapse, multiple crises at once",
        category: .crisisSituations,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "economicPlanning",
            turnsInPosition: 3
        ),
        statsConfig: TestStatsConfig(
            stability: 18, popularSupport: 22,
            treasury: 18, industrialOutput: 28, foodSupply: 12,
            standing: 55, patronFavor: 48, network: 42
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 50, patronIsActive: true,
            rivalThreatLevel: 40, rivalIsActive: true
        ),
        turnNumber: 30
    )

    static let factionWar = TestScenario(
        id: "faction_war",
        name: "Faction Conflict",
        description: "Multiple factions at war, player caught in crossfire",
        category: .crisisSituations,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "partyApparatus",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            eliteLoyalty: 32,
            standing: 58, patronFavor: 38, rivalThreat: 72, network: 48
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 42, patronIsActive: true,
            rivalDisposition: -65, rivalThreatLevel: 75, rivalIsActive: true,
            createAdditionalRivals: 2
        ),
        crisisConfig: TestCrisisConfig(coalitionStrength: 58),
        turnNumber: 28
    )

    static let economicCollapse = TestScenario(
        id: "economic_collapse",
        name: "Economic Collapse",
        description: "Production failing, famine looming, discontent rising",
        category: .crisisSituations,
        positionConfig: TestPositionConfig(
            positionIndex: 5,
            expandedTrack: "economicPlanning",
            turnsInPosition: 4
        ),
        statsConfig: TestStatsConfig(
            stability: 35, popularSupport: 25,
            treasury: 10, industrialOutput: 15, foodSupply: 8,
            standing: 45, patronFavor: 35, rivalThreat: 60, network: 40
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 40, patronIsActive: true,
            rivalDisposition: -55, rivalThreatLevel: 65, rivalIsActive: true
        ),
        turnNumber: 35
    )

    // MARK: - Relationship Scenarios

    static let strongPatron = TestScenario(
        id: "strong_patron",
        name: "Strong Patron Bond",
        description: "Patron fully supports you, high trust relationship",
        category: .relationships,
        positionConfig: TestPositionConfig(
            positionIndex: 3,
            expandedTrack: "shared",
            turnsInPosition: 4
        ),
        statsConfig: TestStatsConfig(
            standing: 55, patronFavor: 92, rivalThreat: 18, network: 38,
            reputationLoyal: 85
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 88, patronIsActive: true,
            rivalThreatLevel: 18, rivalIsActive: true
        ),
        npcOverrides: [
            TestNPCOverride(templateId: "wallace", disposition: 88, fearLevel: 8, trustLevel: 85)
        ],
        turnNumber: 18
    )

    static let hostileRival = TestScenario(
        id: "hostile_rival",
        name: "Hostile Rival Dominant",
        description: "Rival has significant advantage, actively plotting your downfall",
        category: .relationships,
        positionConfig: TestPositionConfig(
            positionIndex: 3,
            expandedTrack: "stateMinistry",
            turnsInPosition: 3
        ),
        statsConfig: TestStatsConfig(
            standing: 42, patronFavor: 48, rivalThreat: 82, network: 28
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 48, patronIsActive: true,
            rivalDisposition: -82, rivalThreatLevel: 85, rivalIsActive: true
        ),
        npcOverrides: [
            TestNPCOverride(templateId: "kovacs", disposition: -82, positionIndex: 4, grudgeLevel: -75)
        ],
        turnNumber: 20
    )

    static let deadPatron = TestScenario(
        id: "dead_patron",
        name: "Patron Recently Deceased",
        description: "Patron has died, must find new protection or face rivals alone",
        category: .relationships,
        positionConfig: TestPositionConfig(
            positionIndex: 3,
            expandedTrack: "securityServices",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            standing: 48, patronFavor: 8, rivalThreat: 62, network: 38
        ),
        relationshipConfig: TestRelationshipConfig(
            patronIsActive: false,
            rivalThreatLevel: 65, rivalIsActive: true,
            createAdditionalAllies: 1
        ),
        npcOverrides: [
            TestNPCOverride(templateId: "wallace", status: "dead")
        ],
        flagsToSet: ["patron_recently_died", "seeking_new_patron"],
        turnNumber: 25
    )

    static let multipleRivals = TestScenario(
        id: "multiple_rivals",
        name: "Multiple Rivals",
        description: "Facing opposition from several directions at once",
        category: .relationships,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "partyApparatus",
            turnsInPosition: 4
        ),
        statsConfig: TestStatsConfig(
            standing: 55, patronFavor: 45, rivalThreat: 75, network: 40
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 50, patronIsActive: true,
            rivalDisposition: -60, rivalThreatLevel: 75, rivalIsActive: true,
            createAdditionalRivals: 2
        ),
        turnNumber: 28
    )

    // MARK: - Combined Complex Scenarios

    static let generalSecretaryStart = TestScenario(
        id: "gen_sec_start",
        name: "New General Secretary",
        description: "Just achieved the top position, now must consolidate power",
        category: .combined,
        positionConfig: TestPositionConfig(
            positionIndex: 8,
            expandedTrack: "shared",
            turnsAsGeneralSecretary: 1
        ),
        statsConfig: TestStatsConfig(
            stability: 58, eliteLoyalty: 62,
            standing: 95, patronFavor: 0, rivalThreat: 52, network: 82,
            reputationCompetent: 78, reputationCunning: 72
        ),
        relationshipConfig: TestRelationshipConfig(
            patronIsActive: false,  // No patron at top
            rivalThreatLevel: 52, rivalIsActive: true,
            createAdditionalRivals: 2
        ),
        crisisConfig: TestCrisisConfig(
            resistanceAccumulation: 28,
            coalitionStrength: 42
        ),
        turnNumber: 50
    )

    static let successionCrisis = TestScenario(
        id: "succession_crisis",
        name: "Succession Crisis",
        description: "General Secretary dying, factions positioning for power",
        category: .combined,
        positionConfig: TestPositionConfig(
            positionIndex: 5,
            expandedTrack: "partyApparatus",
            turnsInPosition: 6
        ),
        statsConfig: TestStatsConfig(
            stability: 42, eliteLoyalty: 38,
            standing: 78, patronFavor: 62, rivalThreat: 72, network: 58
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 62, patronIsActive: true,
            rivalDisposition: -52, rivalThreatLevel: 72, rivalIsActive: true,
            createAdditionalRivals: 1
        ),
        crisisConfig: TestCrisisConfig(coalitionStrength: 52),
        flagsToSet: ["gs_health_failing", "succession_imminent"],
        turnNumber: 45
    )

    static let apexCompetition = TestScenario(
        id: "apex_competition",
        name: "Apex Competition",
        description: "Competing with rivals for apex position in your track",
        category: .combined,
        positionConfig: TestPositionConfig(
            positionIndex: 5,
            expandedTrack: "securityServices",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            standing: 82, patronFavor: 65, rivalThreat: 68, network: 70,
            reputationCompetent: 75, reputationRuthless: 65
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 65, patronIsActive: true,
            rivalDisposition: -58, rivalThreatLevel: 68, rivalIsActive: true,
            createAdditionalRivals: 1
        ),
        trackAffinityOverride: TestTrackAffinityConfig(partyApparatus: 12, securityServices: 58),
        turnNumber: 40
    )

    static let corruptionExposed = TestScenario(
        id: "corruption_exposed",
        name: "Corruption Exposed",
        description: "Your corrupt activities are being investigated",
        category: .combined,
        positionConfig: TestPositionConfig(
            positionIndex: 4,
            expandedTrack: "stateMinistry",
            turnsInPosition: 5
        ),
        statsConfig: TestStatsConfig(
            standing: 52, patronFavor: 35, rivalThreat: 75, network: 45,
            reputationLoyal: 25,
            personalWealth: 70, corruptionEvidence: 80
        ),
        relationshipConfig: TestRelationshipConfig(
            patronDisposition: 38, patronIsActive: true,
            rivalDisposition: -70, rivalThreatLevel: 78, rivalIsActive: true
        ),
        crisisConfig: TestCrisisConfig(resistanceAccumulation: 55),
        flagsToSet: ["under_investigation", "corruption_probe_active"],
        turnNumber: 32
    )

    // MARK: - All Scenarios Collection

    static let allScenarios: [TestScenario] = [
        // Bureau positions
        partyJunior, partySenior, partyApex,
        securityJunior, securitySenior, securityApex,
        foreignJunior, foreignSenior, foreignApex,
        stateSenior, economicSenior, militarySenior,

        // Crises
        nearPurge, lowStability, factionWar, economicCollapse,

        // Relationships
        strongPatron, hostileRival, deadPatron, multipleRivals,

        // Combined
        generalSecretaryStart, successionCrisis, apexCompetition, corruptionExposed
    ]

    /// Find a scenario by ID
    static func scenario(withId id: String) -> TestScenario? {
        allScenarios.first { $0.id == id }
    }

    /// Get all scenarios in a category
    static func scenarios(inCategory category: TestScenarioCategory) -> [TestScenario] {
        allScenarios.filter { $0.category == category }
    }

    /// Get scenario IDs for launch argument help
    static var allScenarioIds: [String] {
        allScenarios.map { $0.id }
    }
}

#endif
