//
//  MemoTrayView.swift
//  Nomenklatura
//
//  Floating memo tray for quick access to saved notes from the Desk
//  Inspired by Suzerain's constant information feed and Disco Elysium's Thought Cabinet
//

import SwiftUI

// MARK: - Memo Tray Button (Floating on Desk)

struct MemoTrayButton: View {
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    private var unreadCount: Int {
        game.unreadJournalCount
    }

    private var totalCount: Int {
        game.journalEntries.count
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Stitch-style sticky note
                VStack(spacing: 4) {
                    Image(systemName: "note.text")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "5D4E37").opacity(0.8))

                    Text("NOTES")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Color(hex: "5D4E37").opacity(0.6))
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
                        .stroke(Color(hex: "5D4E37").opacity(0.15), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    // Red tape at top
                    Rectangle()
                        .fill(Color(hex: "8B0000").opacity(0.25))
                        .frame(height: 4)
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                }
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                // Unread badge
                if unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(theme.stampRed)
                            .frame(width: 20, height: 20)

                        Text(unreadCount < 10 ? "\(unreadCount)" : "9+")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(totalCount > 0 ? 1 : 0.6)
    }
}

// MARK: - Memo Slide-Out Panel

struct MemoSlideOutPanel: View {
    let game: Game
    let isOpen: Bool
    let onClose: () -> Void
    let onViewAll: () -> Void
    @Environment(\.theme) var theme

    private var recentNotes: [JournalEntry] {
        Array(game.journalEntries.prefix(5))
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()

                // Panel
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(theme.accentGold)

                        Text("SAVED NOTES")
                            .font(.system(size: 12, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkBlack)

                        Spacer()

                        if game.unreadJournalCount > 0 {
                            Text("\(game.unreadJournalCount) NEW")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.stampRed)
                                .clipShape(Capsule())
                        }

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(theme.inkGray)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(theme.parchmentDark)

                    Divider()

                    if recentNotes.isEmpty {
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 32))
                                .foregroundColor(theme.inkLight)

                            Text("No notes yet")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkGray)

                            Text("Tap \"Note this\" on briefings\nto save important information")
                                .font(.system(size: 11))
                                .foregroundColor(theme.inkLight)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    } else {
                        // Recent notes list
                        ScrollView {
                            VStack(spacing: 1) {
                                ForEach(recentNotes) { entry in
                                    MemoNoteRow(entry: entry, game: game)
                                }
                            }
                            .padding(.vertical, 8)
                        }

                        Divider()

                        // View all button
                        Button(action: onViewAll) {
                            HStack {
                                Text("View All in Dossier")
                                    .font(.system(size: 12, weight: .medium))

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(theme.accentGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: min(300, geometry.size.width * 0.8))
                .background(theme.parchment)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 20, x: -5, y: 0)
                .offset(x: isOpen ? 0 : 320)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isOpen)
            }
            .padding(.trailing, 8)
            .padding(.top, 100)  // Below header
            .padding(.bottom, 120)  // Above nav bar
        }
        .background(
            Color.black.opacity(isOpen ? 0.3 : 0)
                .ignoresSafeArea()
                .onTapGesture { onClose() }
                .animation(.easeInOut(duration: 0.2), value: isOpen)
        )
        .allowsHitTesting(isOpen)
    }
}

// MARK: - Memo Note Row

struct MemoNoteRow: View {
    let entry: JournalEntry
    let game: Game
    @Environment(\.theme) var theme
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
                if isExpanded && !entry.isRead {
                    game.markJournalEntryRead(id: entry.id)
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    // Category icon
                    Image(systemName: entry.category.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(theme.accentGold)
                        .frame(width: 16)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                            .font(.system(size: 12, weight: entry.isRead ? .regular : .semibold))
                            .foregroundColor(theme.inkBlack)
                            .lineLimit(isExpanded ? nil : 1)
                            .multilineTextAlignment(.leading)

                        Text("Turn \(entry.turnDiscovered)")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }

                    Spacer()

                    // Unread dot
                    if !entry.isRead {
                        Circle()
                            .fill(theme.stampRed)
                            .frame(width: 6, height: 6)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }

                // Expanded content
                if isExpanded {
                    Text(entry.content)
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)
                        .lineLimit(4)
                        .padding(.leading, 24)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                entry.isRead ? Color.clear : theme.parchment.opacity(0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Memo Tray Button") {
    ZStack {
        Color(hex: "2C2C2C").ignoresSafeArea()

        MemoTrayButton(
            game: {
                let g = Game(campaignId: "coldwar")
                // Add sample entries
                g.addJournalEntry(JournalEntry(
                    turnDiscovered: 3,
                    category: .personalityReveal,
                    title: "Minister Wallace's Ambitions",
                    content: "You've discovered that Wallace harbors ambitions beyond his station..."
                ))
                g.addJournalEntry(JournalEntry(
                    turnDiscovered: 2,
                    category: .secretIntelligence,
                    title: "Faction Movements",
                    content: "Intelligence suggests the reformists are planning a move..."
                ))
                return g
            }(),
            onTap: {}
        )
    }
    .environment(\.theme, ColdWarTheme())
}
