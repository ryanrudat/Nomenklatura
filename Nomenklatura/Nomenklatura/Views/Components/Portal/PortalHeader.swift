//
//  PortalHeader.swift
//  Nomenklatura
//
//  Shared header for portal views (title + subtitle with accent border)
//

import SwiftUI

struct PortalHeader: View {
    let title: String
    let subtitle: String
    let accentColor: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(accentColor)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
