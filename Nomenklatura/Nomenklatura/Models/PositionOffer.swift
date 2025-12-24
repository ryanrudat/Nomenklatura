//
//  PositionOffer.swift
//  Nomenklatura
//
//  Position offers from patrons - players don't choose promotions, they're offered them
//

import Foundation
import SwiftData

// MARK: - Offer Reason

enum OfferReason: String, Codable, CaseIterable {
    case affinityMatch          // Player's track affinity matches position
    case patronReward           // Patron rewarding loyal service
    case vacancyNeed            // Position is empty and needs filling
    case testOfLoyalty          // Patron testing if player will accept difficult post
    case factionalManeuver      // Faction wants their person in position
    case demotion               // Punishment assignment (lateral or down)
    case emergencyAppointment   // Crisis requires immediate placement
    case grooming               // Being prepared for higher office

    var displayName: String {
        switch self {
        case .affinityMatch: return "Track Expertise"
        case .patronReward: return "Patron's Favor"
        case .vacancyNeed: return "Vacancy"
        case .testOfLoyalty: return "Test of Loyalty"
        case .factionalManeuver: return "Factional Support"
        case .demotion: return "Reassignment"
        case .emergencyAppointment: return "Emergency Appointment"
        case .grooming: return "Career Development"
        }
    }

    var description: String {
        switch self {
        case .affinityMatch:
            return "Your demonstrated expertise in this area has been noticed."
        case .patronReward:
            return "Your patron wishes to advance your career."
        case .vacancyNeed:
            return "The position is vacant and must be filled."
        case .testOfLoyalty:
            return "This assignment will test your commitment to the cause."
        case .factionalManeuver:
            return "Powerful interests have aligned behind your candidacy."
        case .demotion:
            return "A change of assignment has been deemed appropriate."
        case .emergencyAppointment:
            return "Urgent circumstances require your immediate placement."
        case .grooming:
            return "You are being prepared for greater responsibilities."
        }
    }

    /// Is this offer one that the player should be wary of?
    var isRisky: Bool {
        switch self {
        case .testOfLoyalty, .demotion, .emergencyAppointment:
            return true
        default:
            return false
        }
    }
}

// MARK: - Offer Status

enum OfferStatus: String, Codable, CaseIterable {
    case pending            // Awaiting player decision
    case accepted           // Player accepted
    case declined           // Player declined
    case expired            // Offer timed out
    case withdrawn          // Patron withdrew offer
    case considering        // Player asked for time (delays response)

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .expired: return "Expired"
        case .withdrawn: return "Withdrawn"
        case .considering: return "Under Consideration"
        }
    }
}

// MARK: - Stat Effect

struct OfferStatEffect: Codable {
    var stat: String        // Stat identifier
    var amount: Int         // Change amount (positive or negative)
    var description: String // Why this effect occurs

    static func standing(_ amount: Int, reason: String) -> OfferStatEffect {
        OfferStatEffect(stat: "standing", amount: amount, description: reason)
    }

    static func patronFavor(_ amount: Int, reason: String) -> OfferStatEffect {
        OfferStatEffect(stat: "patronFavor", amount: amount, description: reason)
    }

    static func factionRelation(_ faction: String, _ amount: Int, reason: String) -> OfferStatEffect {
        OfferStatEffect(stat: "faction_\(faction)", amount: amount, description: reason)
    }
}

// MARK: - Position Offer Model

@Model
final class PositionOffer {
    @Attribute(.unique) var id: UUID
    var offerId: String                     // Unique identifier

    // The offer
    var positionId: String                  // Which position is being offered
    var positionName: String                // Display name
    var positionTier: Int                   // Tier level (1-8)
    var trackId: String                     // ExpandedCareerTrack.rawValue

    // Who is offering
    var patronCharacterId: String?          // Character making the offer
    var patronName: String                  // Display name
    var patronTitle: String                 // Their position

    // Context
    var reason: String                      // OfferReason.rawValue
    var offerStatus: String                 // OfferStatus.rawValue
    var turnOffered: Int                    // When offer was made
    var turnsToDecide: Int                  // Turns before expiration
    var turnExpires: Int                    // Calculated expiration turn

    // Narrative
    var briefingText: String                // Detailed description of opportunity
    var patronQuote: String?                // What the patron says

    // Effects (encoded)
    var acceptEffectsData: Data?            // Effects if accepted
    var declineEffectsData: Data?           // Effects if declined

    // Metadata
    var isPromotional: Bool                 // True if higher tier than current
    var isLateral: Bool                     // Same tier, different track
    var previousHolderId: String?           // Who held position before
    var previousHolderFate: String?         // What happened to them
    var hasBeenPresented: Bool = false      // Whether offer has been shown to player as event

    var game: Game?

    init(positionId: String, positionName: String, tier: Int, track: ExpandedCareerTrack) {
        self.id = UUID()
        self.offerId = UUID().uuidString

        self.positionId = positionId
        self.positionName = positionName
        self.positionTier = tier
        self.trackId = track.rawValue

        self.patronName = ""
        self.patronTitle = ""

        self.reason = OfferReason.vacancyNeed.rawValue
        self.offerStatus = OfferStatus.pending.rawValue
        self.turnOffered = 0
        self.turnsToDecide = 4
        self.turnExpires = 4

        self.briefingText = ""
        self.isPromotional = true
        self.isLateral = false
    }

    // MARK: - Computed Properties

    var track: ExpandedCareerTrack {
        ExpandedCareerTrack(rawValue: trackId) ?? .shared
    }

    var offerReason: OfferReason {
        get { OfferReason(rawValue: reason) ?? .vacancyNeed }
        set { reason = newValue.rawValue }
    }

    var status: OfferStatus {
        get { OfferStatus(rawValue: offerStatus) ?? .pending }
        set { offerStatus = newValue.rawValue }
    }

    var acceptEffects: [OfferStatEffect] {
        get {
            guard let data = acceptEffectsData else { return [] }
            return (try? JSONDecoder().decode([OfferStatEffect].self, from: data)) ?? []
        }
        set {
            acceptEffectsData = try? JSONEncoder().encode(newValue)
        }
    }

    var declineEffects: [OfferStatEffect] {
        get {
            guard let data = declineEffectsData else { return [] }
            return (try? JSONDecoder().decode([OfferStatEffect].self, from: data)) ?? []
        }
        set {
            declineEffectsData = try? JSONEncoder().encode(newValue)
        }
    }

    var isPending: Bool {
        status == .pending || status == .considering
    }

    var turnsRemaining: Int {
        max(0, turnExpires - turnOffered)
    }

    var isUrgent: Bool {
        turnsRemaining <= 1
    }

    /// Summary of what happens on acceptance
    var acceptSummary: String {
        var parts: [String] = []
        if isPromotional {
            parts.append("Promotion to Tier \(positionTier)")
        } else if isLateral {
            parts.append("Lateral move to \(track.displayName) track")
        }
        for effect in acceptEffects where effect.amount != 0 {
            let sign = effect.amount > 0 ? "+" : ""
            parts.append("\(sign)\(effect.amount) \(effect.stat)")
        }
        return parts.joined(separator: ", ")
    }

    /// Summary of what happens on decline
    var declineSummary: String {
        if declineEffects.isEmpty {
            return "No immediate consequences"
        }
        var parts: [String] = []
        for effect in declineEffects where effect.amount != 0 {
            let sign = effect.amount > 0 ? "+" : ""
            parts.append("\(sign)\(effect.amount) \(effect.stat)")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Methods

    func accept(on turn: Int) {
        status = .accepted
    }

    func decline(on turn: Int) {
        status = .declined
    }

    func requestTime(on turn: Int, extraTurns: Int = 2) {
        status = .considering
        turnExpires += extraTurns
    }

    func checkExpiration(currentTurn: Int) {
        if currentTurn >= turnExpires && isPending {
            status = .expired
        }
    }

    func withdraw() {
        status = .withdrawn
    }

    func addAcceptEffect(_ effect: OfferStatEffect) {
        var effects = acceptEffects
        effects.append(effect)
        acceptEffects = effects
    }

    func addDeclineEffect(_ effect: OfferStatEffect) {
        var effects = declineEffects
        effects.append(effect)
        declineEffects = effects
    }
}

// MARK: - Position Offer Templates

extension PositionOffer {

    /// Create a promotion offer from a patron
    static func createPromotionOffer(
        positionId: String,
        positionName: String,
        tier: Int,
        track: ExpandedCareerTrack,
        patronName: String,
        patronTitle: String,
        reason: OfferReason,
        currentTurn: Int
    ) -> PositionOffer {
        let offer = PositionOffer(
            positionId: positionId,
            positionName: positionName,
            tier: tier,
            track: track
        )

        offer.patronName = patronName
        offer.patronTitle = patronTitle
        offer.offerReason = reason
        offer.turnOffered = currentTurn
        offer.turnExpires = currentTurn + offer.turnsToDecide
        offer.isPromotional = true
        offer.isLateral = false

        // Generate briefing based on reason
        offer.briefingText = generateBriefing(for: offer)

        // Default effects
        offer.addAcceptEffect(.standing(5, reason: "Career advancement"))
        offer.addAcceptEffect(.patronFavor(10, reason: "Accepted patron's offer"))

        offer.addDeclineEffect(.patronFavor(-15, reason: "Declined patron's offer"))

        return offer
    }

    /// Create a lateral move offer (same tier, different track)
    static func createLateralOffer(
        positionId: String,
        positionName: String,
        tier: Int,
        track: ExpandedCareerTrack,
        patronName: String,
        patronTitle: String,
        reason: OfferReason,
        currentTurn: Int
    ) -> PositionOffer {
        let offer = PositionOffer(
            positionId: positionId,
            positionName: positionName,
            tier: tier,
            track: track
        )

        offer.patronName = patronName
        offer.patronTitle = patronTitle
        offer.offerReason = reason
        offer.turnOffered = currentTurn
        offer.turnExpires = currentTurn + offer.turnsToDecide
        offer.isPromotional = false
        offer.isLateral = true

        offer.briefingText = generateBriefing(for: offer)

        // Lateral moves have lower stakes
        offer.addAcceptEffect(.standing(2, reason: "New assignment"))
        offer.addDeclineEffect(.patronFavor(-5, reason: "Preference noted"))

        return offer
    }

    /// Create a risky assignment offer (test of loyalty, difficult post)
    static func createRiskyOffer(
        positionId: String,
        positionName: String,
        tier: Int,
        track: ExpandedCareerTrack,
        patronName: String,
        patronTitle: String,
        reason: OfferReason,
        currentTurn: Int,
        riskDescription: String
    ) -> PositionOffer {
        let offer = PositionOffer(
            positionId: positionId,
            positionName: positionName,
            tier: tier,
            track: track
        )

        offer.patronName = patronName
        offer.patronTitle = patronTitle
        offer.offerReason = reason
        offer.turnOffered = currentTurn
        offer.turnsToDecide = 2 // Less time to decide
        offer.turnExpires = currentTurn + 2
        offer.isPromotional = tier > 0 // Might be lateral

        offer.briefingText = """
            \(generateBriefing(for: offer))

            WARNING: \(riskDescription)
            """

        // High risk, high reward
        offer.addAcceptEffect(.standing(10, reason: "Willingness to serve where needed"))
        offer.addAcceptEffect(.patronFavor(20, reason: "Demonstrated loyalty"))

        // Declining risky assignments is remembered
        offer.addDeclineEffect(.standing(-5, reason: "Avoided difficult assignment"))
        offer.addDeclineEffect(.patronFavor(-25, reason: "Failed test of loyalty"))

        return offer
    }

    private static func generateBriefing(for offer: PositionOffer) -> String {
        let trackName = offer.track.displayName
        let tierDesc = tierDescription(offer.positionTier)

        switch offer.offerReason {
        case .affinityMatch:
            return """
                Your work in the \(trackName) sphere has been noticed by those who matter. \
                The position of \(offer.positionName) requires someone with your particular expertise. \
                This is a \(tierDesc) assignment that would formalize your specialization.
                """

        case .patronReward:
            return """
                \(offer.patronName) has decided to advance your career. The position of \(offer.positionName) \
                opens new doors in the \(trackName) apparatus. Accept, and you demonstrate worthy loyalty. \
                Decline, and your patron may reconsider their investment in your future.
                """

        case .vacancyNeed:
            return """
                The position of \(offer.positionName) has become vacant and must be filled promptly. \
                The \(trackName) apparatus requires stable leadership. Your name has been put forward \
                as a suitable candidate for this \(tierDesc) position.
                """

        case .testOfLoyalty:
            return """
                \(offer.patronName) wishes to test your commitment. The position of \(offer.positionName) \
                is not a prize—it is a challenge. Success here will prove your worth; failure \
                or refusal will be noted. The Party observes how cadres respond to difficult assignments.
                """

        case .factionalManeuver:
            return """
                Powerful interests within the \(trackName) sphere have aligned behind your candidacy \
                for \(offer.positionName). This support comes with expectations. Acceptance binds you \
                to certain obligations; decline may create enemies among those who championed you.
                """

        case .demotion:
            return """
                A reassignment has been deemed appropriate. The position of \(offer.positionName) \
                offers an opportunity to demonstrate renewed commitment to socialist construction. \
                The Party values those who accept correction with proper attitude.
                """

        case .emergencyAppointment:
            return """
                Urgent circumstances require your immediate placement as \(offer.positionName). \
                The previous holder has been... removed. The \(trackName) apparatus cannot function \
                without leadership. There is no time for deliberation; the state requires your answer.
                """

        case .grooming:
            return """
                You are being prepared for greater responsibilities. The position of \(offer.positionName) \
                is a stepping stone to higher office. \(offer.patronName) sees potential in you that \
                must be developed through experience in the \(trackName) apparatus.
                """
        }
    }

    private static func tierDescription(_ tier: Int) -> String {
        switch tier {
        case 1: return "entry-level"
        case 2: return "junior"
        case 3: return "mid-level"
        case 4: return "senior"
        case 5: return "departmental"
        case 6: return "ministry-level"
        case 7: return "elite"
        case 8: return "apex"
        default: return "standard"
        }
    }
}

// MARK: - Offer Response Options

enum OfferResponseOption: String, Codable, CaseIterable {
    case accept             // Accept immediately
    case decline            // Decline immediately
    case requestTime        // Ask for more time to decide
    case negotiateTerms     // Try to improve the offer (risky)

    var displayName: String {
        switch self {
        case .accept: return "Accept"
        case .decline: return "Decline"
        case .requestTime: return "Request Time"
        case .negotiateTerms: return "Negotiate"
        }
    }

    var description: String {
        switch self {
        case .accept:
            return "Accept the position and begin your new duties"
        case .decline:
            return "Decline the offer with appropriate gratitude"
        case .requestTime:
            return "Ask for additional time to consider the offer"
        case .negotiateTerms:
            return "Attempt to improve the terms of the offer (may offend)"
        }
    }
}
