//
//  DocumentQueueService.swift
//  Nomenklatura
//
//  Manages the queue of documents on the player's desk.
//  Handles document generation, aging, consequences, and prioritization.
//

import Foundation
import SwiftUI
import Combine

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

    /// Generate new documents for the current turn
    func generateDocumentsForTurn(game: Game) {
        isProcessing = true
        defer { isProcessing = false }

        // Reset duplicate tracking for new turn
        generatedThisTurn.removeAll()
        categoriesGeneratedThisTurn.removeAll()
        crisisDocumentGeneratedThisTurn = false

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

        // TODO: Adjust based on player's role when role system is implemented

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
                setsFlag: "investigating_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
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
                effects: ["network": -10, "security": 5]
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
                setsFlag: "arrested_\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
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
                effects: [:]
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
                effects: ["security": 3]
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
                effects: ["network": -5]
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

    // MARK: - Other Category Generators (Stubs for now)

    private func generateMilitaryDocument(for game: Game) -> DeskDocument {
        let templates = [
            generateRequisitionRequest,
            generateBorderIncidentReport,
            generateDisciplineCase
        ]
        return templates.randomElement()!(game)
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
                effects: ["military": 5]
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
                effects: ["network": 10, "security": -5]
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
                setsFlag: "executed_reznik"
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
                effects: ["military": -5]
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
                effects: direction == "increase" ? ["standing": 5] : ["stability": 5]
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
                effects: ["patronFavor": -10, "security": 10]
            )
            .addOption(
                id: "investigate",
                text: "INVESTIGATE SOURCE - Find who's lying",
                shortDescription: "Investigated source",
                effects: ["network": -10]
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
                setsFlag: "helped_morrison"
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
                setsFlag: "visited_morrison_factory"
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

    private func generateDiplomaticDocument(for game: Game) -> DeskDocument {
        let body = """
        DECODED CABLE - CONFIDENTIAL
        FROM: Embassy, London

        British academics propose cultural symposium in Vienna on "shared European heritage."

        Initial assessment: Professor Whitmore likely connected to British intelligence.

        However, symposium provides opportunities:
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
            .titled("Embassy Cable: Cultural Exchange")
            .from("Ambassador Mitchell", title: "London Embassy")
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

    private func generatePersonnelDocument(for game: Game) -> DeskDocument {
        let body = """
        PERSONNEL TRANSFER REQUEST

        Subject: Captain Anna Wallace
        Current Assignment: 3rd Artillery Battalion
        Requested Assignment: Defense Ministry, Strategic Planning

        Qualifications: Top of class, excellent performance reviews, speaks three languages.

        Notes: Captain Wallace is the niece of General Wallace. The General has made no formal request but has "mentioned" her talents in conversation.

        Your recommendation will be given significant weight.

        APPROVE / DENY / DEFER
        """

        return DeskDocument.builder()
            .withTemplateId("transfer_\(UUID().uuidString.prefix(6))")
            .ofType(.assessment)
            .titled("Transfer Request: Capt. Wallace")
            .from("Personnel Division", title: "Defense Ministry")
            .receivedOnTurn(game.turnNumber)
            .withUrgency(.routine)
            .inCategory(.personnel)
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

    private func generateCrisisDocument(for game: Game) -> DeskDocument {
        // Use position-aware language
        let authority = AuthorityLanguage(game: game)

        // Military command context varies by position
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

        // Adjust option text based on authority level
        let suppressText = authority.isTopLeadership ? "SUPPRESS - Send in the military" :
                          authority.isPolitburoMember ? "RECOMMEND SUPPRESSION - Forward to General Secretary" :
                          "RECOMMEND FORCE - Escalate to Politburo"
        let suppressDesc = authority.isTopLeadership ? "Ordered military suppression" :
                          "Recommended military suppression"

        return DeskDocument.builder()
            .withTemplateId("crisis_\(UUID().uuidString.prefix(6))")
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
        if let _ = option.triggersDocument {
            // TODO: Generate follow-up document based on triggerId
            // For now, this is handled by flag system
        }

        return option
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

        // TODO: Queue a follow-up event if reaction is significant
    }
}

