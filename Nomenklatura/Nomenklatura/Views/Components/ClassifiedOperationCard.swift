//
//  ClassifiedOperationCard.swift
//  Nomenklatura
//
//  Dark, cinematic card for high-stakes classified operations
//  Used for BPS operations, military actions, purges, and crisis decisions
//

import SwiftUI

// MARK: - Operation Data Model

struct ClassifiedOperation: Identifiable {
    let id: UUID
    let decisionNumber: String           // e.g., "#8492"
    let ministry: String                 // e.g., "MINISTRY OF INTERIOR"
    let operationName: String            // e.g., "SILENT FALL"
    let imageRef: String?                // Optional image reference
    let imageName: String?               // Asset name for the image
    let briefingText: String             // Intelligence briefing
    let projectedOutcomes: [OperationOutcome]
    let cost: Int                        // Political capital cost
    let riskLevel: OperationRiskLevel
    let failureProbability: Int          // 0-100
    let securityLevel: Int               // 1-10
    let operationType: OperationType

    init(
        decisionNumber: String,
        ministry: String,
        operationName: String,
        imageRef: String? = nil,
        imageName: String? = nil,
        briefingText: String,
        projectedOutcomes: [OperationOutcome],
        cost: Int,
        riskLevel: OperationRiskLevel,
        failureProbability: Int,
        securityLevel: Int = 5,
        operationType: OperationType = .bpsOperation
    ) {
        self.id = UUID()
        self.decisionNumber = decisionNumber
        self.ministry = ministry
        self.operationName = operationName
        self.imageRef = imageRef
        self.imageName = imageName
        self.briefingText = briefingText
        self.projectedOutcomes = projectedOutcomes
        self.cost = cost
        self.riskLevel = riskLevel
        self.failureProbability = failureProbability
        self.securityLevel = securityLevel
        self.operationType = operationType
    }
}

struct OperationOutcome: Identifiable {
    let id = UUID()
    let stat: String                     // e.g., "LOYALTY", "FEAR", "STABILITY"
    let change: Int                      // Positive or negative
    let isPositive: Bool                 // For color coding (context-dependent)

    var displayText: String {
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(change) \(stat)"
    }
}

enum OperationRiskLevel: String {
    case minimal = "MINIMAL"
    case low = "LOW"
    case moderate = "MODERATE"
    case high = "HIGH"
    case critical = "CRITICAL"

    var color: Color {
        switch self {
        case .minimal: return Color.green
        case .low: return Color(hex: "4CAF50")
        case .moderate: return Color.orange
        case .high: return Color(hex: "E53935")
        case .critical: return Color(hex: "B71C1C")
        }
    }
}

enum OperationType: String {
    case bpsOperation = "BPS OPERATION"
    case militaryAction = "MILITARY ACTION"
    case purge = "INTERNAL PURGE"
    case foreignOperation = "FOREIGN OPERATION"
    case crisisResponse = "CRISIS RESPONSE"
    case blackOperation = "BLACK OPERATION"
}

// MARK: - Main Card View

struct ClassifiedOperationCard: View {
    let operation: ClassifiedOperation
    let game: Game
    let onDismiss: () -> Void
    let onExecute: () -> Void

    @State private var isExecuting = false

    // Dark theme colors
    private let bgDark = Color(hex: "1A2634")
    private let bgMedium = Color(hex: "243447")
    private let bgLight = Color(hex: "2D4052")
    private let accentTeal = Color(hex: "4A7C8C")
    private let textPrimary = Color.white
    private let textSecondary = Color(hex: "8BA4B4")
    private let dangerRed = Color(hex: "E53935")
    private let warningOrange = Color(hex: "FF9800")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Decision badge and title
                    decisionHeader

                    // Operation image
                    operationImage

                    // Briefing text
                    briefingSection

                    // Projected outcomes
                    outcomesSection

                    // Risk assessment
                    riskAssessmentSection

                    // Action buttons
                    actionButtons

                    // Security footer
                    securityFooter
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(bgDark)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("DAILY BRIEFING")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(textPrimary)

                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(textSecondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16))
                    .foregroundColor(textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(bgMedium)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Decision Header

    private var decisionHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Badge row
            HStack(spacing: 12) {
                // Decision number badge
                Text("DECISION \(operation.decisionNumber)")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Ministry
                Text(operation.ministry)
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundColor(textSecondary)
            }

            // Operation name with TOP SECRET stamp
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OPERATION:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(textSecondary)

                    Text(operation.operationName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // TOP SECRET stamp
                topSecretStamp
                    .offset(x: 10, y: -5)
            }
        }
        .padding(16)
        .background(bgMedium)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var topSecretStamp: some View {
        Text("TOP SECRET")
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundColor(dangerRed.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(dangerRed.opacity(0.7), lineWidth: 1.5)
            )
            .rotationEffect(.degrees(12))
    }

    // MARK: - Operation Image

    private var operationImage: some View {
        ZStack(alignment: .bottomLeading) {
            // Image placeholder or actual image
            if let imageName = operation.imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } else {
                // Placeholder with gradient
                LinearGradient(
                    colors: [bgLight, bgMedium],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 180)
                .overlay(
                    Image(systemName: operationTypeIcon)
                        .font(.system(size: 60))
                        .foregroundColor(textSecondary.opacity(0.3))
                )
            }

            // Vignette overlay
            LinearGradient(
                colors: [.clear, bgDark.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Image reference
            if let imageRef = operation.imageRef {
                Text(imageRef)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(textSecondary.opacity(0.7))
                    .padding(8)
                    .background(bgDark.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(12)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var operationTypeIcon: String {
        switch operation.operationType {
        case .bpsOperation: return "eye.fill"
        case .militaryAction: return "shield.fill"
        case .purge: return "xmark.seal.fill"
        case .foreignOperation: return "globe"
        case .crisisResponse: return "exclamationmark.triangle.fill"
        case .blackOperation: return "moon.fill"
        }
    }

    // MARK: - Briefing Section

    private var briefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ClickableNarrativeText(
                text: operation.briefingText,
                game: game,
                font: .system(size: 14),
                color: textPrimary.opacity(0.9)
            )
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(bgMedium)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(bgLight, lineWidth: 1)
        )
    }

    // MARK: - Outcomes Section

    private var outcomesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PROJECTED OUTCOMES")
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundColor(textSecondary)

            // Outcome badges
            OperationFlowLayout(spacing: 8) {
                ForEach(operation.projectedOutcomes) { outcome in
                    outcomeBadge(outcome: outcome)
                }
            }

            // Cost
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 12))
                    Text("COST: \(operation.cost) CAP")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(bgLight)
                .clipShape(Capsule())
            }
        }
    }

    private func outcomeBadge(outcome: OperationOutcome) -> some View {
        HStack(spacing: 4) {
            Image(systemName: outcome.change >= 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 10, weight: .bold))

            Text(outcome.displayText)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            outcome.isPositive ? accentTeal : dangerRed
        )
        .clipShape(Capsule())
    }

    // MARK: - Risk Assessment

    private var riskAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RISK ASSESSMENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(2)
                    .foregroundColor(textSecondary)

                Spacer()

                Text(operation.riskLevel.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(operation.riskLevel.color)
            }

            // Risk bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(bgLight)
                        .frame(height: 8)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [warningOrange, operation.riskLevel.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(operation.failureProbability) / 100, height: 8)
                }
            }
            .frame(height: 8)

            // Failure probability
            HStack {
                Rectangle()
                    .fill(bgLight)
                    .frame(width: 40, height: 4)

                Spacer()

                Text("Failure probability: \(operation.failureProbability)%")
                    .font(.system(size: 10))
                    .italic()
                    .foregroundColor(textSecondary)
            }
        }
        .padding(16)
        .background(bgMedium)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Dismiss button
            Button(action: onDismiss) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("DISMISS")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(bgLight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Execute button
            Button(action: {
                isExecuting = true
                onExecute()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 12, weight: .bold))
                    Text("EXECUTE ORDER")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [bgLight, accentTeal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .disabled(isExecuting)
        }
    }

    // MARK: - Security Footer

    private var securityFooter: some View {
        Text("RESTRICTED ACCESS // LEVEL \(operation.securityLevel)")
            .font(.system(size: 10, weight: .medium))
            .tracking(3)
            .foregroundColor(textSecondary.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

// MARK: - Flow Layout for Badges

struct OperationFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = OperationFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = OperationFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct OperationFlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Preview

#Preview("Classified Operation Card") {
    let game = Game(campaignId: "coldwar")

    ZStack {
        Color.black.ignoresSafeArea()

        ClassifiedOperationCard(
            operation: ClassifiedOperation(
                decisionNumber: "#8492",
                ministry: "MINISTRY OF INTERIOR",
                operationName: "SILENT FALL",
                imageRef: "IMG_REF_332.01",
                briefingText: "Intelligence suggests a mole in the Ministry. Authorizing a full purge will immediately stabilize party loyalty but will significantly raise public unrest and draw international attention.",
                projectedOutcomes: [
                    OperationOutcome(stat: "LOYALTY", change: -20, isPositive: false),
                    OperationOutcome(stat: "FEAR", change: 15, isPositive: true)
                ],
                cost: 50,
                riskLevel: .high,
                failureProbability: 75,
                securityLevel: 5,
                operationType: .bpsOperation
            ),
            game: game,
            onDismiss: { print("Dismissed") },
            onExecute: { print("Executed") }
        )
        .padding(20)
    }
}

#Preview("Military Action") {
    let game = Game(campaignId: "coldwar")

    ZStack {
        Color.black.ignoresSafeArea()

        ClassifiedOperationCard(
            operation: ClassifiedOperation(
                decisionNumber: "#1147",
                ministry: "MINISTRY OF DEFENSE",
                operationName: "IRON CURTAIN",
                imageRef: "MIL_OPS_047.12",
                briefingText: "Border tensions with Canada have reached critical levels. Deploying additional troops to the northern frontier will demonstrate resolve but may escalate the conflict.",
                projectedOutcomes: [
                    OperationOutcome(stat: "MILITARY", change: 15, isPositive: true),
                    OperationOutcome(stat: "TREASURY", change: -30, isPositive: false),
                    OperationOutcome(stat: "INTL STANDING", change: -10, isPositive: false)
                ],
                cost: 80,
                riskLevel: .critical,
                failureProbability: 40,
                securityLevel: 8,
                operationType: .militaryAction
            ),
            game: game,
            onDismiss: { print("Dismissed") },
            onExecute: { print("Executed") }
        )
        .padding(20)
    }
}
