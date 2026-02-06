//
//  BureauOperationsCenter.swift
//  Nomenklatura
//
//  Main operations dashboard for the player's committed bureau.
//  Displays active operations, activity feed, and available actions.
//

import SwiftUI
import SwiftData

// MARK: - Bureau Operations Center

/// Main operations center dashboard for a committed bureau
struct BureauOperationsCenter: View {
    let game: Game
    let bureau: ExpandedCareerTrack

    @State private var summary: BureauOperationsSummary?
    @State private var isExpanded = true

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    private var bureauTitle: String {
        BureauColors.headerTitle(for: bureau)
    }

    private var summaryRefreshToken: String {
        let cooldownKey: String
        let operationsKey: String

        switch bureau {
        case .securityServices:
            cooldownKey = "security_cooldowns"
            operationsKey = (game.variables["security_pending_actions"] ?? "") + "|" + (game.variables["active_detentions"] ?? "")
        case .economicPlanning:
            cooldownKey = "economic_cooldowns"
            operationsKey = game.variables["economic_projects"] ?? ""
        case .partyApparatus:
            cooldownKey = "party_cooldowns"
            operationsKey = game.variables["party_campaigns"] ?? ""
        default:
            cooldownKey = ""
            operationsKey = ""
        }

        return [
            "\(game.turnNumber)",
            "\(game.currentPositionIndex)",
            "\(game.network)",
            "\(game.variables[cooldownKey] ?? "")",
            operationsKey
        ].joined(separator: "|")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            centerHeader

            if isExpanded {
                // Main content
                ScrollView {
                    VStack(spacing: 16) {
                        // Summary statistics
                        if let summary = summary {
                            summaryStats(summary)
                        }

                        // Active Operations
                        ActiveOperationsSection(game: game, bureau: bureau)

                        // Recent Activity
                        ActivityFeedSection(game: game, bureau: bureau)

                        // Available Actions
                        ActionableTasksSection(game: game, bureau: bureau)

                        // Open full portal button
                        openPortalButton
                    }
                    .padding(16)
                }
            }
        }
        .background(FiftiesColors.agedPaper)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(bureauColor.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            loadSummary()
        }
        .onChange(of: summaryRefreshToken) { _, _ in
            loadSummary()
        }
    }

    // MARK: - Header

    private var centerHeader: some View {
        VStack(spacing: 0) {
            // Top color stripe with pattern
            ZStack {
                Rectangle()
                    .fill(bureauColor)

                // Decorative pattern
                HStack(spacing: 4) {
                    ForEach(0..<30, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 2)
                    }
                }
            }
            .frame(height: 6)

            // Title bar with emblem
            HStack(spacing: 12) {
                // Bureau emblem (small size)
                BureauEmblem(bureau: bureau, size: .small)

                // Title and subtitle
                VStack(alignment: .leading, spacing: 2) {
                    Text(bureauTitle.uppercased())
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.5)
                        .foregroundColor(bureauColor)

                    Text("COMMAND CENTER")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                }

                Spacer()

                // Active status light
                if let summary = summary, summary.activeOperations > 0 {
                    HStack(spacing: 4) {
                        StatusLight(.active, size: 6)
                        Text("\(summary.activeOperations) ACTIVE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.approvedGreen)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(FiftiesColors.approvedGreen.opacity(0.1))
                    .cornerRadius(2)
                }

                // Expand/collapse button
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(FiftiesColors.carbonCopy)
                        .padding(6)
                        .background(FiftiesColors.agedPaper)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [FiftiesColors.manillaFolder, FiftiesColors.agedPaper],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // Bottom border
            Rectangle()
                .fill(bureauColor.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Summary Statistics (Visual Dashboard)

    private func summaryStats(_ summary: BureauOperationsSummary) -> some View {
        VStack(spacing: 12) {
            // Top row: Circular gauges
            HStack(spacing: 16) {
                // Success rate gauge (prominent)
                CircularGauge(
                    value: summary.successRate * 100,
                    label: "SUCCESS",
                    color: summary.successRate >= 0.6 ? FiftiesColors.approvedGreen : FiftiesColors.brassGold,
                    size: 60
                )

                // Divider
                Rectangle()
                    .fill(bureauColor.opacity(0.2))
                    .frame(width: 1, height: 50)

                // Quick stats in vertical layout
                VStack(alignment: .leading, spacing: 8) {
                    // Active operations
                    HStack(spacing: 6) {
                        StatusLight(.active, size: 8)
                        Text("\(summary.activeOperations)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.approvedGreen)
                        Text("ACTIVE")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                    }

                    // Pending approval
                    HStack(spacing: 6) {
                        StatusLight(.warning, size: 8)
                        Text("\(summary.pendingApproval)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.brassGold)
                        Text("PENDING")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                    }

                    // Available tasks
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 8))
                            .foregroundColor(bureauColor)
                            .frame(width: 16)
                        Text("\(summary.availableTaskCount)")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(bureauColor)
                        Text("AVAILABLE")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [FiftiesColors.manillaFolder, FiftiesColors.agedPaper.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(bureauColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Open Portal Button

    private var openPortalButton: some View {
        NavigationLink {
            // Navigate to the appropriate bureau portal
            destinationView
        } label: {
            HStack {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 12))

                Text("OPEN \(BureauColors.code(for: bureau)) COMMAND CENTER")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundColor(bureauColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(bureauColor, lineWidth: 1.5)
            )
            .background(bureauColor.opacity(0.05))
            .cornerRadius(4)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch bureau {
        case .securityServices:
            SecurityPortalView(game: game)
        case .economicPlanning:
            EconomicPortalView(game: game)
        case .partyApparatus:
            PartyPortalView(game: game)
        default:
            EmptyView()
        }
    }

    // MARK: - Data Loading

    private func loadSummary() {
        summary = BureauOperationsService.shared.getOperationsSummary(for: bureau, game: game)
    }
}

// MARK: - Compact Version

/// Compact version of operations center for constrained layouts
struct BureauOperationsCenterCompact: View {
    let game: Game
    let bureau: ExpandedCareerTrack

    @State private var summary: BureauOperationsSummary?

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Color stripe
            Rectangle()
                .fill(bureauColor)
                .frame(height: 3)

            HStack(spacing: 12) {
                // Icon
                Image(systemName: BureauColors.icon(for: bureau))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(bureauColor)

                // Code
                Text(BureauColors.code(for: bureau))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(bureauColor)

                Rectangle()
                    .fill(bureauColor.opacity(0.3))
                    .frame(width: 1, height: 16)

                // Quick stats
                if let summary = summary {
                    HStack(spacing: 8) {
                        Label("\(summary.activeOperations)", systemImage: "circle.fill")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(FiftiesColors.approvedGreen)

                        Label("\(summary.availableTaskCount)", systemImage: "list.bullet")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(bureauColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(FiftiesColors.carbonCopy)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(FiftiesColors.manillaFolder)
        }
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(bureauColor.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            summary = BureauOperationsService.shared.getOperationsSummary(for: bureau, game: game)
        }
    }
}
