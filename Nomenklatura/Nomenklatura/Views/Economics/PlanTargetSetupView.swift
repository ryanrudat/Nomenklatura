//
//  PlanTargetSetupView.swift
//  Nomenklatura
//
//  Modal/sheet view that prompts the player to set Five-Year Plan sector
//  targets at the start of each 20-turn cycle. Offers preset difficulty
//  levels plus a custom per-sector slider.
//

import SwiftUI

struct PlanTargetSetupView: View {
    @Bindable var game: Game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) var theme

    @State private var selectedPreset: PlanTargetPreset? = .ambitious
    @State private var customValues: [PlanSector: Double] = Self.defaultCustomValues()
    @State private var isCustom: Bool = false

    private static func defaultCustomValues() -> [PlanSector: Double] {
        var defaults: [PlanSector: Double] = [:]
        for sector in PlanSector.allCases {
            defaults[sector] = Double(PlanTargetPreset.ambitious.defaultDelta)
        }
        return defaults
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro

                    presetPicker

                    Divider()

                    customToggle

                    if isCustom {
                        customSliders
                    } else {
                        presetPreview
                    }

                    footer
                }
                .padding(16)
            }
            .background(theme.parchment)
            .navigationTitle("Five-Year Plan \(game.planTargets.cycleNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit Plan") {
                        commit()
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SET CYCLE TARGETS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(theme.sovietRed)

            Text("Gosplan awaits your production targets for the next \(FiveYearPlanTargets.cycleLength) turns. Each economic action you execute contributes progress toward these goals. Meet them and your standing rises; fail them and the Committee takes notice.")
                .font(.system(size: 12))
                .foregroundColor(theme.inkBlack)
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DIFFICULTY PRESET")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(PlanTargetPreset.allCases) { preset in
                presetRow(preset)
            }
        }
    }

    private func presetRow(_ preset: PlanTargetPreset) -> some View {
        let isSelected = selectedPreset == preset && !isCustom
        return Button {
            selectedPreset = preset
            isCustom = false
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? theme.accentGold : theme.inkLight)

                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    Text(preset.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)
                }

                Spacer()

                Text("+\(preset.defaultDelta) avg")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.accentGold)
            }
            .padding(10)
            .background(isSelected ? theme.parchmentDark : theme.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? theme.accentGold : theme.borderTan, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var presetPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TARGETS (PREVIEW)")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(PlanSector.allCases) { sector in
                HStack {
                    Image(systemName: sector.iconName)
                        .frame(width: 20)
                        .foregroundColor(theme.accentGold)
                    Text(sector.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("+\(previewValue(for: sector))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.inkBlack)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(10)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var customToggle: some View {
        Toggle(isOn: $isCustom) {
            Text("Customize per sector")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.inkBlack)
        }
        .tint(theme.accentGold)
    }

    private var customSliders: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CUSTOM TARGETS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            ForEach(PlanSector.allCases) { sector in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: sector.iconName)
                            .frame(width: 20)
                            .foregroundColor(theme.accentGold)
                        Text(sector.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.inkBlack)
                        Spacer()
                        Text("+\(Int(customValues[sector] ?? 0))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(theme.accentGold)
                    }
                    Slider(
                        value: Binding(
                            get: { customValues[sector] ?? 0 },
                            set: { customValues[sector] = $0 }
                        ),
                        in: 0...40,
                        step: 1
                    )
                    .tint(theme.accentGold)

                    Text(sector.subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Once committed, this cycle runs for \(FiveYearPlanTargets.cycleLength) turns. End-of-cycle consequences range from Stakhanovite triumph (all 6 sectors met) to Plan Failure (0-1 met).")
                .font(.system(size: 11))
                .foregroundColor(theme.inkGray)
        }
    }

    // MARK: - Logic

    private func previewValue(for sector: PlanSector) -> Int {
        (selectedPreset ?? .ambitious).defaultDelta
    }

    private func commit() {
        if isCustom {
            let deltas: [PlanSector: Int] = customValues.mapValues { Int($0) }
            game.configurePlanTargets(custom: deltas)
        } else if let preset = selectedPreset {
            game.configurePlanTargets(preset: preset)
        } else {
            game.configurePlanTargets(preset: .ambitious)
        }
    }
}

// MARK: - Plan Targets Card

/// Compact per-sector progress card shown on the Planning tab. Provides an
/// at-a-glance view of the current cycle's goals and how far each sector has
/// progressed toward them.
struct FiveYearPlanTargetsCard: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var targets: FiveYearPlanTargets { game.planTargets }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CYCLE \(targets.cycleNumber) TARGETS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                if targets.isConfigured {
                    Text("Turn \(game.turnNumber) / \(targets.endTurn)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.inkGray)
                }
            }

            if !targets.isConfigured {
                Text("Targets not yet set — visit Command Center to configure.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)
                    .padding(.vertical, 6)
            } else {
                ForEach(PlanSector.allCases) { sector in
                    sectorRow(sector)
                }
            }
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    private func sectorRow(_ sector: PlanSector) -> some View {
        let goal = targets.target(for: sector)
        let current = targets.progress(for: sector)
        let pct = targets.progressPercent(for: sector)
        let expected = targets.expectedProgressPercent(currentTurn: game.turnNumber)
        let color: Color = {
            if pct >= expected + 5 { return .green }
            if pct >= expected - 10 { return theme.accentGold }
            if pct >= expected - 25 { return .orange }
            return .red
        }()

        return HStack(spacing: 10) {
            Image(systemName: sector.iconName)
                .font(.system(size: 12))
                .foregroundColor(theme.accentGold)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(sector.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.inkBlack)
                Text("\(current) / \(goal)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(theme.inkLight)
            }

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(theme.parchment)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(100, pct)) / 100, height: 6)
                }
            }
            .frame(width: 80, height: 6)

            Text("\(pct)%")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Cycle Result Banner

/// Small banner surface shown on the Economy hub when a cycle has just
/// resolved. Reads the latest `plan_*` flags on the Game to figure out what
/// to render.
struct CycleResultBanner: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme

    private var banner: (title: String, subtitle: String, color: Color)? {
        let cycle = max(1, game.planTargets.cycleNumber - 1) // previous cycle just resolved
        if game.flags.contains("plan_\(cycle)_exceeded") {
            return ("Stakhanovite Triumph — Plan \(cycle) Exceeded", "All 6 sector targets met. +15 standing, +10 elite loyalty.", .green)
        } else if game.flags.contains("plan_\(cycle)_success") {
            return ("Plan \(cycle) Successfully Completed", "Most sector targets met. +5 standing.", theme.accentGold)
        } else if game.flags.contains("plan_\(cycle)_partial") {
            return ("Plan \(cycle) — Mixed Results", "Several targets missed. The Politburo is watching.", .orange)
        } else if game.flags.contains("plan_\(cycle)_failure") {
            return ("Plan \(cycle) Failure", "Targets missed. Committee intervention risk rising.", .red)
        }
        return nil
    }

    var body: some View {
        if let b = banner {
            VStack(alignment: .leading, spacing: 4) {
                Text(b.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text(b.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(b.color)
            .cornerRadius(8)
        }
    }
}
