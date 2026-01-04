//
//  LegacyTransitionView.swift
//  Nomenklatura
//
//  Shows the transition between generations when the player dies and heir takes over.
//  Three phases reflecting Communist reality:
//  1. Official Funeral/Denouncement - State funeral or denouncement
//  2. Dynasty Assessment - Revolutionary credentials recalculated
//  3. Heir's Beginning - Position assigned, relationships inherited
//

import SwiftUI

struct LegacyTransitionView: View {
    let summary: LegacySummary
    let onContinue: () -> Void

    @Environment(\.theme) var theme
    @State private var currentPhase: TransitionPhase = .funeral
    @State private var showingDetails = false

    var body: some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Phase indicator
                phaseIndicator
                    .padding(.top, 40)

                Spacer()

                // Phase content
                phaseContent
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                Spacer()

                // Continue button
                continueButton
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 20)
        }
        .animation(.easeInOut(duration: 0.5), value: currentPhase)
    }

    // MARK: - Phase Indicator

    private var phaseIndicator: some View {
        HStack(spacing: 20) {
            ForEach(TransitionPhase.allCases, id: \.self) { phase in
                VStack(spacing: 4) {
                    Circle()
                        .fill(currentPhase.rawValue >= phase.rawValue ? theme.sovietRed : theme.inkLight.opacity(0.3))
                        .frame(width: 12, height: 12)

                    Text(phase.shortName)
                        .font(.system(size: 10))
                        .foregroundColor(currentPhase == phase ? theme.parchment : theme.inkLight.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch currentPhase {
        case .funeral:
            funeralPhase
        case .assessment:
            assessmentPhase
        case .beginning:
            beginningPhase
        }
    }

    // MARK: - Funeral Phase

    private var funeralPhase: some View {
        VStack(spacing: 24) {
            // Title based on cause
            Text(funeralTitle)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundColor(theme.parchment)
                .multilineTextAlignment(.center)

            // Memorial portrait frame
            RoundedRectangle(cornerRadius: 4)
                .stroke(theme.accentGold.opacity(0.5), lineWidth: 2)
                .frame(width: 120, height: 150)
                .overlay(
                    VStack {
                        Image(systemName: "person.fill")
                            .font(.system(size: 50))
                            .foregroundColor(theme.parchment.opacity(0.5))
                        Text(summary.lastLeaderName)
                            .font(.system(size: 12, design: .serif))
                            .foregroundColor(theme.parchment)
                    }
                )

            // Epitaph
            Text(summary.lastLeaderEpitaph)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(theme.parchment.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .italic()

            // Official statement
            Text(officialStatement)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(theme.inkLight)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
                .padding(.top, 10)
        }
    }

    private var funeralTitle: String {
        switch summary.lastLeaderCause {
        case .naturalDeath:
            return "STATE FUNERAL"
        case .retired:
            return "FAREWELL CEREMONY"
        case .executedEnemy, .purgedDisgraced:
            return "OFFICIAL DENOUNCEMENT"
        case .executedMartyr:
            return "POSTHUMOUS REHABILITATION"
        case .assassinated:
            return "TRAGIC LOSS"
        case .coupVictim:
            return "REGIME TRANSITION"
        case .imprisoned:
            return "SILENCE"
        }
    }

    private var officialStatement: String {
        switch summary.lastLeaderCause {
        case .naturalDeath, .retired:
            return "\"Comrade \(summary.lastLeaderName) served the Party faithfully. The revolution continues.\""
        case .executedEnemy, .purgedDisgraced:
            return "\"Let the fate of \(summary.lastLeaderName) serve as a warning to all who would betray the revolution.\""
        case .executedMartyr:
            return "\"The Party acknowledges that errors were made. Comrade \(summary.lastLeaderName) has been restored to honor.\""
        case .assassinated:
            return "\"A tragic accident has claimed Comrade \(summary.lastLeaderName). Investigations continue.\""
        case .coupVictim:
            return "\"The old regime has been swept away. A new era begins.\""
        case .imprisoned:
            return "No official statement has been issued."
        }
    }

    // MARK: - Assessment Phase

    private var assessmentPhase: some View {
        VStack(spacing: 20) {
            Text("FAMILY STANDING ASSESSMENT")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(theme.parchment)
                .tracking(2)

            // Dynasty info card
            VStack(spacing: 12) {
                HStack {
                    Text("Dynasty:")
                    Spacer()
                    Text(summary.dynastyName)
                        .foregroundColor(theme.accentGold)
                }

                HStack {
                    Text("Generations:")
                    Spacer()
                    Text("\(summary.generationsCount)")
                }

                HStack {
                    Text("Total Service:")
                    Spacer()
                    Text("\(summary.totalTurns / 6) years")
                }

                Divider()
                    .background(theme.inkLight.opacity(0.3))

                HStack {
                    Text("Current Standing:")
                    Spacer()
                    Text(summary.reputation.displayName)
                        .foregroundColor(reputationColor)
                }
            }
            .font(.system(size: 14, design: .serif))
            .foregroundColor(theme.parchment.opacity(0.9))
            .padding(16)
            .background(theme.inkBlack.opacity(0.5))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan.opacity(0.3), lineWidth: 1)
            )

            // Warnings
            if !summary.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(theme.sovietRed)
                                .font(.system(size: 12))
                            Text(warning)
                                .font(.system(size: 12, design: .serif))
                                .foregroundColor(theme.sovietRed.opacity(0.9))
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
    }

    private var reputationColor: Color {
        switch summary.reputation {
        case .revered, .respected:
            return theme.accentGold
        case .neutral, .rehabilitated:
            return theme.parchment
        case .questionable, .tainted:
            return theme.sovietRed
        }
    }

    // MARK: - Beginning Phase

    private var beginningPhase: some View {
        VStack(spacing: 24) {
            Text("A NEW CHAPTER BEGINS")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(theme.accentGold)
                .tracking(2)

            if let heir = summary.heirName {
                VStack(spacing: 16) {
                    Text("You are now \(heir)")
                        .font(.system(size: 18, design: .serif))
                        .foregroundColor(theme.parchment)

                    // Inheritance details
                    VStack(spacing: 8) {
                        inheritanceRow(
                            label: "Inherited Standing:",
                            value: "\(summary.heirInheritancePercent)%"
                        )

                        inheritanceRow(
                            label: "Position Adjustment:",
                            value: positionModifierText
                        )
                    }
                    .padding(12)
                    .background(theme.inkBlack.opacity(0.5))
                    .cornerRadius(6)

                    // Advice
                    Text(adviceText)
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(theme.inkLight)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .italic()
                }
            } else {
                VStack(spacing: 12) {
                    Text("THE DYNASTY ENDS")
                        .font(.system(size: 18, design: .serif))
                        .foregroundColor(theme.sovietRed)

                    Text("With no heir to continue, the \(summary.dynastyName) legacy fades into history.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(theme.parchment.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func inheritanceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13, design: .serif))
                .foregroundColor(theme.parchment.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundColor(theme.accentGold)
        }
    }

    private var positionModifierText: String {
        if summary.positionModifier > 0 {
            return "+\(summary.positionModifier) levels"
        } else if summary.positionModifier < 0 {
            return "\(summary.positionModifier) levels"
        } else {
            return "Same level"
        }
    }

    private var adviceText: String {
        switch summary.lastLeaderCause {
        case .executedEnemy, .purgedDisgraced:
            return "Prove your loyalty. Distance yourself from the past. Survive."
        case .executedMartyr:
            return "Your predecessor's rehabilitation opens doors. Use this gift wisely."
        case .naturalDeath, .retired:
            return "Honor your predecessor's legacy while forging your own path."
        case .assassinated:
            return "Trust no one. Your predecessor's enemies may now be yours."
        case .coupVictim:
            return "The new order watches you closely. Demonstrate your value."
        case .imprisoned:
            return "Your family is under suspicion. Tread carefully."
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            if currentPhase == .beginning {
                onContinue()
            } else {
                currentPhase = currentPhase.next
            }
        }) {
            Text(currentPhase == .beginning ? "Begin New Chapter" : "Continue")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.inkBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.accentGold)
                .cornerRadius(8)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Transition Phase

enum TransitionPhase: Int, CaseIterable {
    case funeral = 0
    case assessment = 1
    case beginning = 2

    var shortName: String {
        switch self {
        case .funeral: return "Memorial"
        case .assessment: return "Assessment"
        case .beginning: return "Succession"
        }
    }

    var next: TransitionPhase {
        switch self {
        case .funeral: return .assessment
        case .assessment: return .beginning
        case .beginning: return .beginning
        }
    }
}

// MARK: - Preview

#Preview {
    let mockSummary = LegacySummary(
        dynastyName: "Chen",
        generationsCount: 2,
        totalTurns: 48,
        reputation: .respected,
        lastLeaderName: "Chen Weimin",
        lastLeaderEpitaph: "Served the Party for 8 years before passing peacefully.",
        lastLeaderCause: .naturalDeath,
        heirName: "Chen Xiaoming",
        heirInheritancePercent: 65,
        positionModifier: 0,
        warnings: []
    )

    LegacyTransitionView(summary: mockSummary) {
        print("Continue pressed")
    }
    .environment(\.theme, ColdWarTheme())
}
