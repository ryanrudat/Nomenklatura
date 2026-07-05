//
//  PilotZone.swift
//  Nomenklatura
//
//  Special Development Zones — reform by contained experiment. Designate
//  one region, let market rules run there for a fixed trial, and measure.
//  Success hands the reformers proof ("tested" reform is cheaper to pass:
//  the next liberalizing Economic Constitution step gets a power discount);
//  failure stays local and the ideologues gloat. The gradualist's method:
//  never bet the country when you can bet a province.
//
//  One zone at a time. State lives in the variables dictionary. Per-turn
//  processing is EconomyService.processPilotZone.
//

import Foundation

enum PilotZone {
    static let trialLength = 8          // turns
    static let successThreshold = 16    // accumulated score needed
    static let designateAPCost = 1
    static let designateTreasuryCost = 10
    /// Power discount on liberalizing Economic Constitution steps after a
    /// successful pilot (consumed when such a law passes).
    static let reformCreditDiscount = 10
    static let reformCreditFlag = "reform_pilot_credit"
}

extension Game {
    /// Region currently designated as the Special Development Zone, if any.
    var pilotZoneRegionId: String? {
        get { variables["pilot_zone_region"] }
        set { variables["pilot_zone_region"] = newValue }
    }

    var pilotZoneStartTurn: Int { intVariable("pilot_zone_start_turn") }
    var pilotZoneScore: Int { intVariable("pilot_zone_score") }

    var pilotZoneTurnsElapsed: Int {
        guard pilotZoneRegionId != nil else { return 0 }
        return turnNumber - pilotZoneStartTurn
    }

    /// Zones require an economy already open to markets — under a full
    /// command economy there is nothing to pilot.
    var canDesignatePilotZone: Bool {
        currentEconomicSystem != .commandEconomy && pilotZoneRegionId == nil
    }

    /// Honest mid-trial readout for the UI.
    var pilotZoneProgressLabel: String {
        let elapsed = max(1, pilotZoneTurnsElapsed)
        let pace = Double(pilotZoneScore) / Double(elapsed)
        let neededPace = Double(PilotZone.successThreshold) / Double(PilotZone.trialLength)
        if pace >= neededPace + 0.5 { return "FLOURISHING" }
        if pace >= neededPace { return "PROMISING" }
        if pace >= neededPace - 0.5 { return "UNEVEN" }
        return "STRUGGLING"
    }
}
