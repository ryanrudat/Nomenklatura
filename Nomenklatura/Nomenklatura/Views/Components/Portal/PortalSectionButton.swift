//
//  PortalSectionButton.swift
//  Nomenklatura
//
//  Shared section button and protocol for all portal views
//

import SwiftUI

// MARK: - Portal Section Protocol

protocol PortalSection: RawRepresentable, CaseIterable, Hashable where RawValue == String {
    var title: String { get }
    var icon: String { get }
    var requiredLevel: Int { get }
}

// MARK: - Portal Section Button

struct PortalSectionButton<S: PortalSection>: View {
    let section: S
    let isSelected: Bool
    let isLocked: Bool
    let accentColor: Color
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: section.icon)
                        .font(.system(size: 16))

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.white)
                            .offset(x: 8, y: 8)
                    }
                }

                Text(section.title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundColor(
                isLocked ? theme.inkLight :
                    (isSelected ? .white : theme.inkGray)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isLocked ? theme.parchmentDark.opacity(0.5) :
                    (isSelected ? accentColor : theme.parchmentDark)
            )
            .cornerRadius(6)
            .opacity(isLocked ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
    }
}
