//
//  FocusForecastSheet.swift
//  Nomenklatura
//
//  Phase 3.4: confirmation sheet shown when the player switches a
//  sector's focus. Renders the FocusForecast as a brutalist preview:
//  inputs/outputs delta, reserve projection, cross-sector impacts,
//  and stat effect changes — so the Chairman sees the cascade before
//  signing.
//

import SwiftUI

struct FocusForecastSheet: View {
    let forecast: FocusForecast
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    transitionLine

                    if forecast.isLocked {
                        lockedNotice
                    } else {
                        inputsOutputsSection
                        reserveProjectionSection
                        if !forecast.crossSectorImpacts.isEmpty {
                            crossSectorSection
                        }
                        if !forecast.statEffectChanges.isEmpty {
                            statEffectsSection
                        }
                        if forecast.treasuryCostDelta != 0 {
                            treasuryRow
                        }
                    }

                    actionButtons
                        .padding(.top, 12)
                }
                .padding(20)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PROPOSED REFOCUS")
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(2.5)
                .foregroundColor(theme.sovietRed)

            Text(forecast.sector.displayName.uppercased())
                .font(.system(size: 22, weight: .black))
                .tracking(2)
                .foregroundColor(theme.inkBlack)

            Rectangle()
                .fill(theme.accentGold)
                .frame(width: 60, height: 2)
                .padding(.top, 4)
        }
    }

    private var transitionLine: some View {
        HStack(spacing: 10) {
            Text(forecast.currentFocus?.name ?? "(none)")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(theme.inkGray)
                .strikethrough()
            Image(systemName: "arrow.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(theme.sovietRed)
            Text(forecast.proposedFocus.name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(theme.inkBlack)
        }
        .padding(.bottom, 4)
    }

    private var lockedNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(forecast.lockReason ?? "Locked", systemImage: "lock.fill")
                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(theme.sovietRed)
            Text("This focus cannot be activated at the current technology era. Complete more Five-Year Plans to advance.")
                .font(.system(size: 13))
                .foregroundColor(theme.inkGray)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle().stroke(theme.sovietRed, lineWidth: 1.5)
        )
    }

    private var inputsOutputsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Resource Flow Δ")

            if forecast.inputDelta.isEmpty && forecast.outputDelta.isEmpty {
                Text("No supply-chain change.")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkLight)
            } else {
                ForEach(sortedDeltaKeys(forecast.inputDelta), id: \.self) { resource in
                    deltaRow(label: "Consumes", resource: resource, delta: forecast.inputDelta[resource] ?? 0, isInput: true)
                }
                ForEach(sortedDeltaKeys(forecast.outputDelta), id: \.self) { resource in
                    deltaRow(label: "Produces", resource: resource, delta: forecast.outputDelta[resource] ?? 0, isInput: false)
                }
            }
        }
    }

    private var reserveProjectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Projected Reserves Next Turn")

            if forecast.hasShortfallRisk {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.sovietRed)
                    Text("DEFICIT RISK: \(forecast.deficitResources.map(\.displayName).joined(separator: ", "))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.sovietRed)
                }
                .padding(.bottom, 4)
            }

            // Show only resources that change or are deficit
            let changedResources = forecast.reserveProjection.filter { resource, projected in
                forecast.inputDelta[resource] != nil ||
                forecast.outputDelta[resource] != nil ||
                projected < 0
            }

            ForEach(Array(changedResources.keys.sorted { $0.displayName < $1.displayName }), id: \.self) { resource in
                let projected = forecast.reserveProjection[resource] ?? 0
                HStack {
                    Image(systemName: resource.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkGray)
                        .frame(width: 16)
                    Text(resource.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("\(projected)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(projected < 0 ? theme.sovietRed : theme.inkBlack)
                }
            }
        }
    }

    private var crossSectorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Other Sectors Strained")
            ForEach(Array(forecast.crossSectorImpacts.keys), id: \.self) { sector in
                let satisfaction = forecast.crossSectorImpacts[sector] ?? 0
                HStack {
                    Text(sector.displayName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text("\(satisfaction)% capacity")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(satisfaction < 50 ? theme.sovietRed : theme.warningAmber)
                }
            }
        }
    }

    private var statEffectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Stat Effect Changes")
            ForEach(forecast.statEffectChanges.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                HStack {
                    Text(key)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    Text(formatDelta(value))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(value > 0 ? theme.successGreen : theme.sovietRed)
                }
            }
        }
    }

    private var treasuryRow: some View {
        HStack {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundColor(theme.accentGold)
            Text("Treasury Cost / Turn")
                .font(.system(size: 12))
                .foregroundColor(theme.inkBlack)
            Spacer()
            Text(formatDelta(forecast.treasuryCostDelta))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(forecast.treasuryCostDelta < 0 ? theme.successGreen : theme.sovietRed)
        }
        .padding(8)
        .background(theme.parchmentDark)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                onCancel()
                dismiss()
            } label: {
                Text("CANCEL")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(theme.inkGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.parchmentDark)
                    .overlay(Rectangle().stroke(theme.inkGray, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                onConfirm()
                dismiss()
            } label: {
                Text(forecast.isLocked ? "LOCKED" : "DECREE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(forecast.isLocked ? theme.inkGray : theme.sovietRed)
            }
            .buttonStyle(.plain)
            .disabled(forecast.isLocked)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(2)
            .foregroundColor(theme.inkGray)
            .padding(.bottom, 2)
    }

    private func deltaRow(label: String, resource: StrategicResource, delta: Int, isInput: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: resource.iconName)
                .font(.system(size: 12))
                .foregroundColor(theme.inkGray)
                .frame(width: 16)
            Text(resource.displayName)
                .font(.system(size: 12))
                .foregroundColor(theme.inkBlack)
            Text("(\(label.lowercased()))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.inkLight)
            Spacer()
            Text(formatDelta(delta))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(deltaColor(delta: delta, isInput: isInput))
        }
    }

    private func deltaColor(delta: Int, isInput: Bool) -> Color {
        // For inputs: less consumption is good (green); more consumption is bad (red).
        // For outputs: more production is good (green); less production is bad (red).
        if delta == 0 { return theme.inkGray }
        let positive = isInput ? (delta < 0) : (delta > 0)
        return positive ? theme.successGreen : theme.sovietRed
    }

    private func formatDelta(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func sortedDeltaKeys(_ deltas: [StrategicResource: Int]) -> [StrategicResource] {
        deltas.keys.sorted { $0.displayName < $1.displayName }
    }
}
