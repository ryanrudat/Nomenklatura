//
//  CampaignConfig.swift
//  Nomenklatura
//
//  Campaign configuration models loaded from JSON
//

import Foundation

// MARK: - Campaign Configuration

struct CampaignConfig: Codable, Identifiable {
    var id: String
    var name: String
    var era: String
    var description: String

    var nationName: String
    var leaderTitle: String
    var currencyName: String?

    var startingPosition: Int
    var startingStats: StartingStats
    var startingPersonalStats: StartingPersonalStats

    var tone: String
    var toneKeywords: [String]
    var avoidKeywords: [String]

    var factions: [FactionConfig]
    var ladder: [LadderPosition]
    var startingCharacters: [CharacterTemplate]
    var personalActions: [PersonalAction]

    // Multi-era support
    var terminology: CampaignTerminology?
    var screenLabels: ScreenLabels?
    var statNameOverrides: [String: String]?
    var themeId: String?
    var newspaperConfig: NewspaperConfig?

    // Player faction selection
    var playerFactions: [PlayerFactionConfig]?

    // Leadership dynamics configuration
    var leadershipConfig: LeadershipConfig?
}

// MARK: - Leadership Configuration

/// Configures the power dynamics between the General Secretary and Standing Committee
struct LeadershipConfig: Codable {
    /// How much power the GS has relative to the SC (0.0-1.0)
    /// 0.0 = Pure collective leadership (SC can override GS)
    /// 0.5 = Balanced (GS leads but needs SC consensus)
    /// 1.0 = Near-absolute (GS can override SC, Xi Jinping style)
    var generalSecretaryPower: Double = 0.5

    /// GS vote weight in SC decisions (1 = normal, 2 = double, 3 = triple)
    var gsVoteWeight: Int = 1

    /// Can GS issue decrees without SC vote?
    var gsCanDecree: Bool = true

    /// Political capital cost multiplier for decrees (higher = more expensive)
    var decreeCostMultiplier: Double = 1.5

    /// Frequency of SC meetings in turns (default: every 5 turns)
    var meetingFrequency: Int = 5

    /// Minimum agenda items required to convene a meeting
    var minimumAgendaItems: Int = 1

    /// Can SC override GS decisions?
    var scCanOverrideGs: Bool = true

    /// Threshold for SC to override GS (votes needed as fraction of total members)
    var overrideThreshold: Double = 0.75

    static var collectiveLeadership: LeadershipConfig {
        LeadershipConfig(
            generalSecretaryPower: 0.3,
            gsVoteWeight: 1,
            gsCanDecree: false,
            decreeCostMultiplier: 2.0,
            meetingFrequency: 4,
            minimumAgendaItems: 1,
            scCanOverrideGs: true,
            overrideThreshold: 0.6
        )
    }

    static var strongLeader: LeadershipConfig {
        LeadershipConfig(
            generalSecretaryPower: 0.8,
            gsVoteWeight: 2,
            gsCanDecree: true,
            decreeCostMultiplier: 1.0,
            meetingFrequency: 6,
            minimumAgendaItems: 2,
            scCanOverrideGs: true,
            overrideThreshold: 0.9
        )
    }

    static var absoluteLeader: LeadershipConfig {
        LeadershipConfig(
            generalSecretaryPower: 1.0,
            gsVoteWeight: 3,
            gsCanDecree: true,
            decreeCostMultiplier: 0.5,
            meetingFrequency: 8,
            minimumAgendaItems: 3,
            scCanOverrideGs: false,
            overrideThreshold: 1.0
        )
    }
}

// MARK: - Starting Stats

struct StartingStats: Codable {
    var stability: Int
    var popularSupport: Int
    var militaryLoyalty: Int
    var eliteLoyalty: Int
    var treasury: Int
    var industrialOutput: Int
    var foodSupply: Int
    var internationalStanding: Int
}

struct StartingPersonalStats: Codable {
    var standing: Int
    var patronFavor: Int
    var rivalThreat: Int
    var network: Int
}

// MARK: - Faction Configuration

struct FactionConfig: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var startingPower: Int
    var startingPlayerStanding: Int
}

// MARK: - Ladder Position

struct LadderPosition: Codable, Identifiable {
    var id: String { "\(expandedTrack.rawValue)_\(index)" }
    var index: Int
    var track: CareerTrack                  // Legacy simple track (shared, capital, regional)
    var expandedTrack: ExpandedCareerTrack  // New 6-track system
    var title: String
    var description: String
    var requiredStanding: Int
    var requiredPatronFavor: Int?
    var requiredNetwork: Int?
    var requiredFactionSupport: [String: Int]?
    var maxHolders: Int
    var unlockedActions: [String]
    var canBranchTo: [String]?              // IDs of positions player can transfer to
    var canReceiveOffersFrom: [String]?     // Character IDs who can offer this position
    var requiredAffinityScore: Int?         // Minimum track affinity to be offered
    var isApexPosition: Bool                // Is this the top of a track?
    var minimumTurnsInPosition: Int?        // Minimum turns player must serve before next promotion

    // Support decoding without track for backwards compatibility
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.index = try container.decode(Int.self, forKey: .index)
        self.track = try container.decodeIfPresent(CareerTrack.self, forKey: .track) ?? .shared
        self.expandedTrack = try container.decodeIfPresent(ExpandedCareerTrack.self, forKey: .expandedTrack) ?? .shared
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decode(String.self, forKey: .description)
        self.requiredStanding = try container.decode(Int.self, forKey: .requiredStanding)
        self.requiredPatronFavor = try container.decodeIfPresent(Int.self, forKey: .requiredPatronFavor)
        self.requiredNetwork = try container.decodeIfPresent(Int.self, forKey: .requiredNetwork)
        self.requiredFactionSupport = try container.decodeIfPresent([String: Int].self, forKey: .requiredFactionSupport)
        self.maxHolders = try container.decode(Int.self, forKey: .maxHolders)
        self.unlockedActions = try container.decode([String].self, forKey: .unlockedActions)
        self.canBranchTo = try container.decodeIfPresent([String].self, forKey: .canBranchTo)
        self.canReceiveOffersFrom = try container.decodeIfPresent([String].self, forKey: .canReceiveOffersFrom)
        self.requiredAffinityScore = try container.decodeIfPresent(Int.self, forKey: .requiredAffinityScore)
        self.isApexPosition = try container.decodeIfPresent(Bool.self, forKey: .isApexPosition) ?? false
        self.minimumTurnsInPosition = try container.decodeIfPresent(Int.self, forKey: .minimumTurnsInPosition)
    }

    private enum CodingKeys: String, CodingKey {
        case index, track, expandedTrack, title, description, requiredStanding
        case requiredPatronFavor, requiredNetwork, requiredFactionSupport
        case maxHolders, unlockedActions, canBranchTo
        case canReceiveOffersFrom, requiredAffinityScore, isApexPosition
        case minimumTurnsInPosition
    }

    init(
        index: Int,
        track: CareerTrack = .shared,
        expandedTrack: ExpandedCareerTrack = .shared,
        title: String,
        description: String,
        requiredStanding: Int,
        requiredPatronFavor: Int? = nil,
        requiredNetwork: Int? = nil,
        requiredFactionSupport: [String: Int]? = nil,
        maxHolders: Int,
        unlockedActions: [String],
        canBranchTo: [String]? = nil,
        canReceiveOffersFrom: [String]? = nil,
        requiredAffinityScore: Int? = nil,
        isApexPosition: Bool = false
    ) {
        self.index = index
        self.track = track
        self.expandedTrack = expandedTrack
        self.title = title
        self.description = description
        self.requiredStanding = requiredStanding
        self.requiredPatronFavor = requiredPatronFavor
        self.requiredNetwork = requiredNetwork
        self.requiredFactionSupport = requiredFactionSupport
        self.maxHolders = maxHolders
        self.unlockedActions = unlockedActions
        self.canBranchTo = canBranchTo
        self.canReceiveOffersFrom = canReceiveOffersFrom
        self.requiredAffinityScore = requiredAffinityScore
        self.isApexPosition = isApexPosition
    }
}

// MARK: - Character Template

struct CharacterTemplate: Codable, Identifiable {
    var id: String
    var name: String
    var title: String
    var role: String
    var positionIndex: Int?
    var positionTrack: String?  // Explicit track assignment (e.g., "securityServices", "regional")
    var personality: CharacterPersonality
    var speechPattern: String
    var factionId: String?
    var isPatron: Bool
    var isRival: Bool
    var startingDisposition: Int

    // Lore System Fields
    var backstory: String?                      // Character's personal history
    var ageCategory: String?                    // "elderly", "middle-aged", "young", "very young"
    var originLocation: String?                 // Where they came from
    var familyBackground: String?               // Family details
    var secrets: [CharacterSecretTemplate]?     // Tiered secrets
    var relationships: [CharacterRelationshipTemplate]?  // Pre-existing connections
    var historicalConnections: [String]?        // Links to historical events/founders
}

/// Template for character secrets
struct CharacterSecretTemplate: Codable {
    var title: String
    var content: String
    var tier: String                            // "discoverable" or "narrativeOnly"
    var category: String                        // crime, betrayal, corruption, etc.
    var canBeUsedAsLeverage: Bool
    var associatedCharacterIds: [String]
    var historicalEventId: String?
}

/// Template for character relationships
struct CharacterRelationshipTemplate: Codable {
    var targetCharacterId: String
    var targetCharacterName: String
    var relationshipType: String                // family, mentor, warComrade, etc.
    var description: String
    var sentiment: Int
    var historicalOrigin: String?
}

// MARK: - Campaign Terminology

struct CampaignTerminology: Codable {
    var leader: String            // "General Secretary" / "Chairman"
    var party: String             // "The Party" / "People's Worker Party"
    var comrade: String           // "Comrade" / "Tongzhi"
    var purge: String             // "Purge" / "Shuanggui"
    var enemy: String             // "Counter-revolutionary" / "Two-faced person"
    var investigation: String     // "NKVD Investigation" / "CCDI Review"
    var loyaltyOrgan: String      // "State Security" / "Central Commission for Discipline Inspection"
    var succession: String        // "Succession" / "Leadership transition"

    static var soviet: CampaignTerminology {
        CampaignTerminology(
            leader: "General Secretary",
            party: "The Party",
            comrade: "Comrade",
            purge: "Purge",
            enemy: "counter-revolutionary",
            investigation: "NKVD Investigation",
            loyaltyOrgan: "State Security",
            succession: "succession"
        )
    }

    static var ccp: CampaignTerminology {
        CampaignTerminology(
            leader: "General Secretary",
            party: "People's Worker Party",
            comrade: "Tongzhi",
            purge: "Shuanggui",
            enemy: "two-faced person",
            investigation: "CCDI Review",
            loyaltyOrgan: "Central Commission for Discipline Inspection",
            succession: "leadership transition"
        )
    }

    /// Socialist terminology for the PSR
    static var american: CampaignTerminology {
        CampaignTerminology(
            leader: "General Secretary",
            party: "The Party",
            comrade: "Comrade",
            purge: "Purge",
            enemy: "counter-revolutionary",
            investigation: "BPS Investigation",
            loyaltyOrgan: "Bureau of People's Security",
            succession: "succession"
        )
    }
}

// MARK: - Screen Labels

struct ScreenLabels: Codable {
    var deskTitle: String         // "The Desk" / "The Office"
    var deskSubtitle: String      // "The Apparatus" / "Standing Committee"
    var ladderTitle: String       // "The Ladder" / "Party Hierarchy"
    var dossierTitle: String      // "The Dossier" / "Personnel Files"
    var ledgerTitle: String       // "The Ledger" / "State of Affairs"
    var fallenTitle: String       // "FALLEN" / "REMOVED"

    static var soviet: ScreenLabels {
        ScreenLabels(
            deskTitle: "The Desk",
            deskSubtitle: "The Apparatus",
            ladderTitle: "The Ladder",
            dossierTitle: "The Dossier",
            ledgerTitle: "The Ledger",
            fallenTitle: "FALLEN"
        )
    }

    static var ccp: ScreenLabels {
        ScreenLabels(
            deskTitle: "The Office",
            deskSubtitle: "Standing Committee",
            ladderTitle: "Party Hierarchy",
            dossierTitle: "Personnel Files",
            ledgerTitle: "State of Affairs",
            fallenTitle: "REMOVED"
        )
    }

    /// Socialist screen labels for the PSR
    static var american: ScreenLabels {
        ScreenLabels(
            deskTitle: "The Desk",
            deskSubtitle: "People's Congress",
            ladderTitle: "The Ladder",
            dossierTitle: "The Dossier",
            ledgerTitle: "The Ledger",
            fallenTitle: "FALLEN"
        )
    }
}

// MARK: - Campaign Loader

class CampaignLoader {
    static let shared = CampaignLoader()

    private var loadedCampaigns: [String: CampaignConfig] = [:]

    func loadCampaign(id: String) -> CampaignConfig? {
        // Check cache first
        if let cached = loadedCampaigns[id] {
            return cached
        }

        // Load from bundle
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Data/Campaigns") else {
            // Try without subdirectory (for flat bundle)
            guard let flatUrl = Bundle.main.url(forResource: id, withExtension: "json") else {
                #if DEBUG
                print("Campaign file not found: \(id).json")
                #endif
                return nil
            }
            return loadFromURL(flatUrl, id: id)
        }

        return loadFromURL(url, id: id)
    }

    private func loadFromURL(_ url: URL, id: String) -> CampaignConfig? {
        do {
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(CampaignConfig.self, from: data)
            loadedCampaigns[id] = config
            return config
        } catch {
            #if DEBUG
            print("Failed to load campaign \(id): \(error)")
            #endif
            return nil
        }
    }

    /// Returns the Cold War campaign with hardcoded data as fallback
    func getColdWarCampaign() -> CampaignConfig {
        if let loaded = loadCampaign(id: "coldwar") {
            return loaded
        }

        // Fallback to hardcoded config
        return createColdWarConfig()
    }

    private func createColdWarConfig() -> CampaignConfig {
        CampaignConfig(
            id: "coldwar",
            name: "Nomenklatura",
            era: "Cold War Era",
            description: "You are a cog in the Party machine. Survive purges, outmaneuver rivals, and climb the ranks of the nomenklatura toward ultimate power.",
            nationName: "The People's Socialist Republic",
            leaderTitle: "General Secretary",
            currencyName: "rubles",
            startingPosition: 1,
            startingStats: StartingStats(
                stability: 50,
                popularSupport: 50,
                militaryLoyalty: 60,
                eliteLoyalty: 55,
                treasury: 55,  // Increased from 45 to give more starting room
                industrialOutput: 50,
                foodSupply: 45,  // Slightly increased from 40
                internationalStanding: 50
            ),
            startingPersonalStats: StartingPersonalStats(
                standing: 20,
                patronFavor: 50,
                rivalThreat: 30,
                network: 10
            ),
            tone: "grim_bureaucratic",
            toneKeywords: ["comrade", "party", "socialism", "counter-revolutionary", "politburo", "quota", "collective", "struggle"],
            avoidKeywords: ["democracy", "freedom", "election", "vote", "parliament", "congress"],
            factions: [
                FactionConfig(id: "youth_league", name: "Youth League", description: "The meritocrats who rose through competence and dedication.", startingPower: 55, startingPlayerStanding: 50),
                FactionConfig(id: "princelings", name: "Princelings", description: "Red aristocracy - descendants of revolutionary heroes.", startingPower: 70, startingPlayerStanding: 45),
                FactionConfig(id: "reformists", name: "Reformists", description: "Pragmatists who believe in progress through careful change.", startingPower: 50, startingPlayerStanding: 55),
                FactionConfig(id: "old_guard", name: "Proletariat Union", description: "The labor unions that sparked the Revolution and guard its ideals.", startingPower: 65, startingPlayerStanding: 40),
                FactionConfig(id: "regional", name: "People's Provincial Administration", description: "Zone governors and Labour Council networks - power built far from Washington.", startingPower: 60, startingPlayerStanding: 50)
            ],
            ladder: createExpandedLadder(),
            startingCharacters: createStartingCharacters(),
            personalActions: createColdWarActions(),
            playerFactions: PlayerFactionConfig.allFactions
        )
    }

    private func createColdWarActions() -> [PersonalAction] {
        [
            PersonalAction(id: "plant_ally_security", category: .buildNetwork, title: "Plant ally in State Protection", description: "Cultivate an informant in Wallace's department.", costAP: 1, riskLevel: .medium, requirements: ActionRequirements(minStanding: 25), effects: ["network": 5], isLocked: false, lockReason: nil),
            PersonalAction(id: "cultivate_military", category: .buildNetwork, title: "Cultivate military contact", description: "Build relationship with junior officers.", costAP: 1, riskLevel: .low, requirements: nil, effects: ["network": 3], isLocked: false, lockReason: nil),
            PersonalAction(id: "gather_intel_rival", category: .buildNetwork, title: "Gather intelligence on Kovacs", description: "Learn your rival's secrets and weaknesses.", costAP: 1, riskLevel: .medium, requirements: ActionRequirements(minNetwork: 15), effects: ["network": 2, "rivalThreat": -5], isLocked: false, lockReason: nil),
            PersonalAction(id: "leak_failures", category: .undermineRivals, title: "Leak rival's failures to the press office", description: "Anonymously expose Kovacs's production shortfalls.", costAP: 2, riskLevel: .high, requirements: ActionRequirements(minNetwork: 20), effects: ["rivalThreat": -15, "reputationCunning": 10], isLocked: false, lockReason: nil),
            PersonalAction(id: "frame_conspiracy", category: .undermineRivals, title: "Implicate rival in conspiracy", description: "Plant evidence suggesting Kovacs has foreign contacts.", costAP: 2, riskLevel: .high, requirements: ActionRequirements(minStanding: 50, minNetwork: 40), effects: ["rivalThreat": -25, "reputationRuthless": 15], isLocked: false, lockReason: nil),
            PersonalAction(id: "private_meeting_secretary", category: .securePosition, title: "Private meeting with General Secretary", description: "Request a one-on-one audience to demonstrate loyalty.", costAP: 1, riskLevel: .low, requirements: ActionRequirements(minStanding: 40), effects: ["patronFavor": 5, "reputationLoyal": 5], isLocked: false, lockReason: nil),
            PersonalAction(id: "public_praise_patron", category: .securePosition, title: "Publicly praise your patron", description: "Give a speech crediting Wallace for recent successes.", costAP: 1, riskLevel: .low, requirements: nil, effects: ["patronFavor": 8, "standing": -3], isLocked: false, lockReason: nil),
            PersonalAction(id: "prepare_dossier", category: .securePosition, title: "Prepare defensive dossier", description: "Compile evidence of your loyalty and achievements.", costAP: 1, riskLevel: .low, requirements: nil, effects: ["network": 2], isLocked: false, lockReason: nil),
            PersonalAction(id: "propose_promotion", category: .makeYourPlay, title: "Propose yourself for Department Head", description: "Request promotion when a vacancy opens.", costAP: 2, riskLevel: .medium, requirements: ActionRequirements(minStanding: 65, minPatronFavor: 60, vacancyRequired: true), effects: ["standing": 10], isLocked: true, lockReason: "Requires Standing 65+, Patron Favor 60+, and a vacancy"),
            PersonalAction(id: "challenge_rival", category: .makeYourPlay, title: "Challenge Kovacs at Standing Committee", description: "Publicly expose his failures and demand his removal.", costAP: 2, riskLevel: .high, requirements: ActionRequirements(minStanding: 70, minNetwork: 50, requiredFlags: ["kovacs_weakness_known"]), effects: ["rivalThreat": -30, "standing": 15, "reputationRuthless": 10], isLocked: true, lockReason: "Requires Standing 70+, Network 50+, and intelligence on Kovacs"),
            PersonalAction(id: "begin_coup", category: .makeYourPlay, title: "Begin coup preparations", description: "Sound out military leaders about removing the General Secretary.", costAP: 2, riskLevel: .high, requirements: ActionRequirements(minStanding: 85, minNetwork: 70, requiredFactionSupport: ["princelings": 70]), effects: ["network": -20], isLocked: true, lockReason: "Requires Standing 85+, Network 70+, Princeling support 70+")
        ]
    }

    /// Creates the expanded 6-track career ladder
    private func createExpandedLadder() -> [LadderPosition] {
        var positions: [LadderPosition] = []

        // ============================================
        // TIER 0-1: SHARED ENTRY POSITIONS
        // ============================================

        positions.append(LadderPosition(
            index: 0, track: .shared, expandedTrack: .shared,
            title: "Party Official",
            description: "A minor functionary in the vast apparatus. You file reports, attend meetings, and wait for opportunity to knock.",
            requiredStanding: 0, maxHolders: 100, unlockedActions: []
        ))

        positions.append(LadderPosition(
            index: 1, track: .shared, expandedTrack: .shared,
            title: "Junior Party Official",
            description: "You have a seat at the table, but little influence. Your work will be noticed—your path forward branches from here.",
            requiredStanding: 15, maxHolders: 10,
            unlockedActions: ["attend_committee", "vote_policy"],
            canBranchTo: ["partyApparatus_2", "stateMinistry_2", "securityServices_2", "foreignAffairs_2", "economicPlanning_2", "militaryPolitical_2"]
        ))

        // ============================================
        // TIER 2-6: PARTY APPARATUS TRACK (Central Committee)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .partyApparatus,
            title: "Instructor of the Central Committee",
            description: "You monitor local Party organizations, report on cadre quality, and enforce doctrinal purity. The Party's eyes and ears.",
            requiredStanding: 35, requiredPatronFavor: 35,
            maxHolders: 8, unlockedActions: ["monitor_cadres", "report_deviations"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .partyApparatus,
            title: "Deputy Head of Central Committee Department",
            description: "You oversee personnel decisions for an entire sector of the Party. Appointments flow through your desk.",
            requiredStanding: 50, requiredPatronFavor: 45, requiredNetwork: 20,
            maxHolders: 5, unlockedActions: ["personnel_decisions", "approve_appointments"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .partyApparatus,
            title: "Head of Central Committee Department",
            description: "You control a major department—Organizational, Propaganda, or Administrative Affairs. The Party machine answers to you.",
            requiredStanding: 65, requiredPatronFavor: 55, requiredNetwork: 35,
            requiredFactionSupport: ["youth_league": 50],
            maxHolders: 3, unlockedActions: ["department_policy", "mass_appointments", "ideology_enforcement"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .partyApparatus,
            title: "Secretary of the Central Committee",
            description: "One of the Party's supreme authorities. You shape doctrine, control the apparatus, and whisper in the General Secretary's ear.",
            requiredStanding: 80, requiredNetwork: 50,
            requiredFactionSupport: ["youth_league": 65],
            maxHolders: 2, unlockedActions: ["cc_secretariat", "doctrine_revision", "purge_initiation"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .partyApparatus,
            title: "Second Secretary of the Central Committee",
            description: "The Party's conscience incarnate. You are the guardian of ideology, the keeper of personnel files, second only to the General Secretary in Party matters. Your influence may earn you a seat on the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 65,
            requiredFactionSupport: ["youth_league": 75],
            maxHolders: 1, unlockedActions: ["party_oversight", "succession_planning", "constitutional_interpretation"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-6: STATE MINISTRY TRACK (Council of Ministers)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .stateMinistry,
            title: "Deputy Minister",
            description: "You manage a division within a ministry. Paperwork flows endlessly, but so does information.",
            requiredStanding: 35, requiredPatronFavor: 30,
            maxHolders: 10, unlockedActions: ["ministry_administration", "budget_allocation"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .stateMinistry,
            title: "First Deputy Minister",
            description: "The minister's right hand. When they are absent, you speak with their authority.",
            requiredStanding: 50, requiredPatronFavor: 45, requiredNetwork: 20,
            maxHolders: 6, unlockedActions: ["acting_minister", "inter_ministry_coordination"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .stateMinistry,
            title: "Minister",
            description: "You lead a ministry of the People's Socialist Republic. Thousands work under your direction; millions depend on your decisions.",
            requiredStanding: 65, requiredPatronFavor: 55, requiredNetwork: 35,
            requiredFactionSupport: ["reformists": 45],
            maxHolders: 4, unlockedActions: ["ministerial_decree", "budget_control", "sector_policy"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .stateMinistry,
            title: "Deputy Chairman of the Council of Ministers",
            description: "One of the vice-premiers. You coordinate entire sectors of the economy and sit on the government's inner cabinet.",
            requiredStanding: 80, requiredNetwork: 50,
            requiredFactionSupport: ["reformists": 55, "youth_league": 50],
            maxHolders: 3, unlockedActions: ["cabinet_coordination", "economic_oversight", "state_planning"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .stateMinistry,
            title: "First Deputy Chairman of the Council of Ministers",
            description: "The premier's deputy and likely successor. You run the day-to-day operations of the state while the General Secretary handles Party affairs. Your stature may secure you a place on the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 65,
            requiredFactionSupport: ["reformists": 65, "youth_league": 60],
            maxHolders: 1, unlockedActions: ["state_direction", "crisis_management", "government_reorganization"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-6: SECURITY SERVICES TRACK (State Protection)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .securityServices,
            title: "Senior Investigator",
            description: "You conduct investigations into enemies of the state. Every file you open could make or break a career.",
            requiredStanding: 35, requiredPatronFavor: 35,
            maxHolders: 8, unlockedActions: ["investigate_target", "gather_evidence"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .securityServices,
            title: "Deputy Directorate Chief",
            description: "You oversee operations for an entire directorate—counter-intelligence, surveillance, or protection.",
            requiredStanding: 50, requiredPatronFavor: 50, requiredNetwork: 25,
            maxHolders: 5, unlockedActions: ["directorate_operations", "authorize_surveillance"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .securityServices,
            title: "Directorate Chief",
            description: "You command a major arm of State Protection. Your agents are everywhere; your files contain secrets that could destroy anyone.",
            requiredStanding: 65, requiredPatronFavor: 60, requiredNetwork: 40,
            requiredFactionSupport: ["old_guard": 55],
            maxHolders: 3, unlockedActions: ["mass_surveillance", "arrest_authority", "dossier_access"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .securityServices,
            title: "First Deputy Director of State Protection",
            description: "The director's shadow. You manage operations while they handle politics. The organs of state security obey your orders.",
            requiredStanding: 80, requiredNetwork: 55,
            requiredFactionSupport: ["old_guard": 65],
            maxHolders: 2, unlockedActions: ["security_operations", "special_investigations", "protection_details"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .securityServices,
            title: "Director of State Protection",
            description: "The sword and shield of the Party. You command the secret police, control the surveillance apparatus, and hold files on every leader in the nation. Such power often earns a seat on the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 70,
            requiredFactionSupport: ["old_guard": 75, "youth_league": 55],
            maxHolders: 1, unlockedActions: ["state_security_control", "political_protection", "enemy_elimination"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-6: FOREIGN AFFAIRS TRACK (Ministry of Foreign Affairs)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .foreignAffairs,
            title: "Embassy Counselor",
            description: "You serve in an embassy abroad, managing relations and gathering information. The outside world is your domain.",
            requiredStanding: 35, requiredPatronFavor: 30,
            maxHolders: 10, unlockedActions: ["diplomatic_report", "cultural_exchange"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .foreignAffairs,
            title: "Ambassador",
            description: "You represent the People's Socialist Republic to a foreign nation. Your words carry the weight of the state.",
            requiredStanding: 50, requiredPatronFavor: 45, requiredNetwork: 20,
            maxHolders: 6, unlockedActions: ["diplomatic_negotiation", "treaty_proposal"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .foreignAffairs,
            title: "Deputy Minister of Foreign Affairs",
            description: "You oversee entire regions of the world—the capitalist West, the socialist bloc, the developing nations.",
            requiredStanding: 65, requiredPatronFavor: 55, requiredNetwork: 35,
            maxHolders: 4, unlockedActions: ["regional_diplomacy", "bloc_coordination", "international_agreements"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .foreignAffairs,
            title: "First Deputy Minister of Foreign Affairs",
            description: "The foreign minister's alter ego. You handle the daily business of diplomacy while they attend summits and conferences.",
            requiredStanding: 80, requiredNetwork: 50,
            requiredFactionSupport: ["reformists": 50],
            maxHolders: 2, unlockedActions: ["foreign_policy_coordination", "crisis_diplomacy", "international_representation"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .foreignAffairs,
            title: "Minister of Foreign Affairs",
            description: "The voice of the nation to the world. You negotiate with superpowers, manage alliances, and shape the international order. Your global perspective may earn you a seat among the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 65,
            requiredFactionSupport: ["reformists": 60],
            maxHolders: 1, unlockedActions: ["international_policy", "summit_diplomacy", "treaty_authority"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-6: ECONOMIC PLANNING TRACK (State Planning Commission)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .economicPlanning,
            title: "Senior Economist",
            description: "You crunch the numbers that drive the planned economy. Quotas, allocations, projections—the future in spreadsheets.",
            requiredStanding: 35, requiredPatronFavor: 30,
            maxHolders: 10, unlockedActions: ["economic_analysis", "quota_recommendation"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .economicPlanning,
            title: "Department Head of Planning Commission",
            description: "You control planning for an entire sector—heavy industry, agriculture, consumer goods.",
            requiredStanding: 50, requiredPatronFavor: 45, requiredNetwork: 20,
            maxHolders: 5, unlockedActions: ["sector_planning", "resource_allocation"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .economicPlanning,
            title: "Deputy Chairman of the State Planning Commission",
            description: "You coordinate the Five-Year Plan across multiple sectors. The economy's blueprint passes through your hands.",
            requiredStanding: 65, requiredPatronFavor: 55, requiredNetwork: 35,
            requiredFactionSupport: ["reformists": 50],
            maxHolders: 3, unlockedActions: ["plan_coordination", "investment_direction", "production_targets"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .economicPlanning,
            title: "First Deputy Chairman of Planning Commission",
            description: "The chairman's deputy and the operational head of economic planning. Every factory, every farm, every quota flows through your office.",
            requiredStanding: 80, requiredNetwork: 50,
            requiredFactionSupport: ["reformists": 60, "youth_league": 50],
            maxHolders: 2, unlockedActions: ["economic_direction", "plan_revision", "emergency_allocation"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .economicPlanning,
            title: "Chairman of the State Planning Commission",
            description: "The architect of socialism. You design the Five-Year Plans that shape the nation's economic destiny. Success is survival; failure is catastrophe. Such responsibility often warrants a place on the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 65,
            requiredFactionSupport: ["reformists": 70, "youth_league": 60],
            maxHolders: 1, unlockedActions: ["economic_masterplan", "national_planning", "economic_reform"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-6: MILITARY-POLITICAL TRACK (Main Political Directorate)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .capital, expandedTrack: .militaryPolitical,
            title: "Regimental Political Officer",
            description: "You ensure political reliability in a military unit. The soldiers fight for the motherland; you ensure they fight for the Party.",
            requiredStanding: 35, requiredPatronFavor: 35,
            maxHolders: 10, unlockedActions: ["troop_morale", "political_education"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .capital, expandedTrack: .militaryPolitical,
            title: "Divisional Political Commissar",
            description: "You oversee political work for an entire division. Officers defer to generals on tactics; they defer to you on loyalty.",
            requiredStanding: 50, requiredPatronFavor: 45, requiredNetwork: 25,
            requiredFactionSupport: ["princelings": 40],
            maxHolders: 6, unlockedActions: ["unit_reliability", "officer_vetting"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .capital, expandedTrack: .militaryPolitical,
            title: "Deputy Head of Main Political Directorate",
            description: "You oversee political work for entire military branches—ground forces, navy, or air defense.",
            requiredStanding: 65, requiredPatronFavor: 55, requiredNetwork: 40,
            requiredFactionSupport: ["princelings": 55],
            maxHolders: 4, unlockedActions: ["branch_political_control", "military_appointment_vetting"],
            requiredAffinityScore: 30
        ))

        positions.append(LadderPosition(
            index: 5, track: .capital, expandedTrack: .militaryPolitical,
            title: "First Deputy Head of Main Political Directorate",
            description: "Second in command of the Party's presence in the armed forces. The army obeys the General Staff; the General Staff heeds you.",
            requiredStanding: 80, requiredNetwork: 55,
            requiredFactionSupport: ["princelings": 65, "youth_league": 55],
            maxHolders: 2, unlockedActions: ["military_political_oversight", "defense_policy_input"],
            requiredAffinityScore: 40
        ))

        positions.append(LadderPosition(
            index: 6, track: .capital, expandedTrack: .militaryPolitical,
            title: "Head of the Main Political Directorate",
            description: "The guardian of the army's political soul. You ensure the generals serve the Party, not themselves. In a crisis, the army's loyalty depends on you. Such critical trust frequently earns a seat on the Standing Committee.",
            requiredStanding: 88, requiredNetwork: 70,
            requiredFactionSupport: ["princelings": 75, "youth_league": 65],
            maxHolders: 1, unlockedActions: ["military_loyalty_control", "defense_council_seat", "coup_prevention"],
            isApexPosition: true
        ))

        // ============================================
        // TIER 2-4: REGIONAL TRACK (Provincial/Republic Assignments)
        // ============================================

        positions.append(LadderPosition(
            index: 2, track: .regional, expandedTrack: .regional,
            title: "Provincial Party Secretary",
            description: "Assigned to a distant zone. Far from Washington's intrigues, but here you can build your own power base.",
            requiredStanding: 35,
            maxHolders: 10, unlockedActions: ["manage_region", "meet_quotas", "local_appointments"],
            requiredAffinityScore: 10
        ))

        positions.append(LadderPosition(
            index: 3, track: .regional, expandedTrack: .regional,
            title: "Provincial First Secretary",
            description: "You run an entire zone. Success here proves your worth to Washington; failure means obscurity—or worse.",
            requiredStanding: 55, requiredNetwork: 25,
            maxHolders: 5, unlockedActions: ["regional_policy", "request_resources", "report_to_capital"],
            requiredAffinityScore: 20
        ))

        positions.append(LadderPosition(
            index: 4, track: .regional, expandedTrack: .regional,
            title: "Republic First Secretary",
            description: "Leader of an entire territory. Almost independent if you're careful—but Washington is always watching.",
            requiredStanding: 75, requiredNetwork: 45,
            requiredFactionSupport: ["regional": 55],
            maxHolders: 2, unlockedActions: ["republic_policy", "nationalities_policy", "regional_economy_control"],
            requiredAffinityScore: 30
        ))

        // ============================================
        // TIER 7-8: SHARED TOP POSITIONS (All tracks merge)
        // ============================================

        positions.append(LadderPosition(
            index: 7, track: .shared, expandedTrack: .shared,
            title: "Deputy General Secretary",
            description: "Second in command of the entire Party. All tracks, all factions, all interests converge on you. You can speak for the General Secretary in their absence. One step from supreme power.",
            requiredStanding: 90, requiredNetwork: 70,
            requiredFactionSupport: ["princelings": 60, "youth_league": 70, "old_guard": 55],
            maxHolders: 1, unlockedActions: ["act_for_secretary", "control_agenda", "block_policy", "succession_maneuvering"]
        ))

        positions.append(LadderPosition(
            index: 8, track: .shared, expandedTrack: .shared,
            title: "General Secretary",
            description: "Supreme power. The Party, the state, the nation—all answer to you. You typically chair the Standing Committee and set its agenda. But power must be maintained, term limits may constrain you, and rivals never stop scheming.",
            requiredStanding: 95, requiredNetwork: 80,
            requiredFactionSupport: ["princelings": 70, "youth_league": 80, "old_guard": 65],
            maxHolders: 1, unlockedActions: ["all", "force_decree", "modify_laws", "abolish_term_limits"]
        ))

        return positions
    }

    // MARK: - Starting Characters

    /// Creates the comprehensive roster of starting characters across all positions
    private func createStartingCharacters() -> [CharacterTemplate] {
        var characters: [CharacterTemplate] = []

        // ============================================
        // TOP LEADERSHIP (Shared Track - Indices 7-8)
        // ============================================

        // General Secretary (index 8) - The supreme leader
        characters.append(CharacterTemplate(
            id: "brenner",
            name: "Harold Mitchell",
            title: "General Secretary",
            role: "leader",
            positionIndex: 8,
            positionTrack: "shared",
            personality: CharacterPersonality(ambitious: 30, paranoid: 70, ruthless: 60, competent: 50, loyal: 20, corrupt: 40),
            speechPattern: "Speaks slowly, deliberately, choosing each word with care. Heavy pauses between sentences. Uses party jargon naturally—'dialectical necessities,' 'the collective wisdom.' References the Second Revolution as if he marched on Washington himself. When displeased, grows quieter, not louder. 'Comrade... I wonder if you understand what you are asking.' Never directly threatens. The threat is always implied.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born to a factory foreman's family in a cramped Philadelphia tenement. Lost a brother to the influenza; lost his father's job in the Depression. Joined the Youth League as a young man, caught Chairman Fitzgerald's eye organizing strikes in the textile mills. Rose through competence and caution, always the reliable second choice—until Fitzgerald chose him as successor. Married Margaret Sullivan before the Revolution; she took her own life during the worst of the Purges, officially recorded as 'illness.' He never remarried. Carries guilt for every death warrant he signed to survive.",
            ageCategory: "middle-aged",
            originLocation: "Philadelphia, Pennsylvania",
            familyBackground: "Working-class Irish-Catholic family. Father was a textile mill foreman until the Depression. One surviving sister, now in a state sanatorium.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Death Warrants",
                    content: "During the Consolidation Purges, Mitchell signed death warrants for seventeen former comrades and friends—people he had organized with, shared meals with, trusted. He told himself it was necessary for survival. Some of those names visit him in dreams.",
                    tier: "discoverable",
                    category: "guilt",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: "purge"
                ),
                CharacterSecretTemplate(
                    title: "Margaret's Death",
                    content: "His wife Margaret did not die of illness. She took her own life during the Purges, unable to bear what her husband was becoming. The medical records were altered. Only Wallace knows the truth—and holds it as leverage.",
                    tier: "discoverable",
                    category: "knowledge",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Fitzgerald's Chosen",
                    content: "Mitchell was Fitzgerald's hand-picked successor—but not his first choice. The original heir apparent was purged after the Purges. Mitchell has always wondered if Fitzgerald regretted choosing him.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "fitzgerald"
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "conspiracy",
                    description: "Mutual survivors of the Purges, bound by shared secrets. Wallace knows too much for Mitchell to move against him; Mitchell protects Wallace's position. Neither trusts the other. Both need each other.",
                    sentiment: 20,
                    historicalOrigin: "The Consolidation Purges"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "morozova",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "mentor",
                    description: "Mitchell elevated Patterson over more experienced candidates. She owes him her position and remains publicly loyal. Whether that loyalty will survive his decline remains to be seen.",
                    sentiment: 60,
                    historicalOrigin: "Post-Fitzgerald succession"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "ozols",
                    targetCharacterName: "General Raymond Carter",
                    relationshipType: "rival",
                    description: "The eternal tension between Party and military. Carter commands the army's loyalty; Mitchell commands the Party's. They work together because neither can rule alone, but there is no warmth between them.",
                    sentiment: 10,
                    historicalOrigin: "Post-war power structure"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "kadaris",
                    targetCharacterName: "Comrade Henderson",
                    relationshipType: "ally",
                    description: "Mitchell uses Henderson's genuine idealism as cover for his own pragmatic decisions. Henderson believes in the Revolution; Mitchell believes in survival. They rose together under Fitzgerald.",
                    sentiment: 45,
                    historicalOrigin: "Youth League (before the Revolution)"
                )
            ],
            historicalConnections: ["fitzgerald", "purge", "siege_detroit", "youth_league"]
        ))

        // Deputy General Secretary (index 7)
        characters.append(CharacterTemplate(
            id: "ozols",
            name: "General Raymond Carter",
            title: "Deputy General Secretary",
            role: "neutral",
            positionIndex: 7,
            positionTrack: "shared",
            personality: CharacterPersonality(ambitious: 75, paranoid: 40, ruthless: 55, competent: 70, loyal: 60, corrupt: 30),
            speechPattern: "Military precision in every word. Short, declarative sentences. 'The situation requires action. We have discussed enough.' Uncomfortable with political circumlocution—prefers blunt assessments. Old war wounds make him shift in his chair. References campaigns and battles as metaphors. 'In the Great Lakes offensive, we learned that hesitation costs lives.' Respects competence above ideology.",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born to Black sharecroppers in rural Georgia. Escaped north during the Great Migration, found work in Chicago's meatpacking plants. Enlisted in the revolutionary militia at the start of the Revolution after watching Federal troops fire on strikers. Rose through the ranks during the Civil War, earning his reputation in the brutal street fighting of Chicago under General Steele's command. Wounded twice—once at Chicago, once at Pittsburgh. Married Elizabeth Briggs, daughter of Commissar Thomas Briggs, after the Revolution; she died years after the Purges of tuberculosis. He never remarried. Steele's execution during the Purges broke something in him—he served under the man, loved him like a father, and watched Wallace fabricate the evidence.",
            ageCategory: "middle-aged",
            originLocation: "Rural Georgia (born); Chicago, Illinois (migrated during the Great Migration)",
            familyBackground: "Son of sharecroppers. Escaped the Jim Crow South. Married into the Briggs family—one of the founding families of the Revolution. Widower, no surviving children.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Deserters",
                    content: "During the Battle of Chicago, Carter personally executed seven soldiers who retreated from their positions without orders. The executions were unofficial—no courts-martial, no records. He told himself it was necessary to hold the line. The faces of those boys haunt him still.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: "battle_chicago"
                ),
                CharacterSecretTemplate(
                    title: "Wallace's Crime",
                    content: "Carter knows that Wallace fabricated the evidence against General Steele in the Trial of the Thirty-Six. He has never confronted Wallace directly—but he has never forgiven him. One day, when the moment is right, Carter will have his reckoning.",
                    tier: "narrativeOnly",
                    category: "knowledge",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: "trial_thirtysix"
                ),
                CharacterSecretTemplate(
                    title: "The Southern Past",
                    content: "Carter's father was lynched in 1918 for 'looking at a white woman.' Carter never speaks of his childhood. The Party remade him; the revolution gave him purpose. But the rage of that boy watching his father die never fully extinguished.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "enemy",
                    description: "Cold professionalism masking deep hatred. Carter knows Wallace destroyed General Steele. Wallace knows Carter knows. They work together because the Party demands it. The alliance is built on ice.",
                    sentiment: -40,
                    historicalOrigin: "Trial of the Thirty-Six"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "fletcher",
                    targetCharacterName: "General Fletcher",
                    relationshipType: "warComrade",
                    description: "Fought together under General Steele during the Civil War. Both rose through the Princeling networks. Fletcher is political where Carter is direct, but they trust each other with their lives.",
                    sentiment: 70,
                    historicalOrigin: "Battle of Chicago"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "brenner",
                    targetCharacterName: "Harold Mitchell",
                    relationshipType: "rival",
                    description: "The eternal tension between military and Party. Carter has the army's loyalty; Mitchell has the apparatus. Neither can rule without the other. There is no warmth, only pragmatic alliance.",
                    sentiment: 15,
                    historicalOrigin: "Post-war power structure"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "spencer",
                    targetCharacterName: "Major Spencer",
                    relationshipType: "mentor",
                    description: "Carter sees something of his younger self in Spencer—idealistic, brave, still uncorrupted. He watches over the young commissar, hoping to guide him through the system without losing his soul.",
                    sentiment: 55,
                    historicalOrigin: "Military-Political Directorate"
                )
            ],
            historicalConnections: ["steele", "battle_chicago", "pittsburgh_massacre", "briggs", "trial_thirtysix"]
        ))

        // ============================================
        // PARTY APPARATUS TRACK (Indices 2-6)
        // ============================================

        // Second Secretary of Central Committee (index 6) - Apex position
        characters.append(CharacterTemplate(
            id: "morozova",
            name: "Eleanor Patterson",
            title: "Second Secretary of the Central Committee",
            role: "neutral",
            positionIndex: 6,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 85, paranoid: 75, ruthless: 80, competent: 75, loyal: 45, corrupt: 35),
            speechPattern: "Ice-cold precision. Speaks in complete, grammatically perfect sentences. Never raises her voice—doesn't need to. 'The Central Committee has reviewed your file. All two hundred pages of it.' Sharp eyes that miss nothing. Slight smile that never reaches her eyes. Makes notes constantly in a small leather book. 'Continue, Comrade. I am listening.' Her silence is more threatening than most people's shouting.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 45,
            backstory: "Born to an Irish-American Catholic family in South Boston—her father a longshoreman, her mother a seamstress. The Church was everything until the Revolution; she abandoned both faith and family for the Party. Rose through the Youth League as an organizer and propagandist, catching Fitzgerald's eye with her brilliant pamphlets. Survived the Purges by doing what was necessary: she denounced her own mentor, Professor William Harrigan, as a 'Trotskyist agent.' He was innocent. His wife and two children disappeared into Wallace's system. Patterson never speaks of this. She advanced rapidly after Fitzgerald's death, elevated to Second Secretary by Mitchell over more experienced candidates. She owes him everything—which means she resents him. Never married. 'Married to the Party,' she says. Collects poetry secretly; possessing some of it could be dangerous.",
            ageCategory: "middle-aged",
            originLocation: "South Boston, Massachusetts",
            familyBackground: "Irish-American Catholic working-class family. Estranged from surviving relatives after renouncing the Church during the Revolution. No spouse, no children.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Harrigan Denunciation",
                    content: "During the Purges, Patterson denounced her mentor Professor William Harrigan to save herself. Harrigan was a true believer, guilty of nothing but teaching her to think. He was executed within a week. His wife and two children—ages 8 and 11—were taken by Wallace's men. Patterson knows they went to the camps. She does not know if they survived.",
                    tier: "discoverable",
                    category: "betrayal",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: "purge"
                ),
                CharacterSecretTemplate(
                    title: "The Poetry Collection",
                    content: "Patterson secretly collects poetry—including banned works by pre-revolutionary and foreign poets. Some of these poems are officially forbidden; possessing them could be career-ending or worse. She reads them at night, alone, and remembers a time when she believed in beauty as well as revolution.",
                    tier: "discoverable",
                    category: "forbidden",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Debt to Mitchell",
                    content: "Patterson knows she was not the most qualified candidate for Second Secretary. Mitchell chose her over more experienced officials for reasons she has never fully understood. She suspects he wanted someone who owed him personally—someone controllable. This knowledge burns.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["brenner"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "brenner",
                    targetCharacterName: "Harold Mitchell",
                    relationshipType: "protege",
                    description: "Mitchell elevated her over more qualified candidates. She owes him her position and displays public loyalty. Privately, she resents the debt and waits for her moment. When Mitchell weakens, she will be ready.",
                    sentiment: 40,
                    historicalOrigin: "Post-Fitzgerald succession"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "steinmetz",
                    targetCharacterName: "Walter Hoffman",
                    relationshipType: "rival",
                    description: "Hoffman believed he should have been Second Secretary. He lost to Patterson. The rivalry is professional but bitter. She watches him; he watches her. Neither forgets.",
                    sentiment: -25,
                    historicalOrigin: "Second Secretary selection"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "kirillova",
                    targetCharacterName: "Clara Donovan",
                    relationshipType: "mentor",
                    description: "Patterson is grooming Donovan as her own protégé—someone to carry her legacy, or perhaps to take the fall if needed. Donovan is competent and grateful, which makes her useful.",
                    sentiment: 55,
                    historicalOrigin: "Central Committee Department"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "polzin",
                    targetCharacterName: "Victor Rawlings",
                    relationshipType: "ally",
                    description: "Patterson and Rawlings exchange information and cover for each other. Neither trusts the other fully, but both benefit from the alliance. In this world, that passes for friendship.",
                    sentiment: 35,
                    historicalOrigin: "Central Committee apparatus"
                )
            ],
            historicalConnections: ["fitzgerald", "purge", "intellectuals_purge", "youth_league"]
        ))

        // Secretary of Central Committee (index 5)
        characters.append(CharacterTemplate(
            id: "kadaris",
            name: "Comrade Henderson",
            title: "Secretary of the Central Committee",
            role: "ally",
            positionIndex: 5,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 50, paranoid: 30, ruthless: 20, competent: 60, loyal: 70, corrupt: 20),
            speechPattern: "Genuinely passionate about ideology. Quotes Revolutionary founders with reverence—and actually means it. 'As the union leaders wrote during the March on Washington...' Speaks with warmth when discussing socialist theory. Gets animated, gestures with his hands. Naive about political maneuvering—believes the best in people until proven wrong. 'Surely, comrade, you must see the dialectical necessity?' One of the last true believers.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 65,
            backstory: "Born James Henderson to a schoolteacher and a minister in rural Ohio. Converted to socialism reading pamphlets at the public library. Joined the Youth League during the Depression, rose under Fitzgerald's mentorship. Unlike most survivors, Henderson emerged from the Revolution with his idealism intact—he never had to choose between his beliefs and his survival. He was in a hospital with typhoid during the worst of the Purges, which saved him from complicity. Still believes the Revolution can deliver on its promises. Mitchell keeps him around as a useful symbol of what they once believed.",
            ageCategory: "middle-aged",
            originLocation: "Rural Ohio",
            familyBackground: "Middle-class Protestant family. Father was a Methodist minister who preached social gospel. Mother taught school. Both died before the Revolution.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Convenient Illness",
                    content: "Henderson was hospitalized with typhoid fever during the worst months of the Consolidation Purges. This saved him from the denunciations and compromises that tainted everyone else. Some whisper the illness was too convenient—that Henderson found a way to absent himself. He has never responded to these whispers.",
                    tier: "narrativeOnly",
                    category: "knowledge",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "purge"
                ),
                CharacterSecretTemplate(
                    title: "The Father's Bible",
                    content: "Henderson keeps his father's Bible hidden in a locked drawer. He no longer believes in God, but he cannot bring himself to destroy it. If found, this relic of religious sentiment could be used against him.",
                    tier: "discoverable",
                    category: "forbidden",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "brenner",
                    targetCharacterName: "Harold Mitchell",
                    relationshipType: "ally",
                    description: "Henderson sees Mitchell as Fitzgerald's true heir. Mitchell uses Henderson's genuine idealism as cover for pragmatic decisions. Henderson doesn't notice the manipulation—or chooses not to.",
                    sentiment: 60,
                    historicalOrigin: "Youth League (before the Revolution)"
                )
            ],
            historicalConnections: ["fitzgerald", "youth_league", "march_washington"]
        ))

        // Second Secretary position holder (index 5)
        characters.append(CharacterTemplate(
            id: "steinmetz",
            name: "Walter Hoffman",
            title: "Secretary of the Central Committee",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 65, paranoid: 55, ruthless: 50, competent: 70, loyal: 55, corrupt: 45),
            speechPattern: "Speaks with a slight Midwestern accent despite decades in Washington. Formal, correct, precise. 'The organizational question must be addressed systematically.' Keeps detailed files on everyone—claims it's for 'proper personnel management.' Straightens papers compulsively. 'Order must be maintained.' Never jokes. Suspects humor is a form of ideological deviation.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Milwaukee to German-American Lutheran parents. Raised with rigid discipline and Protestant work ethic. Became a Party organizer in the Wisconsin dairy cooperatives, impressing superiors with his meticulous records. Rose through the apparatus by being indispensable—he knows where every file is, every document, every organizational irregularity. Expected to become Second Secretary in recent years; lost to Patterson. Has never forgiven the slight. Maintains extensive personal files on everyone—'for proper personnel management.'",
            ageCategory: "middle-aged",
            originLocation: "Milwaukee, Wisconsin",
            familyBackground: "German-American Lutheran family. Parents ran a small printing business. Never married—'no time for personal matters.'",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Personal Files",
                    content: "Hoffman maintains private dossiers on everyone in the Central Committee—not official files, but personal observations, overheard conversations, noted inconsistencies. These files are his insurance policy. If anyone moves against him, he has material to counter-attack.",
                    tier: "discoverable",
                    category: "knowledge",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Homosexual Encounters",
                    content: "Hoffman has had discreet encounters with men in carefully chosen locations. In the PSR, homosexuality is officially a 'bourgeois deviation.' Discovery would end his career and possibly his life. He lives in constant fear of exposure.",
                    tier: "discoverable",
                    category: "forbidden",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "morozova",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "rival",
                    description: "Hoffman believed he should have been Second Secretary. Patterson won. He has never forgiven her. The rivalry is professional but bitter, conducted through bureaucratic maneuvering.",
                    sentiment: -30,
                    historicalOrigin: "Second Secretary selection"
                )
            ],
            historicalConnections: ["youth_league"]
        ))

        // Head of Central Committee Department (index 4)
        characters.append(CharacterTemplate(
            id: "polzin",
            name: "Victor Rawlings",
            title: "Head of Central Committee Department",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 70, paranoid: 60, ruthless: 55, competent: 65, loyal: 50, corrupt: 55),
            speechPattern: "Speaks in bureaucratic euphemisms that obscure meaning. 'The matter has been referred for appropriate consideration.' Master of saying nothing while appearing helpful. Nods sympathetically while planning your downfall. 'Of course, comrade, your concerns are valid. Most valid.' Always has a reason why something cannot be done immediately. 'There are procedures...'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Baltimore to a family of minor civil servants. Learned early that procedure is power—whoever controls the paperwork controls the outcome. Survived the Purges by being indispensable to whoever was in charge, providing useful administrative cover for decisions others wanted made. Has no ideology beyond advancement. Trades in information with Patterson, covering for each other's irregularities.",
            ageCategory: "middle-aged",
            originLocation: "Baltimore, Maryland",
            familyBackground: "Family of minor bureaucrats. Wife works in the Party's Women's Committee. Two children attend Party schools.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Bureaucratic Sabotage",
                    content: "Rawlings has buried careers by losing paperwork, delaying approvals, and creating administrative obstacles for those who crossed him. No violence, no denunciations—just procedures. Proving it would require reconstructing years of 'clerical errors.'",
                    tier: "narrativeOnly",
                    category: "crime",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "morozova",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "ally",
                    description: "They exchange information and cover for each other. Neither trusts the other fully, but both benefit from the alliance.",
                    sentiment: 30,
                    historicalOrigin: "Central Committee apparatus"
                )
            ],
            historicalConnections: []
        ))

        // Deputy Head of CC Department (index 3)
        characters.append(CharacterTemplate(
            id: "kirillova",
            name: "Clara Donovan",
            title: "Deputy Head of Central Committee Department",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 55, paranoid: 45, ruthless: 40, competent: 75, loyal: 60, corrupt: 30),
            speechPattern: "Efficient, no-nonsense. 'Here is the report. Page seven is the critical section.' Actually competent at her job, which makes some people suspicious. Speaks quickly when discussing work, slower when politics comes up. 'I prefer to focus on the practical questions.' Younger than most at her level—earned her position through ability. Uncomfortable with flattery.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in New York City to a family of Irish-American dockworkers. Grew up in the Revolution, too young to fight but old enough to remember the chaos. Earned her position through sheer competence at a time when competence was rare. Patterson took notice and became her mentor—or her handler, depending on perspective. Clara is grateful but wary; she knows that protégés can become scapegoats.",
            ageCategory: "young",
            originLocation: "New York City, New York",
            familyBackground: "Irish-American working-class family. Parents were dockworkers and early Revolution supporters. Unmarried—'too busy for romance.'",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Patron's Shadow",
                    content: "Clara suspects Patterson is grooming her not just as a protégé but as a potential fall-back—someone to take the blame if Patterson's past catches up with her. She has begun quietly documenting Patterson's orders, just in case.",
                    tier: "narrativeOnly",
                    category: "knowledge",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["morozova"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "morozova",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "protege",
                    description: "Patterson elevated her and protects her career. Clara is grateful but increasingly suspicious of Patterson's motives. The relationship mixes genuine mentorship with calculated utility.",
                    sentiment: 50,
                    historicalOrigin: "Central Committee Department"
                )
            ],
            historicalConnections: []
        ))

        // ============================================
        // STATE MINISTRY TRACK (Indices 2-6)
        // ============================================

        // First Deputy Chairman of Council of Ministers (index 6) - Apex
        characters.append(CharacterTemplate(
            id: "crawford",
            name: "Albert Crawford",
            title: "First Deputy Chairman of the Council of Ministers",
            role: "neutral",
            positionIndex: 6,
            positionTrack: "stateMinistry",
            personality: CharacterPersonality(ambitious: 80, paranoid: 50, ruthless: 65, competent: 80, loyal: 40, corrupt: 50),
            speechPattern: "Speaks like a man who runs things and knows it. Brisk, efficient, slightly impatient. 'Yes, yes, I understand the political sensitivities. Now, shall we discuss how to actually solve the problem?' Checks his watch frequently. 'I have the Chemical Industry meeting in twenty minutes.' Pragmatic to a fault—ideology is a tool, not a religion. 'Results, comrade. The Congress judges us on results.'",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Red Harbor to a prosperous family of merchants. Educated abroad before the Revolution—one of the few bourgeois experts kept on for competence. Survived by making himself indispensable: he actually knows how to run an economy, which is rarer than ideology in the PSR. His sister married into the Briggs family, connecting him to the Princelings despite his Reformist leanings. Competes with Kowalski for economic influence; Crawford has competence, Kowalski has political cover.",
            ageCategory: "middle-aged",
            originLocation: "Red Harbor, Zone 5",
            familyBackground: "Prosperous merchant family. Harvard-educated. Sister married Thomas Briggs Jr. Wife is a former professor of economics, now purged from teaching.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Bourgeois Past",
                    content: "Crawford's family were capitalists before the Revolution—factory owners, investors, merchants. He destroyed most records, but some documentation survives. If revealed, his 'class background' could be used against him.",
                    tier: "discoverable",
                    category: "identity",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Rationalization Memorandum",
                    content: "Crawford was a co-author of the secret 'Rationalization Memorandum'—a document proposing market reforms that could be interpreted as 'capitalist restoration.' The document was suppressed; its authors could face charges of revisionism.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "kowalski",
                    targetCharacterName: "Director Kowalski",
                    relationshipType: "rival",
                    description: "Crawford and Kowalski compete for economic influence. Crawford is competent where Kowalski is corrupt. They undermine each other constantly while maintaining public collegiality.",
                    sentiment: -40,
                    historicalOrigin: "Council of Ministers vs. Planning Commission"
                )
            ],
            historicalConnections: ["briggs"]
        ))

        // Deputy Chairman of Council of Ministers (index 5)
        characters.append(CharacterTemplate(
            id: "mason",
            name: "Gregory Mason",
            title: "Deputy Chairman of the Council of Ministers",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "stateMinistry",
            personality: CharacterPersonality(ambitious: 60, paranoid: 70, ruthless: 45, competent: 55, loyal: 65, corrupt: 60),
            speechPattern: "Speaks cautiously, always looking for the safe position. 'Naturally, we must consider all aspects...' Sweats visibly when pressed for decisions. 'Perhaps the General Secretary has a preference?' Survived multiple purges by being utterly inoffensive. 'I think we can all agree...' Collects stamps and rarely discusses anything personal.",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Cleveland to a family of office clerks. Survived every purge by being utterly inoffensive—never taking positions, never making enemies, never standing out. His survival is an achievement in itself. Collects stamps obsessively; it's the only passion he allows himself. Has a wife and three children who rarely see him—'Work comes first, always.'",
            ageCategory: "middle-aged",
            originLocation: "Cleveland, Ohio",
            familyBackground: "Middle-class clerical family. Wife and three children. Keeps his family deliberately separate from his political life.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Survivor's Guilt",
                    content: "Mason watched colleagues fall during every purge—some he reported, some he simply failed to defend. He has never been a denouncer, but his silence was often enough. The faces of the fallen visit him at night.",
                    tier: "narrativeOnly",
                    category: "guilt",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "purge"
                )
            ],
            relationships: [],
            historicalConnections: ["purge"]
        ))

        // Minister (index 4)
        characters.append(CharacterTemplate(
            id: "sullivan_i",
            name: "Irene Sullivan",
            title: "Minister of Light Industry",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "stateMinistry",
            personality: CharacterPersonality(ambitious: 65, paranoid: 50, ruthless: 55, competent: 70, loyal: 55, corrupt: 40),
            speechPattern: "Speaks with the weariness of someone who actually has to deliver consumer goods. 'The quota is the quota. Now, where are the textiles coming from?' Practical, direct, occasionally sardonic. 'Apparently the Planning Commission believes cotton grows itself.' Defends her ministry fiercely. 'My workers are not the problem.' One of the few ministers who actually visits factories.",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Lowell, Massachusetts to a family of textile workers. Her grandmother died in the Triangle Shirtwaist fire; her mother organized the Lawrence strike. Irene grew up believing the Revolution would make workers' lives better. As Minister of Light Industry, she fights daily against impossible quotas and resource shortages, trying to deliver consumer goods that people actually need. One of the few officials who visits factories regularly—she remembers where she came from.",
            ageCategory: "middle-aged",
            originLocation: "Lowell, Massachusetts",
            familyBackground: "Multi-generation textile workers. Grandmother died in Triangle Shirtwaist fire. Mother was a labor organizer. Married to a factory manager; two children.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Quota Adjustments",
                    content: "Sullivan has quietly adjusted production reports to protect factory managers who couldn't meet impossible quotas. If discovered, this 'falsification' could be construed as sabotage—a capital offense.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "thompson",
                    targetCharacterName: "Wesley Thompson",
                    relationshipType: "ally",
                    description: "Both Sullivan and Thompson fight for realistic quotas against the fantasies of the Planning Commission. They cover for each other's 'adjustments.'",
                    sentiment: 45,
                    historicalOrigin: "Ministry coordination"
                )
            ],
            historicalConnections: []
        ))

        // First Deputy Minister (index 3)
        characters.append(CharacterTemplate(
            id: "collins",
            name: "Peter Collins",
            title: "First Deputy Minister of Heavy Industry",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "stateMinistry",
            personality: CharacterPersonality(ambitious: 70, paranoid: 40, ruthless: 50, competent: 65, loyal: 50, corrupt: 55),
            speechPattern: "Speaks with the bluff confidence of a former factory director. 'I know machines, comrade. I know what they can do.' Calls everyone 'brother' regardless of rank. 'Listen, brother, the furnaces don't care about politics.' Hands still calloused from early career. Drinks heavily but holds it well. 'To socialist construction!'",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Pittsburgh to a family of steelworkers. Started in the mills at fourteen; became a foreman at twenty-five. Joined the Revolution because he saw what the old system did to workers—the accidents, the poverty, the hopelessness. Rose through ability and personality; workers trust him because he speaks their language. Drinks heavily but functions; it's how he deals with the gap between revolutionary promises and industrial reality.",
            ageCategory: "middle-aged",
            originLocation: "Pittsburgh, Pennsylvania",
            familyBackground: "Multi-generation steelworker family. Wife died in the flu epidemic during the Purges. One son works in the Ministry of Heavy Industry.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Drinking",
                    content: "Collins drinks more than anyone knows—hidden bottles in his office, vodka in his tea. He functions, but barely. A medical examination would reveal liver damage. He drinks to forget the gap between what he believed the Revolution would build and what it actually became.",
                    tier: "discoverable",
                    category: "weakness",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [],
            historicalConnections: ["pittsburgh_massacre"]
        ))

        // ============================================
        // SECURITY SERVICES TRACK (Indices 2-6)
        // ============================================

        // Director of State Protection (index 6) - Apex
        characters.append(CharacterTemplate(
            id: "wallace",
            name: "Director Wallace",
            title: "Director of State Protection",
            role: "patron",
            positionIndex: 6,
            positionTrack: "securityServices",
            personality: CharacterPersonality(ambitious: 85, paranoid: 80, ruthless: 90, competent: 65, loyal: 30, corrupt: 50),
            speechPattern: "Speaks quietly—makes others lean in to hear. Long pauses that force people to fill the silence with confessions. 'Interesting. Tell me more about that.' Eyes that never blink when they should. 'Your file says one thing. You are telling me another.' Occasionally shows fatherly warmth—somehow more terrifying. 'Come now, we are friends here, aren't we?' His smile doesn't match his eyes.",
            factionId: "old_guard",
            isPatron: true,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born Arthur Wallerstein in 1898 to Jewish immigrant parents from Poland, in a Lower East Side tenement. Changed his name during the Revolution—'Wallerstein sounds too foreign.' Worked as a private investigator in New York before the uprising, which taught him that everyone has secrets. Joined revolutionary intelligence operations during the Civil War, proving brilliant at turning Federal agents and building informant networks. Served under Director Blackwood during the Consolidation Purges, learning the machinery of terror. Orchestrated Blackwood's downfall after the Purges and inherited his position—and his files. Lost his only son, David, during the Intervention War during the early Purges. Never speaks of family. Knows where every body is buried because he buried most of them.",
            ageCategory: "elderly",
            originLocation: "New York City, New York (Lower East Side)",
            familyBackground: "Jewish immigrant family from Poland. Parents died during the flu pandemic of 1918. One son, David, killed in action during the Intervention War (1942). Wife Sarah died of grief shortly after.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Steele Fabrication",
                    content: "Wallace personally fabricated the evidence against General Marcus Steele and oversaw his interrogation in the Trial of the Thirty-Six. The confession was coerced; the conspiracy was invented. Wallace destroyed a genuine hero to eliminate a threat to civilian Party control. He keeps no written record of this—only his memory.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["ozols"],
                    historicalEventId: "trial_thirtysix"
                ),
                CharacterSecretTemplate(
                    title: "The Blackwood Files",
                    content: "Wallace inherited Director Blackwood's personal files—a complete record of who denounced whom, which confessions were real, which were fabricated. These files give Wallace leverage over half the leadership. They are hidden in a location known only to him.",
                    tier: "discoverable",
                    category: "knowledge",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: "blackwood"
                ),
                CharacterSecretTemplate(
                    title: "Mitchell's Secrets",
                    content: "Wallace knows that Margaret Mitchell's death was suicide, not illness. He knows about the seventeen death warrants Mitchell signed during the Purges. This knowledge binds Mitchell to him—the General Secretary cannot move against his security chief without risking exposure.",
                    tier: "narrativeOnly",
                    category: "knowledge",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["brenner"],
                    historicalEventId: "purge"
                ),
                CharacterSecretTemplate(
                    title: "The Empty Heart",
                    content: "When David died during the early Purges, something in Wallace died too. He threw himself into his work with even greater intensity—if he could not save his son, he would at least save the state. His ruthlessness became mechanical, professional, complete. He no longer feels the weight of his victims.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "brenner",
                    targetCharacterName: "Harold Mitchell",
                    relationshipType: "conspiracy",
                    description: "Mutual survival pact. Wallace knows Mitchell's darkest secrets; Mitchell protects Wallace's position. Neither trusts the other. Both need each other. The relationship is transactional, not personal.",
                    sentiment: 25,
                    historicalOrigin: "The Consolidation Purges"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "ozols",
                    targetCharacterName: "General Raymond Carter",
                    relationshipType: "enemy",
                    description: "Carter knows Wallace destroyed General Steele. The hatred is mutual and permanent, masked by professional courtesy. One day, this will end in blood.",
                    sentiment: -50,
                    historicalOrigin: "Trial of the Thirty-Six"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "edwards",
                    targetCharacterName: "Colonel Edwards",
                    relationshipType: "mentor",
                    description: "Edwards is Wallace's chosen successor—the apprentice who will inherit the Bureau. Their relationship is professional, even paternal. Wallace sees in Edwards a younger, less damaged version of himself.",
                    sentiment: 60,
                    historicalOrigin: "BPS internal promotion"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "kowalski",
                    targetCharacterName: "Director Kowalski",
                    relationshipType: "ally",
                    description: "Wallace has evidence of Kowalski's embezzlement. He holds it in reserve, a weapon for future use. Kowalski knows he is compromised but cannot escape Wallace's web.",
                    sentiment: 35,
                    historicalOrigin: "BPS surveillance operations"
                )
            ],
            historicalConnections: ["fall_washington", "purge", "trial_thirtysix", "blackwood", "great_war"]
        ))

        // First Deputy Director of State Protection (index 5)
        characters.append(CharacterTemplate(
            id: "edwards",
            name: "Colonel Edwards",
            title: "First Deputy Director of State Protection",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "securityServices",
            personality: CharacterPersonality(ambitious: 70, paranoid: 85, ruthless: 75, competent: 70, loyal: 55, corrupt: 45),
            speechPattern: "Clipped, professional, reveals nothing. 'The operation is proceeding. Details are compartmentalized.' Never sits with his back to the door. Eyes sweep every room upon entry. 'I noticed you took a different route today, comrade.' Speaks of surveillance as necessary hygiene. 'We keep the state clean.' Former field operative—still moves like one. Silence is his natural state.",
            factionId: "old_guard",
            isPatron: false,
            isRival: false,
            startingDisposition: 45,
            backstory: "Born Edward Williams in 1908 in Baltimore, son of a dockworker and a seamstress. Joined the revolutionary underground at sixteen, running messages between cells. During the Civil War, served as a field agent behind federal lines—sabotage, assassination, intelligence gathering. Cold work that changed him. Wallace recruited him personally during the Revolution, recognizing a kindred spirit. Changed his name after the Revolution 'for operational reasons.' Rose through the BPS ranks on competence and ruthlessness. Was present at General Steele's interrogation during the Purges—he held the lamp while Wallace asked questions. Never speaks of it. Wallace sees him as a successor; Edwards isn't sure he wants that weight.",
            ageCategory: "middle-aged",
            originLocation: "Baltimore, Maryland",
            familyBackground: "Working-class family destroyed by the Depression. Mother died of tuberculosis before the Revolution. Father drank himself to death. No wife, no children—'the work is my family.' Has a sister in the Great Lakes Zone whom he has not contacted in fifteen years.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Steele Interrogation",
                    content: "Edwards was present during General Steele's final interrogation during the Purges. He personally witnessed Wallace's methods—and participated. The 'confession' Steele never gave haunts him. Sometimes he wonders if they broke an innocent hero.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: "trial_of_thirty_six"
                ),
                CharacterSecretTemplate(
                    title: "The Name Change",
                    content: "Edwards was born Edward Williams. He changed his name at the Revolution's end 'for operational security.' The real reason: he executed three members of his own cell during the Revolution on Wallace's orders—suspected infiltrators. One was probably innocent. He couldn't bear the name anymore.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Successor's Doubt",
                    content: "Wallace is grooming Edwards to succeed him as Director. Edwards knows this. He also knows what the job truly entails—the weight of secrets, the isolation, the things you do in dark rooms. Part of him wants to flee to his sister in the Great Lakes Zone and disappear. He never will.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "mentor",
                    description: "Wallace is his teacher, his father figure, and his captor all at once. Edwards owes Wallace everything—and is bound to him by shared guilt.",
                    sentiment: 75,
                    historicalOrigin: "Recruited before the Revolution, shared operations ever since"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "strickland",
                    targetCharacterName: "Major Strickland",
                    relationshipType: "rival",
                    description: "Strickland is too eager, too brutal, too obvious. Edwards sees him as a liability—a man who enjoys the work too much. But Strickland is useful, and useful people survive.",
                    sentiment: 35,
                    historicalOrigin: "BPS Counter-Intelligence"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "reynolds",
                    targetCharacterName: "Captain Reynolds",
                    relationshipType: "ally",
                    description: "Reynolds is competent and professional. Edwards respects that. They may have had something more once—or might still. Neither speaks of it.",
                    sentiment: 65,
                    historicalOrigin: "BPS Surveillance operations"
                )
            ],
            historicalConnections: ["trial_of_thirty_six", "purge"]
        ))

        // Directorate Chief (index 4)
        characters.append(CharacterTemplate(
            id: "strickland",
            name: "Major Strickland",
            title: "Chief of Counter-Intelligence Directorate",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "securityServices",
            personality: CharacterPersonality(ambitious: 75, paranoid: 70, ruthless: 80, competent: 60, loyal: 45, corrupt: 55),
            speechPattern: "Speaks with barely concealed aggression. 'Everyone has something to hide. Everyone.' Leans forward when questioning, invading personal space. 'Where were you on the night of the fourteenth? Think carefully.' Enjoys his work—perhaps too much. 'The truth always comes out. Always.' Taps his pen on the desk rhythmically. Makes notes about everything.",
            factionId: "old_guard",
            isPatron: false,
            isRival: false,
            startingDisposition: 40,
            backstory: "Born Marcus Strickland in 1915 in Chicago, during the chaos of the battle that would claim the city. His father was killed by federal artillery; his mother by starvation during the siege. Raised in a revolutionary orphanage, he learned early that weakness invites destruction. Joined the BPS at eighteen, showing immediate aptitude for 'enhanced interrogation.' Rose quickly through Counter-Intelligence by producing confessions—always confessions. Wallace finds him useful but distasteful; Edwards tolerates him because he gets results. Strickland genuinely believes everyone is guilty of something; his job is merely to find out what.",
            ageCategory: "young",
            originLocation: "Chicago, Illinois",
            familyBackground: "Orphan of the Battle of Chicago. Raised in the State Youth Home #14. Never married. Lives in a small apartment near BPS headquarters. Has no friends, only colleagues and targets.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Fabricated Confessions",
                    content: "Strickland has extracted hundreds of confessions. Not all of them were genuine. He knows how to get someone to sign anything—and he doesn't always care if it's true. Some of the 'conspiracies' he uncovered were his own creations, built to meet quotas and advance his career.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace", "edwards"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Sadistic Pleasure",
                    content: "Strickland enjoys his work. Not in the cold, professional way Edwards does—Strickland takes genuine pleasure in breaking people. He tells himself it's righteous anger against enemies of the state. Late at night, he knows the truth.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "edwards",
                    targetCharacterName: "Colonel Edwards",
                    relationshipType: "rival",
                    description: "Edwards is everything Strickland is not—controlled, respected, trusted. Strickland resents him. Edwards merely finds Strickland distasteful but useful.",
                    sentiment: 30,
                    historicalOrigin: "BPS hierarchy"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "ally",
                    description: "Wallace uses Strickland for the dirtiest work. Strickland is grateful for the opportunity to serve. He doesn't realize Wallace considers him disposable.",
                    sentiment: 70,
                    historicalOrigin: "BPS operations"
                )
            ],
            historicalConnections: ["battle_chicago"]
        ))

        // Deputy Directorate Chief (index 3)
        characters.append(CharacterTemplate(
            id: "reynolds",
            name: "Captain Reynolds",
            title: "Deputy Chief of Surveillance Directorate",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "securityServices",
            personality: CharacterPersonality(ambitious: 60, paranoid: 65, ruthless: 50, competent: 70, loyal: 60, corrupt: 35),
            speechPattern: "Speaks precisely, methodically. 'The subject was observed at 14:32. He spoke with three individuals.' Treats surveillance as a science, not a weapon. 'Patterns reveal truth.' Young for her position—promoted for technical competence. 'The listening devices in the Canadian embassy are quite sophisticated.' Keeps personal opinions hidden behind professionalism.",
            factionId: "old_guard",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born Natasha Reynolds in Philadelphia, daughter of a telephone company engineer and a schoolteacher. Showed aptitude for technical work from childhood—could build a radio from spare parts by age twelve. Recruited by the BPS's Technical Division at the Revolution's end, fresh from the revolutionary youth training program. Rose through Surveillance on pure competence: she designs the listening systems, analyzes the intercepts, spots the patterns others miss. One of the few women at her level in the security apparatus. Edwards respects her work; they may share something deeper, though neither acknowledges it. Privately disgusted by Strickland's methods—she believes surveillance should be clean, clinical, almost mathematical.",
            ageCategory: "young",
            originLocation: "Philadelphia, Pennsylvania",
            familyBackground: "Lower-middle-class technical family. Father still works for State Telephone; mother retired. Never married. Lives alone, spends evenings reading intercepted correspondence. The loneliness sometimes feels like drowning.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Forbidden Recordings",
                    content: "Reynolds keeps private copies of certain intercepted conversations—not for leverage, but because she finds the intimate glimpses into other people's lives compelling. She tells herself it's professional curiosity. It's actually loneliness. If discovered, this unauthorized collection would end her career.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Edwards Situation",
                    content: "There is something between Reynolds and Edwards. Neither has named it. They work late together more often than necessary. Once, his hand brushed hers reaching for a file. They pretended it didn't happen. In the BPS, emotional attachments are liabilities. Both know this.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["edwards"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "edwards",
                    targetCharacterName: "Colonel Edwards",
                    relationshipType: "ally",
                    description: "Professional respect that might be something more. They understand each other's silences. Both are too disciplined to acknowledge what lies beneath.",
                    sentiment: 65,
                    historicalOrigin: "BPS Surveillance operations"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "strickland",
                    targetCharacterName: "Major Strickland",
                    relationshipType: "rival",
                    description: "Reynolds finds Strickland's methods crude and his personality repulsive. He leers at her; she looks through him. If she could destroy him professionally without risk, she would.",
                    sentiment: 20,
                    historicalOrigin: "BPS hierarchy"
                )
            ],
            historicalConnections: []
        ))

        // ============================================
        // FOREIGN AFFAIRS TRACK (Indices 2-6)
        // ============================================

        // Minister of Foreign Affairs (index 6) - Apex
        characters.append(CharacterTemplate(
            id: "marshall",
            name: "Secretary Marshall",
            title: "Minister of Foreign Affairs",
            role: "neutral",
            positionIndex: 6,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 70, paranoid: 55, ruthless: 50, competent: 80, loyal: 50, corrupt: 45),
            speechPattern: "Speaks with the cultured smoothness of a career diplomat. Multiple languages slip into his speech naturally. 'As we say in France, the more things change...' Impeccably dressed. 'The European powers respect strength, comrade. They mistake kindness for weakness.' Tells stories about summits and conferences. 'When I met the British Foreign Secretary in Geneva...' World-weary but still believes diplomacy matters.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born William Marshall in 1899 in Boston to a wealthy Brahmin family that sympathized with socialist causes. Educated at Harvard (pre-purge), studied in Paris and Berlin. Spoke five languages before the Revolution; learned Russian afterward. Joined the revolutionary movement as a young intellectual, using family connections to build international networks. During the Civil War, served as liaison to sympathetic foreign governments. After the Revolution, became the Republic's face abroad—cultured, reasonable, deceptively Western. Survived the Purges by being indispensable; the Party needed someone who could charm capitalists at Geneva without embarrassing the Revolution. His polish hides a genuine belief that socialism can triumph through diplomacy rather than war.",
            ageCategory: "elderly",
            originLocation: "Boston, Massachusetts",
            familyBackground: "Old money Boston family. Father was a progressive industrialist; mother a suffragette. Family estates were nationalized after the Revolution; Marshall surrendered them willingly—or claims he did. Wife died in childbirth before the Revolution; never remarried. His daughter lives in Paris, working for the Embassy. He arranged the posting to keep her safe.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Soviet Affair",
                    content: "During a summit in Moscow, Marshall had a brief affair with a Soviet diplomat, Natalia Ivanova. She was almost certainly an intelligence operative. He knew. He didn't care. If the BPS discovered this, his career would end—and possibly his life. Wallace knows. Wallace knows everything.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Daughter in Paris",
                    content: "Marshall's daughter Emily works at the Paris Embassy. Her loyalty to the Republic is... uncertain. She attends salons with French intellectuals who criticize the PSR. Marshall covers for her, intercepts concerning reports, buries problematic cables. If her activities were exposed, they would both be destroyed.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The True Believer's Doubt",
                    content: "Marshall has seen how the world sees the Republic. He has read the Western newspapers, heard the whispered criticisms at diplomatic receptions. Sometimes, late at night after too much French wine, he wonders if they're right. Then he remembers the poverty of his youth, the strikes crushed by federal troops, the workers shot down in the streets. The Republic is imperfect. The alternative was worse.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "graham",
                    targetCharacterName: "Nicholas Graham",
                    relationshipType: "rival",
                    description: "Graham wants his job and makes little effort to hide it. Marshall finds Graham's ambition tiresome but recognizes his competence. A worthy successor, if he can learn patience.",
                    sentiment: 40,
                    historicalOrigin: "Ministry hierarchy"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "grudge",
                    description: "Wallace knows about the Soviet affair. He has never used it—yet. Marshall lives under that shadow, never certain when the axe might fall. They are professionally cordial. Marshall hates him.",
                    sentiment: 25,
                    historicalOrigin: "The Moscow file"
                )
            ],
            historicalConnections: []
        ))

        // First Deputy Minister of Foreign Affairs (index 5)
        characters.append(CharacterTemplate(
            id: "graham",
            name: "Nicholas Graham",
            title: "First Deputy Minister of Foreign Affairs",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 75, paranoid: 60, ruthless: 55, competent: 70, loyal: 45, corrupt: 50),
            speechPattern: "Speaks with barely concealed frustration at being number two. 'The Secretary prefers a softer approach. I would suggest...' Always has an alternative strategy ready. 'Had we listened to my advice on the trade negotiations...' Ambitious but patient. 'My time will come.' Excellent memory for slights and favors alike.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in New York City, son of a union organizer and a teacher. Rose through Youth League ranks on intelligence and ambition. Studied at the Party Academy, then spent a decade in various foreign postings—Mexico, Cuba, the Soviet Union. Learned diplomacy in Moscow, where he survived three leadership transitions. Returned to Washington years after the Purges, positioned as Marshall's eventual successor. He knows Marshall has secrets; he's not above using them when the time is right. Patient as a spider, with a web of contacts across every embassy.",
            ageCategory: "middle-aged",
            originLocation: "New York City",
            familyBackground: "Working-class family with revolutionary credentials. Father died in the March on Washington—genuine martyr status. Mother still alive, proud of her son's rise. Married to a Party functionary; the marriage is practical rather than romantic. Two children in the Youth League.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Moscow Contacts",
                    content: "Graham maintains private channels to Soviet intelligence that bypass official Ministry protocols. He shares information the Ministry would rather keep quiet. In exchange, he receives political intelligence about his rivals. Whether this is treason or just ambitious networking depends on one's perspective.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Marshall's Files",
                    content: "Graham has been collecting evidence of Marshall's Moscow affair for years, waiting for the right moment to use it. He has copies of intercepted cables, hotel receipts, even a photograph. The file sits in his private safe. When Marshall finally falters, Graham will be ready.",
                    tier: "narrativeOnly",
                    category: "political",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["marshall"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "marshall",
                    targetCharacterName: "Secretary Marshall",
                    relationshipType: "rival",
                    description: "Graham respects Marshall's competence while resenting his position. Their relationship is professionally cordial, personally cold. Graham is waiting for Marshall to make a mistake.",
                    sentiment: 35,
                    historicalOrigin: "Ministry hierarchy"
                )
            ],
            historicalConnections: ["march_washington"]
        ))

        // Deputy Minister - Western Affairs (index 4)
        characters.append(CharacterTemplate(
            id: "roberts",
            name: "Kenneth Roberts",
            title: "Deputy Minister for European Affairs",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 60, paranoid: 65, ruthless: 45, competent: 75, loyal: 55, corrupt: 40),
            speechPattern: "Speaks like a man who has spent too long abroad. Occasionally uses European idioms, then catches himself. 'As they say in—that is, as we might observe...' Deeply knowledgeable about capitalist societies. 'I have read their newspapers for twenty years.' Slightly defensive about his cosmopolitanism. 'Understanding the enemy is not the same as admiring them.'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Philadelphia to a middle-class family. Studied in Paris before the Revolution on a scholarship—those years shaped him more than he admits. Joined the revolutionary movement before the Revolution, recruited by Fitzgerald personally during a lecture tour. During the Civil War, served as a courier between American revolutionaries and European socialist parties. After the Revolution, spent fifteen years in various European capitals—London, Paris, Rome. Knows the capitalist world intimately. Constantly accused (quietly) of being too Western, too cosmopolitan, insufficiently revolutionary. The accusations sting because they're partly true.",
            ageCategory: "middle-aged",
            originLocation: "Philadelphia, Pennsylvania",
            familyBackground: "Middle-class family. Father was an accountant; mother a music teacher. Both died during the Intervention War—collateral damage from British bombing of Philadelphia harbor. Roberts was in London at the time. The guilt has never faded. Married to a French-American woman he met in Paris; she finds Washington provincial.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Paris Years",
                    content: "Before the Revolution, Roberts lived in Paris for three years. He attended salons, drank with bourgeois intellectuals, had affairs with artists' models. He was happy. Sometimes he dreams of those cafés, those conversations, that freedom. He has never told anyone how much he misses that life.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The British Contact",
                    content: "Roberts maintains an unofficial channel with a mid-level British diplomat—ostensibly for back-channel negotiations, actually because they were friends before the Revolution. They meet occasionally in neutral territory. If the BPS discovered these unauthorized contacts, Roberts would be accused of espionage.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "marshall",
                    targetCharacterName: "Secretary Marshall",
                    relationshipType: "ally",
                    description: "Marshall and Roberts understand each other—both cosmopolitans in a revolutionary state. They share books, discuss European politics, speak French when they're alone. It's the closest thing either has to genuine friendship.",
                    sentiment: 70,
                    historicalOrigin: "European diplomatic circuit"
                )
            ],
            historicalConnections: ["fitzgerald"]
        ))

        // Ambassador to the United Kingdom (index 3)
        characters.append(CharacterTemplate(
            id: "lawrence",
            name: "Bernard Lawrence",
            title: "Ambassador to the United Kingdom",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 55, paranoid: 50, ruthless: 40, competent: 70, loyal: 60, corrupt: 35),
            speechPattern: "Speaks with acquired British mannerisms from decades abroad. 'Quite so, quite so.' Drinks tea, not coffee. 'The British are curious. They hide everything behind politeness.' Loves diplomatic gossip. 'Did you hear about the French Ambassador's faux pas?' Genuinely enjoys his posting. 'London has excellent tailors.'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born in Baltimore to an English immigrant mother and American father. Grew up speaking both accents. Worked as a labor organizer in the docks before the Revolution. During the Civil War, served as liaison to sympathetic British trade unionists—smuggling money and supplies. After the Revolution, sent to London as a reward for his connections. Has been there ever since. More British than American now. Genuinely loves the country he's supposed to be infiltrating. Returns to Washington as rarely as possible.",
            ageCategory: "elderly",
            originLocation: "Baltimore, Maryland",
            familyBackground: "Half-English heritage. Mother returned to England after the Revolution; Lawrence visits her secretly. Father died in the Intervention War—killed by British forces. The irony haunts him. Married to an American diplomat's daughter; she lives in Washington and they rarely see each other.",
            secrets: [
                CharacterSecretTemplate(
                    title: "Mother in England",
                    content: "Lawrence's mother returned to England after the Revolution. He visits her secretly, using diplomatic cover. If anyone knew the American Ambassador was spending Sunday afternoons with his royalist mother in Surrey, his career would be over.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Going Native",
                    content: "Lawrence has been in London so long he's not sure he's American anymore. He prefers British customs, British food, British company. If given the choice, he would stay in England forever. This thought keeps him awake at night—what does it mean that he prefers the enemy's country to his own?",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "roberts",
                    targetCharacterName: "Kenneth Roberts",
                    relationshipType: "ally",
                    description: "Fellow cosmopolitans. Roberts understands Lawrence's situation better than anyone in Washington. They correspond frequently, commiserating about the provincialism of the capital.",
                    sentiment: 65,
                    historicalOrigin: "Foreign Affairs ministry"
                )
            ],
            historicalConnections: []
        ))

        // Ambassador to Mexico (index 3)
        characters.append(CharacterTemplate(
            id: "sanchez",
            name: "Theresa Sanchez",
            title: "Ambassador to Mexico",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 70, paranoid: 45, ruthless: 50, competent: 75, loyal: 50, corrupt: 40),
            speechPattern: "Speaks with measured precision and revolutionary steel beneath. 'The Mexican liberals are useful, comrade. They believe they can reform our system through dialogue.' Sharp, witty, occasionally cutting. 'Diplomacy is theater. One must know one's lines.' Smokes imported cigarettes. 'A small vice for a servant of the people.'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in San Antonio, Texas, to a Mexican-American family. Her grandmother crossed the border during the Mexican Revolution; Theresa grew up on stories of Zapata and Villa. Joined the revolutionary movement at seventeen, drawn to its promise of equality. During the Civil War, served as a courier across the Mexican border—weapons flowed north, refugees flowed south. After the Revolution, her bilingualism and border connections made her invaluable. Mexico City is a delicate posting: Mexico is nominally neutral but leans toward the government-in-exile. Theresa walks a tightrope daily, charming liberals while reporting their names to Wallace.",
            ageCategory: "middle-aged",
            originLocation: "San Antonio, Texas",
            familyBackground: "Mexican-American family with roots on both sides of the border. Grandmother was a Zapatista; father was a railroad worker and union organizer. Mother died when Theresa was young. Never married—'the Revolution is my spouse.' Has cousins in Mexico City who don't know she reports on them.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Family Reports",
                    content: "Theresa's cousins in Mexico City are prominent liberals who host salons where the government-in-exile's supporters gather. She reports on these gatherings to Wallace. Her cousins trust her. She tells herself it's for the greater good. Some nights she wonders if she's betraying her own blood.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Mexican Dream",
                    content: "Sometimes Theresa imagines staying in Mexico. Disappearing into Mexico City's crowds, becoming Mexican again, forgetting the Revolution and its compromises. The thought is treasonous. She has never told anyone. She never will.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "ally",
                    description: "Theresa is one of Wallace's eyes abroad. She reports directly to him, bypassing Marshall when necessary. Wallace values her; she's not sure how she feels about that.",
                    sentiment: 55,
                    historicalOrigin: "Intelligence coordination during Civil War"
                )
            ],
            historicalConnections: []
        ))

        // Ambassador to the Soviet Union (index 3)
        characters.append(CharacterTemplate(
            id: "chambers",
            name: "Eugene Chambers",
            title: "Ambassador to the Soviet Union",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 80, paranoid: 70, ruthless: 60, competent: 70, loyal: 45, corrupt: 50),
            speechPattern: "Speaks with careful intensity about our socialist brothers. 'The Soviets are valuable allies but have their own agenda.' Watches Soviet broadcasts for intelligence purposes. 'Their methods are... different from ours.' High-pressure posting has made him tense. 'Every word I speak could affect the alliance.'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 45,
            backstory: "Born in Cleveland, son of steelworkers. Joined the Communist Party USA before the Depression, studied Marxism with religious intensity. Traveled to Moscow before the Revolution for training at the International Lenin School—the experience shaped him permanently. During the Revolution, served as liaison to Soviet 'advisors' who brought weapons and expertise. The Soviets made him. He knows this. After the Revolution, spent a decade in various Party positions before Moscow posting in recent years. The pressure is immense: navigate between American interests and Soviet expectations while serving two masters who don't always agree.",
            ageCategory: "middle-aged",
            originLocation: "Cleveland, Ohio",
            familyBackground: "Working-class family, old CPUSA connections. Father was a Party member who died in the Siege of Detroit. Mother survives in a Washington apartment Chambers pays for. Married to a Soviet-trained Party cadre; their relationship is ideological as much as romantic. No children—Moscow advised against it.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Soviet Handler",
                    content: "Chambers reports to Soviet intelligence as well as the Ministry of Foreign Affairs. He receives instructions from Moscow that sometimes conflict with Washington's directives. He has always chosen Moscow. If this became known, he would be executed for treason—even though he believes he's serving the Revolution's true interests.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Doubts",
                    content: "Living in Moscow has shown Chambers the reality of the Soviet system. The purges, the famines, the terror. He tells himself it's necessary—that the American system is better, more humane. But the doubts are growing. What if the whole project is rotten? He cannot allow himself to think this. He thinks it anyway.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "graham",
                    targetCharacterName: "Nicholas Graham",
                    relationshipType: "ally",
                    description: "Fellow Moscow travelers. They trained together before the Revolution, shared the experience of seeing the Soviet Union from the inside. Graham knows about Chambers' divided loyalties. Chambers knows Graham has his own Soviet connections. Mutual blackmail keeps them close.",
                    sentiment: 55,
                    historicalOrigin: "International Lenin School"
                )
            ],
            historicalConnections: ["siege_detroit"]
        ))

        // ============================================
        // ECONOMIC PLANNING TRACK (Indices 2-6)
        // ============================================

        // Chairman of State Planning Commission (index 6) - Apex
        characters.append(CharacterTemplate(
            id: "kowalski",
            name: "Director Kowalski",
            title: "Chairman of the State Planning Commission",
            role: "rival",
            positionIndex: 6,
            positionTrack: "economicPlanning",
            personality: CharacterPersonality(ambitious: 80, paranoid: 55, ruthless: 70, competent: 45, loyal: 35, corrupt: 75),
            speechPattern: "Smooth, persuasive, always ready with statistics. 'The production figures speak for themselves, comrade.' Numbers flow effortlessly—many of them inflated. 'We exceeded quota by fourteen percent.' Dismisses criticism with charts. 'The data does not support that conclusion.' Expensive tastes poorly hidden. 'A small cabin in Vermont, nothing extravagant.' His confidence masks deep insecurity about his actual competence.",
            factionId: "reformists",
            isPatron: false,
            isRival: true,
            startingDisposition: 35,
            backstory: "Born Stefan Kowalski in 1912 to a working-class Polish-American family in Pittsburgh's steel district. His father died in a mill accident when Stefan was fifteen; he swore never to work with his hands. Studied economics at the University of Chicago (before it was purged), showing genuine mathematical talent. Rose rapidly after the Revolution by producing the statistics the Party wanted to hear—if reality disagreed with the Plan, adjust reality. Married Anna Briggs (distant cousin of Commissar Briggs's line) during the early Purges for political connections; the marriage is loveless and both know it. Developed expensive tastes that his salary cannot support. Skims from the Treasury—a small percentage here, an accounting irregularity there. Wallace knows. Wallace always knows.",
            ageCategory: "middle-aged",
            originLocation: "Pittsburgh, Pennsylvania",
            familyBackground: "Polish-American working-class family. Father killed in steel mill accident. Married into the Briggs family (minor branch) for connections. One daughter, Katya, attends the Party school in Washington.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Skimming",
                    content: "Kowalski has been systematically embezzling from the State Planning Commission for years—falsified expense reports, phantom projects, diverted allocations. The amounts are modest individually but significant in aggregate. He maintains a private account and several properties under false names. Wallace has documentation of everything.",
                    tier: "discoverable",
                    category: "corruption",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Falsified Statistics",
                    content: "The production figures Kowalski reports to the Standing Committee are systematically inflated. Every Five-Year Plan he oversees is built on lies. The real economic situation is far worse than official numbers suggest. If the truth emerged, the entire planning apparatus would be discredited—and Kowalski with it.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["carpenter"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Loveless Marriage",
                    content: "Kowalski married Anna Briggs purely for her family connections. She knows it; he knows it; they barely speak. She takes lovers; he pretends not to notice. The marriage is a hollow performance maintained for political appearances. Sometimes he wonders what his life might have been if he'd married for love.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Imposter",
                    content: "Deep down, Kowalski knows he is not as competent as his position requires. He rose on charm, political timing, and telling superiors what they wanted to hear. Carpenter is the real economist; Kowalski is just the face. His confidence is a performance, and he lives in terror of being exposed.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: ["carpenter"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "wallace",
                    targetCharacterName: "Director Wallace",
                    relationshipType: "debt",
                    description: "Wallace has evidence of Kowalski's embezzlement. Kowalski knows he is compromised; Wallace knows he knows. The debt can never be repaid. When Wallace calls in this marker, Kowalski will have no choice but to comply.",
                    sentiment: -30,
                    historicalOrigin: "BPS surveillance"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "carpenter",
                    targetCharacterName: "Anthony Carpenter",
                    relationshipType: "professional",
                    description: "Carpenter is the brilliant economist who actually makes the numbers work. Kowalski relies on him completely—and resents that dependence. Carpenter despises Kowalski's corruption but needs his political cover. They are bound together by mutual necessity.",
                    sentiment: 10,
                    historicalOrigin: "State Planning Commission"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "crawford",
                    targetCharacterName: "Albert Crawford",
                    relationshipType: "rival",
                    description: "Crawford and Kowalski compete for economic influence. Crawford is competent where Kowalski is corrupt; this makes Crawford dangerous. They undermine each other at every opportunity while maintaining the fiction of collegiality.",
                    sentiment: -35,
                    historicalOrigin: "Council of Ministers vs. Planning Commission"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "thompson",
                    targetCharacterName: "Wesley Thompson",
                    relationshipType: "ally",
                    description: "Thompson understands that the numbers must be adjusted. He and Kowalski cover for each other, falsifying reports together. In a world of liars, shared lies create bonds.",
                    sentiment: 40,
                    historicalOrigin: "State Planning Commission"
                )
            ],
            historicalConnections: ["briggs"]
        ))

        // First Deputy Chairman of Planning Commission (index 5)
        characters.append(CharacterTemplate(
            id: "carpenter",
            name: "Anthony Carpenter",
            title: "First Deputy Chairman of the State Planning Commission",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "economicPlanning",
            personality: CharacterPersonality(ambitious: 55, paranoid: 45, ruthless: 35, competent: 85, loyal: 55, corrupt: 30),
            speechPattern: "Speaks in numbers and projections. 'The input-output tables suggest a bottleneck in steel allocation.' Genuinely brilliant economist—and knows it. 'With respect, Director Kowalski, the math does not work.' Frustrated by political interference in planning. 'Science should guide production, not wishful thinking.' Keeps his head down but cannot help correcting errors.",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Boston to an academic family. Father was an economics professor at Harvard (pre-purge); mother a librarian. Showed mathematical brilliance from childhood—could solve differential equations at twelve. Studied at the Party Academy after the Revolution, one of the few genuine intellectual talents the system produced. Rose through the Planning Commission on pure competence. Kowalski is his political cover; Carpenter does the actual work. He knows the economic statistics are falsified. He knows the Plans are built on lies. He continues because someone has to try to make the system work—and if not him, who?",
            ageCategory: "young",
            originLocation: "Boston, Massachusetts",
            familyBackground: "Academic family. Father died in the Intellectuals' Purge—officially 'heart failure,' actually beaten to death in detention. Mother survived by denying any connection to bourgeois academics. Carpenter carries his father's pocket watch; it's the only thing he has left. Married to a fellow economist; they discuss input-output tables over dinner. One son in the Youth League.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Hidden Reports",
                    content: "Carpenter keeps two sets of calculations. The official ones show the Plan succeeding. The real ones show the economy is slowly strangling. He has been documenting the truth for years—a quiet act of treason. If these hidden reports were discovered, he would be executed. If they were never discovered, history would never know how badly the system failed.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["kowalski"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Father's Murder",
                    content: "Carpenter knows his father was murdered during the Intellectuals' Purge. He knows who gave the order. He has done nothing about it for fifteen years. Sometimes he wonders if his compliance makes him complicit. The pocket watch weighs heavy in his vest.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "intellectuals_purge"
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "kowalski",
                    targetCharacterName: "Director Kowalski",
                    relationshipType: "grudge",
                    description: "Kowalski is everything Carpenter despises—corrupt, incompetent, politically connected. Yet Carpenter needs Kowalski's protection. The brilliant economist does the work; the charming politician takes the credit. Both know the arrangement cannot last forever.",
                    sentiment: 15,
                    historicalOrigin: "State Planning Commission"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "erickson",
                    targetCharacterName: "Laura Erickson",
                    relationshipType: "ally",
                    description: "Erickson is competent and honest—rare qualities. Carpenter admires her practical wisdom about agriculture. They share quiet frustrations about the system's failures. Perhaps the only genuine friendship Carpenter has in the Commission.",
                    sentiment: 70,
                    historicalOrigin: "State Planning Commission"
                )
            ],
            historicalConnections: ["intellectuals_purge"]
        ))

        // Deputy Chairman of Planning Commission (index 4)
        characters.append(CharacterTemplate(
            id: "thompson",
            name: "Wesley Thompson",
            title: "Deputy Chairman of the State Planning Commission",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "economicPlanning",
            personality: CharacterPersonality(ambitious: 65, paranoid: 50, ruthless: 55, competent: 60, loyal: 50, corrupt: 60),
            speechPattern: "Speaks the language of quotas and allocations. 'Heavy industry gets priority. This is not negotiable.' Former factory manager who learned to play the game. 'The plan is the plan. We adjust reality to match it.' Pragmatic about falsification. 'Everyone adjusts the numbers. This is known.' Drinks with subordinates—calls it 'building relationships.'",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Gary, Indiana, son of a steelworker. Worked the mills from age sixteen until the Revolution. During the Civil War, organized his plant into a workers' militia—fought at the Battle of Chicago, saw things that never leave a man. After the Revolution, became a factory manager. Learned that meeting quotas mattered more than meeting reality. Falsified his first production report during the Purges; it became easier each time. Rose through the Planning Commission by being reliably flexible with numbers. He knows the whole system runs on lies. He participates anyway. What choice is there?",
            ageCategory: "middle-aged",
            originLocation: "Gary, Indiana",
            familyBackground: "Working-class steel family. Father died of lung disease from the mills. Mother still lives in Gary, proud of her son's success. Married to a schoolteacher; three children. The oldest wants to work in the Planning Commission. Thompson hopes he'll choose something more honest.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The First Falsification",
                    content: "During the Purges, Thompson's factory was failing its quota. Rather than face the consequences, he falsified the production reports. When inspectors came, he bribed them with factory supplies. He's been falsifying numbers ever since. Everyone does it. This is how the system works. But he remembers when he believed in honest work.",
                    tier: "discoverable",
                    category: "corruption",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["kowalski"],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Chicago Nightmares",
                    content: "Thompson still dreams about Chicago. The street fighting. The federal soldiers he killed. The revolutionary comrade he left to die when the position was overrun. He tells himself it was necessary. The dreams suggest otherwise.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "battle_chicago"
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "kowalski",
                    targetCharacterName: "Director Kowalski",
                    relationshipType: "ally",
                    description: "Partners in falsification. Thompson and Kowalski cover for each other, adjust each other's numbers, share the burden of lies. Their alliance is built on mutual complicity—neither can betray the other without destroying himself.",
                    sentiment: 50,
                    historicalOrigin: "State Planning Commission"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "sullivan",
                    targetCharacterName: "Irene Sullivan",
                    relationshipType: "ally",
                    description: "Sullivan fights for realistic quotas in the Council. Thompson appreciates anyone who tries to make the system less insane. They share drinks and complaints about impossible targets.",
                    sentiment: 60,
                    historicalOrigin: "Economic coordination meetings"
                )
            ],
            historicalConnections: ["battle_chicago"]
        ))

        // Department Head of Planning Commission (index 3)
        characters.append(CharacterTemplate(
            id: "erickson",
            name: "Laura Erickson",
            title: "Department Head of the State Planning Commission",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "economicPlanning",
            personality: CharacterPersonality(ambitious: 50, paranoid: 35, ruthless: 30, competent: 80, loyal: 65, corrupt: 25),
            speechPattern: "Speaks with quiet authority about agricultural quotas. 'The grain harvest depends on more than plans, comrade. It depends on rain.' Practical rural background shows through educated speech. 'My grandfather was a farmer in Kansas. I remember what hunger looks like.' Skeptical of overambitious targets. 'Paper does not feed people.'",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born on a Kansas wheat farm. Survived the Dust Bowl and the Great Collectivization—both nearly killed her family. Earned a scholarship to the Party Academy on pure merit, one of the few farm girls to make it. Became an expert on agricultural planning because she knew what happened when the plans were wrong. The Kansas Famine killed her younger brother; the official records say it never happened. She works within the system to prevent another famine, fighting for realistic quotas against ideological fantasies. Carpenter is her ally; together they try to inject reality into the Planning Commission's dreams.",
            ageCategory: "young",
            originLocation: "Kansas (Plains Zone)",
            familyBackground: "Farm family, Swedish-American immigrants. Grandfather homesteaded the land in 1890. Parents still farm the collective; they pretend to believe in collectivization. Younger brother Thomas died in the Kansas Famine—officially 'fever.' Never married; the work consumes her. Has a cat named Wheat.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Kansas Famine",
                    content: "Erickson knows the Kansas Famine was caused by impossible quotas and forced collectivization. She knows thousands died, including her brother. The official history says it never happened. She keeps a private journal documenting the truth. If discovered, it would be treason.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Brother's Grave",
                    content: "Thomas Erickson is buried in an unmarked grave on the family farm. Laura visits every year, on the anniversary. She tells him about her work, about the quotas she's managed to reduce, about the famines she's helped prevent. She never cries. There's no point anymore.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "carpenter",
                    targetCharacterName: "Anthony Carpenter",
                    relationshipType: "ally",
                    description: "The only person in the Commission who shares her commitment to honest numbers. They protect each other, share information, fight the same quiet battles. Carpenter understands her grief without her having to explain it.",
                    sentiment: 75,
                    historicalOrigin: "State Planning Commission"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "armstrong",
                    targetCharacterName: "Nathan Armstrong",
                    relationshipType: "professional",
                    description: "Armstrong governs the Plains Zone where Laura grew up. They negotiate agricultural quotas—she fights for realism, he fights for his farmers. Mutual respect despite different positions.",
                    sentiment: 55,
                    historicalOrigin: "Agricultural planning coordination"
                )
            ],
            historicalConnections: []
        ))

        // ============================================
        // MILITARY-POLITICAL TRACK (Indices 2-6)
        // ============================================

        // Head of Main Political Directorate (index 6) - Apex
        characters.append(CharacterTemplate(
            id: "fletcher",
            name: "General Fletcher",
            title: "Head of the Main Political Directorate",
            role: "neutral",
            positionIndex: 6,
            positionTrack: "militaryPolitical",
            personality: CharacterPersonality(ambitious: 75, paranoid: 65, ruthless: 70, competent: 65, loyal: 60, corrupt: 40),
            speechPattern: "Speaks with the absolute certainty of a political commissar. 'The army's loyalty is not in question. I ensure it personally.' Tells war stories that always have political morals. 'At the Battle of Chicago, the commissars held the line when others wavered.' Suspicious of purely military thinking. 'Generals think of tactics. We think of revolutionary purpose.' Commands respect through force of will.",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born James Fletcher in Ohio, son of a railroad man and a schoolteacher. Joined the revolutionary movement during the Depression, drawn by ideology rather than hardship—his family was comfortable. During the Civil War, served as a political commissar attached to General Steele's forces. Was present at the Battle of Chicago, where he earned his reputation for holding wavering units together through sheer force of will. After the Revolution, rose through the Political Directorate. Survived the Purges by denouncing General Steele—his former commander, his friend—as a traitor. The betrayal haunts him, but he tells himself it was necessary. Married into the Briggs family; his wife is Commissar Briggs's niece.",
            ageCategory: "middle-aged",
            originLocation: "Columbus, Ohio",
            familyBackground: "Middle-class family with no revolutionary credentials. Fletcher invented a working-class backstory early in his career; the lie has never been exposed. Married to Margaret Briggs; three children, all in Party positions. His eldest son serves in the Political Directorate under him.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Steele Betrayal",
                    content: "Fletcher denounced General Steele during the Purges, providing testimony that helped convict his former commander. Steele had trusted him; they had fought together at Chicago. Fletcher told himself it was necessary—that Steele was too popular, too independent. Sometimes he dreams of Steele's face at the trial, the look of betrayal when Fletcher took the stand.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["carter", "wallace"],
                    historicalEventId: "trial_of_thirty_six"
                ),
                CharacterSecretTemplate(
                    title: "The False Background",
                    content: "Fletcher claims working-class origins. In truth, his father was a railroad supervisor, his mother a teacher. The family had a piano. He invented poverty to fit the revolutionary narrative. If the lie were exposed, his entire career would be called into question.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "carter",
                    targetCharacterName: "General Raymond Carter",
                    relationshipType: "warComrade",
                    description: "They fought together under Steele. Both survived by betraying him. Neither speaks of it, but the shared guilt binds them. Carter respects Fletcher's political skills; Fletcher respects Carter's military credibility.",
                    sentiment: 55,
                    historicalOrigin: "Battle of Chicago"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "bellows",
                    targetCharacterName: "General Bellows",
                    relationshipType: "mentor",
                    description: "Fletcher brought Bellows up through the ranks, seeing in him a younger version of himself. Bellows is loyal, capable, and ambitious—but not too ambitious. The perfect subordinate.",
                    sentiment: 70,
                    historicalOrigin: "Political Directorate hierarchy"
                )
            ],
            historicalConnections: ["battle_chicago", "trial_of_thirty_six", "briggs"]
        ))

        // First Deputy Head of Main Political Directorate (index 5)
        characters.append(CharacterTemplate(
            id: "bellows",
            name: "General Bellows",
            title: "First Deputy Head of the Main Political Directorate",
            role: "neutral",
            positionIndex: 5,
            positionTrack: "militaryPolitical",
            personality: CharacterPersonality(ambitious: 70, paranoid: 55, ruthless: 60, competent: 70, loyal: 65, corrupt: 35),
            speechPattern: "Speaks with parade-ground precision. 'The political education of the troops proceeds on schedule.' Coordinates between military and party with practiced ease. 'The generals understand the chain of command. So do I.' Professional soldier who learned politics. 'Ideology is another weapon in our arsenal.' Loyal to the system that promoted him.",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Pittsburgh, son of a steelworker who died at the Pittsburgh Massacre. Witnessed federal troops shoot his father; joined the revolutionary militia at fifteen. Too young for the heaviest fighting, he came of age in the post-war army. Fletcher recognized his talent for combining military and political work—rare ability. Rose through the Political Directorate as Fletcher's protégé. Genuinely believes in the system; the Revolution gave him purpose after his father's death. Waiting patiently for Fletcher to retire, knowing his time will come.",
            ageCategory: "middle-aged",
            originLocation: "Pittsburgh, Pennsylvania",
            familyBackground: "Working-class martyr family. Father killed at the Pittsburgh Massacre—genuine revolutionary credentials. Mother remarried a Party official; Bellows never forgave her. Married to a colonel's daughter; two children in the Youth League. Family life is orderly, like everything else.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Massacre Witness",
                    content: "Bellows watched federal soldiers shoot his father at the Pittsburgh Massacre. He was twelve. He remembers every detail—the sound, the smoke, his father's face. That memory drives him still. He joined the Revolution for revenge as much as justice. The revenge is never quite enough.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "pittsburgh_massacre"
                ),
                CharacterSecretTemplate(
                    title: "The Mother's Betrayal",
                    content: "Bellows's mother remarried within a year of his father's death—to a Party official who helped her get a better apartment. Bellows sees this as a betrayal of his father's memory. He has not spoken to her in twenty years. His wife doesn't know his mother is still alive.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "fletcher",
                    targetCharacterName: "General Fletcher",
                    relationshipType: "mentor",
                    description: "Fletcher is his patron, his model, his ceiling. Bellows is grateful and patient. When Fletcher retires, Bellows will take his place. Until then, he serves loyally.",
                    sentiment: 75,
                    historicalOrigin: "Political Directorate mentorship"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "spencer",
                    targetCharacterName: "Major Spencer",
                    relationshipType: "mentor",
                    description: "Bellows sees something of his younger self in Spencer—the idealism, the genuine belief. He's grooming Spencer as Fletcher groomed him. The cycle continues.",
                    sentiment: 65,
                    historicalOrigin: "Political Directorate hierarchy"
                )
            ],
            historicalConnections: ["pittsburgh_massacre"]
        ))

        // Deputy Head of Main Political Directorate (index 4)
        characters.append(CharacterTemplate(
            id: "orlando",
            name: "General Orlando",
            title: "Deputy Head of the Main Political Directorate",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "militaryPolitical",
            personality: CharacterPersonality(ambitious: 60, paranoid: 60, ruthless: 55, competent: 60, loyal: 70, corrupt: 30),
            speechPattern: "Speaks with careful deference to both political and military superiors. 'The General's tactical wisdom complements Party guidance.' Navigates between two worlds. 'I wear two stars—one from the army, one from the Party.' Genuinely believes in the mission. 'The soldiers trust us to tell them why they fight.'",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born Marco Orlando in New York's Italian immigrant community. Father ran a small grocery; mother took in laundry. Joined the revolutionary movement before the Revolution, drawn by its promise of equality for immigrants. During the Civil War, served as a translator and liaison officer—the army needed men who spoke multiple languages. After the Revolution, transitioned into political work, bridging military and Party cultures. Rose through quiet competence rather than brilliance. Neither Fletcher nor Bellows sees him as a threat, which is exactly how he likes it.",
            ageCategory: "young",
            originLocation: "New York City (Little Italy)",
            familyBackground: "Italian-American immigrant family. Father's grocery was collectivized after the Revolution; he died shortly after. Mother still lives in the old apartment. Orlando sends her money. Married to a schoolteacher from the Bronx; three children. The family speaks Italian at home—a small act of cultural preservation.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Father's Store",
                    content: "Orlando's father ran a grocery store that was collectivized after the Revolution. The old man died within a year—of a broken heart, Orlando believes. He joined the Party that destroyed his father's life's work. Sometimes he wonders if his father would understand.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Vatican Letters",
                    content: "Orlando's mother still corresponds with relatives in Italy—through the Vatican's diplomatic pouch. She asks Orlando to mail the letters; he does, knowing it could be considered contact with a foreign power. The BPS probably knows. So far, they've chosen not to act.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["wallace"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "bellows",
                    targetCharacterName: "General Bellows",
                    relationshipType: "professional",
                    description: "Bellows outranks him; Orlando accepts this without resentment. He does his job, supports his superiors, and causes no trouble. Bellows barely notices him—which suits Orlando perfectly.",
                    sentiment: 50,
                    historicalOrigin: "Political Directorate hierarchy"
                )
            ],
            historicalConnections: []
        ))

        // Divisional Political Commissar (index 3)
        characters.append(CharacterTemplate(
            id: "spencer",
            name: "Major Spencer",
            title: "Divisional Political Commissar",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "militaryPolitical",
            personality: CharacterPersonality(ambitious: 65, paranoid: 45, ruthless: 45, competent: 65, loyal: 70, corrupt: 25),
            speechPattern: "Speaks with the enthusiasm of a true believer who works with troops. 'The soldiers are good material, comrade. They respond to proper education.' Young, energetic, idealistic. 'I tell them stories of the Second Revolution—their eyes light up.' Believes the system can be improved. 'We must earn their loyalty, not demand it.' Still has mud on his boots.",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born David Spencer in Washington, DC—a child of the Revolution, too young to remember the old world. Father was a mid-level Party official; mother a schoolteacher. Grew up on revolutionary stories and Youth League camps. Joined the army at eighteen, served during the Intervention War. Saw combat against Canadian forces in the Pacific Northwest. Returned idealistic rather than broken—rare in veterans. Bellows noticed him, saw the genuine faith, the ability to inspire troops. Rising fast through the Political Directorate. Still believes the Revolution was good, the system can be reformed, the future can be bright. His superiors find his optimism useful and slightly embarrassing.",
            ageCategory: "very young",
            originLocation: "Washington, DC",
            familyBackground: "Party family, born after the Revolution. Father works in the Ministry of Culture; mother teaches at a Party school. Married to his childhood sweetheart; expecting their first child. The future seems bright. He has never known hunger, never known fear of the state. This innocence is both his strength and his blind spot.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Canadian Girl",
                    content: "During the Intervention War, Spencer was stationed in the occupied Pacific Northwest. He had a brief relationship with a Canadian girl in Vancouver—enemy territory. She disappeared during a resistance crackdown. He doesn't know if she's alive or dead. He has never told his wife. He still dreams about her sometimes.",
                    tier: "discoverable",
                    category: "weakness",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Doubt",
                    content: "Spencer genuinely believes in the Revolution. But he's starting to notice things—the gap between rhetoric and reality, the fear in people's eyes when BPS is mentioned, the veterans who don't share his optimism. He pushes these doubts down. A commissar cannot doubt. But they keep surfacing.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "bellows",
                    targetCharacterName: "General Bellows",
                    relationshipType: "mentor",
                    description: "Bellows is grooming him for higher positions. Spencer is grateful, loyal, eager to learn. He sees Bellows as what he hopes to become—principled, effective, respected.",
                    sentiment: 75,
                    historicalOrigin: "Political Directorate mentorship"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "carter",
                    targetCharacterName: "General Raymond Carter",
                    relationshipType: "ally",
                    description: "Carter sees something of his younger self in Spencer—the genuine belief, the willingness to serve. He's protective of the young man, perhaps because he remembers when he was that idealistic.",
                    sentiment: 60,
                    historicalOrigin: "Military-political relations"
                )
            ],
            historicalConnections: []
        ))

        // ============================================
        // REGIONAL TRACK (Indices 2-4)
        // ============================================

        // Zone Governor - Northeast (index 4)
        characters.append(CharacterTemplate(
            id: "sheridan",
            name: "James Sheridan",
            title: "Governor of the Northeast Industrial Zone",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "regional",
            personality: CharacterPersonality(ambitious: 55, paranoid: 40, ruthless: 45, competent: 65, loyal: 60, corrupt: 45),
            speechPattern: "Speaks with the measured patience of someone far from the capital. 'Washington does not understand our situation here.' Protective of his zone. 'The Northeast workers have their own character.' Practical concerns dominate. 'The manufacturing quotas are unrealistic for our conditions.' Enjoys his relative autonomy. 'Out here, I am the Party.'",
            factionId: "regional",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Boston's Irish-American community. Father was a longshoreman and union organizer; mother worked in a textile mill. Joined the revolutionary movement during the Depression, organized the Boston docks during the General Strike. Fought in the Civil War, led dock workers' militias in harbor defense. After the Revolution, returned to the Northeast as a Party official. Rose to Governor by knowing every factory, every union hall, every neighborhood in his zone. Prefers his regional power to the snake pit of Washington. The Northeast runs smoothly because Sheridan knows his people—and they know him.",
            ageCategory: "middle-aged",
            originLocation: "Boston, Massachusetts",
            familyBackground: "Irish-American working-class family. Father died in a dock accident during the Revolution. Mother still lives in South Boston, goes to Mass every Sunday—Sheridan pretends not to know. Married to a former textile worker; four children scattered across the zone in various positions. The family is his power base.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Sunday Mass",
                    content: "Sheridan's mother attends Catholic Mass every Sunday. The church is technically illegal. The local BPS knows and looks the other way—Sheridan arranged it. If his protection of the church became widely known, he could be accused of harboring counter-revolutionary religious elements.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Quota Adjustments",
                    content: "Sheridan quietly adjusts production quotas to be more realistic before they reach factory floors. He reports the official numbers to Washington while managing actual production at sustainable levels. This systematic falsification keeps his zone functioning—and would destroy him if discovered.",
                    tier: "discoverable",
                    category: "corruption",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "bodine",
                    targetCharacterName: "Samuel Bodine",
                    relationshipType: "ally",
                    description: "Fellow regional governors who understand each other's challenges. They share information, coordinate production, and occasionally cover for each other's quota adjustments. Regional solidarity against Washington's unrealistic demands.",
                    sentiment: 65,
                    historicalOrigin: "Regional governors' meetings"
                )
            ],
            historicalConnections: ["boston_strike"]
        ))

        // Zone Governor - Plains (index 4)
        characters.append(CharacterTemplate(
            id: "armstrong",
            name: "Nathan Armstrong",
            title: "Governor of the Plains Agricultural Zone",
            role: "neutral",
            positionIndex: 4,
            positionTrack: "regional",
            personality: CharacterPersonality(ambitious: 70, paranoid: 55, ruthless: 50, competent: 70, loyal: 45, corrupt: 55),
            speechPattern: "Speaks with careful balance between local and central loyalties. 'We are farmers and citizens of the Republic both. This is not a contradiction.' Navigates rural politics with skill. 'The collective farm program brings many changes. We must... adapt.' Ambitious for his people and himself. 'The Plains will be the breadbasket of the Republic. And I will deliver it.' Hospitality masks calculation.",
            factionId: "regional",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born on a Nebraska wheat farm. Third generation Plains farmer. Survived the Dust Bowl, the Depression, and the Revolution. During collectivization, Armstrong was the rare farmer who cooperated—he saw which way the wind was blowing. His cooperation earned him position while his neighbors were sent to camps. Rose through the agricultural apparatus by understanding both farming and politics. Knows that impossible quotas cause famines—and knows how to manipulate reports to prevent them while appearing to comply. The Plains feed the Republic because Armstrong makes sure the quotas don't destroy the harvest.",
            ageCategory: "middle-aged",
            originLocation: "Nebraska (Plains Zone)",
            familyBackground: "Farm family, American for generations. Grandfather homesteaded the land. Father lost half the farm in the Dust Bowl. Armstrong kept the rest by cooperating with collectivization. Married to his childhood sweetheart; six children, all working the land in various collective capacities. The Armstrong name still means something in the Plains, even under socialism.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Kulak Denunciations",
                    content: "During the Great Collectivization, Armstrong survived by denouncing his neighbors as 'kulaks'—class enemies hoarding grain. Some of those families were sent to camps. Some died there. Armstrong tells himself he had no choice. Every harvest season, he remembers their faces.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "The Hidden Harvests",
                    content: "Armstrong runs a systematic underreporting scheme across the Plains. Farmers report lower yields than actual; the surplus is distributed quietly to prevent the famines that impossible quotas would cause. It's technically theft from the state. It's also why people don't starve.",
                    tier: "discoverable",
                    category: "corruption",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["erickson"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "erickson",
                    targetCharacterName: "Laura Erickson",
                    relationshipType: "professional",
                    description: "Erickson negotiates agricultural quotas for the Planning Commission; Armstrong fights for his farmers. They respect each other—both understand what impossible quotas mean. They've developed an unspoken understanding about what numbers are reported versus what's realistic.",
                    sentiment: 55,
                    historicalOrigin: "Agricultural planning negotiations"
                )
            ],
            historicalConnections: []
        ))

        // Zone Secretary (index 3)
        characters.append(CharacterTemplate(
            id: "lincoln",
            name: "Andrew Lincoln",
            title: "Secretary of the Southern Zone",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "regional",
            personality: CharacterPersonality(ambitious: 75, paranoid: 50, ruthless: 55, competent: 60, loyal: 55, corrupt: 60),
            speechPattern: "Speaks with the hunger of someone trying to get back to the capital. 'This zone assignment is temporary. I have proven myself.' Constantly references his connections in Washington. 'When I spoke to Comrade Patterson last month...' Works hard to exceed quotas. 'The Center will notice us.' Treats his zone as a stepping stone—and everyone knows it.",
            factionId: "regional",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Washington, DC, son of a Party functionary. Never worked with his hands, never fought in the war. Rose through the Youth League on political connections and genuine administrative talent. Assigned to the Southern Zone years after the Purges—officially a promotion, actually a exile from the capital's power games. Sees the South as a stepping stone back to Washington. Works his zone hard, squeezing quotas from former Confederate territory that still resents the Revolution. The Black and white populations of the South are his tools; he uses both without understanding either. Competent but disconnected from the people he governs.",
            ageCategory: "young",
            originLocation: "Washington, DC",
            familyBackground: "Party nobility. Father was a Fitzgerald-era Central Committee member who died in the Purges—not as a victim, but from stress. Mother remarried another official. Lincoln grew up in the capital's political hothouse, learning intrigue before he learned to drive. Married to a minister's daughter; no children yet. His wife hates the South and makes no secret of it.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Racial Pragmatism",
                    content: "Lincoln uses the South's racial tensions as tools. He plays Black and white communities against each other, making concessions to one to pressure the other. It's effective governance and deeply cynical. If his private memos about 'managing the Negro question' were published, he would be denounced as a counter-revolutionary racist.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Father's Purge Complicity",
                    content: "Lincoln's father survived the Purges by denouncing colleagues. He died of a heart attack after the Purges, but not before telling his son how he survived. Lincoln has never told anyone this family history. It shaped his understanding of how power works.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: "purge"
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "patterson",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "ally",
                    description: "Lincoln cultivates Patterson as his connection to the capital. She finds him useful for managing the South; he hopes she'll bring him back to Washington. A transactional relationship disguised as mentorship.",
                    sentiment: 60,
                    historicalOrigin: "Youth League networks"
                )
            ],
            historicalConnections: []
        ))

        // Zone Secretary - Industrial (index 3)
        characters.append(CharacterTemplate(
            id: "bodine",
            name: "Samuel Bodine",
            title: "Secretary of the Great Lakes Zone",
            role: "neutral",
            positionIndex: 3,
            positionTrack: "regional",
            personality: CharacterPersonality(ambitious: 50, paranoid: 35, ruthless: 40, competent: 75, loyal: 65, corrupt: 35),
            speechPattern: "Speaks with the pride of someone who runs a showcase industrial region. 'The steel we produce built this Republic.' Knows every factory manager by name. 'Comrade Peterson at Furnace Three has exceeded quota again.' More interested in production than politics. 'Let Washington play their games. We make steel.' Hands like a worker despite years behind a desk.",
            factionId: "regional",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born in Detroit, son of autoworkers. Started working the line at Ford when he was sixteen. Was there during the Siege of Detroit—saw Soviet weapons turn the tide, saw friends die in the winter fighting. After the Revolution, became a factory manager, then a zone administrator. The Great Lakes Zone is his life's work: the arsenal of the Republic. Knows every major plant, every production line, every bottleneck. Cares about making things, not about politics. Washington can play its games; Bodine makes steel. The simplest, most honest man at his level in the entire system—which makes him unusual and slightly suspect.",
            ageCategory: "middle-aged",
            originLocation: "Detroit, Michigan",
            familyBackground: "Working-class autoworker family. Father died at the Siege of Detroit—a true martyr. Mother moved to Cleveland; Bodine visits when he can. Married to a factory nurse; five children, all working in the zone's industries. The Bodine family makes steel—it's what they do.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Soviet Weapons",
                    content: "During the Siege of Detroit, Bodine helped distribute Soviet weapons to the workers' militia. He saw crates with Cyrillic writing, met men who spoke Russian. The official history says the Revolution was purely American. Bodine knows otherwise—and knows that saying so would be dangerous.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: "siege_detroit"
                ),
                CharacterSecretTemplate(
                    title: "The Simple Faith",
                    content: "Bodine believes the Revolution was good. Not complicated-believes, not with reservations—genuinely believes that socialism freed his people from Ford's tyranny. This simple faith sustains him. He doesn't see the system's failures because he doesn't want to. His wife worries this blindness will get him killed.",
                    tier: "narrativeOnly",
                    category: "weakness",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "sheridan",
                    targetCharacterName: "James Sheridan",
                    relationshipType: "ally",
                    description: "Fellow regional governors, both focused on making their zones work. They share a contempt for Washington's political games and a commitment to keeping their workers fed and their factories running. Industrial solidarity.",
                    sentiment: 70,
                    historicalOrigin: "Regional governors' coordination"
                ),
                CharacterRelationshipTemplate(
                    targetCharacterId: "thompson",
                    targetCharacterName: "Wesley Thompson",
                    relationshipType: "professional",
                    description: "Thompson comes from Bodine's territory—they knew each other from the Gary mills. Bodine respects Thompson's rise while being privately disappointed at how political he's become.",
                    sentiment: 50,
                    historicalOrigin: "Great Lakes industrial network"
                )
            ],
            historicalConnections: ["siege_detroit", "battle_chicago"]
        ))

        // ============================================
        // ADDITIONAL KEY FIGURES (Various positions)
        // ============================================

        // Senior Investigator - Security (index 2)
        characters.append(CharacterTemplate(
            id: "peterson",
            name: "Lieutenant Peterson",
            title: "Senior Investigator",
            role: "subordinate",
            positionIndex: 2,
            positionTrack: "securityServices",
            personality: CharacterPersonality(ambitious: 70, paranoid: 60, ruthless: 65, competent: 55, loyal: 50, corrupt: 40),
            speechPattern: "Speaks with the eager intensity of someone proving themselves. 'I have been reviewing the file, Comrade. There are inconsistencies.' Takes notes constantly. 'May I ask a few questions?' Young, ambitious, potentially dangerous. 'Everyone has a past, Comrade. Everyone.' Wants to impress his superiors—any superior.",
            factionId: "old_guard",
            isPatron: false,
            isRival: false,
            startingDisposition: 50,
            backstory: "Born in Washington, DC. A child of the Revolution who never knew the old world. Father was a BPS clerk; mother a typist. Raised on stories of counter-revolutionary threats lurking everywhere. Joined the security services straight from the Youth League, eager to protect the Revolution from its enemies. Assigned to internal investigations—looking for traitors among Party members. Genuinely believes enemies are everywhere. Ambitious in the dangerous way of young men who haven't learned what the work really means. Strickland likes him; Edwards finds him concerning.",
            ageCategory: "very young",
            originLocation: "Washington, DC",
            familyBackground: "Lower Party family. Parents are functionaries, not important but loyal. Only child, doted upon. Never experienced hardship, never questioned the system. The perfect product of revolutionary education. Unmarried—too focused on career advancement. Lives in a small apartment near BPS headquarters.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Manufactured Case",
                    content: "Peterson's first major case was a fabrication. He found insufficient evidence against the target, so he manufactured some—a forged document, a false witness statement. The target was sent to a labor camp. Peterson got promoted. He tells himself the man was probably guilty of something. The doubt never quite goes away.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: ["strickland"],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "strickland",
                    targetCharacterName: "Major Strickland",
                    relationshipType: "mentor",
                    description: "Strickland sees a younger version of himself in Peterson—the eagerness, the willingness to do what's necessary. Peterson admires Strickland's efficiency. Neither realizes this is not a compliment.",
                    sentiment: 65,
                    historicalOrigin: "BPS training"
                )
            ],
            historicalConnections: []
        ))

        // Embassy Counselor (index 2)
        characters.append(CharacterTemplate(
            id: "walsh",
            name: "Counselor Walsh",
            title: "Embassy Counselor - Ottawa",
            role: "subordinate",
            positionIndex: 2,
            positionTrack: "foreignAffairs",
            personality: CharacterPersonality(ambitious: 60, paranoid: 55, ruthless: 35, competent: 70, loyal: 55, corrupt: 35),
            speechPattern: "Speaks with the careful enthusiasm of a junior diplomat. 'The Canadians are most receptive to cultural exchange.' Reports everything to multiple masters. 'I thought the Ministry would want to know...' Caught between diplomatic service and security obligations. 'Some of my colleagues have... additional duties.' Wants a proper ambassadorship.",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born in Boston, son of a teacher and a Party organizer. Educated at the Party Academy, showed aptitude for languages—learned French and Russian. Assigned to the Ottawa embassy after the Purges, where he serves as counselor for cultural affairs. Officially promotes revolutionary culture to Canadians; unofficially reports to both the Ministry and the BPS. The dual reporting creates constant tension. He dreams of a proper ambassadorship somewhere warm—Mexico, maybe Cuba. Instead, he endures Ottawa winters and navigates Canadian politics while trying to please two masters who sometimes give contradictory orders.",
            ageCategory: "young",
            originLocation: "Boston, Massachusetts",
            familyBackground: "Middle Party family. Father teaches at a Party school; mother organizes community committees. Walsh was expected to enter Party service; he exceeded expectations by entering the diplomatic corps. Married to a Canadian woman—a genuine love match that causes endless security headaches. Two children, one born in Canada.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Canadian Wife",
                    content: "Walsh married a Canadian woman, Marie, while posted in Ottawa. The BPS approved it—useful for cover—but the relationship is real. His children are half-Canadian. If tensions with Canada escalate, his family becomes a liability. He would choose them over the Republic. He's never admitted this, even to himself.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "marshall",
                    targetCharacterName: "Secretary Marshall",
                    relationshipType: "professional",
                    description: "Walsh reports to Marshall's ministry but rarely interacts directly with the Secretary. He hopes Marshall notices his competence. So far, Walsh is just another name in the cable traffic.",
                    sentiment: 55,
                    historicalOrigin: "Ministry hierarchy"
                )
            ],
            historicalConnections: []
        ))

        // Senior Economist (index 2)
        characters.append(CharacterTemplate(
            id: "sutton",
            name: "Economist Sutton",
            title: "Senior Economist",
            role: "subordinate",
            positionIndex: 2,
            positionTrack: "economicPlanning",
            personality: CharacterPersonality(ambitious: 45, paranoid: 30, ruthless: 25, competent: 85, loyal: 60, corrupt: 20),
            speechPattern: "Speaks in pure mathematics when excited. 'The coefficients suggest a seventeen percent inefficiency in allocation...' Genuinely loves economic modeling. 'The elegant solution is often the correct one.' Frustrated by political interference. 'The numbers do not lie, comrade. People lie.' Keeps an abacus on his desk despite having a calculator.",
            factionId: "reformists",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born in Chicago, son of a mathematics professor who was quietly purged from the university for 'bourgeois methodology.' Inherited his father's love of numbers but learned to hide it behind revolutionary rhetoric. Studied at the Party Academy, showing such aptitude for economic modeling that even ideologues couldn't dismiss him. Assigned to the Planning Commission, where he runs input-output analysis for resource allocation. Could probably make the planned economy work—if anyone would let him. Instead, watches politicians adjust his careful models to fit their fantasies. Carpenter recognizes his talent; Kowalski barely knows his name.",
            ageCategory: "very young",
            originLocation: "Chicago, Illinois",
            familyBackground: "Academic family. Father was purged from his university position during the Purges; now works as a clerk. Mother teaches primary school. Sutton supports them both on his economist's salary. Unmarried—finds human relationships less tractable than economic ones. Has a cat who understands him better than most colleagues.",
            secrets: [
                CharacterSecretTemplate(
                    title: "Father's Purge",
                    content: "Sutton's father was purged from the university for teaching 'bourgeois economics.' He was lucky—just fired, not arrested. Sutton never mentions him at work. The connection could taint his career. He visits on weekends; they discuss mathematics together, pretending nothing is wrong.",
                    tier: "discoverable",
                    category: "family",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: "intellectuals_purge"
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "carpenter",
                    targetCharacterName: "Anthony Carpenter",
                    relationshipType: "mentor",
                    description: "Carpenter is one of the few people who understands Sutton's work. They speak the same mathematical language. Sutton admires Carpenter's brilliance and envies his position. Carpenter sees Sutton as a potential ally in the fight for rational planning.",
                    sentiment: 70,
                    historicalOrigin: "State Planning Commission"
                )
            ],
            historicalConnections: ["intellectuals_purge"]
        ))

        // Regimental Political Officer (index 2)
        characters.append(CharacterTemplate(
            id: "kowalczyk",
            name: "Captain Kowalczyk",
            title: "Regimental Political Officer",
            role: "subordinate",
            positionIndex: 2,
            positionTrack: "militaryPolitical",
            personality: CharacterPersonality(ambitious: 55, paranoid: 40, ruthless: 40, competent: 60, loyal: 75, corrupt: 25),
            speechPattern: "Speaks with the conviction of someone who lives with soldiers. 'The men need to understand why they serve.' Bridges the gap between officers and troops. 'I drink with privates and dine with colonels.' Genuinely cares about morale. 'A soldier who believes will fight harder than one who merely obeys.' Carries a well-worn copy of Revolutionary writings.",
            factionId: "princelings",
            isPatron: false,
            isRival: false,
            startingDisposition: 60,
            backstory: "Born Jan Kowalczyk in Pittsburgh's Polish community—no relation to Director Kowalski despite the similar names. Father was a steelworker who died at the Pittsburgh Massacre; mother raised six children on workers' compensation and community support. Jan enlisted at eighteen, fought in the Intervention War against Canadian forces. Saw enough combat to understand that soldiers need more than orders—they need reasons. Transferred to political work, rose through the ranks by being genuine. The troops like him; he actually listens. Spencer is his model of what a commissar should be. His future depends on staying authentic in a system that rewards cynicism.",
            ageCategory: "very young",
            originLocation: "Pittsburgh, Pennsylvania",
            familyBackground: "Polish-American working-class family, Pittsburgh Massacre martyrdom. Mother still lives in the old neighborhood. Five siblings scattered across the Republic—one brother is a zone party secretary, another works the docks, three sisters married to workers and soldiers. Strong family bonds. Married to his high school sweetheart; three young children. The family waits anxiously whenever he's deployed.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Friendly Fire",
                    content: "During the Intervention War, Kowalczyk's unit came under artillery fire. They returned fire—at what turned out to be another American unit in the confusion of battle. Kowalczyk's report blamed Canadian infiltrators for the miscommunication. The truth would have ended careers, possibly lives. He still wonders if he should have told the truth.",
                    tier: "discoverable",
                    category: "crime",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "spencer",
                    targetCharacterName: "Major Spencer",
                    relationshipType: "ally",
                    description: "Spencer is what Kowalczyk hopes to become—a commissar who genuinely believes and genuinely cares. They share the same idealism, the same frustration with cynics. Working together restores Kowalczyk's faith in the system.",
                    sentiment: 70,
                    historicalOrigin: "Political Directorate assignments"
                )
            ],
            historicalConnections: ["pittsburgh_massacre"]
        ))

        // Instructor of Central Committee (index 2)
        characters.append(CharacterTemplate(
            id: "kennedy",
            name: "Instructor Kennedy",
            title: "Instructor of the Central Committee",
            role: "subordinate",
            positionIndex: 2,
            positionTrack: "partyApparatus",
            personality: CharacterPersonality(ambitious: 65, paranoid: 50, ruthless: 45, competent: 65, loyal: 60, corrupt: 30),
            speechPattern: "Speaks with the authority of someone who knows where the bodies are buried—metaphorically. 'I have visited forty-seven zone committees this year.' Extensive knowledge of local cadres. 'Comrade Irving in the Southern Zone has potential. Comrade Parker does not.' Eyes and ears of the Central Committee. 'The zones cannot hide from us.'",
            factionId: "youth_league",
            isPatron: false,
            isRival: false,
            startingDisposition: 55,
            backstory: "Born Robert Kennedy in New York City—Irish-American family, father a Tammany Hall precinct captain who switched sides during the Revolution. Learned politics at his father's knee: who's up, who's down, who owes whom. Rose through the Youth League by being useful—remembering names, tracking favors, knowing everyone's secrets. Assigned as an Instructor of the Central Committee, traveling to zones to evaluate local cadres. His reports can make or break careers. Lives in trains and zone capital hotels, constantly moving, constantly watching. Patterson finds him useful; he hopes she remembers that when promotion time comes.",
            ageCategory: "young",
            originLocation: "New York City",
            familyBackground: "Irish-American political family. Father was Tammany Hall, switched to the Revolution at the start of the Revolution—opportunism or genuine conversion, no one's sure. Mother ran the household like a ward office. Kennedy inherited his father's talent for political machinery. Married briefly; divorced after she couldn't handle his constant travel. No children. The Party is his family now.",
            secrets: [
                CharacterSecretTemplate(
                    title: "The Files",
                    content: "Kennedy keeps private files on everyone he evaluates—not the official reports, but personal observations, rumors, suspicions. Who's drinking too much, who's sleeping with whom, who has debts. He's been building this collection for years. It's his insurance policy. If discovered, it would look like he's building a parallel intelligence service—which, in a way, he is.",
                    tier: "discoverable",
                    category: "political",
                    canBeUsedAsLeverage: true,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                ),
                CharacterSecretTemplate(
                    title: "Father's Opportunism",
                    content: "Kennedy's father switched from Tammany Hall to the Revolution when he saw which way the wind was blowing. The family prospered; others who made the wrong choice did not. Kennedy never talks about his father's past. But he wonders sometimes if political flexibility is inherited—and if it's a virtue or a vice.",
                    tier: "narrativeOnly",
                    category: "family",
                    canBeUsedAsLeverage: false,
                    associatedCharacterIds: [],
                    historicalEventId: nil
                )
            ],
            relationships: [
                CharacterRelationshipTemplate(
                    targetCharacterId: "patterson",
                    targetCharacterName: "Eleanor Patterson",
                    relationshipType: "professional",
                    description: "Kennedy reports to Patterson through the Central Committee apparatus. She values his detailed knowledge of zone-level cadres; he hopes to leverage this into a more prominent position. A transactional relationship that serves both parties.",
                    sentiment: 55,
                    historicalOrigin: "Central Committee work"
                )
            ],
            historicalConnections: []
        ))

        return characters
    }
}
