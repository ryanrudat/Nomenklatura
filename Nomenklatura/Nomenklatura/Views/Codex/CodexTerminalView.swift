//
//  CodexTerminalView.swift
//  Nomenklatura
//
//  Secure Party Communication Terminal - NPC messaging interface
//

import SwiftUI
import SwiftData

struct CodexTerminalView: View {
    @Bindable var game: Game
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) var theme
    @StateObject private var codexService = CodexService.shared

    @State private var selectedFilter: MessageFilter = .all
    @State private var selectedMessage: CodexMessage?

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

    private var filteredMessages: [CodexMessage] {
        switch selectedFilter {
        case .all:
            return game.activeCodexMessages
        case .unread:
            return game.unreadCodexMessages
        case .urgent:
            return game.codexMessages.filter {
                !$0.isArchived && ($0.codexPriority == .critical || $0.codexPriority == .urgent)
            }.sorted { $0.timestamp > $1.timestamp }
        case .archived:
            return game.codexMessages.filter { $0.isArchived }.sorted { $0.timestamp > $1.timestamp }
        }
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
                if filteredMessages.isEmpty {
                    emptyState
                } else {
                    messageList
                }
            }
        }
        .sheet(item: $selectedMessage) { message in
            CodexMessageDetailView(message: message, game: game)
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
            return game.activeCodexMessages.count
        case .unread:
            return game.unreadCodexCount
        case .urgent:
            return game.codexMessages.filter {
                !$0.isArchived && ($0.codexPriority == .critical || $0.codexPriority == .urgent)
            }.count
        case .archived:
            return game.codexMessages.filter { $0.isArchived }.count
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredMessages) { message in
                    CodexMessageCard(message: message) {
                        selectedMessage = message
                        CodexService.shared.markAsRead(message)
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

// MARK: - Message Card

struct CodexMessageCard: View {
    let message: CodexMessage
    let onTap: () -> Void
    @Environment(\.theme) var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Unread indicator / priority stripe
                Rectangle()
                    .fill(stripeColor)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 8) {
                    // Header row
                    HStack {
                        // Message type stamp
                        messageTypeStamp

                        Spacer()

                        // Timestamp
                        Text(formatTimestamp(message.timestamp))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(theme.inkLight)
                    }

                    // Sender info
                    HStack(spacing: 8) {
                        // Sender initials
                        senderInitials

                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.senderName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(theme.inkBlack)

                            if let title = message.senderTitle {
                                Text(title)
                                    .font(.system(size: 11))
                                    .foregroundColor(theme.inkGray)
                            }
                        }
                    }

                    // Subject line
                    if let subject = message.subject {
                        Text(subject)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(theme.inkBlack)
                            .lineLimit(1)
                    }

                    // Preview
                    Text(message.content)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                        .lineLimit(2)

                    // Response indicator
                    if message.requiresResponse && message.playerResponseId == nil {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 10))
                            Text("Response Required")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(theme.stampRed)
                    }
                }
                .padding(12)
            }
            .background(message.isRead ? theme.parchmentDark : theme.parchmentDark.opacity(0.95))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(message.isRead ? theme.borderTan : theme.accentGold.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private var stripeColor: Color {
        if !message.isRead {
            return theme.accentGold
        }

        switch message.codexPriority {
        case .critical:
            return theme.stampRed
        case .urgent:
            return theme.stampRed.opacity(0.7)
        case .routine:
            return theme.inkGray.opacity(0.3)
        case .low:
            return theme.inkLight.opacity(0.3)
        }
    }

    private var messageTypeStamp: some View {
        HStack(spacing: 4) {
            Image(systemName: message.codexMessageType.iconName)
                .font(.system(size: 9))
            Text(message.codexMessageType.displayName)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
        }
        .foregroundColor(stampTextColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(stampBackgroundColor)
        .cornerRadius(3)
    }

    private var stampTextColor: Color {
        if message.codexMessageType.isUrgent {
            return .white
        }
        return theme.inkGray
    }

    private var stampBackgroundColor: Color {
        if message.codexMessageType.isUrgent {
            return theme.stampRed
        }
        return theme.borderTan
    }

    private var senderInitials: some View {
        let initials = message.senderName
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
