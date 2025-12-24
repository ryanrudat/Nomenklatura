//
//  SuccessionRelationship.swift
//  Nomenklatura
//
//  Model for heir/successor cultivation relationships
//

import Foundation
import SwiftData

@Model
final class SuccessionRelationship {
    @Attribute(.unique) var id: UUID
    var mentorId: UUID              // Player's character ID
    var protegeId: UUID             // Heir's character ID
    var protegeName: String         // Cached name for display
    var protegeTitle: String?       // Cached title

    var strength: Int               // 0-100 relationship quality
    var turnsActive: Int            // How long this relationship has existed
    var mentorshipType: String      // MentorshipType raw value

    // Risk factors
    var protegeAmbition: Int        // High + neglected = rival risk
    var protegeCompetence: Int      // Affects their success
    var protegeLoyalty: Int         // Loyalty to mentor

    var lastMentoringTurn: Int      // Last turn when actively mentored
    var neglectCounter: Int         // Increases if not maintained

    // Status
    var isActive: Bool              // Whether this relationship is current
    var becameRival: Bool           // If protege turned against mentor
    var becameRivalTurn: Int?       // When they turned

    var game: Game?

    init(
        mentorId: UUID,
        protegeId: UUID,
        protegeName: String,
        protegeTitle: String? = nil,
        turnsActive: Int = 1,
        mentorshipType: MentorshipType = .informal
    ) {
        self.id = UUID()
        self.mentorId = mentorId
        self.protegeId = protegeId
        self.protegeName = protegeName
        self.protegeTitle = protegeTitle
        self.strength = 30
        self.turnsActive = turnsActive
        self.mentorshipType = mentorshipType.rawValue

        // Default protege attributes
        self.protegeAmbition = Int.random(in: 40...70)
        self.protegeCompetence = Int.random(in: 40...70)
        self.protegeLoyalty = Int.random(in: 40...60)

        self.lastMentoringTurn = 1
        self.neglectCounter = 0

        self.isActive = true
        self.becameRival = false
    }

    /// Process a turn for this relationship
    func processTurn(currentTurn: Int) {
        turnsActive += 1

        // Check for neglect
        let turnsSinceMentoring = currentTurn - lastMentoringTurn
        if turnsSinceMentoring >= 2 {
            neglectCounter += 1
            protegeLoyalty = max(0, protegeLoyalty - 5)

            // High ambition + neglect = rival risk
            if neglectCounter >= 3 && protegeAmbition > 70 && protegeLoyalty < 40 {
                becomeRival(turn: currentTurn)
            }
        }

        // Natural ambition growth
        if Int.random(in: 1...100) <= 20 {
            protegeAmbition = min(100, protegeAmbition + 5)
        }
    }

    /// Mentor actively cultivates this heir
    func mentor(turn: Int, strengthBonus: Int = 10) {
        lastMentoringTurn = turn
        neglectCounter = max(0, neglectCounter - 1)
        strength = min(100, strength + strengthBonus)
        protegeLoyalty = min(100, protegeLoyalty + 5)
    }

    /// Advocate for heir's promotion
    func advocatePromotion(success: Bool) {
        if success {
            strength = min(100, strength + 15)
            protegeLoyalty = min(100, protegeLoyalty + 10)
        } else {
            strength = max(0, strength - 10)
            protegeAmbition = min(100, protegeAmbition + 10) // Frustrated
        }
    }

    /// Heir becomes a rival
    func becomeRival(turn: Int) {
        isActive = false
        becameRival = true
        becameRivalTurn = turn
    }

    /// Deactivate relationship (not hostile)
    func deactivate() {
        isActive = false
    }
}

// MARK: - Mentorship Type

enum MentorshipType: String, Codable, CaseIterable, Sendable {
    case informal           // Casual guidance
    case mentorship         // Active mentoring
    case grooming           // Intentional succession prep
    case designated         // Official successor (high risk)

    var displayName: String {
        switch self {
        case .informal: return "Informal Guidance"
        case .mentorship: return "Active Mentorship"
        case .grooming: return "Succession Grooming"
        case .designated: return "Designated Successor"
        }
    }

    var riskLevel: String {
        switch self {
        case .informal: return "Low"
        case .mentorship: return "Low"
        case .grooming: return "Medium"
        case .designated: return "High"
        }
    }

    /// Minimum position index required
    var minimumPosition: Int {
        switch self {
        case .informal: return 3
        case .mentorship: return 4
        case .grooming: return 4
        case .designated: return 5
        }
    }

    /// How visible this relationship is to others
    var visibility: Int {
        switch self {
        case .informal: return 10
        case .mentorship: return 30
        case .grooming: return 60
        case .designated: return 90
        }
    }
}

// MARK: - Computed Properties

extension SuccessionRelationship {
    var currentMentorshipType: MentorshipType {
        MentorshipType(rawValue: mentorshipType) ?? .informal
    }

    /// Risk of this heir becoming a rival
    var rivalRisk: Int {
        var risk = 0

        // High ambition increases risk
        if protegeAmbition > 70 { risk += 30 }
        else if protegeAmbition > 50 { risk += 15 }

        // Low loyalty increases risk
        if protegeLoyalty < 30 { risk += 30 }
        else if protegeLoyalty < 50 { risk += 15 }

        // Neglect increases risk
        risk += neglectCounter * 10

        // Strong relationship decreases risk
        if strength > 70 { risk -= 20 }
        else if strength > 50 { risk -= 10 }

        return max(0, min(100, risk))
    }

    /// Whether this heir is ready to potentially succeed
    var isReadyToSucceed: Bool {
        strength >= 60 && protegeCompetence >= 50 && protegeLoyalty >= 40
    }

    /// Display string for relationship status
    var statusDescription: String {
        if becameRival {
            return "Turned Rival"
        } else if !isActive {
            return "Inactive"
        } else if rivalRisk > 60 {
            return "Dangerous"
        } else if rivalRisk > 30 {
            return "Restless"
        } else if strength > 70 {
            return "Devoted"
        } else if strength > 50 {
            return "Loyal"
        } else {
            return "Developing"
        }
    }
}
