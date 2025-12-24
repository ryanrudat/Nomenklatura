//
//  ScreenHeader.swift
//  Nomenklatura
//
//  Screen header component used across all main screens
//

import SwiftUI

struct ScreenHeader: View {
    let title: String
    let subtitle: String?
    var showWorldButton: Bool = false
    var onWorldTap: (() -> Void)? = nil
    var showCongressButton: Bool = false
    var onCongressTap: (() -> Void)? = nil
    @Environment(\.theme) var theme

    init(
        title: String,
        subtitle: String? = nil,
        showWorldButton: Bool = false,
        onWorldTap: (() -> Void)? = nil,
        showCongressButton: Bool = false,
        onCongressTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.showWorldButton = showWorldButton
        self.onWorldTap = onWorldTap
        self.showCongressButton = showCongressButton
        self.onCongressTap = onCongressTap
    }

    private var hasButtons: Bool {
        showWorldButton || showCongressButton
    }

    var body: some View {
        VStack(spacing: 0) {
            // Soviet red accent stripe at top
            Rectangle()
                .fill(theme.sovietRed)
                .frame(height: 3)

            // Header content with Congress on LEFT, World on RIGHT
            ZStack {
                // Centered title content
                VStack(spacing: 5) {
                    Text(title.uppercased())
                        .font(theme.headerFontLarge)
                        .tracking(4)
                        .foregroundColor(theme.schemeText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if let subtitle = subtitle {
                        Text(subtitle.uppercased())
                            .font(theme.tagFont)
                            .tracking(2)
                            .foregroundColor(theme.accentGold)
                    }

                    // Gold underline accent
                    Rectangle()
                        .fill(theme.accentGold)
                        .frame(width: 60, height: 2)
                        .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, hasButtons ? 70 : 15)

                // Buttons: Congress LEFT, World RIGHT
                if hasButtons {
                    HStack {
                        // Congress button (LEFT side)
                        if showCongressButton, let onCongressTap = onCongressTap {
                            Button(action: onCongressTap) {
                                VStack(spacing: 2) {
                                    Image(systemName: "building.columns.fill")
                                        .font(.system(size: 18))
                                    Text("CONGRESS")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(theme.sovietRed)
                                .frame(width: 54, height: 38)
                                .background(theme.parchmentDark)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        // World button (RIGHT side)
                        if showWorldButton, let onWorldTap = onWorldTap {
                            Button(action: onWorldTap) {
                                VStack(spacing: 2) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18))
                                    Text("WORLD")
                                        .font(.system(size: 8, weight: .bold))
                                        .tracking(0.5)
                                }
                                .foregroundColor(theme.sovietRed)
                                .frame(width: 54, height: 38)
                                .background(theme.parchmentDark)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .padding(.top, 50)
            .padding(.bottom, 15)
        }
        .frame(maxWidth: .infinity)
        .background(theme.schemeCard)
    }
}

// MARK: - Stamp Badge (URGENT, MEMO, NOTICE, etc.)

struct StampBadge: View {
    let text: String
    @Environment(\.theme) var theme

    /// Style based on stamp type
    private var stampStyle: StampStyle {
        switch text.uppercased() {
        case "URGENT":
            return .urgent
        case "NEW ASSIGNMENT":
            return .newAssignment
        case "MEMO":
            return .memo
        case "NOTICE":
            return .notice
        case "PRIVATE":
            return .private_
        default:
            return .memo
        }
    }

    var body: some View {
        Text(text.uppercased())
            .font(theme.stampFont)
            .tracking(1)
            .foregroundColor(stampStyle.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(
                Rectangle()
                    .stroke(stampStyle.color, lineWidth: stampStyle.borderWidth)
            )
            .rotationEffect(.degrees(stampStyle.rotation))
    }
}

/// Styles for different stamp types
enum StampStyle {
    case urgent         // Red, bold, tilted - crisis events
    case newAssignment  // Gold, prominent - introduction
    case memo           // Gray, subtle - routine
    case notice         // Blue/teal, moderate - opportunity
    case private_       // Purple/brown - character events

    var color: Color {
        switch self {
        case .urgent:
            return Color(hex: "B71C1C")  // Deep red
        case .newAssignment:
            return Color(hex: "B8860B")  // Dark gold
        case .memo:
            return Color(hex: "6B6B6B")  // Gray
        case .notice:
            return Color(hex: "1565C0")  // Blue
        case .private_:
            return Color(hex: "5D4037")  // Brown
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .urgent: return 2.5
        case .newAssignment: return 2
        default: return 1.5
        }
    }

    var rotation: Double {
        switch self {
        case .urgent: return -5
        case .newAssignment: return -3
        case .memo: return -2
        case .notice: return -4
        case .private_: return -3
        }
    }
}

// MARK: - Date Badge

struct DateBadge: View {
    let date: String
    @Environment(\.theme) var theme

    var body: some View {
        Text(date)
            .font(theme.labelFont)
            .foregroundColor(theme.inkGray)
    }
}

// MARK: - Section Divider (for grouping content)

struct SectionDivider: View {
    let title: String
    let isDark: Bool
    @Environment(\.theme) var theme

    init(title: String, isDark: Bool = false) {
        self.title = title
        self.isDark = isDark
    }

    var body: some View {
        HStack {
            Rectangle()
                .fill(isDark ? theme.schemeBorder : theme.borderTan)
                .frame(height: 1)

            Text(title.uppercased())
                .font(theme.tagFont)
                .tracking(2)
                .foregroundColor(isDark ? Color(hex: "666666") : theme.inkLight)
                .fixedSize()

            Rectangle()
                .fill(isDark ? theme.schemeBorder : theme.borderTan)
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }
}

#Preview("Screen Header") {
    VStack(spacing: 0) {
        ScreenHeader(title: "The Desk", subtitle: "The Presidium — Turn 14")
        Spacer()
    }
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}

#Preview("Stamps and Dividers") {
    VStack(spacing: 20) {
        // All stamp types
        VStack(alignment: .leading, spacing: 12) {
            StampBadge(text: "URGENT")
            StampBadge(text: "MEMO")
            StampBadge(text: "NOTICE")
            StampBadge(text: "PRIVATE")
            StampBadge(text: "NEW ASSIGNMENT")
        }
        .padding()
        .background(Color(hex: "FFFEF7"))

        HStack {
            StampBadge(text: "URGENT")
            Spacer()
            DateBadge(date: "March 12, 1962")
        }
        .padding()
        .background(Color(hex: "FFFEF7"))

        SectionDivider(title: "Resources", isDark: false)
            .padding(.horizontal)
            .background(Color(hex: "F4F1E8"))

        SectionDivider(title: "Build Network", isDark: true)
            .padding(.horizontal)
            .background(Color(hex: "1A1A1A"))
    }
    .environment(\.theme, ColdWarTheme())
}
