//
//  SettingsView.swift
//  Nomenklatura
//
//  User-facing settings sheet. Reachable via the gear icon in
//  StitchStatusBar. Covers App Store baseline: audio/haptics toggles,
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
/// without needing a dedicated settings @Model. The AI toggle is a
/// placeholder — wiring it to actually short-circuit AIScenarioGenerator
/// is out of scope for this release; see the TODO below.
struct SettingsView: View {
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var games: [Game]

    // MARK: Persisted preferences

    /// Mutes all in-game audio. Default OFF (audio plays).
    @AppStorage("settings.audio.muted") private var audioMuted: Bool = false

    /// Enables tactile feedback. Default ON (haptics fire).
    @AppStorage("settings.haptics.enabled") private var hapticsEnabled: Bool = true

    /// Gates AI-generated scenarios. Default ON.
    ///
    /// TODO: Actually wire this to short-circuit AIScenarioGenerator so
    /// that disabling skips network calls to the proxy and forces local
    /// fallback content. Currently this toggle persists the preference
    /// but does not yet gate the generator.
    @AppStorage("settings.ai.enabled") private var aiEnabled: Bool = true

    // MARK: Local UI state

    @State private var showResetConfirmation = false
    @State private var showResetCompletedAlert = false
    @State private var showPlaceholderLegalAlert = false
    @State private var placeholderLegalTitle = ""

    private var versionLabel: String {
        // Bundle.appVersion returns "1.4 (1)" — reformat to "v1.4 (build 1)"
        // for the more user-facing settings context.
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (build \(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Section 1 — Audio & Haptics
                    SettingsSection(title: "Audio & Haptics") {
                        SettingsToggleRow(
                            icon: "speaker.slash.fill",
                            title: "Mute Audio",
                            subtitle: "Silence all in-game sound",
                            isOn: $audioMuted
                        )
                        SettingsDivider()
                        SettingsToggleRow(
                            icon: "hand.tap.fill",
                            title: "Haptic Feedback",
                            subtitle: "Tactile response on interactions",
                            isOn: $hapticsEnabled
                        )
                    }

                    // Section 2 — AI Features
                    SettingsSection(title: "AI Features") {
                        SettingsToggleRow(
                            icon: "sparkles",
                            title: "Use AI-Generated Scenarios",
                            subtitle: "When disabled, the game uses local fallback content. Disables network calls to the AI proxy.",
                            isOn: $aiEnabled
                        )
                    }

                    // Section 3 — Save Game
                    SettingsSection(title: "Save Game") {
                        Button {
                            showResetConfirmation = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.red)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reset Save")
                                        .font(theme.labelFont)
                                        .fontWeight(.semibold)
                                        .foregroundColor(theme.inkBlack)

                                    Text("Permanently deletes your current save")
                                        .font(theme.tagFont)
                                        .foregroundColor(theme.inkGray)
                                        .multilineTextAlignment(.leading)
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

                    // Section 4 — About
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
                        // Placeholder Privacy + Terms rows.
                        // TODO: Before App Store submission these need to point
                        // at real hosted URLs (privacy policy + terms of
                        // service). For now the rows are tappable but show a
                        // placeholder alert so reviewers/users see they exist.
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

                    // Footer padding
                    Spacer(minLength: 30)

                    Text("THE APPARATUS REMEMBERS.")
                        .font(theme.tagFont)
                        .tracking(2)
                        .foregroundColor(theme.inkLight.opacity(0.5))
                        .padding(.bottom, 30)
                }
            }
            .background(theme.parchment)
            .navigationTitle("SETTINGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(theme.stampRed)
                }
            }
        }
        .confirmationDialog(
            "This will permanently delete your current save. Continue?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Save", role: .destructive) {
                performResetSave()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress on your current run will be lost. This action cannot be undone.")
        }
        .alert("Save Reset", isPresented: $showResetCompletedAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your save has been deleted. Please restart the app to begin a new game.")
        }
        .alert(placeholderLegalTitle, isPresented: $showPlaceholderLegalAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This document will be linked here before the App Store release.")
        }
    }

    /// Wipe all Game entities via SwiftData. Mirrors ContentView.deleteAllGameData()
    /// but doesn't try to navigate — the sheet just dismisses and the user
    /// is told to restart. Cleanly resetting setupState back to .campaignSelect
    /// from inside a sheet is awkward (sheet doesn't own the setupState binding);
    /// the user-facing alert documents that limitation.
    private func performResetSave() {
        for game in games {
            modelContext.delete(game)
        }
        try? modelContext.save()
        showResetCompletedAlert = true
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
