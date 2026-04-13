//
//  PortalEmptyStateView.swift
//  Nomenklatura
//
//  Shared empty state view for all portal sections
//

import SwiftUI

struct PortalEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(theme.inkLight)

            Text(title)
                .font(theme.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(theme.inkBlack)

            Text(message)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(theme.parchmentDark.opacity(0.5))
        .cornerRadius(12)
    }
}
