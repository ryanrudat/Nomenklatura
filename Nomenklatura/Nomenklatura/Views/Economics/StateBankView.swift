//
//  StateBankView.swift
//  Nomenklatura
//
//  State Bank — the Communist alternative to capitalist banking.
//  Three lending channels: Gosbank (domestic), Socialist Bloc, Western/IMF.
//

import SwiftUI
import SwiftData

struct StateBankView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSource: StateBankLoanSource = .gosbank
    @State private var pendingOffer: StateBankLoanTerms?
    @State private var pendingPrincipal: Double = 0
    @State private var showConfirmation: Bool = false
    @State private var pendingEarlyRepay: StateBankLoan?
    @State private var errorMessage: String?

    private var offers: [StateBankLoanTerms] {
        StateBankLoanTerms.offers(for: selectedSource)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    statusRow
                    sourceTabs
                    offersSection
                    activeLoansSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .padding(.bottom, 40)
            }
            .background(FiftiesColors.agedPaper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(theme.accentGold)
                }
            }
            .alert("Confirm Loan Agreement", isPresented: $showConfirmation, presenting: pendingOffer) { terms in
                Button("Sign", role: .destructive) { executeLoan(terms: terms) }
                Button("Cancel", role: .cancel) { pendingOffer = nil }
            } message: { terms in
                Text("Borrow \(Int(pendingPrincipal)) from \(terms.lenderName) at \(terms.percentRateDisplay) for \(terms.durationTurns) turns.\n\nPer-turn payment: \(terms.perTurnPayment(for: Int(pendingPrincipal))).\n\n\(terms.sideEffectDescription)")
            }
            .alert("Early Repayment", isPresented: Binding(get: { pendingEarlyRepay != nil }, set: { if !$0 { pendingEarlyRepay = nil } })) {
                Button("Pay Off (90%)", role: .destructive) {
                    if let loan = pendingEarlyRepay {
                        executeEarlyRepay(loan: loan)
                    }
                    pendingEarlyRepay = nil
                }
                Button("Cancel", role: .cancel) { pendingEarlyRepay = nil }
            } message: {
                if let loan = pendingEarlyRepay {
                    Text("Pay \(loan.earlyRepaymentCost) treasury now to close this \(loan.source.displayName) loan (90% of remaining obligation).")
                }
            }
            .alert("Cannot Proceed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("STATE BANK")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundColor(theme.accentGold)
            Text("Gosbank · Socialist Credit · Foreign Financing")
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
            Rectangle()
                .fill(theme.accentGold.opacity(0.3))
                .frame(height: 1)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatBox(label: "Active Loans", value: "\(game.activeLoanCount) / 3", tint: game.canTakeNewLoan ? theme.inkBlack : FiftiesColors.stampRed)
            StatBox(label: "Outstanding", value: "\(game.totalOutstandingDebt)", tint: theme.inkBlack)
            StatBox(label: "Debt/Turn", value: "\(game.totalDebtService)", tint: FiftiesColors.stampRed)
            StatBox(label: "Treasury", value: "\(game.treasury)", tint: theme.accentGold)
        }
    }

    // MARK: - Source Tabs

    private var sourceTabs: some View {
        HStack(spacing: 8) {
            ForEach(StateBankLoanSource.allCases) { src in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedSource = src }
                } label: {
                    Text(src.shortLabel)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(selectedSource == src ? .white : theme.inkGray)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedSource == src ? theme.sovietRed : FiftiesColors.cardstock)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(theme.borderTan, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Offers Section

    private var offersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedSource.displayName.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Text(selectedSource.tagline)
                .font(.system(size: 11))
                .foregroundColor(theme.inkLight)
                .padding(.bottom, 4)

            ForEach(Array(offers.enumerated()), id: \.offset) { _, terms in
                offerCard(terms: terms)
            }
        }
    }

    private func offerCard(terms: StateBankLoanTerms) -> some View {
        let eligibility = EconomyService.shared.eligibility(for: terms, game: game)
        let available = eligibility.isOk

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(terms.lenderName.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)
                Spacer()
                if !available {
                    Text("UNAVAILABLE")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.stampRed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FiftiesColors.stampRed.opacity(0.1))
                        .cornerRadius(3)
                }
            }

            HStack(spacing: 14) {
                termPill(label: "Rate",     value: terms.percentRateDisplay,       color: rateColor(terms))
                termPill(label: "Duration", value: "\(terms.durationTurns)t",      color: theme.inkBlack)
                termPill(label: "Default",  value: "\(terms.defaultPrincipal)",    color: theme.accentGold)
                termPill(label: "Max",      value: "\(terms.maxPrincipal)",        color: theme.inkGray)
            }

            Text(terms.requirementDescription)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)

            Text(terms.sideEffectDescription)
                .font(.system(size: 10))
                .foregroundColor(.orange)

            if !available, let reason = eligibility.reason {
                Text(reason)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(FiftiesColors.stampRed)
            }

            Button(action: {
                pendingOffer = terms
                pendingPrincipal = Double(terms.defaultPrincipal)
                if !available {
                    errorMessage = eligibility.reason
                    pendingOffer = nil
                } else {
                    showConfirmation = true
                }
            }) {
                Text("REQUEST LOAN")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(available ? FiftiesColors.leatherBrown : Color.gray.opacity(0.5))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!available)
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func termPill(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(theme.inkLight)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
    }

    // MARK: - Active Loans Section

    private var activeLoansSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVE LOANS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.inkGray)
                .padding(.top, 8)

            if game.activeStateBankLoans.isEmpty {
                Text("No active State Bank loans.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkLight)
                    .padding(.vertical, 6)
            } else {
                ForEach(game.activeStateBankLoans) { loan in
                    activeLoanCard(loan: loan)
                }
            }
        }
    }

    private func activeLoanCard(loan: StateBankLoan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(loan.source.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)
                Spacer()
                if loan.isInDefault {
                    Text("DEFAULT")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(FiftiesColors.stampRed)
                        .cornerRadius(3)
                }
            }

            HStack(spacing: 14) {
                termPill(label: "Principal",  value: "\(loan.principal)",              color: theme.accentGold)
                termPill(label: "Rate",       value: loan.percentRateDisplay,          color: theme.inkBlack)
                termPill(label: "Payment",    value: "\(loan.perTurnPayment)/t",       color: FiftiesColors.stampRed)
                termPill(label: "Remaining",  value: "\(loan.turnsRemaining)t",        color: theme.inkBlack)
            }

            // Repayment progress
            GeometryReader { geo in
                let progress = loan.totalTurns > 0
                    ? CGFloat(loan.totalTurns - loan.turnsRemaining) / CGFloat(loan.totalTurns)
                    : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.parchmentDark)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.accentGold)
                        .frame(width: geo.size.width * max(0, min(1, progress)), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Paid: \(loan.totalPaid) / \(loan.totalRepayment)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.inkGray)
                Spacer()
                Button(action: {
                    if game.treasury < loan.earlyRepaymentCost {
                        errorMessage = "Treasury insufficient for early repayment (need \(loan.earlyRepaymentCost))."
                    } else {
                        pendingEarlyRepay = loan
                    }
                }) {
                    Text("PAY OFF (\(loan.earlyRepaymentCost))")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(FiftiesColors.leatherBrown)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(FiftiesColors.cardstock.opacity(0.7))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(loan.isInDefault ? FiftiesColors.stampRed : theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func rateColor(_ terms: StateBankLoanTerms) -> Color {
        switch terms.interestRate * 100 {
        case 0...3:   return FiftiesColors.approvedGreen
        case 3.01...5: return .orange
        default:      return FiftiesColors.stampRed
        }
    }

    private func executeLoan(terms: StateBankLoanTerms) {
        let loan = EconomyService.shared.takeStateBankLoan(
            game: game,
            terms: terms,
            principal: Int(pendingPrincipal)
        )
        if loan == nil {
            errorMessage = "Loan could not be issued."
        }
        pendingOffer = nil
    }

    private func executeEarlyRepay(loan: StateBankLoan) {
        let ok = EconomyService.shared.earlyRepay(loan: loan, game: game)
        if !ok {
            errorMessage = "Treasury insufficient for early repayment."
        }
    }
}

// MARK: - Stat Box

private struct StatBox: View {
    let label: String
    let value: String
    let tint: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(FiftiesColors.cardstock)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.borderTan, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, StateBankLoan.self, configurations: config)
    let game = Game(campaignId: "cold_war")
    return StateBankView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
