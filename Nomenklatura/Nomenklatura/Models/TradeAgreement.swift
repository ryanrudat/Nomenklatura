//
//  TradeAgreement.swift
//  Nomenklatura
//
//  International trade agreements and economic diplomacy
//

import Foundation
import SwiftData

// MARK: - Agreement Type

enum AgreementType: String, Codable, CaseIterable {
    case basicTrade             // Standard trade relations
    case preferentialTrade      // Favorable trade terms
    case aidPackage             // One-way economic assistance (we give)
    case receivingAid           // One-way economic assistance (we receive)
    case oilDeal                // Energy imports/exports
    case armsExport             // Weapons sales
    case armsImport             // Weapons purchases
    case technicalCooperation   // Technology transfer
    case jointVenture           // Shared industrial projects
    case debtAgreement          // Loan terms

    var displayName: String {
        switch self {
        case .basicTrade: return "Trade Agreement"
        case .preferentialTrade: return "Preferential Trade Terms"
        case .aidPackage: return "Economic Aid Package"
        case .receivingAid: return "Receiving Aid"
        case .oilDeal: return "Oil Agreement"
        case .armsExport: return "Arms Export Contract"
        case .armsImport: return "Arms Import Contract"
        case .technicalCooperation: return "Technical Cooperation"
        case .jointVenture: return "Joint Venture"
        case .debtAgreement: return "Debt Agreement"
        }
    }

    var description: String {
        switch self {
        case .basicTrade:
            return "Standard bilateral trade relations with normal tariffs"
        case .preferentialTrade:
            return "Reduced tariffs and favorable trading conditions"
        case .aidPackage:
            return "Economic assistance provided to partner nation"
        case .receivingAid:
            return "Economic assistance received from partner nation"
        case .oilDeal:
            return "Agreement for petroleum import or export"
        case .armsExport:
            return "Military equipment export contract"
        case .armsImport:
            return "Military equipment import contract"
        case .technicalCooperation:
            return "Technology transfer and industrial cooperation"
        case .jointVenture:
            return "Shared industrial or infrastructure project"
        case .debtAgreement:
            return "Terms for debt repayment or restructuring"
        }
    }

    var iconName: String {
        switch self {
        case .basicTrade, .preferentialTrade: return "cart.fill"
        case .aidPackage, .receivingAid: return "gift.fill"
        case .oilDeal: return "drop.fill"
        case .armsExport, .armsImport: return "shield.fill"
        case .technicalCooperation: return "gearshape.2.fill"
        case .jointVenture: return "building.2.fill"
        case .debtAgreement: return "dollarsign.circle.fill"
        }
    }

    /// Whether we pay or receive in this agreement
    var isOutflow: Bool {
        switch self {
        case .aidPackage, .armsImport, .receivingAid:
            return true
        default:
            return false
        }
    }
}

// MARK: - Agreement Status

enum AgreementStatus: String, Codable, CaseIterable {
    case proposed           // Under negotiation
    case active             // Currently in force
    case suspended          // Temporarily halted
    case terminated         // Ended by one party
    case expired            // Reached end date
    case violated           // Terms broken

    var displayName: String {
        switch self {
        case .proposed: return "Under Negotiation"
        case .active: return "Active"
        case .suspended: return "Suspended"
        case .terminated: return "Terminated"
        case .expired: return "Expired"
        case .violated: return "Terms Violated"
        }
    }
}

// MARK: - Trade Agreement Model

@Model
final class TradeAgreement {
    @Attribute(.unique) var id: UUID
    var agreementId: String             // Unique identifier

    // Parties
    var partnerCountryId: String        // ForeignCountry.countryId
    var partnerCountryName: String      // Display name

    // Agreement details
    var agreementType: String           // AgreementType.rawValue
    var agreementStatus: String         // AgreementStatus.rawValue
    var agreementName: String           // Custom name or generated
    var agreementDescription: String    // Full text description

    // Timing
    var turnSigned: Int                 // When agreement was made
    var durationTurns: Int?             // How long it lasts (nil = permanent)
    var turnExpires: Int?               // When it ends

    // Economic effects
    var treasuryEffect: Int             // +/- per turn
    var industrialEffect: Int           // +/- to industrial output
    var foodEffect: Int                 // +/- to food supply
    var technologyEffect: Int           // +/- to research

    // Political effects
    var standingEffect: Int             // Effect on international standing
    var relationshipEffect: Int         // Effect on bilateral relations
    var blocReputationEffect: Int       // Effect on bloc relations

    // Secret terms
    var hasSecretTerms: Bool
    var secretTermsDescription: String?

    // Tracking
    var totalValueExchanged: Int        // Cumulative economic value
    var turnsActive: Int                // How long active

    // Phase 3.6: commodity-level flows. Each turn the supply chain
    // engine subtracts exports from our reserves and adds imports.
    // JSON-encoded [StrategicResource.rawValue: Int].
    var commodityExportsData: Data?
    var commodityImportsData: Data?

    var game: Game?

    init(partnerId: String, partnerName: String, type: AgreementType) {
        self.id = UUID()
        self.agreementId = UUID().uuidString

        self.partnerCountryId = partnerId
        self.partnerCountryName = partnerName

        self.agreementType = type.rawValue
        self.agreementStatus = AgreementStatus.proposed.rawValue
        self.agreementName = "\(type.displayName) with \(partnerName)"
        self.agreementDescription = ""

        self.turnSigned = 0

        self.treasuryEffect = 0
        self.industrialEffect = 0
        self.foodEffect = 0
        self.technologyEffect = 0

        self.standingEffect = 0
        self.relationshipEffect = 0
        self.blocReputationEffect = 0

        self.hasSecretTerms = false
        self.totalValueExchanged = 0
        self.turnsActive = 0
    }

    // MARK: - Computed Properties

    var type: AgreementType {
        AgreementType(rawValue: agreementType) ?? .basicTrade
    }

    var status: AgreementStatus {
        get { AgreementStatus(rawValue: agreementStatus) ?? .proposed }
        set { agreementStatus = newValue.rawValue }
    }

    var isActive: Bool {
        status == .active
    }

    var isPermanent: Bool {
        durationTurns == nil
    }

    /// Phase 3.6: per-turn commodity flows we send abroad under this agreement.
    var commodityExports: [StrategicResource: Int] {
        get { decodeCommodityFlow(from: commodityExportsData) }
        set { commodityExportsData = encodeCommodityFlow(newValue) }
    }

    /// Phase 3.6: per-turn commodity flows we receive under this agreement.
    var commodityImports: [StrategicResource: Int] {
        get { decodeCommodityFlow(from: commodityImportsData) }
        set { commodityImportsData = encodeCommodityFlow(newValue) }
    }

    /// Whether this agreement carries any commodity-level flow at all.
    /// Older / abstract agreements return false — they still apply
    /// their abstract treasuryEffect/industrialEffect/etc.
    var hasCommodityFlows: Bool {
        commodityExportsData != nil || commodityImportsData != nil
    }

    var turnsRemaining: Int? {
        guard let expires = turnExpires else { return nil }
        return max(0, expires - turnSigned - turnsActive)
    }

    /// Net economic impact per turn
    var netEconomicImpact: Int {
        treasuryEffect + industrialEffect + foodEffect + technologyEffect
    }

    /// Summary for display
    var effectsSummary: String {
        var effects: [String] = []

        if treasuryEffect != 0 {
            let sign = treasuryEffect > 0 ? "+" : ""
            effects.append("\(sign)\(treasuryEffect) Treasury")
        }
        if industrialEffect != 0 {
            let sign = industrialEffect > 0 ? "+" : ""
            effects.append("\(sign)\(industrialEffect) Industry")
        }
        if foodEffect != 0 {
            let sign = foodEffect > 0 ? "+" : ""
            effects.append("\(sign)\(foodEffect) Food")
        }
        if technologyEffect != 0 {
            let sign = technologyEffect > 0 ? "+" : ""
            effects.append("\(sign)\(technologyEffect) Technology")
        }

        return effects.isEmpty ? "No direct effects" : effects.joined(separator: ", ")
    }

    // MARK: - Methods

    func activate(on turn: Int) {
        status = .active
        turnSigned = turn
        if let duration = durationTurns {
            turnExpires = turn + duration
        }
    }

    func suspend() {
        if status == .active {
            status = .suspended
        }
    }

    func resume() {
        if status == .suspended {
            status = .active
        }
    }

    func terminate() {
        status = .terminated
    }

    func checkExpiration(currentTurn: Int) {
        if let expires = turnExpires, currentTurn >= expires {
            status = .expired
        }
    }

    func processTurn() {
        guard isActive else { return }
        turnsActive += 1
        totalValueExchanged += abs(netEconomicImpact)
    }
}

// MARK: - Trade Agreement Templates

extension TradeAgreement {

    /// Create a basic trade agreement
    static func createBasicTrade(
        with country: ForeignCountry,
        tradeVolume: Int,
        turn: Int
    ) -> TradeAgreement {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: .basicTrade
        )

        agreement.agreementDescription = """
            Standard trade agreement establishing normal commercial relations between \
            the People's Socialist Republic and \(country.officialName). Trade goods \
            flow according to central planning requirements and mutual availability.
            """

        agreement.treasuryEffect = tradeVolume / 10
        agreement.relationshipEffect = 5
        agreement.durationTurns = 20 // 5 years

        return agreement
    }

    /// Create an arms export agreement
    static func createArmsExport(
        with country: ForeignCountry,
        value: Int,
        turn: Int
    ) -> TradeAgreement {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: .armsExport
        )

        agreement.agreementDescription = """
            Military equipment export contract with \(country.name). Includes small arms, \
            ammunition, and military vehicles. Training and maintenance support provided.
            """

        agreement.treasuryEffect = value
        agreement.industrialEffect = -2 // Diverts production
        agreement.relationshipEffect = 15
        agreement.standingEffect = country.politicalBloc == .socialist ? 5 : -3
        agreement.durationTurns = 12 // 3 years

        return agreement
    }

    /// Create an economic aid package (we give)
    static func createAidPackage(
        to country: ForeignCountry,
        amount: Int,
        turn: Int
    ) -> TradeAgreement {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: .aidPackage
        )

        agreement.agreementDescription = """
            Economic assistance package to support socialist construction in \(country.name). \
            Includes industrial equipment, technical advisors, and development loans.
            """

        agreement.treasuryEffect = -amount
        agreement.relationshipEffect = 25
        agreement.blocReputationEffect = 10
        agreement.standingEffect = 5

        return agreement
    }

    /// Create an oil import agreement
    static func createOilDeal(
        with country: ForeignCountry,
        volume: Int,
        favorableTerms: Bool,
        turn: Int
    ) -> TradeAgreement {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: .oilDeal
        )

        agreement.agreementDescription = """
            Petroleum import agreement with \(country.name). \(volume) million barrels annually \
            at \(favorableTerms ? "preferential" : "market") rates.
            """

        let baseCost = volume * (favorableTerms ? 2 : 3)
        agreement.treasuryEffect = -baseCost
        agreement.industrialEffect = volume / 5
        agreement.relationshipEffect = favorableTerms ? 10 : 5
        agreement.durationTurns = 8 // 2 years

        return agreement
    }

    /// Create a technical cooperation agreement
    static func createTechCooperation(
        with country: ForeignCountry,
        sector: String,
        turn: Int
    ) -> TradeAgreement {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: .technicalCooperation
        )

        agreement.agreementDescription = """
            Technical cooperation in \(sector) with \(country.name). Exchange of specialists, \
            joint research programs, and technology transfer.
            """

        agreement.treasuryEffect = -5
        agreement.technologyEffect = 3
        agreement.relationshipEffect = 10
        agreement.durationTurns = 16 // 4 years

        return agreement
    }
}

// MARK: - Starter Agreements

extension TradeAgreement {

    /// Create the initial trade agreements that exist at game start (turn 0).
    /// Returns agreements with Soviet Union, Czechoslovakia, and Poland.
    static func createStarterAgreements(
        countries: [ForeignCountry]
    ) -> [TradeAgreement] {
        var agreements: [TradeAgreement] = []

        // 1. Basic Trade Agreement with the Soviet Union
        if let soviet = countries.first(where: { $0.countryId == "soviet_union" }) {
            let trade = TradeAgreement(
                partnerId: soviet.countryId,
                partnerName: soviet.name,
                type: .basicTrade
            )
            trade.agreementName = "Soviet Trade Pact"
            trade.agreementDescription = """
                Foundational bilateral trade agreement with the Soviet Union, established \
                at the birth of the People's Socialist Republic. Soviet machinery and raw \
                materials flow in; agricultural goods and strategic minerals flow out.
                """
            trade.activate(on: 0)
            trade.treasuryEffect = 2
            trade.industrialEffect = 1
            trade.relationshipEffect = 5
            // Phase 3.6: machinery and raw materials flow in;
            // agricultural goods flow out.
            trade.commodityImports = [.iron: 3]
            trade.commodityExports = [.grain: 4]
            agreements.append(trade)
        }

        // 2. Technical Cooperation with Czechoslovakia
        if let czech = countries.first(where: { $0.countryId == "czechoslovakia" }) {
            let techCoop = TradeAgreement(
                partnerId: czech.countryId,
                partnerName: czech.name,
                type: .technicalCooperation
            )
            techCoop.agreementName = "Czech Technical Exchange"
            techCoop.agreementDescription = """
                Technology transfer and industrial cooperation with Czechoslovakia. \
                Czech engineers assist our factories while our specialists share \
                advances in mining and metallurgy.
                """
            techCoop.durationTurns = 20
            techCoop.activate(on: 0)
            techCoop.industrialEffect = 1
            techCoop.technologyEffect = 1
            techCoop.relationshipEffect = 5
            // Phase 3.6: Czech industry sends aluminum stock in
            // exchange for our agricultural surplus.
            techCoop.commodityImports = [.aluminum: 2]
            techCoop.commodityExports = [.grain: 2]
            agreements.append(techCoop)
        }

        // 3. Oil Agreement with Poland (coal-for-oil barter)
        if let poland = countries.first(where: { $0.countryId == "poland" }) {
            let oil = TradeAgreement(
                partnerId: poland.countryId,
                partnerName: poland.name,
                type: .oilDeal
            )
            oil.agreementName = "Polish Energy Accord"
            oil.agreementDescription = """
                Energy cooperation agreement with Poland. Polish coal supplements our \
                domestic supply while we provide petroleum products at preferential \
                rates, keeping both nations' factories running.
                """
            oil.durationTurns = 16
            oil.activate(on: 0)
            oil.treasuryEffect = 1
            oil.industrialEffect = 1
            oil.relationshipEffect = 5
            // Phase 3.6: the coal-for-oil barter the description mentions
            // — Polish coal in, our petroleum out.
            oil.commodityImports = [.coal: 4]
            oil.commodityExports = [.oil: 3]
            agreements.append(oil)
        }

        return agreements
    }
}

// MARK: - Commodity Flow Codec (Phase 3.6)

private func decodeCommodityFlow(from data: Data?) -> [StrategicResource: Int] {
    guard let data = data else { return [:] }
    do {
        let raw = try JSONDecoder().decode([String: Int].self, from: data)
        var result: [StrategicResource: Int] = [:]
        for (key, value) in raw {
            if let resource = StrategicResource(rawValue: key) {
                result[resource] = value
            }
        }
        return result
    } catch {
        return [:]
    }
}

private func encodeCommodityFlow(_ flow: [StrategicResource: Int]) -> Data? {
    guard !flow.isEmpty else { return nil }
    let raw = Dictionary(uniqueKeysWithValues: flow.map { ($0.key.rawValue, $0.value) })
    return try? JSONEncoder().encode(raw)
}

// MARK: - Sanctions

enum SanctionType: String, Codable, CaseIterable {
    case tradeEmbargo           // Complete trade ban
    case armsEmbargo            // Weapons only
    case technologyBan          // Tech transfer prohibition
    case financialSanctions     // Banking restrictions
    case diplomaticRestrictions // Reduced diplomatic contact

    var displayName: String {
        switch self {
        case .tradeEmbargo: return "Trade Embargo"
        case .armsEmbargo: return "Arms Embargo"
        case .technologyBan: return "Technology Ban"
        case .financialSanctions: return "Financial Sanctions"
        case .diplomaticRestrictions: return "Diplomatic Restrictions"
        }
    }

    var severity: Int {
        switch self {
        case .tradeEmbargo: return 5
        case .armsEmbargo: return 3
        case .technologyBan: return 4
        case .financialSanctions: return 4
        case .diplomaticRestrictions: return 2
        }
    }
}

struct ActiveSanction: Codable, Identifiable {
    var id: String = UUID().uuidString
    var sanctionType: SanctionType
    var targetCountryId: String
    var reason: String
    var turnImposed: Int
    var imposedByUs: Bool           // True if we imposed it, false if imposed on us
    var multilateral: Bool          // Multiple countries participating

    var displayName: String {
        "\(sanctionType.displayName) \(imposedByUs ? "against" : "from") target"
    }
}
