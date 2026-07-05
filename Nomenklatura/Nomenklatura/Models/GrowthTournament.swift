//
//  GrowthTournament.swift
//  Nomenklatura
//
//  The Growth Tournament — regional governors report the output figures
//  that feed the center, and ambitious or corrupt ones pad them. Padding
//  accumulates invisibly as statistical distortion; sooner or later the
//  warehouse turns out to be empty. The player's lever is the AUDIT:
//  cheap, a little insulting to the governor's patrons, and the only way
//  to know whether your own statistics are lying to you.
//
//  Distortion and audit cooldowns live in the variables dictionary keyed
//  by regionId (no schema change). Per-turn processing is
//  EconomyService.processGrowthTournament; audits go through
//  EconomyService.auditRegion.
//

import Foundation

enum GrowthTournament {
    /// Distortion at or above this level can blow up on its own.
    static let shockThreshold = 12
    /// Per-turn chance (%) a ripe distortion is exposed by events.
    static let shockChancePercent = 15
    /// Turns between audits of the same region.
    static let auditCooldown = 6
    static let auditAPCost = 1
    static let auditTreasuryCost = 5

    /// A governor's prior for honest reporting, shown to the player as a
    /// hint (their corruption/competence are known; their books are not).
    static func reliabilityLabel(for governor: RegionGovernor?) -> String {
        guard let governor else { return "UNKNOWN" }
        let score = governor.competence - governor.corruption
        switch score {
        case 25...: return "HIGH"
        case 0..<25: return "MODERATE"
        default: return "LOW"
        }
    }
}

extension Game {
    /// Accumulated reporting distortion for a region (0 = books honest).
    func statDistortion(for regionId: String) -> Int {
        intVariable("stat_distortion_\(regionId)")
    }

    func setStatDistortion(_ value: Int, for regionId: String) {
        setIntVariable("stat_distortion_\(regionId)", max(0, value))
    }

    /// Growth figure the region REPORTS to the center — its real
    /// contribution plus whatever the governor has padded on top. This is
    /// the number the player sees; the truth costs an audit.
    func reportedContribution(for region: Region) -> Int {
        region.economicContribution + statDistortion(for: region.regionId)
    }

    func auditCooldownRemaining(for regionId: String) -> Int {
        let last = intVariable("audit_turn_\(regionId)")
        guard last > 0 else { return 0 }
        return max(0, GrowthTournament.auditCooldown - (turnNumber - last))
    }

    func recordAudit(for regionId: String) {
        setIntVariable("audit_turn_\(regionId)", turnNumber)
    }
}

/// Outcome of a regional audit, for the UI to present.
enum RegionAuditResult {
    case booksClean
    case paddingFound(distortion: Int)
    case cannotAfford(reason: String)
}
