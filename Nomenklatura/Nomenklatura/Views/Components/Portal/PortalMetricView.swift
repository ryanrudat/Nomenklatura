//
//  PortalMetricView.swift
//  Nomenklatura
//
//  Shared metric view for portal situation cards (value + label)
//

import SwiftUI

struct PortalMetricView: View {
    let label: String
    let value: String
    let color: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(theme.inkGray)
        }
        .frame(maxWidth: .infinity)
    }
}
