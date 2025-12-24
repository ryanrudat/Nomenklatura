//
//  InitialAgendaGenerator.swift
//  Nomenklatura
//
//  Generates initial Standing Committee agenda items at game start
//

import Foundation

final class InitialAgendaGenerator {
    static let shared = InitialAgendaGenerator()

    private init() {}

    /// Generate initial agenda items for the Standing Committee at game start
    func generateInitialAgenda(for committee: StandingCommittee, game: Game) {
        var agenda: [CommitteeAgendaItem] = []

        // Always include 1 personnel item (appointment to watch)
        agenda.append(generatePersonnelItem(game: game))

        // Add 1-2 policy/economic items
        agenda.append(generatePolicyItem(game: game))

        if Bool.random() {
            agenda.append(generateEconomicItem(game: game))
        }

        // Maybe add a foreign policy item based on international standing
        if game.internationalStanding < 50 || Bool.random() {
            agenda.append(generateForeignItem(game: game))
        }

        committee.pendingAgenda = agenda
    }

    // MARK: - Item Generators

    private func generatePersonnelItem(game: Game) -> CommitteeAgendaItem {
        let personnelItems: [(title: String, description: String, priority: CommitteeAgendaItem.AgendaPriority)] = [
            (
                "Provincial Committee Appointments",
                "Several provincial Party secretaryships require confirmation following recent transfers. The Organizational Department has prepared a slate of candidates.",
                .important
            ),
            (
                "Ministry Restructuring",
                "The Council of Ministers proposes consolidating two smaller ministries to improve administrative efficiency. Senior personnel will need reassignment.",
                .routine
            ),
            (
                "Youth League Leadership",
                "The Communist Youth League's Central Committee requests confirmation of its newly-elected leadership slate.",
                .routine
            ),
            (
                "Military District Command",
                "Rotation of military district commanders is due. The General Staff has submitted recommendations for review.",
                .important
            ),
            (
                "Academy Appointments",
                "The Party School and Institute of Social Sciences require new directors. Ideological considerations are paramount.",
                .routine
            )
        ]

        let selected = personnelItems.randomElement()!

        // Pick a sponsor from the committee
        let sponsorId = game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 6 }
            .randomElement()?.templateId

        return CommitteeAgendaItem(
            title: selected.title,
            description: selected.description,
            category: .personnel,
            priority: selected.priority,
            sponsorId: sponsorId,
            turnSubmitted: 1
        )
    }

    private func generatePolicyItem(game: Game) -> CommitteeAgendaItem {
        let policyItems: [(title: String, description: String, priority: CommitteeAgendaItem.AgendaPriority)] = [
            (
                "Media Guidelines Review",
                "The Propaganda Department seeks guidance on cultural policy following recent literary controversies. Some advocate liberalization; others demand stricter controls.",
                .important
            ),
            (
                "Internal Passport Reform",
                "Proposals to relax internal migration restrictions have been submitted. Urban committees warn of overcrowding; agricultural regions protest labor shortages.",
                .routine
            ),
            (
                "Educational Curriculum",
                "The Education Ministry proposes revisions to the standard curriculum emphasizing technical subjects over classical Marxist theory.",
                .routine
            ),
            (
                "Party Membership Criteria",
                "Standards for Party admission have been debated. Reformists seek expansion; traditionalists warn of diluting ideological purity.",
                .important
            ),
            (
                "Regional Autonomy",
                "Minority autonomous regions request expanded cultural rights. The Nationalities Commission has prepared recommendations.",
                .important
            )
        ]

        let selected = policyItems.randomElement()!

        let sponsorId = game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 5 }
            .randomElement()?.templateId

        return CommitteeAgendaItem(
            title: selected.title,
            description: selected.description,
            category: .policy,
            priority: selected.priority,
            sponsorId: sponsorId,
            turnSubmitted: 1
        )
    }

    private func generateEconomicItem(game: Game) -> CommitteeAgendaItem {
        let economicItems: [(title: String, description: String, priority: CommitteeAgendaItem.AgendaPriority)] = [
            (
                "Five-Year Plan Targets",
                "The State Planning Commission requests approval for revised industrial output targets. Current projections suggest shortfalls in heavy industry.",
                .urgent
            ),
            (
                "Agricultural Procurement Quotas",
                "Collective farm procurement quotas must be set for the coming harvest. Regional committees submit conflicting assessments of capacity.",
                .important
            ),
            (
                "Consumer Goods Allocation",
                "Citizens demand improved access to consumer goods. Light industry ministries propose reallocation of resources from defense production.",
                .routine
            ),
            (
                "Price Reform Measures",
                "The Finance Ministry proposes adjusting controlled prices for basic commodities. Economic reformists support gradual marketization.",
                .important
            ),
            (
                "Foreign Technology Import",
                "The Scientific-Technical Committee requests hard currency allocation for importing Western industrial equipment.",
                .routine
            )
        ]

        let selected = economicItems.randomElement()!

        let sponsorId = game.characters
            .filter { $0.isAlive && ($0.factionId == "reformists" || $0.factionId == "youth_league") }
            .randomElement()?.templateId

        return CommitteeAgendaItem(
            title: selected.title,
            description: selected.description,
            category: .economic,
            priority: selected.priority,
            sponsorId: sponsorId,
            turnSubmitted: 1
        )
    }

    private func generateForeignItem(game: Game) -> CommitteeAgendaItem {
        let foreignItems: [(title: String, description: String, priority: CommitteeAgendaItem.AgendaPriority)] = [
            (
                "Western Trade Relations",
                "The Foreign Ministry proposes expanded trade negotiations with capitalist nations. Ideological purists express concern about bourgeois influence.",
                .important
            ),
            (
                "Socialist Bloc Coordination",
                "Fraternal socialist states request a summit to coordinate economic planning and mutual assistance programs.",
                .routine
            ),
            (
                "Third World Solidarity",
                "Liberation movements in the Commonwealth colonies request increased material and advisory support. The International Department awaits guidance.",
                .routine
            ),
            (
                "Border Dispute Response",
                "Tensions with neighboring states require a coordinated diplomatic and military posture. The Defense Council seeks policy direction.",
                .urgent
            ),
            (
                "Cultural Exchange Programs",
                "The State Committee for Cultural Relations proposes expanded people-to-people exchanges. Security services express reservations.",
                .routine
            )
        ]

        let selected = foreignItems.randomElement()!

        let sponsorId = game.characters
            .filter { $0.isAlive && ($0.positionIndex ?? 0) >= 6 }
            .randomElement()?.templateId

        return CommitteeAgendaItem(
            title: selected.title,
            description: selected.description,
            category: .foreign,
            priority: selected.priority,
            sponsorId: sponsorId,
            turnSubmitted: 1
        )
    }
}
