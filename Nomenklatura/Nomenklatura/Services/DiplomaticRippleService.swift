//
//  DiplomaticRippleService.swift
//  Nomenklatura
//
//  Cascades diplomatic action effects across allied/rival countries,
//  trade volumes, world tension, and regional stability.
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.nomenklatura", category: "DiplomaticRipple")

@MainActor
final class DiplomaticRippleService {
    static let shared = DiplomaticRippleService()
    private init() {}

    /// Process cascading effects from a diplomatic action.
    func processRipples(
        relationshipChange: Int,
        tensionChange: Int,
        targetCountry: ForeignCountry,
        wasHostile: Bool,
        game: Game
    ) {
        guard relationshipChange != 0 || tensionChange != 0 else { return }

        let targetBloc = targetCountry.politicalBloc

        applyAllianceRipples(
            relationshipChange: relationshipChange,
            targetCountry: targetCountry,
            targetBloc: targetBloc,
            wasHostile: wasHostile,
            game: game
        )
        adjustTradeVolume(for: targetCountry)
        applyWorldTension(tensionChange: tensionChange, targetCountry: targetCountry, wasHostile: wasHostile, game: game)
        applyRegionalImpact(targetCountry: targetCountry, wasHostile: wasHostile, game: game)
        createRippleEvent(targetCountry: targetCountry, targetBloc: targetBloc, game: game)
    }

    // MARK: - A: Alliance Ripples

    private func applyAllianceRipples(
        relationshipChange: Int,
        targetCountry: ForeignCountry,
        targetBloc: PoliticalBloc,
        wasHostile: Bool,
        game: Game
    ) {
        let targetTreatyTypes = Set(targetCountry.treaties.map(\.type))

        for country in game.foreignCountries where country.countryId != targetCountry.countryId {
            var delta = 0

            if country.politicalBloc == targetBloc {
                delta += clampRipple(Int(Double(relationshipChange) * 0.3))
            }

            if sharesTreatyType(country, targetTreatyTypes: targetTreatyTypes) {
                delta += clampRipple(Int(Double(relationshipChange) * 0.5))
            }

            // "Enemy of my enemy" — opposing bloc gains from hostile action against target
            if wasHostile && isOpposingBloc(country.politicalBloc, to: targetBloc) {
                delta += clampRipple(Int(Double(abs(relationshipChange)) * 0.1))
            }

            if delta != 0 {
                country.modifyRelationship(by: delta)
                logger.debug("Ripple: \(country.name) relationship shifted by \(delta)")
            }
        }
    }

    // MARK: - B: Trade Volume

    private func adjustTradeVolume(for country: ForeignCountry) {
        if country.relationshipScore < -60 {
            country.tradeVolume = max(0, country.tradeVolume - 30)
        } else if country.relationshipScore > 30 {
            country.tradeVolume += 10
        }
    }

    // MARK: - C: World Tension

    private func applyWorldTension(tensionChange: Int, targetCountry: ForeignCountry, wasHostile: Bool, game: Game) {
        var tensionDelta = Int(Double(abs(tensionChange)) * 0.5)

        if targetCountry.hasNuclearWeapons && tensionDelta > 3 {
            tensionDelta += 5
        }

        let signedDelta = wasHostile ? tensionDelta : -tensionDelta
        game.applyStat("worldTension", change: signedDelta)
    }

    // MARK: - D: Regional Border Impact

    private func applyRegionalImpact(targetCountry: ForeignCountry, wasHostile: Bool, game: Game) {
        guard wasHostile, let borderingId = targetCountry.borderingRegionId else { return }

        if let region = game.regions.first(where: { $0.regionId == borderingId }) {
            region.militaryPresence = min(100, region.militaryPresence + 5)
            region.popularLoyalty = max(0, region.popularLoyalty - 3)
            logger.debug("Border region \(region.name) impacted: militaryPresence +5, popularLoyalty -3")
        }
    }

    // MARK: - E: Feedback Event

    private func createRippleEvent(targetCountry: ForeignCountry, targetBloc: PoliticalBloc, game: Game) {
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .narrative,
            summary: "Your diplomatic actions toward \(targetCountry.name) have caused reactions across the \(targetBloc.displayName) bloc."
        )
        event.game = game
        game.events.append(event)
    }

    // MARK: - Helpers

    /// Cap a ripple delta to +-15.
    private func clampRipple(_ value: Int) -> Int {
        max(-15, min(15, value))
    }

    private func sharesTreatyType(_ country: ForeignCountry, targetTreatyTypes: Set<TreatyType>) -> Bool {
        guard !targetTreatyTypes.isEmpty else { return false }
        let countryTypes = Set(country.treaties.map(\.type))
        return !countryTypes.isDisjoint(with: targetTreatyTypes)
    }

    /// Determine if two blocs are on opposing sides.
    private func isOpposingBloc(_ a: PoliticalBloc, to b: PoliticalBloc) -> Bool {
        switch (a, b) {
        case (.socialist, .capitalist), (.capitalist, .socialist):
            return true
        case (.socialist, .rival), (.rival, .socialist):
            return true
        default:
            return false
        }
    }
}
