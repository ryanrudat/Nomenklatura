//
//  CrisisResponsePanel.swift
//  Nomenklatura
//
//  Sheet-presented panel listing every active crisis with its available
//  response options. The player picks one option per crisis, confirms,
//  and watches the result land via a stat-change toast. Crises that are
//  beyond the player's reach (insufficient AP, no decree charges left,
//  failed stat minimums) still render — but as disabled cards with
//  an explanatory reason hint underneath.
//

import SwiftUI
import SwiftData

struct CrisisResponsePanel: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @Environment(\.dismiss) private var dismiss

    /// Result of the last-executed option. Drives the success/failure
    /// stat-change toast that floats above the panel until tapped or
    /// auto-dismissed.
    @State private var pendingResult: CrisisResponseResult?

    private var service: CrisisResponseService { CrisisResponseService.shared }
    private var activeCrises: [CrisisType] { service.activeCrises(in: game) }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.parchment.ignoresSafeArea()

                if activeCrises.isEmpty {
                    emptyState
                } else {
                    crisisListScroll
                }

                // Stat-change toast overlay — reuses Codex toast verbatim,
                // mapping CrisisResponseResult.statChanges → deltas.
                if let result = pendingResult {
                    CodexStatChangeToast(
                        deltas: deltas(from: result),
                        archetypeLabel: result.success
                            ? "\(result.crisisType.displayName) \u{2014} RESOLVED"
                            : "\(result.crisisType.displayName) \u{2014} FAILED",
                        onDismiss: {
                            pendingResult = nil
                            dismiss()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle("CRISIS RESPONSE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Decree-charge counter on the leading side — many crisis
                // options require a charge (option.requiresDecreeCharge), and
                // the pool is shared with Security/Directive/Emergency, so the
                // player should see it before tapping a "DECREE" option.
                ToolbarItem(placement: .navigationBarLeading) {
                    DecreeChargesCounter(game: game)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(theme.stampRed)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48, weight: .regular))
                .foregroundColor(theme.inkLight)
            Text("NO ACTIVE CRISES")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundColor(theme.inkBlack)
            Text("The Apparatus reports no immediate threats.")
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("CLOSE")
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(theme.parchment)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.stampRed)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Crisis List

    private var crisisListScroll: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(activeCrises) { crisis in
                    CrisisSection(
                        crisis: crisis,
                        severity: service.severity(for: crisis, in: game),
                        options: service.availableOptions(for: crisis, in: game),
                        game: game,
                        onConfirm: { option in
                            executeOption(option)
                        }
                    )
                }

                // Footer "Address Later" — banner stays visible for the
                // next tap; nothing is mutated.
                Button {
                    dismiss()
                } label: {
                    Text("ADDRESS LATER")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(theme.inkGray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            Rectangle().stroke(theme.borderTan, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Execution

    private func executeOption(_ option: CrisisResponseOption) {
        let result = service.executeOption(option, in: game)
        withAnimation(.easeInOut(duration: 0.25)) {
            pendingResult = result
        }
    }

    // MARK: - Mapping statChanges → CodexStatDelta

    /// Map a `CrisisResponseResult.statChanges` dict into ordered toast
    /// deltas. Label normalization mirrors `PersistentStatBar` codes so
    /// the player sees consistent terms ("STABILITY", "TREASURY", etc.).
    private func deltas(from result: CrisisResponseResult) -> [CodexStatDelta] {
        result.statChanges
            .sorted { $0.key < $1.key }
            .map { key, amount in
                CodexStatDelta(
                    label: prettyLabel(for: key),
                    amount: amount,
                    isPositive: isPositiveOutcome(key: key, amount: amount)
                )
            }
    }

    private func prettyLabel(for key: String) -> String {
        switch key.lowercased() {
        case "stability":          return "STABILITY"
        case "popularsupport":     return "POPULAR SUPPORT"
        case "militaryloyalty":    return "MILITARY LOYALTY"
        case "eliteloyalty":       return "ELITE LOYALTY"
        case "treasury":           return "TREASURY"
        case "standing":           return "STANDING"
        case "internationalstanding": return "INTERNATIONAL STANDING"
        case "network":            return "NETWORK"
        case "patronfavor":        return "PATRON FAVOR"
        case "rivalthreat":        return "RIVAL THREAT"
        default:                   return key.uppercased()
        }
    }

    /// "Positive" from the player's POV. Most stats: up = good. Rival threat:
    /// down = good. (Treasury negative is a cost — still rendered negative.)
    private func isPositiveOutcome(key: String, amount: Int) -> Bool {
        switch key.lowercased() {
        case "rivalthreat": return amount < 0
        default:            return amount >= 0
        }
    }
}

// MARK: - CrisisSection

private struct CrisisSection: View {
    let crisis: CrisisType
    let severity: Int                              // 0-100
    let options: [CrisisResponseOption]
    @Bindable var game: Game
    let onConfirm: (CrisisResponseOption) -> Void

    @Environment(\.theme) var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: icon + name
            HStack(spacing: 10) {
                Image(systemName: crisis.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(theme.stampRed)
                    .frame(width: 22)

                Text(crisis.displayName)
                    .font(.system(size: 15, weight: .heavy, design: .default))
                    .tracking(1.5)
                    .foregroundColor(theme.inkBlack)

                Spacer()

                Text("SEV \(severity)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(severityColor)
            }

            severityBar

            // Sub-header description
            Text(crisis.shortDescription)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
                .fixedSize(horizontal: false, vertical: true)

            // Options list
            if options.isEmpty {
                Text("NO RESPONSE OPTIONS AVAILABLE")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(theme.inkLight)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        CrisisOptionCard(
                            option: option,
                            game: game,
                            onConfirm: { onConfirm(option) }
                        )
                    }
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusBase)
                    .fill(theme.parchmentDark)
                RoundedRectangle(cornerRadius: theme.cornerRadiusBase)
                    .stroke(theme.borderTan, lineWidth: 1)
            }
        )
        .applyShadow(theme.shadowSubtle)
    }

    // MARK: - Severity Bar (red gradient, 0-100)

    private var severityBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(height: 6)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.urgentRed.opacity(0.7),
                                theme.stampRed,
                                theme.stampRedDark
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * CGFloat(min(max(severity, 0), 100)) / 100.0, height: 6)
            }
        }
        .frame(height: 6)
    }

    private var severityColor: Color {
        if severity >= 75 { return theme.stampRedDark }
        if severity >= 50 { return theme.stampRed }
        return theme.urgentRed.opacity(0.8)
    }
}

// MARK: - CrisisOptionCard

private struct CrisisOptionCard: View {
    let option: CrisisResponseOption
    @Bindable var game: Game
    let onConfirm: () -> Void

    @Environment(\.theme) var theme
    @State private var showConfirm = false

    private var available: Bool { option.isAvailable(in: game) }
    private var chancePercent: Int { Int((option.baseSuccessChance * 100).rounded()) }

    var body: some View {
        Button {
            if available { showConfirm = true }
        } label: {
            cardBody
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .alert(option.label, isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Execute", role: .destructive) {
                onConfirm()
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: label + chance pill
            HStack(spacing: 8) {
                Text(option.label)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(available ? theme.inkBlack : theme.inkLight)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 6)

                chancePill
            }

            // Description
            Text(option.shortDescription)
                .font(theme.bodyFontSmall)
                .foregroundColor(available ? theme.inkGray : theme.inkLight)
                .fixedSize(horizontal: false, vertical: true)

            // Cost row
            costRow

            // Disabled reason hint
            if !available, let reason = unavailableReason {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(theme.stampRedDark)
                    Text(reason.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundColor(theme.stampRedDark)
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .fill(available ? theme.parchment : theme.paperGray.opacity(0.6))
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .stroke(available ? theme.borderTan : theme.borderTan.opacity(0.6), lineWidth: 1)
            }
        )
        .opacity(available ? 1.0 : 0.65)
    }

    // MARK: - Chance Pill

    private var chancePill: some View {
        Text("\(chancePercent)%")
            .font(.system(size: 11, weight: .heavy, design: .monospaced))
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(chanceColor)
            )
    }

    private var chanceColor: Color {
        if chancePercent >= 75 { return theme.successGreen }
        if chancePercent >= 50 { return theme.warningAmber }
        return theme.stampRed
    }

    // MARK: - Cost Row

    private var costRow: some View {
        HStack(spacing: 8) {
            // AP cost — shown even if 0 to keep alignment predictable
            costChip(text: "\(option.costAP) AP", icon: "bolt.fill", tint: theme.accentGold)

            if option.costTreasury > 0 {
                costChip(
                    text: "\u{2212}\(option.costTreasury) $",
                    icon: "dollarsign.circle.fill",
                    tint: theme.stampRed
                )
            }

            if option.requiresDecreeCharge {
                Text("DECREE")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.0)
                    .foregroundColor(theme.inkBlack)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(theme.accentGold)
                    )
            }

            ForEach(Array(option.minStatRequirements.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                Text("\(prettyStatKey(key)) \u{2265} \(value)")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(0.8)
                    .foregroundColor(theme.inkGray)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().stroke(theme.borderTan, lineWidth: 1)
                    )
            }

            Spacer(minLength: 0)
        }
    }

    private func costChip(text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(tint)
            Text(text)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .tracking(0.6)
                .foregroundColor(theme.inkBlack)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(theme.parchmentDark)
        )
        .overlay(
            Capsule().stroke(theme.borderTan, lineWidth: 0.5)
        )
    }

    private func prettyStatKey(_ key: String) -> String {
        switch key.lowercased() {
        case "stability":          return "STAB"
        case "popularsupport":     return "POP"
        case "militaryloyalty":    return "MIL"
        case "eliteloyalty":       return "ELITE"
        case "standing":           return "STND"
        case "internationalstanding": return "INTL"
        case "network":            return "NET"
        default:                   return key.uppercased()
        }
    }

    // MARK: - Availability Reason

    /// Best-effort explanation for why this option is disabled. The
    /// service's `isAvailable(in:)` is the source of truth; this just
    /// surfaces the most likely cause so the player isn't left guessing.
    private var unavailableReason: String? {
        if game.actionPoints < option.costAP {
            return "Insufficient AP"
        }
        if option.costTreasury > game.treasury {
            return "Insufficient treasury"
        }
        if option.requiresDecreeCharge && game.decreeChargesRemaining <= 0 {
            return "No decree charges remaining"
        }
        for (key, required) in option.minStatRequirements {
            let current = currentStat(for: key)
            if current < required {
                return "\(prettyStatKey(key)) below \(required)"
            }
        }
        return "Not available"
    }

    private func currentStat(for key: String) -> Int {
        switch key.lowercased() {
        case "stability":             return game.stability
        case "popularsupport":        return game.popularSupport
        case "militaryloyalty":       return game.militaryLoyalty
        case "eliteloyalty":          return game.eliteLoyalty
        case "standing":              return game.standing
        case "internationalstanding": return game.internationalStanding
        case "network":               return game.network
        case "treasury":              return game.treasury
        default:                      return 0
        }
    }

    // MARK: - Confirm Alert Message

    private var confirmMessage: String {
        var parts: [String] = []
        parts.append(option.narrativeSuccess)
        parts.append("")
        var costs: [String] = []
        if option.costAP > 0 { costs.append("\(option.costAP) AP") }
        if option.costTreasury > 0 { costs.append("\(option.costTreasury) $") }
        if option.requiresDecreeCharge { costs.append("1 Decree Charge") }
        if !costs.isEmpty {
            parts.append("Cost: " + costs.joined(separator: " \u{2022} "))
        }
        parts.append("Success chance: \(chancePercent)%")
        // Last-charge nudge — only for options that actually draw from the pool.
        // The pool is shared with Security/Directive/Emergency surfaces, so the
        // player should know before they spend their final charge.
        if option.requiresDecreeCharge, let warning = decreeLastChargeWarning(for: game) {
            parts.append("")
            parts.append(warning)
        }
        return parts.joined(separator: "\n")
    }
}

#Preview("Crisis Panel") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "coldwar")
    container.mainContext.insert(game)

    return CrisisResponsePanel(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
