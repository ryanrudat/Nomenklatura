//
//  TrackAffinity.swift
//  Nomenklatura
//
//  Track affinity system for organic career path discovery
//

import Foundation

// MARK: - Expanded Career Tracks (6 Specialized + Shared)

enum ExpandedCareerTrack: String, Codable, CaseIterable, Sendable {
    case shared             // Positions before branching (entry) and after merging (top)
    case partyApparatus     // Ideology, personnel, doctrine - Central Committee path
    case stateMinistry      // Council of Ministers, governance - state administration
    case securityServices   // BPS, intelligence, surveillance - security apparatus
    case foreignAffairs     // Diplomacy, international relations - MFA path
    case economicPlanning   // Gosplan, industry, production - economic management
    case militaryPolitical  // Army political officers, defense - MPA path
    case regional           // Provincial/Republic assignments - stepping stones

    var displayName: String {
        switch self {
        case .shared: return "Party"
        case .partyApparatus: return "Party Apparatus"
        case .stateMinistry: return "State Ministry"
        case .securityServices: return "Security Services"
        case .foreignAffairs: return "Foreign Affairs"
        case .economicPlanning: return "Economic Planning"
        case .militaryPolitical: return "Military-Political"
        case .regional: return "Regional"
        }
    }

    var shortName: String {
        switch self {
        case .shared: return "Party"
        case .partyApparatus: return "CC"
        case .stateMinistry: return "CoM"
        case .securityServices: return "BPS"
        case .foreignAffairs: return "MFA"
        case .economicPlanning: return "Gosplan"
        case .militaryPolitical: return "MPA"
        case .regional: return "Region"
        }
    }

    var description: String {
        switch self {
        case .shared:
            return "The common path all Party members travel"
        case .partyApparatus:
            return "The beating heart of the Party - ideology, cadre selection, and doctrinal purity"
        case .stateMinistry:
            return "The machinery of the state - ministries, administration, and governance"
        case .securityServices:
            return "The sword and shield - intelligence, surveillance, and state security"
        case .foreignAffairs:
            return "The voice of the nation - diplomacy, treaties, and international relations"
        case .economicPlanning:
            return "The architects of socialism - Gosplan, quotas, and industrial strategy"
        case .militaryPolitical:
            return "The political soul of the army - commissars, loyalty, and defense policy"
        case .regional:
            return "The distant provinces - where you build your own power base"
        }
    }

    var primaryStat: String {
        switch self {
        case .shared: return "standing"
        case .partyApparatus: return "eliteLoyalty"
        case .stateMinistry: return "stability"
        case .securityServices: return "network"
        case .foreignAffairs: return "internationalStanding"
        case .economicPlanning: return "industrialOutput"
        case .militaryPolitical: return "militaryLoyalty"
        case .regional: return "standing"
        }
    }

    var iconName: String {
        switch self {
        case .shared: return "star.fill"
        case .partyApparatus: return "building.columns.fill"
        case .stateMinistry: return "doc.text.fill"
        case .securityServices: return "shield.fill"
        case .foreignAffairs: return "globe"
        case .economicPlanning: return "chart.bar.fill"
        case .militaryPolitical: return "star.circle.fill"
        case .regional: return "map.fill"
        }
    }

    /// Whether this track has an apex badge position
    var hasApexPosition: Bool {
        switch self {
        case .shared, .regional: return false
        default: return true
        }
    }

    /// The apex badge name for this track
    var apexBadgeName: String? {
        switch self {
        case .partyApparatus: return "Party's Conscience"
        case .stateMinistry: return "Master of the State"
        case .securityServices: return "Sword and Shield"
        case .foreignAffairs: return "Voice of the Nation"
        case .economicPlanning: return "Architect of Socialism"
        case .militaryPolitical: return "Guardian of the Army"
        default: return nil
        }
    }
}

// MARK: - Track Affinity Scores

struct TrackAffinityScores: Sendable {
    var partyApparatus: Int = 0
    var stateMinistry: Int = 0
    var securityServices: Int = 0
    var foreignAffairs: Int = 0
    var economicPlanning: Int = 0
    var militaryPolitical: Int = 0

    // Explicit nonisolated Codable conformance for Swift 6 compatibility
    private enum CodingKeys: String, CodingKey {
        case partyApparatus, stateMinistry, securityServices
        case foreignAffairs, economicPlanning, militaryPolitical
    }
}

extension TrackAffinityScores: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        partyApparatus = try container.decodeIfPresent(Int.self, forKey: .partyApparatus) ?? 0
        stateMinistry = try container.decodeIfPresent(Int.self, forKey: .stateMinistry) ?? 0
        securityServices = try container.decodeIfPresent(Int.self, forKey: .securityServices) ?? 0
        foreignAffairs = try container.decodeIfPresent(Int.self, forKey: .foreignAffairs) ?? 0
        economicPlanning = try container.decodeIfPresent(Int.self, forKey: .economicPlanning) ?? 0
        militaryPolitical = try container.decodeIfPresent(Int.self, forKey: .militaryPolitical) ?? 0
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(partyApparatus, forKey: .partyApparatus)
        try container.encode(stateMinistry, forKey: .stateMinistry)
        try container.encode(securityServices, forKey: .securityServices)
        try container.encode(foreignAffairs, forKey: .foreignAffairs)
        try container.encode(economicPlanning, forKey: .economicPlanning)
        try container.encode(militaryPolitical, forKey: .militaryPolitical)
    }
}

extension TrackAffinityScores {
    /// Returns the track with highest affinity if it meets threshold
    var dominantTrack: ExpandedCareerTrack? {
        let scores = [
            (ExpandedCareerTrack.partyApparatus, partyApparatus),
            (ExpandedCareerTrack.stateMinistry, stateMinistry),
            (ExpandedCareerTrack.securityServices, securityServices),
            (ExpandedCareerTrack.foreignAffairs, foreignAffairs),
            (ExpandedCareerTrack.economicPlanning, economicPlanning),
            (ExpandedCareerTrack.militaryPolitical, militaryPolitical)
        ].sorted { $0.1 > $1.1 }

        guard let highest = scores.first, highest.1 > 0 else { return nil }
        let second = scores.dropFirst().first?.1 ?? 0

        // Dominant if:
        // - Score >= 25 (clear preference), OR
        // - Score >= 15 AND 10+ points ahead of second place (emerging preference)
        if highest.1 >= 25 {
            return highest.0
        } else if highest.1 >= 15 && (highest.1 - second) >= 10 {
            return highest.0
        }

        return nil
    }

    /// Get score for a specific track
    func score(for track: ExpandedCareerTrack) -> Int {
        switch track {
        case .partyApparatus: return partyApparatus
        case .stateMinistry: return stateMinistry
        case .securityServices: return securityServices
        case .foreignAffairs: return foreignAffairs
        case .economicPlanning: return economicPlanning
        case .militaryPolitical: return militaryPolitical
        default: return 0
        }
    }

    /// Set score for a specific track
    mutating func setScore(for track: ExpandedCareerTrack, value: Int) {
        switch track {
        case .partyApparatus: partyApparatus = value
        case .stateMinistry: stateMinistry = value
        case .securityServices: securityServices = value
        case .foreignAffairs: foreignAffairs = value
        case .economicPlanning: economicPlanning = value
        case .militaryPolitical: militaryPolitical = value
        default: break
        }
    }

    /// Add to a specific track's score
    mutating func addScore(for track: ExpandedCareerTrack, amount: Int) {
        let current = score(for: track)
        setScore(for: track, value: current + amount)
    }

    /// Get all scores as array for display
    var allScores: [(track: ExpandedCareerTrack, score: Int)] {
        [
            (.partyApparatus, partyApparatus),
            (.stateMinistry, stateMinistry),
            (.securityServices, securityServices),
            (.foreignAffairs, foreignAffairs),
            (.economicPlanning, economicPlanning),
            (.militaryPolitical, militaryPolitical)
        ].sorted { $0.score > $1.score }
    }

    /// Total affinity accumulated across all tracks
    var totalAffinity: Int {
        partyApparatus + stateMinistry + securityServices + foreignAffairs + economicPlanning + militaryPolitical
    }
}

// MARK: - Affinity Signal

/// Represents a signal that affects track affinity
struct AffinitySignal: Codable, Identifiable, Sendable {
    var id: String = UUID().uuidString
    var trackAffected: ExpandedCareerTrack
    var amount: Int
    var source: AffinitySource
    var description: String
    var turnOccurred: Int

    enum AffinitySource: String, Codable {
        case scenarioChoice      // Player chose an option with track affinity
        case personalAction      // Player took a personal action
        case statEffect          // Stats moved in track-relevant direction
        case characterInteraction // Interaction with track-relevant character
        case positionHeld        // Currently holding a track position
    }
}

// MARK: - Option Archetype

/// Archetypes that map scenario options to track affinities
enum OptionArchetype: String, Codable, CaseIterable {
    // Original archetypes (backwards compatible)
    case repress           // Use force, surveillance, intimidation → Security
    case appease           // Compromise, give concessions → State Ministry
    case deflect           // Redirect blame, avoid responsibility → Party Apparatus
    case reform            // Economic reforms, modernization → Economic Planning
    case attack            // Aggressive action → Security/Military
    case negotiate         // Diplomatic solutions, compromise → Foreign Affairs
    case delay             // Wait and see, postpone → State Ministry
    case sacrifice         // Accept losses for greater good → Party Apparatus

    // Extended archetypes for track affinity
    case investigate       // Launch investigations, gather intel → Security
    case surveil           // Monitor, spy, gather information → Security
    case international     // Engage with foreign powers → Foreign Affairs
    case trade             // Economic diplomacy, agreements → Foreign Affairs
    case production        // Focus on quotas, output → Economic
    case allocate          // Resource distribution decisions → Economic
    case military          // Military solutions, defense focus → Military-Political
    case loyalty           // Political education, army morale → Military-Political
    case mobilize          // Troop movements, military action → Military-Political
    case ideological       // Doctrinal purity, propaganda → Party Apparatus
    case personnel         // Appointments, cadre selection → Party Apparatus
    case orthodox          // Follow party line strictly → Party Apparatus
    case administrative    // Bureaucratic solutions → State Ministry
    case governance        // State administration focus → State Ministry
    case regulate          // Rules, procedures, compliance → State Ministry

    var displayName: String {
        switch self {
        case .repress: return "Crackdown"
        case .appease: return "Appease"
        case .deflect: return "Deflect"
        case .reform: return "Reform"
        case .attack: return "Attack"
        case .negotiate: return "Negotiate"
        case .delay: return "Delay"
        case .sacrifice: return "Sacrifice"
        case .investigate: return "Investigate"
        case .surveil: return "Surveil"
        case .international: return "International"
        case .trade: return "Trade"
        case .production: return "Production"
        case .allocate: return "Allocate"
        case .military: return "Military"
        case .loyalty: return "Loyalty"
        case .mobilize: return "Mobilize"
        case .ideological: return "Ideological"
        case .personnel: return "Personnel"
        case .orthodox: return "Orthodox"
        case .administrative: return "Administrative"
        case .governance: return "Governance"
        case .regulate: return "Regulate"
        }
    }

    /// The track this archetype signals affinity for
    var associatedTrack: ExpandedCareerTrack? {
        switch self {
        case .repress, .investigate, .surveil, .attack:
            return .securityServices
        case .negotiate, .international, .trade:
            return .foreignAffairs
        case .reform, .production, .allocate:
            return .economicPlanning
        case .military, .loyalty, .mobilize:
            return .militaryPolitical
        case .ideological, .personnel, .orthodox, .deflect, .sacrifice:
            return .partyApparatus
        case .administrative, .governance, .regulate, .appease, .delay:
            return .stateMinistry
        }
    }

    /// How much affinity this archetype grants
    var affinityAmount: Int {
        switch self {
        case .repress, .negotiate, .reform, .military, .ideological, .administrative, .attack:
            return 3  // Strong signal
        case .investigate, .international, .production, .loyalty, .personnel, .governance, .appease, .sacrifice:
            return 2  // Medium signal
        case .surveil, .trade, .allocate, .mobilize, .orthodox, .regulate, .deflect, .delay:
            return 1  // Weak signal
        }
    }
}

// MARK: - Track Commitment Status

enum TrackCommitmentStatus: String, Codable, Sendable {
    case uncommitted      // Player hasn't specialized yet
    case emerging         // Clear preference emerging, not locked
    case committed        // Player has chosen/been assigned to a track
    case multiTrack       // Player has demonstrated proficiency in multiple tracks
}
