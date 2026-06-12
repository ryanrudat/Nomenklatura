//
//  PlayerFamily.swift
//  Nomenklatura
//
//  Player family system integrated with gameplay mechanics.
//  In a Communist state, family is both asset and liability:
//  - Political marriages for career advancement
//  - BPS pressure on family to inform
//  - Children's futures tied to your status
//  - Collective responsibility for ideological crimes
//

import Foundation
import SwiftData

// MARK: - Marriage Type

/// How the marriage came about - affects dynamics and counsel quality
nonisolated enum MarriageType: String, Codable, CaseIterable, Sendable {
    case political    // Married for connections, functional relationship
    case love         // Genuine love match, but makes you vulnerable
    case arranged     // Party arranged it, spouse may resent
    case none         // Not married (dedicated to revolution)

    var displayName: String {
        switch self {
        case .political: return "Political Union"
        case .love: return "Love Match"
        case .arranged: return "Party Arrangement"
        case .none: return "Unmarried"
        }
    }

    var description: String {
        switch self {
        case .political:
            return "Your marriage was a strategic alliance, uniting political families."
        case .love:
            return "You married for love, a risky choice in a system that values loyalty to Party over personal bonds."
        case .arranged:
            return "The Party matched you for ideological compatibility. Whether genuine affection developed is another matter."
        case .none:
            return "You remain unmarried, devoted entirely to the revolutionary cause."
        }
    }

    /// Bonus to spouse counsel accuracy based on marriage type
    var counselBonus: Int {
        switch self {
        case .political: return 5   // Calculated advice on politics
        case .love: return 10       // Genuine insight into people
        case .arranged: return 0    // Variable - depends on relationship
        case .none: return 0
        }
    }
}

// MARK: - Family Temperament

/// How family members approach the political reality
nonisolated enum FamilyTemperament: String, Codable, CaseIterable, Sendable {
    case devoted      // "The Party is always right, as are you"
    case questioning  // "Are you sure this is wise?"
    case ambitious    // "When will you be promoted?"
    case fearful      // "They're watching us..."
    case idealistic   // "The revolution demands sacrifice"
    case cynical      // "It's all just power games"
    case resentful    // "You care more about work than us"

    var displayName: String {
        switch self {
        case .devoted: return "Devoted"
        case .questioning: return "Questioning"
        case .ambitious: return "Ambitious"
        case .fearful: return "Fearful"
        case .idealistic: return "Idealistic"
        case .cynical: return "Cynical"
        case .resentful: return "Resentful"
        }
    }

    var counselStyle: String {
        switch self {
        case .devoted:
            return "Always supportive, sometimes blindly so"
        case .questioning:
            return "Challenges assumptions, sometimes wisely"
        case .ambitious:
            return "Focused on advancement, may push too hard"
        case .fearful:
            return "Cautious warnings, sometimes excessive"
        case .idealistic:
            return "Principled advice, may ignore pragmatics"
        case .cynical:
            return "Sees ulterior motives everywhere"
        case .resentful:
            return "Colored by personal grievances"
        }
    }

    /// How this temperament affects informant risk
    var informantRisk: Int {
        switch self {
        case .devoted: return 5     // Would never betray
        case .questioning: return 15 // Might be persuaded
        case .ambitious: return 30   // Could trade information for favor
        case .fearful: return 40     // BPS pressure works
        case .idealistic: return 25  // Might inform "for the revolution"
        case .cynical: return 35     // Self-preservation instinct
        case .resentful: return 50   // Grudges can turn informant
        }
    }
}

// MARK: - Family Relation Type

nonisolated enum FamilyRelationType: String, Codable, CaseIterable, Sendable {
    case spouse
    case son
    case daughter

    var displayName: String {
        switch self {
        case .spouse: return "Spouse"
        case .son: return "Son"
        case .daughter: return "Daughter"
        }
    }

    /// Whether this family member can potentially become heir
    var canBeHeir: Bool {
        switch self {
        case .spouse: return false
        case .son, .daughter: return true
        }
    }
}

// MARK: - Player Family Member

/// A member of the player's family
nonisolated struct PlayerFamilyMember: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var name: String
    var relation: FamilyRelationType
    var age: Int

    // Loyalty split (Communist reality: Party vs Family conflict)
    var loyaltyToPlayer: Int          // 0-100, how devoted to you
    var loyaltyToParty: Int           // 0-100, can conflict with player loyalty

    var politicalAwareness: Int       // 0-100, how much they understand the game
    var temperament: FamilyTemperament

    // Status flags
    var isTargeted: Bool = false      // Being targeted by rivals
    var isInformant: Bool = false     // Secretly reporting to BPS
    var isUnderPressure: Bool = false // BPS pressuring them

    // Can this family member become player's heir?
    var canBecomeHeir: Bool {
        relation.canBeHeir && age >= 18 && !isInformant
    }

    // Risk level (0-100) - how vulnerable this person makes the family
    var riskLevel: Int {
        var risk = 0
        if isTargeted { risk += 30 }
        if isInformant { risk += 50 }
        if isUnderPressure { risk += 20 }
        if loyaltyToParty > loyaltyToPlayer { risk += 15 }
        if temperament.informantRisk > 30 { risk += 10 }
        return min(100, risk)
    }

    /// Description of family member's current state
    var statusDescription: String {
        if isInformant && isUnderPressure {
            return "Under BPS pressure, privately reporting"
        } else if isInformant {
            return "Secretly reporting to security services"
        } else if isUnderPressure {
            return "Being pressured by security services"
        } else if isTargeted {
            return "Under observation by your rivals"
        } else {
            return "Status appears normal"
        }
    }
}

// MARK: - Player Family Model

@Model
final class PlayerFamily {
    @Attribute(.unique) var id: UUID
    var hasFamily: Bool                    // Some cadres remain unmarried
    var marriageType: String               // MarriageType.rawValue

    // Family harmony affects counsel quality and vulnerability
    var familyHarmony: Int                 // 0-100
    var vulnerabilityScore: Int            // 0-100, how targetable

    // Revolutionary credentials of the family line
    var familyRevolutionaryCredentials: Int // 0-100, family's Party history

    // Spouse data (encoded)
    var spouseData: Data?

    // Children data (encoded)
    var childrenData: Data?

    // BPS pressure on spouse
    var spouseUnderPressure: Bool = false

    // Turn tracking
    var lastDomesticSceneTurn: Int = 0     // Last turn a domestic scene occurred
    var lastCounselTurn: Int = 0           // Last turn spouse gave counsel

    // Relationship to game
    var game: Game?

    init(hasFamily: Bool = false, marriageType: MarriageType = .none) {
        self.id = UUID()
        self.hasFamily = hasFamily
        self.marriageType = marriageType.rawValue
        self.familyHarmony = hasFamily ? 60 : 0
        self.vulnerabilityScore = 0
        self.familyRevolutionaryCredentials = 50
    }

    // MARK: - Computed Properties

    var marriage: MarriageType {
        MarriageType(rawValue: marriageType) ?? .none
    }

    var spouse: PlayerFamilyMember? {
        get {
            guard let data = spouseData else { return nil }
            return try? JSONDecoder().decode(PlayerFamilyMember.self, from: data)
        }
        set {
            spouseData = try? JSONEncoder().encode(newValue)
        }
    }

    var children: [PlayerFamilyMember] {
        get {
            guard let data = childrenData else { return [] }
            return (try? JSONDecoder().decode([PlayerFamilyMember].self, from: data)) ?? []
        }
        set {
            childrenData = try? JSONEncoder().encode(newValue)
        }
    }

    var allFamilyMembers: [PlayerFamilyMember] {
        var members: [PlayerFamilyMember] = []
        if let spouse = spouse {
            members.append(spouse)
        }
        members.append(contentsOf: children)
        return members
    }

    /// Children who can potentially become heirs
    var eligibleHeirs: [PlayerFamilyMember] {
        children.filter { $0.canBecomeHeir }
    }

    /// Is any family member an informant?
    var hasInformant: Bool {
        allFamilyMembers.contains { $0.isInformant }
    }

    /// Is any family member under pressure?
    var familyUnderPressure: Bool {
        spouseUnderPressure || allFamilyMembers.contains { $0.isUnderPressure }
    }

    /// Overall family risk level
    var overallRiskLevel: Int {
        guard hasFamily else { return 0 }

        var risk = vulnerabilityScore

        // Add individual risks
        for member in allFamilyMembers {
            risk += member.riskLevel / 4
        }

        // Marriage type modifiers
        if marriage == .love {
            risk += 10  // Love marriages are exploitable
        }

        // Low harmony increases risk
        if familyHarmony < 30 {
            risk += 15
        }

        // Low revolutionary credentials increase risk
        if familyRevolutionaryCredentials < 30 {
            risk += 10
        }

        return min(100, risk)
    }

    // MARK: - Methods

    /// Set up a new spouse
    func setSpouse(name: String, marriageType: MarriageType, temperament: FamilyTemperament, age: Int = 35) {
        self.hasFamily = true
        self.marriageType = marriageType.rawValue

        var newSpouse = PlayerFamilyMember(
            name: name,
            relation: .spouse,
            age: age,
            loyaltyToPlayer: marriageType == .love ? 80 : 60,
            loyaltyToParty: 50,
            politicalAwareness: 50,
            temperament: temperament
        )

        // Arranged marriages may start with resentment
        if marriageType == .arranged {
            newSpouse.temperament = Bool.random() ? temperament : .resentful
            newSpouse.loyaltyToPlayer = 40
        }

        // Political marriages have more political awareness
        if marriageType == .political {
            newSpouse.politicalAwareness = 70
        }

        self.spouse = newSpouse
        recalculateVulnerability()
    }

    /// Add a child
    func addChild(name: String, isSon: Bool, age: Int) {
        let relation: FamilyRelationType = isSon ? .son : .daughter

        let temperament: FamilyTemperament = {
            // Children influenced by parents and environment
            if let spouse = spouse, spouse.temperament == .idealistic {
                return Bool.random() ? .idealistic : .questioning
            }
            return FamilyTemperament.allCases.randomElement() ?? .devoted
        }()

        let child = PlayerFamilyMember(
            name: name,
            relation: relation,
            age: age,
            loyaltyToPlayer: 70,
            loyaltyToParty: age >= 14 ? 40 : 20,  // Young pioneers
            politicalAwareness: min(80, age * 3),
            temperament: temperament
        )

        var currentChildren = children
        currentChildren.append(child)
        children = currentChildren

        recalculateVulnerability()
    }

    /// Mark a family member as targeted by rivals
    func markAsTargeted(memberId: UUID) {
        if var spouse = spouse, spouse.id == memberId {
            spouse.isTargeted = true
            self.spouse = spouse
        }

        var updatedChildren = children
        if let index = updatedChildren.firstIndex(where: { $0.id == memberId }) {
            updatedChildren[index].isTargeted = true
            children = updatedChildren
        }

        recalculateVulnerability()
    }

    /// Apply BPS pressure to family member (seeded — runs in the turn pipeline)
    func applyPressure(memberId: UUID, using rng: inout SeededRNG) {
        if var spouse = spouse, spouse.id == memberId {
            spouse.isUnderPressure = true
            spouseUnderPressure = true
            // Check if they break and become informant
            if checkInformantBreak(member: spouse, using: &rng) {
                spouse.isInformant = true
            }
            self.spouse = spouse
        }

        var updatedChildren = children
        if let index = updatedChildren.firstIndex(where: { $0.id == memberId }) {
            updatedChildren[index].isUnderPressure = true
            if checkInformantBreak(member: updatedChildren[index], using: &rng) {
                updatedChildren[index].isInformant = true
            }
            children = updatedChildren
        }

        familyHarmony = max(0, familyHarmony - 10)
        recalculateVulnerability()
    }

    /// Check if a family member breaks under pressure and becomes informant
    private func checkInformantBreak(member: PlayerFamilyMember, using rng: inout SeededRNG) -> Bool {
        let breakChance = member.temperament.informantRisk +
                         (100 - member.loyaltyToPlayer) / 4 +
                         (member.loyaltyToParty - 50) / 4

        return Int.random(in: 1...100, using: &rng) <= breakChance
    }

    /// Recalculate family vulnerability score
    func recalculateVulnerability() {
        guard hasFamily else {
            vulnerabilityScore = 0
            return
        }

        var score = 20  // Base vulnerability for having family

        // Count vulnerable members
        for member in allFamilyMembers {
            if member.isTargeted { score += 15 }
            if member.isUnderPressure { score += 20 }
            if member.isInformant { score += 30 }
        }

        // Marriage type modifier
        if marriage == .love { score += 10 }
        if marriage == .arranged { score += 5 }

        // Harmony modifier
        if familyHarmony < 30 { score += 15 }

        vulnerabilityScore = min(100, score)
    }

    /// Process turn effects on family
    func processTurn(game: Game) {
        guard hasFamily else { return }

        // Slight harmony decay under stress
        if game.stability < 40 || game.rivalThreat > 60 {
            familyHarmony = max(0, familyHarmony - 2)
        }

        // Children age
        var updatedChildren = children
        for i in updatedChildren.indices {
            updatedChildren[i].age += 1
            // Young adults develop more party loyalty (youth organizations)
            if updatedChildren[i].age >= 14 && updatedChildren[i].age <= 25 {
                updatedChildren[i].loyaltyToParty = min(100, updatedChildren[i].loyaltyToParty + 2)
            }
        }
        children = updatedChildren

        recalculateVulnerability()
    }

    /// Improve family harmony (through personal time, gifts, attention)
    func improveHarmony(amount: Int) {
        familyHarmony = min(100, familyHarmony + amount)
        recalculateVulnerability()
    }

    /// Damage family harmony (through neglect, danger, stress)
    func damageHarmony(amount: Int) {
        familyHarmony = max(0, familyHarmony - amount)
        recalculateVulnerability()
    }

    /// Presence relieves pressure: members under BPS attention confide in the
    /// player and the pressure campaign loses its grip.
    func relievePressure() {
        if var spouse = spouse {
            spouse.isUnderPressure = false
            self.spouse = spouse
        }
        spouseUnderPressure = false
        var updatedChildren = children
        for i in updatedChildren.indices {
            updatedChildren[i].isUnderPressure = false
        }
        children = updatedChildren
        recalculateVulnerability()
    }

    /// Confront and turn back any informants in the household.
    /// Returns the names of those who had broken.
    func clearInformants() -> [String] {
        var cleared: [String] = []
        if var spouse = spouse, spouse.isInformant {
            cleared.append(spouse.name)
            spouse.isInformant = false
            spouse.isUnderPressure = false
            self.spouse = spouse
            spouseUnderPressure = false
        }
        var updatedChildren = children
        for i in updatedChildren.indices where updatedChildren[i].isInformant {
            cleared.append(updatedChildren[i].name)
            updatedChildren[i].isInformant = false
            updatedChildren[i].isUnderPressure = false
        }
        children = updatedChildren
        recalculateVulnerability()
        return cleared
    }
}

// MARK: - Family Generation

extension PlayerFamily {
    /// Generate a random family for a new game
    static func generateRandomFamily(probability: Int = 70) -> PlayerFamily {
        let family = PlayerFamily()

        // 70% chance of having family (some cadres unmarried)
        guard Int.random(in: 1...100) <= probability else {
            return family
        }

        // Generate spouse
        let marriageType = MarriageType.allCases.filter { $0 != .none }.randomElement() ?? .political
        let spouseTemperament = FamilyTemperament.allCases.randomElement() ?? .devoted
        let spouseAge = Int.random(in: 30...50)

        // PSR-flavored names matching the cast's naming conventions
        let spouseNames = marriageType == .political ?
            ["Margaret", "Vera", "Konstantin", "Irene", "Helena", "Gregor", "Camilla", "Viktor"] :
            ["Anna", "Elena", "Marta", "Pavel", "Sonia", "Tomas", "Lena", "Karel"]

        family.setSpouse(
            name: spouseNames.randomElement() ?? "Chen Wei",
            marriageType: marriageType,
            temperament: spouseTemperament,
            age: spouseAge
        )

        // 80% chance of having children
        if Int.random(in: 1...100) <= 80 {
            let numChildren = Int.random(in: 1...3)
            let childNames = ["Pavel", "Anya", "Viktor", "Mira", "Stefan", "Lena", "Tomas", "Vera", "Karel", "Dana"]

            for i in 0..<numChildren {
                let age = Int.random(in: 8...25)
                let isSon = Bool.random()
                family.addChild(
                    name: childNames[i % childNames.count],
                    isSon: isSon,
                    age: age
                )
            }
        }

        // Set family revolutionary credentials
        if marriageType == .political {
            family.familyRevolutionaryCredentials = Int.random(in: 60...90)
        } else {
            family.familyRevolutionaryCredentials = Int.random(in: 30...70)
        }

        return family
    }
}
