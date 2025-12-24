//
//  MultiNewspaperView.swift
//  Nomenklatura
//
//  Wrapper view for multiple newspaper perspectives (state vs samizdat)
//

import SwiftUI

struct MultiNewspaperView: View {
    let stateEdition: NewspaperEdition
    let samizdatEdition: NewspaperEdition?
    let onContinue: () -> Void
    @Environment(\.theme) var theme

    @State private var selectedPublication: PublicationType = .state

    /// Available publications for this turn
    private var availablePublications: [PublicationType] {
        var publications: [PublicationType] = [.state]
        if samizdatEdition != nil {
            publications.append(.samizdat)
        }
        return publications
    }

    var body: some View {
        VStack(spacing: 0) {
            // Publication tab bar (only if samizdat available)
            if samizdatEdition != nil {
                PublicationTabBar(
                    selectedPublication: $selectedPublication,
                    availablePublications: availablePublications
                )
            }

            // Content based on selection
            switch selectedPublication {
            case .state:
                NewspaperView(edition: stateEdition, onContinue: onContinue)
            case .samizdat:
                if let samizdat = samizdatEdition {
                    SamizdatView(edition: samizdat, onContinue: onContinue)
                } else {
                    NewspaperView(edition: stateEdition, onContinue: onContinue)
                }
            case .foreign:
                // Future: Foreign broadcast view
                NewspaperView(edition: stateEdition, onContinue: onContinue)
            }
        }
    }
}

// MARK: - Publication Tab Bar

private struct PublicationTabBar: View {
    @Binding var selectedPublication: PublicationType
    let availablePublications: [PublicationType]
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(availablePublications, id: \.self) { publication in
                PublicationTab(
                    publication: publication,
                    isSelected: selectedPublication == publication
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPublication = publication
                    }
                }
            }
        }
        .background(Color(hex: "2C2C2C"))
    }
}

private struct PublicationTab: View {
    let publication: PublicationType
    let isSelected: Bool
    let action: () -> Void

    private var tabLabel: String {
        switch publication {
        case .state:
            return "THE PEOPLE'S VOICE"
        case .samizdat:
            return "THE CHRONICLE"
        case .foreign:
            return "FOREIGN BROADCAST"
        }
    }

    private var tabIcon: String {
        switch publication {
        case .state:
            return "newspaper.fill"
        case .samizdat:
            return "doc.text.fill"
        case .foreign:
            return "antenna.radiowaves.left.and.right"
        }
    }

    private var tabColor: Color {
        switch publication {
        case .state:
            return Color(hex: "B22234")  // Soviet red
        case .samizdat:
            return Color(hex: "8B4513")  // Brown/sepia
        case .foreign:
            return Color(hex: "1E90FF")  // Blue for Western
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: tabIcon)
                        .font(.system(size: 12))

                    Text(tabLabel)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(isSelected ? .white : Color.white.opacity(0.5))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)

                // Selection indicator
                Rectangle()
                    .fill(isSelected ? tabColor : Color.clear)
                    .frame(height: 3)
            }
        }
        .buttonStyle(.plain)
        .background(isSelected ? tabColor.opacity(0.3) : Color.clear)
    }
}

// MARK: - Samizdat Unlock Banner

struct SamizdatUnlockBanner: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text("UNDERGROUND ACCESS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)

                Text("Your network has provided alternative information sources")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .foregroundColor(.white)
        .padding(10)
        .background(Color(hex: "8B4513"))
    }
}

// MARK: - Preview

#Preview("Multi-Newspaper with Samizdat") {
    let stateEdition = NewspaperEdition(
        turnNumber: 14,
        publicationDate: "15 March 1960",
        publicationName: "The People's Voice",
        publicationType: .state,
        headline: HeadlineStory(
            headline: "FIVE-YEAR PLAN QUOTAS EXCEEDED",
            subheadline: "Workers Demonstrate Socialist Spirit",
            body: "Industrial production has surpassed planned targets by 12%, demonstrating the superiority of socialist planning.",
            category: .economic
        )
    )

    let samizdatEdition = NewspaperEdition(
        turnNumber: 14,
        publicationDate: "III.1960",
        publicationName: "The Chronicle",
        publicationType: .samizdat,
        headline: HeadlineStory(
            headline: "BREAD LINES GROW AS FOOD CRISIS WORSENS",
            subheadline: "State newspapers claim record harvests while children go hungry",
            body: "Despite official reports of success, sources report severe shortages. Food supply: 32%",
            category: .economic
        ),
        propagandaPiece: "DESTROY AFTER READING."
    )

    return MultiNewspaperView(
        stateEdition: stateEdition,
        samizdatEdition: samizdatEdition
    ) {
        print("Continue")
    }
}

#Preview("State Only") {
    let stateEdition = NewspaperEdition(
        turnNumber: 5,
        publicationDate: "8 September 1958",
        publicationName: "The People's Voice",
        publicationType: .state,
        headline: HeadlineStory(
            headline: "HARVEST COLLECTION PROCEEDS SUCCESSFULLY",
            body: "Agricultural officials report satisfactory progress in grain collection.",
            category: .economic
        )
    )

    return MultiNewspaperView(
        stateEdition: stateEdition,
        samizdatEdition: nil
    ) {
        print("Continue")
    }
}
