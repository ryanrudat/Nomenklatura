//
//  CampaignSelectView.swift
//  Nomenklatura
//
//  Campaign selection screen
//

import SwiftUI
import SwiftData

struct CampaignSelectView: View {
    let onCampaignSelected: (String) -> Void
    @Environment(\.theme) var theme

    // Available campaigns
    private let campaigns: [(id: String, name: String, era: String, description: String, startRole: String, available: Bool)] = [
        (
            id: "coldwar",
            name: "The Presidium",
            era: "",
            description: "Navigate the treacherous politics of the Presidium. Survive purges, outmaneuver rivals, position yourself for succession.",
            startRole: "Junior Presidium Member",
            available: true
        )
    ]

    var body: some View {
        ZStack {
            // Dark background
            theme.schemeDark.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("WELCOME, COMRADE")
                        .font(theme.headerFontLarge)
                        .tracking(3)
                        .foregroundColor(theme.schemeText)

                    Text("The Party Awaits")
                        .font(theme.bodyFont)
                        .italic()
                        .foregroundColor(Color(hex: "888888"))
                }
                .padding(.top, 60)
                .padding(.bottom, 30)

                // Campaign cards
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(campaigns, id: \.id) { campaign in
                            CampaignCardView(
                                name: campaign.name,
                                era: campaign.era,
                                description: campaign.description,
                                startRole: campaign.startRole,
                                isAvailable: campaign.available
                            ) {
                                if campaign.available {
                                    onCampaignSelected(campaign.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Campaign Card

struct CampaignCardView: View {
    let name: String
    let era: String
    let description: String
    let startRole: String
    let isAvailable: Bool
    let onSelect: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Era badge (only show if not empty)
                if !era.isEmpty {
                    Text(era.uppercased())
                        .font(theme.tagFont)
                        .tracking(2)
                        .foregroundColor(isAvailable ? theme.accentGold : Color(hex: "666666"))
                }

                // Title
                Text(name)
                    .font(theme.headerFont)
                    .foregroundColor(isAvailable ? theme.schemeText : Color(hex: "666666"))

                // Description
                Text(description)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(isAvailable ? Color(hex: "888888") : Color(hex: "555555"))
                    .lineSpacing(4)

                // Starting role
                HStack {
                    Text("Start as:")
                        .font(theme.tagFont)
                        .foregroundColor(Color(hex: "666666"))
                    Text(startRole)
                        .font(theme.tagFont)
                        .italic()
                        .foregroundColor(Color(hex: "666666"))
                }
                .padding(.top, 4)

                // Coming soon badge for unavailable
                if !isAvailable {
                    Text("COMING SOON")
                        .font(theme.tagFont)
                        .tracking(1)
                        .foregroundColor(Color(hex: "555555"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            Rectangle()
                                .stroke(Color(hex: "444444"), lineWidth: 1)
                        )
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color(hex: "2A2A2A"), Color(hex: "1A1A1A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .stroke(isAvailable ? theme.schemeBorder : Color(hex: "333333"), lineWidth: 1)
            )
            .opacity(isAvailable ? 1.0 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
}

#Preview {
    CampaignSelectView { campaignId in
        print("Selected: \(campaignId)")
    }
    .environment(\.theme, ColdWarTheme())
}
