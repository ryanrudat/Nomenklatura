//
//  PortalStatusIndicator.swift
//  Nomenklatura
//
//  Shared status indicator (dot + label) for portal situation cards
//

import SwiftUI

struct PortalStatusIndicator: View {
    let label: String
    let isStrong: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isStrong ? Color.green : Color.orange)
                .frame(width: 6, height: 6)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(theme.inkGray)
        }
    }
}
