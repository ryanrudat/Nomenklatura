//
//  CodexThreadView.swift
//  Nomenklatura
//
//  Thread view for Codex conversations - shows full message chain
//

import SwiftUI
import SwiftData

struct CodexThreadView: View {
    let threadId: UUID
    @Bindable var game: Game
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) var theme

    // Response state (for responding to latest message)
    @State private var selectedOptionId: String?
    @State private var customResponseText: String = ""
    @State private var showingValidationError: Bool = false
    @State private var validationErrorMessage: String = ""

    // Stat-change toast state (shown after sending a response)
    @State private var toastDeltas: [CodexStatDelta] = []
    @State private var toastArchetype: String?
    @State private var showingStatToast: Bool = false

    private var threadMessages: [CodexMessage] {
        game.codexThread(for: threadId)
    }

    private var conversationPartner: (name: String, title: String?)? {
        // Find the first non-player message to get the conversation partner
        guard let firstNPCMessage = threadMessages.first(where: { $0.senderId != "player" }) else {
            return nil
        }
        return (firstNPCMessage.senderName, firstNPCMessage.senderTitle)
    }

    private var latestMessage: CodexMessage? {
        threadMessages.last
    }

    private var requiresResponse: Bool {
        guard let latest = latestMessage else { return false }
        return latest.requiresResponse && latest.playerResponseId == nil && latest.senderId != "player"
    }

    private var selectedOption: CodexResponseOption? {
        guard let id = selectedOptionId, let latest = latestMessage else { return nil }
        return latest.responseOptions.first(where: { $0.id == id })
    }

    private var canSendResponse: Bool {
        guard selectedOptionId != nil else { return false }
        if !customResponseText.isEmpty {
            let result = TypedResponseValidator.validate(customResponseText)
            return result == .valid
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Conversation header
                        conversationHeader

                        // Thread messages
                        ForEach(Array(threadMessages.enumerated()), id: \.element.id) { index, message in
                            threadMessageBubble(message: message, isLast: index == threadMessages.count - 1)
                                .id(message.id)
                        }

                        // Response section
                        if requiresResponse, let latest = latestMessage {
                            responseSection(for: latest)
                                .id("response-section")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .onAppear {
                    // Mark all messages in thread as read
                    for message in threadMessages where !message.isRead {
                        CodexService.shared.markAsRead(message)
                    }
                    // Scroll to bottom
                    if let lastMessage = threadMessages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                if requiresResponse {
                                    proxy.scrollTo("response-section", anchor: .bottom)
                                } else {
                                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("CONVERSATION")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1)
                            .foregroundColor(theme.inkGray)
                        Text("\(threadMessages.count) messages")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.inkBlack)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        archiveThread()
                    } label: {
                        Image(systemName: "archivebox")
                            .foregroundColor(theme.inkGray)
                    }
                }
            }
            .overlay {
                if showingStatToast {
                    CodexStatChangeToast(
                        deltas: toastDeltas,
                        archetypeLabel: toastArchetype,
                        onDismiss: {
                            showingStatToast = false
                            toastDeltas = []
                            toastArchetype = nil
                        }
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Conversation Header

    private var conversationHeader: some View {
        VStack(spacing: 12) {
            if let partner = conversationPartner {
                HStack(spacing: 12) {
                    // Partner initials
                    let initials = partner.name
                        .split(separator: " ")
                        .prefix(2)
                        .compactMap { $0.first }
                        .map { String($0) }
                        .joined()

                    Text(initials)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(theme.inkGray)
                        .frame(width: 56, height: 56)
                        .background(theme.parchmentDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.borderTan, lineWidth: 1)
                        )
                        .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(partner.name.uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkBlack)

                        if let title = partner.title {
                            Text(title)
                                .font(.system(size: 12))
                                .foregroundColor(theme.inkGray)
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .background(theme.parchmentDark)
                .cornerRadius(8)
            }

            // Thread line
            Rectangle()
                .fill(theme.borderTan)
                .frame(width: 2)
                .frame(height: 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Thread Message Bubble

    private func threadMessageBubble(message: CodexMessage, isLast: Bool) -> some View {
        let isPlayerMessage = message.senderId == "player"

        return VStack(alignment: .leading, spacing: 0) {
            // Connector line
            if !isLast || requiresResponse {
                HStack {
                    Rectangle()
                        .fill(theme.borderTan)
                        .frame(width: 2)
                        .frame(height: 16)
                    Spacer()
                }
                .padding(.leading, 27)
            }

            HStack(alignment: .top, spacing: 12) {
                // Thread indicator dot
                ZStack {
                    Circle()
                        .fill(isPlayerMessage ? theme.accentGold : theme.parchmentDark)
                        .frame(width: 16, height: 16)
                    Circle()
                        .stroke(isPlayerMessage ? theme.accentGold : theme.inkGray, lineWidth: 2)
                        .frame(width: 16, height: 16)
                }
                .padding(.leading, 20)
                .padding(.top, 4)

                // Message content
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        // Message type stamp
                        HStack(spacing: 3) {
                            Image(systemName: message.codexMessageType.iconName)
                                .font(.system(size: 8))
                            Text(message.codexMessageType.displayName)
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.3)
                        }
                        .foregroundColor(isPlayerMessage ? theme.accentGold : theme.inkGray)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(isPlayerMessage ? theme.accentGold.opacity(0.15) : theme.borderTan)
                        .cornerRadius(3)

                        Spacer()

                        // Turn number
                        Text("Turn \(message.turnNumber)")
                            .font(.system(size: 9))
                            .foregroundColor(theme.inkLight)

                        // New badge for unread
                        if !message.isRead {
                            Text("NEW")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(theme.stampRed)
                                .cornerRadius(3)
                        }
                    }

                    // Trigger badge — surfaces *why* this message exists
                    // (especially useful for follow-ups so the player
                    // connects this message to their earlier stance)
                    if !isPlayerMessage, let badge = message.triggerBadgeText {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 8, weight: .bold))
                            Text(badge)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                        }
                        .foregroundColor(theme.stampRed)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.stampRed.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(theme.stampRed.opacity(0.4), lineWidth: 0.5)
                        )
                        .cornerRadius(3)
                    }

                    // Sender
                    HStack(spacing: 4) {
                        Text(isPlayerMessage ? "You" : message.senderName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.inkBlack)

                        if !isPlayerMessage, let title = message.senderTitle {
                            Text("•")
                                .foregroundColor(theme.inkLight)
                            Text(title)
                                .font(.system(size: 11))
                                .foregroundColor(theme.inkGray)
                        }
                    }

                    // Subject
                    if let subject = message.subject {
                        Text(subject)
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundColor(theme.inkBlack)
                    }

                    // Content
                    Text(message.content)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)
                        .lineSpacing(4)

                    // Player's custom text (if this is a response with elaboration)
                    if isPlayerMessage, let customText = message.playerCustomText, !customText.isEmpty {
                        Text("\"\(customText)\"")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(theme.inkGray)
                            .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(isPlayerMessage ? theme.accentGold.opacity(0.08) : theme.parchmentDark)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isPlayerMessage ? theme.accentGold.opacity(0.3) : theme.borderTan, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Response Section

    private func responseSection(for message: CodexMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Connector line
            HStack {
                Rectangle()
                    .fill(theme.borderTan)
                    .frame(width: 2)
                    .frame(height: 16)
                Spacer()
            }
            .padding(.leading, 27)

            // Response card
            VStack(alignment: .leading, spacing: 16) {
                Text("RESPONSE REQUIRED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.stampRed)

                // Response options
                VStack(spacing: 10) {
                    ForEach(message.responseOptions) { option in
                        responseOptionButton(option)
                    }
                }

                // Optional custom text
                if selectedOptionId != nil {
                    customTextInput
                }

                // Send button
                Button {
                    sendResponse(to: message)
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
            .padding(16)
            .background(theme.parchment)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.stampRed.opacity(0.5), lineWidth: 2)
            )
            .padding(.leading, 36)
        }
        .padding(.top, 8)
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
                        .frame(width: 18, height: 18)

                    if selectedOptionId == option.id {
                        Circle()
                            .fill(theme.stampRed)
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.text)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)
                        .multilineTextAlignment(.leading)

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
            .padding(10)
            .background(selectedOptionId == option.id ? theme.parchmentDark : theme.parchment)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedOptionId == option.id ? theme.stampRed : theme.borderTan, lineWidth: selectedOptionId == option.id ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customTextInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ADD PERSONAL NOTE (OPTIONAL)")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(theme.inkGray)

                Spacer()

                Text("\(customResponseText.count)/\(TypedResponseValidator.maxCharacters)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(customResponseText.count > TypedResponseValidator.maxCharacters ? theme.stampRed : theme.inkLight)
            }

            TextEditor(text: $customResponseText)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkBlack)
                .frame(minHeight: 60, maxHeight: 100)
                .padding(8)
                .background(theme.parchmentDark)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showingValidationError ? theme.stampRed : theme.borderTan, lineWidth: 1)
                )
                .onChange(of: customResponseText) { _, _ in
                    validateCustomText()
                }

            if showingValidationError {
                Text(validationErrorMessage)
                    .font(.system(size: 11))
                    .foregroundColor(theme.stampRed)
            }
        }
    }

    // MARK: - Actions

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

    private func sendResponse(to message: CodexMessage) {
        guard let optionId = selectedOptionId else { return }

        if !customResponseText.isEmpty {
            let result = TypedResponseValidator.validate(customResponseText)
            if result != .valid {
                validateCustomText()
                return
            }
        }

        let outcome = CodexService.shared.respondToMessage(
            message,
            optionId: optionId,
            customText: customResponseText.isEmpty ? nil : customResponseText,
            game: game,
            context: modelContext
        )

        // Reset response state
        selectedOptionId = nil
        customResponseText = ""

        // Present the stat-change toast so the player feels the impact.
        if let outcome = outcome {
            presentStatToast(outcome: outcome)
        }
    }

    /// Build delta rows from the response outcome and trigger the toast.
    /// "isPositive" is the player-facing valence: -2 RIVAL THREAT is a
    /// *good* result (rival respects strength), so the arrow points up.
    private func presentStatToast(outcome: CodexService.ResponseOutcome) {
        var deltas: [CodexStatDelta] = []

        let e = outcome.effects
        if e.dispositionChange != 0 {
            deltas.append(CodexStatDelta(
                label: "DISPOSITION",
                amount: e.dispositionChange,
                isPositive: e.dispositionChange > 0
            ))
        }
        if e.patronFavorChange != 0 {
            deltas.append(CodexStatDelta(
                label: "PATRON FAVOR",
                amount: e.patronFavorChange,
                isPositive: e.patronFavorChange > 0
            ))
        }
        if e.rivalThreatChange != 0 {
            // Lower threat is good for the player.
            deltas.append(CodexStatDelta(
                label: "RIVAL THREAT",
                amount: e.rivalThreatChange,
                isPositive: e.rivalThreatChange < 0
            ))
        }

        toastDeltas = deltas
        toastArchetype = outcome.archetype.rawValue
        withAnimation { showingStatToast = true }
    }

    private func archiveThread() {
        for message in threadMessages {
            CodexService.shared.archiveMessage(message)
        }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")
    container.mainContext.insert(game)

    return CodexThreadView(threadId: UUID(), game: game)
        .modelContainer(container)
}
