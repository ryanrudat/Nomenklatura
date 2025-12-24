//
//  DocumentDetailView.swift
//  Nomenklatura
//
//  Full document view when a desk document is opened - 1950s bureaucratic styling
//

import SwiftUI
import SwiftData

struct DocumentDetailView: View {
    let document: DeskDocument
    let game: Game
    let onDismiss: () -> Void
    let onOptionSelected: (DocumentOption) -> Void

    @State private var selectedOptionId: String?
    @State private var dragOffset: CGFloat = 0
    @Environment(\.theme) var theme

    private let dismissThreshold: CGFloat = 150

    var body: some View {
        ZStack {
            // Dimmed background - dims more as you pull down
            Color.black.opacity(0.5 * (1 - min(dragOffset / 300, 0.5)))
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 0) {
                // Pull indicator
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                // Close button - always show for easy dismissal
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(.horizontal)
                }

                ScrollView {
                    VStack(spacing: 15) {
                        // Main document
                        documentContent

                        // Options (if requires decision)
                        if document.requiresDecision {
                            optionsSection
                        }

                        // Action buttons
                        actionButtons
                    }
                    .padding(15)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 120) // Space for tab bar
                }
                .background(theme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 80)
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward dragging
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > dismissThreshold {
                            // Dismiss
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                onDismiss()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .transition(.opacity)
    }

    // MARK: - Document Content

    @ViewBuilder
    private var documentContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with classification stripe
            HStack(alignment: .top) {
                // Classification stripe
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    // Document type header
                    Text(document.documentTypeEnum.displayName.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(stripeColor)

                    // Classification if present
                    if let classification = document.classification {
                        Text(classification)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(FiftiesColors.urgentRed)
                    }

                    // Date
                    Text("DATE: \(formattedDate)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                }

                Spacer()

                // Urgency stamp
                if document.hasStamp, let stampText = document.stampText {
                    RubberStamp(
                        text: stampText,
                        stampType: document.urgencyEnum == .critical ? .urgent : .classified,
                        rotation: -8,
                        size: .medium
                    )
                }
            }
            .padding(.bottom, 12)

            // Typewriter divider
            Text(String(repeating: "=", count: 45))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.3))
                .padding(.bottom, 12)

            // Header text (TO/FROM/RE format)
            if let header = document.headerText {
                Text(header)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(FiftiesColors.fadedInk)
                    .padding(.bottom, 8)
            }

            // Sender info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("FROM:")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)

                    TappableName(name: document.sender, game: game)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }

                if let title = document.senderTitle {
                    Text(title.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                        .padding(.leading, 48)
                }
            }
            .padding(.bottom, 14)

            // Divider
            Text(String(repeating: "-", count: 50))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.3))
                .padding(.bottom, 12)

            // Title
            Text(document.title)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(FiftiesColors.typewriterInk)
                .padding(.bottom, 10)

            // Body text with clickable names
            ClickableNarrativeText(
                text: document.bodyText,
                game: game,
                font: .system(size: 13, design: .serif),
                color: FiftiesColors.typewriterInk,
                lineSpacing: 6
            )

            // Footnote if present
            if let footnote = document.footnoteText {
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle()
                        .fill(FiftiesColors.fadedInk.opacity(0.2))
                        .frame(height: 1)
                        .padding(.vertical, 8)

                    Text(footnote)
                        .font(.system(size: 11, design: document.isHandwritten ? .serif : .monospaced))
                        .italic()
                        .foregroundColor(FiftiesColors.fadedInk)
                }
            }

            // Deadline warning
            if document.turnDeadline != nil {
                let remaining = document.turnsRemaining(currentTurn: game.turnNumber) ?? 0
                deadlineWarning(remaining: remaining)
            }
        }
        .padding(18)
        .background(documentBackground)
        .overlay(
            Rectangle()
                .stroke(FiftiesColors.leatherBrown.opacity(0.2), lineWidth: 1)
        )
        .modifier(CharacterSheetOverlayModifier(game: game))
        .shadow(color: .black.opacity(0.12), radius: 4, x: 2, y: 3)
    }

    @ViewBuilder
    private func deadlineWarning(remaining: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text("DEADLINE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)

                Text(remaining == 0 ? "IMMEDIATE RESPONSE REQUIRED" : "Response required within \(remaining) turn\(remaining == 1 ? "" : "s")")
                    .font(.system(size: 10, design: .serif))
            }

            Spacer()
        }
        .foregroundColor(remaining == 0 ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(remaining == 0 ? FiftiesColors.urgentRed.opacity(0.1) : FiftiesColors.leatherBrown.opacity(0.08))
        )
        .padding(.top, 12)
    }

    // MARK: - Options Section

    @ViewBuilder
    private var optionsSection: some View {
        VStack(spacing: 10) {
            ForEach(document.options, id: \.id) { option in
                DocumentOptionCardView(
                    option: option,
                    isSelected: selectedOptionId == option.id
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedOptionId = option.id
                    }
                }
            }
        }

        // Confirm button
        if selectedOptionId != nil {
            Button {
                if let optionId = selectedOptionId,
                   let option = document.options.first(where: { $0.id == optionId }) {
                    onOptionSelected(option)
                }
            } label: {
                Text("CONFIRM DECISION")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(FiftiesColors.stampRed)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
            .padding(.top, 15)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if !document.requiresDecision {
            HStack(spacing: 12) {
                // File button
                Button {
                    document.file()
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                        Text("FILE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(FiftiesColors.leatherBrown, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Acknowledge button
                Button {
                    document.markAsRead()
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12))
                        Text("ACKNOWLEDGE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(FiftiesColors.leatherBrown)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        RevolutionaryCalendar.formatTurnFull(document.turnReceived).uppercased()
    }

    private var stripeColor: Color {
        switch document.urgencyEnum {
        case .critical, .urgent:
            return FiftiesColors.urgentRed
        case .priority:
            return FiftiesColors.leatherBrown
        case .routine:
            return FiftiesColors.fadedInk
        }
    }

    @ViewBuilder
    private var documentBackground: some View {
        ZStack {
            FiftiesColors.agedPaper

            // Paper texture
            Canvas { context, size in
                for _ in 0..<40 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let length = CGFloat.random(in: 4...12)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + length, y: y))
                    context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.025)), lineWidth: 0.5)
                }
            }

            // Aging gradient
            LinearGradient(
                colors: [FiftiesColors.leatherBrown.opacity(0.06), Color.clear, FiftiesColors.leatherBrown.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Document Option Card

struct DocumentOptionCardView: View {
    let option: DocumentOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? FiftiesColors.stampRed : FiftiesColors.fadedInk, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(FiftiesColors.stampRed)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.text)
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .multilineTextAlignment(.leading)

                    // Effects preview
                    if !option.effects.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(option.effects.keys.sorted().prefix(3)), id: \.self) { key in
                                if let value = option.effects[key], value != 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: value > 0 ? "arrow.up" : "arrow.down")
                                            .font(.system(size: 8))
                                        Text(formatStatName(key))
                                            .font(.system(size: 8, design: .monospaced))
                                    }
                                    .foregroundColor(value > 0 ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? FiftiesColors.stampRed.opacity(0.08) : FiftiesColors.agedPaper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? FiftiesColors.stampRed : FiftiesColors.leatherBrown.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func formatStatName(_ key: String) -> String {
        switch key {
        case "stability": return "STAB"
        case "popularSupport": return "POP"
        case "standing": return "STAND"
        case "treasury": return "TREAS"
        case "militaryLoyalty": return "MIL"
        case "eliteLoyalty": return "ELITE"
        default: return key.prefix(4).uppercased()
        }
    }
}

// MARK: - Preview

private struct DocumentDetailPreview: View {
    var body: some View {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: Game.self, configurations: config)
        let game = Game(campaignId: "coldwar")
        container.mainContext.insert(game)

        let doc = DeskDocument(
            templateId: "test_001",
            documentType: .memo,
            title: "Production Quota Review",
            sender: "Director Wallace",
            senderTitle: "Head of State Security",
            turnReceived: 5,
            urgency: .urgent,
            category: .economic,
            bodyText: "Comrade, the steel production quotas for the eastern district have fallen behind schedule. Factory supervisors report equipment failures and worker absenteeism.\n\nThe Central Committee expects results. We must decide how to respond before questions are asked.",
            requiresDecision: true,
            options: [
                DocumentOption(id: "1", text: "Increase quotas and demand explanations from supervisors", shortDescription: "Push harder", effects: ["industrialOutput": 5, "popularSupport": -10]),
                DocumentOption(id: "2", text: "Send investigators to assess the real situation", shortDescription: "Investigate", effects: ["stability": 5]),
                DocumentOption(id: "3", text: "Report the shortfall accurately to the Committee", shortDescription: "Tell truth", effects: ["standing": -5, "reputationLoyal": 10])
            ]
        )

        return DocumentDetailView(
            document: doc,
            game: game,
            onDismiss: { },
            onOptionSelected: { _ in }
        )
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
    }
}

#Preview {
    DocumentDetailPreview()
}
