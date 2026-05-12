//
//  RivalThreatPanel.swift
//  Nomenklatura
//
//  Audit follow-up — rivals were invisible. The player discovered hostility
//  only when a RivalMove arrived. This panel surfaces every active threat
//  in one collapsible section so the Chairman can plan, not react.
//
//  Selection criteria, severity sort, and inclusion rules are documented
//  inline so future tuning passes can be done by editing one file.
//

import SwiftUI

// MARK: - RivalThreatPanel

/// Collapsible "KNOWN THREATS" section for the Dossier. Lists every
/// living character who currently registers as a threat (rival flag,
/// .rival role, hostile disposition, active grudge, or a pending
/// RivalMove against the Chairman), sorted by severity descending.
struct RivalThreatPanel: View {
    let game: Game

    /// Optional jump-to-Desk callback used by per-card "RESPOND" buttons.
    /// Parent (DossierView in ContentView) flips `selectedTab = .desk` so
    /// the player lands on the RivalMoveCard that needs an answer.
    var onRespondTap: (() -> Void)? = nil

    @Environment(\.theme) var theme

    // MARK: - Threat Selection

    /// A character qualifies as a "threat" if ANY of:
    ///   - `isRival == true`
    ///   - `currentRole == .rival`
    ///   - `disposition < 30`               (hostile)
    ///   - `grudgeLevel < -20`              (active resentment)
    ///   - has an unresolved RivalMove in `game.activeRivalMoves`
    /// AND `currentStatus == .active` (only live threats).
    private var threats: [GameCharacter] {
        let pendingRivalIds = Set(
            game.activeRivalMoves
                .filter { $0.resolution == .pending }
                .map { $0.rivalCharacterId }
        )
        return game.characters.filter { character in
            guard character.currentStatus == .active else { return false }
            return character.isRival
                || character.currentRole == .rival
                || character.disposition < 30
                || character.grudgeLevel < -20
                || pendingRivalIds.contains(character.id)
        }
        .sorted(by: sortBySeverity)
    }

    /// Sort threats: pending RivalMove (urgent deadline first) → hostile →
    /// antagonistic → watchful. Within ties, fall back to disposition asc.
    private func sortBySeverity(_ a: GameCharacter, _ b: GameCharacter) -> Bool {
        let aMove = pendingMove(for: a)
        let bMove = pendingMove(for: b)
        switch (aMove, bMove) {
        case let (m1?, m2?):
            return m1.deadlineTurn < m2.deadlineTurn   // sooner deadline first
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            // Use threat tier; fall back to lower disposition first.
            if a.threatTier.rank != b.threatTier.rank {
                return a.threatTier.rank < b.threatTier.rank
            }
            return a.disposition < b.disposition
        }
    }

    private func pendingMove(for character: GameCharacter) -> RivalMove? {
        game.activeRivalMoves.first {
            $0.rivalCharacterId == character.id && $0.resolution == .pending
        }
    }

    // MARK: - Body

    var body: some View {
        CollapsibleSection(
            title: "KNOWN THREATS",
            storageKey: "dossier.knownThreats",
            defaultExpanded: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if threats.isEmpty {
                    Text("No active threats detected.")
                        .font(theme.tagFont)
                        .italic()
                        .foregroundColor(theme.inkLight)
                        .padding(.vertical, 8)
                } else {
                    ForEach(threats) { character in
                        RivalThreatCard(
                            character: character,
                            pendingMove: pendingMove(for: character),
                            currentTurn: game.turnNumber,
                            game: game,
                            onRespondTap: onRespondTap
                        )
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }
}

// MARK: - ThreatTier

/// Three-tier severity label used by the badge and the sort key.
private enum ThreatTier {
    case hostile        // disposition < 20 OR grudge < -50
    case antagonistic   // disposition 20-40 OR grudge -50 to -20
    case watchful       // disposition 40-50 with grudge < 0

    var rank: Int {
        switch self {
        case .hostile: return 0
        case .antagonistic: return 1
        case .watchful: return 2
        }
    }

    var label: String {
        switch self {
        case .hostile: return "HOSTILE"
        case .antagonistic: return "ANTAGONISTIC"
        case .watchful: return "WATCHFUL"
        }
    }

    func color(_ theme: any CampaignTheme) -> Color {
        switch self {
        case .hostile: return theme.stampRed
        case .antagonistic: return theme.warningAmber
        case .watchful: return theme.accentGold
        }
    }
}

extension GameCharacter {
    fileprivate var threatTier: ThreatTier {
        if disposition < 20 || grudgeLevel < -50 { return .hostile }
        if disposition <= 40 || grudgeLevel <= -20 { return .antagonistic }
        return .watchful
    }
}

// MARK: - RivalThreatCard

/// Per-character card. Matches CharacterCardView's visual language
/// (parchmentDark, left accent stripe, monospace tags) but slimmer so
/// the panel can list 5-10 threats without overwhelming the scroll.
private struct RivalThreatCard: View {
    let character: GameCharacter
    let pendingMove: RivalMove?
    let currentTurn: Int
    let game: Game
    var onRespondTap: (() -> Void)?

    @State private var showingDetail = false
    @Environment(\.theme) var theme

    private var tier: ThreatTier { character.threatTier }

    private var positionDisplay: String? {
        guard let index = character.positionIndex, index > 0 else { return nil }
        let roman = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
        return "Position " + (index < roman.count ? roman[index] : String(index))
    }

    private var subtitleLine: String? {
        switch (character.title, positionDisplay) {
        case let (t?, p?): return "\(t) — \(p)"
        case let (t?, nil): return t
        case let (nil, p?): return p
        default: return nil
        }
    }

    private var factionLabel: String? {
        guard let id = character.factionId else { return nil }
        let names: [String: String] = [
            "old_guard": "OLD GUARD",
            "reformists": "REFORMIST",
            "princelings": "PRINCELING",
            "youth_league": "YOUTH LEAGUE",
            "regional": "REGIONAL"
        ]
        return names[id] ?? id.uppercased()
    }

    private var factionColor: Color {
        guard let id = character.factionId else { return theme.inkLight }
        let colors: [String: Color] = [
            "old_guard": Color(hex: "8B0000"),
            "reformists": Color(hex: "2E7D32"),
            "princelings": Color(hex: "C4A962"),
            "youth_league": Color(hex: "1565C0"),
            "regional": Color(hex: "6D4C41")
        ]
        return colors[id] ?? theme.inkGray
    }

    private var turnsUntilDeadline: Int? {
        guard let move = pendingMove else { return nil }
        return max(0, move.deadlineTurn - currentTurn)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left accent stripe — tier color so urgency reads at a glance
            Rectangle()
                .fill(tier.color(theme))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                // Header: name + position + threat badge
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(character.name)
                            .font(theme.labelFont)
                            .fontWeight(.bold)
                            .foregroundColor(theme.inkBlack)
                        if let subtitle = subtitleLine {
                            Text(subtitle)
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                        }
                    }

                    Spacer()

                    Text(tier.label)
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(tier.color(theme))
                }

                // Faction badge + disposition / grudge readout
                HStack(spacing: 6) {
                    if let label = factionLabel {
                        Text(label)
                            .font(.system(size: 7, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(factionColor)
                            .cornerRadius(2)
                    }

                    Text("DISP \(character.disposition)")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.inkGray)

                    if character.grudgeLevel < 0 {
                        Text("GRUDGE \(character.grudgeLevel)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(theme.stampRed)
                    }
                }

                // Pending move preview or "no scheme" line
                if let move = pendingMove, let remaining = turnsUntilDeadline {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ACTIVE SCHEME: \(move.kind.threatStatDisplay)")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(theme.stampRed)
                        Text("\(remaining) TURN\(remaining == 1 ? "" : "S") UNTIL EXECUTION")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(remaining <= 1 ? theme.stampRed : theme.warningAmber)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.stampRed.opacity(0.08))
                    .overlay(
                        Rectangle()
                            .stroke(theme.stampRed.opacity(0.4), lineWidth: 1)
                    )
                } else {
                    Text("No active scheme.")
                        .font(theme.tagFont)
                        .italic()
                        .foregroundColor(theme.inkLight)
                }

                // Quick-action buttons
                HStack(spacing: 8) {
                    Button {
                        showingDetail = true
                    } label: {
                        Text("VIEW DOSSIER")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .overlay(
                                Rectangle()
                                    .stroke(theme.inkBlack, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    if pendingMove != nil, onRespondTap != nil {
                        Button {
                            onRespondTap?()
                        } label: {
                            Text("RESPOND")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(theme.stampRed)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
            }
            .padding(10)
        }
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
        .sheet(isPresented: $showingDetail) {
            CharacterDetailView(character: character, game: game)
        }
    }
}
