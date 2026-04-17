//
//  OfficialEmptyState.swift
//  Nomenklatura
//
//  Themed empty-state view for lists that have no content.
//  Replaces generic "No entries" text with brutalist-bureaucratic stamps
//  in keeping with the Soviet political-thriller aesthetic.
//

import SwiftUI

enum OfficialEmptyKind {
    case awaitingTransmission       // Generic "no data yet"
    case recordsClassified          // Locked / restricted
    case noRecordsOnFile            // Empty archive
    case queueEmpty                 // Inbox / pending
    case noTargetsIdentified        // No actionable items
    case nothingToReport            // Activity feed
    case operationsDormant          // No active ops
    case archiveSilent              // Historical / fallen

    var title: String {
        switch self {
        case .awaitingTransmission: return "Awaiting Transmission"
        case .recordsClassified:    return "Records Classified"
        case .noRecordsOnFile:      return "No Records on File"
        case .queueEmpty:           return "Queue Empty"
        case .noTargetsIdentified:  return "No Targets Identified"
        case .nothingToReport:      return "Nothing to Report"
        case .operationsDormant:    return "Operations Dormant"
        case .archiveSilent:        return "Archive Silent"
        }
    }

    var detail: String {
        switch self {
        case .awaitingTransmission:
            return "The dispatch wires are quiet. New material will surface as the situation develops."
        case .recordsClassified:
            return "Higher clearance is required to view these documents at this time."
        case .noRecordsOnFile:
            return "The archives contain nothing matching this query."
        case .queueEmpty:
            return "The inbox is clear. The Apparatus will route new traffic when it arrives."
        case .noTargetsIdentified:
            return "No subjects currently meet the operational criteria."
        case .nothingToReport:
            return "The Apparatus is quiet. Watch the dispatches as the day unfolds."
        case .operationsDormant:
            return "No directives are presently in execution."
        case .archiveSilent:
            return "There are no entries to display at this time."
        }
    }

    var iconName: String {
        switch self {
        case .awaitingTransmission: return "antenna.radiowaves.left.and.right"
        case .recordsClassified:    return "lock.doc.fill"
        case .noRecordsOnFile:      return "tray"
        case .queueEmpty:           return "tray.fill"
        case .noTargetsIdentified:  return "scope"
        case .nothingToReport:      return "newspaper"
        case .operationsDormant:    return "powersleep"
        case .archiveSilent:        return "books.vertical"
        }
    }
}

struct OfficialEmptyState: View {
    let kind: OfficialEmptyKind
    var customDetail: String? = nil
    @Environment(\.theme) var theme

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: kind.iconName)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(theme.inkLight)

            VStack(spacing: 6) {
                Text(kind.title.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .tracking(2.5)
                    .foregroundColor(theme.inkGray)

                Text(customDetail ?? kind.detail)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Rectangle()
                .stroke(theme.inkLight.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: 80, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 30) {
            OfficialEmptyState(kind: .awaitingTransmission)
            OfficialEmptyState(kind: .recordsClassified)
            OfficialEmptyState(kind: .queueEmpty)
            OfficialEmptyState(kind: .nothingToReport)
            OfficialEmptyState(kind: .operationsDormant)
            OfficialEmptyState(kind: .noTargetsIdentified)
        }
        .padding()
    }
    .background(Color(hex: "F5F0E1"))
    .environment(\.theme, ColdWarTheme())
}
