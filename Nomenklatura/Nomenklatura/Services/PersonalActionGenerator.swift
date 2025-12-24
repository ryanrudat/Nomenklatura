//
//  PersonalActionGenerator.swift
//  Nomenklatura
//
//  Dynamic personal action generation based on game state
//  Generates context-sensitive actions using actual characters, positions, and opportunities
//

import Foundation

final class PersonalActionGenerator {
    static let shared = PersonalActionGenerator()

    private init() {}

    // MARK: - Main Generation Method

    /// Generate all available personal actions for the current game state
    func generateActions(for game: Game, ladder: [LadderPosition]) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        // Get context
        let patron = game.patron
        let rival = game.primaryRival
        let currentPosition = ladder.first { $0.index == game.currentPositionIndex }
        let expandedTrack = currentPosition?.expandedTrack ?? .shared

        // 1. Core actions (always available)
        actions.append(contentsOf: generateCoreActions(game: game, patron: patron, rival: rival))

        // 2. Track-specific actions
        actions.append(contentsOf: generateTrackActions(track: expandedTrack, game: game))

        // 3. Dynamic opportunity actions based on game state
        actions.append(contentsOf: generateOpportunityActions(game: game, ladder: ladder, patron: patron, rival: rival))

        // 4. Successor cultivation actions (if available)
        actions.append(contentsOf: generateSuccessorActions(game: game))

        // 5. High-stakes actions (position-gated)
        actions.append(contentsOf: generateHighStakesActions(game: game, patron: patron, rival: rival))

        return actions
    }

    // MARK: - Core Actions (Always Available)

    private func generateCoreActions(game: Game, patron: GameCharacter?, rival: GameCharacter?) -> [PersonalAction] {
        var actions: [PersonalAction] = []
        let rivalName = rival?.name ?? "your rival"

        // Build Network category
        actions.append(PersonalAction(
            id: "cultivate_informants",
            category: .buildNetwork,
            title: "Cultivate informants",
            description: "Develop sources throughout the apparatus who can warn you of dangers and opportunities.",
            costAP: 1,
            riskLevel: .low,
            requirements: nil,
            effects: ["network": 4],
            isLocked: false,
            flavorText: "Information is the currency of survival.",
            successNarratives: [
                "A junior clerk in the records office agrees to pass along interesting documents.",
                "An old classmate from the Party school reconnects—and proves well-informed.",
                "Your network grows in the shadows of the apparatus."
            ]
        ))

        actions.append(PersonalAction(
            id: "gather_intel_rival",
            category: .buildNetwork,
            title: "Investigate \(rivalName)",
            description: "Task your network with uncovering \(rivalName)'s secrets and vulnerabilities.",
            costAP: 1,
            riskLevel: .medium,
            requirements: ActionRequirements(minNetwork: 15),
            effects: ["network": 2, "rivalThreat": -5],
            isLocked: false,
            flavorText: "Know your enemy better than they know themselves.",
            successNarratives: [
                "Your sources uncover compromising information about \(rivalName)'s past.",
                "A disgruntled subordinate of \(rivalName) provides useful intelligence.",
                "The file on \(rivalName) grows thicker with each passing week."
            ],
            failureNarratives: [
                "\(rivalName)'s people noticed your inquiries. They're watching you now.",
                "Your investigation hit a wall—someone warned \(rivalName)."
            ]
        ))

        actions.append(PersonalAction(
            id: "secure_allies",
            category: .buildNetwork,
            title: "Shore up alliances",
            description: "Strengthen ties with existing supporters through favors and mutual benefit.",
            costAP: 1,
            riskLevel: .low,
            requirements: nil,
            effects: ["network": 3, "standing": 2],
            isLocked: false,
            flavorText: "Loyalty must be constantly renewed.",
            successNarratives: [
                "A well-timed favor cements an important friendship.",
                "Your allies appreciate being remembered—and will remember you in turn.",
                "The web of mutual obligation grows stronger."
            ]
        ))

        // Secure Position category
        if let patron = patron {
            actions.append(PersonalAction(
                id: "demonstrate_loyalty",
                category: .securePosition,
                title: "Demonstrate loyalty to \(patron.name)",
                description: "Find ways to publicly show your dedication to \(patron.name)'s agenda.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["patronFavor": 8, "standing": -2],
                isLocked: false,
                flavorText: "A loyal dog at the master's heel—but dogs can bite.",
                successNarratives: [
                    "Your speech praising \(patron.name)'s wisdom is noted approvingly.",
                    "\(patron.name) acknowledges your support with a nod at the Presidium.",
                    "Word reaches \(patron.name) of your unwavering loyalty."
                ]
            ))

            actions.append(PersonalAction(
                id: "private_audience",
                category: .securePosition,
                title: "Request private audience with \(patron.name)",
                description: "Seek a one-on-one meeting to reinforce your relationship.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minStanding: 40),
                effects: ["patronFavor": 6, "reputationLoyal": 5],
                isLocked: false,
                flavorText: "Face to face, patron to protege.",
                successNarratives: [
                    "\(patron.name) grants you fifteen minutes. You make them count.",
                    "Over tea, \(patron.name) shares concerns about the faction's direction.",
                    "The audience goes well. \(patron.name) seems to trust you more."
                ]
            ))
        }

        actions.append(PersonalAction(
            id: "prepare_defenses",
            category: .securePosition,
            title: "Prepare defensive dossier",
            description: "Compile evidence of your loyalty and achievements in case of accusations.",
            costAP: 1,
            riskLevel: .low,
            requirements: nil,
            effects: ["network": 2],
            isLocked: false,
            flavorText: "In troubled times, documentation is armor.",
            successNarratives: [
                "Your file of commendations and testimonials grows reassuringly thick.",
                "You've catalogued every success, every approval from superiors.",
                "If accusations come, you'll be ready with evidence of your dedication."
            ]
        ))

        // Undermine Rivals category
        if let rival = rival {
            actions.append(PersonalAction(
                id: "spread_rumors",
                category: .undermineRivals,
                title: "Spread rumors about \(rival.name)",
                description: "Let whispers of \(rival.name)'s failings circulate through the corridors.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minNetwork: 20),
                effects: ["rivalThreat": -8, "reputationCunning": 5],
                isLocked: false,
                flavorText: "A whisper in the right ear can fell a giant.",
                successNarratives: [
                    "The rumors spread like wildfire. \(rival.name)'s reputation suffers.",
                    "People are talking about \(rival.name)'s alleged incompetence.",
                    "Your careful whisper campaign bears fruit."
                ],
                failureNarratives: [
                    "Someone traced the rumors back to you. \(rival.name) knows.",
                    "Your scheme was too obvious. Now you look petty."
                ]
            ))

            actions.append(PersonalAction(
                id: "expose_failures",
                category: .undermineRivals,
                title: "Document \(rival.name)'s failures",
                description: "Compile a record of \(rival.name)'s mistakes and shortcomings.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["rivalThreat": -5],
                isLocked: false,
                flavorText: "Everyone makes mistakes. The trick is remembering them.",
                successNarratives: [
                    "You've assembled a damning record of \(rival.name)'s missteps.",
                    "The file grows. Someday it may prove useful.",
                    "Each failure is noted, dated, documented."
                ]
            ))
        }

        return actions
    }

    // MARK: - Track-Specific Actions

    private func generateTrackActions(track: ExpandedCareerTrack, game: Game) -> [PersonalAction] {
        switch track {
        case .securityServices:
            return generateSecurityTrackActions(game: game)
        case .foreignAffairs:
            return generateForeignAffairsActions(game: game)
        case .economicPlanning:
            return generateEconomicActions(game: game)
        case .partyApparatus:
            return generatePartyApparatusActions(game: game)
        case .stateMinistry:
            return generateStateMinistryActions(game: game)
        case .militaryPolitical:
            return generateMilitaryPoliticalActions(game: game)
        case .regional:
            return generateRegionalActions(game: game)
        case .shared:
            return [] // No track-specific actions for shared positions
        }
    }

    private func generateSecurityTrackActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "security_surveillance",
                category: .buildNetwork,
                title: "Expand surveillance network",
                description: "Use your position to plant informants and monitoring devices.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 6, "reputationRuthless": 3],
                isLocked: false,
                flavorText: "The organs see all, hear all.",
                successNarratives: [
                    "Your surveillance capabilities expand into new areas of the apparatus.",
                    "New listening posts are established. Information flows to your desk.",
                    "The web of watchers grows ever wider."
                ]
            ),
            PersonalAction(
                id: "security_dossiers",
                category: .buildNetwork,
                title: "Access classified dossiers",
                description: "Review security files on colleagues and rivals.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["network": 4],
                isLocked: false,
                flavorText: "Everyone has secrets. State Protection knows most of them.",
                successNarratives: [
                    "The archives yield useful information about your colleagues.",
                    "You discover compromising details that may prove useful later.",
                    "Knowledge is power. Your power grows."
                ]
            ),
            PersonalAction(
                id: "security_intimidate",
                category: .undermineRivals,
                title: "Arrange 'friendly' investigation",
                description: "Have subordinates make pointed inquiries about a rival's activities.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(minNetwork: 40, minPositionIndex: 4),
                effects: ["rivalThreat": -15, "reputationRuthless": 10],
                isLocked: false,
                flavorText: "A visit from State Protection focuses the mind wonderfully.",
                successNarratives: [
                    "Your rival receives unexpected visitors asking uncomfortable questions.",
                    "The investigation finds nothing—but your rival is shaken.",
                    "Everyone noticed the investigators. Your rival's standing suffers."
                ],
                failureNarratives: [
                    "Your superiors question why resources were used for this 'investigation'.",
                    "The target complained to powerful friends. This may come back to haunt you."
                ]
            )
        ]
    }

    private func generateForeignAffairsActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "diplomatic_contacts",
                category: .buildNetwork,
                title: "Cultivate foreign contacts",
                description: "Build relationships with diplomats and foreign officials.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 5],
                isLocked: false,
                flavorText: "The outside world has much to teach—and much to offer.",
                successNarratives: [
                    "A foreign diplomat proves amenable to informal exchanges.",
                    "Your international network expands beyond official channels.",
                    "Useful information flows from abroad."
                ]
            ),
            PersonalAction(
                id: "diplomatic_intelligence",
                category: .buildNetwork,
                title: "Gather foreign intelligence",
                description: "Use your diplomatic position to collect useful information.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["network": 4, "reputationCompetent": 5],
                isLocked: false,
                flavorText: "Every conversation is an opportunity for intelligence.",
                successNarratives: [
                    "Your reports from abroad are well-received by the leadership.",
                    "You've developed a reputation for valuable foreign insights.",
                    "The intelligence you gather proves useful to multiple factions."
                ]
            ),
            PersonalAction(
                id: "diplomatic_prestige",
                category: .securePosition,
                title: "Negotiate minor agreement",
                description: "Achieve a small diplomatic success to burnish your credentials.",
                costAP: 2,
                riskLevel: .medium,
                requirements: ActionRequirements(minNetwork: 30, minPositionIndex: 3),
                effects: ["standing": 8, "reputationCompetent": 8],
                isLocked: false,
                flavorText: "Even small victories on the world stage shine brightly at home.",
                successNarratives: [
                    "The trade agreement is modest, but your role is noted.",
                    "A successful cultural exchange raises your profile.",
                    "The leadership appreciates your diplomatic finesse."
                ]
            )
        ]
    }

    private func generateEconomicActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "economic_data",
                category: .buildNetwork,
                title: "Access production data",
                description: "Review actual economic figures that reveal truths behind the propaganda.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 3],
                isLocked: false,
                flavorText: "The numbers tell stories the newspapers never will.",
                successNarratives: [
                    "You've seen the real figures. They're... illuminating.",
                    "Access to actual data gives you leverage over those who rely on fiction.",
                    "Knowledge of economic reality is power."
                ]
            ),
            PersonalAction(
                id: "economic_favors",
                category: .buildNetwork,
                title: "Allocate resources strategically",
                description: "Use your influence over allocations to build alliances with factory directors.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["network": 6, "reputationCunning": 3],
                isLocked: false,
                flavorText: "In a shortage economy, allocation is power.",
                successNarratives: [
                    "A grateful director becomes a useful ally.",
                    "Your 'adjustments' to the plan go unnoticed—but appreciated.",
                    "The web of economic obligations expands."
                ]
            ),
            PersonalAction(
                id: "economic_reform",
                category: .securePosition,
                title: "Propose efficiency measures",
                description: "Suggest reforms that enhance your reputation as a competent manager.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["standing": 5, "reputationCompetent": 8],
                isLocked: false,
                flavorText: "Reform is dangerous—but so is stagnation.",
                successNarratives: [
                    "Your proposal for streamlined reporting is adopted.",
                    "The Politburo notes your practical approach to economic management.",
                    "You're becoming known as someone who gets results."
                ]
            )
        ]
    }

    private func generatePartyApparatusActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "party_cadres",
                category: .buildNetwork,
                title: "Cultivate cadre connections",
                description: "Build relationships with Party personnel throughout the apparatus.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 5],
                isLocked: false,
                flavorText: "The Party is a web. Every node matters.",
                successNarratives: [
                    "Your network of loyal cadres expands across departments.",
                    "Personnel decisions increasingly favor your people.",
                    "The apparatus becomes more responsive to your needs."
                ]
            ),
            PersonalAction(
                id: "party_doctrine",
                category: .securePosition,
                title: "Demonstrate ideological purity",
                description: "Publish an article or give a speech reinforcing correct doctrine.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["standing": 4, "reputationLoyal": 6],
                isLocked: false,
                flavorText: "Orthodoxy is the safest position.",
                successNarratives: [
                    "Your speech on socialist construction is well-received.",
                    "The ideological department approves of your doctrinal clarity.",
                    "You're seen as a reliable guardian of Party principles."
                ]
            ),
            PersonalAction(
                id: "party_appointments",
                category: .buildNetwork,
                title: "Influence personnel decisions",
                description: "Guide appointments to place allies in key positions.",
                costAP: 2,
                riskLevel: .medium,
                requirements: ActionRequirements(minNetwork: 25, minPositionIndex: 3),
                effects: ["network": 8, "reputationCunning": 5],
                isLocked: false,
                flavorText: "Cadres decide everything.",
                successNarratives: [
                    "Your candidate receives the appointment. They'll remember who helped.",
                    "Another ally moves into a position of influence.",
                    "The personnel roster increasingly reflects your preferences."
                ]
            )
        ]
    }

    private func generateStateMinistryActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "ministry_bureaucracy",
                category: .buildNetwork,
                title: "Navigate the bureaucracy",
                description: "Build relationships with key administrators who control information flow.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 4],
                isLocked: false,
                flavorText: "The bureaucracy is a maze. You're learning the shortcuts.",
                successNarratives: [
                    "A senior clerk becomes a valuable source of advance information.",
                    "Your paperwork moves faster than anyone else's.",
                    "The administrative labyrinth becomes more navigable."
                ]
            ),
            PersonalAction(
                id: "ministry_efficiency",
                category: .securePosition,
                title: "Demonstrate administrative competence",
                description: "Ensure your department runs smoothly and meets its targets.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["standing": 5, "reputationCompetent": 6],
                isLocked: false,
                flavorText: "In government, competence is noticed—eventually.",
                successNarratives: [
                    "Your department's reports are consistently on time and accurate.",
                    "Superiors note your reliable management.",
                    "You're building a reputation as someone who delivers."
                ]
            ),
            PersonalAction(
                id: "ministry_coalition",
                category: .buildNetwork,
                title: "Build inter-ministry coalition",
                description: "Forge alliances with officials in other ministries.",
                costAP: 2,
                riskLevel: .low,
                requirements: ActionRequirements(minNetwork: 20, minPositionIndex: 3),
                effects: ["network": 7, "standing": 3],
                isLocked: false,
                flavorText: "No ministry is an island. Cooperation serves everyone.",
                successNarratives: [
                    "Your cross-ministry working group proves effective.",
                    "Officials from other departments begin seeking your input.",
                    "Your influence extends beyond your own ministry's walls."
                ]
            )
        ]
    }

    private func generateMilitaryPoliticalActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "military_officers",
                category: .buildNetwork,
                title: "Cultivate military contacts",
                description: "Build relationships with career officers in the armed forces.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["network": 5],
                isLocked: false,
                flavorText: "The army is the ultimate guarantor of power.",
                successNarratives: [
                    "A colonel proves amenable to informal discussions.",
                    "Your contacts in the officer corps expand.",
                    "Military intelligence begins flowing your way."
                ]
            ),
            PersonalAction(
                id: "military_loyalty",
                category: .securePosition,
                title: "Ensure political reliability",
                description: "Conduct ideological work that enhances your standing with military leadership.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 2),
                effects: ["standing": 4, "reputationLoyal": 5],
                isLocked: false,
                flavorText: "The Party must control the gun.",
                successNarratives: [
                    "Your political education sessions are well-attended.",
                    "The generals appreciate your ideological guidance.",
                    "Military-Party relations in your area are exemplary."
                ]
            ),
            PersonalAction(
                id: "military_intelligence",
                category: .buildNetwork,
                title: "Access military intelligence",
                description: "Review classified military assessments and operational plans.",
                costAP: 1,
                riskLevel: .medium,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["network": 6],
                isLocked: false,
                flavorText: "Knowledge of military capabilities is power.",
                successNarratives: [
                    "You've seen the real readiness reports. Interesting reading.",
                    "Military secrets become political leverage.",
                    "Your understanding of defense matters impresses colleagues."
                ]
            )
        ]
    }

    private func generateRegionalActions(game: Game) -> [PersonalAction] {
        [
            PersonalAction(
                id: "regional_base",
                category: .buildNetwork,
                title: "Build local power base",
                description: "Cultivate support among regional Party and government officials.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["network": 5],
                isLocked: false,
                flavorText: "The provinces are your proving ground.",
                successNarratives: [
                    "Local cadres rally to your leadership.",
                    "Your regional network grows stronger.",
                    "Provincial officials look to you for guidance."
                ]
            ),
            PersonalAction(
                id: "regional_results",
                category: .securePosition,
                title: "Deliver regional results",
                description: "Ensure your region meets or exceeds production targets.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["standing": 6, "reputationCompetent": 5],
                isLocked: false,
                flavorText: "Success in the provinces opens doors in the capital.",
                successNarratives: [
                    "Your region's numbers look good—or at least, they look good on paper.",
                    "Moscow notices your administrative success.",
                    "You're building a reputation as someone who delivers."
                ]
            ),
            PersonalAction(
                id: "regional_connections",
                category: .buildNetwork,
                title: "Maintain capital connections",
                description: "Keep your relationships in Moscow warm despite your provincial posting.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minNetwork: 15),
                effects: ["network": 4, "patronFavor": 3],
                isLocked: false,
                flavorText: "Out of sight, out of mind—unless you work to prevent it.",
                successNarratives: [
                    "Your regular reports to Moscow keep you in the conversation.",
                    "A trip to the capital renews important friendships.",
                    "You won't be forgotten in the provinces."
                ]
            )
        ]
    }

    // MARK: - Opportunity Actions (Dynamic based on game state)

    private func generateOpportunityActions(game: Game, ladder: [LadderPosition], patron: GameCharacter?, rival: GameCharacter?) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        // Check for vacancies above current position
        let currentIndex = game.currentPositionIndex
        let currentPosition = ladder.first { $0.index == currentIndex }
        let currentTrack = currentPosition?.expandedTrack ?? .shared

        // Filter positions to only those in the player's current track (or shared positions)
        // and only the next 1-2 levels above
        let positionsAbove = ladder.filter { position in
            position.index > currentIndex &&
            position.index <= currentIndex + 2 &&
            (position.expandedTrack == currentTrack || position.expandedTrack == .shared || currentTrack == .shared)
        }

        // Track which position indices we've already added to avoid duplicates
        var addedPositionIndices: Set<Int> = []

        for position in positionsAbove {
            // Skip if we already added a promotion action for this index
            guard !addedPositionIndices.contains(position.index) else { continue }

            // Check if there's a vacancy (simplified check)
            if game.standing >= position.requiredStanding {
                actions.append(PersonalAction(
                    id: "seek_promotion_\(position.expandedTrack.rawValue)_\(position.index)",
                    category: .makeYourPlay,
                    title: "Seek promotion to \(position.title)",
                    description: "Position yourself as a candidate for \(position.title).",
                    costAP: 2,
                    riskLevel: .medium,
                    requirements: ActionRequirements(
                        minStanding: position.requiredStanding,
                        minPatronFavor: position.requiredPatronFavor ?? 50
                    ),
                    effects: ["standing": 5],
                    isLocked: false,
                    flavorText: "Ambition must be acted upon.",
                    successNarratives: [
                        "Your name is now in consideration for the position.",
                        "Key supporters have been notified of your interest.",
                        "The groundwork for advancement is laid."
                    ]
                ))
                addedPositionIndices.insert(position.index)
            }
        }

        // High rivalry - opportunity to strike
        if game.rivalThreat >= 60, let rival = rival {
            actions.append(PersonalAction(
                id: "expose_rival_crisis",
                category: .undermineRivals,
                title: "Expose \(rival.name) at Presidium",
                description: "Use accumulated evidence to publicly challenge \(rival.name)'s position.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(minStanding: 60, minNetwork: 40),
                effects: ["rivalThreat": -25, "standing": 10, "reputationRuthless": 15],
                isLocked: false,
                flavorText: "Strike when the iron is hot.",
                successNarratives: [
                    "Your accusations land. \(rival.name) is on the defensive.",
                    "The Presidium erupts. Your evidence is damning.",
                    "\(rival.name)'s allies begin to distance themselves."
                ],
                failureNarratives: [
                    "Your attack backfired. \(rival.name) had prepared a counter-accusation.",
                    "The leadership views your public attack as destabilizing."
                ]
            ))
        }

        // Low patron favor - need to repair relationship
        if game.patronFavor < 40, let patron = patron {
            actions.append(PersonalAction(
                id: "repair_patron_relationship",
                category: .securePosition,
                title: "Make amends with \(patron.name)",
                description: "Your relationship has cooled. Take steps to restore favor.",
                costAP: 1,
                riskLevel: .low,
                requirements: nil,
                effects: ["patronFavor": 10],
                isLocked: false,
                flavorText: "A patron scorned is a dangerous enemy.",
                successNarratives: [
                    "Your gesture of loyalty is accepted. The chill begins to thaw.",
                    "\(patron.name) appreciates your efforts to make amends.",
                    "The relationship is not fully repaired, but it's a start."
                ]
            ))
        }

        // High network - special intelligence gathering
        if game.network >= 50 {
            actions.append(PersonalAction(
                id: "deep_intelligence",
                category: .buildNetwork,
                title: "Activate deep sources",
                description: "Your extensive network can uncover secrets others cannot reach.",
                costAP: 2,
                riskLevel: .medium,
                requirements: ActionRequirements(minNetwork: 50),
                effects: ["network": 3],
                isLocked: false,
                flavorText: "Your web reaches into the darkest corners.",
                successNarratives: [
                    "Your sources deliver extraordinary intelligence.",
                    "Secrets thought buried come to light.",
                    "Information is power, and your power grows."
                ]
            ))
        }

        // Check for scandal flags that create opportunities
        if game.flags.contains("rival_scandal_brewing") {
            if let rival = rival {
                actions.append(PersonalAction(
                    id: "exploit_scandal",
                    category: .undermineRivals,
                    title: "Exploit \(rival.name)'s scandal",
                    description: "The moment has come to capitalize on \(rival.name)'s misfortune.",
                    costAP: 1,
                    riskLevel: .medium,
                    requirements: ActionRequirements(minNetwork: 25),
                    effects: ["rivalThreat": -20, "reputationCunning": 8],
                    isLocked: false,
                    flavorText: "Never let a good crisis go to waste."
                ))
            }
        }

        return actions
    }

    // MARK: - Successor Actions

    private func generateSuccessorActions(game: Game) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        let hasSuccessor = game.successorRelationships.contains { $0.isActive }
        let successorCount = game.successorRelationships.filter { $0.isActive }.count

        // Only available at higher positions
        guard game.currentPositionIndex >= 3 else { return [] }

        if !hasSuccessor {
            actions.append(PersonalAction(
                id: "identify_protege",
                category: .cultivateSuccessor,
                title: "Identify promising protege",
                description: "Begin cultivating a younger official who could carry your legacy.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(minPositionIndex: 3),
                effects: ["network": 3],
                isLocked: false,
                flavorText: "Every great leader needs an heir.",
                successNarratives: [
                    "You've identified a promising young cadre worth cultivating.",
                    "A junior official shows potential. You begin their mentorship.",
                    "The seeds of succession are planted."
                ]
            ))
        } else if successorCount < 2 {
            actions.append(PersonalAction(
                id: "mentor_protege",
                category: .cultivateSuccessor,
                title: "Advance protege's career",
                description: "Use your influence to secure opportunities for your chosen successor.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(requiresActiveSuccessor: true),
                effects: ["patronFavor": 2, "network": 2],
                isLocked: false,
                flavorText: "Their rise reflects well on you.",
                successNarratives: [
                    "Your protege receives a choice assignment thanks to your intervention.",
                    "The mentorship deepens. Your heir grows stronger.",
                    "Investment in the next generation pays dividends."
                ]
            ))

            actions.append(PersonalAction(
                id: "test_protege",
                category: .cultivateSuccessor,
                title: "Test protege's loyalty",
                description: "Assign a difficult task to gauge your successor's dedication.",
                costAP: 1,
                riskLevel: .low,
                requirements: ActionRequirements(requiresActiveSuccessor: true),
                effects: ["network": 2],
                isLocked: false,
                flavorText: "Trust must be verified.",
                successNarratives: [
                    "Your protege passes the test. Their loyalty is confirmed.",
                    "The challenge reveals your heir's true character.",
                    "You can rely on them when the time comes."
                ]
            ))
        }

        return actions
    }

    // MARK: - High Stakes Actions

    private func generateHighStakesActions(game: Game, patron: GameCharacter?, rival: GameCharacter?) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        // Only available at very high positions
        guard game.currentPositionIndex >= 5 else { return [] }

        if let rival = rival {
            actions.append(PersonalAction(
                id: "denounce_rival",
                category: .makeYourPlay,
                title: "Formally denounce \(rival.name)",
                description: "Bring charges against \(rival.name) before the Central Committee.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(
                    minStanding: 70,
                    minNetwork: 50,
                    requiredFlags: ["rival_evidence_collected"]
                ),
                effects: ["rivalThreat": -40, "standing": 15, "reputationRuthless": 20],
                isLocked: true,
                lockReason: "Requires Standing 70+, Network 50+, and collected evidence",
                flavorText: "The accusation is the weapon. The evidence is ammunition."
            ))
        }

        // Ultimate play - only at highest levels
        if game.currentPositionIndex >= 6 && game.standing >= 85 && game.network >= 70 {
            actions.append(PersonalAction(
                id: "leadership_challenge",
                category: .makeYourPlay,
                title: "Challenge for supreme leadership",
                description: "The time has come to make your bid for the highest office.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(
                    minStanding: 85,
                    minNetwork: 70
                ),
                effects: ["standing": -20, "network": -30],
                isLocked: false,
                flavorText: "History remembers those who dared.",
                successNarratives: [
                    "You've declared your candidacy. There's no turning back.",
                    "The Party must choose. Your bid is public.",
                    "The ultimate gamble begins."
                ],
                failureNarratives: [
                    "Your challenge is premature. The backlash is severe.",
                    "The leadership closes ranks against you.",
                    "You've revealed your ambition too soon."
                ]
            ))
        }

        return actions
    }
}
