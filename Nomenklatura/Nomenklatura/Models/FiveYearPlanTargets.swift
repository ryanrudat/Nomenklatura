//
//  FiveYearPlanTargets.swift
//  Nomenklatura
//
//  Real Five-Year Plan target system. The player sets sector growth goals at the
//  start of a 20-turn cycle, economic actions contribute progress toward those
//  goals, and the end-of-cycle evaluation produces meaningful consequences
//  (bonuses, penalties, Standing Committee interventions).
//
//  Stored as an encoded blob on `Game.planTargetsData` to match the existing
//  persistence pattern. The struct is Codable/Sendable rather than a SwiftData
//  `@Model` because it lives inside a single Game aggregate and does not need
//  its own fetch descriptors.
//

import Foundation

// MARK: - Plan Sector

/// The six sectors the player can set Five-Year Plan goals for.
///
/// These deliberately mirror the Five-Year Plan wheel (Heavy Industry,
/// Agriculture, Energy, Infrastructure, Defense, People's Welfare) rather than
/// the raw `EconomicSector` enum — the wheel is what the player sees, so it
/// is the contract the target-setting UI keeps.
enum PlanSector: String, Codable, CaseIterable, Identifiable, Sendable {
    case heavyIndustry
    case agriculture
    case defense
    case welfare
    case infrastructure
    case energy

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .heavyIndustry: return "Heavy Industry"
        case .agriculture: return "Agriculture"
        case .defense: return "Defense"
        case .welfare: return "People's Welfare"
        case .infrastructure: return "Infrastructure"
        case .energy: return "Energy"
        }
    }

    var iconName: String {
        switch self {
        case .heavyIndustry: return "gearshape.fill"
        case .agriculture: return "leaf.fill"
        case .defense: return "shield.fill"
        case .welfare: return "person.3.fill"
        case .infrastructure: return "road.lanes"
        case .energy: return "bolt.fill"
        }
    }

    /// Short descriptor shown below the sector name in the target-setting UI.
    var subtitle: String {
        switch self {
        case .heavyIndustry: return "Steel, machinery, production"
        case .agriculture: return "Collective farms, food supply"
        case .defense: return "Military-industrial complex"
        case .welfare: return "Housing, consumer goods, stability"
        case .infrastructure: return "Transport, construction"
        case .energy: return "Power, fuel, electrification"
        }
    }
}

// MARK: - Target Preset

/// Preset difficulty levels the player can pick when starting a new cycle.
enum PlanTargetPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case conservative
    case ambitious
    case revolutionary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .ambitious: return "Ambitious"
        case .revolutionary: return "Revolutionary"
        }
    }

    var subtitle: String {
        switch self {
        case .conservative: return "Modest growth, lower risk"
        case .ambitious: return "Standard Five-Year Plan vigor"
        case .revolutionary: return "Stakhanovite heroism — high risk, high reward"
        }
    }

    /// Default delta goal per sector (delta above current state).
    var defaultDelta: Int {
        switch self {
        case .conservative: return 8     // +5..+10
        case .ambitious: return 15       // +10..+20
        case .revolutionary: return 25   // +20..+30
        }
    }

    /// Small +/- jitter applied per sector so presets are not identical.
    var jitter: Int {
        switch self {
        case .conservative: return 3
        case .ambitious: return 5
        case .revolutionary: return 5
        }
    }
}

// MARK: - Five-Year Plan Targets

/// Player-set targets for a single 20-turn Five-Year Plan cycle.
///
/// `targets` stores the delta goal per sector (e.g. +15 heavy industry), and
/// `progress` stores the accumulated contribution from economic actions toward
/// that goal. A sector is considered "met" when `progress >= target`.
struct FiveYearPlanTargets: Codable, Sendable {
    /// Stable identifier — useful for debugging and save-migration logs.
    var id: UUID = UUID()

    /// Which cycle this is (1, 2, 3, ...). Increments when a new plan is started.
    var cycleNumber: Int = 1

    /// Turn on which this cycle begins.
    var startTurn: Int = 1

    /// Turn on which this cycle ends (startTurn + cycleLength).
    var endTurn: Int = 21

    /// Length of a plan cycle in turns. 20 turns per cycle.
    static let cycleLength: Int = 20

    /// Delta goals per sector, e.g. +15 means "raise this sector's progress
    /// score by 15 points during the cycle". Keyed by `PlanSector.rawValue`.
    var targets: [String: Int] = [:]

    /// Accumulated progress toward each sector target. Keyed by
    /// `PlanSector.rawValue`. Progress is added by `EconomicActionService` as
    /// actions resolve successfully.
    var progress: [String: Int] = [:]

    /// True once end-of-cycle evaluation has run and consequences applied.
    var isComplete: Bool = false

    /// True once the player has set the targets for this cycle (or accepted a
    /// default preset). When false, the Economy tab shows a target-setting
    /// modal prompt.
    var isConfigured: Bool = false

    // MARK: Legacy fields (retained so existing save data decodes cleanly)

    /// Legacy: delta goal toward GDP index. Kept for save-file compatibility.
    var gdpTarget: Int = 125
    var industrialTarget: Int = 65
    var agricultureTarget: Int = 55
    var treasuryTarget: Int = 60
    var startingGDP: Int = 100
    var startingIndustrial: Int = 50
    var startingAgriculture: Int = 45
    var startingTreasury: Int = 55

    // MARK: Init

    init() {
        self.id = UUID()
        self.cycleNumber = 1
        self.startTurn = 1
        self.endTurn = 1 + Self.cycleLength
        self.targets = [:]
        self.progress = [:]
        self.isComplete = false
        self.isConfigured = false
    }

    // MARK: Convenience

    /// Get the target delta for a sector (0 if none set).
    func target(for sector: PlanSector) -> Int {
        targets[sector.rawValue] ?? 0
    }

    /// Get the current progress toward a sector's target (0 if none).
    func progress(for sector: PlanSector) -> Int {
        progress[sector.rawValue] ?? 0
    }

    /// Percentage progress (0-100+) toward a sector target.
    func progressPercent(for sector: PlanSector) -> Int {
        let goal = target(for: sector)
        guard goal > 0 else { return 0 }
        let have = progress(for: sector)
        return max(0, min(200, (have * 100) / goal))
    }

    /// How many sectors have fully met their target (progress >= goal).
    var sectorsMetCount: Int {
        PlanSector.allCases.filter { sector in
            let goal = target(for: sector)
            return goal > 0 && progress(for: sector) >= goal
        }.count
    }

    /// How many sectors the player has set a real (non-zero) target on.
    var sectorsWithTargets: Int {
        PlanSector.allCases.filter { target(for: $0) > 0 }.count
    }

    /// Average progress percent across all sectors with targets set.
    var averageProgressPercent: Int {
        let withTargets = PlanSector.allCases.filter { target(for: $0) > 0 }
        guard !withTargets.isEmpty else { return 0 }
        let total = withTargets.reduce(0) { $0 + progressPercent(for: $1) }
        return total / withTargets.count
    }

    /// Expected progress percent at the current turn (linear pacing across cycle).
    func expectedProgressPercent(currentTurn: Int) -> Int {
        guard endTurn > startTurn else { return 0 }
        let elapsed = max(0, currentTurn - startTurn)
        let pct = (elapsed * 100) / (endTurn - startTurn)
        return max(0, min(100, pct))
    }

    /// Mutate: add progress toward a sector's target.
    mutating func addProgress(_ amount: Int, to sector: PlanSector) {
        guard amount != 0 else { return }
        progress[sector.rawValue] = (progress[sector.rawValue] ?? 0) + amount
    }

    // MARK: Preset application

    /// Fill targets from a difficulty preset. Produces slight variance per sector.
    mutating func apply(preset: PlanTargetPreset) {
        targets.removeAll()
        for sector in PlanSector.allCases {
            let jitter = Int.random(in: -preset.jitter...preset.jitter)
            let delta = max(1, preset.defaultDelta + jitter)
            targets[sector.rawValue] = delta
        }
        isConfigured = true
    }

    /// Fill targets from an explicit per-sector dictionary.
    mutating func applyCustom(targets deltas: [PlanSector: Int]) {
        targets = [:]
        for (sector, delta) in deltas {
            targets[sector.rawValue] = max(0, delta)
        }
        isConfigured = true
    }

    // MARK: Codable (tolerant of older saves)

    private enum CodingKeys: String, CodingKey {
        case id, cycleNumber, startTurn, endTurn
        case targets, progress
        case isComplete, isConfigured
        case gdpTarget, industrialTarget, agricultureTarget, treasuryTarget
        case startingGDP, startingIndustrial, startingAgriculture, startingTreasury
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        self.cycleNumber = (try? c.decode(Int.self, forKey: .cycleNumber)) ?? 1
        self.startTurn = (try? c.decode(Int.self, forKey: .startTurn)) ?? 1
        self.endTurn = (try? c.decode(Int.self, forKey: .endTurn)) ?? (1 + Self.cycleLength)
        self.targets = (try? c.decode([String: Int].self, forKey: .targets)) ?? [:]
        self.progress = (try? c.decode([String: Int].self, forKey: .progress)) ?? [:]
        self.isComplete = (try? c.decode(Bool.self, forKey: .isComplete)) ?? false
        self.isConfigured = (try? c.decode(Bool.self, forKey: .isConfigured)) ?? false
        self.gdpTarget = (try? c.decode(Int.self, forKey: .gdpTarget)) ?? 125
        self.industrialTarget = (try? c.decode(Int.self, forKey: .industrialTarget)) ?? 65
        self.agricultureTarget = (try? c.decode(Int.self, forKey: .agricultureTarget)) ?? 55
        self.treasuryTarget = (try? c.decode(Int.self, forKey: .treasuryTarget)) ?? 60
        self.startingGDP = (try? c.decode(Int.self, forKey: .startingGDP)) ?? 100
        self.startingIndustrial = (try? c.decode(Int.self, forKey: .startingIndustrial)) ?? 50
        self.startingAgriculture = (try? c.decode(Int.self, forKey: .startingAgriculture)) ?? 45
        self.startingTreasury = (try? c.decode(Int.self, forKey: .startingTreasury)) ?? 55
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(cycleNumber, forKey: .cycleNumber)
        try c.encode(startTurn, forKey: .startTurn)
        try c.encode(endTurn, forKey: .endTurn)
        try c.encode(targets, forKey: .targets)
        try c.encode(progress, forKey: .progress)
        try c.encode(isComplete, forKey: .isComplete)
        try c.encode(isConfigured, forKey: .isConfigured)
        try c.encode(gdpTarget, forKey: .gdpTarget)
        try c.encode(industrialTarget, forKey: .industrialTarget)
        try c.encode(agricultureTarget, forKey: .agricultureTarget)
        try c.encode(treasuryTarget, forKey: .treasuryTarget)
        try c.encode(startingGDP, forKey: .startingGDP)
        try c.encode(startingIndustrial, forKey: .startingIndustrial)
        try c.encode(startingAgriculture, forKey: .startingAgriculture)
        try c.encode(startingTreasury, forKey: .startingTreasury)
    }
}
