//
//  IntelligenceAlertView.swift
//  Nomenklatura
//
//  Modal view for intelligence alerts with save/dismiss actions.
//  Player must choose to save to notes or dismiss each alert.
//

import SwiftUI

struct IntelligenceAlertView: View {
    let alert: IntelligenceAlert
    let pendingCount: Int
    let onSave: () -> Void
    let onDismiss: () -> Void
    let onSaveAll: (() -> Void)?
    let onDismissAll: (() -> Void)?

    @Environment(\.theme) var theme
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0

    init(
        alert: IntelligenceAlert,
        pendingCount: Int = 1,
        onSave: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onSaveAll: (() -> Void)? = nil,
        onDismissAll: (() -> Void)? = nil
    ) {
        self.alert = alert
        self.pendingCount = pendingCount
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.onSaveAll = onSaveAll
        self.onDismissAll = onDismissAll
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Don't dismiss on background tap - force explicit choice
                }

            // Alert card
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    // Category icon
                    ZStack {
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                            .frame(width: 48, height: 48)

                        Image(systemName: alert.category.iconName)
                            .font(.system(size: 22))
                            .foregroundColor(categoryColor)
                    }

                    // Header text
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accentGold)

                        Text("INTELLIGENCE RECEIVED")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)
                            .foregroundColor(theme.accentGold)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.accentGold)
                    }

                    // Queue indicator (if more than 1)
                    if pendingCount > 1 {
                        Text("\(pendingCount) alerts pending")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Divider
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)

                // Content
                VStack(alignment: .leading, spacing: 12) {
                    // Category label
                    Text(alert.category.displayName.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(categoryColor)

                    // Title
                    Text(alert.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(theme.inkBlack)

                    // Content
                    Text(alert.content)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    // Related character (if any)
                    if let characterName = alert.relatedCharacterName {
                        HStack(spacing: 6) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10))
                            Text("Re: \(characterName)")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(theme.inkLight)
                        .padding(.top, 4)
                    }

                    // Turn discovered
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("Turn \(alert.turnDiscovered)")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.inkLight)
                }
                .padding(20)

                // Divider
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 1)

                // Action buttons
                VStack(spacing: 12) {
                    // Primary actions
                    HStack(spacing: 12) {
                        // Dismiss button
                        Button {
                            dismissWithAnimation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .medium))
                                Text("DISMISS")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.parchmentDark)
                            .foregroundColor(theme.inkGray)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.borderTan, lineWidth: 1)
                            )
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        // Save button
                        Button {
                            saveWithAnimation()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 12, weight: .medium))
                                Text("SAVE TO NOTES")
                                    .font(.system(size: 11, weight: .semibold))
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(theme.accentGold)
                            .foregroundColor(theme.inkBlack)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }

                    // Bulk actions (if multiple pending)
                    if pendingCount > 1 {
                        HStack(spacing: 16) {
                            if let dismissAll = onDismissAll {
                                Button {
                                    dismissAll()
                                } label: {
                                    Text("Dismiss All (\(pendingCount))")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.inkLight)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }

                            if let saveAll = onSaveAll {
                                Button {
                                    saveAll()
                                } label: {
                                    Text("Save All (\(pendingCount))")
                                        .font(.system(size: 10))
                                        .foregroundColor(theme.accentGold)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(theme.parchment)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
            .padding(.horizontal, 24)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Allow downward drag only
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            // Dismiss on large downward swipe
                            dismissWithAnimation()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isVisible = true
            }
        }
    }

    // MARK: - Helpers

    private var categoryColor: Color {
        switch alert.category {
        case .personalityReveal:
            return Color.purple
        case .factionDiscovery:
            return Color.blue
        case .plotDevelopment:
            return theme.accentGold
        case .fateChange:
            return theme.sovietRed
        case .relationshipChange:
            return Color.pink
        case .secretIntelligence:
            return Color.orange
        case .historicalRecord:
            return Color.brown
        case .lawChange:
            return Color.teal
        case .npcActivity:
            return Color.green
        case .committeeActivity:
            return Color.indigo
        }
    }

    private func saveWithAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSave()
        }
    }

    private func dismissWithAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Intelligence Alert Overlay Modifier

struct IntelligenceAlertOverlay: ViewModifier {
    @ObservedObject var alertService = IntelligenceAlertService.shared
    let game: Game?

    func body(content: Content) -> some View {
        content
            .overlay {
                if let alert = alertService.currentAlert, alertService.isShowingAlert, let game = game {
                    IntelligenceAlertView(
                        alert: alert,
                        pendingCount: game.pendingAlertCount,
                        onSave: {
                            alertService.saveCurrentAlert(for: game)
                        },
                        onDismiss: {
                            alertService.dismissCurrentAlert(for: game)
                        },
                        onSaveAll: game.pendingAlertCount > 1 ? {
                            alertService.saveAllAlerts(for: game)
                        } : nil,
                        onDismissAll: game.pendingAlertCount > 1 ? {
                            alertService.dismissAllAlerts(for: game)
                        } : nil
                    )
                }
            }
    }
}

extension View {
    func intelligenceAlertOverlay(game: Game?) -> some View {
        modifier(IntelligenceAlertOverlay(game: game))
    }
}

// MARK: - Preview

#Preview("Intelligence Alert") {
    ZStack {
        Color(hex: "F4F1E8")
            .ignoresSafeArea()

        VStack {
            Text("Content behind alert")
            Spacer()
        }

        IntelligenceAlertView(
            alert: IntelligenceAlert(
                turnDiscovered: 5,
                category: .personalityReveal,
                title: "Character Insight: Director Wallace",
                content: "You have come to understand Director Wallace's true nature. They appear to be primarily ambitious in character. This knowledge may prove useful in future dealings.",
                relatedCharacterName: "Director Harold Wallace"
            ),
            pendingCount: 3,
            onSave: { print("Saved!") },
            onDismiss: { print("Dismissed!") },
            onSaveAll: { print("Save all!") },
            onDismissAll: { print("Dismiss all!") }
        )
    }
    .environment(\.theme, ColdWarTheme())
}

#Preview("Single Alert") {
    ZStack {
        Color(hex: "F4F1E8")
            .ignoresSafeArea()

        IntelligenceAlertView(
            alert: IntelligenceAlert(
                turnDiscovered: 12,
                category: .fateChange,
                title: "Execution: Comrade Petrov",
                content: "Comrade Petrov has been executed for crimes against the state. The Party's justice is final.",
                relatedCharacterName: "Alexei Petrov"
            ),
            pendingCount: 1,
            onSave: { },
            onDismiss: { }
        )
    }
    .environment(\.theme, ColdWarTheme())
}
