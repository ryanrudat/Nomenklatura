//
//  StitchDeskComponents.swift
//  Nomenklatura
//
//  Stitch-inspired desk UI components
//

import SwiftUI

// MARK: - Stitch Status Bar (1950s Government Office Style)

struct StitchStatusBar: View {
    let date: String
    let turnNumber: Int
    var hasNotifications: Bool = false
    var onCongressTap: (() -> Void)? = nil
    var onWorldTap: (() -> Void)? = nil
    var onTurnTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            // Congress button - 1950s style
            if let onCongressTap = onCongressTap {
                Button(action: onCongressTap) {
                    VStack(spacing: 1) {
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 14))
                        Text("CONGRESS")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                    .frame(width: 48, height: 32)
                    .background(FiftiesColors.cardstock)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(FiftiesColors.leatherBrown.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Date - typewriter style
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(FiftiesColors.fadedInk)
                Text(date.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(FiftiesColors.typewriterInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()

            // Turn badge - rubber stamp style (tappable to end turn)
            Button {
                onTurnTap?()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(FiftiesColors.stampRed, lineWidth: 1.5)
                        .frame(width: 60, height: 20)

                    HStack(spacing: 3) {
                        Text("TURN \(turnNumber)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(0.5)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundColor(FiftiesColors.stampRed)
                }
                .rotationEffect(.degrees(-2))
            }
            .buttonStyle(.plain)

            // World button - 1950s style
            if let onWorldTap = onWorldTap {
                Button(action: onWorldTap) {
                    VStack(spacing: 1) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                        Text("WORLD")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                    .frame(width: 44, height: 32)
                    .background(FiftiesColors.cardstock)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(FiftiesColors.leatherBrown.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Notification bell - office style
            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundColor(FiftiesColors.leatherBrown)

                    if hasNotifications {
                        Circle()
                            .fill(FiftiesColors.urgentRed)
                            .frame(width: 7, height: 7)
                            .overlay(
                                Circle()
                                    .stroke(FiftiesColors.agedPaper, lineWidth: 1)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                FiftiesColors.agedPaper
                // Subtle paper grain
                Canvas { context, size in
                    for _ in 0..<15 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let length = CGFloat.random(in: 3...8)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.03)), lineWidth: 0.5)
                    }
                }
            }
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(FiftiesColors.leatherBrown.opacity(0.2))
                .frame(height: 1)
        }
    }
}

// MARK: - Player ID Card (1950s Government Badge Style)

struct PlayerIDCard: View {
    let playerName: String
    let title: String
    let clearanceLevel: Int
    var portraitImage: String? = nil

    var body: some View {
        ZStack {
            // "OFFICIAL" watermark - period style
            Text("OFFICIAL")
                .font(.system(size: 36, weight: .black, design: .serif))
                .foregroundColor(FiftiesColors.typewriterInk.opacity(0.04))
                .rotationEffect(.degrees(-15))
                .offset(x: 50, y: 5)

            // Card content
            HStack(alignment: .top, spacing: 14) {
                // Portrait with photo corners
                ZStack {
                    // Photo background
                    Rectangle()
                        .fill(Color(hex: "2A2A2A"))
                        .frame(width: 72, height: 90)

                    if let imageName = portraitImage {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 68, height: 86)
                            .grayscale(0.8)
                            .contrast(1.2)
                            .clipped()
                    } else {
                        // Use the stylized PlayerSilhouette component
                        PlayerSilhouette(size: 68, showFrame: false)
                    }
                }
                .frame(width: 72, height: 90)
                .overlay(
                    // Photo corner mounts as overlay to not affect centering
                    ZStack {
                        // Top-left
                        PhotoCornerMount()
                            .position(x: 8, y: 8)
                        // Top-right
                        PhotoCornerMount()
                            .rotationEffect(.degrees(90))
                            .position(x: 64, y: 8)
                        // Bottom-left
                        PhotoCornerMount()
                            .rotationEffect(.degrees(-90))
                            .position(x: 8, y: 82)
                        // Bottom-right
                        PhotoCornerMount()
                            .rotationEffect(.degrees(180))
                            .position(x: 64, y: 82)
                    }
                )

                // Info section
                VStack(alignment: .leading, spacing: 6) {
                    // Header with ID icon
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(playerName)
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(FiftiesColors.typewriterInk)

                            Text(title.uppercased())
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(FiftiesColors.fadedInk)
                        }

                        Spacer()

                        // Official seal
                        CircularSeal(text: "PSRA", size: 32)
                    }

                    Spacer()

                    // Clearance badge - typewriter style
                    HStack(spacing: 8) {
                        Text("CLEARANCE:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)

                        Text("LEVEL \(clearanceLevel)")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(FiftiesColors.typewriterInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(FiftiesColors.agedPaper)
                            .overlay(
                                Rectangle()
                                    .stroke(FiftiesColors.leatherBrown.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(14)
        .frame(height: 118)
        .background(
            ZStack {
                // Manila folder color
                FiftiesColors.manillaFolder

                // Paper texture
                Canvas { context, size in
                    for _ in 0..<25 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let length = CGFloat.random(in: 5...15)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        context.stroke(path, with: .color(FiftiesColors.leatherBrown.opacity(0.08)), lineWidth: 0.5)
                    }
                }
            }
        )
        .cornerRadius(3)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(FiftiesColors.leatherBrown.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 5, x: 1, y: 3)
    }
}

// Photo corner mount for dossier photos
private struct PhotoCornerMount: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(Color(hex: "3A3A3A"), lineWidth: 1.5)
    }
}

// MARK: - Personal Stats Widget Row (Player's Political Status)

struct PersonalStatsWidgetRow: View {
    let standing: Int
    let network: Int
    let patronFavor: Int
    let rivalThreat: Int

    // Individual tap handlers for contextual navigation
    var onStandingTap: (() -> Void)? = nil
    var onNetworkTap: (() -> Void)? = nil
    var onPatronTap: (() -> Void)? = nil
    var onRivalTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                FiftiesStatWidget(
                    icon: "star.fill",
                    value: "\(standing)",
                    label: "STANDING",
                    status: standing < 25 ? .critical : (standing < 40 ? .negative : (standing >= 70 ? .positive : .neutral)),
                    onTap: onStandingTap
                )
                FiftiesStatWidget(
                    icon: "person.3.sequence.fill",
                    value: "\(network)",
                    label: "NETWORK",
                    status: network < 20 ? .critical : (network < 35 ? .negative : (network >= 60 ? .positive : .neutral)),
                    onTap: onNetworkTap
                )
            }
            HStack(spacing: 10) {
                FiftiesStatWidget(
                    icon: "hand.thumbsup.fill",
                    value: "\(patronFavor)",
                    label: "PATRON",
                    status: patronFavor < 30 ? .critical : (patronFavor < 50 ? .negative : (patronFavor >= 70 ? .positive : .neutral)),
                    onTap: onPatronTap
                )
                FiftiesStatWidget(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(rivalThreat)",
                    label: "RIVAL",
                    status: rivalThreat >= 70 ? .critical : (rivalThreat >= 50 ? .negative : (rivalThreat < 30 ? .positive : .neutral)),
                    onTap: onRivalTap
                )
            }
        }
    }
}

// MARK: - National Stats Widget Row (State Metrics - for Ledger)

struct StatsWidgetRow: View {
    let treasury: Int
    let stability: Int
    let loyalty: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            FiftiesStatWidget(
                icon: "dollarsign.circle",
                value: formatTreasury(treasury),
                label: "TREASURY",
                status: treasury < 100 ? .critical : (treasury < 300 ? .negative : .neutral),
                onTap: onTap
            )
            FiftiesStatWidget(
                icon: "building.columns",
                value: "\(stability)%",
                label: "STABILITY",
                status: stability < 30 ? .critical : (stability < 50 ? .negative : .neutral),
                onTap: onTap
            )
            FiftiesStatWidget(
                icon: "person.3",
                value: "\(loyalty)%",
                label: "LOYALTY",
                status: loyalty < 30 ? .critical : (loyalty < 50 ? .negative : .neutral),
                onTap: onTap
            )
        }
    }

    private func formatTreasury(_ value: Int) -> String {
        if value >= 1000 {
            return "$\(value / 1000).\(value % 1000 / 100)B"
        } else {
            return "$\(value)M"
        }
    }
}

struct FiftiesStatWidget: View {
    let icon: String
    let value: String
    let label: String
    var status: StatWidgetStatus = .neutral
    var onTap: (() -> Void)? = nil

    enum StatWidgetStatus {
        case positive, negative, neutral, critical

        var indicatorColor: Color {
            switch self {
            case .positive: return Color(hex: "28A745")
            case .negative: return Color(hex: "CC7000")
            case .neutral: return FiftiesColors.fadedInk
            case .critical: return FiftiesColors.urgentRed
            }
        }
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 4) {
                // Icon in circle
                ZStack {
                    Circle()
                        .fill(FiftiesColors.agedPaper)
                        .frame(width: 32, height: 32)

                    Circle()
                        .stroke(status.indicatorColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(FiftiesColors.leatherBrown)
                }

                // Value - typewriter style
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(status == .critical ? FiftiesColors.urgentRed : FiftiesColors.typewriterInk)

                // Label
                Text(label)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(FiftiesColors.fadedInk)

                // Status indicator bar
                Rectangle()
                    .fill(status.indicatorColor)
                    .frame(width: 24, height: 2)
                    .opacity(status == .neutral ? 0.3 : 0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(
                ZStack {
                    FiftiesColors.agedPaper

                    // Subtle texture
                    Canvas { context, size in
                        for _ in 0..<8 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            let length = CGFloat.random(in: 3...8)
                            var path = Path()
                            path.move(to: CGPoint(x: x, y: y))
                            path.addLine(to: CGPoint(x: x + length, y: y))
                            context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.02)), lineWidth: 0.5)
                        }
                    }
                }
            )
            .cornerRadius(3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(FiftiesColors.leatherBrown.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Newspaper Preview Card

struct NewspaperPreviewCard: View {
    let masthead: String
    let headline: String
    let brief: String
    var imageURL: String? = nil
    let onReadReport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Masthead row
            HStack {
                Text(masthead.uppercased())
                    .font(.custom("Georgia-Bold", size: 22))
                    .tracking(-1)
                    .foregroundColor(StitchColors.ink)

                Spacer()

                Text("SPECIAL EDITION")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundColor(StitchColors.inkLight)
            }
            .padding(.bottom, 8)

            Rectangle()
                .fill(StitchColors.ink)
                .frame(height: 2)
                .padding(.bottom, 12)

            // Content row
            HStack(alignment: .top, spacing: 16) {
                // Photo
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [StitchColors.ink.opacity(0.2), StitchColors.ink.opacity(0.4)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100)
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay(
                        // Placeholder crowd silhouette
                        VStack {
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(0..<8, id: \.self) { _ in
                                    Capsule()
                                        .fill(StitchColors.ink.opacity(0.5))
                                        .frame(width: CGFloat.random(in: 6...10), height: CGFloat.random(in: 20...35))
                                }
                            }
                            .padding(.bottom, 8)
                        }
                    )
                    .grayscale(1.0)
                    .contrast(1.25)
                    .cornerRadius(2)

                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text(headline.uppercased())
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(StitchColors.ink)
                        .lineLimit(2)

                    Text(brief)
                        .font(.custom("Georgia", size: 12))
                        .foregroundColor(StitchColors.inkFaded)
                        .lineLimit(3)
                        .lineSpacing(2)

                    Spacer()

                    Button(action: onReadReport) {
                        Text("READ REPORT")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(StitchColors.ink)
                            .cornerRadius(2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "FDFBF7"))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(StitchColors.ink.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(1))
    }
}

// MARK: - Pending Actions Section

struct PendingActionsHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(StitchColors.ink.opacity(0.2))
                .frame(height: 1)

            Text("PENDING ACTIONS")
                .font(.system(size: 11, weight: .bold))
                .tracking(3)
                .foregroundColor(StitchColors.inkLight)

            Rectangle()
                .fill(StitchColors.ink.opacity(0.2))
                .frame(height: 1)
        }
    }
}

struct PendingActionCard: View {
    let category: String
    let title: String
    let description: String
    var isUrgent: Bool = false
    var onApprove: (() -> Void)? = nil
    var onDeny: (() -> Void)? = nil
    var onView: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category badge row
            HStack {
                Text(category.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(isUrgent ? StitchColors.stampRed : StitchColors.inkFaded)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isUrgent ? StitchColors.stampRed.opacity(0.1) : StitchColors.ink.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isUrgent ? StitchColors.stampRed.opacity(0.2) : StitchColors.ink.opacity(0.1), lineWidth: 1)
                    )

                Spacer()

                if isUrgent {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(StitchColors.inkLight)
                }
            }
            .padding(.bottom, 8)

            // Title
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(StitchColors.ink)
                .padding(.bottom, 4)

            // Description
            Text(description)
                .font(.system(size: 12))
                .foregroundColor(StitchColors.inkFaded)
                .lineSpacing(2)
                .padding(.bottom, 12)

            // Actions
            if let approve = onApprove, let deny = onDeny {
                Rectangle()
                    .fill(StitchColors.ink.opacity(0.1))
                    .frame(height: 1)
                    .padding(.bottom, 12)

                HStack(spacing: 8) {
                    Button(action: deny) {
                        Text("DENY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(StitchColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(StitchColors.ink.opacity(0.08))
                            .cornerRadius(2)
                    }
                    .buttonStyle(.plain)

                    Button(action: approve) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("APPROVE")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(StitchColors.ink)
                        .cornerRadius(2)
                        .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            } else if let view = onView {
                Button(action: view) {
                    HStack(spacing: 4) {
                        Text("VIEW DOSSIER")
                            .font(.system(size: 11, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(StitchColors.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(StitchColors.paper)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(StitchColors.ink.opacity(0.1), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            if isUrgent {
                Rectangle()
                    .fill(StitchColors.stampRed)
                    .frame(width: 4)
                    .cornerRadius(4, corners: [.topLeft, .bottomLeft])
            }
        }
        .shadow(color: .black.opacity(isUrgent ? 0.12 : 0.06), radius: isUrgent ? 6 : 3, x: 0, y: 2)
    }
}

// MARK: - Sticky Notes FAB

struct StickyNoteFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.system(size: 22))
                    .foregroundColor(StitchColors.ink.opacity(0.8))

                Text("NOTES")
                    .font(.system(size: 7, weight: .bold))
                    .tracking(1)
                    .foregroundColor(StitchColors.ink.opacity(0.6))
            }
            .frame(width: 52, height: 64)
            .background(
                LinearGradient(
                    colors: [Color(hex: "FFF9C4"), Color(hex: "FFF59D")],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(StickyNoteShape())
            .overlay(
                StickyNoteShape()
                    .stroke(StitchColors.ink.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct StickyNoteShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 4
        let foldSize: CGFloat = 12

        // Top left corner
        path.move(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(180),
                   endAngle: .degrees(270),
                   clockwise: false)

        // Top edge
        path.addLine(to: CGPoint(x: rect.width - cornerRadius, y: 0))

        // Top right corner
        path.addArc(center: CGPoint(x: rect.width - cornerRadius, y: cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(270),
                   endAngle: .degrees(0),
                   clockwise: false)

        // Right edge to fold
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - foldSize))

        // Fold
        path.addLine(to: CGPoint(x: rect.width - foldSize, y: rect.height))

        // Bottom edge
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.height))

        // Bottom left corner
        path.addArc(center: CGPoint(x: cornerRadius, y: rect.height - cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(90),
                   endAngle: .degrees(180),
                   clockwise: false)

        path.closeSubpath()
        return path
    }
}

// MARK: - Wood Desk Background

struct WoodDeskBackground: View {
    var body: some View {
        ZStack {
            // Dark wood base
            Color(hex: "241F1C")

            // Wood grain pattern (simplified)
            GeometryReader { geo in
                ForEach(0..<20, id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(Double.random(in: 0.01...0.03)))
                        .frame(width: geo.size.width, height: CGFloat.random(in: 2...8))
                        .offset(y: CGFloat(i) * geo.size.height / 20)
                }
            }
        }
    }
}

// MARK: - Stitch Bottom Tab Bar

struct StitchBottomTabBar: View {
    enum Tab: String, CaseIterable {
        case desk = "Desk"
        case map = "Map"
        case cabinet = "Cabinet"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .desk: return "doc.on.clipboard"
            case .map: return "map"
            case .cabinet: return "person.2"
            case .settings: return "gearshape"
            }
        }
    }

    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == tab {
                                Circle()
                                    .fill(StitchColors.inkFaded)
                                    .frame(width: 40, height: 40)
                            }

                            Image(systemName: tab.icon)
                                .font(.system(size: 22))
                                .foregroundColor(selectedTab == tab ? .white : StitchColors.inkLight)
                        }

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
                            .foregroundColor(selectedTab == tab ? StitchColors.lightText : StitchColors.inkLight)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Color(hex: "1C1917"))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(StitchColors.ink.opacity(0.3))
                .frame(height: 1)
        }
        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: -4)
    }
}

// MARK: - End Turn Confirmation Sheet

struct EndTurnConfirmationSheet: View {
    let game: Game
    let pendingDocuments: [DeskDocument]
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var hasUrgentItems: Bool {
        pendingDocuments.contains { $0.urgencyEnum >= .urgent }
    }

    private var hasCriticalItems: Bool {
        pendingDocuments.contains { $0.urgencyEnum == .critical }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("END TURN \(game.turnNumber)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(FiftiesColors.typewriterInk)

                    Text("Proceed to personal actions?")
                        .font(.system(size: 12, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)
                }

                Spacer()

                // Warning icon if urgent documents pending
                if hasUrgentItems {
                    Image(systemName: hasCriticalItems ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(hasCriticalItems ? FiftiesColors.urgentRed : .orange)
                }
            }
            .padding()
            .background(FiftiesColors.cardstock)

            Divider()

            // Pending items warning
            if !pendingDocuments.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 12))
                            .foregroundColor(FiftiesColors.urgentRed)
                        Text("UNRESOLVED DOCUMENTS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(FiftiesColors.urgentRed)
                    }

                    Text("Failing to act on these documents will have consequences:")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)

                    // List pending documents
                    ForEach(pendingDocuments.prefix(4), id: \.id) { doc in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(doc.urgencyEnum >= .urgent ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
                                .frame(width: 6, height: 6)

                            Text(doc.title)
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundColor(FiftiesColors.typewriterInk)
                                .lineLimit(1)

                            Spacer()

                            Text(doc.urgencyEnum.rawValue.uppercased())
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(doc.urgencyEnum >= .urgent ? FiftiesColors.urgentRed : FiftiesColors.fadedInk)
                        }
                    }

                    if pendingDocuments.count > 4 {
                        Text("...and \(pendingDocuments.count - 4) more")
                            .font(.system(size: 10, design: .serif))
                            .foregroundColor(FiftiesColors.fadedInk)
                            .italic()
                    }
                }
                .padding()
                .background(FiftiesColors.agedPaper.opacity(0.5))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green.opacity(0.7))

                    Text("All documents processed")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)
                }
                .padding(.vertical, 24)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("RETURN TO DESK")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(FiftiesColors.leatherBrown)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(FiftiesColors.leatherBrown, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 6) {
                        Text("END TURN")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(hasUrgentItems ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(FiftiesColors.cardstock)
        }
        .background(FiftiesColors.agedPaper)
    }
}

// MARK: - Previews

#Preview("Status Bar") {
    VStack {
        StitchStatusBar(date: "Oct 1962", turnNumber: 42, hasNotifications: true)
        Spacer()
    }
    .background(Color.gray.opacity(0.2))
}

#Preview("ID Card") {
    PlayerIDCard(
        playerName: "Comrade Director",
        title: "Minister of Interior",
        clearanceLevel: 4
    )
    .padding()
    .background(WoodDeskBackground())
}

#Preview("Stats Row") {
    StatsWidgetRow(treasury: 4200, stability: 65, loyalty: 88)
        .padding()
        .background(WoodDeskBackground())
}

#Preview("Newspaper Preview") {
    NewspaperPreviewCard(
        masthead: "Daily Worker",
        headline: "Unrest in Northern Provinces",
        brief: "Reports indicate growing dissent among the worker unions in the industrial sector. Local enforcement requests immediate guidance."
    ) {
        print("Read report")
    }
    .padding()
    .background(WoodDeskBackground())
}

#Preview("Pending Actions") {
    VStack(spacing: 16) {
        PendingActionsHeader()

        PendingActionCard(
            category: "Urgent",
            title: "Budget Allocation: Secret Police",
            description: "Directorate V requires additional funding for surveillance equipment to monitor opposition leaders.",
            isUrgent: true,
            onApprove: {},
            onDeny: {}
        )

        PendingActionCard(
            category: "Personnel",
            title: "Review: Agent K's Report",
            description: "Field operative K has submitted the weekly intelligence briefing from the Western border.",
            onView: {}
        )
    }
    .padding()
    .background(WoodDeskBackground())
}

#Preview("Sticky Note FAB") {
    ZStack(alignment: .bottomTrailing) {
        WoodDeskBackground()
        StickyNoteFAB {}
            .padding(20)
    }
}
