//
//  DocumentQueueService.swift
//  Nomenklatura
//
//  Manages the queue of documents on the player's desk.
//  Handles document generation, aging, consequences, and prioritization.
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import os.log

private let documentLog = Logger(subsystem: "com.ryanrudat.Nomenklatura", category: "DocumentQueue")

// MARK: - Document Queue Service

@MainActor
class DocumentQueueService: ObservableObject {

    static let shared = DocumentQueueService()

    // MARK: - Configuration

    /// Maximum documents visible on desk at once
    let maxVisibleDocuments = 5

    /// Maximum total documents in queue before oldest get auto-filed
    let maxQueueSize = 12

    /// Chance of generating a new document each turn (base rate)
    let baseDocumentChance: Double = 0.7

    // MARK: - Published State

    @Published var isProcessing = false

    // MARK: - Document Retrieval

    /// Get all active documents for a game (not filed, burned, or expired)
    func getActiveDocuments(for game: Game) -> [DeskDocument] {
        let validStatuses: Set<String> = [
            DocumentStatus.unread.rawValue,
            DocumentStatus.read.rawValue,
            DocumentStatus.pending.rawValue
        ]

        return game.deskDocuments
            .filter { validStatuses.contains($0.status) }
            .sorted { doc1, doc2 in
                // Sort by urgency (highest first), then by turn received (oldest first)
                if doc1.urgencyEnum != doc2.urgencyEnum {
                    return doc1.urgencyEnum > doc2.urgencyEnum
                }
                return doc1.turnReceived < doc2.turnReceived
            }
    }

    /// Get documents visible on the desk (top N by priority)
    func getVisibleDocuments(for game: Game) -> [DeskDocument] {
        Array(getActiveDocuments(for: game).prefix(maxVisibleDocuments))
    }

    /// Get overflow documents (in the stack, not on desk)
    func getStackedDocuments(for game: Game) -> [DeskDocument] {
        Array(getActiveDocuments(for: game).dropFirst(maxVisibleDocuments))
    }

    /// Count of unread documents
    func unreadCount(for game: Game) -> Int {
        game.deskDocuments.filter { $0.statusEnum == .unread }.count
    }

    /// Count of documents requiring decision
    func pendingDecisionCount(for game: Game) -> Int {
        getActiveDocuments(for: game).filter { $0.requiresDecision && $0.statusEnum != .acted }.count
    }

    /// Get documents expiring this turn
    func getExpiringDocuments(for game: Game) -> [DeskDocument] {
        getActiveDocuments(for: game).filter { doc in
            doc.turnsRemaining(currentTurn: game.turnNumber) == 0
        }
    }

    // MARK: - Document Generation

    /// Track generated document titles this turn to prevent duplicates
    private var generatedThisTurn: Set<String> = []

    /// Track generated document categories this turn to prevent multiple of same type
    private var categoriesGeneratedThisTurn: Set<DocumentCategory> = []

    /// Track if a crisis-themed document was generated (to coordinate with events)
    private var crisisDocumentGeneratedThisTurn: Bool = false

    /// Track the last turn we generated documents for (to prevent reset on multiple calls same turn)
    private var lastGenerationTurn: Int = -1

    // MARK: - Name Generation for Document Lists

    /// Eastern European/Soviet-style first names
    private let firstNames = [
        "Viktor", "Ivan", "Nikolai", "Dmitri", "Sergei", "Aleksei", "Boris", "Yuri", "Andrei", "Pavel",
        "Maria", "Natasha", "Olga", "Katerina", "Anna", "Elena", "Tatiana", "Irina", "Svetlana", "Ludmila",
        "Mikhail", "Vasili", "Grigori", "Fyodor", "Oleg", "Konstantin", "Vladimir", "Pyotr", "Arkady", "Roman",
        "Vera", "Nina", "Galina", "Zoya", "Larisa", "Tamara", "Valentina", "Raisa", "Nadia", "Sonya"
    ]

    /// Eastern European/Soviet-style last names
    private let lastNames = [
        "Petrov", "Kozlov", "Volkov", "Morozov", "Sokolov", "Fedorov", "Ivanov", "Kuznetsov", "Popov", "Smirnov",
        "Novikov", "Lebedev", "Orlov", "Zaitsev", "Pavlov", "Kovalev", "Belov", "Medvedev", "Andreev", "Makarov",
        "Gromov", "Borisov", "Kiselev", "Zhukov", "Voronov", "Korolev", "Baranov", "Stepanov", "Golubev", "Vinogradov",
        "Bogdanov", "Voronin", "Sorokin", "Danilov", "Grigoriev", "Romanov", "Vasiliev", "Tarasov", "Belousov", "Nikitin"
    ]

    /// Work unit/department assignments for context
    private let workUnits = [
        "Section A", "Section B", "Section C", "Unit 12", "Unit 7", "Unit 23",
        "Records", "Filing", "Processing", "Registry", "Archives", "Communications",
        "Motor Pool", "Maintenance", "Security Detail", "Administrative Pool", "Typing Pool",
        "Department 3", "Department 5", "Department 8", "Bureau 2", "Bureau 6"
    ]

    /// Generate a list of random names with optional unit assignments
    private func generateNameList(count: Int, includeUnits: Bool = false) -> [String] {
        var names: Set<String> = []
        var attempts = 0
        let maxAttempts = count * 3

        while names.count < count && attempts < maxAttempts {
            attempts += 1
            let first = firstNames.randomElement()!
            let last = lastNames.randomElement()!
            let fullName: String

            if includeUnits {
                let unit = workUnits.randomElement()!
                fullName = "\(first) \(last) (\(unit))"
            } else {
                fullName = "\(first) \(last)"
            }

            names.insert(fullName)
        }

        return Array(names).sorted { $0.components(separatedBy: " ").last ?? "" < $1.components(separatedBy: " ").last ?? "" }
    }

    /// Format a name list as a numbered document attachment
    private func formatNameListAsAttachment(names: [String], title: String) -> String {
        var result = """

        ═══════════════════════════════════════════
        ATTACHMENT: \(title.uppercased())
        ═══════════════════════════════════════════

        """

        for (index, name) in names.enumerated() {
            result += "\(String(format: "%2d", index + 1)). \(name)\n"
        }

        result += """

        ───────────────────────────────────────────
        Total: \(names.count) personnel
        """

        return result
    }

    /// Generate new documents for the current turn
    func generateDocumentsForTurn(game: Game) {
        let clearance = min(game.currentPositionIndex + 1, 8)
        documentLog.info("📄 [DocQueue] Starting document generation for turn \(game.turnNumber), Position: \(game.currentPositionIndex), Clearance: \(clearance)")

        isProcessing = true
        defer { isProcessing = false }

        // Only reset duplicate tracking when turn changes (prevents duplicates from multiple calls same turn)
        if game.turnNumber != lastGenerationTurn {
            generatedThisTurn.removeAll()
            categoriesGeneratedThisTurn.removeAll()
            crisisDocumentGeneratedThisTurn = false
            lastGenerationTurn = game.turnNumber
        } else {
            // Already generated documents this turn - skip to avoid duplicates
            documentLog.info("📄 [DocQueue] Skipping duplicate generation call for turn \(game.turnNumber)")
            return
        }

        // Generate pending follow-up documents FIRST (these have narrative priority)
        generatePendingFollowUpDocuments(game: game)

        // Also track existing document titles to avoid duplicates
        let existingTitles = Set(getActiveDocuments(for: game).map { $0.title })

        // Check for expired documents first
        processExpiredDocuments(game: game)

        // Determine how many new documents to generate
        let currentCount = getActiveDocuments(for: game).count
        let roomForMore = maxQueueSize - currentCount

        guard roomForMore > 0 else {
            // Queue is full, maybe auto-file some old routine documents
            autoFileOldDocuments(game: game)
            return
        }

        // Generate 1-3 new documents based on game state
        let docsToGenerate = calculateDocumentsToGenerate(game: game, maxNew: min(roomForMore, 3))

        var attempts = 0
        var generated = 0
        let maxAttempts = docsToGenerate * 3 // Allow some retries for duplicates

        while generated < docsToGenerate && attempts < maxAttempts {
            attempts += 1
            if let newDoc = generateDocument(for: game) {
                // Check for duplicates by title AND category
                let isDuplicateTitle = existingTitles.contains(newDoc.title) || generatedThisTurn.contains(newDoc.title)
                let isDuplicateCategory = categoriesGeneratedThisTurn.contains(newDoc.categoryEnum)

                // Allow max 1 document per category per turn (except routine political/economic)
                let isExemptCategory = newDoc.categoryEnum == .political || newDoc.categoryEnum == .economic
                let categoryAllowed = !isDuplicateCategory || (isExemptCategory && categoriesGeneratedThisTurn.filter { $0 == newDoc.categoryEnum }.count < 2)

                if !isDuplicateTitle && categoryAllowed {
                    generatedThisTurn.insert(newDoc.title)
                    categoriesGeneratedThisTurn.insert(newDoc.categoryEnum)
                    if newDoc.categoryEnum == .crisis {
                        crisisDocumentGeneratedThisTurn = true
                    }
                    newDoc.game = game
                    game.deskDocuments.append(newDoc)
                    generated += 1
                }
            }
        }
    }

    /// Check if a crisis document was generated this turn (for event coordination)
    func didGenerateCrisisDocumentThisTurn() -> Bool {
        return crisisDocumentGeneratedThisTurn
    }

    /// Calculate how many documents to generate this turn
    private func calculateDocumentsToGenerate(game: Game, maxNew: Int) -> Int {
        var count = 0

        // Base chance for first document
        if Double.random(in: 0...1) < baseDocumentChance {
            count += 1
        }

        // Additional documents based on game state
        // High tension = more documents
        if game.stability < 40 && Double.random(in: 0...1) < 0.5 {
            count += 1
        }

        // Crisis situations generate more paperwork
        if game.flags.contains("active_crisis") && Double.random(in: 0...1) < 0.6 {
            count += 1
        }

        // Higher position = more documents
        if game.currentPositionIndex >= 3 && Double.random(in: 0...1) < 0.4 {
            count += 1
        }

        return min(count, maxNew)
    }

    /// Generate a single document appropriate for the game state
    private func generateDocument(for game: Game) -> DeskDocument? {
        // Determine document category based on weights
        let category = selectDocumentCategory(for: game)

        // Generate based on category
        switch category {
        case .security:
            return generateSecurityDocument(for: game)
        case .military:
            return generateMilitaryDocument(for: game)
        case .economic:
            return generateEconomicDocument(for: game)
        case .political:
            return generatePoliticalDocument(for: game)
        case .diplomatic:
            return generateDiplomaticDocument(for: game)
        case .personnel:
            return generatePersonnelDocument(for: game)
        case .crisis:
            return generateCrisisDocument(for: game)
        case .personal:
            return generatePersonalDocument(for: game)
        }
    }

    /// Select which category of document to generate
    private func selectDocumentCategory(for game: Game) -> DocumentCategory {
        // Weight categories based on game state
        var weights: [DocumentCategory: Double] = [
            .security: 15,
            .military: 15,
            .economic: 20,
            .political: 20,
            .diplomatic: 10,
            .personnel: 15,
            .crisis: 3,
            .personal: 2
        ]

        // Adjust weights based on game state
        if game.stability < 30 {
            weights[.crisis] = 15
            weights[.security] = 25
        }

        if game.treasury < 200 {
            weights[.economic] = 30
        }

        // Apply role-based document weighting based on player's track and position
        applyRoleBasedWeights(&weights, game: game)

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        var random = Double.random(in: 0..<totalWeight)

        for (category, weight) in weights {
            random -= weight
            if random <= 0 {
                return category
            }
        }

        return .political // Default fallback
    }

    /// Apply role-based document weighting based on player's track and position
    private func applyRoleBasedWeights(_ weights: inout [DocumentCategory: Double], game: Game) {
        let playerTrack = game.currentCommittedTrack
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Adjust weights based on player's career track
        // Players receive more documents relevant to their specialization
        if let track = playerTrack {
            switch track {
            case .securityServices:
                // Security track: 2x security documents, 1.5x crisis documents
                weights[.security] = (weights[.security] ?? 15) * 2.0
                weights[.crisis] = (weights[.crisis] ?? 3) * 1.5
            case .economicPlanning:
                // Economic track: 1.75x economic documents
                weights[.economic] = (weights[.economic] ?? 20) * 1.75
            case .militaryPolitical:
                // Military track: 2x military documents
                weights[.military] = (weights[.military] ?? 15) * 2.0
            case .partyApparatus:
                // Party track: 1.75x political, 1.5x personnel documents
                weights[.political] = (weights[.political] ?? 20) * 1.75
                weights[.personnel] = (weights[.personnel] ?? 15) * 1.5
            case .foreignAffairs:
                // Foreign Affairs track: 2x diplomatic documents
                weights[.diplomatic] = (weights[.diplomatic] ?? 10) * 2.0
            case .stateMinistry:
                // State Ministry: 1.5x economic, 1.5x political
                weights[.economic] = (weights[.economic] ?? 20) * 1.5
                weights[.political] = (weights[.political] ?? 20) * 1.5
            case .regional:
                // Regional track: 1.5x economic, 1.5x personnel (regional matters)
                weights[.economic] = (weights[.economic] ?? 20) * 1.5
                weights[.personnel] = (weights[.personnel] ?? 15) * 1.5
            case .shared:
                // Shared track: No specific weighting - balanced documents
                break
            }
        }

        // Clearance-based filtering
        // Low clearance players don't see crisis or high-sensitivity documents
        if clearanceLevel < 3 {
            weights[.crisis] = 0  // No crisis documents for low-level officials
        }

        // Higher positions see more personnel matters (promotions, transfers, etc.)
        if clearanceLevel >= 5 {
            weights[.personnel] = (weights[.personnel] ?? 15) * 1.3
        }

        // Very high positions see more diplomatic matters
        if clearanceLevel >= 6 {
            weights[.diplomatic] = (weights[.diplomatic] ?? 10) * 1.2
        }
    }

    // MARK: - Category-Specific Document Generators

    private func generateSecurityDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Templates with minimum clearance requirements
        // Security clearances should reflect actual operational responsibility:
        // - Levels 1-2: Administrative security (forwarding reports, loyalty matters)
        // - Levels 3-4: Security oversight (surveillance, investigations)
        // - Levels 5+: Intelligence operations (running assets, covert ops)
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateDenunciationLetter),      // Simple - Level 1+ (just forward accusations)
            (2, generateSecurityConcernReport),   // Entry - Level 2+ (minor security concerns)
            (3, generateSurveillanceReport),      // Security - Level 3+ (approve/deny surveillance)
            (4, generateArrestAuthorization),     // High stakes - Level 4+ (life-altering decision)
            (5, generateIntelligenceHandlerReport) // Intelligence - Level 5+ (running assets is senior work)
        ]

        // Filter templates available at current clearance
        let available = templates.filter { $0.minClearance <= clearanceLevel }

        // Weighted selection preferring appropriate challenge level
        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            return generator(game)
        }

        return generateDenunciationLetter(for: game)
    }

    private func generateDenunciationLetter(for game: Game) -> DeskDocument {
        let subjects = [
            ("Marcus Henderson", "Factory Worker", "Textile Mill #7"),
            ("Dr. Anna Kowalski", "Physician", "City Hospital"),
            ("John Peterson", "Teacher", "Secondary School #12"),
            ("Ellen Morrison", "Secretary", "Trade Ministry"),
            ("Samuel Wallace", "Engineer", "Power Station #3")
        ]

        let (name, job, workplace) = subjects.randomElement()!

        let accusations = [
            "makes jokes about bread lines when supervisors aren't present",
            "has been receiving letters with foreign stamps",
            "was overheard questioning production quotas",
            "hasn't attended Party meetings in two months",
            "keeps a radio tuned to foreign broadcasts",
            "has expressed 'pessimistic' views about the Five-Year Plan",
            "associates with known unreliable elements"
        ]

        let accusation = accusations.randomElement()!

        let body = """
        CONFIDENTIAL - CITIZEN REPORT

        Subject: \(name.uppercased())
        Position: \(job), \(workplace)

        "\(name) \(accusation). Several coworkers have noticed this behavior over the past weeks. His/her attitude is concerning to those of us who take our socialist duties seriously."

        This report is submitted out of duty to the Party and the State.

        - A Concerned Patriot
        """

        return DeskDocument.builder()
            .withTemplateId("denunciation_\(UUID().uuidString.prefix(6))")
            .ofType(.denunciation)
            .titled("Citizen Report: \(name)")
            .from("Anonymous", title: "Concerned Citizen")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.security)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "investigate",
                text: "INVESTIGATE - Open a case file and assign an agent",
                shortDescription: "Opened investigation",
                effects: ["network": -5],
                setsFlag: "investigating_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                triggersDocument: "investigation_denunciation_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .addOption(
                id: "file",
                text: "FILE - Keep on record but take no action",
                shortDescription: "Filed report",
                effects: [:]
            )
            .addOption(
                id: "burn",
                text: "BURN - Destroy the report",
                shortDescription: "Destroyed report",
                effects: ["security": -2]
            )
            .addOption(
                id: "forward",
                text: "FORWARD - Pass to superior (covers you)",
                shortDescription: "Forwarded to superiors",
                effects: ["patronFavor": -3]
            )
            .withConsequenceIfIgnored(
                "The report sat on your desk. If \(name) later causes trouble, questions will be asked.",
                effects: ["security": -5]
            )
            .build()
    }

    private func generateSurveillanceReport(for game: Game) -> DeskDocument {
        let targets = [
            ("Deputy Minister Kowalski", "meeting privately with foreign diplomats"),
            ("Colonel Andrew Peterson", "making unauthorized phone calls"),
            ("Factory Director Morrison", "falsifying production reports"),
            ("Professor Whitmore", "contacting local academics")
        ]

        let (target, activity) = targets.randomElement()!

        let body = """
        SURVEILLANCE REPORT - CLASSIFIED

        Subject: \(target.uppercased())
        Period: Past 14 days
        Classification: EYES ONLY

        Our assets report the subject has been observed \(activity). This pattern has been consistent over multiple observations.

        Assessment: Activity may indicate disloyalty, foreign contact, or corruption. Further investigation recommended.

        Awaiting authorization for enhanced surveillance measures.

        - Bureau of People's Security
        """

        return DeskDocument.builder()
            .withTemplateId("surveillance_\(UUID().uuidString.prefix(6))")
            .ofType(.intelligence)
            .titled("Surveillance Report: \(target)")
            .from("Agent Starling", title: "Field Operations")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.security)
            .classified(as: "CLASSIFIED")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "enhanced",
                text: "AUTHORIZE ENHANCED SURVEILLANCE",
                shortDescription: "Authorized enhanced surveillance",
                effects: ["network": -10, "security": 5],
                triggersDocument: "surveillance_\(target.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .addOption(
                id: "continue",
                text: "CONTINUE CURRENT LEVEL",
                shortDescription: "Continued surveillance",
                effects: [:]
            )
            .addOption(
                id: "close",
                text: "CLOSE SURVEILLANCE - Insufficient evidence",
                shortDescription: "Closed surveillance",
                effects: ["security": -3]
            )
            .build()
    }

    private func generateArrestAuthorization(for game: Game) -> DeskDocument {
        let suspects = [
            ("Ellen Vance", "Secretary", "Suspicion of espionage"),
            ("Dr. Paul Orlando", "Researcher", "Unauthorized foreign contacts"),
            ("Mary Anderson", "Journalist", "Anti-state propaganda")
        ]

        let (name, position, charge) = suspects.randomElement()!

        // Use position-aware language
        let authority = AuthorityLanguage(game: game)
        let arrestLang = authority.arrestAuthorizationLanguage

        let body = """
        \(arrestLang.header)
        URGENT - TIME SENSITIVE

        Subject: \(name.uppercased())
        Position: \(position)
        Charge: \(charge)

        Evidence summary attached. Subject is aware of investigation and may attempt to flee or destroy evidence.

        \(arrestLang.action)

        Note: Subject has family connections to [REDACTED]. Political sensitivity noted.

        \(authority.signatureLine(for: "arrest"))

        \(arrestLang.footer)
        """

        // Adjust option text based on authority level
        let authorizeText = authority.hasUnilateralArrestAuthority ? "AUTHORIZE ARREST" :
                           authority.hasArrestAuthority ? "APPROVE - Forward for authorization" :
                           "ENDORSE - Recommend arrest"
        let authorizeDesc = authority.hasUnilateralArrestAuthority ? "Authorized arrest" :
                           authority.hasArrestAuthority ? "Approved arrest request" :
                           "Endorsed arrest recommendation"

        return DeskDocument.builder()
            .withTemplateId("arrest_\(UUID().uuidString.prefix(6))")
            .ofType(.directive)
            .titled("\(arrestLang.header): \(name)")
            .from("Director Wallace", title: "Bureau of People's Security")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.security)
            .classified(as: "SECRET")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "authorize",
                text: authorizeText,
                shortDescription: authorizeDesc,
                effects: ["security": 10, "stability": -5],
                setsFlag: "arrested_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))",
                triggersDocument: "arrested_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .addOption(
                id: "deny",
                text: "DENY - Insufficient evidence",
                shortDescription: "Denied arrest",
                effects: ["security": -5]
            )
            .addOption(
                id: "delay",
                text: "REQUEST MORE EVIDENCE",
                shortDescription: "Requested more evidence",
                effects: [:],
                triggersDocument: "evidence_update_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .withConsequenceIfIgnored(
                "The suspect fled while awaiting your decision. Security is furious.",
                effects: ["security": -15, "patronFavor": -10]
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    /// Level 2+: Minor security concerns requiring basic judgment
    private func generateSecurityConcernReport(for game: Game) -> DeskDocument {
        let concerns = [
            ("Unauthorized Photographs", "A visitor was observed photographing building exteriors near the loading dock.", "maintenance worker"),
            ("After-Hours Access", "An employee badge was used to access the building at 3:47 AM last Tuesday.", "junior clerk"),
            ("Missing Documents", "Three copies of the quarterly production report cannot be located.", "filing department"),
            ("Suspicious Inquiry", "A telephone caller asked detailed questions about shift schedules.", "unknown")
        ]

        let concern = concerns.randomElement()!

        let body = """
        SECURITY CONCERN REPORT

        Incident: \(concern.0)
        Source: Building Security, Floor 3

        Details: \(concern.1)

        Person of Interest: \(concern.2.capitalized)

        Security Assessment: This incident may be innocent or may indicate a security vulnerability. Further investigation could clarify the situation but may be disruptive.

        REQUESTED ACTION: Your guidance on how to proceed.
        """

        return DeskDocument.builder()
            .withTemplateId("security_concern_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Security Concern: \(concern.0)")
            .from("Building Security", title: "Security Office")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.security)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "investigate",
                text: "INVESTIGATE - Conduct discreet inquiry",
                shortDescription: "Ordered investigation",
                effects: ["security": 3],
                triggersDocument: "investigation_security_\(UUID().uuidString.prefix(8))"
            )
            .addOption(
                id: "note",
                text: "NOTE - Log incident, no action",
                shortDescription: "Logged incident",
                effects: [:]
            )
            .addOption(
                id: "dismiss",
                text: "DISMISS - No security concern",
                shortDescription: "Dismissed concern",
                effects: ["security": -2]
            )
            .build()
    }

    /// Level 5+: Senior intelligence work - managing field assets
    private func generateIntelligenceHandlerReport(for game: Game) -> DeskDocument {
        // Use position-aware language
        let authority = AuthorityLanguage(game: game)
        let intelLang = authority.intelligenceDocumentLanguage

        let body = """
        \(intelLang.header)
        WEEKLY HANDLER REPORT

        Asset: RAVEN (codename)
        Placement: Foreign Ministry
        Handler: SPARROW

        \(intelLang.context)

        RAVEN reports unusual activity in the trade delegation. Several officials have been meeting after hours, discussing matters not reflected in official minutes.

        RAVEN assessment: Possible corruption or unauthorized negotiations. Cannot determine scope without closer access.

        RAVEN requests guidance on whether to pursue this lead or maintain current cover.

        Handler assessment: RAVEN is reliable but this may be beyond current operational scope. Pursuing could compromise years of placement work.

        RECOMMENDED ACTION: \(authority.hasIntelligenceAuthority ? "Awaiting your direction." : "Awaiting direction from senior leadership. Your input will be forwarded.")
        """

        // Adjust option text based on authority level
        let pursueText = authority.hasIntelligenceAuthority ? "AUTHORIZE - Pursue the lead" :
                        "RECOMMEND PURSUIT - Forward recommendation"
        let pursueDesc = authority.hasIntelligenceAuthority ? "Authorized investigation" :
                        "Recommended pursuit"

        return DeskDocument.builder()
            .withTemplateId("handler_\(UUID().uuidString.prefix(6))")
            .ofType(.intelligence)
            .titled("Intelligence Brief: Asset RAVEN")
            .from("Handler SPARROW", title: "Directorate S")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.security)
            .classified(as: intelLang.header)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "pursue",
                text: pursueText,
                shortDescription: pursueDesc,
                effects: ["network": -5],
                triggersDocument: "investigation_intel_\(UUID().uuidString.prefix(8))"
            )
            .addOption(
                id: "maintain",
                text: "MAINTAIN COVER - Do not pursue",
                shortDescription: "Maintained cover",
                effects: [:]
            )
            .addOption(
                id: "extract",
                text: authority.hasIntelligenceAuthority ? "EXTRACT ASSET - Too risky" : "RECOMMEND EXTRACTION",
                shortDescription: authority.hasIntelligenceAuthority ? "Extracted asset" : "Recommended extraction",
                effects: ["network": -15, "security": 5]
            )
            .build()
    }

    // MARK: - Military Category Documents

    private func generateMilitaryDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Military clearances reflect operational responsibility:
        // - Levels 1-2: Administrative filing, supply paperwork
        // - Levels 3-4: Unit discipline, equipment allocation
        // - Levels 5+: Border incidents, tactical decisions
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateSupplyFilingRequest),       // Level 1+ (routine filing)
            (1, generateMaintenanceLogReview),      // Level 1+ (basic admin)
            (2, generateRequisitionRequest),        // Level 2+ (resource allocation)
            (3, generateDisciplineCase),            // Level 3+ (personnel matters)
            (4, generateBorderIncidentReport),      // Level 4+ (high-stakes tactical)
            (5, generateMilitaryReadinessAssessment) // Level 5+ (strategic oversight)
        ]

        let available = templates.filter { $0.minClearance <= clearanceLevel }

        // Weighted selection preferring appropriate challenge level
        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            return generator(game)
        }

        return generateSupplyFilingRequest(for: game)
    }

    /// Level 1+: Basic administrative filing
    private func generateSupplyFilingRequest(for game: Game) -> DeskDocument {
        let items = [
            ("Winter boots", "23rd Infantry", "47 pairs"),
            ("Uniform buttons", "Quartermaster Depot", "2,400 units"),
            ("Typewriter ribbons", "Administrative Pool", "36 spools"),
            ("Blankets", "Training Barracks", "85 units")
        ]

        let (item, unit, quantity) = items.randomElement()!

        let body = """
        SUPPLY REQUEST - FILING CONFIRMATION

        Request ID: SR-\(Int.random(in: 10000...99999))
        Requesting Unit: \(unit)
        Item: \(item)
        Quantity: \(quantity)

        This request has been logged in the central supply system. Please verify the quantities match the attached requisition form and file according to standard procedure.

        Note: Any discrepancies should be noted on Form 27-B and forwarded to the Supply Audit Office.

        REQUIRES YOUR SIGNATURE FOR FILING.
        """

        return DeskDocument.builder()
            .withTemplateId("supply_filing_\(UUID().uuidString.prefix(6))")
            .ofType(.requisition)
            .titled("Supply Filing: \(item)")
            .from("Central Supply Office", title: "Logistics Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.military)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Quantities verified",
                shortDescription: "Approved filing",
                effects: [:]
            )
            .addOption(
                id: "flag_discrepancy",
                text: "FLAG DISCREPANCY - Request audit",
                shortDescription: "Flagged for audit",
                effects: ["security": 2]
            )
            .build()
    }

    /// Level 1+: Basic maintenance review
    private func generateMaintenanceLogReview(for game: Game) -> DeskDocument {
        let vehicles = [
            ("Transport Truck #147", "3rd Transport Battalion"),
            ("Staff Car #23", "Regional Command Pool"),
            ("Maintenance Vehicle #89", "Repair Depot")
        ]

        let (vehicle, unit) = vehicles.randomElement()!
        let hoursLogged = Int.random(in: 200...450)

        let body = """
        MONTHLY MAINTENANCE LOG REVIEW

        Vehicle: \(vehicle)
        Assigned Unit: \(unit)
        Hours Logged This Month: \(hoursLogged)

        The attached maintenance log has been submitted for monthly review. Standard procedure requires verification that:

        1. Oil changes performed on schedule
        2. Tire inspections documented
        3. Fuel consumption within normal parameters

        Chief Mechanic notes: "All appears in order, but the fuel consumption seems slightly high. Could be nothing."

        SIGN TO CONFIRM REVIEW COMPLETE.
        """

        return DeskDocument.builder()
            .withTemplateId("maintenance_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Maintenance Review: \(vehicle)")
            .from("Motor Pool", title: "Vehicle Maintenance")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.military)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Log satisfactory",
                shortDescription: "Approved maintenance log",
                effects: [:]
            )
            .addOption(
                id: "investigate_fuel",
                text: "INVESTIGATE - Check fuel records",
                shortDescription: "Investigated fuel usage",
                effects: ["security": 3]
            )
            .addOption(
                id: "request_detail",
                text: "REQUEST DETAIL - Need more information",
                shortDescription: "Requested details",
                effects: [:]
            )
            .build()
    }

    /// Level 5+: Strategic military readiness assessment
    private func generateMilitaryReadinessAssessment(for game: Game) -> DeskDocument {
        let authority = AuthorityLanguage(game: game)

        let readinessPercent = Int.random(in: 55...78)
        let criticalShortage = ["ammunition", "medical supplies", "winter gear", "vehicle parts"].randomElement()!

        let body = """
        CLASSIFIED - STRATEGIC ASSESSMENT
        QUARTERLY MILITARY READINESS REPORT

        OVERALL READINESS: \(readinessPercent)%

        CRITICAL FINDINGS:
        1. \(criticalShortage.capitalized) reserves below minimum threshold
        2. Training exercises delayed due to budget constraints
        3. Officer retention down 12% from last quarter

        REGIONAL BREAKDOWN:
        - Northern District: 72% (border tensions increasing)
        - Eastern District: 65% (equipment shortages)
        - Southern District: 81% (stable)
        - Western District: 58% (significant concerns)

        RECOMMENDATION: Immediate resource reallocation to address critical shortages. Without action, readiness could fall below 50% within two quarters.

        \(authority.approvalChain)
        """

        let authorizeText = authority.isTopLeadership ? "AUTHORIZE REALLOCATION" : "RECOMMEND REALLOCATION"

        return DeskDocument.builder()
            .withTemplateId("readiness_\(UUID().uuidString.prefix(6))")
            .ofType(.intelligence)
            .titled("Strategic Readiness Assessment")
            .from("General Staff", title: "Defense Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.military)
            .classified(as: "TOP SECRET")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "reallocate",
                text: "\(authorizeText) - Address shortages",
                shortDescription: "Authorized reallocation",
                effects: ["military": 10, "treasury": -40]
            )
            .addOption(
                id: "defer",
                text: "DEFER - Request updated assessment",
                shortDescription: "Deferred action",
                effects: ["military": -5]
            )
            .addOption(
                id: "minimize",
                text: "MINIMIZE REPORT - Revise figures upward",
                shortDescription: "Minimized concerns",
                effects: ["security": -5],
                setsFlag: "falsified_readiness_report"
            )
            .build()
    }

    private func generateRequisitionRequest(for game: Game) -> DeskDocument {
        let units = [
            ("4th Armored Division", "Col. Andrew Peterson"),
            ("12th Infantry Battalion", "Maj. Victor Reynolds"),
            ("7th Artillery Regiment", "Col. Maria Sullivan")
        ]

        let (unit, commander) = units.randomElement()!

        let items = [
            "200 winter uniforms",
            "47 vehicle batteries",
            "Medical supplies (list attached)",
            "12,000 rounds ammunition"
        ]

        let body = """
        EQUIPMENT REQUISITION - PRIORITY

        FROM: \(commander), \(unit)
        TO: Defense Ministry Logistics

        REQUEST:
        \(items.shuffled().prefix(3).map { "- \($0)" }.joined(separator: "\n"))

        JUSTIFICATION: Division readiness currently at 67% due to equipment shortages. Inspection scheduled for next month.

        Personal note (handwritten):
        "Comrade, I know resources are tight. But my men are struggling. I'm not asking for myself. - \(commander.components(separatedBy: " ").last ?? "Commander")"
        """

        return DeskDocument.builder()
            .withTemplateId("requisition_\(UUID().uuidString.prefix(6))")
            .ofType(.requisition)
            .titled("Equipment Requisition: \(unit)")
            .from(commander, title: "Division Commander")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.military)
            .withBody(body)
            .withFootnote("The handwritten note is personal - he didn't have to add it.")
            .requiresDecision(true)
            .addOption(
                id: "approve_full",
                text: "APPROVE IN FULL",
                shortDescription: "Approved full requisition",
                effects: ["treasury": -50, "military": 10]
            )
            .addOption(
                id: "approve_partial",
                text: "APPROVE PARTIAL - Essential items only",
                shortDescription: "Approved partial requisition",
                effects: ["treasury": -25, "military": 5]
            )
            .addOption(
                id: "deny",
                text: "DENY - Insufficient resources",
                shortDescription: "Denied requisition",
                effects: ["military": -10]
            )
            .addOption(
                id: "reallocate",
                text: "REALLOCATE FROM ANOTHER UNIT",
                shortDescription: "Reallocated from other unit",
                effects: ["military": 5],
                triggersDocument: "reallocation_\(unit.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .build()
    }

    private func generateBorderIncidentReport(for game: Game) -> DeskDocument {
        let body = """
        CLASSIFIED - IMMEDIATE ACTION REQUIRED
        BORDER INCIDENT REPORT - SECTOR 7

        0342 HOURS: Patrol unit engaged unidentified personnel crossing from Western sector.

        Exchange of fire. Duration: approximately 8 minutes.

        CASUALTIES:
        - Pvt. Daniel O'Brien, deceased (gunshot wound)
        - Pvt. Anna Sullivan, wounded (stable)
        - 2 unidentified foreign nationals, deceased
        - 1 foreign national, captured (wounded)

        Captured individual carried documents suggesting [REDACTED - EYES ONLY]

        Sgt. Martin requesting guidance on:
        1. Disposition of captured individual
        2. Whether to report through normal channels
        3. Whether to request reinforcements

        AWAITING ORDERS.
        """

        return DeskDocument.builder()
            .withTemplateId("border_incident_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Border Incident: Sector 7")
            .from("Sgt. James Martin", title: "Border Patrol Unit 7")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.critical)
            .inCategory(.military)
            .classified(as: "TOP SECRET")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "contain",
                text: "CONTAIN - Handle internally, no report",
                shortDescription: "Contained incident",
                effects: ["security": 5, "stability": -5],
                setsFlag: "covered_up_border_incident"
            )
            .addOption(
                id: "escalate",
                text: "ESCALATE - Report up the chain immediately",
                shortDescription: "Reported incident",
                effects: ["patronFavor": 5]
            )
            .addOption(
                id: "interrogate",
                text: "INTERROGATE PRISONER - Before Security gets involved",
                shortDescription: "Interrogated prisoner first",
                effects: ["network": 10, "security": -5],
                triggersDocument: "interrogation_border_\(UUID().uuidString.prefix(8))"
            )
            .withConsequenceIfIgnored(
                "The situation at the border deteriorated. Questions are being asked about the delay.",
                effects: ["military": -10, "patronFavor": -15]
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    private func generateDisciplineCase(for game: Game) -> DeskDocument {
        let body = """
        MILITARY TRIBUNAL RECOMMENDATION
        Case #1247

        ACCUSED: Lieutenant Victor Reynolds
        UNIT: 12th Infantry Battalion
        CHARGE: Dereliction of duty; conduct unbecoming

        SUMMARY: Lt. Reynolds was found intoxicated while on duty during nighttime watch. When confronted, he allegedly stated: "What's the point? We're all just waiting to die in a war nobody wants."

        ACCUSED'S STATEMENT: "I take full responsibility. I ask only that my family not suffer for my weakness. My father served 30 years. My brother died at Antietam. I have shamed them."

        COMMANDING OFFICER: Recommends execution or hard labor.
        POLITICAL OFFICER: Recommends re-education.

        YOUR DECISION REQUIRED.
        """

        return DeskDocument.builder()
            .withTemplateId("discipline_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Courts-Martial: Lt. Viktor Reynolds")
            .from("Military Tribunal", title: "Judge Advocate")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.military)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "execution",
                text: "EXECUTION - Send a message",
                shortDescription: "Ordered execution",
                effects: ["military": 10, "stability": -10],
                setsFlag: "executed_reznik",
                triggersDocument: "case_outcome_execution_reynolds"
            )
            .addOption(
                id: "labor",
                text: "HARD LABOR (10 years)",
                shortDescription: "Sentenced to hard labor",
                effects: ["military": 5, "stability": -5]
            )
            .addOption(
                id: "reeducation",
                text: "RE-EDUCATION - 6 months, return to duty",
                shortDescription: "Ordered re-education",
                effects: ["military": -5],
                triggersDocument: "case_outcome_reeducation_reynolds"
            )
            .addOption(
                id: "discharge",
                text: "MEDICAL DISCHARGE - Unfit for service",
                shortDescription: "Medical discharge",
                effects: ["military": -3]
            )
            .build()
    }

    private func generateEconomicDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Templates with minimum clearance requirements
        // (minClearance, generator)
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateRoutineBudgetReport),       // Simple - Level 1+
            (1, generateSupplyShortageNotice),     // Simple - Level 1+
            (2, generateQuotaAdjustmentRequest),   // Medium - Level 2+
            (3, generateFactoryDirectorAppeal),    // Medium-Complex - Level 3+
            (4, generateProductionDiscrepancy),    // Complex - Level 4+
            (5, generateResourceAllocationRequest) // Complex - Level 5+
        ]

        // Filter templates available at current clearance
        let available = templates.filter { $0.minClearance <= clearanceLevel }

        // Prefer templates closer to player's level for appropriate challenge
        let weighted = available.flatMap { template -> [(Int, (Game) -> DeskDocument)] in
            // Weight higher-level documents more heavily if player can handle them
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: (template.minClearance, template.generator), count: weight)
        }

        if let selected = weighted.randomElement() {
            return selected.1(game)
        }

        // Fallback to simplest
        return generateRoutineBudgetReport(for: game)
    }

    // MARK: - Simple Economic Documents (Level 1-2)

    private func generateRoutineBudgetReport(for game: Game) -> DeskDocument {
        let surplus = Int.random(in: -15...25)
        let status = surplus >= 0 ? "SURPLUS" : "DEFICIT"
        let body = """
        MONTHLY BUDGET SUMMARY - YOUR DEPARTMENT

        Operating Budget: $\(Int.random(in: 50...150)),000
        Expenditures: $\(Int.random(in: 45...140)),000
        Status: \(status) of $\(abs(surplus)),000

        Review and initial below to confirm receipt.
        """

        return DeskDocument.builder()
            .withTemplateId("budget_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Monthly Budget Summary")
            .from("Accounting Office", title: "Finance Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.economic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "ACKNOWLEDGE - Initial and file",
                shortDescription: "Acknowledged budget report",
                effects: [:]
            )
            .addOption(
                id: "question",
                text: "REQUEST DETAILS - Ask for line items",
                shortDescription: "Requested budget details",
                effects: ["bureaucracy": 5]
            )
            .withDeadline(turnsFromNow: 3)
            .build()
    }

    private func generateSupplyShortageNotice(for game: Game) -> DeskDocument {
        let items = ["paper", "typewriter ribbons", "filing folders", "ink", "carbon paper"]
        let item = items.randomElement()!

        let body = """
        SUPPLY NOTICE

        Item: \(item.capitalized)
        Status: LOW STOCK
        Current Supply: \(Int.random(in: 1...3)) weeks remaining

        Requisition has been submitted. This is for your awareness.

        No action required unless you wish to expedite.
        """

        return DeskDocument.builder()
            .withTemplateId("supply_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Supply Shortage Notice")
            .from("Supply Clerk", title: "Administrative Services")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.economic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "file",
                text: "FILE - Note for records",
                shortDescription: "Filed supply notice",
                effects: [:]
            )
            .addOption(
                id: "expedite",
                text: "EXPEDITE - Use your authority to speed up",
                shortDescription: "Expedited supply order",
                effects: ["standing": 2, "bureaucracy": -5]
            )
            .withDeadline(turnsFromNow: 4)
            .build()
    }

    private func generateQuotaAdjustmentRequest(for game: Game) -> DeskDocument {
        let percentage = Int.random(in: 5...15)
        let direction = Bool.random() ? "increase" : "decrease"

        let body = """
        QUOTA ADJUSTMENT REQUEST

        From: District Production Committee
        Request: \(percentage)% \(direction) in quarterly targets

        Justification: \(direction == "increase" ? "New equipment installation complete. Capacity expanded." : "Equipment maintenance required. Temporary reduction needed.")

        Your approval is required to process this adjustment.
        """

        return DeskDocument.builder()
            .withTemplateId("quota_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Quota Adjustment Request")
            .from("District Committee", title: "Production Planning")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.economic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Grant the adjustment",
                shortDescription: "Approved quota adjustment",
                effects: direction == "increase" ? ["standing": 5] : ["stability": 5],
                triggersDocument: "compliance_quota_district_\(UUID().uuidString.prefix(6))"
            )
            .addOption(
                id: "deny",
                text: "DENY - Maintain current targets",
                shortDescription: "Denied quota adjustment",
                effects: direction == "increase" ? ["stability": -5] : ["standing": -5]
            )
            .addOption(
                id: "partial",
                text: "PARTIAL - Approve half the requested change",
                shortDescription: "Partially approved adjustment",
                effects: [:]
            )
            .withDeadline(turnsFromNow: 2)
            .build()
    }

    private func generateResourceAllocationRequest(for game: Game) -> DeskDocument {
        // Use position-aware language
        let authority = AuthorityLanguage(game: game)
        let resourceLang = authority.resourceAllocationLanguage(resource: "coal", amount: "40,000 tonnes")

        let actionLine = authority.hasStrategicResourceAuthority ?
            "YOU HAVE 40,000 TONNES TO DISTRIBUTE." :
            "Your recommendation will be forwarded to the Politburo for final allocation."

        let body = """
        \(resourceLang.header)
        URGENT - \(authority.hasStrategicResourceAuthority ? "ALLOCATION DECISION" : "INPUT") REQUIRED

        Available coal surplus for Q4: 40,000 tonnes
        Total requested: 185,000 tonnes

        \(resourceLang.action)

        REQUESTS:

        1. RESIDENTIAL HEATING - 60,000 tonnes
           "Predicted harsh winter. Without additional coal, rationing will be necessary."

        2. STEEL PRODUCTION - 50,000 tonnes
           "Current allocation insufficient to meet tank production targets."

        3. RAIL TRANSPORT - 45,000 tonnes
           "Locomotives at reduced capacity. Shipping delays mounting."

        4. EXPORT COMMITMENT - 30,000 tonnes
           "Contractual obligation to allied nation."

        \(actionLine)

        \(authority.approvalChain)
        """

        // Adjust option text based on authority level
        let verb = authority.hasStrategicResourceAuthority ? "ALLOCATE TO" : "RECOMMEND"

        return DeskDocument.builder()
            .withTemplateId("allocation_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled(resourceLang.header)
            .from("Planning Commission", title: "Resource Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.economic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "housing",
                text: "\(verb) HOUSING - People must not freeze",
                shortDescription: authority.hasStrategicResourceAuthority ? "Allocated to housing" : "Recommended housing priority",
                effects: ["stability": 10, "military": -10, "treasury": -20]
            )
            .addOption(
                id: "military",
                text: "\(verb) MILITARY - Defense above all",
                shortDescription: authority.hasStrategicResourceAuthority ? "Allocated to military" : "Recommended military priority",
                effects: ["military": 10, "stability": -10]
            )
            .addOption(
                id: "rail",
                text: "\(verb) TRANSPORT - Keep economy moving",
                shortDescription: authority.hasStrategicResourceAuthority ? "Allocated to transport" : "Recommended transport priority",
                effects: ["treasury": 20, "stability": -5]
            )
            .addOption(
                id: "export",
                text: "\(verb) EXPORTS - Honor commitments",
                shortDescription: authority.hasStrategicResourceAuthority ? "Allocated to exports" : "Recommended export priority",
                effects: ["diplomatic": 10, "stability": -15]
            )
            .withConsequenceIfIgnored(
                "Without your input, bureaucrats made the choice. Poorly.",
                effects: ["stability": -10, "treasury": -30]
            )
            .withDeadline(turnsFromNow: 2)
            .build()
    }

    private func generateProductionDiscrepancy(for game: Game) -> DeskDocument {
        let body = """
        INTERNAL MEMO - DO NOT DISTRIBUTE

        FROM: Statistical Analysis Division
        SUBJECT: Irregularities in Steel Sector Reporting

        Our analysis indicates significant discrepancies between reported and actual steel production.

        REPORTED (Q3): 2.4 million tonnes
        ESTIMATED ACTUAL: 1.7 million tonnes

        Discrepancy: approximately 700,000 tonnes (29% inflation)

        This pattern has persisted for 18 months. Previous reports may have been similarly inflated.

        IMPLICATIONS:
        - National figures are overstated
        - Five-Year Plan targets are fictionally "met"
        - Your predecessor approved these numbers

        WHAT DO YOU WANT US TO DO WITH THIS FINDING?
        """

        return DeskDocument.builder()
            .withTemplateId("discrepancy_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Production Discrepancy Analysis")
            .from("Statistical Analysis", title: "Planning Commission")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.economic)
            .classified(as: "INTERNAL ONLY")
            .withBody(body)
            .withFootnote("The analyst who wrote this is watching to see what you do.")
            .requiresDecision(true)
            .addOption(
                id: "bury",
                text: "BURY IT - Classify and destroy copies",
                shortDescription: "Buried the report",
                effects: ["security": -10],
                setsFlag: "buried_discrepancy_report"
            )
            .addOption(
                id: "correct",
                text: "CORRECT QUIETLY - Adjust future targets",
                shortDescription: "Quietly corrected",
                effects: ["treasury": -20]
            )
            .addOption(
                id: "report",
                text: "REPORT UP - Tell the Minister",
                shortDescription: "Reported to Minister",
                effects: ["patronFavor": -10, "security": 10],
                triggersDocument: "consequence_ministerial_response"
            )
            .addOption(
                id: "investigate",
                text: "INVESTIGATE SOURCE - Find who's lying",
                shortDescription: "Investigated source",
                effects: ["network": -10],
                triggersDocument: "investigation_production_\(UUID().uuidString.prefix(8))"
            )
            .build()
    }

    private func generateFactoryDirectorAppeal(for game: Game) -> DeskDocument {
        let body = """
        [HANDWRITTEN LETTER - not official channels]

        Comrade,

        I am writing to you directly because I am desperate. I am the director of Tractor Factory #12 in Volgograd.

        My factory has been assigned a quota of 500 tractors per quarter. Last quarter we produced 340. The quarter before, 380.

        The problem is not laziness. Our machinery is 40 years old. We have requested modernization funds for three years. Denied each time.

        I have 2,000 workers. They are trying. But you cannot build new tractors with broken machines.

        If we miss quota again, I will be arrested as a wrecker. My family will suffer.

        I am begging you - reduce our quota, or approve emergency funds, or tell me what I should do.

        I have a wife and two daughters. They are 10 and 14. The older one wants to be an engineer like her father.

        With desperate hope,
        Director Eugene Morrison
        """

        return DeskDocument.builder()
            .withTemplateId("appeal_\(UUID().uuidString.prefix(6))")
            .ofType(.letter)
            .titled("Personal Appeal: Dir. Morrison")
            .from("Eugene Morrison", title: "Director, Tractor Factory #12")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.economic)
            .withBody(body)
            .withFootnote("He put himself at risk writing this. Not through channels. To you personally.")
            .requiresDecision(true)
            .addOption(
                id: "reduce_quota",
                text: "REDUCE QUOTA - Make it achievable",
                shortDescription: "Reduced quota",
                effects: ["treasury": -10],
                setsFlag: "helped_morrison",
                triggersDocument: "compliance_factory_morrison"
            )
            .addOption(
                id: "approve_funds",
                text: "APPROVE EMERGENCY FUNDS",
                shortDescription: "Approved modernization",
                effects: ["treasury": -50]
            )
            .addOption(
                id: "ignore",
                text: "IGNORE - Not your problem",
                shortDescription: "Ignored appeal",
                effects: [:]
            )
            .addOption(
                id: "advise_fudge",
                text: "ADVISE - 'Do what everyone else does'",
                shortDescription: "Advised to fudge numbers",
                effects: ["security": -5]
            )
            .addOption(
                id: "visit",
                text: "VISIT FACTORY - See for yourself",
                shortDescription: "Visited factory",
                effects: [:],
                setsFlag: "visited_morrison_factory",
                triggersDocument: "visit_factory_morrison"
            )
            .withConsequenceIfIgnored(
                "Director Morrison was arrested three months later. His daughters are now in a state orphanage.",
                effects: ["stability": -5]
            )
            .build()
    }

    private func generatePoliticalDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Templates with minimum clearance requirements
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateMeetingAttendanceNotice),     // Simple - Level 1+
            (1, generateSloganUpdateMemo),            // Simple - Level 1+
            (2, generateLoyaltyPledgeReminder),       // Medium - Level 2+
            (3, generatePropagandaDirective),         // Complex - Level 3+
        ]

        let available = templates.filter { $0.minClearance <= clearanceLevel }

        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            return generator(game)
        }

        return generateMeetingAttendanceNotice(for: game)
    }

    private func generateMeetingAttendanceNotice(for game: Game) -> DeskDocument {
        let meetings = [
            "Weekly Party Study Circle",
            "Monthly Self-Criticism Session",
            "Quarterly Production Review",
            "Department Political Education"
        ]
        let meeting = meetings.randomElement()!

        let body = """
        ATTENDANCE NOTICE

        You are required to attend:
        \(meeting)

        Date: Next scheduled session
        Location: Conference Room B

        Attendance is mandatory. Please confirm.
        """

        return DeskDocument.builder()
            .withTemplateId("meeting_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Meeting Attendance Required")
            .from("Party Secretary", title: "Political Office")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "confirm",
                text: "CONFIRM - Will attend",
                shortDescription: "Confirmed attendance",
                effects: [:]
            )
            .addOption(
                id: "excuse",
                text: "REQUEST EXCUSE - Cite work obligations",
                shortDescription: "Requested excuse",
                effects: ["standing": -2]
            )
            .withDeadline(turnsFromNow: 3)
            .build()
    }

    private func generateSloganUpdateMemo(for game: Game) -> DeskDocument {
        let slogans = [
            "Forward to Victory!",
            "Unity Through Labor!",
            "The People's Will Prevails!",
            "Production for Progress!"
        ]

        let body = """
        SLOGAN UPDATE

        The approved slogan for this quarter:
        "\(slogans.randomElement()!)"

        Please ensure all departmental materials reflect this update.

        This is a routine notice requiring acknowledgment.
        """

        return DeskDocument.builder()
            .withTemplateId("slogan_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Quarterly Slogan Update")
            .from("Propaganda Office", title: "Communications Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "acknowledge",
                text: "ACKNOWLEDGE - Will update materials",
                shortDescription: "Acknowledged update",
                effects: [:]
            )
            .withDeadline(turnsFromNow: 4)
            .build()
    }

    private func generateLoyaltyPledgeReminder(for game: Game) -> DeskDocument {
        let body = """
        LOYALTY CERTIFICATION REMINDER

        Your annual Party Loyalty Certification is due for renewal.

        Requirements:
        - Complete Form PL-47
        - Obtain supervisor signature
        - Submit by deadline

        Failure to certify may affect performance reviews.
        """

        return DeskDocument.builder()
            .withTemplateId("loyalty_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Loyalty Certification Due")
            .from("Personnel Office", title: "Party Records")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "submit",
                text: "SUBMIT - Complete certification promptly",
                shortDescription: "Submitted certification",
                effects: ["standing": 5]
            )
            .addOption(
                id: "delay",
                text: "DELAY - Request extension",
                shortDescription: "Requested extension",
                effects: ["standing": -5]
            )
            .withDeadline(turnsFromNow: 2)
            .build()
    }

    private func generatePropagandaDirective(for game: Game) -> DeskDocument {
        let body = """
        PARTY DIRECTIVE #447
        IMMEDIATE IMPLEMENTATION REQUIRED

        Effective immediately, all educational materials must reflect the following corrections:

        1. References to General Henderson are to be REMOVED. His contributions are to be attributed to the collective leadership.

        2. Production figures for Year 42 are to be REVISED UPWARD per attached guidelines.

        Ensure all unit materials are updated within 72 hours.

        Report any personnel who express confusion or resistance.

        BY ORDER OF THE CENTRAL COMMITTEE
        """

        return DeskDocument.builder()
            .withTemplateId("directive_\(UUID().uuidString.prefix(6))")
            .ofType(.directive)
            .titled("Party Directive #447")
            .from("Central Propaganda Directorate", title: "Party Headquarters")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "comply",
                text: "COMPLY FULLY - Update all materials",
                shortDescription: "Complied with directive",
                effects: ["patronFavor": 5]
            )
            .addOption(
                id: "comply_slow",
                text: "COMPLY SLOWLY - Drag your feet",
                shortDescription: "Slow compliance",
                effects: [:]
            )
            .addOption(
                id: "warn_officers",
                text: "WARN YOUR PEOPLE - 'The truth changed again'",
                shortDescription: "Warned subordinates",
                effects: ["network": 5, "security": -5]
            )
            .withConsequenceIfIgnored(
                "Your section was noted for delayed implementation. Questions are being asked.",
                effects: ["patronFavor": -10, "security": -5]
            )
            .withDeadline(turnsFromNow: 2)
            .build()
    }

    // MARK: - Diplomatic Category Documents

    private func generateDiplomaticDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Diplomatic clearances reflect international exposure:
        // - Levels 1-2: Translation filing, visitor logs (clerical)
        // - Levels 3-4: Visa processing, cultural exchange coordination
        // - Levels 5-6: Embassy communications, ambassador cables
        // - Levels 7+: Treaty negotiations, international incidents
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateTranslationFiling),          // Level 1+ (routine clerical)
            (2, generateVisitorLogReview),           // Level 2+ (low-level security)
            (3, generateVisaApplicationReview),      // Level 3+ (minor decisions)
            (4, generateCulturalExchangeCoordination), // Level 4+ (inter-ministry)
            (5, generateEmbassyCable),               // Level 5+ (confidential comms)
            (6, generateDiplomaticIncidentReport)    // Level 6+ (sensitive matters)
        ]

        let available = templates.filter { $0.minClearance <= clearanceLevel }

        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            return generator(game)
        }

        return generateTranslationFiling(for: game)
    }

    /// Level 1+: Basic translation filing
    private func generateTranslationFiling(for game: Game) -> DeskDocument {
        let documents = [
            ("Trade Circular #127", "French", "Commercial Division"),
            ("Technical Manual Excerpt", "German", "Industrial Bureau"),
            ("Agricultural Report Summary", "English", "Ministry of Agriculture"),
            ("Cultural Bulletin", "Italian", "Propaganda Office")
        ]

        let (docName, language, requestor) = documents.randomElement()!

        let body = """
        TRANSLATION REQUEST FILING

        Document: \(docName)
        Source Language: \(language)
        Requesting Office: \(requestor)

        The attached document has been translated per standard protocol. Please verify the filing code and forward to the requesting department.

        Translator notes: "Standard commercial language. No unusual terminology detected."

        SIGN TO CONFIRM FILING COMPLETE.
        """

        return DeskDocument.builder()
            .withTemplateId("translation_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Translation Filing: \(docName)")
            .from("Translation Bureau", title: "Foreign Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.diplomatic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "file",
                text: "FILE - Standard processing",
                shortDescription: "Filed translation",
                effects: [:]
            )
            .addOption(
                id: "flag",
                text: "FLAG FOR REVIEW - Request original",
                shortDescription: "Flagged for review",
                effects: ["security": 1]
            )
            .build()
    }

    /// Level 2+: Visitor log verification
    private func generateVisitorLogReview(for game: Game) -> DeskDocument {
        let visitors = [
            ("Dr. Hans Mueller", "Austrian Trade Delegation", "3 days"),
            ("Mr. James Crawford", "British Cultural Attaché Office", "1 week"),
            ("Mme. Isabelle Dupont", "French Academic Exchange", "5 days")
        ]

        let (name, affiliation, duration) = visitors.randomElement()!

        let body = """
        FOREIGN VISITOR LOG - VERIFICATION REQUIRED

        Visitor: \(name)
        Affiliation: \(affiliation)
        Duration of Visit: \(duration)
        Host Department: Cultural Affairs

        The visitor access log requires your verification signature before archiving. Standard security notation indicates no unusual activity during the visit.

        Building Security notes: "Visitor adhered to designated areas. No protocol violations observed."

        VERIFY AND SIGN FOR RECORDS.
        """

        return DeskDocument.builder()
            .withTemplateId("visitor_log_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Visitor Log: \(name)")
            .from("Building Security", title: "Foreign Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.diplomatic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "verify",
                text: "VERIFY - Sign for archiving",
                shortDescription: "Verified visitor log",
                effects: [:]
            )
            .addOption(
                id: "request_detail",
                text: "REQUEST DETAIL - Who approved extended access?",
                shortDescription: "Questioned access",
                effects: ["security": 2]
            )
            .build()
    }

    /// Level 3+: Visa application processing
    private func generateVisaApplicationReview(for game: Game) -> DeskDocument {
        let applicants = [
            ("Prof. Erik Lindqvist", "Sweden", "Academic exchange program"),
            ("Mr. Antonio Silva", "Portugal", "Trade delegation member"),
            ("Ms. Maria Kowalczyk", "Poland (emigre)", "Family reunification claim")
        ]

        let (name, nationality, purpose) = applicants.randomElement()!

        let body = """
        VISA APPLICATION REVIEW

        Applicant: \(name)
        Nationality: \(nationality)
        Purpose of Visit: \(purpose)

        Background Check: CLEARED (Standard)
        Sponsoring Department: Ministry of Foreign Affairs

        Application has passed initial screening. Your authorization is required for final processing.

        Case Officer notes: "Standard application. No flags in our records."

        AUTHORIZE / DENY / REQUEST ADDITIONAL REVIEW
        """

        return DeskDocument.builder()
            .withTemplateId("visa_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Visa Application: \(name)")
            .from("Visa Processing Office", title: "Foreign Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.diplomatic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "authorize",
                text: "AUTHORIZE - Approve visa",
                shortDescription: "Approved visa",
                effects: ["diplomatic": 2]
            )
            .addOption(
                id: "deny",
                text: "DENY - Insufficient justification",
                shortDescription: "Denied visa",
                effects: ["security": 2, "diplomatic": -2]
            )
            .addOption(
                id: "additional_review",
                text: "ADDITIONAL REVIEW - Request security check",
                shortDescription: "Requested security review",
                effects: ["security": 3]
            )
            .build()
    }

    /// Level 4+: Cultural exchange program coordination
    private func generateCulturalExchangeCoordination(for game: Game) -> DeskDocument {
        let programs = [
            ("Youth Orchestra Exchange", "Vienna", "Austrian Cultural Ministry"),
            ("Technical Student Program", "Dresden", "Technical University"),
            ("Athletic Delegation Visit", "Prague", "Sports Committee")
        ]

        let (program, city, partner) = programs.randomElement()!

        // Generate participant lists - 23 cleared, 2 pending
        let clearedNames = generateNameList(count: 23, includeUnits: false)
        let pendingNames = generateNameList(count: 2, includeUnits: false)

        let clearedList = formatNameListAsAttachment(names: clearedNames, title: "Cleared Participants")
        let pendingSection = """

        ═══════════════════════════════════════════
        PENDING SECURITY CLEARANCE
        ═══════════════════════════════════════════

         1. \(pendingNames[0]) - AWAITING REVIEW
         2. \(pendingNames[1]) - AWAITING REVIEW

        ───────────────────────────────────────────
        """

        let body = """
        INTER-MINISTRY COORDINATION REQUEST

        Program: \(program)
        Destination: \(city)
        Partner Organization: \(partner)

        The Cultural Affairs Division requests your coordination signature for the upcoming exchange program. Multiple ministries must approve participation lists.

        Security has cleared 23 of 25 proposed participants. Two individuals require additional background verification.

        Question: Should we proceed with 23 participants or delay until all 25 are cleared?

        Deadline for partner notification: 5 days

        AWAITING YOUR DECISION.
        \(clearedList)
        \(pendingSection)
        """

        return DeskDocument.builder()
            .withTemplateId("exchange_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Exchange Program: \(program)")
            .from("Cultural Affairs Division", title: "Foreign Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.diplomatic)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "proceed_23",
                text: "PROCEED - 23 participants, meet deadline",
                shortDescription: "Approved partial list",
                effects: ["diplomatic": 5]
            )
            .addOption(
                id: "delay",
                text: "DELAY - Wait for full clearance",
                shortDescription: "Delayed for clearances",
                effects: ["security": 3, "diplomatic": -3]
            )
            .addOption(
                id: "replace",
                text: "REPLACE - Find alternate participants",
                shortDescription: "Replaced unclear participants",
                effects: ["diplomatic": 3]
            )
            .build()
    }

    /// Level 5+: Embassy cable (the original diplomatic template)
    private func generateEmbassyCable(for game: Game) -> DeskDocument {
        let embassies = [
            ("London", "Ambassador Mitchell", "British academics propose cultural symposium"),
            ("Paris", "Ambassador Rousseau", "French trade delegation requests expanded access"),
            ("Vienna", "Ambassador Hartmann", "Austrian officials suggest bilateral talks")
        ]

        let (city, ambassador, topic) = embassies.randomElement()!

        let body = """
        DECODED CABLE - CONFIDENTIAL
        FROM: Embassy, \(city)

        \(topic) on "shared European heritage."

        Initial assessment: Key foreign participants may have intelligence connections.

        However, the proposal provides opportunities:
        1. Propaganda value
        2. Intelligence gathering
        3. Potential recruitment

        Risk: Defection opportunities for our delegates.

        RECOMMENDATION: Participate with carefully selected delegation.

        AWAITING GUIDANCE.
        """

        return DeskDocument.builder()
            .withTemplateId("cable_\(UUID().uuidString.prefix(6))")
            .ofType(.cable)
            .titled("Embassy Cable: \(city)")
            .from(ambassador, title: "\(city) Embassy")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.diplomatic)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Send delegation",
                shortDescription: "Approved delegation",
                effects: ["diplomatic": 10, "security": -5]
            )
            .addOption(
                id: "approve_conditions",
                text: "APPROVE WITH CONDITIONS - Security escort",
                shortDescription: "Approved with conditions",
                effects: ["diplomatic": 5]
            )
            .addOption(
                id: "decline_politely",
                text: "DECLINE POLITELY - 'Scheduling conflicts'",
                shortDescription: "Politely declined",
                effects: ["diplomatic": -5]
            )
            .addOption(
                id: "counter",
                text: "COUNTER-PROPOSE - Hold it here instead",
                shortDescription: "Counter-proposed",
                effects: ["diplomatic": 5, "treasury": -30]
            )
            .build()
    }

    /// Level 6+: Diplomatic incident requiring senior attention
    private func generateDiplomaticIncidentReport(for game: Game) -> DeskDocument {
        let authority = AuthorityLanguage(game: game)

        let incidents = [
            ("Embassy staff detained briefly at border", "Western authorities", "claimed 'document irregularities'"),
            ("Diplomatic pouch delayed", "Foreign customs", "unprecedented 'inspection request'"),
            ("Trade attaché expelled", "Host government", "alleged 'activities incompatible with status'")
        ]

        let (incident, actor, detail) = incidents.randomElement()!

        let body = """
        DIPLOMATIC INCIDENT REPORT - URGENT
        CLASSIFICATION: SECRET

        INCIDENT: \(incident)
        FOREIGN ACTOR: \(actor)
        STATED REASON: \(detail)

        Our embassy has lodged a formal protest. The foreign ministry has not yet responded.

        Assessment: This may be an isolated incident or part of a broader pattern of provocations.

        Options:
        1. Measured response - formal protest only
        2. Proportional response - similar action against their personnel
        3. Escalation - summon their ambassador for explanation

        \(authority.approvalChain)
        """

        let escalateText = authority.isPolitburoMember ? "ESCALATE - Summon their ambassador" : "RECOMMEND ESCALATION"

        return DeskDocument.builder()
            .withTemplateId("incident_\(UUID().uuidString.prefix(6))")
            .ofType(.intelligence)
            .titled("Diplomatic Incident Report")
            .from("Foreign Ministry", title: "Crisis Desk")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.diplomatic)
            .classified(as: "SECRET")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "measured",
                text: "MEASURED RESPONSE - Formal protest only",
                shortDescription: "Lodged formal protest",
                effects: ["diplomatic": -5]
            )
            .addOption(
                id: "proportional",
                text: "PROPORTIONAL - Mirror their action",
                shortDescription: "Proportional response",
                effects: ["diplomatic": -10, "security": 5]
            )
            .addOption(
                id: "escalate",
                text: escalateText,
                shortDescription: "Escalated incident",
                effects: ["diplomatic": -15, "patronFavor": 5],
                setsFlag: "escalated_diplomatic_incident"
            )
            .build()
    }

    // MARK: - Personnel Category Documents

    private func generatePersonnelDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // DEBUG: Log clearance level
        documentLog.info("📋 [Personnel] Position Index: \(game.currentPositionIndex), Clearance Level: \(clearanceLevel)")

        // Personnel clearances reflect administrative scope:
        // - Levels 1-2: Leave requests, timesheet verification
        // - Levels 3-4: Minor transfers, training assignments
        // - Levels 5+: Senior appointments, politically sensitive transfers
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (1, generateLeaveRequestFiling),         // Level 1+ (routine admin)
            (1, generateTimesheetVerification),      // Level 1+ (basic clerical)
            (2, generateTrainingAssignment),         // Level 2+ (minor decisions)
            (3, generateMinorTransferRequest),       // Level 3+ (standard transfers)
            (4, generateSeniorTransferRequest),      // Level 4+ (sensitive transfers)
            (5, generateNepotismTransferRequest)     // Level 5+ (politically charged)
        ]

        let available = templates.filter { $0.minClearance <= clearanceLevel }

        // DEBUG: Log available templates with their clearance requirements
        let availableClearances = available.map { $0.minClearance }
        documentLog.info("📋 [Personnel] Available templates: \(availableClearances.count) with clearances: \(availableClearances)")

        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            let doc = generator(game)
            documentLog.info("📋 [Personnel] Generated document: \(doc.title)")
            return doc
        }

        return generateLeaveRequestFiling(for: game)
    }

    /// Level 1+: Basic leave request filing
    private func generateLeaveRequestFiling(for game: Game) -> DeskDocument {
        let employees = [
            ("Comrade Petrov", "Filing Clerk", "2 days"),
            ("Comrade Ivanova", "Typist Pool", "1 week"),
            ("Comrade Sokolov", "Mail Room", "3 days")
        ]

        let (name, department, duration) = employees.randomElement()!
        let reason = ["family matter", "medical appointment", "personal business"].randomElement()!

        let body = """
        LEAVE REQUEST - ADMINISTRATIVE FILING

        Employee: \(name)
        Department: \(department)
        Requested Duration: \(duration)
        Reason: \(reason.capitalized)

        Supervisor has approved this request. Your signature is required for central records.

        Note: Employee has sufficient leave balance.

        SIGN TO FILE IN CENTRAL RECORDS.
        """

        return DeskDocument.builder()
            .withTemplateId("leave_\(UUID().uuidString.prefix(6))")
            .ofType(.memo)
            .titled("Leave Request: \(name)")
            .from("Personnel Records", title: "Central Administration")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "file",
                text: "FILE - Process normally",
                shortDescription: "Filed leave request",
                effects: [:]
            )
            .addOption(
                id: "verify",
                text: "VERIFY - Check leave balance first",
                shortDescription: "Requested verification",
                effects: [:],
                triggersDocument: "verification_leave_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            )
            .build()
    }

    /// Level 1+: Timesheet verification
    private func generateTimesheetVerification(for game: Game) -> DeskDocument {
        let departments = [
            ("Records Division", 47, 2115),
            ("Typing Pool", 23, 1035),
            ("Mail Services", 12, 540)
        ]

        let (dept, employeeCount, totalHours) = departments.randomElement()!

        // Generate employee timesheet summary
        let employeeNames = generateNameList(count: min(employeeCount, 15), includeUnits: false) // Show up to 15 for readability
        var timesheetEntries: [String] = []
        var runningTotal = 0

        for (index, name) in employeeNames.enumerated() {
            let standardHours = 45
            let overtime = index % 4 == 0 ? Int.random(in: 2...8) : 0 // Some have overtime
            let hours = standardHours + overtime
            runningTotal += hours
            let overtimeNote = overtime > 0 ? " (+\(overtime) OT)" : ""
            timesheetEntries.append("\(String(format: "%2d", index + 1)). \(name): \(hours) hrs\(overtimeNote)")
        }

        let timesheetSummary = """

        ═══════════════════════════════════════════
        ATTACHMENT: TIMESHEET SUMMARY (SAMPLE)
        ═══════════════════════════════════════════

        \(timesheetEntries.joined(separator: "\n"))
        \(employeeCount > 15 ? "\n        ... and \(employeeCount - 15) additional employees" : "")

        ───────────────────────────────────────────
        Sample Total: \(runningTotal) hrs | Full Dept: \(totalHours) hrs
        """

        let body = """
        MONTHLY TIMESHEET VERIFICATION

        Department: \(dept)
        Employees: \(employeeCount) employees
        Total Hours Logged: \(totalHours) hours

        The attached timesheet summary requires your verification before payroll processing. Standard procedure requires checking that:

        1. Total hours match expected work days
        2. Overtime is properly authorized
        3. Absences are documented

        Payroll Office notes: "All figures appear in order."

        SIGN TO APPROVE FOR PAYROLL.
        \(timesheetSummary)
        """

        return DeskDocument.builder()
            .withTemplateId("timesheet_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Timesheet: \(dept)")
            .from("Payroll Office", title: "Central Administration")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Forward to payroll",
                shortDescription: "Approved timesheets",
                effects: [:]
            )
            .addOption(
                id: "audit",
                text: "REQUEST AUDIT - Check overtime hours",
                shortDescription: "Requested overtime audit",
                effects: ["security": 1]
            )
            .build()
    }

    /// Level 2+: Training program assignment
    private func generateTrainingAssignment(for game: Game) -> DeskDocument {
        let programs = [
            ("Industrial Safety Certification", "Factory Supervisors", "3 days"),
            ("Administrative Procedures Update", "Office Staff", "1 day"),
            ("Ideological Education Seminar", "All Personnel", "2 days")
        ]

        let (program, target, duration) = programs.randomElement()!
        let slots = Int.random(in: 15...30)

        // Generate actual participant names
        let participantNames = generateNameList(count: slots, includeUnits: true)
        let participantList = formatNameListAsAttachment(names: participantNames, title: "Nominated Participants")

        let body = """
        TRAINING PROGRAM ASSIGNMENT

        Program: \(program)
        Target Group: \(target)
        Duration: \(duration)
        Available Slots: \(slots)

        The Personnel Development Office requests your approval for the attached list of \(slots) participants.

        All nominees have been cleared by their supervisors. Training budget has been allocated.

        Note: Ideological content has been approved by the Party Education Committee.

        APPROVE LIST / REQUEST MODIFICATIONS
        \(participantList)
        """

        return DeskDocument.builder()
            .withTemplateId("training_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Training: \(program)")
            .from("Personnel Development", title: "Training Office")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Proceed with listed participants",
                shortDescription: "Approved training list",
                effects: [:]
            )
            .addOption(
                id: "modify",
                text: "MODIFY - Substitute certain individuals",
                shortDescription: "Modified participant list",
                effects: [:]
            )
            .addOption(
                id: "expand",
                text: "EXPAND - Request additional slots",
                shortDescription: "Requested expansion",
                effects: ["treasury": -10]
            )
            .build()
    }

    /// Level 3+: Standard transfer request
    private func generateMinorTransferRequest(for game: Game) -> DeskDocument {
        let clearance = min(game.currentPositionIndex + 1, 8)

        // FAILSAFE: This requires clearance 3+
        if clearance < 3 {
            documentLog.error("🚨 [MinorTransfer] FAILSAFE - Redirecting at clearance \(clearance)")
            return generateLeaveRequestFiling(for: game)
        }

        let transfers = [
            ("Sgt. Viktor Orlov", "Guard Post 7", "Administrative Pool", "personal request"),
            ("Clerk Maria Volkov", "Records Office", "Personnel Division", "efficiency improvement"),
            ("Tech. Dmitri Kozlov", "Maintenance Unit", "Motor Pool", "skill utilization")
        ]

        let (name, from, to, reason) = transfers.randomElement()!

        let body = """
        PERSONNEL TRANSFER REQUEST

        Subject: \(name)
        Current Assignment: \(from)
        Requested Assignment: \(to)
        Reason: \(reason.capitalized)

        Both sending and receiving units have approved this transfer. Your authorization is required for inter-departmental moves.

        Performance Review: Satisfactory
        Security Status: Cleared

        APPROVE / DENY / DEFER
        """

        return DeskDocument.builder()
            .withTemplateId("transfer_minor_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Transfer: \(name)")
            .from("Personnel Division", title: "Central Administration")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Standard transfer",
                shortDescription: "Approved transfer",
                effects: [:]
            )
            .addOption(
                id: "deny",
                text: "DENY - Current position essential",
                shortDescription: "Denied transfer",
                effects: [:]
            )
            .addOption(
                id: "defer",
                text: "DEFER - Request justification",
                shortDescription: "Deferred decision",
                effects: [:]
            )
            .build()
    }

    /// Level 4+: Senior or sensitive transfer
    private func generateSeniorTransferRequest(for game: Game) -> DeskDocument {
        let clearance = min(game.currentPositionIndex + 1, 8)

        // FAILSAFE: This requires clearance 4+
        if clearance < 4 {
            documentLog.error("🚨 [SeniorTransfer] FAILSAFE - Redirecting at clearance \(clearance)")
            return generateLeaveRequestFiling(for: game)
        }

        let transfers = [
            ("Lt. Col. Nikolai Petrov", "Regional Command", "General Staff", "merit-based advancement"),
            ("Director Elena Mikhailova", "Industrial Bureau", "Planning Commission", "restructuring"),
            ("Commissar Alexei Volkov", "District Party Office", "Central Committee Staff", "career development")
        ]

        let (name, from, to, reason) = transfers.randomElement()!

        let body = """
        SENIOR PERSONNEL TRANSFER REQUEST
        CLASSIFICATION: CONFIDENTIAL

        Subject: \(name)
        Current Assignment: \(from)
        Requested Assignment: \(to)
        Stated Reason: \(reason.capitalized)

        This transfer involves senior personnel and requires additional scrutiny.

        Background notes:
        - Subject has 15 years of service
        - Performance consistently rated "Excellent"
        - No security concerns on record

        However: The receiving unit already has full staffing. This transfer would create redundancy.

        YOUR DECISION WILL BE NOTED.
        """

        return DeskDocument.builder()
            .withTemplateId("transfer_senior_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Senior Transfer: \(name)")
            .from("Senior Personnel Office", title: "Central Administration")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.personnel)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - Merit warrants position",
                shortDescription: "Approved senior transfer",
                effects: ["patronFavor": 5]
            )
            .addOption(
                id: "deny",
                text: "DENY - No vacancy exists",
                shortDescription: "Denied on staffing grounds",
                effects: [:]
            )
            .addOption(
                id: "create_position",
                text: "CREATE POSITION - Approve with new slot",
                shortDescription: "Created new position",
                effects: ["treasury": -20, "patronFavor": 10]
            )
            .build()
    }

    /// Level 5+: Politically sensitive transfer (nepotism case)
    private func generateNepotismTransferRequest(for game: Game) -> DeskDocument {
        let clearance = min(game.currentPositionIndex + 1, 8)

        // CRITICAL: This should ONLY be called for clearance level 5+
        documentLog.error("🚨 [NEPOTISM] Called! Position Index: \(game.currentPositionIndex), Clearance: \(clearance)")

        // Assert in debug builds to catch this issue
        assert(clearance >= 5, "NEPOTISM document generated at clearance \(clearance) - should only appear at 5+")

        // FAILSAFE: If somehow called at wrong clearance, generate a simple leave request instead
        if clearance < 5 {
            documentLog.error("🚨 [NEPOTISM] FAILSAFE TRIGGERED - Redirecting to leave request at clearance \(clearance)")
            return generateLeaveRequestFiling(for: game)
        }

        let body = """
        PERSONNEL TRANSFER REQUEST
        CLASSIFICATION: CONFIDENTIAL

        Subject: Captain Anna Wallace
        Current Assignment: 3rd Artillery Battalion
        Requested Assignment: Defense Ministry, Strategic Planning

        Qualifications: Top of class, excellent performance reviews, speaks three languages.

        Notes: Captain Wallace is the niece of General Wallace. The General has made no formal request but has "mentioned" her talents in conversation.

        Your recommendation will be given significant weight.

        APPROVE / DENY / DEFER
        """

        return DeskDocument.builder()
            .withTemplateId("transfer_nepotism_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Transfer Request: Capt. Wallace")
            .from("Personnel Division", title: "Defense Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)
            .withFootnote("The General has never asked directly. But he knows this is on your desk.")
            .requiresDecision(true)
            .addOption(
                id: "approve",
                text: "APPROVE - She's qualified",
                shortDescription: "Approved transfer",
                effects: ["patronFavor": 10]
            )
            .addOption(
                id: "deny",
                text: "DENY - Needed in current role",
                shortDescription: "Denied transfer",
                effects: ["patronFavor": -15, "military": 5]
            )
            .addOption(
                id: "defer",
                text: "DEFER - Request more information",
                shortDescription: "Deferred decision",
                effects: [:]
            )
            .build()
    }

    // MARK: - Crisis Category Documents

    private func generateCrisisDocument(for game: Game) -> DeskDocument {
        let clearanceLevel = min(game.currentPositionIndex + 1, 8)

        // Crisis clearances reflect scope of authority:
        // Note: Category-level filtering already prevents crisis < Level 3
        // - Level 3: Minor incidents (equipment failures, supply issues)
        // - Level 4: Local disturbances (small protests, workplace disputes)
        // - Level 5+: Major crises (strikes, regional unrest, sabotage)
        let templates: [(minClearance: Int, generator: (Game) -> DeskDocument)] = [
            (3, generateEquipmentFailureCrisis),     // Level 3+ (facility incident)
            (3, generateSupplyDisruptionCrisis),     // Level 3+ (logistical crisis)
            (4, generateLocalDisturbanceCrisis),     // Level 4+ (minor unrest)
            (5, generateWorkerStrikeCrisis),         // Level 5+ (major labor crisis)
            (6, generateRegionalUnrestCrisis)        // Level 6+ (widespread unrest)
        ]

        let available = templates.filter { $0.minClearance <= clearanceLevel }

        let weighted = available.flatMap { template -> [(Game) -> DeskDocument] in
            let weight = max(1, 3 - (clearanceLevel - template.minClearance))
            return Array(repeating: template.generator, count: weight)
        }

        if let generator = weighted.randomElement() {
            return generator(game)
        }

        return generateEquipmentFailureCrisis(for: game)
    }

    /// Level 3+: Equipment failure requiring immediate action
    private func generateEquipmentFailureCrisis(for game: Game) -> DeskDocument {
        let incidents = [
            ("Boiler explosion", "Heating Plant #12", "3 workers injured"),
            ("Power generator failure", "Factory District 7", "production halted"),
            ("Crane collapse", "Construction Site 4", "1 fatality, 2 injured")
        ]

        let (incident, location, casualties) = incidents.randomElement()!

        let body = """
        URGENT INCIDENT REPORT

        INCIDENT: \(incident)
        LOCATION: \(location)
        CASUALTIES: \(casualties)

        Emergency services have responded. The immediate danger is contained.

        However, an investigation must be initiated. Options:

        1. Internal review - handled quietly by the facility
        2. Safety committee investigation - formal but controlled
        3. Full external audit - thorough but may uncover other issues

        Note: The facility manager is requesting guidance before speaking to workers.

        RESPONSE REQUIRED WITHIN 24 HOURS.
        """

        return DeskDocument.builder()
            .withTemplateId("crisis_equipment_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("URGENT: \(incident)")
            .from("Facility Manager", title: location)
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.crisis)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "internal",
                text: "INTERNAL REVIEW - Handle quietly",
                shortDescription: "Ordered internal review",
                effects: ["security": 5, "stability": -5]
            )
            .addOption(
                id: "committee",
                text: "SAFETY COMMITTEE - Formal investigation",
                shortDescription: "Ordered committee review",
                effects: ["stability": 5]
            )
            .addOption(
                id: "audit",
                text: "FULL AUDIT - External investigation",
                shortDescription: "Ordered external audit",
                effects: ["stability": 10, "treasury": -15],
                setsFlag: "ordered_safety_audit"
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    /// Level 3+: Supply chain disruption
    private func generateSupplyDisruptionCrisis(for game: Game) -> DeskDocument {
        let disruptions = [
            ("Coal shipment delayed", "Power Station 3", "48-hour reserves remaining"),
            ("Food distribution breakdown", "District 14", "delivery trucks unavailable"),
            ("Medical supplies shortage", "Regional Hospital", "critical medications low")
        ]

        let (issue, location, impact) = disruptions.randomElement()!

        let body = """
        SUPPLY EMERGENCY - URGENT

        ISSUE: \(issue)
        AFFECTED: \(location)
        IMPACT: \(impact)

        The situation requires immediate action to prevent escalation.

        Options:
        1. Emergency reallocation from other facilities
        2. Priority transport requisition (costly)
        3. Rationing protocol until normal supply resumes

        Local officials are awaiting your guidance.

        TIME-SENSITIVE MATTER.
        """

        return DeskDocument.builder()
            .withTemplateId("crisis_supply_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("SUPPLY EMERGENCY: \(issue)")
            .from("Logistics Office", title: "Supply Command")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.urgent)
            .inCategory(.crisis)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "reallocate",
                text: "REALLOCATE - Draw from other facilities",
                shortDescription: "Reallocated supplies",
                effects: ["stability": 5]
            )
            .addOption(
                id: "priority",
                text: "PRIORITY TRANSPORT - Emergency requisition",
                shortDescription: "Emergency transport ordered",
                effects: ["treasury": -25, "stability": 10]
            )
            .addOption(
                id: "ration",
                text: "RATIONING - Temporary reduction",
                shortDescription: "Implemented rationing",
                effects: ["stability": -10, "treasury": 10]
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    /// Level 4+: Local disturbance
    private func generateLocalDisturbanceCrisis(for game: Game) -> DeskDocument {
        let disturbances = [
            ("Workers demanding overtime pay", "Textile Factory #23", "50 workers"),
            ("Students protesting cafeteria conditions", "Technical Institute", "100 students"),
            ("Residents complaining about water quality", "Housing Block 7", "200 residents")
        ]

        let (issue, location, scale) = disturbances.randomElement()!

        let body = """
        DISTURBANCE REPORT - PRIORITY

        ISSUE: \(issue)
        LOCATION: \(location)
        SCALE: Approximately \(scale) involved

        The situation is currently contained but could escalate. Local Party officials have requested guidance.

        Assessment: This appears to be a legitimate grievance, not politically motivated. However, unaddressed complaints can attract unwanted attention.

        Options:
        1. Address grievance directly (may set precedent)
        2. Disperse and investigate later
        3. Refer to appropriate ministry

        AWAITING YOUR DECISION.
        """

        return DeskDocument.builder()
            .withTemplateId("crisis_local_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("DISTURBANCE: \(location)")
            .from("Local Party Secretary", title: "District Office")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.crisis)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "address",
                text: "ADDRESS GRIEVANCE - Meet their concerns",
                shortDescription: "Addressed complaints",
                effects: ["stability": 10, "treasury": -20]
            )
            .addOption(
                id: "disperse",
                text: "DISPERSE - Order them back to work",
                shortDescription: "Ordered dispersal",
                effects: ["stability": -5, "security": 5]
            )
            .addOption(
                id: "refer",
                text: "REFER - Pass to relevant ministry",
                shortDescription: "Referred to ministry",
                effects: [:]
            )
            .withDeadline(turnsFromNow: 2)
            .build()
    }

    /// Level 5+: Major worker strike (original crisis template)
    private func generateWorkerStrikeCrisis(for game: Game) -> DeskDocument {
        let authority = AuthorityLanguage(game: game)

        let militaryLine = authority.isTopLeadership ?
            "Military units are on standby awaiting your orders." :
            authority.isPolitburoMember ?
            "Military units are on standby. Your recommendation will be forwarded to the General Secretary." :
            "Military units are on standby pending senior leadership decision. Your assessment is requested."

        let body = """
        CRISIS ALERT - IMMEDIATE

        Workers at Steel Mill #7 have stopped production. They are demanding:
        1. Increased rations
        2. Reduced quotas
        3. Investigation of safety conditions

        Local Party secretary reports "counter-revolutionary elements" may be involved.

        Situation is contained for now but spreading to neighboring factories.

        \(militaryLine)

        TIME IS CRITICAL.

        \(authority.approvalChain)
        """

        let suppressText = authority.isTopLeadership ? "SUPPRESS - Send in the military" :
                          authority.isPolitburoMember ? "RECOMMEND SUPPRESSION - Forward to General Secretary" :
                          "RECOMMEND FORCE - Escalate to Politburo"
        let suppressDesc = authority.isTopLeadership ? "Ordered military suppression" :
                          "Recommended military suppression"

        return DeskDocument.builder()
            .withTemplateId("crisis_strike_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("CRISIS: Worker Unrest - Steel Mill #7")
            .from("Regional Command", title: "Crisis Center")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.critical)
            .inCategory(.crisis)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "negotiate",
                text: authority.isTopLeadership ? "NEGOTIATE - Meet their demands partially" : "RECOMMEND NEGOTIATION",
                shortDescription: authority.isTopLeadership ? "Negotiated with workers" : "Recommended negotiation",
                effects: ["stability": 10, "treasury": -30, "patronFavor": -10]
            )
            .addOption(
                id: "suppress",
                text: suppressText,
                shortDescription: suppressDesc,
                effects: ["stability": -20, "security": 15],
                setsFlag: "suppressed_workers"
            )
            .addOption(
                id: "investigate",
                text: "INVESTIGATE 'ELEMENTS' - Find the ringleaders",
                shortDescription: "Investigated ringleaders",
                effects: ["security": 10, "stability": -5]
            )
            .addOption(
                id: "concede",
                text: authority.isTopLeadership ? "CONCEDE ALL DEMANDS - End this now" : "RECOMMEND FULL CONCESSION",
                shortDescription: authority.isTopLeadership ? "Full concession" : "Recommended full concession",
                effects: ["stability": 20, "treasury": -50, "patronFavor": -20]
            )
            .withConsequenceIfIgnored(
                "The strike spread to three more factories. The situation is now out of control.",
                effects: ["stability": -30, "patronFavor": -20]
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    /// Level 6+: Regional unrest requiring high-level intervention
    private func generateRegionalUnrestCrisis(for game: Game) -> DeskDocument {
        let authority = AuthorityLanguage(game: game)

        let body = """
        CRISIS ALERT - CRITICAL
        CLASSIFICATION: SECRET

        Multiple districts are reporting coordinated unrest. The pattern suggests organization beyond local grievances.

        AFFECTED AREAS:
        - Industrial District 4: Production stopped
        - Mining Region 7: Work slowdown
        - Agricultural Collective 12: Refusing quotas

        Intelligence suggests:
        1. Possible external coordination
        2. Underground pamphlets circulating
        3. Former political prisoners may be involved

        Regional security forces are overstretched. National resources may be required.

        \(authority.approvalChain)

        THIS REQUIRES IMMEDIATE HIGH-LEVEL ATTENTION.
        """

        let crackdownText = authority.isTopLeadership ? "AUTHORIZE CRACKDOWN - National security response" :
                           "RECOMMEND CRACKDOWN - Forward to leadership"

        return DeskDocument.builder()
            .withTemplateId("crisis_regional_\(UUID().uuidString.prefix(6))")
            .ofType(.intelligence)
            .titled("CRISIS: Regional Unrest")
            .from("State Security", title: "Emergency Operations")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.critical)
            .inCategory(.crisis)
            .classified(as: "SECRET")
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "crackdown",
                text: crackdownText,
                shortDescription: "Authorized regional crackdown",
                effects: ["stability": -30, "security": 25],
                setsFlag: "regional_crackdown"
            )
            .addOption(
                id: "targeted",
                text: "TARGETED RESPONSE - Arrest organizers only",
                shortDescription: "Targeted arrests",
                effects: ["stability": -10, "security": 15]
            )
            .addOption(
                id: "concessions",
                text: "EMERGENCY CONCESSIONS - Address root causes",
                shortDescription: "Made emergency concessions",
                effects: ["stability": 15, "treasury": -75, "patronFavor": -25]
            )
            .addOption(
                id: "negotiate_leaders",
                text: "NEGOTIATE - Talk to the organizers",
                shortDescription: "Opened negotiations",
                effects: ["stability": 5, "security": -15],
                setsFlag: "negotiated_with_dissidents"
            )
            .withConsequenceIfIgnored(
                "The regional unrest has spread to the capital. The government's authority is openly questioned.",
                effects: ["stability": -50, "patronFavor": -30]
            )
            .withDeadline(turnsFromNow: 1)
            .build()
    }

    private func generatePersonalDocument(for game: Game) -> DeskDocument {
        let body = """
        [HANDWRITTEN NOTE, slipped under your door]

        Comrade,

        We've never spoken, but I've watched your career. You seem... different from the others. More thoughtful.

        I have information. About the Minister. Things he's done. Things that would interest certain people.

        I'm not asking for money. I'm asking for protection. For my family.

        If you're interested, leave your office light on tonight after 8pm. I'll find a way to contact you again.

        If you're not interested, burn this note and forget you ever saw it.

        - A Friend
        """

        return DeskDocument.builder()
            .withTemplateId("anonymous_\(UUID().uuidString.prefix(6))")
            .ofType(.personalNote)
            .titled("Anonymous Note")
            .from("Unknown", title: nil)
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personal)
            .withBody(body)
            .requiresDecision(true)
            .addOption(
                id: "signal_yes",
                text: "LEAVE LIGHT ON - You're interested",
                shortDescription: "Signaled interest",
                effects: ["network": 10, "security": -10],
                setsFlag: "contacted_informant"
            )
            .addOption(
                id: "burn",
                text: "BURN IT - Too dangerous",
                shortDescription: "Burned the note",
                effects: [:]
            )
            .addOption(
                id: "report",
                text: "REPORT TO SECURITY - This could be a test",
                shortDescription: "Reported to security",
                effects: ["security": 5, "network": -10]
            )
            .build()
    }

    // MARK: - Document Processing

    /// Public method to check and process expired documents
    func checkExpiredDocuments(game: Game) {
        processExpiredDocuments(game: game)
    }

    /// Process documents that have passed their deadline
    private func processExpiredDocuments(game: Game) {
        let activeDocuments = getActiveDocuments(for: game)

        for document in activeDocuments {
            if document.isExpired(currentTurn: game.turnNumber) {
                document.expire()

                // Apply consequences
                if let effects = document.consequenceEffects {
                    for (stat, change) in effects {
                        game.applyStat(stat, change: change)
                    }
                }

                // Log the expiration
                if let consequence = document.consequenceIfIgnored {
                    let event = GameEvent(
                        turnNumber: game.turnNumber,
                        eventType: .narrative,
                        summary: "Document expired: \(document.title)"
                    )
                    event.fullBriefing = consequence
                    event.importance = document.urgencyEnum == .critical ? 8 : 5
                    event.game = game
                    game.events.append(event)
                }
            }
        }
    }

    /// Auto-file old routine documents when queue is full
    private func autoFileOldDocuments(game: Game) {
        let routineDocuments = getActiveDocuments(for: game)
            .filter { $0.urgencyEnum == .routine && $0.statusEnum == .read }
            .sorted { $0.turnReceived < $1.turnReceived }

        // File the oldest routine documents
        for document in routineDocuments.prefix(2) {
            document.file()
        }
    }

    // MARK: - Document Actions

    /// Handle player selecting an option on a document
    func selectOption(document: DeskDocument, optionId: String, game: Game) -> DocumentOption? {
        guard let option = document.options.first(where: { $0.id == optionId }) else {
            return nil
        }

        // Apply effects
        for (stat, change) in option.effects {
            game.applyStat(stat, change: change)
        }

        // Set/remove flags
        if let flag = option.setsFlag {
            if !game.flags.contains(flag) {
                game.flags.append(flag)
            }
        }
        if let flag = option.removesFlag {
            game.flags.removeAll { $0 == flag }
        }

        // Record the decision
        document.recordDecision(optionId: optionId, turn: game.turnNumber)

        // Log the decision
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .decision,
            summary: option.shortDescription
        )
        event.decisionContext = document.title
        event.optionChosen = option.shortDescription
        event.game = game
        game.events.append(event)

        // Handle character reactions
        if let reaction = option.characterReaction {
            handleCharacterReaction(reaction, game: game)
        }

        // Trigger follow-up documents
        if let triggerId = option.triggersDocument {
            // Queue follow-up document for future generation
            // Store the parent document ID and chain context for narrative continuity
            let queueKey = "pending_doc_\(triggerId)"
            if !game.flags.contains(queueKey) {
                game.flags.append(queueKey)
            }
            // Also store the parent document ID for chain tracking
            game.variables["doc_parent_\(triggerId)"] = document.id.uuidString
            game.variables["doc_chain_\(triggerId)"] = document.chainId ?? document.id.uuidString
        }

        return option
    }

    /// Extended version that also schedules Codex message reactions from affected characters
    func selectOptionWithCodexReaction(
        document: DeskDocument,
        optionId: String,
        game: Game,
        context: ModelContext
    ) -> DocumentOption? {
        // First, process the option normally
        guard let option = selectOption(document: document, optionId: optionId, game: game) else {
            return nil
        }

        // Schedule Codex reactions from relevant characters
        scheduleCodexReactionsForDecision(document: document, option: option, game: game, context: context)

        // Schedule delayed consequences based on the decision
        scheduleDocumentConsequences(document: document, option: option, game: game)

        return option
    }

    /// Schedule delayed consequences for a document decision
    /// These consequences will fire in future turns, reflecting real-world effects of bureaucratic decisions
    private func scheduleDocumentConsequences(document: DeskDocument, option: DocumentOption, game: Game) {
        let currentTurn = game.turnNumber
        var consequences: [ScheduledConsequence] = []

        // Base delay for consequences (2-5 turns)
        let baseDelay = Int.random(in: 2...5)

        // Check if this decision has significant effects worth scheduling consequences for
        let totalEffectMagnitude = option.effects.values.reduce(0) { $0 + abs($1) }
        guard totalEffectMagnitude >= 10 else { return }  // Only schedule for impactful decisions

        // Generate consequences based on document category
        switch document.categoryEnum {
        case .military:
            consequences.append(contentsOf: generateMilitaryConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .security:
            consequences.append(contentsOf: generateSecurityConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .economic:
            consequences.append(contentsOf: generateEconomicDocConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .political:
            consequences.append(contentsOf: generatePoliticalDocConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .personnel:
            consequences.append(contentsOf: generatePersonnelConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .diplomatic:
            consequences.append(contentsOf: generateDiplomaticConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .crisis:
            consequences.append(contentsOf: generateCrisisConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))

        case .personal:
            // Personal matters can lead to gratitude or resentment
            consequences.append(contentsOf: generatePersonalConsequences(
                document: document, option: option, currentTurn: currentTurn, baseDelay: baseDelay, game: game
            ))
        }

        // Schedule all generated consequences
        for consequence in consequences {
            game.scheduleDocumentConsequence(consequence)
            #if DEBUG
            print("[DocConsequence] Scheduled: \(consequence.type.displayName) for turn \(consequence.triggerTurn)")
            #endif
        }
    }

    /// Schedule Codex messages from characters affected by a document decision
    private func scheduleCodexReactionsForDecision(
        document: DeskDocument,
        option: DocumentOption,
        game: Game,
        context: ModelContext
    ) {
        // Check if the document has a character reaction
        if let reaction = option.characterReaction {
            // Find the reacting character
            if let character = game.characters.first(where: { $0.name == reaction.characterName }) {
                // Only schedule Codex message if disposition change is significant
                if abs(reaction.dispositionChange) >= 10 {
                    CodexService.shared.scheduleDecisionReaction(
                        character: character,
                        decision: document,
                        option: option,
                        delay: 1,  // React next turn
                        game: game,
                        context: context
                    )
                }
            }
        }

        // Check if the document sender is a character who should react
        if let senderCharacter = game.characters.first(where: { $0.name == document.sender || $0.title == document.senderTitle }) {
            // Patron reacts to decisions that affect their interests
            if senderCharacter.isPatron {
                // Check if decision affects patron favor
                if let favorChange = option.effects["patronFavor"], abs(favorChange) >= 5 {
                    CodexService.shared.scheduleDecisionReaction(
                        character: senderCharacter,
                        decision: document,
                        option: option,
                        delay: 1,
                        game: game,
                        context: context
                    )
                }
            }

            // Rival reacts to decisions that benefit or harm them
            if senderCharacter.isRival {
                // Check if decision affects rival threat
                if let threatChange = option.effects["rivalThreat"], abs(threatChange) >= 5 {
                    CodexService.shared.scheduleDecisionReaction(
                        character: senderCharacter,
                        decision: document,
                        option: option,
                        delay: 2,  // Rivals take longer to react
                        game: game,
                        context: context
                    )
                }
            }
        }

        // Check for security-sensitive decisions that might trigger patron/rival messages
        if let flag = option.setsFlag {
            // Decisions that set sensitive flags should trigger character awareness
            let sensitiveFlags = ["covered_up", "suppressed", "falsified", "negotiated_with", "arrested"]
            if sensitiveFlags.contains(where: { flag.contains($0) }) {
                // Patron may find out about sensitive decisions
                if let patron = game.patron, Bool.random() {
                    CodexService.shared.scheduleDecisionReaction(
                        character: patron,
                        decision: document,
                        option: option,
                        delay: Int.random(in: 2...4),  // Delayed discovery
                        game: game,
                        context: context
                    )
                }

                // Rival may use sensitive decisions against player
                if let rival = game.primaryRival, Bool.random() {
                    CodexService.shared.scheduleDecisionReaction(
                        character: rival,
                        decision: document,
                        option: option,
                        delay: Int.random(in: 3...5),  // Even more delayed
                        game: game,
                        context: context
                    )
                }
            }
        }
    }

    /// Handle a character's reaction to a decision
    private func handleCharacterReaction(_ reaction: CharacterReactionInfo, game: Game) {
        // Find the character
        let character = game.characters.first { char in
            if let id = reaction.characterId {
                return char.id.uuidString == id
            }
            return char.name.lowercased().contains(reaction.characterName.lowercased())
        }

        guard let character = character else { return }

        // Apply disposition change
        character.disposition += reaction.dispositionChange

        // Queue a follow-up event if reaction is significant (disposition change >= 15 or <= -15)
        if abs(reaction.dispositionChange) >= 15 {
            let reactionType = reaction.dispositionChange > 0 ? "positive" : "negative"
            let triggerId = "character_reaction_\(character.id.uuidString.prefix(8))_\(reactionType)"
            if !game.flags.contains("pending_doc_\(triggerId)") {
                game.flags.append("pending_doc_\(triggerId)")
                game.variables["reaction_character_\(triggerId)"] = character.id.uuidString
                game.variables["reaction_type_\(triggerId)"] = reactionType
            }
        }
    }

    // MARK: - Document Follow-Up Generation

    /// Generate pending follow-up documents from queued triggers
    func generatePendingFollowUpDocuments(game: Game) {
        let pendingFlags = game.flags.filter { $0.hasPrefix("pending_doc_") }

        for flag in pendingFlags {
            let triggerId = flag.replacingOccurrences(of: "pending_doc_", with: "")

            if let followUpDoc = createFollowUpDocument(triggerId: triggerId, game: game) {
                followUpDoc.game = game
                game.deskDocuments.append(followUpDoc)
            }

            // Clear the processed flag
            game.flags.removeAll { $0 == flag }

            // Clean up associated variables
            game.variables.removeValue(forKey: "doc_parent_\(triggerId)")
            game.variables.removeValue(forKey: "doc_chain_\(triggerId)")
            game.variables.removeValue(forKey: "reaction_character_\(triggerId)")
            game.variables.removeValue(forKey: "reaction_type_\(triggerId)")
        }
    }

    /// Create a follow-up document based on trigger ID pattern
    private func createFollowUpDocument(triggerId: String, game: Game) -> DeskDocument? {
        let parentId = game.variables["doc_parent_\(triggerId)"]
        let chainId = game.variables["doc_chain_\(triggerId)"]

        // Match trigger patterns to document types
        switch triggerId {
        // Investigation follow-ups
        case let id where id.hasPrefix("investigation_"):
            return generateInvestigationFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Arrest follow-ups
        case let id where id.hasPrefix("arrest_") || id.hasPrefix("arrested_"):
            return generateArrestFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Appeal/denial follow-ups
        case let id where id.hasPrefix("appeal_") || id.hasPrefix("denied_"):
            return generateAppealFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Consequence reports
        case let id where id.hasPrefix("consequence_"):
            return generateConsequenceFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Character reactions
        case let id where id.hasPrefix("character_reaction_"):
            return generateCharacterReactionFollowUp(triggerId: id, game: game)

        // Policy implementation follow-ups
        case let id where id.hasPrefix("policy_"):
            return generatePolicyFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Verification follow-ups (leave balance, credentials, etc.)
        case let id where id.hasPrefix("verification_"):
            return generateVerificationFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Interrogation follow-ups
        case let id where id.hasPrefix("interrogation_"):
            return generateInterrogationFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Visit/inspection follow-ups
        case let id where id.hasPrefix("visit_"):
            return generateVisitFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Evidence update follow-ups
        case let id where id.hasPrefix("evidence_update_"):
            return generateEvidenceUpdateFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Compliance follow-ups (quota, policy implementation)
        case let id where id.hasPrefix("compliance_"):
            return generateComplianceFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Reallocation impact follow-ups
        case let id where id.hasPrefix("reallocation_"):
            return generateReallocationImpactFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Surveillance result follow-ups
        case let id where id.hasPrefix("surveillance_"):
            return generateSurveillanceResultFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        // Case outcome follow-ups (discipline, sentencing)
        case let id where id.hasPrefix("case_outcome_"):
            return generateCaseOutcomeFollowUp(triggerId: id, parentId: parentId, chainId: chainId, game: game)

        default:
            return nil
        }
    }

    // MARK: - Follow-Up Document Templates

    /// Generate an investigation report following an investigation request
    private func generateInvestigationFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let outcomes = [
            ("evidence_found", "Investigation has uncovered concerning evidence", true),
            ("nothing_found", "Investigation concluded with no actionable findings", false),
            ("inconclusive", "Investigation results are inconclusive - more time needed", false)
        ]

        let (outcomeId, summary, requiresAction) = outcomes.randomElement()!

        let body = """
        INVESTIGATION REPORT
        Reference: \(triggerId.uppercased())

        Following your authorization, our agents conducted a thorough investigation.

        FINDINGS: \(summary)

        \(outcomeId == "evidence_found" ?
            "Subject was observed engaging in unauthorized contacts. Documentation attached (classified).\n\nRECOMMENDED ACTION: Proceed to formal interrogation." :
            outcomeId == "nothing_found" ?
            "No evidence of wrongdoing was discovered. Subject appears to be a loyal citizen.\n\nRECOMMENDED ACTION: Close case file." :
            "Further surveillance is recommended before drawing conclusions.\n\nRECOMMENDED ACTION: Extend investigation period.")

        Awaiting your direction.

        - Bureau of People's Security
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_investigation_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Investigation Report: \(triggerId.replacingOccurrences(of: "investigation_", with: "").capitalized)")
            .from("Investigation Division", title: "Bureau of People's Security")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(requiresAction ? .priority : .routine)
            .inCategory(.security)
            .classified(as: "CLASSIFIED")
            .withBody(body)
            .withGenerationReason("investigation_follow_up")

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "investigation_follow_up")
        }

        if requiresAction {
            builder = builder
                .requiresDecision(true)
                .addOption(
                    id: "proceed_interrogation",
                    text: "PROCEED - Authorize formal interrogation",
                    shortDescription: "Authorized interrogation",
                    effects: ["security": 5, "stability": -3]
                )
                .addOption(
                    id: "close_case",
                    text: "CLOSE CASE - Evidence insufficient",
                    shortDescription: "Closed case",
                    effects: ["security": -3]
                )
                .addOption(
                    id: "continue_surveillance",
                    text: "CONTINUE SURVEILLANCE - Gather more evidence",
                    shortDescription: "Extended surveillance",
                    effects: ["network": -5]
                )
        } else {
            builder = builder
                .requiresDecision(true)
                .addOption(
                    id: "acknowledge",
                    text: "ACKNOWLEDGE - File report",
                    shortDescription: "Acknowledged report",
                    effects: [:]
                )
        }

        return builder.build()
    }

    /// Generate a detention/arrest update following an arrest authorization
    private func generateArrestFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectName = triggerId
            .replacingOccurrences(of: "arrested_", with: "")
            .replacingOccurrences(of: "arrest_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("confession", "Subject has confessed to anti-state activities", "TRIAL PREPARATION"),
            ("resistance", "Subject is refusing to cooperate despite questioning", "EXTENDED DETENTION"),
            ("complications", "Medical complications have arisen during detention", "MEDICAL REVIEW"),
            ("new_leads", "Subject has implicated additional individuals", "EXPANDED INVESTIGATION")
        ]

        let (outcomeType, summary, nextStep) = outcomes.randomElement()!

        let body = """
        DETENTION UPDATE
        Subject: \(subjectName.uppercased())
        Status: IN CUSTODY

        Following the arrest you authorized, we submit this status report.

        CURRENT SITUATION: \(summary)

        \(outcomeType == "confession" ?
            "The confession implicates several co-conspirators. Names attached in separate classified annex." :
            outcomeType == "resistance" ?
            "Enhanced interrogation methods may be required. Your authorization is requested." :
            outcomeType == "complications" ?
            "Subject requires medical attention. This may delay proceedings and attract attention." :
            "Subject claims knowledge of a broader network. Investigation scope may need to expand significantly.")

        RECOMMENDED NEXT STEP: \(nextStep)

        Awaiting further instructions.

        - Detention Facility Command
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_detention_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Detention Update: \(subjectName)")
            .from("Detention Commander", title: "Facility 7")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.priority)
            .inCategory(.security)
            .classified(as: "SECRET")
            .withBody(body)
            .requiresDecision(true)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "arrest_follow_up")
        }

        switch outcomeType {
        case "confession":
            builder = builder
                .addOption(id: "trial", text: "PROCEED TO TRIAL", shortDescription: "Ordered trial",
                          effects: ["security": 10, "stability": -5])
                .addOption(id: "expand", text: "INVESTIGATE NAMED INDIVIDUALS", shortDescription: "Expanded investigation",
                          effects: ["security": 5, "network": -10])
        case "resistance":
            builder = builder
                .addOption(id: "enhanced", text: "AUTHORIZE ENHANCED METHODS", shortDescription: "Enhanced interrogation",
                          effects: ["security": 5, "stability": -10])
                .addOption(id: "patience", text: "CONTINUE STANDARD METHODS", shortDescription: "Continued questioning",
                          effects: [:])
                .addOption(id: "release", text: "RELEASE - INSUFFICIENT EVIDENCE", shortDescription: "Released subject",
                          effects: ["security": -10, "stability": 5])
        case "complications":
            builder = builder
                .addOption(id: "medical", text: "PROVIDE MEDICAL CARE", shortDescription: "Provided medical care",
                          effects: ["treasury": -10])
                .addOption(id: "transfer", text: "TRANSFER TO HOSPITAL (RISKY)", shortDescription: "Transferred to hospital",
                          effects: ["security": -10])
                .addOption(id: "continue", text: "CONTINUE DESPITE COMPLICATIONS", shortDescription: "Continued detention",
                          effects: ["stability": -5])
        default:
            builder = builder
                .addOption(id: "expand", text: "EXPAND INVESTIGATION", shortDescription: "Expanded investigation",
                          effects: ["network": -15, "security": 10])
                .addOption(id: "focus", text: "FOCUS ON CURRENT SUBJECT", shortDescription: "Maintained focus",
                          effects: [:])
        }

        return builder.build()
    }

    /// Generate an appeal letter following a denial
    private func generateAppealFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let appealTypes = [
            ("resource", "Resource Allocation Appeal", "Our department is struggling without the requested resources."),
            ("personnel", "Personnel Decision Appeal", "We respectfully request reconsideration of the personnel decision."),
            ("quota", "Quota Appeal", "The current targets are physically impossible to achieve.")
        ]

        let (appealType, title, opening) = appealTypes.randomElement()!

        let body = """
        [FORMAL APPEAL - SECOND REQUEST]

        Comrade,

        \(opening)

        We understand resources are limited and priorities must be set. However, we believe the original decision may not have considered all relevant factors.

        ADDITIONAL CONTEXT:
        - \(appealType == "resource" ? "Three workers have been injured due to equipment failures this month alone." :
             appealType == "personnel" ? "The individual in question has served faithfully for 12 years with an exemplary record." :
             "Other factories with newer equipment receive the same quotas despite having twice our capacity.")

        We do not make this appeal lightly. We ask only for fair consideration.

        Respectfully submitted,
        - Department Representative
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_appeal_\(UUID().uuidString.prefix(6))")
            .ofType(.letter)
            .titled(title)
            .from("Department Representative", title: "Appeals Office")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(appealType == "resource" ? .economic : appealType == "personnel" ? .personnel : .economic)
            .withBody(body)
            .withFootnote("This is their second appeal. A third will go to your superiors.")
            .requiresDecision(true)
            .addOption(id: "reconsider", text: "RECONSIDER - Grant the appeal", shortDescription: "Granted appeal",
                      effects: appealType == "resource" ? ["treasury": -30, "stability": 5] : ["stability": 5])
            .addOption(id: "deny_final", text: "DENY FINAL - No further appeals", shortDescription: "Denied final",
                      effects: ["stability": -5])
            .addOption(id: "partial", text: "PARTIAL GRANT - Compromise solution", shortDescription: "Partial grant",
                      effects: [:])

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "appeal_follow_up")
        }

        return builder.build()
    }

    /// Generate a consequence report showing effects of a previous decision
    private func generateConsequenceFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let consequences = [
            ("positive", "POSITIVE OUTCOMES REPORT", "The decision has yielded favorable results beyond expectations."),
            ("negative", "COMPLICATIONS REPORT", "Unforeseen complications have arisen from the recent decision."),
            ("mixed", "SITUATION ASSESSMENT", "The decision has produced mixed results requiring your attention.")
        ]

        let (consequenceType, title, opening) = consequences.randomElement()!

        let body = """
        \(title)
        Reference: Previous Decision

        \(opening)

        \(consequenceType == "positive" ?
            "Production has increased by 12% in affected sectors.\nWorker morale shows improvement.\nOther departments are requesting similar measures." :
            consequenceType == "negative" ?
            "Unexpected resistance has emerged from affected parties.\nCosts have exceeded initial projections by 40%.\nQuestions are being raised at higher levels." :
            "Some metrics show improvement while others have declined.\nThe situation remains fluid and may require adjustment.\nFurther monitoring is recommended.")

        This report is for your awareness. \(consequenceType == "negative" ? "Immediate attention may be required." : "No immediate action required unless you wish to adjust course.")

        - Analysis Division
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_consequence_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Analysis Division", title: "Strategic Planning")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(consequenceType == "negative" ? .priority : .routine)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(consequenceType == "negative")

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "consequence_follow_up")
        }

        if consequenceType == "negative" {
            builder = builder
                .addOption(id: "address", text: "ADDRESS ISSUES - Take corrective action", shortDescription: "Took corrective action",
                          effects: ["treasury": -20, "stability": 5])
                .addOption(id: "stay_course", text: "STAY THE COURSE - Issues will resolve", shortDescription: "Maintained course",
                          effects: ["stability": -5])
                .addOption(id: "deflect", text: "DEFLECT BLAME - Not your responsibility", shortDescription: "Deflected blame",
                          effects: ["patronFavor": -5])
        } else {
            builder = builder
                .addOption(id: "acknowledge", text: "ACKNOWLEDGE - Note for records", shortDescription: "Acknowledged",
                          effects: [:])
        }

        return builder.build()
    }

    /// Generate a response from a character following a significant reaction
    private func generateCharacterReactionFollowUp(triggerId: String, game: Game) -> DeskDocument? {
        guard let characterIdString = game.variables["reaction_character_\(triggerId)"],
              let characterId = UUID(uuidString: characterIdString),
              let character = game.characters.first(where: { $0.id == characterId }) else {
            return nil
        }

        let reactionType = game.variables["reaction_type_\(triggerId)"] ?? "neutral"
        let isPositive = reactionType == "positive"

        let body: String
        let title: String
        let urgency: DocumentUrgency

        if isPositive {
            title = "Message from \(character.name)"
            urgency = .routine
            body = """
            [PERSONAL NOTE]

            Comrade,

            I wanted to express my gratitude for your recent decision. It is rare to find someone in your position who acts with such wisdom and consideration.

            I believe we could work well together. Should you ever need assistance in matters within my purview, you need only ask.

            I look forward to our continued cooperation.

            With respect,
            \(character.name)
            \(character.title ?? "")
            """
        } else {
            title = "Formal Complaint: \(character.name)"
            urgency = .priority
            body = """
            [OFFICIAL CORRESPONDENCE]

            To Whom It May Concern,

            I am writing to formally register my objection to the recent decision regarding matters under my oversight.

            The action taken was neither wise nor necessary, and I intend to raise this matter through appropriate channels.

            I trust that future decisions will be made with greater consideration for those affected.

            \(character.name)
            \(character.title ?? "")
            """
        }

        return DeskDocument.builder()
            .withTemplateId("followup_reaction_\(UUID().uuidString.prefix(6))")
            .ofType(isPositive ? .personalNote : .letter)
            .titled(title)
            .from(character.name, title: character.title, characterId: character.id.uuidString)
            .receivedOnTurn(game.turnNumber)
            .withUrgency(urgency)
            .inCategory(.personal)
            .withBody(body)
            .withGenerationReason("character_reaction_follow_up")
            .requiresDecision(true)
            .addOption(
                id: isPositive ? "accept" : "acknowledge",
                text: isPositive ? "ACCEPT OFFER - Build relationship" : "ACKNOWLEDGE - Note the objection",
                shortDescription: isPositive ? "Accepted alliance offer" : "Acknowledged complaint",
                effects: isPositive ? ["network": 10] : [:]
            )
            .addOption(
                id: isPositive ? "cautious" : "dismiss",
                text: isPositive ? "CAUTIOUS RESPONSE - Don't commit" : "DISMISS - Ignore the complaint",
                shortDescription: isPositive ? "Cautious response" : "Dismissed complaint",
                effects: isPositive ? [:] : ["network": -5]
            )
            .build()
    }

    /// Generate a policy implementation update
    private func generatePolicyFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let body = """
        POLICY IMPLEMENTATION UPDATE
        Reference: \(triggerId.uppercased())

        The policy you approved has been implemented across affected sectors.

        IMPLEMENTATION STATUS: 78% Complete
        COMPLIANCE RATE: Satisfactory

        Notable observations:
        - Initial resistance has subsided
        - Some regional variations in implementation
        - Full compliance expected within two weeks

        No action required unless you wish to adjust implementation parameters.

        - Implementation Office
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_policy_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Policy Implementation Update")
            .from("Implementation Office", title: "Administrative Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.political)
            .withBody(body)
            .requiresDecision(true)
            .addOption(id: "acknowledge", text: "ACKNOWLEDGE", shortDescription: "Acknowledged update", effects: [:])
            .addOption(id: "accelerate", text: "ACCELERATE IMPLEMENTATION", shortDescription: "Accelerated", effects: ["stability": -5])

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "policy_follow_up")
        }

        return builder.build()
    }

    // MARK: - New Follow-Up Document Templates

    /// Generate a verification follow-up (leave balance, credentials, etc.)
    private func generateVerificationFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectName = triggerId
            .replacingOccurrences(of: "verification_leave_", with: "")
            .replacingOccurrences(of: "verification_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("confirmed", "Verification Complete: Records Confirmed", "Balance verified. Employee has 12 days remaining leave. Request is within policy parameters.", true),
            ("insufficient", "Verification Complete: Insufficient Balance", "Balance insufficient. Employee has only 4 days remaining, requested 7 days. Request exceeds available leave.", false),
            ("discrepancy", "Verification Alert: Discrepancy Detected", "Accounting discrepancy detected. Records show 8 days unaccounted for. Possible clerical error or falsification.", true)
        ]

        let (outcomeId, title, details, _) = outcomes.randomElement()!

        let body = """
        PERSONNEL VERIFICATION REPORT
        Reference: \(triggerId.uppercased())
        Subject: \(subjectName)

        STATUS: \(title.uppercased())

        FINDINGS:
        \(details)

        \(outcomeId == "confirmed" ?
            "RECOMMENDATION: Approve leave request. All documentation in order." :
            outcomeId == "insufficient" ?
            "RECOMMENDATION: Deny request or approve partial leave (4 days maximum)." :
            "RECOMMENDATION: Hold request pending investigation of discrepancy. Possible personnel file audit required.")

        - HR Administration
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_verification_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("HR Administration", title: "Personnel Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(outcomeId == "discrepancy" ? .priority : .routine)
            .inCategory(.personnel)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "verification_follow_up")
        }

        if outcomeId == "confirmed" {
            builder = builder
                .requiresDecision(true)
                .addOption(id: "approve_verified", text: "APPROVE - Balance confirmed", shortDescription: "Approved (verified)", effects: ["stability": 2])
                .addOption(id: "deny_anyway", text: "DENY - Operational needs", shortDescription: "Denied despite balance", effects: ["stability": -3])
        } else if outcomeId == "insufficient" {
            builder = builder
                .requiresDecision(true)
                .addOption(id: "deny_insufficient", text: "DENY - Insufficient balance", shortDescription: "Denied (insufficient)", effects: [:])
                .addOption(id: "approve_partial", text: "APPROVE PARTIAL - 4 days only", shortDescription: "Approved partial", effects: ["stability": 1])
                .addOption(id: "approve_exception", text: "APPROVE EXCEPTION - Grant anyway", shortDescription: "Approved exception", effects: ["stability": -2, "treasury": -5])
        } else {
            builder = builder
                .requiresDecision(true)
                .addOption(id: "investigate_discrepancy", text: "INVESTIGATE - Audit personnel files", shortDescription: "Investigating discrepancy", effects: ["treasury": -10], triggersDocument: "investigation_personnel_\(subjectName.lowercased().replacingOccurrences(of: " ", with: "_"))")
                .addOption(id: "dismiss_clerical", text: "DISMISS - Likely clerical error", shortDescription: "Dismissed as error", effects: [:])
                .addOption(id: "hold_pending", text: "HOLD - Pending resolution", shortDescription: "Held pending", effects: [:])
        }

        return builder.build()
    }

    /// Generate an interrogation follow-up
    private func generateInterrogationFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectRef = triggerId
            .replacingOccurrences(of: "interrogation_border_", with: "Border Subject ")
            .replacingOccurrences(of: "interrogation_", with: "Subject ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("confession", "Interrogation Report: Confession Obtained", "Subject has confessed to border crossing with intent to defect. Names of co-conspirators provided.", true),
            ("defiance", "Interrogation Report: Subject Uncooperative", "Subject maintains innocence despite extended questioning. No actionable intelligence obtained.", true),
            ("intel", "Interrogation Report: Intelligence Gathered", "Subject provided valuable information about smuggling routes. Potential asset for future operations.", true),
            ("cover_story", "Interrogation Report: Cover Story Verified", "Investigation confirms subject's cover story. Appears to be legitimate border worker with proper documentation.", false)
        ]

        let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

        let body = """
        INTERROGATION SUMMARY
        Reference: \(triggerId.uppercased())
        Subject: \(subjectRef)

        STATUS: \(title.uppercased())

        SUMMARY:
        \(summary)

        \(outcomeId == "confession" ?
            "Subject is cooperative and has requested leniency in exchange for further information.\n\nRECOMMENDATION: Formal charges and tribunal, or offer reduced sentence for additional names." :
            outcomeId == "defiance" ?
            "Subject shows signs of training to resist interrogation. May indicate foreign intelligence involvement.\n\nRECOMMENDATION: Extended detention or enhanced methods pending authorization." :
            outcomeId == "intel" ?
            "Information provided has been corroborated by field agents. Subject may be useful as informant.\n\nRECOMMENDATION: Consider recruitment or controlled release with surveillance." :
            "No evidence of hostile intent. Detention not justified under current regulations.\n\nRECOMMENDATION: Release with monitoring notation in file.")

        - Facility Security Command
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_interrogation_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Detention Commander", title: "Facility 7")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(requiresAction ? .priority : .routine)
            .inCategory(.security)
            .classified(as: "SECRET")
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "interrogation_follow_up")
        }

        switch outcomeId {
        case "confession":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "tribunal", text: "TRIBUNAL - Formal charges", shortDescription: "Sent to tribunal", effects: ["security": 5, "stability": -3])
                .addOption(id: "deal", text: "DEAL - Reduced sentence for names", shortDescription: "Offered deal", effects: ["security": 8, "network": 5])
        case "defiance":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "enhanced", text: "ENHANCED METHODS - Authorize", shortDescription: "Enhanced interrogation", effects: ["security": 5, "stability": -10])
                .addOption(id: "extended", text: "EXTENDED DETENTION - Continue standard", shortDescription: "Extended detention", effects: ["security": 2])
                .addOption(id: "release_monitored", text: "RELEASE - With full surveillance", shortDescription: "Released monitored", effects: ["security": -3, "network": 5])
        case "intel":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "recruit", text: "RECRUIT - Enlist as informant", shortDescription: "Recruited informant", effects: ["network": 10, "security": 3])
                .addOption(id: "release_surveillance", text: "RELEASE - Controlled with surveillance", shortDescription: "Released surveillance", effects: ["network": 5])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "release", text: "RELEASE - No grounds for detention", shortDescription: "Released", effects: ["stability": 3])
                .addOption(id: "file_notation", text: "RELEASE - With security notation", shortDescription: "Released with notation", effects: ["security": 2])
        }

        return builder.build()
    }

    /// Generate a visit/inspection follow-up
    private func generateVisitFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let locationName = triggerId
            .replacingOccurrences(of: "visit_factory_", with: "")
            .replacingOccurrences(of: "visit_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("as_reported", "Inspection Report: Conditions As Stated", "Facility inspection confirms director's assessment. Equipment is indeed aging and workforce is stretched. Quota adjustment is reasonable.", "approve"),
            ("worse", "Inspection Report: Conditions Critical", "Situation is more severe than reported. Multiple safety violations observed. Urgent intervention required to prevent catastrophic failure.", "urgent"),
            ("hidden_issues", "Inspection Report: Discrepancies Found", "Director's report omitted significant details. Evidence of resource diversion and inflated maintenance costs. Possible embezzlement.", "investigate"),
            ("model", "Inspection Report: Model Facility", "Contrary to appeal, facility exceeds standards. Director may be attempting to secure resources for personal gain. Current quotas achievable.", "deny")
        ]

        let (outcomeId, title, summary, _) = outcomes.randomElement()!

        let body = """
        FACILITY INSPECTION REPORT
        Location: \(locationName) Production Facility
        Reference: \(triggerId.uppercased())

        STATUS: \(title.uppercased())

        OBSERVATIONS:
        \(summary)

        \(outcomeId == "as_reported" ?
            "RECOMMENDATION: Approve quota adjustment as requested. Director appears competent and honest." :
            outcomeId == "worse" ?
            "RECOMMENDATION: Emergency resource allocation required. Without intervention, production will cease within weeks." :
            outcomeId == "hidden_issues" ?
            "RECOMMENDATION: Suspend director pending investigation. Audit all financial records. Consider replacement." :
            "RECOMMENDATION: Deny appeal. Consider disciplinary action for filing fraudulent request.")

        - Industrial Inspection Bureau
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_visit_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Chief Inspector", title: "Industrial Inspection Bureau")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(outcomeId == "worse" || outcomeId == "hidden_issues" ? .priority : .routine)
            .inCategory(.economic)
            .classified(as: "CONFIDENTIAL")
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "inspection_follow_up")
        }

        switch outcomeId {
        case "as_reported":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "approve_adjustment", text: "APPROVE - Grant quota adjustment", shortDescription: "Approved adjustment", effects: ["stability": 5, "treasury": -10])
                .addOption(id: "partial_adjustment", text: "PARTIAL - Reduce quota by half requested", shortDescription: "Partial adjustment", effects: ["stability": 2])
        case "worse":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "emergency_funds", text: "EMERGENCY FUNDS - Immediate allocation", shortDescription: "Emergency funding", effects: ["treasury": -50, "stability": 10])
                .addOption(id: "gradual_support", text: "GRADUAL SUPPORT - Phased assistance", shortDescription: "Gradual support", effects: ["treasury": -25, "stability": 3])
                .addOption(id: "close_facility", text: "CLOSE FACILITY - Redistribute workers", shortDescription: "Closed facility", effects: ["stability": -15, "treasury": 20])
        case "hidden_issues":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "suspend_investigate", text: "SUSPEND - Launch investigation", shortDescription: "Suspended for investigation", effects: ["security": 5, "stability": -5], triggersDocument: "investigation_embezzlement_\(locationName.lowercased().replacingOccurrences(of: " ", with: "_"))")
                .addOption(id: "warn_only", text: "WARN - Issue formal warning", shortDescription: "Formal warning issued", effects: [:])
                .addOption(id: "overlook", text: "OVERLOOK - Everyone does it", shortDescription: "Overlooked", effects: ["stability": 3, "security": -5])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "deny_discipline", text: "DENY - Disciplinary action", shortDescription: "Denied with discipline", effects: ["stability": -5, "standing": 3])
                .addOption(id: "deny_warning", text: "DENY - Warning only", shortDescription: "Denied with warning", effects: [:])
        }

        return builder.build()
    }

    /// Generate an evidence update follow-up
    private func generateEvidenceUpdateFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectName = triggerId
            .replacingOccurrences(of: "evidence_update_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("strengthened", "Evidence Update: Case Strengthened", "Additional evidence has been gathered. Witness testimony corroborates suspicions. Case is now ready for prosecution.", true),
            ("weakened", "Evidence Update: Case Compromised", "Key witness has recanted. Physical evidence chain of custody questioned. Prosecution would be risky.", false),
            ("third_party", "Evidence Update: New Suspect Identified", "Investigation has implicated a third party of higher standing. Original subject may be a minor player.", true),
            ("exonerated", "Evidence Update: Subject Cleared", "Further investigation reveals subject is innocent. Original accusation appears to be personal vendetta.", false)
        ]

        let (outcomeId, title, summary, urgent) = outcomes.randomElement()!

        let body = """
        CASE EVIDENCE UPDATE
        Subject: \(subjectName)
        Reference: \(triggerId.uppercased())

        STATUS: \(title.uppercased())

        UPDATE:
        \(summary)

        \(outcomeId == "strengthened" ?
            "RECOMMENDATION: Proceed with arrest authorization. Evidence supports conviction." :
            outcomeId == "weakened" ?
            "RECOMMENDATION: Close case or continue surveillance. Arrest at this time would be premature." :
            outcomeId == "third_party" ?
            "RECOMMENDATION: Expand investigation to new suspect. Original subject may provide testimony against superior." :
            "RECOMMENDATION: Release if detained. Close case. Consider investigation into accuser for filing false report.")

        - Investigation Division
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_evidence_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Senior Investigator", title: "Bureau of People's Security")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(urgent ? .priority : .routine)
            .inCategory(.security)
            .classified(as: "SECRET")
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "evidence_update_follow_up")
        }

        switch outcomeId {
        case "strengthened":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "authorize_arrest", text: "AUTHORIZE ARREST - Proceed", shortDescription: "Authorized arrest", effects: ["security": 10, "stability": -5])
                .addOption(id: "continue_gathering", text: "CONTINUE - Gather more evidence", shortDescription: "Continued investigation", effects: ["security": 2])
        case "weakened":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "close_case", text: "CLOSE CASE - Insufficient evidence", shortDescription: "Closed case", effects: ["stability": 3])
                .addOption(id: "continue_surveillance", text: "CONTINUE SURVEILLANCE - Wait for opportunity", shortDescription: "Continued surveillance", effects: ["security": 2, "network": -5])
        case "third_party":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "expand_investigation", text: "EXPAND - Investigate new suspect", shortDescription: "Expanded investigation", effects: ["security": 5, "network": -10], triggersDocument: "investigation_expanded_\(UUID().uuidString.prefix(6))")
                .addOption(id: "focus_original", text: "FOCUS - Proceed with original subject", shortDescription: "Focused on original", effects: ["security": 3])
                .addOption(id: "drop_both", text: "DROP - Too politically sensitive", shortDescription: "Dropped investigation", effects: ["security": -5, "stability": 5])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "close_exonerate", text: "CLOSE - Exonerate subject", shortDescription: "Exonerated subject", effects: ["stability": 5])
                .addOption(id: "investigate_accuser", text: "INVESTIGATE ACCUSER - False report", shortDescription: "Investigating accuser", effects: ["security": 5, "stability": -3])
        }

        return builder.build()
    }

    /// Generate a compliance follow-up (quota, policy implementation)
    private func generateComplianceFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectRef = triggerId
            .replacingOccurrences(of: "compliance_quota_", with: "Quota - ")
            .replacingOccurrences(of: "compliance_factory_", with: "Factory - ")
            .replacingOccurrences(of: "compliance_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("full", "Compliance Report: Full Achievement", "All targets met or exceeded. Implementation successful. Workers have adapted well to new requirements.", false),
            ("partial", "Compliance Report: Partial Achievement", "78% of targets achieved. Some sectors struggling with adjustment. Additional time may be needed.", false),
            ("non_compliance", "Compliance Report: Non-Compliance Detected", "Significant shortfalls in target achievement. Local officials may be sabotaging implementation or falsifying reports.", true),
            ("over_performance", "Compliance Report: Exceptional Results", "Targets exceeded by 140%. Possible indication of previously set quotas being too low, or heroic worker effort.", false)
        ]

        let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

        let body = """
        COMPLIANCE STATUS REPORT
        Subject: \(subjectRef)
        Reference: \(triggerId.uppercased())

        STATUS: \(title.uppercased())

        FINDINGS:
        \(summary)

        \(outcomeId == "full" ?
            "RECOMMENDATION: Commend local officials. Consider as model for other regions." :
            outcomeId == "partial" ?
            "RECOMMENDATION: Monitor progress. May require additional resources or revised timeline." :
            outcomeId == "non_compliance" ?
            "RECOMMENDATION: Investigation into local officials. Consider replacing leadership or imposing penalties." :
            "RECOMMENDATION: Review original quota settings. Either reward workers or adjust future targets upward.")

        - Compliance Monitoring Division
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_compliance_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Compliance Monitor", title: "Central Planning Bureau")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(requiresAction ? .priority : .routine)
            .inCategory(.economic)
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "compliance_follow_up")
        }

        switch outcomeId {
        case "full":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "commend", text: "COMMEND - Issue commendation", shortDescription: "Issued commendation", effects: ["stability": 5, "standing": 3])
                .addOption(id: "acknowledge", text: "ACKNOWLEDGE - Note success", shortDescription: "Acknowledged", effects: [:])
        case "partial":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "extend_deadline", text: "EXTEND - Additional time granted", shortDescription: "Extended deadline", effects: ["stability": 3])
                .addOption(id: "pressure", text: "PRESSURE - Demand full compliance", shortDescription: "Demanded compliance", effects: ["stability": -5, "standing": 2])
                .addOption(id: "resources", text: "RESOURCES - Allocate additional support", shortDescription: "Allocated resources", effects: ["treasury": -15, "stability": 5])
        case "non_compliance":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "investigate_officials", text: "INVESTIGATE - Audit local leadership", shortDescription: "Investigating officials", effects: ["security": 5, "stability": -5], triggersDocument: "investigation_compliance_\(UUID().uuidString.prefix(6))")
                .addOption(id: "replace_leadership", text: "REPLACE - New local officials", shortDescription: "Replaced leadership", effects: ["stability": -10, "standing": 5])
                .addOption(id: "accept_shortfall", text: "ACCEPT - Revise targets down", shortDescription: "Accepted shortfall", effects: ["standing": -5, "stability": 5])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "reward_workers", text: "REWARD - Bonuses for workers", shortDescription: "Rewarded workers", effects: ["treasury": -20, "stability": 10])
                .addOption(id: "raise_quotas", text: "RAISE QUOTAS - Increase future targets", shortDescription: "Raised quotas", effects: ["stability": -5, "treasury": 10])
                .addOption(id: "investigate_reporting", text: "INVESTIGATE - Verify numbers", shortDescription: "Investigating reports", effects: ["security": 3])
        }

        return builder.build()
    }

    /// Generate a reallocation impact follow-up
    private func generateReallocationImpactFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let unitName = triggerId
            .replacingOccurrences(of: "reallocation_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("smooth", "Reallocation Report: Transfer Complete", "Resource transfer completed without incident. Donor unit has adjusted operations successfully.", false),
            ("complaint", "Reallocation Report: Formal Complaint Filed", "Commander of donor unit has filed formal objection. Claims transfer compromises readiness and endangers personnel.", true),
            ("equipment_issues", "Reallocation Report: Equipment Problems", "Transferred equipment found to be in poor condition. Recipient unit reports significant maintenance required.", true),
            ("morale_impact", "Reallocation Report: Morale Concerns", "Donor unit experiencing low morale following transfer. Personnel retention concerns reported.", false)
        ]

        let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

        let body = """
        RESOURCE REALLOCATION IMPACT REPORT
        Affected Unit: \(unitName)
        Reference: \(triggerId.uppercased())

        STATUS: \(title.uppercased())

        IMPACT ASSESSMENT:
        \(summary)

        \(outcomeId == "smooth" ?
            "RECOMMENDATION: No action required. File for records." :
            outcomeId == "complaint" ?
            "RECOMMENDATION: Address complaint or risk escalation to higher command. Commander has influential connections." :
            outcomeId == "equipment_issues" ?
            "RECOMMENDATION: Either allocate repair funds or source replacement equipment. Current state affects operational capability." :
            "RECOMMENDATION: Consider morale-boosting measures for donor unit. Continued neglect may lead to discipline problems.")

        - Logistics Command
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_reallocation_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Logistics Officer", title: "Resource Allocation Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(requiresAction ? .priority : .routine)
            .inCategory(.military)
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "reallocation_follow_up")
        }

        switch outcomeId {
        case "smooth":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "file", text: "FILE - Note successful transfer", shortDescription: "Filed", effects: [:])
        case "complaint":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "dismiss_complaint", text: "DISMISS - Operational necessity", shortDescription: "Dismissed complaint", effects: ["militaryLoyalty": -5, "standing": 2])
                .addOption(id: "partial_restore", text: "PARTIAL RESTORE - Return some resources", shortDescription: "Partially restored", effects: ["treasury": -15, "militaryLoyalty": 3])
                .addOption(id: "full_restore", text: "FULL RESTORE - Reverse reallocation", shortDescription: "Fully restored", effects: ["treasury": -30, "militaryLoyalty": 5, "standing": -3])
        case "equipment_issues":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "repair_funds", text: "REPAIR - Allocate maintenance budget", shortDescription: "Funded repairs", effects: ["treasury": -20, "militaryLoyalty": 3])
                .addOption(id: "source_replacement", text: "REPLACE - Source new equipment", shortDescription: "Sourced replacement", effects: ["treasury": -40, "militaryLoyalty": 5])
                .addOption(id: "make_do", text: "MAKE DO - Use as available", shortDescription: "Use as-is", effects: ["militaryLoyalty": -3])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "morale_boost", text: "BOOST MORALE - Extra rations and leave", shortDescription: "Boosted morale", effects: ["treasury": -10, "militaryLoyalty": 5])
                .addOption(id: "ignore_morale", text: "IGNORE - Soldiers will adapt", shortDescription: "Ignored", effects: ["militaryLoyalty": -3])
        }

        return builder.build()
    }

    /// Generate a surveillance result follow-up
    private func generateSurveillanceResultFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let subjectName = triggerId
            .replacingOccurrences(of: "surveillance_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        let outcomes = [
            ("incriminating", "Surveillance Report: Evidence Obtained", "Enhanced surveillance has captured incriminating activity. Subject observed meeting with known foreign contacts.", true),
            ("nothing", "Surveillance Report: No Activity", "Extended surveillance period has yielded nothing of interest. Subject appears to lead unremarkable life.", false),
            ("cover_blown", "Surveillance Report: Operation Compromised", "Subject has detected surveillance. Observed counter-surveillance behavior. Asset may be burned.", true),
            ("asset_identified", "Surveillance Report: Recruitment Opportunity", "Subject displays disillusionment with current situation. May be receptive to recruitment as informant.", true)
        ]

        let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

        let body = """
        ENHANCED SURVEILLANCE REPORT
        Subject: \(subjectName)
        Reference: \(triggerId.uppercased())

        STATUS: \(title.uppercased())

        FINDINGS:
        \(summary)

        \(outcomeId == "incriminating" ?
            "RECOMMENDATION: Proceed to arrest and interrogation. Evidence sufficient for detention." :
            outcomeId == "nothing" ?
            "RECOMMENDATION: Close surveillance operation. Resources better allocated elsewhere." :
            outcomeId == "cover_blown" ?
            "RECOMMENDATION: Withdraw surveillance team. Consider whether to detain subject before they can flee or warn others." :
            "RECOMMENDATION: Initiate recruitment approach. Subject may provide valuable intelligence if handled correctly.")

        - Surveillance Division
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_surveillance_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled(title)
            .from("Surveillance Commander", title: "Bureau of People's Security")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(requiresAction ? .priority : .routine)
            .inCategory(.security)
            .classified(as: "SECRET")
            .withBody(body)

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "surveillance_follow_up")
        }

        switch outcomeId {
        case "incriminating":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "arrest_now", text: "ARREST - Detain immediately", shortDescription: "Arrested subject", effects: ["security": 10, "stability": -5])
                .addOption(id: "continue_watching", text: "CONTINUE - Identify network first", shortDescription: "Continued surveillance", effects: ["security": 3, "network": 5])
        case "nothing":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "close_surveillance", text: "CLOSE - End operation", shortDescription: "Closed surveillance", effects: ["network": 5])
                .addOption(id: "extend_period", text: "EXTEND - One more month", shortDescription: "Extended surveillance", effects: ["network": -5, "treasury": -10])
        case "cover_blown":
            builder = builder
                .requiresDecision(true)
                .addOption(id: "withdraw", text: "WITHDRAW - Pull surveillance team", shortDescription: "Withdrew team", effects: ["security": -3])
                .addOption(id: "detain_subject", text: "DETAIN - Arrest before flight", shortDescription: "Detained subject", effects: ["security": 5, "stability": -5])
                .addOption(id: "double_down", text: "OVERT SURVEILLANCE - Let them know we're watching", shortDescription: "Overt surveillance", effects: ["security": 3, "stability": -3])
        default:
            builder = builder
                .requiresDecision(true)
                .addOption(id: "recruit", text: "RECRUIT - Initiate approach", shortDescription: "Initiated recruitment", effects: ["network": 10, "security": 5])
                .addOption(id: "continue_observe", text: "OBSERVE - Monitor before approach", shortDescription: "Continued observation", effects: ["network": 3])
                .addOption(id: "ignore", text: "IGNORE - Not worth the risk", shortDescription: "Ignored opportunity", effects: [:])
        }

        return builder.build()
    }

    /// Generate a case outcome follow-up (discipline, sentencing)
    private func generateCaseOutcomeFollowUp(triggerId: String, parentId: String?, chainId: String?, game: Game) -> DeskDocument {
        let isExecution = triggerId.contains("execution")
        let isReeducation = triggerId.contains("reeducation")

        let subjectName = triggerId
            .replacingOccurrences(of: "case_outcome_execution_", with: "")
            .replacingOccurrences(of: "case_outcome_reeducation_", with: "")
            .replacingOccurrences(of: "case_outcome_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized

        if isExecution {
            let outcomes = [
                ("carried_out", "Execution Report: Sentence Carried Out", "Sentence was carried out at dawn. Subject showed no resistance. Body has been disposed of per regulations.", false),
                ("complications", "Execution Report: Complications Arose", "Execution was delayed due to procedural issues. Subject's family has filed appeal to higher authority.", true),
                ("message_sent", "Execution Report: Deterrent Effect Noted", "Public announcement of execution has had visible effect on discipline. Reported incidents down 40% this week.", false)
            ]
            let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

            let body = """
            CASE DISPOSITION REPORT
            Subject: \(subjectName)
            Sentence: Capital Punishment
            Reference: \(triggerId.uppercased())

            STATUS: \(title.uppercased())

            REPORT:
            \(summary)

            \(outcomeId == "carried_out" ?
                "RECOMMENDATION: File closed. No further action required." :
                outcomeId == "complications" ?
                "RECOMMENDATION: Address appeal immediately. Delay may be seen as weakness." :
                "RECOMMENDATION: Consider similar measures for other discipline cases while deterrent effect is strong.")

            - Military Justice Command
            """

            var builder = DeskDocument.builder()
                .withTemplateId("followup_execution_\(UUID().uuidString.prefix(6))")
                .ofType(.report)
                .titled(title)
                .from("Execution Commander", title: "Military Justice Division")
                .receivedOnTurn(game.turnNumber)
                .withUrgency(requiresAction ? .priority : .routine)
                .inCategory(.military)
                .classified(as: "CLASSIFIED")
                .withBody(body)

            if let parentId = parentId {
                builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "execution_follow_up")
            }

            switch outcomeId {
            case "carried_out":
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "file_closed", text: "FILE - Case closed", shortDescription: "Filed closed", effects: [:])
            case "complications":
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "deny_appeal", text: "DENY APPEAL - Proceed immediately", shortDescription: "Denied appeal", effects: ["stability": -5, "standing": 3])
                    .addOption(id: "review_appeal", text: "REVIEW - Consider appeal", shortDescription: "Reviewing appeal", effects: ["stability": 3, "standing": -3])
            default:
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "capitalize", text: "CAPITALIZE - Publicize further", shortDescription: "Publicized", effects: ["stability": -3, "militaryLoyalty": 5])
                    .addOption(id: "note_effect", text: "NOTE - Record deterrent effect", shortDescription: "Noted effect", effects: [:])
            }

            return builder.build()

        } else if isReeducation {
            let outcomes = [
                ("progress", "Reeducation Report: Progress Noted", "Subject showing signs of genuine reform. Participation in self-criticism sessions is exemplary.", false),
                ("resistance", "Reeducation Report: Resistance Continues", "Subject maintains defiant attitude. Additional measures may be required.", true),
                ("completed", "Reeducation Report: Program Complete", "Subject has completed reeducation program. Instructors recommend return to duty with monitoring.", false)
            ]
            let (outcomeId, title, summary, requiresAction) = outcomes.randomElement()!

            let body = """
            REEDUCATION STATUS REPORT
            Subject: \(subjectName)
            Program: Political Rehabilitation
            Reference: \(triggerId.uppercased())

            STATUS: \(title.uppercased())

            ASSESSMENT:
            \(summary)

            \(outcomeId == "progress" ?
                "RECOMMENDATION: Continue program. Expected completion in 3 months." :
                outcomeId == "resistance" ?
                "RECOMMENDATION: Extend program or escalate to labor assignment." :
                "RECOMMENDATION: Approve return to duty. Assign to low-sensitivity position initially.")

            - Political Education Division
            """

            var builder = DeskDocument.builder()
                .withTemplateId("followup_reeducation_\(UUID().uuidString.prefix(6))")
                .ofType(.report)
                .titled(title)
                .from("Reeducation Commander", title: "Political Education Division")
                .receivedOnTurn(game.turnNumber)
                .withUrgency(requiresAction ? .priority : .routine)
                .inCategory(.personnel)
                .withBody(body)

            if let parentId = parentId {
                builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "reeducation_follow_up")
            }

            switch outcomeId {
            case "progress":
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "continue_program", text: "CONTINUE - Maintain current program", shortDescription: "Continued program", effects: [:])
                    .addOption(id: "accelerate", text: "ACCELERATE - Intensive sessions", shortDescription: "Accelerated program", effects: ["stability": -2])
            case "resistance":
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "extend_program", text: "EXTEND - Additional 6 months", shortDescription: "Extended program", effects: ["stability": 2])
                    .addOption(id: "labor_camp", text: "LABOR ASSIGNMENT - Hard labor 2 years", shortDescription: "Assigned labor", effects: ["stability": -5, "security": 3])
                    .addOption(id: "release_anyway", text: "RELEASE - Not worth resources", shortDescription: "Released", effects: ["security": -3, "stability": 3])
            default:
                builder = builder
                    .requiresDecision(true)
                    .addOption(id: "approve_return", text: "APPROVE - Return to duty", shortDescription: "Approved return", effects: ["militaryLoyalty": 3])
                    .addOption(id: "assign_monitoring", text: "APPROVE WITH MONITORING - Extended surveillance", shortDescription: "Approved with monitoring", effects: ["security": 2])
            }

            return builder.build()
        }

        // Generic case outcome
        let body = """
        CASE STATUS UPDATE
        Subject: \(subjectName)
        Reference: \(triggerId.uppercased())

        Case has been processed according to your directive.
        No further action required unless you specify otherwise.

        - Administrative Division
        """

        var builder = DeskDocument.builder()
            .withTemplateId("followup_case_\(UUID().uuidString.prefix(6))")
            .ofType(.report)
            .titled("Case Status: \(subjectName)")
            .from("Case Administrator", title: "Administrative Division")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
            .withBody(body)
            .requiresDecision(true)
            .addOption(id: "acknowledge", text: "ACKNOWLEDGE", shortDescription: "Acknowledged", effects: [:])

        if let parentId = parentId {
            builder = builder.asFollowUpTo(documentId: parentId, chainId: chainId, reason: "case_follow_up")
        }

        return builder.build()
    }

    // MARK: - Document Consequence Generators

    /// Generate consequences for military document decisions
    private func generateMilitaryConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Approved military spending can succeed or fail
        if let treasuryCost = option.effects["treasury"], treasuryCost < -20 {
            // High-cost military decisions have operational outcomes
            if Bool.random() { // 50% chance of success
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .operationalSuccess,
                    magnitude: 30,
                    description: "The operation authorized in '\(document.title)' has achieved its objectives. Command reports favorable outcomes.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["militaryLoyalty": 5, "stability": 3]
                ))
            } else {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .operationalFailure,
                    magnitude: 40,
                    description: "The operation authorized in '\(document.title)' has encountered significant setbacks. An inquiry may be warranted.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["militaryLoyalty": -5, "stability": -5, "standing": -3]
                ))
            }
        }

        // Denied military requests breed resentment
        if let militaryEffect = option.effects["military"], militaryEffect < 0 {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 1,
                type: .militaryUnrest,
                magnitude: 25,
                description: "Grumbling in military circles about your handling of '\(document.title)'. Officers remember who denied their requests.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["militaryLoyalty": -3]
            ))
        }

        return consequences
    }

    /// Generate consequences for security document decisions
    private func generateSecurityConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Approving arrests/investigations creates political fallout
        if option.text.lowercased().contains("approve") || option.text.lowercased().contains("authorize") {
            // Security actions can backfire
            if Int.random(in: 1...100) <= 30 { // 30% chance of blowback
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .investigationOpened,
                    magnitude: 35,
                    description: "Your authorization of '\(document.title)' has drawn scrutiny. Someone is asking questions about your role.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["network": -5, "standing": -3]
                ))
            }
        }

        // Denying security requests may let threats fester
        if option.text.lowercased().contains("deny") || option.text.lowercased().contains("reject") {
            if Int.random(in: 1...100) <= 40 { // 40% chance
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay + 2,
                    type: .bureaucraticBlowback,
                    magnitude: 30,
                    description: "The matter you dismissed in '\(document.title)' has resurfaced. Security reports suggest the threat was real.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["stability": -5, "security": -5]
                ))
            }
        }

        return consequences
    }

    /// Generate consequences for economic document decisions
    private func generateEconomicDocConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Large economic commitments have delayed effects
        if let treasuryCost = option.effects["treasury"], treasuryCost < -30 {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 2,
                type: .resourceShortage,
                magnitude: 35,
                description: "The expenditure approved in '\(document.title)' has strained resources in other areas. Budget shortfalls are emerging.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["treasury": -10, "industrialOutput": -3]
            ))
        }

        // Economic reforms create political reactions
        if let outputChange = option.effects["industrialOutput"], abs(outputChange) >= 5 {
            if outputChange > 0 {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .politicalFavor,
                    magnitude: 25,
                    description: "Your economic decision in '\(document.title)' has improved production figures. Certain factions view you more favorably.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["standing": 3, "patronFavor": 2]
                ))
            } else {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .eliteBacklash,
                    magnitude: 30,
                    description: "Your economic decision in '\(document.title)' has hurt production. Questions are being asked about your judgment.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["standing": -3, "eliteLoyalty": -5]
                ))
            }
        }

        return consequences
    }

    /// Generate consequences for political document decisions
    private func generatePoliticalDocConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Political decisions affect relationships long-term
        if let patronEffect = option.effects["patronFavor"], abs(patronEffect) >= 5 {
            let isPositive = patronEffect > 0
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: isPositive ? .gratitude : .resentment,
                magnitude: 30,
                description: isPositive ?
                    "Your handling of '\(document.title)' has been noted favorably in certain circles. Allies remember loyalty." :
                    "Your decision on '\(document.title)' has not been forgotten. Certain parties feel... disappointed.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: isPositive ? ["network": 3] : ["network": -3, "rivalThreat": 5]
            ))
        }

        // Stability changes have ripple effects
        if let stabilityChange = option.effects["stability"], stabilityChange < -5 {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 1,
                type: .popularUnrest,
                magnitude: 25,
                description: "The instability caused by '\(document.title)' continues to ripple outward. Regional reports indicate growing discontent.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["popularSupport": -5, "stability": -3]
            ))
        }

        return consequences
    }

    /// Generate consequences for personnel document decisions
    private func generatePersonnelConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Personnel decisions affect loyalty
        if option.text.lowercased().contains("approve") || option.text.lowercased().contains("transfer") {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: .gratitude,
                magnitude: 20,
                description: "The individual affected by '\(document.title)' has not forgotten your favorable decision. You may have made an ally.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["network": 2]
            ))
        }

        // Denied personnel requests breed resentment
        if option.text.lowercased().contains("deny") || option.text.lowercased().contains("reject") {
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: .resentment,
                magnitude: 25,
                description: "The individual denied in '\(document.title)' harbors resentment. In the Party, such feelings can fester.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["network": -2]
            ))
        }

        return consequences
    }

    /// Generate consequences for diplomatic document decisions
    private func generateDiplomaticConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Diplomatic decisions have international ramifications
        if let standingChange = option.effects["internationalStanding"], abs(standingChange) >= 5 {
            let isPositive = standingChange > 0
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay + 1,
                type: isPositive ? .politicalFavor : .internationalPressure,
                magnitude: 30,
                description: isPositive ?
                    "Your diplomatic handling of '\(document.title)' has improved foreign perception. Trade opportunities may emerge." :
                    "Your decision on '\(document.title)' has drawn international criticism. Foreign pressure is mounting.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: isPositive ? ["treasury": 5] : ["treasury": -5, "stability": -3]
            ))
        }

        return consequences
    }

    /// Generate consequences for crisis document decisions
    private func generateCrisisConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Crisis decisions always have follow-up effects
        let effectTotal = option.effects.values.reduce(0, +)
        let wasPositiveAction = effectTotal < 0 // Negative treasury = spending to address crisis

        if wasPositiveAction {
            // Addressing crisis can succeed or partially succeed
            if Bool.random() {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .operationalSuccess,
                    magnitude: 40,
                    description: "Your decisive action on '\(document.title)' has contained the crisis. The situation is stabilizing.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["stability": 5, "standing": 5, "patronFavor": 3]
                ))
            } else {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay,
                    type: .bureaucraticBlowback,
                    magnitude: 35,
                    description: "Despite resources committed to '\(document.title)', the situation remains precarious. More may be needed.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["stability": -3]
                ))
            }
        } else {
            // Inaction or minimal action on crisis
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay - 1, // Crisis consequences come faster
                type: .popularUnrest,
                magnitude: 45,
                description: "Your restrained response to '\(document.title)' has allowed the situation to deteriorate. Public confidence is shaken.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["popularSupport": -10, "stability": -5]
            ))
        }

        return consequences
    }

    private func generatePersonalConsequences(
        document: DeskDocument,
        option: DocumentOption,
        currentTurn: Int,
        baseDelay: Int,
        game: Game
    ) -> [ScheduledConsequence] {
        var consequences: [ScheduledConsequence] = []

        // Personal appeals create strong relationship effects
        let effectTotal = option.effects.values.reduce(0, +)
        let wasHelpful = effectTotal < 0  // Spending resources to help = helpful

        if wasHelpful {
            // Helping someone creates gratitude
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: .gratitude,
                magnitude: 30,
                description: "Your assistance regarding '\(document.title)' has not been forgotten. You have earned a friend in the apparatus.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["network": 3, "patronFavor": 2]
            ))

            // But helping one may slight another
            if Bool.random() {
                consequences.append(ScheduledConsequence(
                    triggerTurn: currentTurn + baseDelay + 2,
                    type: .resentment,
                    magnitude: 20,
                    description: "Others have taken note of who you chose to assist. Not everyone approves of favoritism.",
                    relatedDocumentId: document.id.uuidString,
                    relatedOptionId: option.id,
                    statEffects: ["rivalThreat": 3]
                ))
            }
        } else {
            // Refusing personal appeals creates resentment
            consequences.append(ScheduledConsequence(
                triggerTurn: currentTurn + baseDelay,
                type: .resentment,
                magnitude: 25,
                description: "Your rejection of the request in '\(document.title)' has created an enemy. Slights are remembered in the Party.",
                relatedDocumentId: document.id.uuidString,
                relatedOptionId: option.id,
                statEffects: ["network": -2]
            ))
        }

        return consequences
    }
}

