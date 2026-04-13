//
//  PortalDetailRow.swift
//  Nomenklatura
//
//  Shared detail row for project/campaign/detention expanded details
//

import SwiftUI

struct PortalDetailRow: View {
    let label: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.inkBlack)
        }
    }
}
