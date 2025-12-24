//
//  PositionOfferService.swift
//  Nomenklatura
//
//  Service for generating and managing position offers from patrons
//

import Foundation

// MARK: - Position Offer Service

class PositionOfferService {

    static let shared = PositionOfferService()

    private init() {}

    // MARK: - Offer Generation

    /// Generate potential position offers based on game state
    func generateOffers(for game: Game, config: CampaignConfig) -> [PositionOffer] {
        var offers: [PositionOffer] = []

        // Don't generate offers if player is at the top
        guard game.currentPositionIndex < 8 else { return [] }

        let scores = game.trackAffinityScores
        let currentTurn = game.turnNumber

        // Check each track for potential offers
        for track in ExpandedCareerTrack.allCases where track != .shared {
            if let offer = checkTrackForOffer(
                game: game,
                config: config,
                track: track,
                affinityScore: scores.score(for: track),
                currentTurn: currentTurn
            ) {
                offers.append(offer)
            }
        }

        // Also check for lateral moves based on patron desires
        if let lateralOffer = generatePatronLateralOffer(game: game, config: config, currentTurn: currentTurn) {
            offers.append(lateralOffer)
        }

        return offers
    }

    /// Check if a track should generate an offer
    private func checkTrackForOffer(
        game: Game,
        config: CampaignConfig,
        track: ExpandedCareerTrack,
        affinityScore: Int,
        currentTurn: Int
    ) -> PositionOffer? {

        // Find the next position up in this track
        let currentIndex = game.currentPositionIndex
        let nextIndex = currentIndex + 1

        guard let nextPosition = config.ladder.first(where: {
            $0.expandedTrack == track && $0.index == nextIndex
        }) else {
            return nil
        }

        // Check if player meets basic requirements
        guard game.standing >= nextPosition.requiredStanding else { return nil }

        // Check affinity threshold if required
        if let requiredAffinity = nextPosition.requiredAffinityScore {
            guard affinityScore >= requiredAffinity else { return nil }
        }

        // Determine offer reason based on conditions
        let reason = determineOfferReason(
            game: game,
            track: track,
            affinityScore: affinityScore,
            position: nextPosition
        )

        // Find a suitable patron for this track
        let (patronName, patronTitle) = findPatronForTrack(game: game, track: track)

        // Create the offer
        let offer = PositionOffer.createPromotionOffer(
            positionId: nextPosition.id,
            positionName: nextPosition.title,
            tier: nextPosition.index,
            track: track,
            patronName: patronName,
            patronTitle: patronTitle,
            reason: reason,
            currentTurn: currentTurn
        )

        return offer
    }

    /// Determine why the offer is being made
    private func determineOfferReason(
        game: Game,
        track: ExpandedCareerTrack,
        affinityScore: Int,
        position: LadderPosition
    ) -> OfferReason {

        // High affinity = recognized expertise
        if affinityScore >= 30 {
            return .affinityMatch
        }

        // High patron favor = patron rewarding loyalty
        if game.patronFavor >= 70 {
            return .patronReward
        }

        // Check for vacancies
        if game.variables["vacancy_\(position.id)"] != nil {
            return .vacancyNeed
        }

        // Low stability = emergency appointment
        if game.stability < 30 {
            return .emergencyAppointment
        }

        // Default to grooming/development
        return .grooming
    }

    /// Find appropriate patron for a track
    private func findPatronForTrack(game: Game, track: ExpandedCareerTrack) -> (name: String, title: String) {
        // Look for characters associated with this track
        // Maps career tracks to player factions that dominate them
        let trackFaction: String
        switch track {
        case .partyApparatus:
            trackFaction = "youth_league"   // Meritocrats dominate party apparatus
        case .securityServices:
            trackFaction = "old_guard"      // Ideological guardians control security
        case .militaryPolitical:
            trackFaction = "princelings"    // Red aristocracy has military ties
        case .economicPlanning, .stateMinistry:
            trackFaction = "reformists"     // Pragmatists lead economic planning
        case .foreignAffairs:
            trackFaction = "reformists"     // Pragmatists handle foreign affairs
        case .regional:
            trackFaction = "regional"       // Regional networks control provinces
        default:
            trackFaction = "youth_league"
        }

        // Find a character in this faction who could offer
        if let patron = game.characters.first(where: {
            $0.factionId == trackFaction &&
            $0.status == CharacterStatus.active.rawValue &&
            $0.positionIndex ?? 0 > game.currentPositionIndex
        }) {
            return (patron.name, patron.title ?? "Official")
        }

        // Fallback to player's patron if they have one
        if let patron = game.patron {
            return (patron.name, patron.title ?? "Party Member")
        }

        // Default generic patron
        return ("The Central Committee", "Party Leadership")
    }

    /// Generate a lateral move offer from patron
    private func generatePatronLateralOffer(
        game: Game,
        config: CampaignConfig,
        currentTurn: Int
    ) -> PositionOffer? {

        // Only offer laterals if patron favor is moderate and player hasn't committed
        guard game.patronFavor >= 50,
              game.patronFavor < 80,
              game.currentTrackCommitment != .committed else {
            return nil
        }

        let scores = game.trackAffinityScores

        // Find a track the player hasn't explored much
        let lowAffinityTracks = ExpandedCareerTrack.allCases.filter {
            $0 != .shared && $0 != .regional && scores.score(for: $0) < 10
        }

        guard let targetTrack = lowAffinityTracks.randomElement() else {
            return nil
        }

        // Find position at current tier in target track
        guard let targetPosition = config.ladder.first(where: {
            $0.expandedTrack == targetTrack && $0.index == game.currentPositionIndex
        }) else {
            return nil
        }

        let (patronName, patronTitle) = findPatronForTrack(game: game, track: targetTrack)

        return PositionOffer.createLateralOffer(
            positionId: targetPosition.id,
            positionName: targetPosition.title,
            tier: targetPosition.index,
            track: targetTrack,
            patronName: patronName,
            patronTitle: patronTitle,
            reason: .testOfLoyalty,
            currentTurn: currentTurn
        )
    }

    // MARK: - Offer Evaluation

    /// Evaluate whether player should receive offers this turn
    func shouldGenerateOffers(game: Game) -> Bool {
        // Already have pending offers
        if game.hasPendingOffers {
            return false
        }

        // Minimum position requirement
        if game.currentPositionIndex < 1 {
            return false
        }

        // Cooldown between offers (every 4 turns minimum)
        if let lastOfferTurn = game.variables["last_offer_turn"],
           let turn = Int(lastOfferTurn),
           game.turnNumber - turn < 4 {
            return false
        }

        // Random chance based on standing and favor
        let offerChance = (game.standing + game.patronFavor) / 4
        return Int.random(in: 1...100) <= offerChance
    }

    // MARK: - Offer Processing

    /// Process player accepting an offer
    func acceptOffer(_ offer: PositionOffer, game: Game, config: CampaignConfig) {
        offer.accept(on: game.turnNumber)

        // Apply position change
        if let position = config.ladder.first(where: { $0.id == offer.positionId }) {
            game.currentPositionIndex = position.index
            game.currentTrack = position.track.rawValue
            game.currentExpandedTrack = position.expandedTrack.rawValue  // Update specialized track
            game.turnsInCurrentPosition = 0

            // If it's a specialized track, add affinity and commit
            if position.expandedTrack != .shared {
                game.addTrackAffinity(
                    track: position.expandedTrack,
                    amount: 10,
                    source: .positionHeld,
                    description: "Appointed to \(position.title)"
                )

                // Commit to track when accepting a specialized position
                if game.currentTrackCommitment != .committed {
                    game.commitToTrack(position.expandedTrack)
                }
            }

            // Check for apex position
            if position.isApexPosition {
                game.recordApexPosition(track: position.expandedTrack)
            }
        }

        // Apply stat effects
        for effect in offer.acceptEffects {
            game.applyStat(effect.stat, change: effect.amount)
        }

        // Record offer accepted
        game.variables["last_offer_turn"] = String(game.turnNumber)
        game.flags.append("accepted_\(offer.offerId)")
        game.updatedAt = Date()
    }

    /// Process player declining an offer
    func declineOffer(_ offer: PositionOffer, game: Game) {
        offer.decline(on: game.turnNumber)

        // Apply decline effects
        for effect in offer.declineEffects {
            game.applyStat(effect.stat, change: effect.amount)
        }

        // Record offer declined
        game.variables["last_offer_turn"] = String(game.turnNumber)
        game.flags.append("declined_\(offer.offerId)")

        // Patron remembers
        if offer.offerReason == .patronReward || offer.offerReason == .testOfLoyalty {
            game.flags.append("disappointed_patron_\(game.turnNumber)")
        }

        game.updatedAt = Date()
    }

    /// Process player requesting more time
    func requestTimeForOffer(_ offer: PositionOffer, game: Game) {
        offer.requestTime(on: game.turnNumber)

        // Small penalty for indecision
        game.applyStat("patronFavor", change: -2)

        game.updatedAt = Date()
    }

    // MARK: - Turn Processing

    /// Process all offers at end of turn
    func processTurn(game: Game) {
        // Check for expired offers
        game.processOfferExpirations()

        // Handle expired offers
        for offer in game.positionOffers where offer.status == .expired {
            // Expired offers have consequences
            game.applyStat("patronFavor", change: -10)
            game.flags.append("expired_offer_\(offer.offerId)")
        }

        // Maybe generate new offers
        if shouldGenerateOffers(game: game) {
            let config = CampaignLoader.shared.getColdWarCampaign()
            let newOffers = generateOffers(for: game, config: config)

            for offer in newOffers {
                game.addPositionOffer(offer)
            }
        }
    }
}

// MARK: - Offer Presentation

extension PositionOfferService {

    /// Create a DynamicEvent to present an offer
    func createOfferEvent(for offer: PositionOffer, currentTurn: Int) -> DynamicEvent {
        let responses = [
            EventResponse(
                id: "accept_\(offer.offerId)",
                text: "Accept the position",
                shortText: "Accept",
                effects: ["position_change": 1],
                riskLevel: .low,
                setsFlag: "accepted_offer_\(offer.offerId)"
            ),
            EventResponse(
                id: "decline_\(offer.offerId)",
                text: "Decline with appropriate gratitude",
                shortText: "Decline",
                effects: ["patronFavor": -15],
                riskLevel: .medium,
                setsFlag: "declined_offer_\(offer.offerId)"
            ),
            EventResponse(
                id: "consider_\(offer.offerId)",
                text: "Request time to consider",
                shortText: "Consider",
                effects: ["patronFavor": -2],
                riskLevel: .low
            )
        ]

        // Convert patronCharacterId string to UUID if available
        var relatedIds: [UUID]? = nil
        if let patronId = offer.patronCharacterId, let uuid = UUID(uuidString: patronId) {
            relatedIds = [uuid]
        }

        return DynamicEvent(
            eventType: .patronDirective,
            priority: offer.isUrgent ? .urgent : .elevated,
            title: "Position Offered: \(offer.positionName)",
            briefText: """
                \(offer.patronName) (\(offer.patronTitle)) has offered you a position as \(offer.positionName).

                \(offer.briefingText)
                """,
            relatedCharacterIds: relatedIds,
            turnGenerated: currentTurn,
            expiresOnTurn: currentTurn + offer.turnsRemaining,
            isUrgent: offer.isUrgent,
            responseOptions: responses,
            linkedDecisionId: "offer_\(offer.offerId)",
            callbackFlag: "offer_\(offer.offerId)_resolved",
            iconName: offer.track.iconName
        )
    }
}
