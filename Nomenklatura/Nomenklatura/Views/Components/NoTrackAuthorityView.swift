//
//  NoTrackAuthorityView.swift
//  Nomenklatura
//
//  Displayed when player tries to access bureau actions without being in that track.
//  Players must be assigned to a bureau's career track to execute actions there,
//  unless they hold top leadership positions (Position 7+).
//

import SwiftUI

struct NoTrackAuthorityView: View {
    let bureauName: String
    let requiredTrack: String
    let accentColor: Color
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 16) {
            // Lock icon
            ZStack {
                Circle()
                    .fill(theme.parchmentDark)
                    .frame(width: 64, height: 64)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28))
                    .foregroundColor(theme.inkLight)
            }

            // Title
            Text("NO AUTHORITY")
                .font(.system(size: 14, weight: .bold))
                .tracking(2)
                .foregroundColor(theme.inkBlack)

            // Explanation
            VStack(spacing: 8) {
                Text("You are not assigned to the \(bureauName).")
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)

                Text("Actions require the **\(requiredTrack)** career track or top leadership status (Position 7+).")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            // Divider
            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)
                .padding(.horizontal, 40)

            // What you can do
            VStack(alignment: .leading, spacing: 8) {
                Text("AS AN OBSERVER, YOU CAN:")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                ObserverCapabilityRow(icon: "eye.fill", text: "View operations and intelligence")
                ObserverCapabilityRow(icon: "doc.text.fill", text: "Read briefings and reports")
                ObserverCapabilityRow(icon: "person.2.fill", text: "Monitor personnel status")
            }
            .padding(.horizontal, 20)

            // How to gain authority
            VStack(spacing: 6) {
                Text("TO GAIN AUTHORITY:")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(accentColor)

                Text("Accept a position offer in this bureau's track, or advance to the Standing Committee.")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .background(accentColor.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(theme.parchment)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

struct ObserverCapabilityRow: View {
    let icon: String
    let text: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)
                .frame(width: 16)

            Text(text)
                .font(theme.tagFont)
                .foregroundColor(theme.inkGray)
        }
    }
}

#Preview {
    NoTrackAuthorityView(
        bureauName: "State Protection Bureau",
        requiredTrack: "Security Services",
        accentColor: .red
    )
    .padding()
}
