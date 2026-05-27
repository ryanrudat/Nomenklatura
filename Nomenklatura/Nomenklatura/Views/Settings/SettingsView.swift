//
//  SettingsView.swift
//  Nomenklatura
//
//  User-facing settings sheet. Reachable via the gear icon in
//  StitchStatusBar. Covers App Store baseline: a haptics toggle,
//  AI feature toggle, reset save, version/credits/legal placeholders.
//
//  Aesthetic: Brutalist Bureaucratic Theater — matches the parchment +
//  rubber-stamp visual language used across the Desk.
//

import SwiftUI
import SwiftData

/// Settings sheet presented from the Desk's StitchStatusBar gear icon.
///
/// Toggles are backed by @AppStorage so they survive process restart
/// without needing a dedicated settings @Model. The AI toggle gates
/// scenario generation via `Secrets.userAIEnabled`; the haptics toggle
/// gates the Desk's `.sensoryFeedback`.
struct SettingsView: View {
    // Game lifecycle callbacks injected from ContentView via DeskView. Optional
    // so the view can still be previewed standalone; when nil the row is hidden.
    var onRestart: (() -> Void)?
    var onMainMenu: (() -> Void)?
    var onDeleteAllData: (() -> Void)?

    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]

    // MARK: Persisted preferences

    /// Enables tactile feedback. Default ON (haptics fire). Read on the Desk
    /// via @AppStorage to gate `.sensoryFeedback`.
    @AppStorage("settings.haptics.enabled") private var hapticsEnabled: Bool = true

    /// Gates AI-generated scenarios. Default ON. Read by `Secrets.userAIEnabled`,
    /// which `AIScenarioGenerator` / `ScenarioManager` check before calling the
    /// proxy; when OFF the game uses local fallback content (no network calls).
    @AppStorage("settings.ai.enabled") private var aiEnabled: Bool = true

    // MARK: Local UI state

    @State private var showPlaceholderLegalAlert = false
    @State private var placeholderLegalTitle = ""
    @State private var showMainMenuConfirmation = false   // bound by New Run button
    @State private var showDeleteAllConfirmation = false  // bound by Wipe All Data button

    private var versionLabel: String {
        // Bundle.appVersion returns "1.4 (1)" — reformat to "v1.4 (build 1)"
        // for the more user-facing settings context.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (build \(build))"
    }

    var body: some View {
        NavigationStack {
            mainScroll
                .background(theme.parchment)
                .navigationTitle("SETTINGS")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                            .foregroundColor(theme.stampRed)
                    }
                }
        }
        .modifier(SettingsConfirmationDialogs(
            showPlaceholderLegalAlert: $showPlaceholderLegalAlert,
            showMainMenuConfirmation: $showMainMenuConfirmation,
            showDeleteAllConfirmation: $showDeleteAllConfirmation,
            placeholderLegalTitle: placeholderLegalTitle,
            onMainMenu: onMainMenu,
            onDeleteAllData: onDeleteAllData,
            dismiss: dismiss
        ))
    }

    @ViewBuilder
    private var mainScroll: some View {
        ScrollView {
            VStack(spacing: 0) {
                gameMenuSection
                hapticsSection
                aiFeaturesSection
                aboutSection
                Spacer(minLength: 30)
                Text("THE APPARATUS REMEMBERS.")
                    .font(theme.tagFont)
                    .tracking(2)
                    .foregroundColor(theme.inkLight.opacity(0.5))
                    .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder
    private var hapticsSection: some View {
        SettingsSection(title: "Haptics") {
            SettingsToggleRow(
                icon: "hand.tap.fill",
                title: "Haptic Feedback",
                subtitle: "Tactile response on key interactions",
                isOn: $hapticsEnabled
            )
        }
    }

    @ViewBuilder
    private var aiFeaturesSection: some View {
        SettingsSection(title: "AI Features") {
            SettingsToggleRow(
                icon: "sparkles",
                title: "Use AI-Generated Scenarios",
                subtitle: "When disabled, the game uses local fallback content. Disables network calls to the AI proxy.",
                isOn: $aiEnabled
            )
        }
    }

/// About section — version, credits, legal links. Placeholder alerts
    /// for Privacy/Terms remain in place until hosted URLs are finalized.
    @ViewBuilder
    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsInfoRow(
                icon: "info.circle.fill",
                title: "Version",
                value: versionLabel
            )
            SettingsDivider()
            SettingsInfoRow(
                icon: "person.fill",
                title: "Credits",
                value: "Designed and developed by Ryan Rudat. Built with AI-assisted narrative."
            )
            SettingsDivider()
            SettingsLinkRow(
                icon: "lock.shield.fill",
                title: "Privacy Policy"
            ) {
                placeholderLegalTitle = "Privacy Policy"
                showPlaceholderLegalAlert = true
            }
            SettingsDivider()
            SettingsLinkRow(
                icon: "doc.text.fill",
                title: "Terms of Service"
            ) {
                placeholderLegalTitle = "Terms of Service"
                showPlaceholderLegalAlert = true
            }
        }
    }

    /// Game Menu section — consolidated 2-button reset model.
    ///
    /// "New Run" ends the current game and returns to campaign select; from
    /// there the player picks any campaign/faction (re-picking the same
    /// faction trivially handles the old "restart with same faction" intent).
    /// "Wipe All Data" is the niche power-user option below an Advanced
    /// divider — corrupted save / fresh-install testing / privacy.
    ///
    /// The legacy `onRestart` callback param is retained on the SettingsView
    /// API for back-compat with callers that haven't migrated; it's no longer
    /// surfaced as a button. The legacy `Reset Save` section is gone too.
    @ViewBuilder
    private var gameMenuSection: some View {
        if onMainMenu != nil || onDeleteAllData != nil {
            SettingsSection(title: "Game Menu") {
                if onMainMenu != nil {
                    SettingsActionRow(
                        icon: "arrow.clockwise",
                        title: "New Run",
                        subtitle: "End the current game and return to campaign select",
                        tint: theme.accentGold
                    ) {
                        showMainMenuConfirmation = true
                    }
                }
                if onMainMenu != nil && onDeleteAllData != nil {
                    advancedDivider
                }
                if onDeleteAllData != nil {
                    SettingsActionRow(
                        icon: "trash.fill",
                        title: "Wipe All Data",
                        subtitle: "Completely reset the app — removes all saved games",
                        tint: .red
                    ) {
                        showDeleteAllConfirmation = true
                    }
                }
            }
        }
    }

    /// Subtle "ADVANCED" divider between the safe New Run button and the
    /// nuclear Wipe All Data button. Helps the player see Wipe as the
    /// destructive escape hatch, not a peer option.
    @ViewBuilder
    private var advancedDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(theme.inkLight.opacity(0.3))
                .frame(height: 1)
            Text("ADVANCED")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(theme.inkLight.opacity(0.5))
            Rectangle()
                .fill(theme.inkLight.opacity(0.3))
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

}

// MARK: - Confirmation dialog bundle

/// All six confirmation/alert dialogs hoisted into a single ViewModifier so
/// SettingsView.body stays small enough for Swift's view-builder type checker.
/// After the reset-model consolidation (2026-05-12), only 3 dialogs remain:
/// New Run, Wipe All Data, and the placeholder legal alert. The legacy
/// Reset Save + Save-Reset-completed + Restart-Game dialogs are gone.
private struct SettingsConfirmationDialogs: ViewModifier {
    @Binding var showPlaceholderLegalAlert: Bool
    @Binding var showMainMenuConfirmation: Bool
    @Binding var showDeleteAllConfirmation: Bool
    let placeholderLegalTitle: String
    let onMainMenu: (() -> Void)?
    let onDeleteAllData: (() -> Void)?
    let dismiss: DismissAction

    func body(content: Content) -> some View {
        content
            .alert(placeholderLegalTitle, isPresented: $showPlaceholderLegalAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This document will be linked here before the App Store release.")
            }
            .confirmationDialog(
                "Start a New Run?",
                isPresented: $showMainMenuConfirmation,
                titleVisibility: .visible
            ) {
                Button("End Game", role: .destructive) {
                    dismiss()
                    onMainMenu?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your current game will end. You'll return to campaign select.")
            }
            .confirmationDialog(
                "Wipe All Data?",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Wipe Everything", role: .destructive) {
                    dismiss()
                    onDeleteAllData?()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all saved games and settings. The app will reset to initial state.")
            }
    }
}

// MARK: - Section Container

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header — uppercase, tracked, rubber-stamp style
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.stampRed)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)

            content
        }
    }
}

// MARK: - Rows

private struct SettingsToggleRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.leatherBrown)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.labelFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.inkBlack)

                Text(subtitle)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(theme.stampRed)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.parchmentDark)
    }
}

private struct SettingsInfoRow: View {
    let icon: String
    let title: String
    let value: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(theme.leatherBrown)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(theme.labelFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.inkBlack)

                Text(value)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(theme.parchmentDark)
    }
}

private struct SettingsLinkRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(theme.leatherBrown)
                    .frame(width: 40)

                Text(title)
                    .font(theme.labelFont)
                    .fontWeight(.semibold)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.inkLight)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(theme.parchmentDark)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let tint: Color
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(tint)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(theme.labelFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)

                    Text(subtitle)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(theme.inkLight)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(theme.parchmentDark)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsDivider: View {
    @Environment(\.theme) var theme

    var body: some View {
        Rectangle()
            .fill(theme.borderTan)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    return SettingsView()
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
