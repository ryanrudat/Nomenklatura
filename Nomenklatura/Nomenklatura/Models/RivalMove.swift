//
//  RivalMove.swift
//  Nomenklatura
//
//  Wave 3 / Audit "deep-politics" — converts the political layer from
//  "rivals quietly apply hidden stat deltas" to "named rivals make
//  specific, deadline-bound threats the Chairman must counter."
//
//  This file is the data layer only. The generator service lives in
//  Services/RivalMoveGenerator.swift; the activeRivalMoves accessor
//  on Game lives in Models/Game+RivalMoves.swift (extension-only to
//  avoid contending with parallel work on Game.swift).
//

import Foundation

// MARK: - RivalMove

/// A named, time-limited scheme by an in-game rival. The Chairman sees
/// this on the Desk and chooses a counter response. Failure to counter
/// applies `pendingEffect` on the deadline turn.
struct RivalMove: Codable, Identifiable, Equatable {
    let id: UUID
    let rivalCharacterId: UUID
    let rivalName: String              // Cached for display + safety if the character disappears
    let kind: RivalMoveKind
    let headline: String               // "Minister Volkov is scheduling private meetings"
    let body: String                   // 2-3 sentence narrative
    let createdTurn: Int
    let deadlineTurn: Int              // Player has until this turn (inclusive) to counter
    let pendingEffect: PendingEffect   // Applied if no counter chosen by deadline
    let counterOptions: [RivalCounterOption]
    var resolution: RivalMoveResolution // .pending, .countered(by:), .expired, .ignored

    init(
        id: UUID = UUID(),
        rivalCharacterId: UUID,
        rivalName: String,
        kind: RivalMoveKind,
        headline: String,
        body: String,
        createdTurn: Int,
        deadlineTurn: Int,
        pendingEffect: PendingEffect,
        counterOptions: [RivalCounterOption],
        resolution: RivalMoveResolution = .pending
    ) {
        self.id = id
        self.rivalCharacterId = rivalCharacterId
        self.rivalName = rivalName
        self.kind = kind
        self.headline = headline
        self.body = body
        self.createdTurn = createdTurn
        self.deadlineTurn = deadlineTurn
        self.pendingEffect = pendingEffect
        self.counterOptions = counterOptions
        self.resolution = resolution
    }
}

// MARK: - RivalMoveKind

/// Each kind targets a specific stat axis. The kind drives which
/// template library the generator pulls from and which `pendingEffect`
/// stat the move threatens.
enum RivalMoveKind: String, Codable, CaseIterable {
    case factionWhisperCampaign        // Threatens eliteLoyalty
    case militaryCircleApproach        // Threatens militaryLoyalty
    case publicCriticism               // Threatens popularSupport
    case foreignContact                // Threatens internationalStanding
    case patronUnderminding            // Threatens patronFavor
    case rivalConsolidation            // Threatens standing

    /// Default stat key targeted by this kind. The pendingEffect carries
    /// the actual stat used; this is the fallback used by the generator.
    var defaultStat: String {
        switch self {
        case .factionWhisperCampaign: return "eliteLoyalty"
        case .militaryCircleApproach: return "militaryLoyalty"
        case .publicCriticism: return "popularSupport"
        case .foreignContact: return "internationalStanding"
        case .patronUnderminding: return "patronFavor"
        case .rivalConsolidation: return "standing"
        }
    }
}

// MARK: - PendingEffect

/// The stat damage that lands if the player lets the deadline pass.
/// Magnitude is typically negative (damage to player). Stored as Double
/// for future granularity, but Game.applyStat takes Int so the resolver
/// rounds at apply-time.
struct PendingEffect: Codable, Equatable {
    let stat: String                   // "eliteLoyalty" / "militaryLoyalty" / etc.
    let magnitude: Double              // Usually -3 to -10
}

// MARK: - RivalCounterOption

/// One of the (typically 3-4) responses the player can pick to counter
/// a RivalMove. Each option has a cost, a success chance, and stat
/// deltas on success/failure.
struct RivalCounterOption: Codable, Identifiable, Equatable {
    let id: UUID
    let label: String                  // "[SURVEIL]"
    let description: String            // "Have State Security shadow him. Costs 15 network."
    let cost: CounterCost
    let outcome: CounterOutcome

    init(
        id: UUID = UUID(),
        label: String,
        description: String,
        cost: CounterCost,
        outcome: CounterOutcome
    ) {
        self.id = id
        self.label = label
        self.description = description
        self.cost = cost
        self.outcome = outcome
    }
}

// MARK: - CounterCost

struct CounterCost: Codable, Equatable {
    let actionPoints: Int              // 0 or 1
    let network: Int                   // 0 to ~25
    let treasury: Int                  // 0 to ~5
}

// MARK: - CounterOutcome

struct CounterOutcome: Codable, Equatable {
    let successChance: Double          // 0.0...1.0
    let onSuccess: [StatDelta]         // What the player gets if it works
    let onFailure: [StatDelta]         // What the player loses if it doesn't
}

// MARK: - StatDelta

struct StatDelta: Codable, Equatable {
    let stat: String
    let delta: Double
}

// MARK: - RivalMoveResolution

enum RivalMoveResolution: Codable, Equatable {
    case pending
    case countered(optionId: UUID, success: Bool, turn: Int)
    case expired                       // Player let the deadline pass — pendingEffect applies
    case ignored                       // Player explicitly chose to do nothing

    var isResolved: Bool {
        switch self {
        case .pending: return false
        case .countered, .expired, .ignored: return true
        }
    }
}
