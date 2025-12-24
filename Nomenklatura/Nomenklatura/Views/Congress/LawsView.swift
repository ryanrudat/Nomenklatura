//
//  LawsView.swift
//  Nomenklatura
//
//  Laws sub-tab for viewing and proposing changes to the legal code
//

import SwiftUI
import SwiftData

struct LawsView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedCategory: LawCategory = .institutional
    @State private var selectedLaw: Law?
    @State private var showingProposalSheet = false

    private var filteredLaws: [Law] {
        game.laws.filter { $0.lawCategory == selectedCategory }
            .sorted { $0.name < $1.name }
    }

    private var playerCanProposeLaws: Bool {
        // Must be on Standing Committee to propose laws
        // Current threshold: position 7+ (Senior Politburo)
        game.currentPositionIndex >= 7
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter bar
            LawCategoryBar(selectedCategory: $selectedCategory)
                .padding(.horizontal, 15)
                .padding(.top, 10)

            // Laws list
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Category description
                    CategoryHeaderCard(category: selectedCategory)
                        .padding(.horizontal, 15)
                        .padding(.top, 10)

                    // Laws in this category
                    ForEach(filteredLaws, id: \.id) { law in
                        LawCard(
                            law: law,
                            game: game,
                            canPropose: playerCanProposeLaws
                        ) {
                            selectedLaw = law
                            showingProposalSheet = true
                        }
                        .padding(.horizontal, 15)
                    }

                    // Empty state
                    if filteredLaws.isEmpty {
                        VStack(spacing: 10) {
                            Text("No laws in this category")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkGray)
                        }
                        .padding(30)
                    }

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            // Power consolidation meter at bottom
            PowerConsolidationMeter(score: game.powerConsolidationScore)
                .padding(.horizontal, 15)
                .padding(.bottom, 15)
        }
        .sheet(isPresented: $showingProposalSheet) {
            if let law = selectedLaw {
                LawProposalSheet(law: law, game: game)
            }
        }
    }
}

// MARK: - Category Filter Bar

struct LawCategoryBar: View {
    @Binding var selectedCategory: LawCategory
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(LawCategory.allCases, id: \.self) { category in
                LawCategoryButton(
                    category: category,
                    isSelected: selectedCategory == category
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
}

struct LawCategoryButton: View {
    let category: LawCategory
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Image(systemName: category.iconName)
                    .font(.system(size: 14))
                Text(category.displayName)
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? theme.sovietRed.opacity(0.15) : Color.clear)
            )
            .foregroundColor(isSelected ? theme.sovietRed : theme.inkGray)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Header Card

struct CategoryHeaderCard: View {
    let category: LawCategory
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.system(size: 24))
                .foregroundColor(theme.sovietRed)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(category.displayName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)

                Text(category.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkGray)
                    .lineLimit(2)
            }

            Spacer()

            // Modification difficulty indicator
            VStack(alignment: .trailing, spacing: 2) {
                Text("Difficulty")
                    .font(.system(size: 9))
                    .foregroundColor(theme.inkLight)
                Text("\(category.modificationDifficulty)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(difficultyColor)
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private var difficultyColor: Color {
        switch category.modificationDifficulty {
        case 70...: return .statLow
        case 50..<70: return .statMedium
        default: return .statHigh
        }
    }
}

// MARK: - Power Consolidation Meter

struct PowerConsolidationMeter: View {
    let score: Int
    @Environment(\.theme) var theme

    private var meterColor: Color {
        switch score {
        case 80...: return theme.sovietRed
        case 60..<80: return theme.accentGold
        case 40..<60: return .statMedium
        default: return theme.inkGray
        }
    }

    private var powerLevel: String {
        switch score {
        case 80...: return "SUPREME"
        case 60..<80: return "DOMINANT"
        case 40..<60: return "ESTABLISHED"
        case 20..<40: return "RISING"
        default: return "NASCENT"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("POWER CONSOLIDATION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text(powerLevel)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(meterColor)

                Text("\(score)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(meterColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.parchmentDark)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(meterColor)
                        .frame(width: geometry.size.width * CGFloat(score) / 100)

                    // Threshold markers
                    ForEach([40, 60, 80], id: \.self) { threshold in
                        Rectangle()
                            .fill(theme.inkLight.opacity(0.5))
                            .frame(width: 1)
                            .offset(x: geometry.size.width * CGFloat(threshold) / 100)
                    }
                }
            }
            .frame(height: 8)

            // Threshold labels
            HStack {
                Text("Social")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Economic")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Political")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)

                Spacer()

                Text("Institutional")
                    .font(.system(size: 8))
                    .foregroundColor(theme.inkLight)
            }
        }
        .padding(12)
        .background(theme.parchment)
        .overlay(
            Rectangle()
                .stroke(meterColor.opacity(0.3), lineWidth: 1)
        )
    }
}
