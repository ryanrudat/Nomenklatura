//
//  HistoricalSessionGenerator.swift
//  Nomenklatura
//
//  Generates 43 years of pre-game historical sessions
//  Party Congresses, People's Congresses, and Standing Committee meetings
//

import Foundation
import SwiftData

final class HistoricalSessionGenerator {
    static let shared = HistoricalSessionGenerator()

    private init() {}

    /// Generate all historical sessions for a new game
    func generateAllHistoricalSessions(for game: Game, context: ModelContext) {
        // Generate Party Congresses (every 5 years: Year 1, 6, 11, 16, 21, 26, 31, 36, 41)
        generatePartyCongressHistory(for: game, context: context)

        // Generate People's Congresses (annual from Year 3)
        generatePeoplesCongressHistory(for: game, context: context)

        // Generate Standing Committee meetings (2-3 per year from Year 5)
        generateCommitteeMeetingsHistory(for: game, context: context)

        // Generate key Central Committee plenums
        generateCentralCommitteePlenums(for: game, context: context)
    }

    // MARK: - Party Congress Generation

    private func generatePartyCongressHistory(for game: Game, context: ModelContext) {
        let partyCongressYears = [1, 6, 11, 16, 21, 26, 31, 36, 41]

        for (index, year) in partyCongressYears.enumerated() {
            let congress = generatePartyCongress(number: index + 1, year: year)
            context.insert(congress)
            congress.game = game
            game.historicalSessions.append(congress)
        }
    }

    private func generatePartyCongress(number: Int, year: Int) -> HistoricalSession {
        let era = RevolutionaryCalendar.era(for: year)
        let session = HistoricalSession(
            sessionType: .partyCongress,
            sessionNumber: number,
            revolutionaryYear: year,
            title: "\(RevolutionaryCalendar.ordinal(number)) Party Congress",
            summary: generatePartyCongressSummary(number: number, year: year, era: era)
        )

        session.keyDecisions = generatePartyCongressDecisions(number: number, era: era)
        session.memberChanges = generateMemberChanges(era: era, sessionType: .partyCongress)
        session.atmosphere = determineAtmosphere(era: era, sessionType: .partyCongress)
        session.accessLevel = determineAccessLevel(era: era, sessionType: .partyCongress)

        // Add secret content for restricted sessions
        if session.accessLevel > 0 {
            session.secretSummary = generateSecretSummary(era: era, sessionType: .partyCongress)
            session.secretDecisions = generateSecretDecisions(era: era)
        }

        return session
    }

    private func generatePartyCongressSummary(number: Int, year: Int, era: RevolutionaryCalendar.HistoricalEra) -> String {
        switch era {
        case .revolutionaryFounding:
            return "The \(RevolutionaryCalendar.ordinal(number)) Party Congress convened amid the fires of revolution. The delegates, many still bearing the scars of struggle, committed themselves to building the new socialist state upon the ruins of the old order."

        case .firstFiveYearPlan:
            return "The Congress ratified the First Five-Year Plan, charting a course toward rapid industrialization. Delegates reported impressive gains in steel and coal production. The countryside's transformation into collective farms proceeded \"according to plan.\""

        case .secondFiveYearPlan:
            return "Amid elaborate ceremonies celebrating socialist achievements, the Congress endorsed the continuation of centralized planning. The Leader's portrait hung in every hall. Dissent, if any existed, remained invisible."

        case .greatPurge:
            return "The Congress met under a cloud of terror. Many seats stood empty—their former occupants having been declared \"enemies of the people.\" Those who remained competed to denounce wreckers and saboteurs in ever more extravagant terms."

        case .preWarTension:
            return "The Congress focused on military preparedness and ideological vigilance. Border incidents with hostile neighbors were reported. The delegates approved increased defense spending and renewed their pledge of loyalty to the Leader."

        case .greatPatrioticWar:
            return "Convened in the midst of total war, the Congress celebrated the heroic resistance of the people against fascist aggression. Tales of partisan heroism alternated with demands for greater sacrifice on the home front."

        case .postWarReconstruction:
            return "The Congress surveyed the war's devastation and pledged to rebuild. New industrial targets were set. Ideological campaigns against \"cosmopolitanism\" and \"Western influence\" were announced."

        case .thawPeriod:
            return "In the uncertain atmosphere following the Leader's death, the Congress heard veiled criticisms of \"past excesses.\" A new collective leadership promised \"socialist legality\" and hinted at rehabilitations to come."
        }
    }

    private func generatePartyCongressDecisions(number: Int, era: RevolutionaryCalendar.HistoricalEra) -> [String] {
        switch era {
        case .revolutionaryFounding:
            return [
                "Nationalization of all major industries approved",
                "Land redistribution to the peasantry endorsed",
                "Creation of state security apparatus authorized",
                "Suppression of counter-revolutionary elements mandated"
            ]
        case .firstFiveYearPlan:
            return [
                "First Five-Year Plan targets adopted",
                "Collectivization of agriculture accelerated",
                "Industrial quotas increased by 25%",
                "Worker discipline measures strengthened"
            ]
        case .secondFiveYearPlan:
            return [
                "Second Five-Year Plan ratified",
                "Socialist competition campaigns expanded",
                "Cultural revolution in education endorsed",
                "Cult of the Leader formalized in party doctrine"
            ]
        case .greatPurge:
            return [
                "Intensification of struggle against enemies approved",
                "Extraordinary powers granted to security organs",
                "Mass expulsion of \"unreliable elements\" from Party",
                "Show trials of \"anti-Party conspirators\" endorsed"
            ]
        case .preWarTension:
            return [
                "Military budget increased by 40%",
                "Border fortifications authorized",
                "Ideological vigilance campaigns launched",
                "Youth mobilization programs expanded"
            ]
        case .greatPatrioticWar:
            return [
                "Total mobilization for victory declared",
                "Hero cities and partisan regions honored",
                "Post-war reconstruction planning initiated",
                "Allied cooperation acknowledged (cautiously)"
            ]
        case .postWarReconstruction:
            return [
                "Fourth Five-Year Plan adopted for reconstruction",
                "Anti-cosmopolitan campaign launched",
                "Scientific-technical development prioritized",
                "Return to ideological orthodoxy mandated"
            ]
        case .thawPeriod:
            return [
                "Limited criticism of \"personality cult\" permitted",
                "Rehabilitation commission established",
                "Consumer goods production increased",
                "Cultural relaxation cautiously endorsed"
            ]
        }
    }

    // MARK: - People's Congress Generation

    private func generatePeoplesCongressHistory(for game: Game, context: ModelContext) {
        // People's Congresses annually from Year 3 to Year 42
        for year in 3...42 {
            let session = generatePeoplesCongress(number: year - 2, year: year)
            context.insert(session)
            session.game = game
            game.historicalSessions.append(session)
        }
    }

    private func generatePeoplesCongress(number: Int, year: Int) -> HistoricalSession {
        let era = RevolutionaryCalendar.era(for: year)
        let session = HistoricalSession(
            sessionType: .peoplesCongress,
            sessionNumber: number,
            revolutionaryYear: year,
            title: "\(RevolutionaryCalendar.ordinal(number)) People's Congress",
            summary: generatePeoplesCongressSummary(year: year, era: era)
        )

        session.keyDecisions = generatePeoplesCongressDecisions(era: era)
        session.atmosphere = "performative"  // Always rubber-stamp
        session.accessLevel = 0  // Public record

        return session
    }

    private func generatePeoplesCongressSummary(year: Int, era: RevolutionaryCalendar.HistoricalEra) -> String {
        let summaries: [String] = [
            "The delegates unanimously approved all measures placed before them. Thunderous applause greeted each announcement. The session concluded ahead of schedule.",
            "Representatives from all regions gathered to endorse the Party's wise leadership. Not a single dissenting vote was recorded.",
            "The People's Congress convened in the Great Hall. After brief but enthusiastic deliberations, all government reports were approved.",
            "Delegates reported on socialist achievements in their constituencies. The proposed legislation passed with perfect unanimity."
        ]
        return summaries.randomElement()!
    }

    private func generatePeoplesCongressDecisions(era: RevolutionaryCalendar.HistoricalEra) -> [String] {
        return [
            "Government work report unanimously approved",
            "National budget endorsed without amendment",
            "Supreme Court report accepted",
            "All proposed legislation passed unanimously"
        ]
    }

    // MARK: - Standing Committee Meetings

    private func generateCommitteeMeetingsHistory(for game: Game, context: ModelContext) {
        // 2-3 meetings per year from Year 5 to Year 42
        var meetingNumber = 1
        for year in 5...42 {
            let meetingsThisYear = Int.random(in: 2...3)
            for _ in 1...meetingsThisYear {
                let session = generateCommitteeMeeting(number: meetingNumber, year: year)
                context.insert(session)
                session.game = game
                game.historicalSessions.append(session)
                meetingNumber += 1
            }
        }
    }

    private func generateCommitteeMeeting(number: Int, year: Int) -> HistoricalSession {
        let era = RevolutionaryCalendar.era(for: year)
        let session = HistoricalSession(
            sessionType: .standingCommittee,
            sessionNumber: number,
            revolutionaryYear: year,
            title: "Standing Committee Meeting \(number)",
            summary: generateCommitteeMeetingSummary(year: year, era: era)
        )

        session.keyDecisions = generateCommitteeMeetingDecisions(era: era)
        session.atmosphere = determineAtmosphere(era: era, sessionType: .standingCommittee)
        session.accessLevel = 5  // Restricted by default

        if era == .greatPurge || era == .preWarTension {
            session.accessLevel = 7  // Secret during terror periods
            session.secretSummary = generateSecretSummary(era: era, sessionType: .standingCommittee)
            session.secretDecisions = generateSecretDecisions(era: era)
        }

        return session
    }

    private func generateCommitteeMeetingSummary(year: Int, era: RevolutionaryCalendar.HistoricalEra) -> String {
        let summaries: [RevolutionaryCalendar.HistoricalEra: [String]] = [
            .revolutionaryFounding: [
                "The Committee reviewed progress in consolidating revolutionary power.",
                "Emergency measures to combat counter-revolutionary activity were discussed."
            ],
            .firstFiveYearPlan: [
                "Plan fulfillment reports dominated the agenda. Shortfalls were attributed to sabotage.",
                "Agricultural collectivization progress was reviewed. \"Voluntary\" compliance rates reported."
            ],
            .greatPurge: [
                "Security matters occupied the full session. Names were discussed.",
                "The Committee reviewed lists submitted by the organs. Decisions were reached."
            ],
            .greatPatrioticWar: [
                "War mobilization dominated all discussions. Heroic sacrifices were acknowledged.",
                "Resource allocation for the front was the primary concern."
            ],
            .thawPeriod: [
                "The Committee debated the pace of reform. Caution prevailed.",
                "Personnel matters and rehabilitation cases were reviewed."
            ]
        ]

        let eraSummaries = summaries[era] ?? ["The Committee met in closed session to discuss matters of state."]
        return eraSummaries.randomElement()!
    }

    private func generateCommitteeMeetingDecisions(era: RevolutionaryCalendar.HistoricalEra) -> [String] {
        switch era {
        case .greatPurge:
            return [
                "Certain personnel matters were resolved",
                "Security recommendations were approved",
                "Investigation priorities were set"
            ]
        case .thawPeriod:
            return [
                "Rehabilitation cases reviewed",
                "Cultural policy adjustments discussed",
                "Economic reform proposals considered"
            ]
        default:
            return [
                "Personnel appointments confirmed",
                "Policy implementation reviewed",
                "Resource allocation approved"
            ]
        }
    }

    // MARK: - Central Committee Plenums

    private func generateCentralCommitteePlenums(for game: Game, context: ModelContext) {
        // Key plenums during significant moments
        let significantPlenums: [(year: Int, title: String, summary: String)] = [
            (17, "Plenum on Counter-Revolutionary Conspiracy",
             "The Central Committee heard shocking evidence of a vast conspiracy reaching to the highest levels. Arrests followed."),
            (18, "Plenum on the Trotsky-Zinoviev Bloc",
             "Former leaders were condemned as foreign agents. The purge intensified."),
            (27, "Wartime Plenum",
             "Meeting in the shadow of invasion, the Committee pledged total victory or total destruction."),
            (38, "Plenum on the Cult of Personality",
             "For the first time, criticism of past leadership was heard. Many delegates wept."),
            (40, "Plenum on Economic Reform",
             "Cautious proposals for decentralization were debated. Orthodox elements resisted.")
        ]

        for (year, title, summary) in significantPlenums {
            let session = HistoricalSession(
                sessionType: .centralCommittee,
                sessionNumber: year,
                revolutionaryYear: year,
                title: title,
                summary: summary
            )
            session.accessLevel = 5
            session.atmosphere = "tense"

            context.insert(session)
            session.game = game
            game.historicalSessions.append(session)
        }
    }

    // MARK: - Helper Methods

    private func determineAtmosphere(era: RevolutionaryCalendar.HistoricalEra, sessionType: HistoricalSessionType) -> String {
        switch era {
        case .revolutionaryFounding:
            return "tense"
        case .greatPurge:
            return "confrontational"
        case .greatPatrioticWar:
            return sessionType == .partyCongress ? "harmonious" : "tense"
        case .thawPeriod:
            return "tense"
        default:
            return sessionType == .peoplesCongress ? "performative" : "harmonious"
        }
    }

    private func determineAccessLevel(era: RevolutionaryCalendar.HistoricalEra, sessionType: HistoricalSessionType) -> Int {
        if sessionType == .peoplesCongress { return 0 }

        switch era {
        case .greatPurge, .preWarTension:
            return 7  // Secret
        case .revolutionaryFounding, .thawPeriod:
            return 5  // Restricted
        default:
            return sessionType == .standingCommittee ? 5 : 0
        }
    }

    private func generateSecretSummary(era: RevolutionaryCalendar.HistoricalEra, sessionType: HistoricalSessionType) -> String {
        switch era {
        case .greatPurge:
            return "Behind closed doors, the committee reviewed execution lists. Several members present would themselves be arrested within months."
        case .preWarTension:
            return "Intelligence reports on foreign threats were discussed. Military weakness was acknowledged privately."
        case .thawPeriod:
            return "The true extent of past crimes was debated. Some argued for full disclosure; others warned of destabilization."
        default:
            return "Classified matters were discussed. Records remain sealed."
        }
    }

    private func generateSecretDecisions(era: RevolutionaryCalendar.HistoricalEra) -> [String] {
        switch era {
        case .greatPurge:
            return [
                "Execution quotas for regions approved",
                "Additional investigation targets identified",
                "Family member liability policies confirmed"
            ]
        case .preWarTension:
            return [
                "Military readiness assessments (pessimistic) noted",
                "Secret diplomatic approaches discussed",
                "Intelligence failures acknowledged"
            ]
        case .thawPeriod:
            return [
                "Full rehabilitation of certain figures debated",
                "Opening of archives considered then rejected",
                "Limits on de-Stalinization established"
            ]
        default:
            return ["[Contents remain classified]"]
        }
    }

    private func generateMemberChanges(era: RevolutionaryCalendar.HistoricalEra, sessionType: HistoricalSessionType) -> [String] {
        switch era {
        case .greatPurge:
            return [
                "Multiple seats vacated due to \"exposure of enemies\"",
                "New members elected from security organs",
                "Several delegates arrested during session"
            ]
        case .thawPeriod:
            return [
                "Several members rehabilitated posthumously",
                "New generation of leaders promoted",
                "Old Guard members retired \"for health reasons\""
            ]
        default:
            return [
                "Routine changes to committee composition",
                "Retirements and new elections as normal"
            ]
        }
    }
}
