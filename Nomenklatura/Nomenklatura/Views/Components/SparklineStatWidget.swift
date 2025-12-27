//
//  SparklineStatWidget.swift
//  Nomenklatura
//
//  Personal stat widget with integrated vintage sparkline chart
//

import SwiftUI

// MARK: - Sparkline Stat Widget

/// 1950s-style stat display with embedded sparkline trend chart
struct SparklineStatWidget: View {
    let icon: String
    let value: String
    let label: String
    let history: [Int]
    var dangerThreshold: Int = 40
    var safeThreshold: Int = 70
    var invertThresholds: Bool = false  // For rival threat where high = bad
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

    private var effectiveDangerThreshold: Int {
        invertThresholds ? safeThreshold : dangerThreshold
    }

    private var effectiveSafeThreshold: Int {
        invertThresholds ? dangerThreshold : safeThreshold
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: 3) {
                // Icon in circle with value overlay
                ZStack {
                    Circle()
                        .fill(FiftiesColors.agedPaper)
                        .frame(width: 28, height: 28)

                    Circle()
                        .stroke(status.indicatorColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(FiftiesColors.leatherBrown)
                }

                // Value - typewriter style
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(status == .critical ? FiftiesColors.urgentRed : FiftiesColors.typewriterInk)

                // Sparkline
                if history.count >= 2 {
                    VintageSparklineView(
                        data: history,
                        dangerThreshold: effectiveDangerThreshold,
                        safeThreshold: effectiveSafeThreshold,
                        showLabels: false,
                        height: 16,
                        showBaseline: false,
                        showTrendArrow: true,
                        handDrawnWobble: 0.5
                    )
                    .frame(height: 16)
                } else {
                    // Placeholder when no history
                    Rectangle()
                        .fill(FiftiesColors.fadedInk.opacity(0.1))
                        .frame(height: 16)
                        .overlay(
                            Text("—")
                                .font(.system(size: 8))
                                .foregroundColor(FiftiesColors.fadedInk.opacity(0.5))
                        )
                }

                // Label
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundColor(FiftiesColors.fadedInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(
                ZStack {
                    FiftiesColors.agedPaper

                    // Subtle texture
                    Canvas { context, size in
                        for _ in 0..<6 {
                            let x = CGFloat.random(in: 0...size.width)
                            let y = CGFloat.random(in: 0...size.height)
                            let length = CGFloat.random(in: 3...6)
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

// MARK: - Enhanced Personal Stats Row with Sparklines

/// Personal stats widget row with integrated sparklines showing historical trends
struct SparklinePersonalStatsRow: View {
    let standing: Int
    let network: Int
    let patronFavor: Int
    let rivalThreat: Int

    // Historical data for sparklines
    var standingHistory: [Int] = []
    var networkHistory: [Int] = []
    var patronFavorHistory: [Int] = []
    var rivalThreatHistory: [Int] = []

    // Individual tap handlers for contextual navigation
    var onStandingTap: (() -> Void)? = nil
    var onNetworkTap: (() -> Void)? = nil
    var onPatronTap: (() -> Void)? = nil
    var onRivalTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                SparklineStatWidget(
                    icon: "star.fill",
                    value: "\(standing)",
                    label: "STANDING",
                    history: standingHistory,
                    dangerThreshold: 25,
                    safeThreshold: 70,
                    status: standingStatus,
                    onTap: onStandingTap
                )
                SparklineStatWidget(
                    icon: "person.3.sequence.fill",
                    value: "\(network)",
                    label: "NETWORK",
                    history: networkHistory,
                    dangerThreshold: 20,
                    safeThreshold: 60,
                    status: networkStatus,
                    onTap: onNetworkTap
                )
            }
            HStack(spacing: 8) {
                SparklineStatWidget(
                    icon: "hand.thumbsup.fill",
                    value: "\(patronFavor)",
                    label: "PATRON",
                    history: patronFavorHistory,
                    dangerThreshold: 30,
                    safeThreshold: 70,
                    status: patronStatus,
                    onTap: onPatronTap
                )
                SparklineStatWidget(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(rivalThreat)",
                    label: "RIVAL",
                    history: rivalThreatHistory,
                    dangerThreshold: 30,  // Low is good
                    safeThreshold: 50,    // High is bad
                    invertThresholds: true,
                    status: rivalStatus,
                    onTap: onRivalTap
                )
            }
        }
    }

    // Status calculations
    private var standingStatus: SparklineStatWidget.StatWidgetStatus {
        if standing < 25 { return .critical }
        if standing < 40 { return .negative }
        if standing >= 70 { return .positive }
        return .neutral
    }

    private var networkStatus: SparklineStatWidget.StatWidgetStatus {
        if network < 20 { return .critical }
        if network < 35 { return .negative }
        if network >= 60 { return .positive }
        return .neutral
    }

    private var patronStatus: SparklineStatWidget.StatWidgetStatus {
        if patronFavor < 30 { return .critical }
        if patronFavor < 50 { return .negative }
        if patronFavor >= 70 { return .positive }
        return .neutral
    }

    private var rivalStatus: SparklineStatWidget.StatWidgetStatus {
        // Inverted: high rival threat is bad
        if rivalThreat >= 70 { return .critical }
        if rivalThreat >= 50 { return .negative }
        if rivalThreat < 30 { return .positive }
        return .neutral
    }
}

// MARK: - Stat Detail Sheet

/// Full-screen sheet showing detailed stat history with large chart
struct StatDetailSheet: View {
    let statName: String
    let currentValue: Int
    let history: [Int]
    let description: String
    var dangerThreshold: Int = 40
    var safeThreshold: Int = 70
    var onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Current value header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(statName.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(FiftiesColors.fadedInk)

                            Text("\(currentValue)")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundColor(valueColor)
                        }

                        Spacer()

                        // Trend indicator
                        VStack(alignment: .trailing, spacing: 4) {
                            Image(systemName: trendIcon)
                                .font(.system(size: 24))
                                .foregroundColor(trendColor)

                            Text(trendLabel)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(FiftiesColors.fadedInk)
                        }
                    }
                    .padding()
                    .background(FiftiesColors.cardstock)
                    .overlay(
                        Rectangle()
                            .stroke(FiftiesColors.leatherBrown.opacity(0.2), lineWidth: 1)
                    )

                    // Description
                    Text(description)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(FiftiesColors.fadedInk)
                        .padding(.horizontal)

                    // Large sparkline chart
                    DetailedSparklineView(
                        data: history,
                        title: "\(statName) HISTORY",
                        dangerThreshold: dangerThreshold,
                        safeThreshold: safeThreshold,
                        height: 160
                    )
                    .padding(.horizontal)

                    // Statistics summary
                    if !history.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("STATISTICS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(FiftiesColors.fadedInk)

                            HStack(spacing: 16) {
                                StatisticBox(label: "HIGHEST", value: "\(history.max() ?? 0)")
                                StatisticBox(label: "LOWEST", value: "\(history.min() ?? 0)")
                                StatisticBox(label: "AVERAGE", value: "\(history.reduce(0, +) / max(1, history.count))")
                                StatisticBox(label: "TURNS", value: "\(history.count)")
                            }
                        }
                        .padding()
                        .background(FiftiesColors.agedPaper)
                        .overlay(
                            Rectangle()
                                .stroke(Color(hex: "D4C9B0"), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
            .background(FiftiesColors.freshPaper)
            .navigationTitle(statName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                }
            }
        }
    }

    private var valueColor: Color {
        if currentValue < dangerThreshold {
            return Color("statLow")
        } else if currentValue > safeThreshold {
            return Color("statHigh")
        } else {
            return FiftiesColors.typewriterInk
        }
    }

    private var trend: SparklineTrend {
        guard history.count >= 2 else { return .stable }
        let recent = Array(history.suffix(3))
        let first = recent.first ?? 50
        let last = recent.last ?? 50
        let diff = last - first

        if diff > 5 { return .rising }
        if diff < -5 { return .falling }
        return .stable
    }

    private var trendIcon: String {
        switch trend {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch trend {
        case .rising: return Color("statHigh")
        case .falling: return Color("statLow")
        case .stable: return FiftiesColors.fadedInk
        }
    }

    private var trendLabel: String {
        switch trend {
        case .rising: return "RISING"
        case .falling: return "FALLING"
        case .stable: return "STABLE"
        }
    }
}

// MARK: - Statistic Box

struct StatisticBox: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(FiftiesColors.typewriterInk)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews

#Preview("Sparkline Stat Widget") {
    HStack(spacing: 12) {
        SparklineStatWidget(
            icon: "star.fill",
            value: "67",
            label: "STANDING",
            history: [45, 52, 58, 62, 67],
            status: .positive
        )

        SparklineStatWidget(
            icon: "exclamationmark.triangle.fill",
            value: "72",
            label: "RIVAL",
            history: [50, 55, 62, 68, 72],
            invertThresholds: true,
            status: .critical
        )
    }
    .padding()
    .background(Color(hex: "241F1C"))
}

#Preview("Personal Stats Row") {
    SparklinePersonalStatsRow(
        standing: 67,
        network: 45,
        patronFavor: 72,
        rivalThreat: 38,
        standingHistory: [50, 55, 58, 62, 67],
        networkHistory: [35, 38, 42, 45, 45],
        patronFavorHistory: [60, 65, 68, 70, 72],
        rivalThreatHistory: [55, 50, 45, 42, 38]
    )
    .padding()
    .background(Color(hex: "241F1C"))
}

#Preview("Stat Detail Sheet") {
    StatDetailSheet(
        statName: "Standing",
        currentValue: 67,
        history: [45, 48, 52, 55, 58, 62, 60, 63, 67],
        description: "Your reputation and influence within the Party apparatus. Higher standing grants access to better positions and protects you from rivals.",
        onDismiss: {}
    )
}
