//
//  LoanProposalSheet.swift
//  Nomenklatura
//
//  Foreign loan proposal interface - request financing from international lenders
//  Soviet 1950s aesthetic: official financial documents with monospaced text
//

import SwiftUI

struct LoanProposalSheet: View {
    @Bindable var game: Game
    @Binding var isPresented: Bool
    @Environment(\.theme) var theme
    @State private var selectedSource: LoanSource?
    @State private var loanAmount: Double = 10
    @State private var showConfirmation = false

    private var availableSources: [(source: LoanSource, relationship: Int, available: Bool)] {
        EconomyService.shared.availableLoanSources(game: game)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    sheetHeader

                    // Loan capacity status
                    loanCapacityBar

                    // Source selection
                    if selectedSource == nil {
                        loanSourceList
                    } else {
                        loanConfigView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(FiftiesColors.agedPaper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if selectedSource != nil {
                            selectedSource = nil
                        } else {
                            isPresented = false
                        }
                    }
                    .foregroundColor(theme.inkGray)
                }
            }
            .alert("Confirm Loan Agreement", isPresented: $showConfirmation) {
                Button("Sign Agreement", role: .destructive) {
                    executeLoan()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let source = selectedSource {
                    let amount = Int(loanAmount)
                    let relationship = availableSources.first(where: { $0.source.id == source.id })?.relationship ?? 0
                    let rate = source.interestRate(forRelationship: relationship)
                    Text("Borrow \(amount) from \(source.lenderName) at \(rate)% interest for \(source.durationTurns) turns. Payment: ~\(estimatedPayment(amount: amount, rate: rate, duration: source.durationTurns))/turn.")
                }
            }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        VStack(spacing: 6) {
            Text("MINISTRY OF FINANCE")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.accentGold)

            Text("Foreign Financing Request")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)

            Rectangle()
                .fill(theme.accentGold.opacity(0.3))
                .frame(height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Loan Capacity

    private var loanCapacityBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active Loans")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkLight)
                Text("\(game.activeLoanCount) / 3")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(game.canTakeNewLoan ? theme.inkBlack : FiftiesColors.stampRed)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Outstanding Debt")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkLight)
                Text("\(game.totalOutstandingDebt)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.inkBlack)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("Treasury")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.inkLight)
                Text("\(game.treasury)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.accentGold)
            }
        }
        .padding(10)
        .background(FiftiesColors.cardstock)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Source List

    private var loanSourceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AVAILABLE LENDERS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(availableSources, id: \.source.id) { entry in
                LoanSourceCard(
                    source: entry.source,
                    relationship: entry.relationship,
                    available: entry.available,
                    onSelect: {
                        selectedSource = entry.source
                        loanAmount = Double(max(5, entry.source.maxAmount / 2))
                    }
                )
            }
        }
    }

    // MARK: - Loan Configuration

    private var loanConfigView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let source = selectedSource {
                let entry = availableSources.first(where: { $0.source.id == source.id })
                let relationship = entry?.relationship ?? 0
                let rate = source.interestRate(forRelationship: relationship)
                let amount = Int(loanAmount)

                // Lender info
                VStack(alignment: .leading, spacing: 8) {
                    Text("LOAN TERMS FROM")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    Text(source.lenderName.uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Interest Rate")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("\(rate)%")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.stampRed)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duration")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("\(source.durationTurns) turns")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.inkBlack)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Max Amount")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("\(source.maxAmount)")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.accentGold)
                        }
                    }
                }
                .padding(12)
                .background(FiftiesColors.cardstock)
                .cornerRadius(8)

                // Amount slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("LOAN AMOUNT")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)
                        Spacer()
                        Text("\(amount)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentGold)
                    }

                    Slider(value: $loanAmount, in: 5...Double(source.maxAmount), step: 5)
                        .tint(theme.accentGold)

                    HStack {
                        Text("5")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(theme.inkLight)
                        Spacer()
                        Text("\(source.maxAmount)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(theme.inkLight)
                    }
                }

                // Payment projection
                VStack(alignment: .leading, spacing: 6) {
                    Text("REPAYMENT SCHEDULE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    let payment = estimatedPayment(amount: amount, rate: rate, duration: source.durationTurns)
                    let totalCost = payment * source.durationTurns
                    let totalInterest = totalCost - amount

                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Per Turn")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("-\(payment)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.stampRed)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Interest")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("\(totalInterest)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total Cost")
                                .font(.system(size: 9))
                                .foregroundColor(theme.inkLight)
                            Text("\(totalCost)")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(theme.inkBlack)
                        }
                    }
                }
                .padding(10)
                .background(FiftiesColors.cardstock.opacity(0.5))
                .cornerRadius(6)

                // Conditions
                if !source.conditions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONDITIONS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)

                        ForEach(source.conditions, id: \.self) { condition in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text(condition)
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.inkBlack)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(6)
                }

                // Sign button
                Button(action: { showConfirmation = true }) {
                    HStack {
                        Image(systemName: "signature")
                            .font(.system(size: 12))
                        Text("SIGN LOAN AGREEMENT")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FiftiesColors.leatherBrown)
                    .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Helpers

    private func estimatedPayment(amount: Int, rate: Int, duration: Int) -> Int {
        guard duration > 0 else { return 0 }
        let interest = amount * rate / 100
        let principal = amount / duration
        return interest + principal
    }

    private func executeLoan() {
        guard let source = selectedSource else { return }
        let amount = Int(loanAmount)
        EconomyService.shared.takeLoan(game: game, source: source, amount: amount)
        isPresented = false
    }
}

// MARK: - Loan Source Card

private struct LoanSourceCard: View {
    let source: LoanSource
    let relationship: Int
    let available: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    private var rate: Int {
        source.interestRate(forRelationship: relationship)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.lenderName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(available ? theme.inkBlack : theme.inkLight)

                        Text(categoryLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(categoryColor)
                    }

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

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Rate")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight)
                        Text("\(rate)%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(available ? rateColor : theme.inkLight)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Max")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight)
                        Text("\(source.maxAmount)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(available ? theme.accentGold : theme.inkLight)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Duration")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight)
                        Text("\(source.durationTurns)t")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(available ? theme.inkBlack : theme.inkLight)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Relations")
                            .font(.system(size: 8))
                            .foregroundColor(theme.inkLight)
                        Text("\(relationship)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(available ? relationshipColor : theme.inkLight)
                    }
                }

                if !source.conditions.isEmpty {
                    Text(source.conditions.joined(separator: " | "))
                        .font(.system(size: 9))
                        .foregroundColor(theme.inkLight)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(available ? FiftiesColors.cardstock : FiftiesColors.cardstock.opacity(0.4))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(available ? theme.borderTan : theme.borderTan.opacity(0.5), lineWidth: 1)
            )
        }
        .disabled(!available)
    }

    private var categoryLabel: String {
        switch source.category {
        case .socialist: return "Socialist Bloc"
        case .western: return "Western"
        case .institutional: return "International Institution"
        }
    }

    private var categoryColor: Color {
        switch source.category {
        case .socialist: return FiftiesColors.stampRed
        case .western: return theme.steelBlue
        case .institutional: return FiftiesColors.leatherBrown
        }
    }

    private var rateColor: Color {
        switch rate {
        case 0...3: return FiftiesColors.approvedGreen
        case 4...5: return .orange
        default: return FiftiesColors.stampRed
        }
    }

    private var relationshipColor: Color {
        if relationship >= source.requiredRelationship + 20 { return FiftiesColors.approvedGreen }
        if relationship >= source.requiredRelationship { return .orange }
        return FiftiesColors.stampRed
    }
}
