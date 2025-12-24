//
//  CongressTabView.swift
//  Nomenklatura
//
//  Main hub for Congress tab with sub-navigation to Laws, Standing Committee, and Sessions
//

import SwiftUI
import SwiftData

// MARK: - Congress Sub-Tab Enum

enum CongressSubTab: String, CaseIterable {
    case policies
    case committee
    case sessions

    var title: String {
        switch self {
        case .policies: return "Policies"
        case .committee: return "Committee"
        case .sessions: return "Sessions"
        }
    }

    var icon: String {
        switch self {
        case .policies: return "building.columns.fill"
        case .committee: return "person.3.fill"
        case .sessions: return "calendar.badge.clock"
        }
    }

    var description: String {
        switch self {
        case .policies: return "Policy settings across all institutions"
        case .committee: return "The Standing Committee of the Politburo"
        case .sessions: return "Legislative sessions and voting history"
        }
    }
}

// MARK: - Congress Tab View

struct CongressTabView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedSubTab: CongressSubTab = .policies

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                CongressHeader(game: game)

                // Sub-tab selector
                CongressSubTabBar(selectedTab: $selectedSubTab)
                    .padding(.horizontal, 15)
                    .padding(.top, 10)

                // Content based on selected sub-tab
                Group {
                    switch selectedSubTab {
                    case .policies:
                        PolicySlotsView(game: game)
                    case .committee:
                        StandingCommitteeView(game: game)
                    case .sessions:
                        SessionsView(game: game)
                    }
                }
            }
        }
    }
}

// MARK: - Congress Header

struct CongressHeader: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            // Flag backdrop - subtle, faded
            Image("flag_1")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .offset(y: 40)
                .clipped()
                .opacity(0.30)
                .grayscale(0.5)
                .overlay(
                    // Gradient overlay for text readability
                    LinearGradient(
                        colors: [
                            theme.parchment.opacity(0.3),
                            theme.parchment.opacity(0.7),
                            theme.parchment
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 8) {
                // Title row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THE PEOPLE'S CONGRESS")
                            .font(.system(size: 24, weight: .black))
                            .tracking(3)
                            .foregroundColor(theme.inkBlack)

                        Text(congressSubtitle)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }

                    Spacer()

                    // Standing Committee status indicator
                    VStack(alignment: .trailing, spacing: 2) {
                        if isOnStandingCommittee {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(theme.sovietRed)
                                Text("SC Member")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        } else {
                            Text("Observer")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.inkGray)
                        }

                        // Next session countdown
                        Text("Next session: Turn \(nextSessionTurn)")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkGray)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.top, 15)

                // Decorative divider
                Rectangle()
                    .fill(theme.inkBlack.opacity(0.3))
                    .frame(height: 1)
                    .padding(.horizontal, 15)
            }
        }
        .clipped()
    }

    private var congressSubtitle: String {
        if isOnStandingCommittee {
            return "You may propose and vote on policy changes"
        } else {
            return "Reach Senior Politburo to participate in policy decisions"
        }
    }

    private var isOnStandingCommittee: Bool {
        // Current threshold: position 7+ or actual SC membership
        game.currentPositionIndex >= 7
    }

    private var nextSessionTurn: Int {
        // Party Congress every 20 turns
        let congressCycle = 20
        let currentTurn = game.turnNumber
        let turnsUntilNext = congressCycle - (currentTurn % congressCycle)
        return currentTurn + turnsUntilNext
    }
}

// MARK: - Congress Sub-Tab Bar

struct CongressSubTabBar: View {
    @Binding var selectedTab: CongressSubTab
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CongressSubTab.allCases, id: \.self) { tab in
                CongressSubTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }
            }
        }
    }
}

struct CongressSubTabButton: View {
    let tab: CongressSubTab
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 28))
                Text(tab.title.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .tracking(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? theme.sovietRed.opacity(0.15) : theme.parchmentDark.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.sovietRed.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .foregroundColor(isSelected ? theme.sovietRed : theme.inkGray)
        }
        .buttonStyle(.plain)
    }
}

