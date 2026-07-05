//
//  PoliticalOrder.swift
//  Nomenklatura
//
//  The political axis of the reform system: what kind of state the PSR is.
//  Counterpart to EconomicSystemType (the economic axis, which already
//  exists and is consumed by EconomyService). The player starts in the
//  one-party state; reforms passed through the Standing Committee law
//  pipeline — or transitions forced by coups and collapse — move the state
//  along this axis. Democracy is the hardest destination: it requires
//  surrendering the very machinery that kept the Chairman alive.
//
//  Grounded in regime-type scholarship: each order names who confers
//  legitimacy and who can veto the leader, which later consumers (vote
//  engines, win/loss checks, AI prompts) read instead of switching on cases.
//

import Foundation

enum PoliticalOrderType: String, Codable, CaseIterable {
    case partyState             // one-party rule, committee politics (start)
    case hybridAssembly         // partial legislature, managed pluralism
    case electoralDemocracy     // real elections, the leader can lose
    case militaryJunta          // the army as veto player turned ruler
    case personalistKleptocracy // rule by patronage; the state as property

    var displayName: String {
        switch self {
        case .partyState: return "One-Party State"
        case .hybridAssembly: return "Hybrid Assembly"
        case .electoralDemocracy: return "Electoral Democracy"
        case .militaryJunta: return "Military Junta"
        case .personalistKleptocracy: return "Personalist Regime"
        }
    }

    /// Player-facing one-liner for reform UI and the Codex.
    var blurb: String {
        switch self {
        case .partyState:
            return "The Party is the state. Power flows through the Standing Committee, and legitimacy through doctrine."
        case .hybridAssembly:
            return "A genuine legislature debates within limits the Party still sets. Managed pluralism — reversible, in either direction."
        case .electoralDemocracy:
            return "The ballot confers power, and can withdraw it. The Chairman who built this can also be retired by it."
        case .militaryJunta:
            return "The garrison no longer guards the state; it is the state. Order without politics."
        case .personalistKleptocracy:
            return "Institutions are façades; loyalty is bought. The treasury and the ruling family are hard to tell apart."
        }
    }

    /// Who confers the right to rule — read by AI prompts and reform UI.
    var legitimacySource: String {
        switch self {
        case .partyState: return "party doctrine and committee consensus"
        case .hybridAssembly: return "managed elections and Party guidance"
        case .electoralDemocracy: return "competitive elections"
        case .militaryJunta: return "force and the promise of order"
        case .personalistKleptocracy: return "patronage and personal loyalty"
        }
    }

    /// How strongly organized elites can check the leader (0-100).
    /// Consumed by vote engines and transition requirements in later steps.
    var eliteVetoPower: Int {
        switch self {
        case .partyState: return 60
        case .hybridAssembly: return 70
        case .electoralDemocracy: return 85
        case .militaryJunta: return 40
        case .personalistKleptocracy: return 20
        }
    }

    /// Compact descriptor injected into the AI scenario prompt so all
    /// generated text tracks the current regime automatically.
    var promptDescriptor: String {
        switch self {
        case .partyState:
            return "an authoritarian one-party state; legitimacy rests on \(legitimacySource)"
        case .hybridAssembly:
            return "a hybrid regime with a partially empowered legislature; legitimacy rests on \(legitimacySource); reform and reversal are both live possibilities"
        case .electoralDemocracy:
            return "a young electoral democracy; legitimacy rests on \(legitimacySource); the player can genuinely lose power at the ballot box"
        case .militaryJunta:
            return "a military junta; legitimacy rests on \(legitimacySource); civilian institutions are subordinate to the armed forces"
        case .personalistKleptocracy:
            return "a personalist kleptocracy; legitimacy rests on \(legitimacySource); institutions are hollow and loyalty is transactional"
        }
    }
}

extension Game {
    /// The state's current political order. Backed by the variables
    /// dictionary (no schema change), same pattern as the chairmanship tier.
    /// Defaults to the one-party state the campaign opens in.
    var politicalOrder: PoliticalOrderType {
        get {
            guard let raw = variables["political_order"],
                  let order = PoliticalOrderType(rawValue: raw) else { return .partyState }
            return order
        }
        set {
            variables["political_order"] = newValue.rawValue
        }
    }
}
