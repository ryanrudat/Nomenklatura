//
//  EmergencyDecree.swift
//  Nomenklatura
//
//  Phase 3.8: Chairman's active response toolkit when the supply chain
//  breaks. Each decree has a clear political cost and a targeted relief
//  effect. Decrees are gated to situations where they make sense — you
//  can't requisition grain you don't have a grain crisis for.
//

import Foundation

enum EmergencyDecree: String, CaseIterable, Codable, Identifiable {
    case requisitionGrain
    case emergencyCoalImports
    case industrialConscription
    case strategicReserveLiquidation
    case blackMarketTolerance
    case emergencyOilRationing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .requisitionGrain:           return "Requisition Grain"
        case .emergencyCoalImports:       return "Emergency Coal Imports"
        case .industrialConscription:     return "Industrial Conscription"
        case .strategicReserveLiquidation: return "Liquidate Strategic Reserves"
        case .blackMarketTolerance:       return "Tolerate Black Market"
        case .emergencyOilRationing:      return "Emergency Oil Rationing"
        }
    }

    var description: String {
        switch self {
        case .requisitionGrain:
            return "Seize grain and materials from the regions. Granaries and stockpiles fill at gunpoint; the countryside seethes."
        case .emergencyCoalImports:
            return "Pay above-market rates for coal from any willing exporter. Treasury bleeds; the furnaces stay lit."
        case .industrialConscription:
            return "Compel idle workers into priority sectors. Production ratios fill; popular support craters."
        case .strategicReserveLiquidation:
            return "Empty the wartime stockpile to plug current deficits. Immediate relief; future war means starting from zero."
        case .blackMarketTolerance:
            return "Look the other way at smuggling. Goods flow unofficially; the rule of law weakens."
        case .emergencyOilRationing:
            return "Cut civilian fuel use to keep industry and military supplied. Industrial throughput preserved; the people walk to work."
        }
    }

    /// Treasury cost (negative = costs treasury). 0 if the decree pays in
    /// political capital instead of money.
    var treasuryCost: Int {
        switch self {
        case .requisitionGrain:           return -5
        case .emergencyCoalImports:       return -15
        case .industrialConscription:     return -3
        case .strategicReserveLiquidation: return 0
        case .blackMarketTolerance:       return 5   // black market cut
        case .emergencyOilRationing:      return 0
        }
    }

    /// Political stat changes applied immediately when the decree fires.
    var statEffects: [String: Int] {
        switch self {
        case .requisitionGrain:
            return ["popularSupport": -8, "stability": -3]
        case .emergencyCoalImports:
            return ["internationalStanding": -2]
        case .industrialConscription:
            return ["popularSupport": -10, "eliteLoyalty": 3, "stability": -2]
        case .strategicReserveLiquidation:
            return ["militaryLoyalty": -3]
        case .blackMarketTolerance:
            return ["stability": -5, "popularSupport": 2]
        case .emergencyOilRationing:
            return ["popularSupport": -5, "militaryLoyalty": 2]
        }
    }

    /// Strategic resource changes applied immediately. Positive = added
    /// to reserves; negative = drawn from reserves.
    var resourceEffects: [StrategicResource: Int] {
        switch self {
        case .requisitionGrain:           return [.grain: 30, .coal: 20, .steel: 15]
        case .emergencyCoalImports:       return [.coal: 20]
        case .industrialConscription:     return [.steel: 8, .iron: 6]
        case .strategicReserveLiquidation: return [.coal: 15, .oil: 10, .iron: 10, .steel: 8, .grain: 10]
        case .blackMarketTolerance:       return [.cotton: 10, .timber: 10, .grain: 8]
        case .emergencyOilRationing:      return [.oil: 12]
        }
    }

    /// Whether this decree is available given current game state. Each
    /// decree requires a specific kind of crisis to be reachable, so the
    /// player can't spam them outside of genuine emergencies.
    func isAvailable(in game: Game) -> Bool {
        let reserves = game.strategicReserves
        switch self {
        case .requisitionGrain:
            return (reserves[.grain] ?? 0) <= 5
        case .emergencyCoalImports:
            return (reserves[.coal] ?? 0) <= 5 && game.treasury >= 15
        case .industrialConscription:
            return (reserves[.steel] ?? 0) <= 0 || (reserves[.iron] ?? 0) <= 0
        case .strategicReserveLiquidation:
            // Once per game proxy: only when a multi-resource crisis exists
            let deficitCount = StrategicResource.allCases
                .filter { (reserves[$0] ?? 0) <= 0 }.count
            return deficitCount >= 2
        case .blackMarketTolerance:
            return (reserves[.cotton] ?? 0) <= 0 || (reserves[.timber] ?? 0) <= 0
        case .emergencyOilRationing:
            return (reserves[.oil] ?? 0) <= 5
        }
    }

    var lockReason: String {
        switch self {
        case .requisitionGrain:
            return "Available only during a grain crisis (≤ 5 reserves)."
        case .emergencyCoalImports:
            return "Available during a coal crisis. Requires ≥ 15 treasury for procurement."
        case .industrialConscription:
            return "Available only when steel or iron reserves are exhausted."
        case .strategicReserveLiquidation:
            return "Available only when 2+ resources are simultaneously in deficit."
        case .blackMarketTolerance:
            return "Available only during a cotton or timber shortage."
        case .emergencyOilRationing:
            return "Available only during an oil crisis (≤ 5 reserves)."
        }
    }
}
