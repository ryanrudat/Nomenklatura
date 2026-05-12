//
//  MemorialSheetView.swift
//  Nomenklatura
//
//  "The Removed" — sheet presentation that wraps FallenCharactersView
//  with a NavigationStack and parchment background. Opened from the
//  BottomNavBar memorial button (formerly the Game Menu hamburger;
//  Game Menu actions now live inside SettingsView).
//

import SwiftUI

struct MemorialSheetView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    /// Every character who is no longer in active service — executed,
    /// imprisoned, exiled, deceased, disappeared, under investigation,
    /// or retired. `isFallen` is true for any non-`.active`/non-`.rehabilitated`
    /// status, which matches FallenCharactersView's six-section grouping.
    private var fallen: [GameCharacter] {
        game.characters
            .filter { $0.isFallen }
            .sorted { ($0.statusChangedTurn ?? 0) > ($1.statusChangedTurn ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Records of comrades removed from active service. The apparatus remembers — and so does the player.")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    FallenCharactersView(characters: fallen, game: game)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 30)
            }
            .background(theme.parchment)
            .navigationTitle("THE REMOVED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.stampRed)
                }
            }
        }
    }
}
