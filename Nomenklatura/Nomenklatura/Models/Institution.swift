//
//  Institution.swift
//  Nomenklatura
//
//  Institutions of the Socialist State - the pillars of power
//

import Foundation
import SwiftUI

// MARK: - Institution Enum

enum Institution: String, Codable, CaseIterable, Identifiable {
    case presidium      // Standing Committee / Politburo - supreme power
    case congress       // People's Congress - rubber-stamp legislature
    case military       // Armed Forces - defense and internal security
    case security       // BPS - Bureau of People's Security
    case economy        // Gosplan - Economic Planning Commission
    case regions        // Regional Governance - provincial administration
    case propaganda     // Agitprop - Media & Ideology Department
    case foreign        // MFA - Ministry of Foreign Affairs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .presidium: return "The Presidium"
        case .congress: return "People's Congress"
        case .military: return "The Military"
        case .security: return "State Security"
        case .economy: return "Economic Planning"
        case .regions: return "Regional Governance"
        case .propaganda: return "Propaganda & Media"
        case .foreign: return "Foreign Affairs"
        }
    }

    var shortName: String {
        switch self {
        case .presidium: return "Presidium"
        case .congress: return "Congress"
        case .military: return "Military"
        case .security: return "BPS"
        case .economy: return "Gosplan"
        case .regions: return "Regions"
        case .propaganda: return "Agitprop"
        case .foreign: return "MFA"
        }
    }

    var description: String {
        switch self {
        case .presidium:
            return "The supreme decision-making body. Controls leadership selection, term limits, emergency powers, and succession rules."
        case .congress:
            return "The legislative assembly of the people. Determines session frequency, delegate selection, and legislative authority."
        case .military:
            return "The armed forces of the Socialist Republic. Governs political commissars, budget control, officer promotion, and nuclear authority."
        case .security:
            return "The Bureau of People's Security. Controls surveillance scope, arrest authority, and internal investigations."
        case .economy:
            return "The central planning apparatus. Sets enterprise management, private enterprise policy, foreign trade, and price controls."
        case .regions:
            return "Provincial and republican governance. Determines governor appointment, regional autonomy, and resource revenue distribution."
        case .propaganda:
            return "The ideological apparatus. Controls press freedom, cultural policy, and religious affairs."
        case .foreign:
            return "International relations and diplomacy. Sets alliance policy, border controls, and engagement with international organizations."
        }
    }

    var icon: String {
        switch self {
        case .presidium: return "building.columns.fill"
        case .congress: return "person.3.sequence.fill"
        case .military: return "shield.fill"
        case .security: return "eye.fill"
        case .economy: return "chart.bar.fill"
        case .regions: return "map.fill"
        case .propaganda: return "megaphone.fill"
        case .foreign: return "globe"
        }
    }

    var accentColor: Color {
        switch self {
        case .presidium: return Color(red: 0.8, green: 0.15, blue: 0.15)  // Deep red
        case .congress: return Color(red: 0.6, green: 0.2, blue: 0.2)     // Burgundy
        case .military: return Color(red: 0.25, green: 0.35, blue: 0.25)  // Military green
        case .security: return Color(red: 0.2, green: 0.2, blue: 0.3)     // Dark blue-gray
        case .economy: return Color(red: 0.5, green: 0.4, blue: 0.2)      // Industrial brown
        case .regions: return Color(red: 0.4, green: 0.3, blue: 0.2)      // Earth tone
        case .propaganda: return Color(red: 0.7, green: 0.2, blue: 0.2)   // Bright red
        case .foreign: return Color(red: 0.2, green: 0.3, blue: 0.5)      // Diplomatic blue
        }
    }

    /// Base difficulty for changing policies in this institution
    var baseDifficulty: Int {
        switch self {
        case .presidium: return 85   // Hardest - core power structure
        case .military: return 75    // Military resists civilian interference
        case .security: return 70    // Security apparatus protects itself
        case .congress: return 50    // Rubber stamp, easier to reform
        case .economy: return 55     // Economic policy is contested
        case .regions: return 60     // Regional interests resist central control
        case .propaganda: return 45  // Easier to adjust messaging
        case .foreign: return 50     // Foreign policy is flexible
        }
    }

    /// Number of policy slots in this institution
    var slotCount: Int {
        switch self {
        case .presidium: return 4
        case .congress: return 3
        case .military: return 4
        case .security: return 3
        case .economy: return 4
        case .regions: return 3
        case .propaganda: return 3
        case .foreign: return 3
        }
    }

    /// Which factions have primary interest in this institution
    var primaryFactions: [String] {
        switch self {
        case .presidium: return ["old_guard", "princelings"]
        case .congress: return ["youth_league", "regional"]
        case .military: return ["princelings", "old_guard"]
        case .security: return ["old_guard", "princelings"]
        case .economy: return ["reformists", "youth_league"]
        case .regions: return ["regional", "reformists"]
        case .propaganda: return ["old_guard", "youth_league"]
        case .foreign: return ["reformists", "youth_league"]
        }
    }
}

// MARK: - Institution Category (for grouping in UI)

enum InstitutionCategory: String, CaseIterable {
    case power       // Presidium, Congress
    case security    // Military, BPS
    case governance  // Economy, Regions
    case ideology    // Propaganda, Foreign

    var displayName: String {
        switch self {
        case .power: return "Power Structure"
        case .security: return "Security Apparatus"
        case .governance: return "State Governance"
        case .ideology: return "Ideology & Relations"
        }
    }

    var institutions: [Institution] {
        switch self {
        case .power: return [.presidium, .congress]
        case .security: return [.military, .security]
        case .governance: return [.economy, .regions]
        case .ideology: return [.propaganda, .foreign]
        }
    }
}
