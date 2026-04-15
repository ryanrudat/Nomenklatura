//
//  BureauOperationsView.swift
//  Nomenklatura
//
//  Standalone view that hosts the BureauOperationsCenter.
//  Accessed from the Ledger's Bureau Hub or from threat links.
//

import SwiftUI
import SwiftData

struct BureauOperationsView: View {
    let game: Game
    let bureau: ExpandedCareerTrack

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme

    var body: some View {
        NavigationStack {
            ZStack {
                theme.parchment.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        BureauOperationsCenter(game: game, bureau: bureau)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(BureauColors.headerTitle(for: bureau))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    return BureauOperationsView(game: game, bureau: .securityServices)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
