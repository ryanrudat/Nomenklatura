//
//  DocumentCardView.swift
//  Nomenklatura
//
//  A physical document card that sits on the desk - 1950s bureaucratic styling
//

import SwiftUI

struct DocumentCardView: View {
    let document: DeskDocument
    let onTap: () -> Void

    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Document shadow
                Rectangle()
                    .fill(Color.black.opacity(0.15))
                    .offset(x: 2, y: 3)

                // Main document
                VStack(alignment: .leading, spacing: 0) {
                    documentHeader

                    // Divider
                    Text(String(repeating: "-", count: 45))
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk.opacity(0.3))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)

                    // Sender info
                    senderInfo

                    // Body preview
                    Text(String(document.bodyText.prefix(80)) + "...")
                        .font(.system(size: 10, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)

                    Spacer(minLength: 6)

                    // Footer
                    documentFooter
                }
                .frame(height: 140)
                .background(documentBackground)
                .clipShape(Rectangle())
                .overlay(
                    Rectangle()
                        .stroke(FiftiesColors.leatherBrown.opacity(0.15), lineWidth: 0.5)
                )
            }
            .rotationEffect(.degrees(document.rotation))
        }
        .buttonStyle(.plain)
        // Coffee stain overlay
        .overlay(alignment: .topTrailing) {
            if document.hasCoffeeStain {
                Circle()
                    .stroke(Color(hex: "8B6914").opacity(0.06), lineWidth: 2)
                    .frame(width: 25, height: 25)
                    .blur(radius: 0.5)
                    .offset(x: -15, y: 20)
            }
        }
        // Paper clip for multi-page docs
        .overlay(alignment: .topTrailing) {
            if document.requiresDecision && document.options.count > 2 {
                Image(systemName: "paperclip")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6A6A6A").opacity(0.6))
                    .rotationEffect(.degrees(25))
                    .offset(x: -8, y: 8)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var documentHeader: some View {
        HStack(alignment: .top, spacing: 0) {
            // Category stripe
            Rectangle()
                .fill(stripeColor)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                // Document type
                Text(document.documentTypeEnum.displayName.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(stripeColor)

                // Category
                Text(document.categoryEnum.displayName.uppercased())
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(FiftiesColors.fadedInk)
            }
            .padding(.leading, 6)

            Spacer()

            // Urgency stamp
            if let stampText = document.stampText {
                RubberStamp(
                    text: stampText,
                    stampType: document.urgencyEnum == .critical ? .urgent : .classified,
                    rotation: -6,
                    size: .small
                )
                .padding(.trailing, 8)
            }

            // Unread indicator
            if document.statusEnum == .unread {
                Circle()
                    .fill(FiftiesColors.urgentRed)
                    .frame(width: 6, height: 6)
                    .padding(.trailing, 8)
            }
        }
        .padding(.top, 8)
        .frame(height: 32)
    }

    // MARK: - Sender Info

    @ViewBuilder
    private var senderInfo: some View {
        HStack(spacing: 4) {
            Text("FROM:")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk)

            Text(document.sender.uppercased())
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .foregroundColor(FiftiesColors.typewriterInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Footer

    @ViewBuilder
    private var documentFooter: some View {
        HStack {
            // Deadline indicator
            if document.turnDeadline != nil {
                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text("DUE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                }
                .foregroundColor(FiftiesColors.urgentRed.opacity(0.8))
            }

            // Options count
            if document.requiresDecision {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.square")
                        .font(.system(size: 8))
                    Text("\(document.options.count) OPTIONS")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                }
                .foregroundColor(FiftiesColors.fadedInk)
            }

            Spacer()

            // Read hint
            HStack(spacing: 2) {
                Text("READ")
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                Image(systemName: "arrow.right")
                    .font(.system(size: 6))
            }
            .foregroundColor(FiftiesColors.fadedInk)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: - Background

    @ViewBuilder
    private var documentBackground: some View {
        ZStack {
            // Base paper color based on document type
            paperColor

            // Paper texture
            Canvas { context, size in
                for _ in 0..<20 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let length = CGFloat.random(in: 3...8)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + length, y: y))
                    context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.02)), lineWidth: 0.5)
                }
            }

            // Edge aging
            LinearGradient(
                colors: [FiftiesColors.leatherBrown.opacity(0.05), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
        }
    }

    // MARK: - Computed Properties

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

    private var paperColor: Color {
        switch document.documentTypeEnum.visualStyle {
        case .officialMemo, .formalReport:
            return FiftiesColors.agedPaper
        case .handwrittenLetter:
            return Color(hex: "F5F0E0") // Slightly warmer
        case .classifiedCable:
            return Color(hex: "E8E4D8") // Slightly grayer
        case .formDocument:
            return Color(hex: "F0EDE5") // Clean white-ish
        case .anonymousTip:
            return Color(hex: "E5E0D0") // Rougher paper
        case .typewriterDocument:
            return FiftiesColors.agedPaper
        case .newsClipping:
            return Color(hex: "F2EDD8") // Newsprint yellow
        }
    }
}

// MARK: - Document Stack View

/// Shows multiple documents scattered on the desk
struct DocumentStackView: View {
    let documents: [DeskDocument]
    let onDocumentTap: (DeskDocument) -> Void

    // Grid layout for documents
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if documents.isEmpty {
            emptyDeskView
        } else {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(documents, id: \.id) { document in
                    DocumentCardView(document: document) {
                        onDocumentTap(document)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyDeskView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.4))

            Text("DESK CLEAR")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.5))

            Text("No pending documents")
                .font(.system(size: 10, design: .serif))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Preview

private struct DocumentCardPreview: View {
    var body: some View {
        let doc = DeskDocument(
            templateId: "test_001",
            documentType: .memo,
            title: "Production Quota Review",
            sender: "Director Wallace",
            senderTitle: "Head of State Security",
            turnReceived: 5,
            urgency: .urgent,
            category: .economic,
            bodyText: "Comrade, the steel production quotas for the eastern district have fallen behind schedule. Factory supervisors report equipment failures and worker absenteeism. We must decide how to respond before the Central Committee notices.",
            requiresDecision: true,
            options: [
                DocumentOption(id: "1", text: "Increase quotas", shortDescription: "Push harder", effects: [:]),
                DocumentOption(id: "2", text: "Investigate", shortDescription: "Look into it", effects: [:]),
                DocumentOption(id: "3", text: "Report accurately", shortDescription: "Tell the truth", effects: [:])
            ]
        )

        return ScrollView {
            VStack(spacing: 20) {
                DocumentCardView(document: doc) {
                    print("Tapped document")
                }
                .frame(maxWidth: .infinity)

                DocumentStackView(documents: [doc, doc, doc]) { _ in }
            }
            .padding()
        }
        .background(FiftiesColors.leatherBrown.opacity(0.3))
    }
}

#Preview {
    DocumentCardPreview()
}
