//
//  BottomNavBar.swift
//  Nomenklatura
//
//  Bottom navigation bar component
//

import SwiftUI

enum NavTab: String, CaseIterable {
    case desk
    case ledger
    case dossier
    case codex
    case economy

    var title: String {
        switch self {
        case .desk: return "Desk"
        case .ledger: return "Ledger"
        case .dossier: return "Dossier"
        case .codex: return "Codex"
        case .economy: return "Gosplan"
        }
    }

    /// Maps each tab to a politically-charged SovietIcon kind.
    /// Falls back to SF Symbol via SovietIcon when the icon system can't render.
    var sovietIconKind: SovietIcon.Kind {
        switch self {
        case .desk: return .desk
        case .ledger: return .ledger
        case .dossier: return .dossier
        case .codex: return .codex
        case .economy: return .economy
        }
    }

    /// Convert to GameTab for notification service
    var gameTab: GameTab {
        switch self {
        case .desk: return .desk
        case .ledger: return .ledger
        case .dossier: return .dossier
        case .codex: return .codex
        case .economy: return .ladder
        }
    }
}

struct BottomNavBar: View {
    @Binding var selectedTab: NavTab
    var onMenuTap: (() -> Void)? = nil
    var notificationService: NotificationService = NotificationService.shared
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavTab.allCases, id: \.self) { tab in
                NavBarItem(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    hasNotification: notificationService.hasUnread(for: tab.gameTab)
                ) {
                    selectedTab = tab
                    // Mark notifications as read when tab is selected
                    notificationService.markAsRead(for: tab.gameTab)
                }
            }

            // Menu button (if callback provided)
            if let onMenuTap = onMenuTap {
                Button(action: onMenuTap) {
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 30, height: 2)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20))

                        Text("MENU")
                            .font(theme.tagFont)
                            .tracking(1)
                    }
                    .foregroundColor(Color(hex: "666666"))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(theme.schemeCard)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .padding(.horizontal, 20)
        .padding(.bottom, 25)
    }
}

struct NavBarItem: View {
    let tab: NavTab
    let isSelected: Bool
    var hasNotification: Bool = false
    let action: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Soviet red accent bar above selected item
                Rectangle()
                    .fill(isSelected ? theme.sovietRed : Color.clear)
                    .frame(width: 30, height: 2)

                // Icon with notification badge
                ZStack(alignment: .topTrailing) {
                    SovietIcon(kind: tab.sovietIconKind, size: 20)

                    // Notification dot
                    if hasNotification && !isSelected {
                        NotificationDot(isVisible: true, color: theme.stampRed)
                            .offset(x: 4, y: -4)
                    }
                }

                Text(tab.title.uppercased())
                    .font(theme.tagFont)
                    .tracking(1)
            }
            .foregroundColor(isSelected ? theme.accentGold : Color(hex: "666666"))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack {
            Spacer()
            BottomNavBar(selectedTab: .constant(.desk))
        }
    }
    .environment(\.theme, ColdWarTheme())
}
