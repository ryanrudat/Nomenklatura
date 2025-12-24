//
//  StanceTagView.swift
//  Nomenklatura
//
//  Stance tag component for character relationships
//

import SwiftUI

struct StanceTagView: View {
    let stance: StanceTag
    var isProminent: Bool = false
    @Environment(\.theme) var theme

    private var backgroundColor: Color {
        switch stance {
        case .patron: return .stancePatronBg
        case .rival: return .stanceRivalBg
        case .ally: return .stanceAllyBg
        case .neutral: return .stanceNeutralBg
        }
    }

    private var textColor: Color {
        switch stance {
        case .patron: return .stancePatronText
        case .rival: return .stanceRivalText
        case .ally: return .stanceAllyText
        case .neutral: return .stanceNeutralText
        }
    }

    var body: some View {
        Text(stance.rawValue)
            .font(isProminent ? .system(size: 10, weight: .bold) : theme.tagFont)
            .foregroundColor(textColor)
            .padding(.horizontal, isProminent ? 7 : 5)
            .padding(.vertical, isProminent ? 3 : 2)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: isProminent ? 4 : 3)
                    .stroke(isProminent ? textColor.opacity(0.5) : .clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: isProminent ? 4 : 3))
    }
}

// MARK: - Trait Tag (for character personality traits)

struct TraitTagView: View {
    let trait: String
    @Environment(\.theme) var theme

    var body: some View {
        Text(trait)
            .font(theme.tagFont)
            .foregroundColor(Color(hex: "666666"))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(hex: "E8E4D9"))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

// MARK: - Character Tags Row

struct CharacterTagsRow: View {
    let stances: [StanceTag]
    let traits: [String]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(stances, id: \.self) { stance in
                StanceTagView(stance: stance)
            }

            ForEach(traits, id: \.self) { trait in
                TraitTagView(trait: trait)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 15) {
        HStack(spacing: 5) {
            StanceTagView(stance: .patron)
            StanceTagView(stance: .rival)
        }

        HStack(spacing: 5) {
            StanceTagView(stance: .ally)
            TraitTagView(trait: "Reformist")
        }

        HStack(spacing: 5) {
            StanceTagView(stance: .neutral)
            TraitTagView(trait: "Ambitious")
            TraitTagView(trait: "Paranoid")
        }
    }
    .padding()
    .background(Color(hex: "FFFEF7"))
    .environment(\.theme, ColdWarTheme())
}
