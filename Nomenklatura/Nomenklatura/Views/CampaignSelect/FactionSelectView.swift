//
//  FactionSelectView.swift
//  Nomenklatura
//
//  Faction selection screen - choose your political background
//

import SwiftUI

struct FactionSelectView: View {
    let factions: [PlayerFactionConfig]
    let onFactionSelected: (String) -> Void
    let onBack: () -> Void
    @Environment(\.theme) var theme

    @State private var selectedIndex: Int = 0
    @State private var showingDetails: Bool = false

    var body: some View {
        ZStack {
            // Dark background
            theme.schemeDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                // Faction cards - with room for page indicators below
                TabView(selection: $selectedIndex) {
                    ForEach(Array(factions.enumerated()), id: \.element.id) { index, faction in
                        PlayerFactionCardView(
                            faction: faction,
                            isSelected: selectedIndex == index,
                            onSelect: {
                                onFactionSelected(faction.id)
                            }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))  // Hide default, use custom below

                // Custom page indicator
                HStack(spacing: 8) {
                    ForEach(0..<factions.count, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? theme.accentGold : Color(hex: "555555"))
                            .frame(width: index == selectedIndex ? 10 : 8, height: index == selectedIndex ? 10 : 8)
                    }
                }
                .padding(.top, 10)

                // Page indicator text
                pageIndicatorText

                Spacer(minLength: 20)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("BACK")
                    }
                    .font(theme.tagFont)
                    .foregroundColor(theme.accentGold)
                }
                Spacer()
            }
            .padding(.horizontal, 20)

            Text("CHOOSE YOUR BACKGROUND")
                .font(theme.headerFontLarge)
                .tracking(3)
                .foregroundColor(theme.schemeText)

            Text("Your origins shape how the Party factions view you")
                .font(theme.bodyFontSmall)
                .foregroundColor(Color(hex: "888888"))

            // Clarification text
            Text("Affects starting stats and relationships with Military, Party, Security, and Industry")
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "666666"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 4)
        }
        .padding(.top, 50)
        .padding(.bottom, 20)
    }

    // MARK: - Page Indicator

    private var pageIndicatorText: some View {
        Text("\(selectedIndex + 1) of \(factions.count)")
            .font(theme.tagFont)
            .foregroundColor(Color(hex: "666666"))
            .padding(.top, 10)
    }
}

// MARK: - Player Faction Card View

struct PlayerFactionCardView: View {
    let faction: PlayerFactionConfig
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Faction header
                    factionHeader

                    // Description
                    Text(faction.description)
                        .font(theme.bodyFont)
                        .foregroundColor(Color(hex: "CCCCCC"))
                        .lineSpacing(4)

                    // Historical basis
                    Text(faction.historicalBasis)
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(Color(hex: "888888"))
                        .padding(.bottom, 8)

                    Divider()
                        .background(Color(hex: "444444"))

                    // Benefits section
                    benefitsSection

                    Divider()
                        .background(Color(hex: "444444"))

                    // Drawbacks section
                    drawbacksSection

                    // Special ability
                    if let ability = faction.specialAbility {
                        abilitySection(ability)
                    }

                    // Vulnerability
                    if let vulnerability = faction.vulnerability {
                        vulnerabilitySection(vulnerability)
                    }

                    // Spacer to ensure content doesn't get cut off
                    Spacer()
                        .frame(height: 20)
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)

            // Select button - with padding to ensure it's above page indicators
            selectButton
                .padding(.bottom, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "1A1A1A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? theme.accentGold : Color(hex: "333333"), lineWidth: isSelected ? 2 : 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 60)  // Extra padding to clear page indicators
    }

    // MARK: - Faction Header

    private var factionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(faction.name.uppercased())
                .font(theme.headerFont)
                .tracking(2)
                .foregroundColor(theme.schemeText)

            Text(faction.subtitle)
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.accentGold)
        }
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(Color(hex: "4CAF50"))
                Text("BENEFITS")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(Color(hex: "4CAF50"))
            }

            ForEach(faction.benefitStrings, id: \.self) { benefit in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "4CAF50"))
                        .frame(width: 16)
                    Text(benefit)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(Color(hex: "AAAAAA"))
                }
            }
        }
    }

    // MARK: - Drawbacks Section

    private var drawbacksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(Color(hex: "F44336"))
                Text("DRAWBACKS")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(Color(hex: "F44336"))
            }

            ForEach(faction.drawbackStrings, id: \.self) { drawback in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Color(hex: "F44336"))
                        .frame(width: 16)
                    Text(drawback)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(Color(hex: "AAAAAA"))
                }
            }
        }
    }

    // MARK: - Ability Section

    private func abilitySection(_ ability: FactionAbility) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color(hex: "444444"))

            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(theme.accentGold)
                Text("SPECIAL ABILITY")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.accentGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(ability.name)
                    .font(theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.schemeText)

                Text(ability.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(Color(hex: "AAAAAA"))
            }
        }
    }

    // MARK: - Vulnerability Section

    private func vulnerabilitySection(_ vulnerability: FactionVulnerability) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color(hex: "444444"))

            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(hex: "FF9800"))
                Text("VULNERABILITY")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(Color(hex: "FF9800"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(vulnerability.name)
                    .font(theme.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.schemeText)

                Text(vulnerability.description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(Color(hex: "AAAAAA"))
            }
        }
    }

    // MARK: - Select Button

    private var selectButton: some View {
        Button(action: onSelect) {
            Text("CHOOSE THIS PATH")
                .font(theme.tagFont)
                .tracking(2)
                .foregroundColor(theme.schemeDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.accentGold)
        }
    }
}

// MARK: - Preview

#Preview {
    FactionSelectView(
        factions: PlayerFactionConfig.allFactions,
        onFactionSelected: { factionId in
            print("Selected faction: \(factionId)")
        },
        onBack: {
            print("Back pressed")
        }
    )
    .environment(\.theme, ColdWarTheme())
}
