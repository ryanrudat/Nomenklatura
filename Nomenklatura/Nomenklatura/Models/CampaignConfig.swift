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

    /// American socialist terminology for the PSRA
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
    var deskSubtitle: String      // "The Presidium" / "Standing Committee"
    var ladderTitle: String       // "The Ladder" / "Party Hierarchy"
    var dossierTitle: String      // "The Dossier" / "Personnel Files"
    var ledgerTitle: String       // "The Ledger" / "State of Affairs"
    var fallenTitle: String       // "FALLEN" / "REMOVED"

    static var soviet: ScreenLabels {
        ScreenLabels(
            deskTitle: "The Desk",
            deskSubtitle: "The Presidium",
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

    /// American socialist screen labels for the PSRA
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
            era: "Cold War · 1950s-1960s",
            description: "Navigate the treacherous politics of the Presidium. Survive purges, outmaneuver rivals, position yourself for succession.",
            nationName: "The People's Socialist Republic",
            leaderTitle: "General Secretary",
            currencyName: "rubles",
            startingPosition: 1,
            startingStats: StartingStats(
                stability: 50,
                popularSupport: 50,
                militaryLoyalty: 60,
                eliteLoyalty: 55,
                treasury: 45,
                industrialOutput: 50,
                foodSupply: 40,
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
            PersonalAction(id: "challenge_rival", category: .makeYourPlay, title: "Challenge Kovacs at Presidium", description: "Publicly expose his failures and demand his removal.", costAP: 2, riskLevel: .high, requirements: ActionRequirements(minStanding: 70, minNetwork: 50, requiredFlags: ["kovacs_weakness_known"]), effects: ["rivalThreat": -30, "standing": 15, "reputationRuthless": 10], isLocked: true, lockReason: "Requires Standing 70+, Network 50+, and intelligence on Kovacs"),
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
            title: "Junior Presidium Member",
            description: "You have a seat at the table, but little influence. Your work will be noticed—your path forward branches from here.",
            requiredStanding: 15, maxHolders: 10,
            unlockedActions: ["attend_presidium", "vote_policy"],
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
            startingDisposition: 50
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
            startingDisposition: 50
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
            startingDisposition: 45
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
            startingDisposition: 65
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
            startingDisposition: 50
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 55
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
            startingDisposition: 55
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
            isRival: true,
            startingDisposition: 55
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
            startingDisposition: 45
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
            startingDisposition: 40
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 60
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
            startingDisposition: 55
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
            startingDisposition: 45
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
            startingDisposition: 35
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
            startingDisposition: 55
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
            startingDisposition: 50
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
            startingDisposition: 60
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 55
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
            startingDisposition: 60
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
            startingDisposition: 55
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
            startingDisposition: 50
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
            startingDisposition: 50
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
            startingDisposition: 60
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
            startingDisposition: 50
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
            startingDisposition: 55
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
            startingDisposition: 60
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
            startingDisposition: 60
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
            startingDisposition: 55
        ))

        return characters
    }
}
