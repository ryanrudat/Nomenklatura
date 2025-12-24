//
//  CodexView.swift
//  Nomenklatura
//
//  The Codex - encyclopedia of PSRA lore
//

import SwiftUI

struct CodexView: View {
    var onWorldTap: (() -> Void)? = nil
    var onCongressTap: (() -> Void)? = nil
    @Environment(\.theme) var theme
    @State private var selectedCategory: CodexCategory = .institutions
    @State private var selectedEntry: CodexEntry?
    @State private var searchText = ""

    private var displayedEntries: [CodexEntry] {
        if !searchText.isEmpty {
            return CodexDatabase.shared.searchEntries(searchText)
        }
        return CodexDatabase.shared.entriesInCategory(selectedCategory)
    }

    var body: some View {
        ZStack {
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with optional world and congress buttons
                ScreenHeader(
                    title: "THE CODEX",
                    subtitle: "Encyclopedia of the PSRA",
                    showWorldButton: onWorldTap != nil,
                    onWorldTap: onWorldTap,
                    showCongressButton: onCongressTap != nil,
                    onCongressTap: onCongressTap
                )

                // Category tabs
                CodexTabBar(selectedCategory: $selectedCategory)
                    .padding(.horizontal, 15)
                    .padding(.top, 10)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.inkGray)
                    TextField("Search entries...", text: $searchText)
                        .font(theme.bodyFont)
                }
                .padding(10)
                .background(theme.parchmentDark)
                .cornerRadius(8)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)

                // Entry list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedEntries) { entry in
                            CodexEntryRow(entry: entry) {
                                selectedEntry = entry
                            }
                        }

                        if displayedEntries.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(theme.inkLight)

                                Text(searchText.isEmpty ? "No entries in this category" : "No matching entries")
                                    .font(theme.bodyFont)
                                    .foregroundColor(theme.inkGray)
                            }
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.bottom, 120)
                }
            }
        }
        .sheet(item: $selectedEntry) { entry in
            CodexDetailView(entry: entry)
        }
    }
}

// MARK: - Codex Tab Bar

struct CodexTabBar: View {
    @Binding var selectedCategory: CodexCategory
    @Environment(\.theme) var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CodexCategory.allCases, id: \.self) { category in
                    CodexTabButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
        }
    }
}

struct CodexTabButton: View {
    let category: CodexCategory
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.iconName)
                    .font(.system(size: 12))
                Text(category.displayName.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundColor(isSelected ? .white : theme.inkGray)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? theme.sovietRed : theme.parchmentDark)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Codex Entry Row

struct CodexEntryRow: View {
    let entry: CodexEntry
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Category icon
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accentGold)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.term)
                        .font(theme.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)

                    Text(entry.shortDescription)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkLight)
            }
            .padding(12)
            .background(theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Codex Detail View

struct CodexDetailView: View {
    let entry: CodexEntry
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: entry.category.iconName)
                                .font(.system(size: 16))
                                .foregroundColor(theme.accentGold)

                            Text(entry.category.displayName.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1)
                                .foregroundColor(theme.inkGray)
                        }

                        Text(entry.term)
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .foregroundColor(theme.inkBlack)

                        Text(entry.shortDescription)
                            .font(theme.bodyFont)
                            .italic()
                            .foregroundColor(theme.inkGray)
                    }

                    Divider()
                        .background(theme.borderTan)

                    // Full description
                    Text(entry.fullDescription)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)
                        .lineSpacing(6)

                    // Related entries
                    if !entry.relatedEntries.isEmpty {
                        relatedEntriesSection
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
        }
    }

    @ViewBuilder
    private var relatedEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .background(theme.borderTan)

            Text("RELATED ENTRIES")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            FlowLayout(spacing: 8) {
                ForEach(entry.relatedEntries, id: \.self) { relatedId in
                    if let relatedEntry = CodexDatabase.shared.entry(for: relatedId) {
                        RelatedEntryTag(entry: relatedEntry)
                    }
                }
            }
        }
    }
}

// MARK: - Related Entry Tag

struct RelatedEntryTag: View {
    let entry: CodexEntry
    @Environment(\.theme) var theme
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: entry.category.iconName)
                    .font(.system(size: 10))
                Text(entry.term)
                    .font(theme.tagFont)
            }
            .foregroundColor(theme.accentGold)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.parchmentDark)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            CodexDetailView(entry: entry)
        }
    }
}

// MARK: - Preview

#Preview {
    CodexView()
        .environment(\.theme, ColdWarTheme())
}
