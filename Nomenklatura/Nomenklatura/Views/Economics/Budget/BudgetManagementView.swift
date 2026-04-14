//
//  BudgetManagementView.swift
//  Nomenklatura
//
//  Interactive state budget view with income/expense breakdown and priority controls
//

import SwiftUI

struct BudgetManagementView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var report: EconomyService.EconomicReport {
        if let data = game.lastEconomicReport,
           let decoded = EconomyService.shared.decodeReport(data) {
            return decoded
        }
        return EconomyService.shared.calculateTurnEconomy(game: game)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            budgetHeader
            netBalanceSummary
            incomeSection
            expenseSection
            allocationControls
        }
        .padding(.horizontal, 15)
        .padding(.bottom, 120)
    }

    // MARK: - Header

    private var budgetHeader: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 2)

            Text("STATE BUDGET ALLOCATION")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.inkBlack)

            Rectangle()
                .fill(theme.accentGold)
                .frame(height: 2)
        }
    }

    // MARK: - Net Balance

    private var netBalanceSummary: some View {
        VStack(spacing: 8) {
            HStack {
                Text("NET BALANCE PER TURN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: report.netChange >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 12))
                    Text("\(report.netChange > 0 ? "+" : "")\(report.netChange)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                }
                .foregroundColor(report.netChange >= 0 ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)
            }

            HStack(spacing: 0) {
                summaryCell(value: "\(report.totalIncome)", label: "INCOME", color: FiftiesColors.approvedGreen)
                summaryDivider
                summaryCell(value: "\(report.totalExpenses)", label: "EXPENSES", color: FiftiesColors.stampRed)
                summaryDivider
                summaryCell(value: "\(game.treasury)", label: "TREASURY", color: theme.accentGold)
            }
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Income Section

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("INCOME SOURCES", icon: "arrow.down.circle.fill", color: FiftiesColors.approvedGreen)

            VStack(spacing: 0) {
                budgetRow(label: "Domestic Production", value: report.domesticProduction, isIncome: true)
                budgetRow(label: "Foreign Trade", value: report.foreignTrade, isIncome: true)
                budgetRow(label: "Resource Extraction", value: report.resourceExtraction, isIncome: true)
                budgetRow(label: "Foreign Aid", value: report.foreignAid, isIncome: true)
                if report.tradeAgreementBonus > 0 {
                    budgetRow(label: "Trade Agreements", value: report.tradeAgreementBonus, isIncome: true)
                }

                Divider().background(theme.borderTan)

                HStack {
                    Text("TOTAL INCOME")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("+\(report.totalIncome)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.approvedGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(FiftiesColors.cardstock)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    // MARK: - Expense Section

    private var expenseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("EXPENDITURES", icon: "arrow.up.circle.fill", color: FiftiesColors.stampRed)

            VStack(spacing: 0) {
                budgetRow(label: "Military Spending", value: report.militarySpending, isIncome: false)
                budgetRow(label: "Social Programs", value: report.socialPrograms, isIncome: false)
                budgetRow(label: "Infrastructure", value: report.infrastructureCosts, isIncome: false)
                budgetRow(label: "Debt Payments", value: report.debtPayments, isIncome: false)
                if report.crisisResponse > 0 {
                    budgetRow(label: "Crisis Response", value: report.crisisResponse, isIncome: false)
                }
                budgetRow(label: "Corruption/Inefficiency", value: report.corruption, isIncome: false)
                if report.embargoEffects > 0 {
                    budgetRow(label: "Embargo Losses", value: report.embargoEffects, isIncome: false)
                }
                if report.warCosts > 0 {
                    budgetRow(label: "War Costs", value: report.warCosts, isIncome: false)
                }

                Divider().background(theme.borderTan)

                HStack {
                    Text("TOTAL EXPENSES")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("-\(report.totalExpenses)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.stampRed)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .background(FiftiesColors.cardstock)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
    }

    // MARK: - Allocation Controls

    private var allocationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("BUDGET PRIORITIES", icon: "slider.horizontal.3", color: theme.accentGold)

            Text("Adjust allocation percentages. Total must equal 100%.")
                .font(.system(size: 9))
                .foregroundColor(theme.inkGray)

            VStack(spacing: 0) {
                priorityRow(key: "military", label: "MILITARY ALLOCATION", icon: "shield.fill")
                priorityRow(key: "social", label: "SOCIAL PROGRAMS", icon: "person.3.fill")
                priorityRow(key: "infrastructure", label: "INFRASTRUCTURE", icon: "road.lanes")
                priorityRow(key: "reserve", label: "STRATEGIC RESERVE", icon: "lock.fill")
            }
            .background(FiftiesColors.cardstock)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.borderTan, lineWidth: 1)
            )

            // Total indicator
            HStack {
                Spacer()
                let total = game.budgetPriorities.values.reduce(0, +)
                Text("TOTAL: \(total)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(total == 100 ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)
            }
        }
    }

    // MARK: - Subviews

    private func summaryCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }

    private var summaryDivider: some View {
        Rectangle()
            .fill(theme.borderTan)
            .frame(width: 1, height: 30)
    }

    private func sectionLabel(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)
        }
    }

    private func budgetRow(label: String, value: Int, isIncome: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(theme.inkBlack)
                Spacer()
                Text("\(isIncome ? "+" : "-")\(value)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isIncome ? FiftiesColors.approvedGreen : FiftiesColors.stampRed)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            Divider()
                .background(theme.borderTan.opacity(0.5))
        }
    }

    private func priorityRow(key: String, label: String, icon: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(theme.accentGold)
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        adjustPriority(key, delta: -5)
                    } label: {
                        Text("\u{2212}")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(FiftiesColors.stampRed)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPriority(key) <= 0)

                    Text("\(currentPriority(key))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.inkBlack)
                        .frame(width: 48)

                    Button {
                        adjustPriority(key, delta: 5)
                    } label: {
                        Text("+")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(FiftiesColors.approvedGreen)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPriority(key) >= 100)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()
                .background(theme.borderTan.opacity(0.5))
        }
    }

    // MARK: - Priority Logic

    private func currentPriority(_ key: String) -> Int {
        game.budgetPriorities[key] ?? 0
    }

    private func adjustPriority(_ key: String, delta: Int) {
        var priorities = game.budgetPriorities
        let oldValue = priorities[key] ?? 0
        let newValue = max(0, min(100, oldValue + delta))
        let actualDelta = newValue - oldValue

        guard actualDelta != 0 else { return }

        priorities[key] = newValue

        // Compensate: reduce the largest other category
        let otherKeys = priorities.keys.filter { $0 != key }
        if let largestKey = otherKeys.max(by: { (priorities[$0] ?? 0) < (priorities[$1] ?? 0) }) {
            let largestValue = priorities[largestKey] ?? 0
            priorities[largestKey] = max(0, largestValue - actualDelta)
        }

        game.budgetPriorities = priorities
    }
}
