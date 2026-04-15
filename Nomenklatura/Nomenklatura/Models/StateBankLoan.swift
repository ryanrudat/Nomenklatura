//
//  StateBankLoan.swift
//  Nomenklatura
//
//  State Bank loan system — the communist alternative to capitalist banking.
//  All lending is managed by the state through three channels:
//    1. Gosbank (domestic money printing)
//    2. Socialist Bloc (fraternal loans from USSR/DDR/China)
//    3. Western/IMF (structural adjustment loans with liberalization demands)
//

import Foundation
import SwiftData

// MARK: - Loan Source Kind

/// The three kinds of loan sources available to a Communist state.
enum StateBankLoanSource: String, Codable, CaseIterable, Identifiable {
    case gosbank            // Domestic money-printing (inflationary)
    case socialistBloc      // Fraternal socialist loans
    case western            // Western/IMF loans (liberalization pressure)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gosbank:       return "Gosbank (State Bank)"
        case .socialistBloc: return "Socialist Bloc"
        case .western:       return "Western / IMF"
        }
    }

    var shortLabel: String {
        switch self {
        case .gosbank:       return "GOSBANK"
        case .socialistBloc: return "BLOC"
        case .western:       return "WESTERN"
        }
    }

    var tagline: String {
        switch self {
        case .gosbank:       return "Domestic monetary emission — requires Standing Committee approval."
        case .socialistBloc: return "Fraternal aid from USSR or DDR — requires socialist discipline."
        case .western:       return "Structural adjustment credit — demands liberalization."
        }
    }
}

// MARK: - StateBankLoan Model

/// A single active loan managed by the State Bank.
@Model
final class StateBankLoan {
    @Attribute(.unique) var id: UUID

    /// Source channel (gosbank, socialistBloc, western)
    var sourceRaw: String

    /// Lender country identifier (nil for gosbank domestic)
    var lenderCountryID: String?

    /// Original principal amount (added to treasury on acceptance)
    var principal: Int

    /// Annual interest rate as a decimal (0.02 = 2%)
    var interestRate: Double

    /// Total repayment duration in turns
    var totalTurns: Int

    /// Turns remaining until fully repaid
    var turnsRemaining: Int

    /// Running total of amount repaid so far (principal + interest)
    var totalPaid: Int

    /// Whether this loan is in default due to insufficient treasury
    var isInDefault: Bool

    /// Turn when the loan was originated (for reporting)
    var turnTaken: Int

    init(
        id: UUID = UUID(),
        source: StateBankLoanSource,
        lenderCountryID: String? = nil,
        principal: Int,
        interestRate: Double,
        totalTurns: Int,
        turnTaken: Int = 0
    ) {
        self.id = id
        self.sourceRaw = source.rawValue
        self.lenderCountryID = lenderCountryID
        self.principal = principal
        self.interestRate = interestRate
        self.totalTurns = max(1, totalTurns)
        self.turnsRemaining = max(1, totalTurns)
        self.totalPaid = 0
        self.isInDefault = false
        self.turnTaken = turnTaken
    }

    // MARK: - Derived

    var source: StateBankLoanSource {
        StateBankLoanSource(rawValue: sourceRaw) ?? .gosbank
    }

    /// Fixed payment per turn: principal * (1 + rate) / totalTurns (rounded up)
    var perTurnPayment: Int {
        let total = Double(principal) * (1.0 + interestRate)
        let perTurn = total / Double(max(1, totalTurns))
        return max(1, Int(perTurn.rounded(.up)))
    }

    /// Total amount that will be repaid over the life of the loan
    var totalRepayment: Int {
        perTurnPayment * totalTurns
    }

    /// Remaining amount owed (approximation based on turns left)
    var remainingOwed: Int {
        max(0, perTurnPayment * turnsRemaining)
    }

    /// Early-repayment cost: 90% of the remaining owed
    var earlyRepaymentCost: Int {
        max(1, Int((Double(remainingOwed) * 0.9).rounded(.up)))
    }

    var isFullyPaid: Bool { turnsRemaining <= 0 }

    var percentRateDisplay: String {
        let pct = interestRate * 100
        if pct == pct.rounded() {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }
}

// MARK: - Loan Terms Catalog

/// Static terms for each loan source, used when presenting offers to the player.
struct StateBankLoanTerms {
    let source: StateBankLoanSource
    let lenderCountryID: String?
    let lenderName: String
    let interestRate: Double
    let durationTurns: Int
    let defaultPrincipal: Int
    let minPrincipal: Int
    let maxPrincipal: Int
    let requirementDescription: String
    let sideEffectDescription: String

    /// Preset offers the player can request from the State Bank.
    static func offers() -> [StateBankLoanTerms] {
        [
            // GOSBANK — domestic money printing
            StateBankLoanTerms(
                source: .gosbank,
                lenderCountryID: nil,
                lenderName: "Gosbank",
                interestRate: 0.02,
                durationTurns: 10,
                defaultPrincipal: 20,
                minPrincipal: 10,
                maxPrincipal: 40,
                requirementDescription: "Requires Standing Committee approval.",
                sideEffectDescription: "Adds +2–5% inflation. Treasury +principal immediately."
            ),
            // SOCIALIST BLOC — USSR
            StateBankLoanTerms(
                source: .socialistBloc,
                lenderCountryID: "soviet_union",
                lenderName: "Soviet Union (Gosbank SSSR)",
                interestRate: 0.025,
                durationTurns: 15,
                defaultPrincipal: 25,
                minPrincipal: 10,
                maxPrincipal: 50,
                requirementDescription: "Relationship > 40 with USSR. Must maintain Command Economy.",
                sideEffectDescription: "Sets 'socialist_loan_obligation' flag. Bloc monitors policy drift."
            ),
            // SOCIALIST BLOC — DDR
            StateBankLoanTerms(
                source: .socialistBloc,
                lenderCountryID: "east_germany",
                lenderName: "DDR (Staatsbank)",
                interestRate: 0.03,
                durationTurns: 15,
                defaultPrincipal: 15,
                minPrincipal: 10,
                maxPrincipal: 30,
                requirementDescription: "Relationship > 40 with DDR. Must maintain Command Economy.",
                sideEffectDescription: "Sets 'socialist_loan_obligation' flag."
            ),
            // WESTERN — IMF
            StateBankLoanTerms(
                source: .western,
                lenderCountryID: "imf",
                lenderName: "International Monetary Fund",
                interestRate: 0.07,
                durationTurns: 20,
                defaultPrincipal: 40,
                minPrincipal: 20,
                maxPrincipal: 80,
                requirementDescription: "International Standing > 50.",
                sideEffectDescription: "Sets 'western_loan_obligation' flag. Elite loyalty −3 on signing."
            ),
            // WESTERN — USA
            StateBankLoanTerms(
                source: .western,
                lenderCountryID: "united_states",
                lenderName: "United States (Export-Import Bank)",
                interestRate: 0.05,
                durationTurns: 20,
                defaultPrincipal: 30,
                minPrincipal: 15,
                maxPrincipal: 60,
                requirementDescription: "International Standing > 50.",
                sideEffectDescription: "Sets 'western_loan_obligation' flag. Elite loyalty −3 on signing."
            )
        ]
    }

    static func offers(for source: StateBankLoanSource) -> [StateBankLoanTerms] {
        offers().filter { $0.source == source }
    }

    /// Projected per-turn payment for a given principal under these terms.
    func perTurnPayment(for principal: Int) -> Int {
        let total = Double(principal) * (1.0 + interestRate)
        return max(1, Int((total / Double(max(1, durationTurns))).rounded(.up)))
    }

    var percentRateDisplay: String {
        let pct = interestRate * 100
        if pct == pct.rounded() { return "\(Int(pct))%" }
        return String(format: "%.1f%%", pct)
    }
}
