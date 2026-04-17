//
//  ActiveOperationsSection.swift
//  Nomenklatura
//
//  Displays active bureau operations with visual progress indicators.
//  Part of the Bureau Operations Center in the Ledger view.
//  Features Soviet-inspired visual elements like status lights and gauges.
//

import SwiftUI
import SwiftData

// MARK: - Active Operations Section

/// Section showing all active operations for the player's bureau with visual elements
struct ActiveOperationsSection: View {
    let game: Game
    let bureau: ExpandedCareerTrack

    @State private var operations: [BureauOperation] = []

    private var bureauColor: Color {
        BureauColors.primary(for: bureau)
    }

    private var accentColor: Color {
        BureauColors.accent(for: bureau)
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
            // Section header with visual indicator
            sectionHeader

            if operations.isEmpty {
                emptyState
            } else {
                operationsList
            }
        }
        .onAppear {
            loadOperations()
        }
        .onChange(of: refreshToken) { _, _ in
            loadOperations()
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack(spacing: 8) {
            // Visual status light instead of simple circle
            StatusLight(operations.isEmpty ? .inactive : .active, size: 8)

            Text("ACTIVE OPERATIONS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(FiftiesColors.typewriterInk)

            Spacer()

            // Count badge with bureau styling
            if !operations.isEmpty {
                Text("\(operations.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(bureauColor)
                    .cornerRadius(2)
            }
        }
    }

    // MARK: - Operations List

    private var operationsList: some View {
        VStack(spacing: 8) {
            ForEach(operations) { operation in
                OperationCard(operation: operation, bureauColor: bureauColor)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        OfficialEmptyState(kind: .operationsDormant)
            .background(ColdWarTheme.shared.agedPaper.opacity(0.5))
            .cornerRadius(4)
    }

    // MARK: - Data Loading

    private func loadOperations() {
        operations = BureauOperationsService.shared.getActiveOperations(for: bureau, game: game)
    }
}

// MARK: - Operation Card

/// Individual operation card with visual progress indicator and status lights
struct OperationCard: View {
    let operation: BureauOperation
    let bureauColor: Color

    private var statusLightType: StatusLight.Status {
        switch operation.status {
        case .inProgress:
            return .active
        case .awaitingApproval:
            return .warning
        case .awaitingResources:
            return .warning
        case .pending:
            return .inactive
        default:
            return .inactive
        }
    }

    private var statusColor: Color {
        switch operation.status {
        case .inProgress:
            return FiftiesColors.approvedGreen
        case .awaitingApproval:
            return FiftiesColors.brassGold
        case .awaitingResources:
            return Color(hex: "CD853F")
        case .pending:
            return ColdWarTheme.shared.carbonCopy
        default:
            return ColdWarTheme.shared.inkGray
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left side: Circular progress gauge
            CircularGauge(
                value: Double(operation.progress),
                label: "",
                color: bureauColor,
                size: 48
            )

            // Middle: Operation details
            VStack(alignment: .leading, spacing: 4) {
                // Operation name with icon
                HStack(spacing: 6) {
                    Image(systemName: operation.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(bureauColor)

                    Text(operation.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .lineLimit(1)
                }

                // Target name
                if let targetName = operation.targetCharacterName ?? operation.targetRegionName {
                    Text(targetName)
                        .font(.system(size: 9, design: .serif))
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                        .lineLimit(1)
                }

                // Timing info
                HStack(spacing: 8) {
                    if let turnsRemaining = operation.turnsRemaining {
                        Label("\(turnsRemaining) turns", systemImage: "clock")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(ColdWarTheme.shared.carbonCopy)
                    }

                    // Success chance indicator
                    HStack(spacing: 2) {
                        Image(systemName: operation.successChance >= 60 ? "arrow.up.right" : "arrow.right")
                            .font(.system(size: 7))
                        Text("\(operation.successChance)%")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(operation.successChance >= 60 ? FiftiesColors.approvedGreen : ColdWarTheme.shared.inkGray)
                }
            }

            Spacer()

            // Right side: Status light and label
            VStack(spacing: 4) {
                StatusLight(statusLightType, size: 10)

                Text(operation.status.displayName.uppercased())
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundColor(statusColor)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 50)
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [FiftiesColors.manillaFolder, ColdWarTheme.shared.agedPaper],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    LinearGradient(
                        colors: [bureauColor.opacity(0.3), bureauColor.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
