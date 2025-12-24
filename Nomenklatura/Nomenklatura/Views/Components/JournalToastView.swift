//
//  JournalToastView.swift
//  Nomenklatura
//
//  Toast notification view for journal entries
//

import SwiftUI

struct JournalToastView: View {
    let toast: JournalToast
    let onDismiss: () -> Void
    @Environment(\.theme) var theme
    @State private var isVisible = false

    var body: some View {
        VStack {
            Spacer()

            // Make entire toast tappable to dismiss
            Button {
                dismissToast()
            } label: {
                HStack(spacing: 12) {
                    // Book icon
                    ZStack {
                        Circle()
                            .fill(theme.accentGold.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: toast.entry.category.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(theme.accentGold)
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("ADDED TO JOURNAL")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1)
                                .foregroundColor(theme.accentGold)

                            // Hint to view in Dossier
                            Text("• View in Dossier")
                                .font(.system(size: 8))
                                .foregroundColor(theme.inkLight)
                        }

                        Text(toast.entry.title)
                            .font(theme.labelFont)
                            .fontWeight(.medium)
                            .foregroundColor(theme.inkBlack)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Arrow indicator (shows it's tappable)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.inkLight)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(theme.parchment)
                .overlay(
                    Rectangle()
                        .fill(theme.accentGold)
                        .frame(width: 3),
                    alignment: .leading
                )
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 100)  // Above bottom nav
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 50)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }

    private func dismissToast() {
        withAnimation(.easeOut(duration: 0.2)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Journal Toast Overlay Modifier

struct JournalToastOverlay: ViewModifier {
    @ObservedObject var journalService = JournalService.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if let toast = journalService.currentToast {
                    JournalToastView(toast: toast) {
                        journalService.dismissCurrentToast()
                    }
                }
            }
    }
}

extension View {
    func journalToastOverlay() -> some View {
        modifier(JournalToastOverlay())
    }
}

// MARK: - Preview

#Preview("Journal Toast") {
    ZStack {
        Color(hex: "F4F1E8")
            .ignoresSafeArea()

        VStack {
            Text("Content behind toast")
            Spacer()
        }

        JournalToastView(
            toast: JournalToast(
                entry: JournalEntry(
                    turnDiscovered: 5,
                    category: .personalityReveal,
                    title: "Character Insight: Director Wallace",
                    content: "You have come to understand Director Wallace's true nature..."
                )
            ),
            onDismiss: {}
        )
    }
    .environment(\.theme, ColdWarTheme())
}
