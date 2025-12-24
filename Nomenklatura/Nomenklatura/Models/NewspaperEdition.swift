//
//  NewspaperEdition.swift
//  Nomenklatura
//
//  Model for the newspaper mechanic - world-building through regime press
//

import Foundation

// MARK: - Publication Type

enum PublicationType: String, Codable, CaseIterable, Sendable {
    case state          // "The People's Voice" - official Party organ
    case samizdat       // Underground truth-tellers - typed/mimeographed
    case foreign        // Western radio/newspapers (rare)

    var displayName: String {
        switch self {
        case .state: return "State Press"
        case .samizdat: return "Underground"
        case .foreign: return "Foreign Broadcast"
        }
    }

    /// Whether this publication tells the "truth" about stats
    var showsRealStats: Bool {
        switch self {
        case .state: return false
        case .samizdat, .foreign: return true
        }
    }
}

// MARK: - Newspaper Edition

struct NewspaperEdition: Codable, Identifiable, Sendable {
    var id: UUID
    var turnNumber: Int
    var publicationDate: String
    var publicationName: String  // "The People's Voice" / "The People's Truth"
    var publicationType: PublicationType

    var headline: HeadlineStory
    var secondaryStories: [NewspaperStory]
    var characterFateReport: CharacterFateReport?
    var internationalNews: String?
    var propagandaPiece: String?

    var generatedAt: Date

    init(
        turnNumber: Int,
        publicationDate: String,
        publicationName: String = "The People's Voice",
        publicationType: PublicationType = .state,
        headline: HeadlineStory,
        secondaryStories: [NewspaperStory] = [],
        characterFateReport: CharacterFateReport? = nil,
        internationalNews: String? = nil,
        propagandaPiece: String? = nil
    ) {
        self.id = UUID()
        self.turnNumber = turnNumber
        self.publicationDate = publicationDate
        self.publicationName = publicationName
        self.publicationType = publicationType
        self.headline = headline
        self.secondaryStories = secondaryStories
        self.characterFateReport = characterFateReport
        self.internationalNews = internationalNews
        self.propagandaPiece = propagandaPiece
        self.generatedAt = Date()
    }
}

// MARK: - Headline Story

struct HeadlineStory: Codable, Identifiable, Sendable {
    var id: UUID
    var headline: String
    var subheadline: String?
    var body: String
    var category: HeadlineCategory

    init(
        headline: String,
        subheadline: String? = nil,
        body: String,
        category: HeadlineCategory = .political
    ) {
        self.id = UUID()
        self.headline = headline
        self.subheadline = subheadline
        self.body = body
        self.category = category
    }
}

enum HeadlineCategory: String, Codable, CaseIterable, Sendable {
    case political       // Party congress, leadership changes
    case economic        // Production quotas, industrial achievements
    case military        // Defense matters, Warsaw Pact
    case international   // Cold War, foreign relations
    case domestic        // Internal affairs, social programs
    case ideological     // Marxist-Leninist theory, campaigns
}

// MARK: - Secondary Story

struct NewspaperStory: Codable, Identifiable, Sendable {
    var id: UUID
    var headline: String
    var brief: String
    var importance: Int  // 1-5, affects placement

    init(headline: String, brief: String, importance: Int = 3) {
        self.id = UUID()
        self.headline = headline
        self.brief = brief
        self.importance = importance
    }
}

// MARK: - Character Fate Report

struct CharacterFateReport: Codable, Identifiable, Sendable {
    var id: UUID
    var characterName: String
    var characterTitle: String?
    var fateType: CharacterFateType
    var euphemism: String           // "reassigned to agricultural duties"
    var fullReport: String          // Longer description
    var isRehabilitating: Bool      // Mark if this is a rehabilitation notice

    init(
        characterName: String,
        characterTitle: String? = nil,
        fateType: CharacterFateType,
        euphemism: String,
        fullReport: String,
        isRehabilitating: Bool = false
    ) {
        self.id = UUID()
        self.characterName = characterName
        self.characterTitle = characterTitle
        self.fateType = fateType
        self.euphemism = euphemism
        self.fullReport = fullReport
        self.isRehabilitating = isRehabilitating
    }
}

enum CharacterFateType: String, Codable, CaseIterable, Sendable {
    case promoted
    case reassigned           // Demotion disguised
    case retired              // Forced retirement
    case underInvestigation   // NKVD/CCDI attention
    case arrested
    case executed
    case disappeared
    case exiled
    case rehabilitated        // Restored (can be posthumous)
    case died                 // Natural or "natural"

    /// Euphemistic Soviet/CCP-style description
    var displayEuphemism: String {
        switch self {
        case .promoted:
            return "elevated to new responsibilities"
        case .reassigned:
            return "transferred to other work"
        case .retired:
            return "released for health reasons"
        case .underInvestigation:
            return "assisting with inquiries"
        case .arrested:
            return "detained for questioning"
        case .executed:
            return "convicted of crimes against the state"
        case .disappeared:
            return "whereabouts unknown"
        case .exiled:
            return "sent to assist regional development"
        case .rehabilitated:
            return "errors in previous judgment corrected"
        case .died:
            return "passed away after illness"
        }
    }

    /// Whether this fate type should be displayed prominently
    var isPermanent: Bool {
        switch self {
        case .executed, .died, .exiled:
            return true
        default:
            return false
        }
    }

    /// Whether this person might return
    var canReturn: Bool {
        switch self {
        case .reassigned, .retired, .underInvestigation, .arrested, .disappeared, .exiled, .rehabilitated:
            return true
        case .promoted, .executed, .died:
            return false
        }
    }
}

// MARK: - Newspaper Configuration (per-campaign)

struct NewspaperConfig: Codable, Sendable {
    var publicationName: String        // "The People's Voice", "People's Daily"
    var masthead: String?              // Motto/slogan under name
    var dateFormat: String             // How dates appear
    var currency: String               // For economic stories
    var leaderTitle: String            // "Comrade General Secretary"

    static var psra: NewspaperConfig {
        NewspaperConfig(
            publicationName: "The People's Voice",
            masthead: "Organ of the Central Committee of the Communist Party of America",
            dateFormat: "MMMM d, yyyy",
            currency: "dollars",
            leaderTitle: "Comrade General Secretary"
        )
    }

    static var ccp: NewspaperConfig {
        NewspaperConfig(
            publicationName: "People's Daily",
            masthead: "Organ of the CPC Central Committee",
            dateFormat: "yyyy年M月d日",
            currency: "yuan",
            leaderTitle: "General Secretary"
        )
    }
}
