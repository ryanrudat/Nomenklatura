//
//  WealthSource.swift
//  Nomenklatura
//
//  Model for tracking sources of personal wealth and corruption
//

import Foundation

// MARK: - Wealth Source Type

enum WealthSourceType: String, Codable, CaseIterable, Sendable {
    case diversion       // Diverted state funds
    case bribery         // Accepted bribes
    case embezzlement    // Skimmed from projects
    case gifts           // "Gifts" from subordinates
    case familyBusiness  // Family enterprises (grey economy)
    case cleanSalary     // Legitimate Party salary (small)

    var displayName: String {
        switch self {
        case .diversion: return "Fund Diversion"
        case .bribery: return "Bribes Accepted"
        case .embezzlement: return "Embezzlement"
        case .gifts: return "Subordinate Gifts"
        case .familyBusiness: return "Family Business"
        case .cleanSalary: return "Official Salary"
        }
    }

    /// Risk level of this wealth source (1-5)
    var riskLevel: Int {
        switch self {
        case .diversion: return 5       // Very high - directly from state
        case .bribery: return 4         // High - witnesses exist
        case .embezzlement: return 4    // High - paper trail
        case .gifts: return 2           // Low - "customary"
        case .familyBusiness: return 3  // Medium - depends on scope
        case .cleanSalary: return 0     // None - legitimate
        }
    }

    /// How much visibility this type generates
    var visibilityImpact: Int {
        switch self {
        case .diversion: return 3
        case .bribery: return 5
        case .embezzlement: return 2
        case .gifts: return 4
        case .familyBusiness: return 6
        case .cleanSalary: return 0
        }
    }

    /// How much evidence this type creates
    var evidenceImpact: Int {
        switch self {
        case .diversion: return 8
        case .bribery: return 3
        case .embezzlement: return 10
        case .gifts: return 1
        case .familyBusiness: return 4
        case .cleanSalary: return 0
        }
    }
}

// MARK: - Wealth Record

struct WealthRecord: Codable, Identifiable, Sendable {
    var id: UUID
    var turnNumber: Int
    var sourceType: WealthSourceType
    var amount: Int
    var description: String

    init(turnNumber: Int, sourceType: WealthSourceType, amount: Int, description: String) {
        self.id = UUID()
        self.turnNumber = turnNumber
        self.sourceType = sourceType
        self.amount = amount
        self.description = description
    }
}

// MARK: - Corruption Level

enum CorruptionLevel: String, Codable, CaseIterable, Sendable {
    case clean          // 0-10 wealth
    case modest         // 11-30 wealth
    case comfortable    // 31-50 wealth
    case wealthy        // 51-70 wealth
    case oligarch       // 71+ wealth

    var displayName: String {
        switch self {
        case .clean: return "Clean"
        case .modest: return "Modest Means"
        case .comfortable: return "Comfortable"
        case .wealthy: return "Wealthy"
        case .oligarch: return "Party Oligarch"
        }
    }

    var description: String {
        switch self {
        case .clean:
            return "You live on your official salary like a good communist."
        case .modest:
            return "A few extra luxuries, nothing anyone would notice."
        case .comfortable:
            return "Your family lives better than most. Questions may arise."
        case .wealthy:
            return "Your wealth is becoming difficult to hide. The envious take note."
        case .oligarch:
            return "You have accumulated power through wealth. You are either untouchable or a target."
        }
    }

    static func level(for wealth: Int) -> CorruptionLevel {
        switch wealth {
        case 0...10: return .clean
        case 11...30: return .modest
        case 31...50: return .comfortable
        case 51...70: return .wealthy
        default: return .oligarch
        }
    }
}

// MARK: - Risk Level

enum CorruptionRiskLevel: String, Codable, CaseIterable, Sendable {
    case safe           // Evidence < 20 or visibility < 20
    case cautious       // Evidence or visibility 20-40
    case exposed        // Evidence or visibility 41-60
    case dangerous      // Evidence or visibility 61-80
    case imminent       // Evidence or visibility 81+

    var displayName: String {
        switch self {
        case .safe: return "Safe"
        case .cautious: return "Cautious"
        case .exposed: return "Exposed"
        case .dangerous: return "Dangerous"
        case .imminent: return "Investigation Imminent"
        }
    }

    var warningText: String? {
        switch self {
        case .safe: return nil
        case .cautious: return "Your activities may be attracting notice."
        case .exposed: return "The Bureau of People's Security has opened a file on you."
        case .dangerous: return "Evidence against you is accumulating. Consider laundering."
        case .imminent: return "An investigation is likely. Your position may not protect you."
        }
    }

    static func level(for visibility: Int, evidence: Int) -> CorruptionRiskLevel {
        let maxRisk = max(visibility, evidence)
        switch maxRisk {
        case 0..<20: return .safe
        case 20..<40: return .cautious
        case 40..<60: return .exposed
        case 60..<80: return .dangerous
        default: return .imminent
        }
    }
}
