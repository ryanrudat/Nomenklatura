//
//  CollapsibleSection.swift
//  Nomenklatura
//
//  Reusable collapsible wrapper for dense scroll-stack screens.
//  Persists expanded/collapsed state via @AppStorage so the player's
//  preferred layout survives across launches.
//

import SwiftUI

struct CollapsibleSection<Content: View>: View {
    let title: String
    let storageKey: String
    let defaultExpanded: Bool
    @ViewBuilder let content: () -> Content

    @AppStorage private var isExpanded: Bool
    @Environment(\.theme) var theme

    init(
        title: String,
        storageKey: String,
        defaultExpanded: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.storageKey = storageKey
        self.defaultExpanded = defaultExpanded
        self.content = content
        self._isExpanded = AppStorage(wrappedValue: defaultExpanded, "collapsible.\(storageKey)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.inkGray)
                        .frame(width: 12)

                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(theme.inkBlack)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            CollapsibleSection(title: "Stability", storageKey: "preview.stability") {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 80)
            }
            CollapsibleSection(title: "Power Centers", storageKey: "preview.power") {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 80)
            }
            CollapsibleSection(title: "Resources", storageKey: "preview.resources", defaultExpanded: false) {
                Rectangle().fill(Color.gray.opacity(0.2)).frame(height: 80)
            }
        }
        .padding()
    }
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
