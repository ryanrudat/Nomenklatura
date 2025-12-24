//
//  PositionHistoryService.swift
//  Nomenklatura
//
//  Service for tracking position changes and maintaining historical records
//

import Foundation
import SwiftData

/// Service for managing position history tracking
final class PositionHistoryService {
    static let shared = PositionHistoryService()

    private init() {}

    // MARK: - Player Position Tracking

    /// Record the player taking a new position
    func recordPlayerPromotion(
        game: Game,
        toPositionIndex: Int,
        positionTitle: String,
        track: CareerTrack = .shared
    ) {
        // End any current player position record
        endCurrentPlayerPosition(game: game, reason: .promoted)

        // Create new position record
        let holder = PositionHolder(
            characterId: nil,  // Player doesn't have a character ID
            characterName: "You",
            characterTitle: positionTitle,
            positionIndex: toPositionIndex,
            positionTrack: track.rawValue,
            turnStarted: game.turnNumber,
            wasPlayer: true
        )
        holder.game = game
        game.positionHistory.append(holder)
    }

    /// Record the player's position ending (demotion, arrest, etc.)
    func recordPlayerPositionEnd(
        game: Game,
        reason: PositionEndReason
    ) {
        endCurrentPlayerPosition(game: game, reason: reason)
    }

    // MARK: - NPC Position Tracking

    /// Record an NPC taking a position
    func recordNPCPromotion(
        game: Game,
        character: GameCharacter,
        toPositionIndex: Int,
        positionTitle: String,
        track: CareerTrack = .shared
    ) {
        // End any current position for this character
        endCurrentNPCPosition(game: game, characterId: character.id, reason: .promoted)

        // Create new position record
        let holder = PositionHolder(
            characterId: character.id,
            characterName: character.name,
            characterTitle: positionTitle,
            positionIndex: toPositionIndex,
            positionTrack: track.rawValue,
            turnStarted: game.turnNumber,
            wasPlayer: false
        )
        holder.game = game
        game.positionHistory.append(holder)
    }

    /// Record an NPC's position ending
    func recordNPCPositionEnd(
        game: Game,
        character: GameCharacter,
        reason: PositionEndReason
    ) {
        endCurrentNPCPosition(game: game, characterId: character.id, reason: reason)
    }

    /// Record an NPC being purged/removed from their position
    func recordNPCPurge(
        game: Game,
        character: GameCharacter
    ) {
        endCurrentNPCPosition(game: game, characterId: character.id, reason: .purged)
    }

    /// Record an NPC death
    func recordNPCDeath(
        game: Game,
        character: GameCharacter,
        wasExecuted: Bool = false
    ) {
        let reason: PositionEndReason = wasExecuted ? .executed : .died
        endCurrentNPCPosition(game: game, characterId: character.id, reason: reason)
    }

    // MARK: - Game Initialization

    /// Initialize position history at game start
    /// Records the starting positions of all characters
    func initializePositionHistory(game: Game, ladder: [LadderPosition]) {
        // Record player's starting position
        if let playerPosition = ladder.first(where: { $0.index == game.currentPositionIndex }) {
            let playerHolder = PositionHolder(
                characterId: nil,
                characterName: "You",
                characterTitle: playerPosition.title,
                positionIndex: game.currentPositionIndex,
                positionTrack: playerPosition.expandedTrack.rawValue,
                turnStarted: 1,
                wasPlayer: true
            )
            playerHolder.game = game
            game.positionHistory.append(playerHolder)
        }

        // Record starting positions for all NPCs
        // Find the best matching position for each character based on their positionIndex and title
        for character in game.characters {
            guard let posIndex = character.positionIndex else { continue }

            // Find matching position - preferring exact title match when multiple positions exist at same index
            let matchingPosition = findBestMatchingPosition(
                for: character,
                atIndex: posIndex,
                in: ladder
            )

            if let position = matchingPosition {
                // Update character's track if not already set
                if character.positionTrack == nil {
                    character.positionTrack = position.expandedTrack.rawValue
                }

                let holder = PositionHolder(
                    characterId: character.id,
                    characterName: character.name,
                    characterTitle: character.title ?? position.title,
                    positionIndex: posIndex,
                    positionTrack: position.expandedTrack.rawValue,
                    turnStarted: 1,
                    wasPlayer: false
                )
                holder.game = game
                game.positionHistory.append(holder)
            }
        }
    }

    /// Find the best matching ladder position for a character
    /// Multiple positions can exist at the same index across different tracks
    private func findBestMatchingPosition(
        for character: GameCharacter,
        atIndex posIndex: Int,
        in ladder: [LadderPosition]
    ) -> LadderPosition? {
        // Get all positions at this index
        let positionsAtIndex = ladder.filter { $0.index == posIndex }

        // If only one position at this index, use it
        if positionsAtIndex.count == 1 {
            return positionsAtIndex.first
        }

        // PRIORITY 1: Use explicit positionTrack if specified
        if let trackString = character.positionTrack,
           let track = ExpandedCareerTrack(rawValue: trackString),
           let matchedPosition = positionsAtIndex.first(where: { $0.expandedTrack == track }) {
            return matchedPosition
        }

        // Try to match by title similarity
        if let charTitle = character.title {
            let titleLower = charTitle.lowercased()

            // Direct title match
            if let exactMatch = positionsAtIndex.first(where: { $0.title.lowercased() == titleLower }) {
                return exactMatch
            }

            // Partial title match based on key words
            for position in positionsAtIndex {
                let positionTitleLower = position.title.lowercased()

                // Check for track-specific keywords in character title
                if titleLower.contains("security") || titleLower.contains("protection") || titleLower.contains("investigator") {
                    if position.expandedTrack == .securityServices {
                        return position
                    }
                }
                if titleLower.contains("ambassador") || titleLower.contains("foreign") || titleLower.contains("diplomatic") || titleLower.contains("counselor") {
                    if position.expandedTrack == .foreignAffairs {
                        return position
                    }
                }
                if titleLower.contains("planning") || titleLower.contains("economist") || titleLower.contains("gosplan") {
                    if position.expandedTrack == .economicPlanning {
                        return position
                    }
                }
                if titleLower.contains("political") || titleLower.contains("commissar") || titleLower.contains("directorate") {
                    if position.expandedTrack == .militaryPolitical {
                        return position
                    }
                }
                if titleLower.contains("minister") || titleLower.contains("industry") || titleLower.contains("council") {
                    if position.expandedTrack == .stateMinistry {
                        return position
                    }
                }
                if titleLower.contains("secretary") || titleLower.contains("central committee") || titleLower.contains("instructor") {
                    if position.expandedTrack == .partyApparatus {
                        return position
                    }
                }
                if titleLower.contains("republic") || titleLower.contains("provincial") {
                    if position.expandedTrack == .regional {
                        return position
                    }
                }

                // Check for partial title overlap
                if positionTitleLower.contains(titleLower) || titleLower.contains(positionTitleLower) {
                    return position
                }
            }
        }

        // Match by faction if available (player factions mapped to career tracks)
        if let factionId = character.factionId {
            for position in positionsAtIndex {
                switch factionId {
                case "old_guard":
                    // Ideological guardians dominate security services
                    if position.expandedTrack == .securityServices { return position }
                case "princelings":
                    // Red aristocracy has military ties
                    if position.expandedTrack == .militaryPolitical { return position }
                case "reformists":
                    // Pragmatists lead economic planning and state ministries
                    if position.expandedTrack == .economicPlanning || position.expandedTrack == .stateMinistry { return position }
                case "youth_league":
                    // Meritocrats dominate party apparatus and foreign affairs
                    if position.expandedTrack == .partyApparatus || position.expandedTrack == .foreignAffairs { return position }
                case "regional":
                    // Provincial networks control regional positions
                    if position.expandedTrack == .regional { return position }
                default:
                    break
                }
            }
        }

        // Fallback to shared track if available, otherwise first position at index
        return positionsAtIndex.first(where: { $0.expandedTrack == .shared }) ?? positionsAtIndex.first
    }

    // MARK: - Private Helpers

    private func endCurrentPlayerPosition(game: Game, reason: PositionEndReason) {
        if let currentRecord = game.positionHistory.first(where: { $0.wasPlayer && $0.isCurrent }) {
            currentRecord.endTenure(turn: game.turnNumber, reason: reason)
        }
    }

    private func endCurrentNPCPosition(game: Game, characterId: UUID, reason: PositionEndReason) {
        if let currentRecord = game.positionHistory.first(where: {
            $0.characterId == characterId && $0.isCurrent
        }) {
            currentRecord.endTenure(turn: game.turnNumber, reason: reason)
        }
    }

    // MARK: - Query Helpers

    /// Get all holders of a specific position (current and past)
    func getPositionHolders(game: Game, positionIndex: Int) -> [PositionHolder] {
        game.positionHistory
            .filter { $0.positionIndex == positionIndex }
            .sorted { ($0.turnEnded ?? Int.max) > ($1.turnEnded ?? Int.max) }
    }

    /// Get the current holder of a position (if any)
    func getCurrentHolder(game: Game, positionIndex: Int) -> PositionHolder? {
        game.positionHistory.first {
            $0.positionIndex == positionIndex && $0.isCurrent
        }
    }

    /// Get a character's position history
    func getCharacterPositionHistory(game: Game, characterId: UUID) -> [PositionHolder] {
        game.positionHistory
            .filter { $0.characterId == characterId }
            .sorted { $0.turnStarted > $1.turnStarted }
    }

    /// Get the player's position history
    func getPlayerPositionHistory(game: Game) -> [PositionHolder] {
        game.positionHistory
            .filter { $0.wasPlayer }
            .sorted { $0.turnStarted > $1.turnStarted }
    }
}
