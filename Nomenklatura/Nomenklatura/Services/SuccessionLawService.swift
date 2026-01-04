//
//  SuccessionLawService.swift
//  Nomenklatura
//
//  Service for handling law-governed succession mechanics.
//  The leadership_succession law determines how heirs are selected and what they inherit.
//

import Foundation
import SwiftData

// MARK: - Succession Mode

/// The current succession rules based on the leadership_succession law state
enum SuccessionMode: String, Codable {
    case collectiveDecision    // defaultState - SC selects from candidates
    case designatedSuccessor   // modifiedWeak - Leader names heir, SC confirms
    case familyPrivilege       // modifiedStrong - Family members get priority
    case partyElection         // strengthened - Open competition among Politburo
    case revolutionaryContinuity // abolished - Autocratic, leader's choice stands

    var displayName: String {
        switch self {
        case .collectiveDecision: return "Collective Decision"
        case .designatedSuccessor: return "Designated Successor"
        case .familyPrivilege: return "Family Privilege"
        case .partyElection: return "Party Election"
        case .revolutionaryContinuity: return "Revolutionary Continuity"
        }
    }

    var description: String {
        switch self {
        case .collectiveDecision:
            return "The Standing Committee collectively selects the successor from approved candidates."
        case .designatedSuccessor:
            return "The current leader may designate a preferred successor, subject to Standing Committee confirmation."
        case .familyPrivilege:
            return "Family members of the deceased leader receive priority consideration in succession."
        case .partyElection:
            return "All eligible Politburo members may compete for succession through Party election."
        case .revolutionaryContinuity:
            return "The leader rules until death, and their designated successor automatically takes power."
        }
    }

    /// Base inheritance percentage for this mode
    var baseInheritancePercent: Int {
        switch self {
        case .collectiveDecision: return 50
        case .designatedSuccessor: return 70
        case .familyPrivilege: return 85
        case .partyElection: return 40
        case .revolutionaryContinuity: return 60
        }
    }

    /// How much power does the Standing Committee have over succession?
    var standingCommitteePower: SCSuccessionPower {
        switch self {
        case .collectiveDecision: return .high
        case .designatedSuccessor: return .medium
        case .familyPrivilege: return .low
        case .partyElection: return .veryHigh
        case .revolutionaryContinuity: return .none
        }
    }
}

enum SCSuccessionPower: String, Codable {
    case none      // SC has no say
    case low       // Rubber stamp
    case medium    // Can reject but rarely does
    case high      // Makes the decision
    case veryHigh  // Open competition

    var displayName: String {
        switch self {
        case .none: return "None"
        case .low: return "Minimal"
        case .medium: return "Advisory"
        case .high: return "Decisive"
        case .veryHigh: return "Electoral"
        }
    }
}

// MARK: - Succession Law Service

class SuccessionLawService {
    static let shared = SuccessionLawService()

    private init() {}

    // MARK: - Get Current Mode

    /// Get the current succession mode based on the leadership_succession law
    func getCurrentMode(game: Game) -> SuccessionMode {
        guard let successionLaw = game.laws.first(where: { $0.lawId == "leadership_succession" }) else {
            // No law found, default to collective decision
            return .collectiveDecision
        }

        switch successionLaw.lawCurrentState {
        case .defaultState:
            return .collectiveDecision
        case .modifiedWeak:
            return .designatedSuccessor
        case .modifiedStrong:
            return .familyPrivilege
        case .strengthened:
            return .partyElection
        case .abolished:
            return .revolutionaryContinuity
        }
    }

    // MARK: - Calculate Inheritance

    /// Calculate inheritance percentage based on succession law and heir relationship
    func calculateInheritance(
        heir: GameCharacter,
        relationship: HeirRelationship,
        isFamily: Bool,
        game: Game
    ) -> InheritanceResult {
        let mode = getCurrentMode(game: game)
        let basePercent = mode.baseInheritancePercent

        // Relationship modifiers
        let relationshipModifier = getRelationshipModifier(relationship: relationship)

        // Family modifier based on law
        let familyModifier: Int
        if isFamily {
            switch mode {
            case .familyPrivilege:
                familyModifier = 20  // Bonus for family under family privilege
            case .partyElection:
                familyModifier = -10  // Penalty for nepotism under open election
            default:
                familyModifier = 5  // Small bonus in most systems
            }
        } else {
            familyModifier = 0
        }

        // Heir competence modifier
        let competenceModifier = (heir.personalityCompetent - 50) / 10  // -5 to +5

        // Calculate final percentage (capped at 100)
        let finalPercent = min(100, max(10, basePercent + relationshipModifier + familyModifier + competenceModifier))

        return InheritanceResult(
            mode: mode,
            basePercent: basePercent,
            relationshipModifier: relationshipModifier,
            familyModifier: familyModifier,
            competenceModifier: competenceModifier,
            finalPercent: finalPercent,
            scPower: mode.standingCommitteePower
        )
    }

    private func getRelationshipModifier(relationship: HeirRelationship) -> Int {
        switch relationship {
        case .child:
            return 15
        case .protege:
            return 10
        case .ally:
            return 0
        case .lieutenant:
            return -5
        }
    }

    // MARK: - Heir Eligibility

    /// Determine if an heir is eligible under current succession law
    func isHeirEligible(
        heir: GameCharacter,
        isFamily: Bool,
        game: Game
    ) -> HeirEligibility {
        let mode = getCurrentMode(game: game)

        // Check basic requirements
        guard heir.isAlive && heir.isActive else {
            return HeirEligibility(
                isEligible: false,
                reason: "\(heir.name) is not available.",
                requiresSCApproval: false
            )
        }

        // Mode-specific eligibility
        switch mode {
        case .collectiveDecision:
            // Anyone can be nominated, but SC must approve
            return HeirEligibility(
                isEligible: true,
                reason: "Subject to Standing Committee approval.",
                requiresSCApproval: true
            )

        case .designatedSuccessor:
            // Player's designated heir, SC confirms
            return HeirEligibility(
                isEligible: true,
                reason: "Your designated successor requires Standing Committee confirmation.",
                requiresSCApproval: true
            )

        case .familyPrivilege:
            if isFamily {
                // Family gets automatic eligibility
                return HeirEligibility(
                    isEligible: true,
                    reason: "Family members receive priority under current succession law.",
                    requiresSCApproval: false
                )
            } else {
                // Non-family can only succeed if no family available
                return HeirEligibility(
                    isEligible: true,
                    reason: "Non-family successors considered only if no family heir is available.",
                    requiresSCApproval: true
                )
            }

        case .partyElection:
            // Must meet position requirements
            if let posIndex = heir.positionIndex, posIndex >= 4 {
                return HeirEligibility(
                    isEligible: true,
                    reason: "Eligible for Party election (senior position held).",
                    requiresSCApproval: true
                )
            } else {
                return HeirEligibility(
                    isEligible: false,
                    reason: "Must hold senior position (Level 4+) to be eligible for Party election.",
                    requiresSCApproval: false
                )
            }

        case .revolutionaryContinuity:
            // Leader's choice stands without approval
            return HeirEligibility(
                isEligible: true,
                reason: "Your designated successor will take power automatically.",
                requiresSCApproval: false
            )
        }
    }

    // MARK: - Position Inheritance

    /// Determine what position the heir starts at based on law and predecessor's end
    func calculateStartingPosition(
        predecessorPosition: Int,
        predecessorEnd: PredecessorEndType,
        mode: SuccessionMode
    ) -> PositionInheritance {
        var positionModifier: Int = 0
        var explanation: String = ""

        // Modifier based on how predecessor ended
        switch predecessorEnd {
        case .naturalDeath:
            positionModifier = 0
            explanation = "Natural succession - position maintained."
        case .retiredGracefully:
            positionModifier = 0
            explanation = "Orderly transition - position maintained."
        case .purged:
            positionModifier = -2
            explanation = "Predecessor was purged - heir starts lower to prove loyalty."
        case .executed:
            positionModifier = -3
            explanation = "Predecessor was executed - family is under suspicion."
        case .posthumouslyRehabilitated:
            positionModifier = 1
            explanation = "Predecessor rehabilitated - heir elevated in restoration."
        case .assassinated:
            positionModifier = -1
            explanation = "Predecessor assassinated - uncertain circumstances."
        case .coupVictim:
            positionModifier = -2
            explanation = "Regime change - new authorities set position."
        }

        // Law modifier
        switch mode {
        case .familyPrivilege:
            positionModifier += 1  // Family privilege helps position
        case .partyElection:
            positionModifier -= 1  // Competition may lower starting position
        default:
            break
        }

        let finalPosition = max(0, min(8, predecessorPosition + positionModifier))

        return PositionInheritance(
            predecessorPosition: predecessorPosition,
            positionModifier: positionModifier,
            finalPosition: finalPosition,
            explanation: explanation
        )
    }
}

// MARK: - Supporting Structs

struct InheritanceResult {
    let mode: SuccessionMode
    let basePercent: Int
    let relationshipModifier: Int
    let familyModifier: Int
    let competenceModifier: Int
    let finalPercent: Int
    let scPower: SCSuccessionPower
}

struct HeirEligibility {
    let isEligible: Bool
    let reason: String
    let requiresSCApproval: Bool
}

struct PositionInheritance {
    let predecessorPosition: Int
    let positionModifier: Int
    let finalPosition: Int
    let explanation: String
}

enum PredecessorEndType: String, Codable {
    case naturalDeath
    case retiredGracefully
    case purged
    case executed
    case posthumouslyRehabilitated
    case assassinated
    case coupVictim
}

// MARK: - Heir Relationship

enum HeirRelationship: String, Codable, CaseIterable {
    case child           // Family member - highest inheritance
    case protege         // Political protege - good inheritance
    case ally            // Trusted ally - moderate inheritance
    case lieutenant      // Loyal subordinate - lower inheritance

    var inheritanceMultiplier: Double {
        switch self {
        case .child: return 0.75        // Inherits 75% of standing/network
        case .protege: return 0.60      // Inherits 60%
        case .ally: return 0.45         // Inherits 45%
        case .lieutenant: return 0.30   // Inherits 30%
        }
    }

    var displayName: String {
        switch self {
        case .child: return "Family Member"
        case .protege: return "Political Protege"
        case .ally: return "Trusted Ally"
        case .lieutenant: return "Loyal Lieutenant"
        }
    }

    var description: String {
        switch self {
        case .child:
            return "Blood ties ensure the strongest inheritance of your political capital"
        case .protege:
            return "Years of mentorship create a natural successor"
        case .ally:
            return "A proven ally can continue your work, though some connections will be lost"
        case .lieutenant:
            return "A loyal subordinate can pick up the mantle, but must rebuild much"
        }
    }

    /// Whether this relationship type qualifies as "family" for succession law purposes
    var isFamily: Bool {
        self == .child
    }
}
