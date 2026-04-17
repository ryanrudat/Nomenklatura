//
//  ActivityFeedSection.swift
//  Nomenklatura
//
//  Displays recent activity feed for bureau operations with visual indicators.
//  Part of the Bureau Operations Center in the Ledger view.
//  Features status lights and visual timeline.
//

import SwiftUI
import SwiftData

// MARK: - Activity Feed Section

/// Section showing recent activity log for the player's bureau with visual elements
struct ActivityFeedSection: View {
    let game: Game
    let bureau: ExpandedCareerTrack

    @State private var entries: [BureauActivityEntry] = []

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    private var refreshToken: String {
        switch bureau {
        case .securityServices:
            return "\(game.turnNumber)|\(game.variables["security_pending_actions"] ?? "")|\(game.variables["active_detentions"] ?? "")"
        case .economicPlanning:
            return "\(game.turnNumber)|\(game.variables["economic_projects"] ?? "")"
        case .partyApparatus:
            return "\(game.turnNumber)|\(game.variables["party_campaigns"] ?? "")"
        default:
            return "\(game.turnNumber)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            sectionHeader

            if entries.isEmpty {
                emptyState
            } else {
                feedList
            }
        }
        .onAppear {
            loadActivity()
        }
        .onChange(of: refreshToken) { _, _ in
            loadActivity()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            // Visual timeline icon
            ZStack {
                Circle()
                    .fill(bureauColor.opacity(0.1))
                    .frame(width: 24, height: 24)

                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11))
                    .foregroundColor(bureauColor)
            }

            Text("RECENT ACTIVITY")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(FiftiesColors.typewriterInk)

            Spacer()

            // Count indicator
            if !entries.isEmpty {
                Text("\(entries.prefix(8).count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(bureauColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(bureauColor.opacity(0.1))
                    .cornerRadius(2)
            }
        }
    }

    // MARK: - Feed List

    private var feedList: some View {
        VStack(spacing: 0) {
            ForEach(entries.prefix(8)) { entry in
                ActivityFeedRow(entry: entry, bureauColor: bureauColor)

                if entry.id != entries.prefix(8).last?.id {
                    Divider()
                        .background(FiftiesColors.carbonCopy.opacity(0.3))
                }
            }
        }
        .background(FiftiesColors.manillaFolder)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(bureauColor.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        OfficialEmptyState(kind: .nothingToReport)
            .background(FiftiesColors.agedPaper.opacity(0.5))
            .cornerRadius(4)
    }

    // MARK: - Data Loading

    private func loadActivity() {
        entries = BureauOperationsService.shared.getRecentActivity(for: bureau, game: game, limit: 10)
    }
}

// MARK: - Activity Feed Row

/// Individual row in the activity feed with visual status indicator
struct ActivityFeedRow: View {
    let entry: BureauActivityEntry
    let bureauColor: Color

    private var statusLightType: StatusLight.Status {
        if let success = entry.wasSuccess {
            return success ? .active : .critical
        }
        return .inactive
    }

    private var iconColor: Color {
        if let success = entry.wasSuccess {
            return success ? FiftiesColors.approvedGreen : Color(hex: "8B0000")
        }
        return bureauColor
    }

    var body: some View {
        HStack(spacing: 10) {
            // Timeline connector with status light
            VStack(spacing: 0) {
                Rectangle()
                    .fill(bureauColor.opacity(0.2))
                    .frame(width: 2, height: 8)

                // Status light replaces simple icon
                StatusLight(statusLightType, size: 8)

                Rectangle()
                    .fill(bureauColor.opacity(0.2))
                    .frame(width: 2, height: 8)
            }

            // Icon in colored circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 24, height: 24)

                Image(systemName: entry.iconName)
                    .font(.system(size: 10))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(FiftiesColors.typewriterInk)

                Text(entry.description)
                    .font(.system(size: 9, design: .serif))
                    .foregroundColor(FiftiesColors.fadedInk)
                    .lineLimit(1)
            }

            Spacer()

            // Turn badge
            VStack(alignment: .trailing, spacing: 4) {
                Text("T\(entry.turn)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(bureauColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(bureauColor.opacity(0.1))
                    .cornerRadius(2)

                // Success/failure label
                if let success = entry.wasSuccess {
                    Text(success ? "SUCCESS" : "FAILED")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .foregroundColor(success ? FiftiesColors.approvedGreen : Color(hex: "8B0000"))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
