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

        // 6. Dictator-level actions (General Secretary powers)
        actions.append(contentsOf: generatePurgeActions(game: game, rival: rival))
        actions.append(contentsOf: generateInformationControlActions(game: game))
        actions.append(contentsOf: generateConsolidationActions(game: game))

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
                    "\(patron.name) acknowledges your support with a nod at the Standing Committee.",
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
                title: "Expose \(rival.name) at Standing Committee",
                description: "Use accumulated evidence to publicly challenge \(rival.name)'s position.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(minStanding: 60, minNetwork: 40),
                effects: ["rivalThreat": -25, "standing": 10, "reputationRuthless": 15],
                isLocked: false,
                flavorText: "Strike when the iron is hot.",
                successNarratives: [
                    "Your accusations land. \(rival.name) is on the defensive.",
                    "The Standing Committee erupts. Your evidence is damning.",
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

        // Player is General Secretary — successor cultivation always available

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

        // Player is General Secretary — high stakes actions always available

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

        // Ultimate play - player is General Secretary, gate on stats only
        if game.standing >= 85 && game.network >= 70 {
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

    // MARK: - Purge Enemies Actions (General Secretary powers)

    private func generatePurgeActions(game: Game, rival: GameCharacter?) -> [PersonalAction] {
        var actions: [PersonalAction] = []
        let rivalName = rival?.name ?? "your rival"

        // Order Show Trial — wire to ShowTrialService
        actions.append(PersonalAction(
            id: "order_show_trial",
            category: .purgeEnemies,
            title: "Order show trial against \(rivalName)",
            description: "Initiate a public show trial to destroy \(rivalName)'s reputation and remove them from power.",
            costAP: 2,
            riskLevel: .high,
            requirements: ActionRequirements(
                minStanding: 50,
                minNetwork: 30,
                minPowerConsolidation: 30
            ),
            effects: ["rivalThreat": -20, "stability": -5, "reputationRuthless": 15, "eliteLoyalty": -8],
            isLocked: false,
            flavorText: "The courtroom becomes a theater of power.",
            actionNarrative: "You direct the security apparatus to prepare charges. The trial will be public, the verdict predetermined.",
            successNarratives: [
                "The trial is a spectacle. \(rivalName) confesses to crimes real and imagined.",
                "Cameras broadcast the humiliation. No one will dare challenge you after this.",
                "The verdict is guilty. \(rivalName) is led away to thunderous silence."
            ],
            failureNarratives: [
                "International observers condemn the trial. Domestic unrest grows.",
                "The accused refuses to confess. The trial becomes an embarrassment.",
                "Whispers spread that the charges were fabricated. Your legitimacy suffers."
            ]
        ))

        // Launch Anti-Corruption Campaign
        actions.append(PersonalAction(
            id: "launch_anticorruption",
            category: .purgeEnemies,
            title: "Launch anti-corruption campaign",
            description: "Target a rival faction with a sweeping corruption investigation. The tigers and flies will both be caught.",
            costAP: 2,
            riskLevel: .medium,
            requirements: ActionRequirements(
                minStanding: 40,
                minPowerConsolidation: 20
            ),
            effects: ["popularSupport": 8, "rivalThreat": -10, "eliteLoyalty": -5, "reputationRuthless": 8],
            isLocked: false,
            flavorText: "Anti-corruption is the sharpest sword in the arsenal.",
            actionNarrative: "You announce a campaign to root out corruption. Everyone understands who the real targets are.",
            successNarratives: [
                "Dozens of officials connected to your rival are placed under investigation.",
                "The campaign sweeps through the bureaucracy. Your enemies tremble.",
                "Public approval soars as corrupt officials are paraded before cameras."
            ],
            failureNarratives: [
                "The investigations uncover uncomfortable connections to your own allies.",
                "The campaign is seen as politically motivated. International credibility suffers."
            ]
        ))

        // Authorize Mass Detention (Shuanggui)
        actions.append(PersonalAction(
            id: "authorize_detention",
            category: .purgeEnemies,
            title: "Authorize shuanggui detention",
            description: "Order the extralegal detention and interrogation of suspect officials. They will confess or disappear.",
            costAP: 1,
            riskLevel: .high,
            requirements: ActionRequirements(
                minNetwork: 40,
                minPowerConsolidation: 40
            ),
            effects: ["rivalThreat": -12, "stability": -3, "reputationRuthless": 12, "eliteLoyalty": -10],
            isLocked: false,
            flavorText: "In the Party's discipline system, there are no lawyers.",
            actionNarrative: "Officials are quietly taken to undisclosed locations. The interrogations begin.",
            successNarratives: [
                "The detained officials provide useful confessions and intelligence.",
                "Word spreads through the apparatus. Potential dissenters reconsider.",
                "Your security services report full cooperation from the detainees."
            ],
            failureNarratives: [
                "A detainee dies in custody. The cover-up is imperfect.",
                "International human rights organizations publicize the detentions."
            ]
        ))

        // Purge Bureau
        actions.append(PersonalAction(
            id: "purge_bureau",
            category: .purgeEnemies,
            title: "Purge disloyal bureau",
            description: "Remove an entire tier of officials from a bureau and replace them with loyalists.",
            costAP: 2,
            riskLevel: .high,
            requirements: ActionRequirements(
                minStanding: 60,
                minNetwork: 50,
                minPowerConsolidation: 50
            ),
            effects: ["network": 8, "stability": -8, "eliteLoyalty": -12, "reputationRuthless": 15],
            isLocked: false,
            flavorText: "Cadres decide everything. And you decide the cadres.",
            actionNarrative: "You sign dismissal orders by the dozen. New faces will fill the empty offices by morning.",
            successNarratives: [
                "The purged bureau is restaffed with your loyalists. Efficiency improves overnight.",
                "The mass dismissals send a clear message: loyalty is not optional.",
                "A generation of bureaucrats is swept aside. Your people take their places."
            ],
            failureNarratives: [
                "The purge disrupts essential government functions. Problems cascade.",
                "Experienced officials flee the apparatus. Institutional knowledge is lost.",
                "The scale of the purge alarms even your supporters."
            ]
        ))

        return actions
    }

    // MARK: - Control Information Actions (General Secretary powers)

    private func generateInformationControlActions(game: Game) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        // Issue Propaganda Directive
        actions.append(PersonalAction(
            id: "propaganda_directive",
            category: .controlInformation,
            title: "Issue propaganda directive",
            description: "Order state media to amplify your achievements and minimize failures. The people will hear what you want them to hear.",
            costAP: 1,
            riskLevel: .low,
            requirements: ActionRequirements(
                minPowerConsolidation: 10
            ),
            effects: ["popularSupport": 6, "network": -3],
            isLocked: false,
            flavorText: "Truth is whatever the Party says it is.",
            actionNarrative: "The propaganda department receives new guidelines. Tomorrow's headlines are already written.",
            successNarratives: [
                "State media praises your leadership in glowing terms. The people believe.",
                "Your image is everywhere: billboards, newspapers, television. The cult grows.",
                "The narrative shifts. Your version of events becomes the official record."
            ]
        ))

        // Suppress Samizdat
        actions.append(PersonalAction(
            id: "suppress_samizdat",
            category: .controlInformation,
            title: "Suppress underground press",
            description: "Crack down on samizdat publications and dissident networks that spread unauthorized information.",
            costAP: 1,
            riskLevel: .medium,
            requirements: ActionRequirements(
                minNetwork: 25,
                minPowerConsolidation: 20
            ),
            effects: ["stability": 4, "popularSupport": -3, "reputationRuthless": 5],
            isLocked: false,
            flavorText: "Every typewriter is a potential weapon against the state.",
            actionNarrative: "Security forces raid printing operations and confiscate materials. Dissident voices fall silent.",
            successNarratives: [
                "Underground printing presses are seized. The flow of samizdat slows.",
                "Key dissident organizers are identified and placed under surveillance.",
                "The information space is cleaner. Only approved voices remain."
            ],
            failureNarratives: [
                "The crackdown drives the underground press deeper, making it harder to monitor.",
                "Confiscated materials leak to foreign journalists. The story goes international."
            ]
        ))

        // Control Media Narrative
        actions.append(PersonalAction(
            id: "control_narrative",
            category: .controlInformation,
            title: "Control media narrative",
            description: "Shape newspaper coverage of recent events to present your policies in the most favorable light.",
            costAP: 1,
            riskLevel: .low,
            requirements: ActionRequirements(
                minPowerConsolidation: 15
            ),
            effects: ["popularSupport": 4, "standing": 3, "reputationCompetent": 5],
            isLocked: false,
            flavorText: "The pen is mightier than the sword when you control all the pens.",
            actionNarrative: "Editors receive clear instructions about what to emphasize and what to bury.",
            successNarratives: [
                "The morning papers tell exactly the story you wanted told.",
                "Coverage of your latest initiative is universally positive.",
                "Unflattering details about your policies disappear from the news cycle."
            ]
        ))

        // Censor Foreign Broadcasts
        actions.append(PersonalAction(
            id: "censor_foreign",
            category: .controlInformation,
            title: "Censor foreign broadcasts",
            description: "Jam foreign radio signals and restrict access to outside information sources.",
            costAP: 1,
            riskLevel: .medium,
            requirements: ActionRequirements(
                minNetwork: 20,
                minPowerConsolidation: 25
            ),
            effects: ["stability": 3, "popularSupport": -4, "reputationRuthless": 3],
            isLocked: false,
            flavorText: "The outside world has nothing useful to say to our people.",
            actionNarrative: "Signal jammers are activated. The firewall between your people and the world grows thicker.",
            successNarratives: [
                "Foreign broadcasts are reduced to static. Your information monopoly strengthens.",
                "Citizens lose access to alternative viewpoints. The Party's voice is all that remains.",
                "The jamming operation is a technical success. Outside influence wanes."
            ],
            failureNarratives: [
                "Tech-savvy citizens find ways around the censorship. Resentment builds.",
                "The censorship draws international condemnation and trade pressure."
            ]
        ))

        return actions
    }

    // MARK: - Consolidate Power Actions (General Secretary powers)

    private func generateConsolidationActions(game: Game) -> [PersonalAction] {
        var actions: [PersonalAction] = []

        // Pack the Standing Committee
        actions.append(PersonalAction(
            id: "pack_standing_committee",
            category: .consolidatePower,
            title: "Pack the Standing Committee",
            description: "Engineer the replacement of a hostile Standing Committee member with a loyalist. The highest body must answer to you alone.",
            costAP: 2,
            riskLevel: .high,
            requirements: ActionRequirements(
                minStanding: 60,
                minNetwork: 40,
                minPowerConsolidation: 35
            ),
            effects: ["eliteLoyalty": 10, "network": 5, "reputationCunning": 10, "stability": -3],
            isLocked: false,
            flavorText: "The Standing Committee should stand with you, or not stand at all.",
            actionNarrative: "Through a careful combination of pressure, inducement, and bureaucratic maneuvering, you arrange a personnel change at the highest level.",
            successNarratives: [
                "Your loyalist takes their seat on the Standing Committee. The balance of power shifts.",
                "The replaced member 'retires for health reasons.' Everyone understands.",
                "The Standing Committee now has one more voice singing your tune."
            ],
            failureNarratives: [
                "Your attempt to force a change is blocked by a coalition of moderates.",
                "The targeted member fights back with powerful allies. Your move is checked."
            ]
        ))

        // Modify Constitution
        actions.append(PersonalAction(
            id: "modify_constitution",
            category: .consolidatePower,
            title: "Modify the constitution",
            description: "Push through constitutional amendments that expand your authority and weaken institutional checks on your power.",
            costAP: 2,
            riskLevel: .high,
            requirements: ActionRequirements(
                minStanding: 70,
                minPowerConsolidation: 50,
                minEliteLoyalty: 40
            ),
            effects: ["standing": 5, "eliteLoyalty": -8, "stability": -5, "reputationCunning": 12],
            isLocked: false,
            flavorText: "The law is what you make it.",
            actionNarrative: "The People's Congress convenes to ratify amendments that were written in your office.",
            successNarratives: [
                "The constitution is amended. Your powers are expanded. The legislature applauds.",
                "Legal scholars note the changes give you unprecedented authority. They keep their observations private.",
                "The constitutional framework now reflects the reality of your rule."
            ],
            failureNarratives: [
                "Unexpected resistance within the legislature delays the amendments.",
                "Legal experts publicly question the changes. International credibility suffers."
            ]
        ))

        // Abolish Term Limits
        if !game.termLimitsAbolished {
            actions.append(PersonalAction(
                id: "abolish_term_limits",
                category: .consolidatePower,
                title: "Abolish term limits",
                description: "Remove the constitutional restriction on how long you can serve. Your rule will have no expiration date.",
                costAP: 2,
                riskLevel: .high,
                requirements: ActionRequirements(
                    minStanding: 75,
                    minPowerConsolidation: 60,
                    minEliteLoyalty: 50
                ),
                effects: ["standing": 10, "eliteLoyalty": -15, "stability": -8, "popularSupport": -5, "reputationRuthless": 10],
                isLocked: false,
                flavorText: "Why should the people's mandate have an expiration date?",
                actionNarrative: "The legislature votes to remove presidential term limits. The vote is nearly unanimous. It had to be.",
                successNarratives: [
                    "Term limits are abolished. You can rule for as long as you see fit.",
                    "The rubber-stamp legislature approves the change. The world watches in silence.",
                    "Your hold on power is now constitutionally unlimited. The dynasty begins."
                ],
                failureNarratives: [
                    "Even your loyalists balk at removing all checks on power. The motion is tabled.",
                    "Street protests erupt at the attempt. International sanctions are threatened."
                ]
            ))
        }

        // Create New Security Agency
        actions.append(PersonalAction(
            id: "create_security_agency",
            category: .consolidatePower,
            title: "Create parallel security agency",
            description: "Establish a new security apparatus that answers only to you, bypassing existing institutional chains of command.",
            costAP: 2,
            riskLevel: .high,
            requirements: ActionRequirements(
                minStanding: 55,
                minNetwork: 35,
                minPowerConsolidation: 40,
                forbiddenFlags: ["parallel_security_created"]
            ),
            effects: ["network": 12, "militaryLoyalty": -5, "eliteLoyalty": -5, "stability": -3, "reputationRuthless": 8],
            isLocked: false,
            flavorText: "Trust no one institution. Control them all through competition.",
            actionNarrative: "You sign the decree establishing a new security directorate with broad authority and a direct reporting line to your office.",
            successNarratives: [
                "The new agency begins operations immediately. Its loyalty is to you personally.",
                "Existing security services eye the newcomer warily. That's the point.",
                "A parallel power structure now exists, answering only to the General Secretary."
            ],
            failureNarratives: [
                "Military and existing security leaders push back against the new competitor.",
                "The new agency struggles to recruit competent personnel from suspicious existing services."
            ]
        ))

        return actions
    }
}
