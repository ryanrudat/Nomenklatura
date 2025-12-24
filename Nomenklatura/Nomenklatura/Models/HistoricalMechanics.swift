//
//  HistoricalMechanics.swift
//  Nomenklatura
//
//  Models for historical accuracy: power consolidation, self-criticism,
//  show trials, and purge campaigns
//

import Foundation
import SwiftData

// MARK: - Power Consolidation

/// Tracks the General Secretary's power consolidation level
/// Higher consolidation = harder to remove through collective leadership
struct PowerConsolidation: Codable {
    var score: Int                    // 0-100

    // Factors affecting consolidation
    var turnsInPosition: Int
    var loyalAppointments: Int        // How many positions filled with loyalists
    var successfulPurges: Int
    var failedPolicies: Int
    var economicCrises: Int
    var factionalOpposition: Int

    init() {
        self.score = 20  // Start relatively vulnerable
        self.turnsInPosition = 0
        self.loyalAppointments = 0
        self.successfulPurges = 0
        self.failedPolicies = 0
        self.economicCrises = 0
        self.factionalOpposition = 0
    }

    /// Recalculate power consolidation score
    mutating func recalculate() {
        var newScore = 20  // Base

        // Time in position (max +30)
        newScore += min(30, turnsInPosition * 2)

        // Loyal appointments (max +25)
        newScore += min(25, loyalAppointments * 5)

        // Successful purges (max +20)
        newScore += min(20, successfulPurges * 10)

        // Penalties
        newScore -= failedPolicies * 5
        newScore -= economicCrises * 10
        newScore -= factionalOpposition * 3

        score = max(0, min(100, newScore))
    }

    /// Percentage of Politburo votes needed to remove leader
    var removalThreshold: Int {
        switch score {
        case 0...20: return 51    // Simple majority
        case 21...40: return 60
        case 41...60: return 70
        case 61...80: return 80
        case 81...100: return 95  // Nearly impossible
        default: return 51
        }
    }

    /// Display text for consolidation level
    var displayLevel: String {
        switch score {
        case 0...20: return "Vulnerable"
        case 21...40: return "Weak"
        case 41...60: return "Moderate"
        case 61...80: return "Strong"
        case 81...100: return "Absolute"
        default: return "Unknown"
        }
    }
}

// MARK: - Self-Criticism

/// Options for self-criticism sessions
enum SelfCriticismLevel: String, Codable, CaseIterable {
    case minor          // Admit small errors
    case full           // Complete public confession
    case tearful        // Dramatic public breakdown

    var displayName: String {
        switch self {
        case .minor: return "Minor Confession"
        case .full: return "Full Self-Criticism"
        case .tearful: return "Tearful Confession"
        }
    }

    var description: String {
        switch self {
        case .minor:
            return "Admit minor ideological errors and promise to study harder."
        case .full:
            return "Publicly confess to serious failures and beg the Party's forgiveness."
        case .tearful:
            return "Complete breakdown - tears, begging, total abasement before the collective."
        }
    }

    /// Suspicion reduction percentage
    var suspicionReduction: Int {
        switch self {
        case .minor: return 30
        case .full: return 60
        case .tearful: return 80
        }
    }

    /// Effects on player stats
    var effects: [String: Int] {
        switch self {
        case .minor:
            return [
                "reputationCompetent": -10,
                "standing": -5
            ]
        case .full:
            return [
                "reputationCompetent": -20,
                "standing": -15,
                "patronFavor": -10
            ]
        case .tearful:
            return [
                "reputationCompetent": -30,
                "standing": -20,
                "reputationRuthless": -10  // Shows weakness
            ]
        }
    }

    /// Risk that self-criticism is used against you later
    var futureRisk: Int {
        switch self {
        case .minor: return 10
        case .full: return 30
        case .tearful: return 50
        }
    }
}

/// Result of a self-criticism session
struct SelfCriticismResult: Codable {
    var level: SelfCriticismLevel
    var suspicionReduced: Int
    var statChanges: [String: Int]
    var wasRecorded: Bool           // Can be used against player later
    var sympathyGained: Bool        // Some faction members feel sympathy
    var narrativeText: String
}

// MARK: - Show Trial

/// Model for show trial proceedings
struct ShowTrial: Codable, Identifiable {
    var id: UUID
    var defendantId: UUID
    var defendantName: String
    var defendantTitle: String?

    var charges: [TrialCharge]
    var turnInitiated: Int
    var phase: ShowTrialPhase

    // Outcomes
    var confessionObtained: Bool
    var confessionType: ConfessionType?
    var sentence: TrialSentence?
    var executedTurn: Int?

    // Effects
    var intimidationGained: Int     // Faction fear
    var martyrCreated: Bool         // If defendant resisted
    var internationalCondemnation: Int

    init(
        defendantId: UUID,
        defendantName: String,
        defendantTitle: String? = nil,
        charges: [TrialCharge],
        turnInitiated: Int
    ) {
        self.id = UUID()
        self.defendantId = defendantId
        self.defendantName = defendantName
        self.defendantTitle = defendantTitle
        self.charges = charges
        self.turnInitiated = turnInitiated
        self.phase = .accusation
        self.confessionObtained = false
        self.intimidationGained = 0
        self.martyrCreated = false
        self.internationalCondemnation = 0
    }
}

enum ShowTrialPhase: String, Codable, CaseIterable {
    case accusation           // Charges announced
    case confessionExtraction // Behind scenes
    case publicTrial          // The show
    case sentencing           // Verdict
    case completed            // Done

    var displayName: String {
        switch self {
        case .accusation: return "Accusation"
        case .confessionExtraction: return "Interrogation"
        case .publicTrial: return "Public Trial"
        case .sentencing: return "Sentencing"
        case .completed: return "Completed"
        }
    }
}

enum TrialCharge: String, Codable, CaseIterable {
    case economicSabotage         // "Wrecking"
    case espionage                // Foreign contacts
    case counterRevolutionary     // Anti-party activities
    case trotskyism               // Ideological deviation
    case bourgeoisNationalism     // Nationalism
    case corruption               // Taking bribes
    case incompetence            // Failing quotas

    var displayName: String {
        switch self {
        case .economicSabotage: return "Economic Sabotage"
        case .espionage: return "Espionage for Foreign Powers"
        case .counterRevolutionary: return "Counter-Revolutionary Activity"
        case .trotskyism: return "Trotskyist Deviation"
        case .bourgeoisNationalism: return "Bourgeois Nationalism"
        case .corruption: return "Corruption and Bribery"
        case .incompetence: return "Criminal Negligence"
        }
    }

    /// Soviet-style formal charge
    var formalCharge: String {
        switch self {
        case .economicSabotage:
            return "deliberately sabotaging socialist construction through intentional wrecking activities"
        case .espionage:
            return "maintaining treasonous contacts with foreign intelligence services"
        case .counterRevolutionary:
            return "organizing counter-revolutionary conspiracy against the Socialist Republic"
        case .trotskyism:
            return "adherence to Trotskyist-Zinovievist bloc ideology"
        case .bourgeoisNationalism:
            return "promoting bourgeois nationalist deviation from Marxist-Leninist principles"
        case .corruption:
            return "abuse of position for personal enrichment"
        case .incompetence:
            return "criminal negligence resulting in harm to socialist construction"
        }
    }

    /// Severity affects sentence
    var severity: Int {
        switch self {
        case .espionage, .counterRevolutionary: return 10
        case .economicSabotage, .trotskyism: return 8
        case .bourgeoisNationalism: return 6
        case .corruption: return 5
        case .incompetence: return 3
        }
    }
}

enum ConfessionType: String, Codable, CaseIterable {
    case scripted             // Read prepared confession
    case resisted             // Refused to confess
    case recanted             // Confessed then withdrew
    case implicatedOthers     // Named co-conspirators

    var effects: (sentence: Int, martyr: Bool, newTargets: Bool) {
        switch self {
        case .scripted: return (-2, false, false)      // Lighter sentence
        case .resisted: return (2, true, false)        // Harsher, creates martyr
        case .recanted: return (3, true, false)        // Harshest
        case .implicatedOthers: return (-3, false, true) // Lightest, new purge targets
        }
    }
}

enum TrialSentence: String, Codable, CaseIterable {
    case execution
    case imprisonment25        // 25 years
    case imprisonment15        // 15 years
    case imprisonment10        // 10 years
    case exile
    case demotion             // Rare leniency

    var displayName: String {
        switch self {
        case .execution: return "Death by Firing Squad"
        case .imprisonment25: return "25 Years in Labor Camp"
        case .imprisonment15: return "15 Years in Labor Camp"
        case .imprisonment10: return "10 Years in Labor Camp"
        case .exile: return "Exile to Remote Region"
        case .demotion: return "Demotion and Public Reprimand"
        }
    }
}

// MARK: - Purge Campaign

/// Model for purge campaigns initiated by General Secretary
@Model
final class PurgeCampaign {
    @Attribute(.unique) var id: UUID
    var name: String                 // "Anti-Rightist Campaign"
    var targetSector: String         // PurgeSector raw value
    var intensity: String            // PurgeIntensity raw value

    var turnStarted: Int
    var turnEnded: Int?
    var isActive: Bool

    // Quotas and tracking
    var arrestQuota: Int
    var arrestsMade: Int
    var executionsMade: Int

    // Costs and effects
    var sectorLoyaltyLost: Int
    var productivityLost: Int
    var internationalStandingLost: Int

    // Results
    var rivalsEliminated: Int
    var innocentsArrested: Int
    var martyrsCreated: Int

    var game: Game?

    init(
        name: String,
        targetSector: PurgeSector,
        intensity: PurgeIntensity,
        turnStarted: Int
    ) {
        self.id = UUID()
        self.name = name
        self.targetSector = targetSector.rawValue
        self.intensity = intensity.rawValue
        self.turnStarted = turnStarted
        self.isActive = true

        self.arrestQuota = intensity.quota
        self.arrestsMade = 0
        self.executionsMade = 0

        self.sectorLoyaltyLost = 0
        self.productivityLost = 0
        self.internationalStandingLost = 0

        self.rivalsEliminated = 0
        self.innocentsArrested = 0
        self.martyrsCreated = 0
    }

    func endCampaign(turn: Int) {
        isActive = false
        turnEnded = turn
    }
}

enum PurgeSector: String, Codable, CaseIterable {
    case partyApparatus      // Central party bureaucracy
    case military            // Armed forces
    case securityServices    // Bureau of People's Security (BPS)
    case industrialMinistries // Economic managers
    case regionalGovernments // Zone governors and provincial leadership
    case intellectuals       // Writers, scientists, academics

    var displayName: String {
        switch self {
        case .partyApparatus: return "Party Apparatus"
        case .military: return "Military"
        case .securityServices: return "Security Services"
        case .industrialMinistries: return "Industrial Ministries"
        case .regionalGovernments: return "Regional Governments"
        case .intellectuals: return "Intellectuals"
        }
    }

    /// Cost to the affected stat when purging this sector
    var immediateCost: (stat: String, amount: Int) {
        switch self {
        case .partyApparatus: return ("eliteLoyalty", -10)
        case .military: return ("militaryLoyalty", -15)
        case .securityServices: return ("stability", -5)
        case .industrialMinistries: return ("industrialOutput", -10)
        case .regionalGovernments: return ("popularSupport", -5)
        case .intellectuals: return ("internationalStanding", -10)
        }
    }

    /// Long-term effect
    var longTermEffect: String {
        switch self {
        case .partyApparatus: return "Weakened administration"
        case .military: return "Reduced defense capability"
        case .securityServices: return "Paranoid security apparatus"
        case .industrialMinistries: return "Economic disruption"
        case .regionalGovernments: return "Regional resentment"
        case .intellectuals: return "Cultural stagnation"
        }
    }
}

enum PurgeIntensity: String, Codable, CaseIterable {
    case limited            // 5 arrests
    case moderate           // 15 arrests
    case sweeping           // 30+ arrests

    var displayName: String {
        switch self {
        case .limited: return "Limited"
        case .moderate: return "Moderate"
        case .sweeping: return "Sweeping"
        }
    }

    var quota: Int {
        switch self {
        case .limited: return 5
        case .moderate: return 15
        case .sweeping: return 30
        }
    }

    /// Risk multiplier for being discovered targeting innocents
    var riskMultiplier: Double {
        switch self {
        case .limited: return 1.0
        case .moderate: return 1.5
        case .sweeping: return 2.5
        }
    }
}

// MARK: - Extensions for Game

extension Game {
    /// Active purge campaigns
    var activePurgeCampaigns: [PurgeCampaign] {
        purgeCampaigns.filter { $0.isActive }
    }

    /// Check if a purge campaign is on cooldown
    var canLaunchPurgeCampaign: Bool {
        // Need at least 3 turns between campaigns
        guard let lastCampaign = purgeCampaigns.sorted(by: { $0.turnStarted > $1.turnStarted }).first else {
            return true
        }
        guard let endTurn = lastCampaign.turnEnded else {
            return false // Still active
        }
        return turnNumber - endTurn >= 3
    }
}
