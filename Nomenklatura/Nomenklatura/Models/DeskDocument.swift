//
//  DeskDocument.swift
//  Nomenklatura
//
//  Documents that land on the player's desk - memos, reports, letters, cables, etc.
//  Multiple documents can be present at once, creating a realistic bureaucrat experience.
//

import Foundation
import SwiftData

// MARK: - Document Type

/// The physical form of a document
enum DocumentType: String, Codable, CaseIterable {
    case memo              // Internal government memo
    case report            // Official report (investigation, production, etc.)
    case letter            // Personal letter (handwritten feel)
    case cable             // Diplomatic/intelligence cable
    case requisition       // Resource/equipment request
    case denunciation      // Anonymous tip/accusation
    case directive         // Order from above
    case assessment        // Evaluation form (loyalty, performance)
    case transcript        // Interrogation or meeting transcript
    case intelligence      // Spy report / classified intel
    case newspaper         // Press clipping
    case personalNote      // Handwritten note, informal

    var displayName: String {
        switch self {
        case .memo: return "Memorandum"
        case .report: return "Report"
        case .letter: return "Letter"
        case .cable: return "Cable"
        case .requisition: return "Requisition"
        case .denunciation: return "Citizen Report"
        case .directive: return "Directive"
        case .assessment: return "Assessment"
        case .transcript: return "Transcript"
        case .intelligence: return "Intelligence Brief"
        case .newspaper: return "Press Clipping"
        case .personalNote: return "Note"
        }
    }

    /// Whether this document type typically has a handwritten feel
    var isHandwritten: Bool {
        switch self {
        case .letter, .denunciation, .personalNote:
            return true
        default:
            return false
        }
    }

    /// The visual style to use for this document
    var visualStyle: DocumentVisualStyle {
        switch self {
        case .memo, .directive:
            return .officialMemo
        case .report, .assessment:
            return .formalReport
        case .letter, .personalNote:
            return .handwrittenLetter
        case .cable, .intelligence:
            return .classifiedCable
        case .requisition:
            return .formDocument
        case .denunciation:
            return .anonymousTip
        case .transcript:
            return .typewriterDocument
        case .newspaper:
            return .newsClipping
        }
    }
}

/// Visual styling for documents
enum DocumentVisualStyle: String, Codable {
    case officialMemo       // Red stripe, government header
    case formalReport       // Clean, typed, official
    case handwrittenLetter  // Personal, possibly messy
    case classifiedCable    // Decoded message feel, stamps
    case formDocument       // Checkboxes, fill-in-the-blank
    case anonymousTip       // Rough paper, no letterhead
    case typewriterDocument // Monospace, carbon copy feel
    case newsClipping       // Newspaper style, possibly torn edges
}

// MARK: - Document Urgency

/// How urgent a document is - affects visual presentation and consequences
enum DocumentUrgency: String, Codable, CaseIterable, Comparable {
    case routine    // Can wait, no deadline
    case priority   // Should be handled soon
    case urgent     // Needs attention today
    case critical   // Immediate action required

    nonisolated var sortOrder: Int {
        switch self {
        case .routine: return 0
        case .priority: return 1
        case .urgent: return 2
        case .critical: return 3
        }
    }

    nonisolated static func < (lhs: DocumentUrgency, rhs: DocumentUrgency) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    var stampText: String? {
        switch self {
        case .routine: return nil
        case .priority: return "PRIORITY"
        case .urgent: return "URGENT"
        case .critical: return "IMMEDIATE ACTION"
        }
    }

    /// How many turns before consequences trigger (nil = no deadline)
    var defaultDeadline: Int? {
        switch self {
        case .routine: return nil
        case .priority: return 3
        case .urgent: return 2
        case .critical: return 1
        }
    }
}

// MARK: - Document Status

/// Current state of the document
enum DocumentStatus: String, Codable {
    case unread     // Player hasn't opened it yet
    case read       // Player has read it but not acted
    case pending    // Player started but didn't finish
    case acted      // Player made a decision
    case filed      // Put away for later (safe)
    case burned     // Destroyed (may have consequences)
    case expired    // Deadline passed without action
}

// MARK: - Document Category

/// What area of government this document relates to
enum DocumentCategory: String, Codable, CaseIterable {
    case security       // Investigations, surveillance, arrests
    case military       // Troops, deployments, discipline
    case economic       // Production, resources, planning
    case political      // Party loyalty, ideology, propaganda
    case diplomatic     // Foreign relations, treaties, espionage
    case personnel      // Promotions, assignments, evaluations
    case crisis         // Emergencies requiring immediate attention
    case personal       // Direct appeals, personal matters

    var displayName: String {
        switch self {
        case .security: return "Security"
        case .military: return "Military"
        case .economic: return "Economic"
        case .political: return "Political"
        case .diplomatic: return "Foreign Affairs"
        case .personnel: return "Personnel"
        case .crisis: return "Crisis"
        case .personal: return "Personal"
        }
    }
}

// MARK: - Document Option

/// A choice the player can make on a document that requires decision
struct DocumentOption: Codable, Identifiable {
    let id: String
    let text: String                    // Full text shown to player
    let shortDescription: String        // Brief summary for logs
    let effects: [String: Int]          // Stat changes
    var setsFlag: String?               // Game flag to set
    var removesFlag: String?            // Game flag to remove
    var triggersDocument: String?       // ID of follow-up document to generate
    var triggersEvent: String?          // ID of dynamic event to trigger
    var characterReaction: CharacterReactionInfo? // How a character reacts

    init(
        id: String,
        text: String,
        shortDescription: String,
        effects: [String: Int] = [:],
        setsFlag: String? = nil,
        removesFlag: String? = nil,
        triggersDocument: String? = nil,
        triggersEvent: String? = nil,
        characterReaction: CharacterReactionInfo? = nil
    ) {
        self.id = id
        self.text = text
        self.shortDescription = shortDescription
        self.effects = effects
        self.setsFlag = setsFlag
        self.removesFlag = removesFlag
        self.triggersDocument = triggersDocument
        self.triggersEvent = triggersEvent
        self.characterReaction = characterReaction
    }
}

/// Information about how a character reacts to a choice
struct CharacterReactionInfo: Codable {
    let characterId: String?        // UUID string, or nil for name lookup
    let characterName: String
    let dispositionChange: Int      // How much their opinion changes
    let reactionText: String?       // What they say/do in response
    let delayed: Bool               // Whether reaction comes later
}

// MARK: - Desk Document Model

@Model
final class DeskDocument {
    var id: UUID
    var templateId: String              // For tracking document types
    var documentType: String            // DocumentType raw value
    var title: String
    var sender: String                  // Character name
    var senderTitle: String?            // Character's position
    var senderCharacterId: String?      // UUID string if linked to GameCharacter

    // Timing
    var turnReceived: Int               // When it arrived
    var turnDeadline: Int?              // When consequences trigger
    var turnActedOn: Int?               // When player made decision

    // Classification
    var urgency: String                 // DocumentUrgency raw value
    var category: String                // DocumentCategory raw value
    var classification: String?         // "CLASSIFIED", "TOP SECRET", etc.

    // Content
    var headerText: String?             // "TO:", "FROM:", "RE:", etc.
    var bodyText: String                // Main content
    var footnoteText: String?           // Handwritten notes, P.S., etc.
    var attachmentDescriptions: [String]? // "See attached report", etc.

    // State
    var status: String                  // DocumentStatus raw value
    var requiresDecision: Bool
    var optionsData: Data?              // Encoded [DocumentOption]
    var chosenOptionId: String?         // Which option was selected

    // Consequences
    var consequenceIfIgnored: String?   // What happens if deadline passes
    var consequenceEffects: [String: Int]? // Stat changes if ignored

    // Visual
    var isHandwritten: Bool
    var hasStamp: Bool                  // Show rubber stamp
    var stampText: String?              // Custom stamp text
    var hasCoffeeStain: Bool            // Aesthetic detail
    var rotation: Double                // Slight rotation for desk scatter

    // Relationships
    var game: Game?
    var relatedDocumentIds: [String]?   // UUIDs of connected documents

    // MARK: - Computed Properties

    var documentTypeEnum: DocumentType {
        DocumentType(rawValue: documentType) ?? .memo
    }

    var urgencyEnum: DocumentUrgency {
        DocumentUrgency(rawValue: urgency) ?? .routine
    }

    var categoryEnum: DocumentCategory {
        DocumentCategory(rawValue: category) ?? .political
    }

    var statusEnum: DocumentStatus {
        get { DocumentStatus(rawValue: status) ?? .unread }
        set { status = newValue.rawValue }
    }

    var options: [DocumentOption] {
        get {
            guard let data = optionsData else { return [] }
            return (try? JSONDecoder().decode([DocumentOption].self, from: data)) ?? []
        }
        set {
            optionsData = try? JSONEncoder().encode(newValue)
        }
    }

    /// How many turns until deadline (nil if no deadline)
    func turnsRemaining(currentTurn: Int) -> Int? {
        guard let deadline = turnDeadline else { return nil }
        return max(0, deadline - currentTurn)
    }

    /// Whether the document has expired (deadline passed)
    func isExpired(currentTurn: Int) -> Bool {
        guard let deadline = turnDeadline else { return false }
        return currentTurn > deadline && statusEnum != .acted
    }

    /// Whether this document is from a known character
    var isFromKnownCharacter: Bool {
        senderCharacterId != nil
    }

    // MARK: - Initialization

    init(
        templateId: String,
        documentType: DocumentType,
        title: String,
        sender: String,
        senderTitle: String? = nil,
        turnReceived: Int,
        urgency: DocumentUrgency = .routine,
        category: DocumentCategory,
        bodyText: String,
        requiresDecision: Bool = false,
        options: [DocumentOption] = []
    ) {
        self.id = UUID()
        self.templateId = templateId
        self.documentType = documentType.rawValue
        self.title = title
        self.sender = sender
        self.senderTitle = senderTitle
        self.turnReceived = turnReceived
        self.turnDeadline = urgency.defaultDeadline.map { turnReceived + $0 }
        self.urgency = urgency.rawValue
        self.category = category.rawValue
        self.bodyText = bodyText
        self.status = DocumentStatus.unread.rawValue
        self.requiresDecision = requiresDecision
        self.isHandwritten = documentType.isHandwritten
        self.hasStamp = urgency >= .urgent
        self.stampText = urgency.stampText
        self.hasCoffeeStain = Bool.random() && Double.random(in: 0...1) < 0.2
        self.rotation = Double.random(in: -3...3)

        if !options.isEmpty {
            self.optionsData = try? JSONEncoder().encode(options)
        }
    }

    // MARK: - Actions

    /// Mark the document as read
    func markAsRead() {
        if statusEnum == .unread {
            statusEnum = .read
        }
    }

    /// Record a decision on this document
    func recordDecision(optionId: String, turn: Int) {
        chosenOptionId = optionId
        turnActedOn = turn
        statusEnum = .acted
    }

    /// File the document (safe storage)
    func file() {
        statusEnum = .filed
    }

    /// Burn/destroy the document
    func burn() {
        statusEnum = .burned
    }

    /// Mark as expired (deadline passed)
    func expire() {
        statusEnum = .expired
    }
}

// MARK: - Document Builder

/// Fluent builder for creating documents
class DeskDocumentBuilder {
    private var templateId: String = "doc_\(UUID().uuidString.prefix(8))"
    private var documentType: DocumentType = .memo
    private var title: String = ""
    private var sender: String = ""
    private var senderTitle: String?
    private var senderCharacterId: String?
    private var turnReceived: Int = 1
    private var urgency: DocumentUrgency = .routine
    private var category: DocumentCategory = .political
    private var classification: String?
    private var headerText: String?
    private var bodyText: String = ""
    private var footnoteText: String?
    private var requiresDecision: Bool = false
    private var options: [DocumentOption] = []
    private var consequenceIfIgnored: String?
    private var consequenceEffects: [String: Int]?
    private var customDeadline: Int?

    func withTemplateId(_ id: String) -> DeskDocumentBuilder {
        self.templateId = id
        return self
    }

    func ofType(_ type: DocumentType) -> DeskDocumentBuilder {
        self.documentType = type
        return self
    }

    func titled(_ title: String) -> DeskDocumentBuilder {
        self.title = title
        return self
    }

    func from(_ sender: String, title: String? = nil, characterId: String? = nil) -> DeskDocumentBuilder {
        self.sender = sender
        self.senderTitle = title
        self.senderCharacterId = characterId
        return self
    }

    func receivedOnTurn(_ turn: Int) -> DeskDocumentBuilder {
        self.turnReceived = turn
        return self
    }

    func withUrgency(_ urgency: DocumentUrgency) -> DeskDocumentBuilder {
        self.urgency = urgency
        return self
    }

    func inCategory(_ category: DocumentCategory) -> DeskDocumentBuilder {
        self.category = category
        return self
    }

    func classified(as classification: String) -> DeskDocumentBuilder {
        self.classification = classification
        return self
    }

    func withHeader(_ header: String) -> DeskDocumentBuilder {
        self.headerText = header
        return self
    }

    func withBody(_ body: String) -> DeskDocumentBuilder {
        self.bodyText = body
        return self
    }

    func withFootnote(_ footnote: String) -> DeskDocumentBuilder {
        self.footnoteText = footnote
        return self
    }

    func requiresDecision(_ requires: Bool = true) -> DeskDocumentBuilder {
        self.requiresDecision = requires
        return self
    }

    func withOptions(_ options: [DocumentOption]) -> DeskDocumentBuilder {
        self.options = options
        self.requiresDecision = !options.isEmpty
        return self
    }

    func addOption(
        id: String,
        text: String,
        shortDescription: String,
        effects: [String: Int] = [:],
        setsFlag: String? = nil
    ) -> DeskDocumentBuilder {
        let option = DocumentOption(
            id: id,
            text: text,
            shortDescription: shortDescription,
            effects: effects,
            setsFlag: setsFlag
        )
        self.options.append(option)
        self.requiresDecision = true
        return self
    }

    func withConsequenceIfIgnored(_ description: String, effects: [String: Int] = [:]) -> DeskDocumentBuilder {
        self.consequenceIfIgnored = description
        self.consequenceEffects = effects
        return self
    }

    func withDeadline(turnsFromNow turns: Int) -> DeskDocumentBuilder {
        self.customDeadline = turns
        return self
    }

    func build() -> DeskDocument {
        let doc = DeskDocument(
            templateId: templateId,
            documentType: documentType,
            title: title,
            sender: sender,
            senderTitle: senderTitle,
            turnReceived: turnReceived,
            urgency: urgency,
            category: category,
            bodyText: bodyText,
            requiresDecision: requiresDecision,
            options: options
        )

        doc.senderCharacterId = senderCharacterId
        doc.classification = classification
        doc.headerText = headerText
        doc.footnoteText = footnoteText
        doc.consequenceIfIgnored = consequenceIfIgnored
        doc.consequenceEffects = consequenceEffects

        if let custom = customDeadline {
            doc.turnDeadline = turnReceived + custom
        }

        return doc
    }
}

// MARK: - Extensions

extension DeskDocument {
    /// Create a builder for fluent document construction
    static func builder() -> DeskDocumentBuilder {
        DeskDocumentBuilder()
    }
}
