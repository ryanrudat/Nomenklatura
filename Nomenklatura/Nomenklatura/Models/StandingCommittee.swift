//
//  StandingCommittee.swift
//  Nomenklatura
//
//  The Standing Committee (Politburo Standing Committee / Presidium)
//  The inner circle of power that makes major decisions
//

import Foundation
import SwiftData

// MARK: - Standing Committee Rank

/// Hierarchical ranks within the Standing Committee
/// Note: SC membership is separate from administrative position.
/// A member can hold any position while serving on the Standing Committee.
enum SCRank: String, Codable, CaseIterable, Comparable {
    case candidateMember = "Candidate Member"     // Probationary, advisory vote only
    case fullMember = "Full Member"               // Full voting rights
    case chairman = "Chairman"                    // General Secretary, chairs the committee

    var displayName: String { rawValue }

    var abbreviation: String {
        switch self {
        case .candidateMember: return "SC-C"
        case .fullMember: return "SC"
        case .chairman: return "GS"
        }
    }

    var description: String {
        switch self {
        case .candidateMember:
            return "Candidate Members attend meetings and may speak, but their votes are advisory. They are being evaluated for full membership."
        case .fullMember:
            return "Full Members have equal voting rights on all matters before the Committee. They form the inner circle of power."
        case .chairman:
            return "The Chairman sets the agenda, breaks ties, and speaks for the Committee. First among equals—in theory."
        }
    }

    /// Seniority order for comparison
    var seniority: Int {
        switch self {
        case .candidateMember: return 1
        case .fullMember: return 2
        case .chairman: return 3
        }
    }

    static func < (lhs: SCRank, rhs: SCRank) -> Bool {
        lhs.seniority < rhs.seniority
    }
}

// MARK: - Standing Committee Model

@Model
final class StandingCommittee {
    var id: UUID = UUID()

    // Committee composition - membership is SEPARATE from administrative position
    // A minister, party secretary, or anyone can be on the SC regardless of their job title
    var fullMemberIds: [String]      // Full members with voting rights (character template IDs)
    var candidateMemberIds: [String] // Candidate members with advisory votes
    var chairId: String?             // General Secretary / Chairman
    var secretaryId: String?         // Committee Secretary (procedural)

    // Player SC status (tracked separately since player isn't in characters array)
    var playerIsOnCommittee: Bool = false
    var playerRank: String?          // "candidateMember", "fullMember", or "chairman"

    // Committee state
    var lastMeetingTurn: Int         // When committee last convened
    var pendingAgendaData: Data?     // Encoded [CommitteeAgendaItem]
    var meetingMinutesData: Data?    // Encoded [CommitteeMeeting]

    // Power dynamics
    var factionBalanceData: Data?    // Encoded [String: Int] faction power on committee

    // Relationship back to game
    @Relationship var game: Game?

    init() {
        self.fullMemberIds = []
        self.candidateMemberIds = []
        self.lastMeetingTurn = 0
    }

    /// All member IDs (full + candidate)
    var memberIds: [String] {
        fullMemberIds + candidateMemberIds
    }

    // MARK: - Computed Properties

    var pendingAgenda: [CommitteeAgendaItem] {
        get {
            guard let data = pendingAgendaData else { return [] }
            return (try? JSONDecoder().decode([CommitteeAgendaItem].self, from: data)) ?? []
        }
        set {
            pendingAgendaData = try? JSONEncoder().encode(newValue)
        }
    }

    var meetingMinutes: [CommitteeMeeting] {
        get {
            guard let data = meetingMinutesData else { return [] }
            return (try? JSONDecoder().decode([CommitteeMeeting].self, from: data)) ?? []
        }
        set {
            meetingMinutesData = try? JSONEncoder().encode(newValue)
        }
    }

    var factionBalance: [String: Int] {
        get {
            guard let data = factionBalanceData else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
        }
        set {
            factionBalanceData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Number of seats on the committee (typically 5-9)
    var seatCount: Int {
        fullMemberIds.count + candidateMemberIds.count + (playerIsOnCommittee ? 1 : 0)
    }

    /// Check if player is a full member (not just candidate)
    var playerIsFullMember: Bool {
        guard let rank = playerRank else { return false }
        return rank == SCRank.fullMember.rawValue || rank == SCRank.chairman.rawValue
    }

    /// Check if player is committee chair
    var playerIsChair: Bool {
        playerRank == SCRank.chairman.rawValue
    }

    /// Get the player's Standing Committee rank
    var playerSCRank: SCRank? {
        guard playerIsOnCommittee, let rank = playerRank else { return nil }
        return SCRank(rawValue: rank)
    }

    /// Get the SC rank for a character
    func getRank(for characterId: String) -> SCRank? {
        if characterId == chairId {
            return .chairman
        } else if fullMemberIds.contains(characterId) {
            return .fullMember
        } else if candidateMemberIds.contains(characterId) {
            return .candidateMember
        }
        return nil
    }

    /// Check if a character is on the committee
    func isMember(_ characterId: String) -> Bool {
        fullMemberIds.contains(characterId) ||
        candidateMemberIds.contains(characterId) ||
        characterId == chairId
    }

    // MARK: - Player Membership Management

    /// Promote player to Standing Committee
    func addPlayer(as rank: SCRank) {
        playerIsOnCommittee = true
        playerRank = rank.rawValue
    }

    /// Remove player from Standing Committee
    func removePlayer() {
        playerIsOnCommittee = false
        playerRank = nil
    }

    /// Promote player to a higher rank
    func promotePlayer(to rank: SCRank) {
        guard playerIsOnCommittee else { return }
        playerRank = rank.rawValue
    }
}

// MARK: - Committee Agenda Item

struct CommitteeAgendaItem: Codable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var description: String
    var category: AgendaCategory
    var priority: AgendaPriority
    var sponsorId: String?           // Who submitted this item
    var turnSubmitted: Int

    // Voting tracking
    var hasBeenVoted: Bool = false
    var votesFor: [String] = []      // Member IDs who voted for
    var votesAgainst: [String] = []  // Member IDs who voted against
    var abstentions: [String] = []   // Member IDs who abstained

    var passed: Bool {
        votesFor.count > votesAgainst.count
    }

    var wasUnanimous: Bool {
        votesAgainst.isEmpty && abstentions.isEmpty
    }

    enum AgendaCategory: String, Codable {
        case personnel          // Appointments, dismissals
        case policy             // Major policy decisions
        case economic           // Economic planning
        case foreign            // Foreign policy
        case security           // Security matters
        case ideological        // Ideological campaigns
        case crisis             // Emergency matters
        case succession         // Leadership succession
    }

    enum AgendaPriority: String, Codable {
        case routine
        case important
        case urgent
        case critical
    }
}

// MARK: - Committee Meeting

struct CommitteeMeeting: Codable, Identifiable {
    var id: String = UUID().uuidString
    var turnHeld: Int
    var attendeeIds: [String]        // Who was present
    var itemsDiscussed: [String]     // Agenda item IDs
    var decisionsReached: [CommitteeDecision]
    var atmosphere: MeetingAtmosphere

    enum MeetingAtmosphere: String, Codable {
        case harmonious      // Unity, consensus
        case tense           // Disagreements present
        case confrontational // Open conflict
        case performative    // Going through motions
    }
}

struct CommitteeDecision: Codable, Identifiable {
    var id: String = UUID().uuidString
    var agendaItemId: String
    var outcome: DecisionOutcome
    var votingRecord: VotingRecord
    var dissenterIds: [String]       // Who opposed (may face consequences)
    var narrativeSummary: String

    enum DecisionOutcome: String, Codable {
        case approved
        case rejected
        case deferred
        case amendedAndApproved
        case referredToSubcommittee
    }
}

struct VotingRecord: Codable {
    var votesFor: Int
    var votesAgainst: Int
    var abstentions: Int
    var isUnanimous: Bool

    var totalVotes: Int {
        votesFor + votesAgainst + abstentions
    }

    var passedByMajority: Bool {
        votesFor > votesAgainst
    }
}

// MARK: - Standing Committee Service

final class StandingCommitteeService {
    static let shared = StandingCommitteeService()

    private init() {}

    // MARK: - Committee Initialization

    /// Initialize the Standing Committee with the most powerful characters
    /// Note: SC membership is NOT tied to administrative position.
    /// A minister, regional leader, or party secretary can all serve on the SC.
    func initializeCommittee(for game: Game) -> StandingCommittee {
        let committee = StandingCommittee()
        committee.game = game

        // Find the most powerful characters to be committee members
        // Selection criteria: influence (standing), faction leadership, experience
        let eligibleMembers = game.characters
            .filter { $0.isAlive && $0.positionIndex != nil }
            .sorted { characterPower($0) > characterPower($1) }

        // Take top members for the committee
        let fullMembers = eligibleMembers.prefix(5)  // 5 full members
        let candidateMembers = eligibleMembers.dropFirst(5).prefix(2)  // 2 candidate members

        committee.fullMemberIds = fullMembers.map { $0.templateId }
        committee.candidateMemberIds = candidateMembers.map { $0.templateId }

        // Set chair as highest-power member
        if let chair = fullMembers.first {
            committee.chairId = chair.templateId
        }

        // Calculate faction balance
        updateFactionBalance(committee: committee, game: game)

        return committee
    }

    /// Calculate a character's power for SC selection
    /// This determines who gets on the committee - not their job title
    private func characterPower(_ character: GameCharacter) -> Int {
        var power = 0

        // Influence is primary factor
        power += character.remainingInfluence * 2

        // Position does contribute but isn't sole factor
        power += (character.positionIndex ?? 0) * 10

        // Faction loyalty indicates political clout
        power += character.factionLoyalty / 2

        // Disposition toward player matters for political alignments
        power += max(0, character.disposition / 5)

        // Veteran bonus (senior experience = more connections)
        power += min(character.turnsAtSeniorPosition, 20) * 2

        // Competence bonus
        power += character.personalityCompetent / 5

        return power
    }

    /// Update faction balance on the committee
    func updateFactionBalance(committee: StandingCommittee, game: Game) {
        var balance: [String: Int] = [:]

        for memberId in committee.memberIds {
            if let member = game.characters.first(where: { $0.templateId == memberId }),
               let factionId = member.factionId {
                balance[factionId, default: 0] += 1
            }
        }

        committee.factionBalance = balance
    }

    // MARK: - Eligibility and Elections

    /// Check if a character is eligible for Standing Committee membership
    func isEligibleForStandingCommittee(_ character: GameCharacter, game: Game) -> SCEligibilityResult {
        var failureReasons: [String] = []

        // Must be alive
        guard character.isAlive else {
            return SCEligibilityResult(isEligible: false, reasons: ["Not active"])
        }

        // Position Level 5+ (Senior Politburo)
        let position = character.positionIndex ?? 0
        if position < 5 {
            failureReasons.append("Position must be Senior Politburo (5+), currently \(position)")
        }

        // Senior Tenure 12+ turns at position 4+ (3+ years in senior positions)
        if character.turnsAtSeniorPosition < 12 {
            failureReasons.append("Need 12+ turns at senior level, have \(character.turnsAtSeniorPosition)")
        }

        // Not under active investigation or detained
        if character.currentStatus == .underInvestigation || character.currentStatus == .detained {
            failureReasons.append("Under active investigation or detention")
        }

        // Competence 50+
        if character.personalityCompetent < 50 {
            failureReasons.append("Competence must be 50+, currently \(character.personalityCompetent)")
        }

        // Loyalty 40+
        if character.personalityLoyal < 40 {
            failureReasons.append("Loyalty must be 40+, currently \(character.personalityLoyal)")
        }

        // Must have faction alignment
        if character.factionId == nil || character.factionId?.isEmpty == true {
            failureReasons.append("Must be aligned with a major faction")
        }

        return SCEligibilityResult(
            isEligible: failureReasons.isEmpty,
            reasons: failureReasons.isEmpty ? ["Meets all eligibility criteria"] : failureReasons
        )
    }

    /// Get all eligible candidates for Standing Committee
    func getEligibleCandidates(for game: Game) -> [GameCharacter] {
        game.characters.filter { character in
            isEligibleForStandingCommittee(character, game: game).isEligible
        }.sorted { ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0) }
    }

    /// Run Standing Committee election at Party Congress (every 20 turns)
    /// Returns the new committee composition
    func runPartyCongressElection(game: Game) -> SCElectionResult {
        guard let committee = game.standingCommittee else {
            return SCElectionResult(
                newMembers: [],
                removedMembers: [],
                narrative: "No Standing Committee exists."
            )
        }

        // Get eligible candidates
        let candidates = getEligibleCandidates(for: game)

        // Get General Secretary (chair) for endorsement weighting
        let chair = game.characters.first { $0.templateId == committee.chairId }
        let chairFactionId = chair?.factionId

        // Calculate election scores for each candidate
        var candidateScores: [(character: GameCharacter, score: Double)] = []

        for candidate in candidates {
            let score = calculateElectionScore(
                candidate: candidate,
                game: game,
                chairFactionId: chairFactionId
            )
            candidateScores.append((candidate, score))
        }

        // Sort by score and select top 7
        candidateScores.sort { $0.score > $1.score }
        let elected = candidateScores.prefix(7).map { $0.character }

        // Determine who was removed and who is new
        let previousMemberIds = Set(committee.memberIds)
        let newMemberIds = Set(elected.map { $0.templateId })

        let removedMemberIds = previousMemberIds.subtracting(newMemberIds)
        let addedMemberIds = newMemberIds.subtracting(previousMemberIds)

        let removedMembers = removedMemberIds.compactMap { id in
            game.characters.first { $0.templateId == id }
        }
        let addedMembers = addedMemberIds.compactMap { id in
            game.characters.first { $0.templateId == id }
        }

        // Update committee composition - split into full and candidate members
        let fullMemberCount = 5
        committee.fullMemberIds = elected.prefix(fullMemberCount).map { $0.templateId }
        committee.candidateMemberIds = elected.dropFirst(fullMemberCount).map { $0.templateId }

        // Chair is the highest-ranked or General Secretary
        if let newChair = elected.first(where: { ($0.positionIndex ?? 0) >= 8 }) ?? elected.first {
            committee.chairId = newChair.templateId
        }

        // Update faction balance
        updateFactionBalance(committee: committee, game: game)

        // Generate narrative
        let narrative = generateElectionNarrative(
            addedMembers: addedMembers,
            removedMembers: removedMembers,
            chair: chair,
            game: game
        )

        return SCElectionResult(
            newMembers: addedMembers,
            removedMembers: removedMembers,
            narrative: narrative
        )
    }

    /// Calculate election score for a candidate
    /// Weights: Faction power (40%) + GS endorsement (30%) + Competence (20%) + Track (10%)
    private func calculateElectionScore(
        candidate: GameCharacter,
        game: Game,
        chairFactionId: String?
    ) -> Double {
        var score: Double = 0

        // Faction power (40% weight)
        if let factionId = candidate.factionId,
           let faction = game.factions.first(where: { $0.factionId == factionId }) {
            score += Double(faction.power) * 0.4
        }

        // GS endorsement (30% weight) - same faction as chair gets bonus
        if let chairFaction = chairFactionId, candidate.factionId == chairFaction {
            score += 30.0  // Full endorsement
        } else if chairFactionId != nil {
            // Partial endorsement based on faction relations
            // For now, give 10 points for non-hostile factions
            score += 10.0
        }

        // Competence/personality (20% weight)
        let competenceScore = Double(candidate.personalityCompetent) / 100.0 * 15.0
        let loyaltyScore = Double(candidate.personalityLoyal) / 100.0 * 5.0
        score += competenceScore + loyaltyScore

        // Track/position performance (10% weight)
        let positionScore = Double(candidate.positionIndex ?? 0) * 1.5
        score += min(positionScore, 10.0)

        // Random variance (+/- 5%)
        let variance = Double.random(in: -5...5)
        score += variance

        return max(0, score)
    }

    /// Generate narrative for election results
    private func generateElectionNarrative(
        addedMembers: [GameCharacter],
        removedMembers: [GameCharacter],
        chair: GameCharacter?,
        game: Game
    ) -> String {
        var narrative = "The Party Congress has concluded its deliberations on Standing Committee composition.\n\n"

        if addedMembers.isEmpty && removedMembers.isEmpty {
            narrative += "The existing committee was reconfirmed in its entirety—a vote of confidence in the current leadership."
        } else {
            if !addedMembers.isEmpty {
                let names = addedMembers.map { $0.name }.joined(separator: ", ")
                narrative += "Newly elected to the Standing Committee: \(names).\n"
            }

            if !removedMembers.isEmpty {
                let names = removedMembers.map { $0.name }.joined(separator: ", ")
                narrative += "\nDeparting the Standing Committee: \(names). Their contributions to the Party are acknowledged."
            }
        }

        if let chair = chair {
            narrative += "\n\n\(chair.name) continues as Committee Chair, guiding the inner circle's deliberations."
        }

        return narrative
    }

    /// Fill a vacant seat on the Standing Committee (between Congress sessions)
    /// The General Secretary appoints replacements
    func fillVacancy(committee: StandingCommittee, game: Game) -> GameCharacter? {
        guard committee.memberIds.count < 7 else { return nil }

        // Get eligible candidates not already on committee
        let candidates = getEligibleCandidates(for: game)
            .filter { !committee.memberIds.contains($0.templateId) }

        // Chair's faction gets preference
        let chairFactionId = game.characters
            .first { $0.templateId == committee.chairId }?
            .factionId

        // Prefer chair's faction members
        let preferredCandidates = candidates.filter { $0.factionId == chairFactionId }
        let appointee = preferredCandidates.first ?? candidates.first

        if let appointee = appointee {
            // New appointments start as candidate members
            committee.candidateMemberIds.append(appointee.templateId)
            updateFactionBalance(committee: committee, game: game)
            return appointee
        }

        return nil
    }

    /// Update senior tenure for all characters (call at end of each turn)
    func updateSeniorTenure(game: Game) {
        for character in game.characters where character.isAlive {
            let position = character.positionIndex ?? 0
            if position >= 4 {
                character.turnsAtSeniorPosition += 1
            }
        }
    }

    // MARK: - Law Proposals

    /// Submit a law change proposal to the Standing Committee agenda
    func proposeLawChange(
        law: Law,
        newState: LawState,
        sponsor: GameCharacter?,
        game: Game
    ) -> Bool {
        guard let committee = game.standingCommittee else { return false }

        // Check if sponsor is on committee
        if let sponsor = sponsor, !committee.memberIds.contains(sponsor.templateId) {
            return false
        }

        // Create agenda item for the law change
        let item = CommitteeAgendaItem(
            title: "Modify: \(law.name)",
            description: "Proposal to change \(law.name) from \(law.lawCurrentState.displayName) to \(newState.displayName)",
            category: .policy,
            priority: law.lawCategory == .institutional ? .critical : .important,
            sponsorId: sponsor?.templateId,
            turnSubmitted: game.turnNumber
        )

        var agenda = committee.pendingAgenda
        agenda.append(item)
        committee.pendingAgenda = agenda

        return true
    }

    /// Process a law change vote result
    func processLawChangeVote(
        item: CommitteeAgendaItem,
        law: Law,
        newState: LawState,
        passed: Bool,
        sponsorName: String,
        game: Game
    ) {
        if passed {
            law.modify(
                to: newState,
                by: sponsorName,
                forced: false,
                turn: game.turnNumber
            )

            game.lawsModifiedCount += 1

            // Check for term limits abolition
            if law.lawId == "term_limits" && newState == .abolished {
                game.termLimitsAbolished = true
            }

            // Generate consequences for law changes
            generateLawConsequences(law: law, newState: newState, game: game)
        }
    }

    /// Generate consequences for changing a law
    private func generateLawConsequences(law: Law, newState: LawState, game: Game) {
        // Schedule consequences based on law category and change severity
        let category = law.lawCategory
        let currentTurn = game.turnNumber

        // More severe changes = more consequences
        let severity: Int = {
            switch newState {
            case .abolished: return 3
            case .modifiedStrong: return 2
            case .strengthened, .modifiedWeak: return 1
            case .defaultState: return 0
            }
        }()

        guard severity > 0 else { return }

        // Institutional laws generate elite backlash
        if category == .institutional {
            let consequence = ScheduledConsequence(
                triggerTurn: currentTurn + 2,
                type: .eliteBacklash,
                magnitude: 20 * severity,
                description: "Elite backlash to \(law.name) changes",
                relatedLawId: law.lawId
            )
            law.addConsequence(consequence)
        }

        // Economic laws affect treasury/output
        if category == .economic {
            let consequence = ScheduledConsequence(
                triggerTurn: currentTurn + 3,
                type: .economicEffect,
                magnitude: 15 * severity,
                description: "Economic effects of \(law.name) changes",
                relatedLawId: law.lawId,
                statEffects: ["treasury": -5 * severity, "industrialOutput": -3 * severity]
            )
            law.addConsequence(consequence)
        }

        // Political laws may cause popular unrest
        if category == .political {
            let consequence = ScheduledConsequence(
                triggerTurn: currentTurn + 2,
                type: .popularUnrest,
                magnitude: 10 * severity,
                description: "Popular reaction to \(law.name) changes",
                relatedLawId: law.lawId
            )
            law.addConsequence(consequence)
        }

        // Faction-related consequences
        for loserId in law.losers {
            if let loserFaction = game.factions.first(where: { $0.factionId == loserId }) {
                loserFaction.playerStanding = max(0, loserFaction.playerStanding - 10 * severity)
            }
        }

        for beneficiaryId in law.beneficiaries {
            if let beneficiary = game.factions.first(where: { $0.factionId == beneficiaryId }) {
                beneficiary.playerStanding = min(100, beneficiary.playerStanding + 5 * severity)
            }
        }
    }

    // MARK: - Agenda Management

    /// Add an item to the committee's agenda
    func submitAgendaItem(
        to committee: StandingCommittee,
        title: String,
        description: String,
        category: CommitteeAgendaItem.AgendaCategory,
        priority: CommitteeAgendaItem.AgendaPriority,
        sponsor: GameCharacter?,
        game: Game
    ) {
        let item = CommitteeAgendaItem(
            title: title,
            description: description,
            category: category,
            priority: priority,
            sponsorId: sponsor?.templateId,
            turnSubmitted: game.turnNumber
        )

        var agenda = committee.pendingAgenda
        agenda.append(item)
        committee.pendingAgenda = agenda
    }

    // MARK: - Meeting Simulation

    /// Convene a committee meeting
    func conveneMeeting(committee: StandingCommittee, game: Game) -> CommitteeMeetingResult {
        var meeting = CommitteeMeeting(
            turnHeld: game.turnNumber,
            attendeeIds: committee.memberIds,
            itemsDiscussed: [],
            decisionsReached: [],
            atmosphere: determineAtmosphere(committee: committee, game: game)
        )

        var processedItems: [CommitteeAgendaItem] = []
        var results: [CommitteeDecisionResult] = []

        // Process each agenda item
        for item in committee.pendingAgenda.sorted(by: { priorityOrder($0.priority) > priorityOrder($1.priority) }) {
            let result = processAgendaItem(item: item, committee: committee, meeting: &meeting, game: game)
            results.append(result)

            var updatedItem = item
            updatedItem.hasBeenVoted = true
            updatedItem.votesFor = result.votesFor.map { $0.templateId }
            updatedItem.votesAgainst = result.votesAgainst.map { $0.templateId }
            updatedItem.abstentions = result.abstentions.map { $0.templateId }
            processedItems.append(updatedItem)

            meeting.itemsDiscussed.append(item.id)
        }

        // Clear the agenda
        committee.pendingAgenda = []

        // Store meeting minutes
        var minutes = committee.meetingMinutes
        minutes.append(meeting)
        committee.meetingMinutes = minutes

        committee.lastMeetingTurn = game.turnNumber

        // Generate narrative
        let narrative = generateMeetingNarrative(meeting: meeting, results: results, game: game)

        return CommitteeMeetingResult(
            meeting: meeting,
            itemResults: results,
            narrative: narrative
        )
    }

    private func priorityOrder(_ priority: CommitteeAgendaItem.AgendaPriority) -> Int {
        switch priority {
        case .routine: return 1
        case .important: return 2
        case .urgent: return 3
        case .critical: return 4
        }
    }

    private func determineAtmosphere(committee: StandingCommittee, game: Game) -> CommitteeMeeting.MeetingAtmosphere {
        // Check for factional tension
        let factionCount = committee.factionBalance.filter { $0.value > 0 }.count
        let hasStrongOpposition = committee.factionBalance.values.max() ?? 0 < (committee.seatCount / 2)

        if game.stability < 30 || hasStrongOpposition {
            return .confrontational
        } else if factionCount > 2 || game.stability < 50 {
            return .tense
        } else if game.stability > 70 && factionCount <= 2 {
            return .harmonious
        }

        return .performative
    }

    // MARK: - Voting Simulation

    private func processAgendaItem(
        item: CommitteeAgendaItem,
        committee: StandingCommittee,
        meeting: inout CommitteeMeeting,
        game: Game
    ) -> CommitteeDecisionResult {
        var votesFor: [GameCharacter] = []
        var votesAgainst: [GameCharacter] = []
        var abstentions: [GameCharacter] = []

        // Get members
        let members = committee.memberIds.compactMap { memberId in
            game.characters.first { $0.templateId == memberId }
        }

        // Chair votes first and sets the tone
        let chair = members.first { $0.templateId == committee.chairId }
        let chairVoteFor = determineVote(member: chair, item: item, isChairVote: nil, game: game)

        for member in members {
            let votesWithChair = determineVote(member: member, item: item, isChairVote: chairVoteFor, game: game)

            if votesWithChair == nil {
                abstentions.append(member)
            } else if votesWithChair == true {
                votesFor.append(member)
            } else {
                votesAgainst.append(member)
            }
        }

        // Determine outcome
        let outcome: CommitteeDecision.DecisionOutcome
        if votesFor.count > votesAgainst.count {
            outcome = abstentions.isEmpty ? .approved : .amendedAndApproved
        } else if votesFor.count == votesAgainst.count {
            outcome = .deferred
        } else {
            outcome = .rejected
        }

        // Create decision record
        let decision = CommitteeDecision(
            agendaItemId: item.id,
            outcome: outcome,
            votingRecord: VotingRecord(
                votesFor: votesFor.count,
                votesAgainst: votesAgainst.count,
                abstentions: abstentions.count,
                isUnanimous: votesAgainst.isEmpty && abstentions.isEmpty
            ),
            dissenterIds: votesAgainst.map { $0.templateId },
            narrativeSummary: generateDecisionNarrative(item: item, outcome: outcome)
        )

        meeting.decisionsReached.append(decision)

        return CommitteeDecisionResult(
            item: item,
            outcome: outcome,
            votesFor: votesFor,
            votesAgainst: votesAgainst,
            abstentions: abstentions,
            narrative: decision.narrativeSummary
        )
    }

    private func determineVote(
        member: GameCharacter?,
        item: CommitteeAgendaItem,
        isChairVote: Bool?,
        game: Game
    ) -> Bool? {
        guard let member = member else { return nil }

        // Base vote on personality and category alignment
        var voteScore = 50  // Neutral starting point

        // Loyal members follow the chair
        if let chairVote = isChairVote {
            voteScore += member.personalityLoyal / 2 * (chairVote ? 1 : -1)
        }

        // Ambitious members support items that increase power
        if item.category == .personnel {
            voteScore += member.personalityAmbitious / 4
        }

        // Ruthless members support security/purge measures
        if item.category == .security {
            voteScore += member.personalityRuthless / 3
        }

        // Competent members evaluate based on merit
        if member.personalityCompetent > 70 {
            // More likely to abstain if item seems poorly thought out
            if item.priority == .routine && Int.random(in: 1...100) < 20 {
                return nil  // Abstain
            }
        }

        // Paranoid members avoid controversial positions
        if member.personalityParanoid > 60 && isChairVote == nil {
            // Wait to see which way the wind blows
            return nil
        }

        // Faction alignment
        if let sponsorId = item.sponsorId,
           let sponsor = game.characters.first(where: { $0.templateId == sponsorId }) {
            if sponsor.factionId == member.factionId {
                voteScore += 20  // Support faction ally
            } else if let relationship = game.npcRelationships.first(where: {
                $0.sourceCharacterId == member.templateId && $0.targetCharacterId == sponsorId
            }) {
                voteScore += relationship.disposition / 4
            }
        }

        // Add randomness
        voteScore += Int.random(in: -15...15)

        // Determine vote
        if voteScore > 60 {
            return true
        } else if voteScore < 40 {
            return false
        } else {
            return nil  // Abstain in uncertain cases
        }
    }

    // MARK: - Narrative Generation

    private func generateMeetingNarrative(
        meeting: CommitteeMeeting,
        results: [CommitteeDecisionResult],
        game: Game
    ) -> String {
        var narrative = "The Standing Committee convened in the Great Hall. "

        switch meeting.atmosphere {
        case .harmonious:
            narrative += "The atmosphere was one of studied unity, the members moving through the agenda with practiced efficiency."
        case .tense:
            narrative += "Tension hung in the air as members took their seats. Glances were exchanged. Lines had been drawn."
        case .confrontational:
            narrative += "From the first moment it was clear this would be no ordinary session. Voices were raised. Accusations flew."
        case .performative:
            narrative += "The members went through the motions, rubber-stamping decisions already made in private conversations."
        }

        // Add decision summaries
        let approvedCount = results.filter { $0.outcome == .approved || $0.outcome == .amendedAndApproved }.count
        let rejectedCount = results.filter { $0.outcome == .rejected }.count

        if results.count > 0 {
            narrative += "\n\n\(approvedCount) measure\(approvedCount == 1 ? " was" : "s were") approved."
            if rejectedCount > 0 {
                narrative += " \(rejectedCount) \(rejectedCount == 1 ? "was" : "were") rejected—a rare display of dissent."
            }
        }

        // Note any dissenters
        let allDissenters = results.flatMap { $0.votesAgainst }
        if !allDissenters.isEmpty {
            let dissenterNames = Array(Set(allDissenters.map { $0.name })).prefix(3)
            narrative += "\n\n\(dissenterNames.joined(separator: ", ")) voted against one or more measures. Such opposition will be noted."
        }

        return narrative
    }

    private func generateDecisionNarrative(item: CommitteeAgendaItem, outcome: CommitteeDecision.DecisionOutcome) -> String {
        switch outcome {
        case .approved:
            return "The motion passed without significant opposition."
        case .rejected:
            return "The committee declined to approve the measure."
        case .deferred:
            return "No consensus was reached. The matter will be revisited."
        case .amendedAndApproved:
            return "After amendments, the measure was approved."
        case .referredToSubcommittee:
            return "The committee referred the matter for further study."
        }
    }

    // MARK: - Event Generation

    /// Generate a committee meeting event for the player
    func generateCommitteeMeetingEvent(result: CommitteeMeetingResult, game: Game) -> DynamicEvent {
        let title: String
        let priority: EventPriority

        switch result.meeting.atmosphere {
        case .confrontational:
            title = "Stormy Committee Session"
            priority = .elevated
        case .tense:
            title = "Committee Meets Amid Tension"
            priority = .normal
        case .harmonious:
            title = "Committee Session"
            priority = .background
        case .performative:
            title = "Routine Committee Meeting"
            priority = .background
        }

        return DynamicEvent(
            eventType: .worldNews,
            priority: priority,
            title: title,
            briefText: result.narrative,
            turnGenerated: game.turnNumber,
            isUrgent: result.meeting.atmosphere == .confrontational,
            responseOptions: [
                EventResponse(
                    id: "note",
                    text: "Note the proceedings",
                    shortText: "Note",
                    effects: [:]
                )
            ]
        )
    }
}

// MARK: - Result Types

struct CommitteeMeetingResult {
    let meeting: CommitteeMeeting
    let itemResults: [CommitteeDecisionResult]
    let narrative: String
}

struct CommitteeDecisionResult {
    let item: CommitteeAgendaItem
    let outcome: CommitteeDecision.DecisionOutcome
    let votesFor: [GameCharacter]
    let votesAgainst: [GameCharacter]
    let abstentions: [GameCharacter]
    let narrative: String
}

// MARK: - Election Result Types

struct SCEligibilityResult {
    let isEligible: Bool
    let reasons: [String]
}

struct SCElectionResult {
    let newMembers: [GameCharacter]
    let removedMembers: [GameCharacter]
    let narrative: String
}
