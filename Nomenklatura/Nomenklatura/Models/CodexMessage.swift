//
//  CodexMessage.swift
//  Nomenklatura
//
//  Codex Communication System - NPC-to-Player messaging model
//

import Foundation
import SwiftData

@Model
final class CodexMessage {
    @Attribute(.unique) var id: UUID
    var senderId: String              // Character templateId or "player"
    var senderName: String            // Display name
    var senderTitle: String?          // Position/title
    var recipientId: String           // "player" or character templateId
    var messageType: String           // CodexMessageType.rawValue
    var priority: String              // CodexMessagePriority.rawValue
    var subject: String?              // Optional subject line
    var content: String               // Message body
    var timestamp: Date               // When message was sent
    var turnNumber: Int               // Game turn when created
    var isRead: Bool                  // Has player read this
    var isArchived: Bool              // Player archived this
    var requiresResponse: Bool        // Does this need a reply
    var responseOptionsData: Data?    // Encoded [CodexResponseOption]
    var playerResponseId: String?     // ID of response option chosen
    var playerCustomText: String?     // Player's typed elaboration
    var responseEffectsApplied: Bool  // Have consequences been applied
    var threadId: UUID?               // For conversation threading
    var parentMessageId: UUID?        // Reply-to reference
    var expiresOnTurn: Int?           // Optional expiration
    var createdAt: Date

    // Event-driven trigger tracking
    var triggerType: String?          // CodexTriggerType.rawValue
    var triggerSourceId: String?      // Document/consequence/event ID that triggered this
    var triggerContext: String?       // Additional context about the trigger
    var scheduledDeliveryTurn: Int?   // For delayed message delivery
    var isDelivered: Bool             // Has message been delivered to player

    var game: Game?

    // MARK: - Initializer

    init(
        senderId: String,
        senderName: String,
        senderTitle: String? = nil,
        recipientId: String = "player",
        messageType: CodexMessageType,
        priority: CodexMessagePriority = .routine,
        subject: String? = nil,
        content: String,
        turnNumber: Int,
        requiresResponse: Bool = false,
        responseOptions: [CodexResponseOption]? = nil,
        threadId: UUID? = nil,
        parentMessageId: UUID? = nil,
        expiresOnTurn: Int? = nil,
        triggerType: CodexTriggerType? = nil,
        triggerSourceId: String? = nil,
        triggerContext: String? = nil,
        scheduledDeliveryTurn: Int? = nil
    ) {
        self.id = UUID()
        self.senderId = senderId
        self.senderName = senderName
        self.senderTitle = senderTitle
        self.recipientId = recipientId
        self.messageType = messageType.rawValue
        self.priority = priority.rawValue
        self.subject = subject
        self.content = content
        self.timestamp = Date()
        self.turnNumber = turnNumber
        self.isRead = false
        self.isArchived = false
        self.requiresResponse = requiresResponse
        self.playerCustomText = nil
        self.responseEffectsApplied = false
        self.threadId = threadId ?? UUID()
        self.parentMessageId = parentMessageId
        self.expiresOnTurn = expiresOnTurn
        self.createdAt = Date()

        // Event-driven trigger tracking
        self.triggerType = triggerType?.rawValue
        self.triggerSourceId = triggerSourceId
        self.triggerContext = triggerContext
        self.scheduledDeliveryTurn = scheduledDeliveryTurn
        self.isDelivered = scheduledDeliveryTurn == nil  // Immediate if not scheduled

        if let options = responseOptions {
            self.responseOptionsData = try? JSONEncoder().encode(options)
        }
    }

    // MARK: - Computed Properties

    var codexMessageType: CodexMessageType {
        CodexMessageType(rawValue: messageType) ?? .routine
    }

    var codexPriority: CodexMessagePriority {
        CodexMessagePriority(rawValue: priority) ?? .routine
    }

    var codexTriggerType: CodexTriggerType? {
        guard let trigger = triggerType else { return nil }
        return CodexTriggerType(rawValue: trigger)
    }

    /// Whether this message is ready to be delivered (scheduled turn has arrived)
    var isReadyForDelivery: Bool {
        guard let scheduledTurn = scheduledDeliveryTurn, let game = game else {
            return !isDelivered
        }
        return game.turnNumber >= scheduledTurn && !isDelivered
    }

    var responseOptions: [CodexResponseOption] {
        get {
            guard let data = responseOptionsData else { return [] }
            return (try? JSONDecoder().decode([CodexResponseOption].self, from: data)) ?? []
        }
        set {
            responseOptionsData = try? JSONEncoder().encode(newValue)
        }
    }

    var isExpired: Bool {
        guard let expires = expiresOnTurn, let game = game else { return false }
        return game.turnNumber > expires
    }

    var hasUnreadResponse: Bool {
        !isRead && parentMessageId != nil
    }

    /// Short human-readable label describing why this message was sent.
    /// Returns nil for player-sent messages or when no trigger info exists.
    var triggerBadgeText: String? {
        guard senderId != "player" else { return nil }
        if let ctx = triggerContext, !ctx.isEmpty { return ctx }
        return codexTriggerType?.displayName
    }
}

// MARK: - Message Types

enum CodexMessageType: String, Codable, CaseIterable {
    case summons         // Superior requesting meeting/presence
    case inquiry         // Question requiring answer
    case warning         // Alert about danger/threat
    case request         // Subordinate/peer asking for something
    case intelligence    // Information from network/contacts
    case directive       // Orders from above
    case social          // Informal relationship building
    case report          // Status update/progress report
    case response        // Reply to previous message
    case routine         // Standard administrative communication

    var displayName: String {
        switch self {
        case .summons: return "SUMMONS"
        case .inquiry: return "INQUIRY"
        case .warning: return "WARNING"
        case .request: return "REQUEST"
        case .intelligence: return "INTELLIGENCE"
        case .directive: return "DIRECTIVE"
        case .social: return "PERSONAL"
        case .report: return "REPORT"
        case .response: return "RESPONSE"
        case .routine: return "MEMO"
        }
    }

    var iconName: String {
        switch self {
        case .summons: return "bell.fill"
        case .inquiry: return "questionmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .request: return "hand.raised.fill"
        case .intelligence: return "eye.fill"
        case .directive: return "arrow.down.doc.fill"
        case .social: return "person.2.fill"
        case .report: return "doc.text.fill"
        case .response: return "arrowshape.turn.up.left.fill"
        case .routine: return "envelope.fill"
        }
    }

    var isUrgent: Bool {
        switch self {
        case .summons, .warning, .directive: return true
        default: return false
        }
    }
}

// MARK: - Message Priority

enum CodexMessagePriority: String, Codable, CaseIterable {
    case critical   // Immediate attention required
    case urgent     // Important, respond soon
    case routine    // Standard priority
    case low        // Can wait, informational

    var displayName: String {
        switch self {
        case .critical: return "CRITICAL"
        case .urgent: return "URGENT"
        case .routine: return "ROUTINE"
        case .low: return "LOW"
        }
    }

    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .urgent: return 1
        case .routine: return 2
        case .low: return 3
        }
    }
}

// MARK: - Response Option

struct CodexResponseOption: Codable, Identifiable {
    let id: String
    let text: String                  // Display text for the option
    let archetype: String             // Response tone: respectful, assertive, evasive, etc.
    let consequences: String?         // Brief hint about what this might cause

    init(id: String = UUID().uuidString, text: String, archetype: String, consequences: String? = nil) {
        self.id = id
        self.text = text
        self.archetype = archetype
        self.consequences = consequences
    }
}

// MARK: - Response Archetype

enum CodexResponseArchetype: String, Codable, CaseIterable {
    case respectful      // Deferential, formal
    case assertive       // Confident, direct
    case evasive         // Non-committal, deflecting
    case obsequious      // Flattering, ingratiating
    case defiant         // Challenging, resistant
    case cooperative     // Helpful, agreeable
    case cautious        // Careful, hedging

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Sender Rank (for UI display)

enum CodexSenderRank: Codable {
    case superior        // Higher position than player
    case peer            // Same level
    case subordinate     // Lower position
    case external        // Foreign contact, etc.

    static func determine(senderPosition: Int?, playerPosition: Int) -> CodexSenderRank {
        guard let senderPos = senderPosition else { return .external }
        if senderPos > playerPosition { return .superior }
        if senderPos < playerPosition { return .subordinate }
        return .peer
    }
}

// MARK: - Trigger Type (Event-Driven)

enum CodexTriggerType: String, Codable, CaseIterable {
    case relationship       // Patron favor, rival threat, ally disposition change
    case decisionReaction   // Character reacting to a desk document decision
    case consequence        // ConsequenceEngine fired a consequence
    case stateThreshold     // Game stat crossed a threshold (stability < 30, etc.)
    case promotion          // Player was promoted
    case characterEvent     // Character death, arrest, or other major event
    case periodic           // Regular check-in (patron hasn't contacted in 5+ turns)
    case playerInitiated    // Player sent a message (senior positions only)

    var displayName: String {
        switch self {
        case .relationship: return "Relationship Event"
        case .decisionReaction: return "Decision Reaction"
        case .consequence: return "Consequence"
        case .stateThreshold: return "State Change"
        case .promotion: return "Promotion"
        case .characterEvent: return "Character Event"
        case .periodic: return "Check-in"
        case .playerInitiated: return "Player Message"
        }
    }
}

// MARK: - Response Effect Calculation

struct CodexResponseEffects {
    var dispositionChange: Int = 0          // -10 to +10
    var patronFavorChange: Int = 0          // Only for patron messages
    var rivalThreatChange: Int = 0          // Only for rival messages
    var setsFlag: String?                   // Game flag to set
    var schedulesFollowUp: Bool = false     // Should schedule a follow-up message
    var followUpDelay: Int = 3              // Turns until follow-up

    static func calculate(archetype: CodexResponseArchetype, senderIsPatron: Bool, senderIsRival: Bool) -> CodexResponseEffects {
        var effects = CodexResponseEffects()

        switch archetype {
        case .respectful:
            effects.dispositionChange = 3
            if senderIsPatron { effects.patronFavorChange = 2 }
        case .cooperative:
            effects.dispositionChange = 4
            if senderIsPatron { effects.patronFavorChange = 3 }
            effects.schedulesFollowUp = true  // May create obligation
        case .assertive:
            effects.dispositionChange = 0  // Neutral, shows strength
            if senderIsRival { effects.rivalThreatChange = -2 }  // Rival respects strength
        case .cautious, .evasive:
            effects.dispositionChange = -1  // Slight suspicion
        case .defiant:
            effects.dispositionChange = -5
            if senderIsPatron { effects.patronFavorChange = -5 }
            if senderIsRival { effects.rivalThreatChange = 3 }  // Escalates conflict
            effects.schedulesFollowUp = true  // Will have consequences
            effects.followUpDelay = 2
        case .obsequious:
            effects.dispositionChange = 2
            if senderIsPatron { effects.patronFavorChange = 1 }
            // But may lose respect long-term
        }

        return effects
    }
}

// MARK: - Typed Response Validation

struct TypedResponseValidator {
    static let maxCharacters = 280
    static let minCharacters = 10

    enum ValidationResult {
        case valid
        case tooShort
        case tooLong
        case offTopic
        case empty
    }

    static func validate(_ text: String?) -> ValidationResult {
        guard let text = text, !text.isEmpty else {
            return .empty  // Empty is OK - it's optional
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count < minCharacters {
            return .tooShort
        }

        if trimmed.count > maxCharacters {
            return .tooLong
        }

        // Check for off-topic patterns
        let offTopicPatterns = ["http", "www.", "@", "#", "://"]
        for pattern in offTopicPatterns {
            if trimmed.lowercased().contains(pattern) {
                return .offTopic
            }
        }

        // Check minimum word count
        let wordCount = trimmed.split(separator: " ").count
        if wordCount < 2 {
            return .tooShort
        }

        return .valid
    }

    static func errorMessage(for result: ValidationResult) -> String? {
        switch result {
        case .valid, .empty:
            return nil
        case .tooShort:
            return "Please write a more complete response (at least 10 characters)"
        case .tooLong:
            return "Response is too long (maximum 280 characters)"
        case .offTopic:
            return "Please keep your response in character"
        }
    }
}
