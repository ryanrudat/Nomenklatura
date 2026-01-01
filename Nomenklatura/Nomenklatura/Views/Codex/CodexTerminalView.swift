//
//  CodexTerminalView.swift
//  Nomenklatura
//
//  Secure Party Communication Terminal - NPC messaging interface
//

import SwiftUI
import SwiftData

// Helper wrapper to make UUID identifiable for sheet presentation
struct ThreadIdentifier: Identifiable {
    let id: UUID
}

struct CodexTerminalView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) var theme
    @StateObject private var codexService = CodexService.shared

    @State private var selectedFilter: MessageFilter = .all
    @State private var selectedThread: ThreadIdentifier?

    enum MessageFilter: String, CaseIterable {
        case all = "ALL"
        case unread = "UNREAD"
        case urgent = "URGENT"
        case archived = "ARCHIVED"

        var iconName: String {
            switch self {
            case .all: return "tray.full.fill"
            case .unread: return "envelope.badge.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            case .archived: return "archivebox.fill"
            }
        }
    }

    /// Thread summaries - one entry per conversation thread
    private var filteredThreads: [(threadId: UUID, latestMessage: CodexMessage, messageCount: Int, hasUnread: Bool)] {
        switch selectedFilter {
        case .all:
            return game.codexThreadSummaries
        case .unread:
            return game.codexThreadSummaries.filter { $0.hasUnread }
        case .urgent:
            return game.codexThreadSummaries.filter {
                $0.latestMessage.codexPriority == .critical || $0.latestMessage.codexPriority == .urgent
            }
        case .archived:
            // For archived, we need separate logic - show archived threads
            return archivedThreadSummaries
        }
    }

    /// Archived thread summaries
    private var archivedThreadSummaries: [(threadId: UUID, latestMessage: CodexMessage, messageCount: Int, hasUnread: Bool)] {
        var threadMap: [UUID: [CodexMessage]] = [:]

        for message in game.codexMessages where message.isArchived {
            guard let threadId = message.threadId else { continue }
            threadMap[threadId, default: []].append(message)
        }

        return threadMap.compactMap { threadId, messages in
            guard let latest = messages.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
            return (threadId, latest, messages.count, false)
        }.sorted { $0.latestMessage.timestamp > $1.latestMessage.timestamp }
    }

    var body: some View {
        ZStack {
            // Parchment background
            theme.parchment.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                terminalHeader

                // Filter tabs
                filterTabs
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Message list or empty state
                if filteredThreads.isEmpty {
                    emptyState
                } else {
                    threadList
                }
            }
        }
        .sheet(item: $selectedThread) { thread in
            CodexThreadView(threadId: thread.id, game: game)
        }
    }

    // MARK: - Header

    private var terminalHeader: some View {
        VStack(spacing: 4) {
            HStack {
                // Terminal icon
                Image(systemName: "terminal.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentGold)

                Text("SECURE TERMINAL")
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(theme.inkGray)

                Spacer()

                // Unread badge
                if game.unreadCodexCount > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(theme.stampRed)
                            .frame(width: 8, height: 8)
                        Text("\(game.unreadCodexCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.stampRed)
                    }
                }
            }

            // Decorative line
            Rectangle()
                .fill(theme.inkGray.opacity(0.3))
                .frame(height: 1)

            Text("PARTY COMMUNICATIONS NETWORK")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundColor(theme.inkLight)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.parchmentDark)
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(MessageFilter.allCases, id: \.self) { filter in
                filterTab(filter)
            }
        }
    }

    private func filterTab(_ filter: MessageFilter) -> some View {
        let isSelected = selectedFilter == filter
        let count = countForFilter(filter)

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: filter.iconName)
                    .font(.system(size: 10))
                Text(filter.rawValue)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                if count > 0 && filter != .all {
                    Text("(\(count))")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(isSelected ? .white : theme.inkGray)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? theme.stampRed : theme.parchmentDark)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.clear : theme.borderTan, lineWidth: 1)
            )
        }
    }

    private func countForFilter(_ filter: MessageFilter) -> Int {
        switch filter {
        case .all:
            return game.codexThreadSummaries.count
        case .unread:
            return game.codexThreadSummaries.filter { $0.hasUnread }.count
        case .urgent:
            return game.codexThreadSummaries.filter {
                $0.latestMessage.codexPriority == .critical || $0.latestMessage.codexPriority == .urgent
            }.count
        case .archived:
            return archivedThreadSummaries.count
        }
    }

    // MARK: - Thread List

    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredThreads, id: \.threadId) { thread in
                    CodexThreadCard(
                        threadId: thread.threadId,
                        latestMessage: thread.latestMessage,
                        messageCount: thread.messageCount,
                        hasUnread: thread.hasUnread,
                        game: game
                    ) {
                        selectedThread = ThreadIdentifier(id: thread.threadId)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            // Typewriter-style empty state
            VStack(spacing: 8) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundColor(theme.inkLight)

                Text(emptyStateTitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.inkGray)

                Text(emptyStateSubtitle)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkLight)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all:
            return "NO COMMUNICATIONS"
        case .unread:
            return "NO UNREAD MESSAGES"
        case .urgent:
            return "NO URGENT MATTERS"
        case .archived:
            return "ARCHIVE EMPTY"
        }
    }

    private var emptyStateSubtitle: String {
        switch selectedFilter {
        case .all:
            return "The terminal is quiet. Party communications will appear here as they arrive."
        case .unread:
            return "All messages have been reviewed."
        case .urgent:
            return "No matters requiring immediate attention."
        case .archived:
            return "Archived communications will appear here."
        }
    }
}

// MARK: - Thread Card (One card per conversation)

struct CodexThreadCard: View {
    let threadId: UUID
    let latestMessage: CodexMessage
    let messageCount: Int
    let hasUnread: Bool
    let game: Game
    let onTap: () -> Void
    @Environment(\.theme) var theme

    /// Get the conversation partner (the NPC in this thread)
    private var conversationPartner: (name: String, title: String?)? {
        game.codexThreadPartner(for: threadId)
    }

    /// Check if any message in thread requires response
    private var threadRequiresResponse: Bool {
        let thread = game.codexThread(for: threadId)
        return thread.contains { $0.requiresResponse && $0.playerResponseId == nil && $0.senderId != "player" }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Unread indicator stripe
                Rectangle()
                    .fill(hasUnread ? theme.accentGold : theme.inkGray.opacity(0.3))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 8) {
                    // Header row
                    HStack {
                        // Message count badge
                        HStack(spacing: 3) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 9))
                            Text("\(messageCount)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(theme.inkGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.borderTan)
                        .cornerRadius(3)

                        // Unread badge
                        if hasUnread {
                            Text("NEW")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.accentGold)
                                .cornerRadius(3)
                        }

                        Spacer()

                        // Latest message timestamp
                        Text(formatTimestamp(latestMessage.timestamp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.inkLight)
                    }

                    // Conversation partner info
                    if let partner = conversationPartner {
                        HStack(spacing: 8) {
                            // Partner initials
                            partnerInitials(name: partner.name)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(partner.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(theme.inkBlack)

                                if let title = partner.title {
                                    Text(title)
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.inkGray)
                                }
                            }
                        }
                    }

                    // Latest message preview
                    VStack(alignment: .leading, spacing: 4) {
                        // Who sent the latest message
                        Text(latestMessage.senderId == "player" ? "You:" : "\(latestMessage.senderName.components(separatedBy: " ").first ?? ""):")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(theme.inkGray)

                        Text(latestMessage.content)
                            .font(theme.bodyFontSmall)
                            .foregroundColor(theme.inkGray)
                            .lineLimit(2)
                    }

                    // Bottom row
                    HStack {
                        // Response required indicator
                        if threadRequiresResponse {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .font(.system(size: 10))
                                Text("Response Required")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(theme.stampRed)
                        }

                        Spacer()

                        // Tap to view thread
                        HStack(spacing: 3) {
                            Text("View conversation")
                                .font(.system(size: 9))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundColor(theme.inkLight)
                    }
                }
                .padding(12)
            }
            .background(hasUnread ? theme.parchmentDark.opacity(0.95) : theme.parchmentDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(hasUnread ? theme.accentGold.opacity(0.5) : theme.borderTan, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func partnerInitials(name: String) -> some View {
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map { String($0) }
            .joined()

        return Text(initials)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(theme.inkGray)
            .frame(width: 36, height: 36)
            .background(theme.parchment)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.borderTan, lineWidth: 1)
            )
            .cornerRadius(4)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Message Detail View

struct CodexMessageDetailView: View {
    let message: CodexMessage
    @Bindable var game: Game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) var theme

    // Response state
    @State private var selectedOptionId: String?
    @State private var customResponseText: String = ""
    @State private var showingValidationError: Bool = false
    @State private var validationErrorMessage: String = ""

    private var selectedOption: CodexResponseOption? {
        guard let id = selectedOptionId else { return nil }
        return message.responseOptions.first(where: { $0.id == id })
    }

    private var canSendResponse: Bool {
        guard selectedOptionId != nil else { return false }
        // Custom text is optional, but if provided must be valid
        if !customResponseText.isEmpty {
            let result = TypedResponseValidator.validate(customResponseText)
            return result == .valid
        }
        return true
    }

    private var characterCount: Int {
        customResponseText.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Classification header
                    classificationHeader

                    // Sender card
                    senderCard

                    // Divider
                    typewriterDivider

                    // Message content
                    messageContent

                    // Response options (if needed)
                    if message.requiresResponse && message.playerResponseId == nil {
                        responseSection
                    }

                    // Actions
                    actionButtons
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.inkBlack)
                }
            }
        }
    }

    private var classificationHeader: some View {
        HStack {
            // Message type stamp
            HStack(spacing: 4) {
                Image(systemName: message.codexMessageType.iconName)
                    .font(.system(size: 11))
                Text(message.codexMessageType.displayName)
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(message.codexMessageType.isUrgent ? theme.stampRed : theme.inkGray)
            .cornerRadius(4)

            Spacer()

            // Priority
            if message.codexPriority != .routine {
                Text(message.codexPriority.displayName)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.stampRed)
            }

            // Turn number
            Text("TURN \(message.turnNumber)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.inkLight)
        }
    }

    private var senderCard: some View {
        HStack(spacing: 12) {
            // Sender initials
            let initials = message.senderName
                .split(separator: " ")
                .prefix(2)
                .compactMap { $0.first }
                .map { String($0) }
                .joined()

            Text(initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(theme.inkGray)
                .frame(width: 50, height: 50)
                .background(theme.parchmentDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.borderTan, lineWidth: 1)
                )
                .cornerRadius(6)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.senderName.uppercased())
                    .font(.system(size: 14, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                if let title = message.senderTitle {
                    Text(title)
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkGray)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(theme.parchmentDark)
        .cornerRadius(8)
    }

    private var typewriterDivider: some View {
        Text(String(repeating: "-", count: 50))
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(theme.inkGray.opacity(0.3))
    }

    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let subject = message.subject {
                Text(subject)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundColor(theme.inkBlack)
            }

            Text(message.content)
                .font(theme.bodyFont)
                .foregroundColor(theme.inkBlack)
                .lineSpacing(6)
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            typewriterDivider

            Text("RESPONSE REQUIRED")
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.stampRed)

            // Response options (selectable)
            VStack(spacing: 10) {
                ForEach(message.responseOptions) { option in
                    responseOptionButton(option)
                }
            }

            // Optional custom text input
            if selectedOptionId != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ADD PERSONAL NOTE (OPTIONAL)")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkGray)

                        Spacer()

                        // Character count
                        Text("\(characterCount)/\(TypedResponseValidator.maxCharacters)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(characterCount > TypedResponseValidator.maxCharacters ? theme.stampRed : theme.inkLight)
                    }

                    TextEditor(text: $customResponseText)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)
                        .frame(minHeight: 80, maxHeight: 120)
                        .padding(10)
                        .background(theme.parchmentDark)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showingValidationError ? theme.stampRed : theme.borderTan, lineWidth: 1)
                        )
                        .onChange(of: customResponseText) { _, _ in
                            validateCustomText()
                        }

                    // Validation error
                    if showingValidationError {
                        Text(validationErrorMessage)
                            .font(.system(size: 11))
                            .foregroundColor(theme.stampRed)
                    }
                }
            }

            // Send button
            Button {
                sendResponse()
            } label: {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12))
                    Text("SEND RESPONSE")
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(canSendResponse ? theme.stampRed : theme.inkLight)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(!canSendResponse)
        }
    }

    private func responseOptionButton(_ option: CodexResponseOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedOptionId = option.id
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(selectedOptionId == option.id ? theme.stampRed : theme.inkGray, lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if selectedOptionId == option.id {
                        Circle()
                            .fill(theme.stampRed)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.text)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)
                        .multilineTextAlignment(.leading)

                    // Archetype label
                    HStack(spacing: 6) {
                        Text(option.archetype.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(theme.accentGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.accentGold.opacity(0.1))
                            .cornerRadius(3)

                        if let consequences = option.consequences {
                            Text(consequences)
                                .font(.system(size: 10))
                                .foregroundColor(theme.inkGray)
                                .italic()
                        }
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(selectedOptionId == option.id ? theme.parchmentDark : theme.parchment)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedOptionId == option.id ? theme.stampRed : theme.borderTan, lineWidth: selectedOptionId == option.id ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func validateCustomText() {
        let result = TypedResponseValidator.validate(customResponseText)
        if let error = TypedResponseValidator.errorMessage(for: result) {
            validationErrorMessage = error
            showingValidationError = true
        } else {
            showingValidationError = false
            validationErrorMessage = ""
        }
    }

    private func sendResponse() {
        guard let optionId = selectedOptionId else { return }

        // Final validation
        if !customResponseText.isEmpty {
            let result = TypedResponseValidator.validate(customResponseText)
            if result != .valid {
                validateCustomText()
                return
            }
        }

        // Send the response
        CodexService.shared.respondToMessage(
            message,
            optionId: optionId,
            customText: customResponseText.isEmpty ? nil : customResponseText,
            game: game,
            context: modelContext
        )

        dismiss()
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                CodexService.shared.archiveMessage(message)
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "archivebox")
                    Text("Archive")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.inkGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(theme.parchmentDark)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.borderTan, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 12)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")
    container.mainContext.insert(game)

    return CodexTerminalView(game: game)
        .modelContainer(container)
}
