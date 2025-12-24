//
//  CharacterFateService.swift
//  Nomenklatura
//
//  Centralized service for handling character fate changes across all bureaus.
//  Includes death, dismissal, exile, imprisonment, and rehabilitation.
//
//  DeathCause enum is defined in NetworkContactSystem.swift
//

import Foundation
import SwiftData
import os.log

private let fateLogger = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "CharacterFate")

// MARK: - Dismissal Type

/// Types of dismissal from position
enum DismissalType: String, Codable, CaseIterable {
    case forcedResignation    // Made to resign "voluntarily"
    case removedForCause      // Officially removed for violations
    case demotedSeverely      // Major demotion (multiple levels)
    case transferredObscure   // Sent to unimportant post
    case retiredForced        // Forced into retirement
    case suspendedPending     // Suspended pending investigation
    case firedByPatron        // Patron threw them under bus
    case factionPurge         // Removed as part of faction purge
    case lossOfConfidence     // Leadership lost confidence

    var displayText: String {
        switch self {
        case .forcedResignation: return "Resigned"
        case .removedForCause: return "Removed for cause"
        case .demotedSeverely: return "Severely demoted"
        case .transferredObscure: return "Transferred"
        case .retiredForced: return "Retired"
        case .suspendedPending: return "Suspended"
        case .firedByPatron: return "Dismissed"
        case .factionPurge: return "Purged"
        case .lossOfConfidence: return "Removed"
        }
    }

    /// Newspaper-friendly description
    var officialDescription: String {
        switch self {
        case .forcedResignation: return "resigned to pursue other interests"
        case .removedForCause: return "removed following serious violations"
        case .demotedSeverely: return "reassigned to new responsibilities"
        case .transferredObscure: return "transferred to provincial assignment"
        case .retiredForced: return "retired for health reasons"
        case .suspendedPending: return "temporarily relieved of duties"
        case .firedByPatron: return "relieved of responsibilities"
        case .factionPurge: return "removed during organizational restructuring"
        case .lossOfConfidence: return "no longer serving in current capacity"
        }
    }

    /// Target CharacterStatus after dismissal
    var resultingStatus: CharacterStatus {
        switch self {
        case .retiredForced: return .retired
        case .suspendedPending: return .underInvestigation
        case .factionPurge: return .exiled
        default: return .active // They might stay active at lower position
        }
    }
}

// MARK: - Character Fate Service

/// Centralized service for handling character fate changes across all bureaus
final class CharacterFateService {
    static let shared = CharacterFateService()

    private init() {}

    // MARK: - Death

    /// Execute a character (permanent removal)
    func killCharacter(
        _ character: GameCharacter,
        cause: DeathCause,
        perpetrator: GameCharacter? = nil,
        game: Game,
        modelContext: ModelContext
    ) {
        // Cannot kill already dead characters
        guard character.isAlive else { return }

        // Set status based on cause
        switch cause {
        case .executed, .executionByPurge, .executionByMilitary, .purged:
            character.status = CharacterStatus.executed.rawValue
        case .disappeared:
            character.status = CharacterStatus.disappeared.rawValue
        case .arrested:
            character.status = CharacterStatus.detained.rawValue
        case .exiled:
            character.status = CharacterStatus.exiled.rawValue
        default:
            character.status = CharacterStatus.dead.rawValue
        }

        // Clear position
        let previousPosition = character.positionIndex
        let previousTrack = character.positionTrack
        character.positionIndex = nil
        character.positionTrack = nil
        character.isDetained = false

        // Mark position as vacant for promotion system
        if let position = previousPosition, let track = previousTrack {
            markPositionVacant(position: position, track: track, game: game)
        }

        // Record death details
        character.statusChangedTurn = game.turnNumber
        character.statusDetails = cause.displayText
        character.fateNarrative = generateDeathNarrative(
            character: character,
            cause: cause,
            perpetrator: perpetrator,
            previousPosition: previousPosition,
            previousTrack: previousTrack
        )

        // Add to game's fallen records
        recordDeath(
            character: character,
            cause: cause,
            perpetrator: perpetrator,
            game: game
        )

        // Generate effects on game state
        applyDeathEffects(
            character: character,
            cause: cause,
            game: game
        )
    }

    /// Generate narrative for death
    private func generateDeathNarrative(
        character: GameCharacter,
        cause: DeathCause,
        perpetrator: GameCharacter?,
        previousPosition: Int?,
        previousTrack: String?
    ) -> String {
        let perpetratorDesc = perpetrator.map { "on orders of \($0.name)" } ?? ""

        switch cause {
        case .executed:
            return "\(character.name) was executed \(perpetratorDesc) following conviction."
        case .executionByPurge, .purged:
            return "\(character.name) was swept away in the anti-corruption campaign \(perpetratorDesc)."
        case .executionByMilitary:
            return "\(character.name) faced a military tribunal and was summarily executed."
        case .heartAttack:
            return "\(character.name) suffered a fatal heart attack during questioning."
        case .suicide:
            return "\(character.name) reportedly took their own life while under investigation."
        case .carAccident, .accident:
            return "\(character.name) died in an accident. The circumstances remain unclear."
        case .planeAccident:
            return "\(character.name) perished when their aircraft went down en route to assignment."
        case .fallingAccident:
            return "\(character.name) fell from a window. Officials ruled it accidental."
        case .disappeared:
            return "\(character.name) vanished. No further information is available."
        case .resistingArrest:
            return "\(character.name) was shot while resisting arrest."
        case .arrested:
            return "\(character.name) has been arrested and is awaiting trial."
        case .exiled:
            return "\(character.name) has been exiled to a remote province."
        case .naturalCauses, .illness:
            return "\(character.name) has passed away from natural causes."
        }
    }

    /// Record death in game state
    private func recordDeath(
        character: GameCharacter,
        cause: DeathCause,
        perpetrator: GameCharacter?,
        game: Game
    ) {
        // Store death record in game variables
        var deaths = getDeathRecords(for: game)
        deaths.append(DeathRecord(
            characterId: character.id.uuidString,
            characterName: character.name,
            cause: cause,
            perpetratorId: perpetrator?.id.uuidString,
            perpetratorName: perpetrator?.name,
            turn: game.turnNumber,
            previousPosition: character.positionIndex ?? 0
        ))
        saveDeathRecords(deaths, for: game)
    }

    /// Apply game state effects from death
    private func applyDeathEffects(
        character: GameCharacter,
        cause: DeathCause,
        game: Game
    ) {
        let position = character.positionIndex ?? 0

        // High-profile deaths affect stability
        if position >= 5 {
            game.stability -= (cause.isOfficial ? 5 : 10)
        }

        // Executions create fear
        if cause.isOfficial {
            game.eliteLoyalty += 3 // Fear increases loyalty
            game.popularSupport -= 2 // But reduces popular support
        }

        // Suspicious deaths create unease
        if !cause.isOfficial && cause != .illness && cause != .naturalCauses {
            game.stability -= 3
            game.eliteLoyalty -= 2
        }
    }

    // MARK: - Dismissal

    /// Dismiss a character from their position
    func dismissCharacter(
        _ character: GameCharacter,
        dismissalType: DismissalType,
        perpetrator: GameCharacter? = nil,
        game: Game,
        modelContext: ModelContext
    ) {
        // Cannot dismiss non-active characters
        guard character.currentStatus == .active else { return }

        let previousPosition = character.positionIndex ?? 0
        let previousTrack = character.positionTrack ?? "unknown"

        // Apply dismissal based on type
        switch dismissalType {
        case .demotedSeverely:
            // Demote by 3 levels
            character.positionIndex = max(0, previousPosition - 3)

        case .transferredObscure:
            // Keep position level but mark as transferred
            character.positionTrack = "provincial"
            character.positionIndex = max(0, previousPosition - 1)

        case .retiredForced:
            character.status = CharacterStatus.retired.rawValue
            character.positionIndex = nil
            character.positionTrack = nil
            // Mark position as vacant
            markPositionVacant(position: previousPosition, track: previousTrack, game: game)

        case .suspendedPending:
            character.status = CharacterStatus.underInvestigation.rawValue

        case .factionPurge:
            character.status = CharacterStatus.exiled.rawValue
            character.positionIndex = nil
            character.positionTrack = nil
            // Mark position as vacant
            markPositionVacant(position: previousPosition, track: previousTrack, game: game)

        default:
            // For other types, remove from position but keep active
            character.positionIndex = 0
            character.positionTrack = nil
            // Mark previous position as vacant
            markPositionVacant(position: previousPosition, track: previousTrack, game: game)
        }

        // Record dismissal
        character.statusChangedTurn = game.turnNumber
        character.statusDetails = dismissalType.displayText
        character.fateNarrative = generateDismissalNarrative(
            character: character,
            dismissalType: dismissalType,
            perpetrator: perpetrator,
            previousPosition: previousPosition,
            previousTrack: previousTrack
        )

        // Record in game state
        recordDismissal(
            character: character,
            dismissalType: dismissalType,
            perpetrator: perpetrator,
            previousPosition: previousPosition,
            game: game
        )

        // Apply effects
        applyDismissalEffects(
            character: character,
            dismissalType: dismissalType,
            previousPosition: previousPosition,
            game: game
        )
    }

    /// Generate dismissal narrative
    private func generateDismissalNarrative(
        character: GameCharacter,
        dismissalType: DismissalType,
        perpetrator: GameCharacter?,
        previousPosition: Int,
        previousTrack: String
    ) -> String {
        let perpetratorDesc = perpetrator.map { "by \($0.name)" } ?? ""

        switch dismissalType {
        case .forcedResignation:
            return "\(character.name) was pressured to resign \(perpetratorDesc) from Position \(previousPosition)."
        case .firedByPatron:
            return "\(character.name)'s patron sacrificed them to protect their own position."
        case .factionPurge:
            return "\(character.name) was swept away as part of a faction purge."
        case .retiredForced:
            return "\(character.name) was forced into early retirement 'for health reasons.'"
        default:
            return "\(character.name) \(dismissalType.officialDescription) from \(previousTrack)."
        }
    }

    /// Record dismissal
    private func recordDismissal(
        character: GameCharacter,
        dismissalType: DismissalType,
        perpetrator: GameCharacter?,
        previousPosition: Int,
        game: Game
    ) {
        var dismissals = getDismissalRecords(for: game)
        dismissals.append(DismissalRecord(
            characterId: character.id.uuidString,
            characterName: character.name,
            dismissalType: dismissalType,
            perpetratorId: perpetrator?.id.uuidString,
            perpetratorName: perpetrator?.name,
            turn: game.turnNumber,
            previousPosition: previousPosition
        ))
        saveDismissalRecords(dismissals, for: game)
    }

    /// Apply dismissal effects
    private func applyDismissalEffects(
        character: GameCharacter,
        dismissalType: DismissalType,
        previousPosition: Int,
        game: Game
    ) {
        // High-profile dismissals affect stability
        if previousPosition >= 5 {
            game.stability -= 3
        }

        // Purge-style dismissals create fear
        if dismissalType == .factionPurge {
            game.eliteLoyalty += 2
            game.stability -= 5
        }
    }

    // MARK: - Exile

    /// Exile a character
    func exileCharacter(
        _ character: GameCharacter,
        destination: String = "remote province",
        perpetrator: GameCharacter? = nil,
        game: Game,
        modelContext: ModelContext
    ) {
        guard character.isAlive else { return }

        let previousPosition = character.positionIndex ?? 0
        let previousTrack = character.positionTrack ?? "unknown"

        character.status = CharacterStatus.exiled.rawValue
        character.positionIndex = nil
        character.positionTrack = nil
        character.statusChangedTurn = game.turnNumber
        character.statusDetails = "Exiled to \(destination)"
        character.fateNarrative = "\(character.name) was exiled to \(destination), removed from all positions of power."

        // Mark position as vacant for promotion system
        if previousPosition > 0 {
            markPositionVacant(position: previousPosition, track: previousTrack, game: game)
        }

        // Exile affects stability less than death
        if previousPosition >= 5 {
            game.stability -= 2
        }
    }

    // MARK: - Imprisonment

    /// Imprison a character
    func imprisonCharacter(
        _ character: GameCharacter,
        sentence: Int, // Years
        facility: String = "labor camp",
        perpetrator: GameCharacter? = nil,
        game: Game,
        modelContext: ModelContext
    ) {
        guard character.isAlive else { return }

        let previousPosition = character.positionIndex ?? 0
        let previousTrack = character.positionTrack ?? "unknown"

        character.status = CharacterStatus.imprisoned.rawValue
        character.positionIndex = nil
        character.positionTrack = nil
        character.isDetained = false
        character.statusChangedTurn = game.turnNumber
        character.statusDetails = "\(sentence) years in \(facility)"
        character.fateNarrative = "\(character.name) was sentenced to \(sentence) years in \(facility)."

        // Mark position as vacant for promotion system
        if previousPosition > 0 {
            markPositionVacant(position: previousPosition, track: previousTrack, game: game)
        }

        // Record sentence end turn (if they survive)
        let endTurn = game.turnNumber + (sentence * 26) // Roughly 26 turns per year
        game.variables["sentence_end_\(character.id.uuidString)"] = String(endTurn)

        if previousPosition >= 5 {
            game.stability -= 3
            game.eliteLoyalty += 2 // Fear
        }
    }

    // MARK: - Rehabilitation

    /// Rehabilitate a fallen character (can return from exile/imprisonment/disappeared)
    func rehabilitateCharacter(
        _ character: GameCharacter,
        newPosition: Int = 2,
        newTrack: String = "partyApparatus",
        sponsor: GameCharacter? = nil,
        game: Game,
        modelContext: ModelContext
    ) {
        guard [.exiled, .imprisoned, .disappeared, .retired].contains(character.currentStatus) else {
            return
        }

        character.status = CharacterStatus.rehabilitated.rawValue
        character.positionIndex = newPosition
        character.positionTrack = newTrack
        character.statusChangedTurn = game.turnNumber
        character.statusDetails = "Rehabilitated"

        let sponsorDesc = sponsor.map { "with the support of \($0.name)" } ?? ""
        character.fateNarrative = "\(character.name) has been rehabilitated \(sponsorDesc) and returns to public life."

        // Rehabilitation can signal thaw or power shift
        game.stability += 2
    }

    // MARK: - Convenience Methods

    /// Quick execution (shorthand)
    func execute(_ character: GameCharacter, game: Game, modelContext: ModelContext) {
        killCharacter(character, cause: .executed, game: game, modelContext: modelContext)
    }

    /// Quick dismissal (shorthand)
    func dismiss(_ character: GameCharacter, game: Game, modelContext: ModelContext) {
        dismissCharacter(character, dismissalType: .forcedResignation, game: game, modelContext: modelContext)
    }

    // MARK: - Storage

    private func getDeathRecords(for game: Game) -> [DeathRecord] {
        guard let data = game.variables["death_records"],
              let jsonData = data.data(using: .utf8),
              let records = try? JSONDecoder().decode([DeathRecord].self, from: jsonData) else {
            return []
        }
        return records
    }

    private func saveDeathRecords(_ records: [DeathRecord], for game: Game) {
        if let data = try? JSONEncoder().encode(records),
           let string = String(data: data, encoding: .utf8) {
            game.variables["death_records"] = string
        }
    }

    private func getDismissalRecords(for game: Game) -> [DismissalRecord] {
        guard let data = game.variables["dismissal_records"],
              let jsonData = data.data(using: .utf8),
              let records = try? JSONDecoder().decode([DismissalRecord].self, from: jsonData) else {
            return []
        }
        return records
    }

    private func saveDismissalRecords(_ records: [DismissalRecord], for game: Game) {
        if let data = try? JSONEncoder().encode(records),
           let string = String(data: data, encoding: .utf8) {
            game.variables["dismissal_records"] = string
        }
    }

    // MARK: - Query Methods

    /// Get all death records
    func getAllDeaths(for game: Game) -> [DeathRecord] {
        getDeathRecords(for: game)
    }

    /// Get deaths by cause
    func getDeaths(byCause cause: DeathCause, for game: Game) -> [DeathRecord] {
        getDeathRecords(for: game).filter { $0.cause == cause }
    }

    /// Get recent deaths
    func getRecentDeaths(turns: Int, for game: Game) -> [DeathRecord] {
        let threshold = game.turnNumber - turns
        return getDeathRecords(for: game).filter { $0.turn >= threshold }
    }

    /// Get all dismissals
    func getAllDismissals(for game: Game) -> [DismissalRecord] {
        getDismissalRecords(for: game)
    }

    // MARK: - Vacancy Tracking

    /// Mark a position as vacant for the promotion system
    /// This enables PositionOfferService to generate offers for vacant positions
    private func markPositionVacant(position: Int, track: String, game: Game) {
        // Store vacancy information in game variables
        let vacancyKey = "vacancy_\(track)_\(position)"
        let turnKey = "vacancy_turn_\(track)_\(position)"

        game.variables[vacancyKey] = "true"
        game.variables[turnKey] = "\(game.turnNumber)"

        // Log the vacancy
        fateLogger.info("Position vacancy created: \(track) position \(position) at turn \(game.turnNumber)")
    }

    /// Check if a position is vacant
    func isPositionVacant(position: Int, track: String, game: Game) -> Bool {
        let vacancyKey = "vacancy_\(track)_\(position)"
        return game.variables[vacancyKey] == "true"
    }

    /// Get all vacant positions
    func getVacantPositions(for game: Game) -> [(track: String, position: Int, sinceTurn: Int)] {
        var vacancies: [(track: String, position: Int, sinceTurn: Int)] = []

        for (key, value) in game.variables where key.hasPrefix("vacancy_") && value == "true" {
            // Parse vacancy key: "vacancy_TRACK_POSITION"
            let parts = key.dropFirst("vacancy_".count).split(separator: "_")
            if parts.count >= 2,
               let position = Int(parts.last!) {
                let track = parts.dropLast().joined(separator: "_")
                let turnKey = "vacancy_turn_\(track)_\(position)"
                let sinceTurn = Int(game.variables[turnKey] ?? "0") ?? 0
                vacancies.append((track: track, position: position, sinceTurn: sinceTurn))
            }
        }

        return vacancies.sorted { $0.position > $1.position } // Higher positions first
    }

    /// Clear a vacancy when position is filled
    func clearVacancy(position: Int, track: String, game: Game) {
        let vacancyKey = "vacancy_\(track)_\(position)"
        let turnKey = "vacancy_turn_\(track)_\(position)"

        game.variables.removeValue(forKey: vacancyKey)
        game.variables.removeValue(forKey: turnKey)

        fateLogger.info("Position vacancy cleared: \(track) position \(position)")
    }
}

// MARK: - Records

/// Record of a character death
struct DeathRecord: Codable, Identifiable {
    let id: UUID
    let characterId: String
    let characterName: String
    let cause: DeathCause
    let perpetratorId: String?
    let perpetratorName: String?
    let turn: Int
    let previousPosition: Int

    init(
        characterId: String,
        characterName: String,
        cause: DeathCause,
        perpetratorId: String? = nil,
        perpetratorName: String? = nil,
        turn: Int,
        previousPosition: Int
    ) {
        self.id = UUID()
        self.characterId = characterId
        self.characterName = characterName
        self.cause = cause
        self.perpetratorId = perpetratorId
        self.perpetratorName = perpetratorName
        self.turn = turn
        self.previousPosition = previousPosition
    }
}

/// Record of a character dismissal
struct DismissalRecord: Codable, Identifiable {
    let id: UUID
    let characterId: String
    let characterName: String
    let dismissalType: DismissalType
    let perpetratorId: String?
    let perpetratorName: String?
    let turn: Int
    let previousPosition: Int

    init(
        characterId: String,
        characterName: String,
        dismissalType: DismissalType,
        perpetratorId: String? = nil,
        perpetratorName: String? = nil,
        turn: Int,
        previousPosition: Int
    ) {
        self.id = UUID()
        self.characterId = characterId
        self.characterName = characterName
        self.dismissalType = dismissalType
        self.perpetratorId = perpetratorId
        self.perpetratorName = perpetratorName
        self.turn = turn
        self.previousPosition = previousPosition
    }
}
