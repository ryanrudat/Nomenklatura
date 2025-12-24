//
//  ActionConfirmationSheet.swift
//  Nomenklatura
//
//  Themed confirmation sheet for bureau actions that matches the app's UI style.
//

import SwiftUI

/// A themed confirmation sheet for executing bureau actions
struct ActionConfirmationSheet: View {
    let title: String
    let description: String
    let successChance: Int
    let riskLevel: String
    let riskColor: Color
    let accentColor: Color
    let actionVerb: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 0) {
            // Handle bar
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.inkLight.opacity(0.5))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Header
            VStack(spacing: 8) {
                Text("CONFIRM ACTION")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(theme.inkGray)

                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.inkBlack)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)

            Divider()
                .background(theme.borderTan)
                .padding(.vertical, 16)

            // Description
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)

            // Stats
            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(successChance)%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(successChanceColor)
                    Text("SUCCESS")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)
                }

                Rectangle()
                    .fill(theme.borderTan)
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text(riskLevel.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(riskColor)
                    Text("RISK")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)
                }
            }
            .padding(.vertical, 20)

            Divider()
                .background(theme.borderTan)

            // Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.parchmentDark)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.borderTan, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(actionVerb)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(accentColor)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(theme.parchment)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }

    private var successChanceColor: Color {
        switch successChance {
        case 70...: return .green
        case 50..<70: return .blue
        case 30..<50: return .orange
        default: return .red
        }
    }
}

// Note: Uses RoundedCorner from existing project utilities
