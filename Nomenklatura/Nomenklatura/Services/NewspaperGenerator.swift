//
//  NewspaperGenerator.swift
//  Nomenklatura
//
//  Generates newspaper editions based on game state
//

import Foundation

final class NewspaperGenerator {
    static let shared = NewspaperGenerator()

    private init() {}

    // MARK: - Generate Newspaper

    func generateNewspaper(
        for game: Game,
        config: NewspaperConfig = .psra,
        worldEvents: [WorldEvent]? = nil
    ) -> NewspaperEdition {
        // Get world events from game if not provided
        let events = worldEvents ?? game.publicWorldEvents(turns: 1)

        let headline = generateHeadline(for: game, worldEvents: events)
        let secondaryStories = generateSecondaryStories(for: game, worldEvents: events, count: 2)
        let characterFate = generateCharacterFateReport(for: game)
        let international = generateInternationalNews(for: game, worldEvents: events)
        let propaganda = generatePropaganda(for: game)

        return NewspaperEdition(
            turnNumber: game.turnNumber,
            publicationDate: formatDate(for: game.turnNumber),
            publicationName: config.publicationName,
            headline: headline,
            secondaryStories: secondaryStories,
            characterFateReport: characterFate,
            internationalNews: international,
            propagandaPiece: propaganda
        )
    }

    // MARK: - Headline Generation

    private func generateHeadline(for game: Game, worldEvents: [WorldEvent]) -> HeadlineStory {
        // Domestic drama outranks everything — a regime's paper spins last
        // night's arrests before it reports foreign affairs.
        if let domestic = generateDomesticDramaHeadline(for: game) {
            return domestic
        }

        // Check for major world events first - they should dominate headlines
        if let eventHeadline = generateEventBasedHeadline(from: worldEvents, game: game) {
            return eventHeadline
        }

        // Player diplomatic actions take priority over generic headlines
        if let diplomaticHeadline = generatePlayerDiplomacyHeadline(for: game) {
            return diplomaticHeadline
        }

        // World tension headline when tension is critical (50% chance to allow variety)
        let worldTension = worldTensionValue(for: game)
        if worldTension > 60, Int.random(in: 1...100) <= 50 {
            return generateWorldTensionHeadline(tension: worldTension)
        }

        // Check for follow-up headlines referencing past events (20% chance)
        if Int.random(in: 1...100) <= 20,
           let followUp = generateFollowUpHeadline(for: game) {
            return followUp
        }

        // Fall back to stat-based generation
        let category = selectHeadlineCategory(for: game)

        switch category {
        case .economic:
            return generateEconomicHeadline(for: game)
        case .political:
            return generatePoliticalHeadline(for: game)
        case .military:
            return generateMilitaryHeadline(for: game)
        case .international:
            return generateInternationalHeadline(for: game)
        case .domestic:
            return generateDomesticHeadline(for: game)
        case .ideological:
            return generateIdeologicalHeadline(for: game)
        }
    }

    /// Front-page treatment for last night's domestic drama. Feeds the
    /// previously-orphaned trial/corruption/death/congress generators plus
    /// the conspiracy-aftermath flash staged by ConspiracyService. A single
    /// dedupe token in variables prevents the same story running two
    /// mornings straight; nil on quiet mornings.
    private func generateDomesticDramaHeadline(for game: Game) -> HeadlineStory? {
        let lastStoryKey = "press_last_domestic_story"

        // 1. Conspiracy/coup aftermath — staged by ConspiracyService,
        //    consumed here so it runs exactly one morning.
        if let flash = game.variables["press_domestic_flash"] {
            game.variables["press_domestic_flash"] = nil
            return generateConspiracyAftermathHeadline(kind: flash, game: game)
        }

        // 2. Death or execution of a cadre last turn.
        if let fallen = game.characters.first(where: { c in
            guard let changed = c.statusChangedTurn, changed == game.turnNumber - 1 else { return false }
            return c.currentStatus == .executed || c.currentStatus == .dead
        }) {
            let token = "death-\(fallen.templateId)"
            if game.variables[lastStoryKey] != token {
                game.variables[lastStoryKey] = token
                let cause: DeathCause = fallen.currentStatus == .executed ? .executed : .naturalCauses
                return generateDeathHeadline(character: fallen, cause: cause, game: game)
            }
        }

        // 3. Active show trial — one story per phase as it advances.
        if let trial = game.activeShowTrials.first(where: { $0.phase != .completed }) {
            let token = "trial-\(trial.id.uuidString)-\(String(describing: trial.phase))"
            if game.variables[lastStoryKey] != token {
                game.variables[lastStoryKey] = token
                return generateTrialHeadline(trial: trial, game: game)
            }
        }

        // 4. The Chairman's corruption scandal broke — the paper spins it
        //    as a campaign against unnamed ministries.
        if game.flags.contains("corruption_exposed") {
            let token = "corruption-exposed"
            if game.variables[lastStoryKey] != token {
                game.variables[lastStoryKey] = token
                return generateCorruptionHeadline(targetName: "senior officials", phase: "initiated", game: game)
            }
        }

        // 5. A Congress session convened last turn.
        if let session = game.currentCongressSession, session.turnConvened == game.turnNumber - 1 {
            let token = "congress-\(session.sessionNumber)"
            if game.variables[lastStoryKey] != token {
                game.variables[lastStoryKey] = token
                return generateCongressHeadline(session: session, game: game)
            }
        }

        return nil
    }

    /// State-press treatment of a staged domestic flash. Conspiracy kinds:
    /// "order_restored" = the plot was crushed (triumphant tone);
    /// "state_of_emergency" = the coup wounded the regime and the paper
    /// conspicuously minimizes. Reform kinds announce the amended order.
    private func generateConspiracyAftermathHeadline(kind: String, game: Game) -> HeadlineStory {
        switch kind {
        case "reform_political":
            return HeadlineStory(
                headline: "THE CONSTITUTION AMENDED",
                subheadline: "Republic Enters a New Political Era: \(game.politicalOrder.displayName) Proclaimed",
                body: "By solemn vote of the Standing Committee, the constitutional order of the Republic has been revised. The state now stands as \(game.politicalOrder.displayName.lowercased()). \(game.politicalOrder.blurb) Officials at every level are instructed to study the amended text and align their work accordingly.",
                category: .political
            )
        case "pilot_success":
            return HeadlineStory(
                headline: "THE ZONE DELIVERS",
                subheadline: "Special Development Zone Exceeds All Targets; Method Validated",
                body: "The Special Development Zone experiment has concluded in triumph: production up, shelves stocked, workers' incomes rising. The Party declares the results a vindication of scientific policy-making — cautious experiment, rigorous measurement, disciplined expansion. Delegations from every region are already requesting instruction in the zone's methods.",
                category: .economic
            )
        case "pilot_failure":
            return HeadlineStory(
                headline: "ZONE EXPERIMENT CONCLUDES",
                subheadline: "Valuable Lessons Drawn from Special Development Zone Trial",
                body: "The Special Development Zone trial has concluded on schedule. While certain targets were not achieved — owing to speculative excesses and the sabotage of elements hostile to disciplined experimentation — the Party affirms that the exercise has yielded valuable lessons. There are no plans for expansion at this time.",
                category: .economic
            )
        case "statistics_scandal":
            return HeadlineStory(
                headline: "REPORTING DISCIPLINE RESTORED",
                subheadline: "Isolated Irregularities in Regional Returns Corrected; Responsible Officials Reassigned",
                body: "Following a routine review, certain irregularities in regional production returns have been identified and corrected. The Party emphasizes that these were the failures of individual officials, not of the planning system, whose scientific character remains beyond question. Revised figures will be published in due course.",
                category: .economic
            )
        case "credit_crash":
            return HeadlineStory(
                headline: "FINANCIAL RECTIFICATION CAMPAIGN ANNOUNCED",
                subheadline: "State Bank Moves Against Speculation; Discipline Returns to Enterprise Credit",
                body: "The State Bank has announced a comprehensive rectification of enterprise credit, correcting distortions introduced by speculative elements and undisciplined managers. Citizens are assured that deposits remain secure and that the temporary adjustment in production schedules reflects prudent planning, not crisis. Those who spread rumors to the contrary will answer for them.",
                category: .economic
            )
        case "reform_economic":
            return HeadlineStory(
                headline: "A NEW ECONOMIC COURSE",
                subheadline: "Economic Constitution Revised; Republic Adopts \(game.currentEconomicSystem.displayName)",
                body: "The Standing Committee has approved a revision of the Economic Constitution. The Republic's economy will henceforth operate under \(game.currentEconomicSystem.displayName.lowercased()). Ministries and enterprises are directed to implement the transition with discipline. The Party assures citizens that the change serves the long-term prosperity of all.",
                category: .economic
            )
        case "state_of_emergency":
            return HeadlineStory(
                headline: "CALM RETURNS TO THE CAPITAL",
                subheadline: "Garrison Exercises Conclude; Ministries Resume Normal Operations",
                body: "Residents are advised that the unusual troop movements observed in recent days were scheduled readiness exercises, conducted successfully under the personal direction of the Chairman. Rumors circulated by hostile elements regarding disturbances at government buildings are without foundation. All ministries report normal operations.",
                category: .political
            )
        default: // "order_restored"
            return HeadlineStory(
                headline: "WRECKERS' PLOT SMASHED",
                subheadline: "Organs of State Security Act Decisively; Conspirators in Custody",
                body: "The vigilance of the organs of state security has exposed and dismantled a conspiratorial clique that sought to betray the revolution from within. The plotters, whose names will be announced pending investigation, were taken into custody without incident. The Party calls on all citizens to redouble their watchfulness against enemies of the people.",
                category: .political
            )
        }
    }

    /// Generate a headline from actual world events
    private func generateEventBasedHeadline(from events: [WorldEvent], game: Game) -> HeadlineStory? {
        // Filter for significant events suitable for state press
        let significantEvents = events
            .filter { !$0.isClassified && $0.severity >= .significant }
            .sorted { $0.severity > $1.severity }

        guard let topEvent = significantEvents.first else { return nil }

        // Get the country name for the headline
        let countryName = game.country(withId: topEvent.countryId)?.name ?? "foreign nation"

        // Generate headline based on event type with actual country name
        let (headline, subheadline, body, category) = formatEventForNewspaper(
            event: topEvent,
            countryName: countryName,
            game: game
        )

        return HeadlineStory(
            headline: headline,
            subheadline: subheadline,
            body: body,
            category: category
        )
    }

    /// Generate a follow-up headline referencing a past event
    private func generateFollowUpHeadline(for game: Game) -> HeadlineStory? {
        // Get significant events from past 2-5 turns (not current turn)
        let pastEvents = game.recentWorldEvents(turns: 5)
            .filter { $0.turnOccurred < game.turnNumber && $0.turnOccurred >= game.turnNumber - 5 }
            .filter { !$0.isClassified && $0.severity >= .moderate }

        guard let pastEvent = pastEvents.randomElement() else { return nil }

        let countryName = game.country(withId: pastEvent.countryId)?.name ?? "foreign nation"
        let country = game.country(withId: pastEvent.countryId)
        let isHostile = country?.isEnemy ?? false
        let turnsSince = game.turnNumber - pastEvent.turnOccurred

        // Generate follow-up based on event type
        switch pastEvent.eventType {
        case .borderIncident:
            if isHostile {
                if turnsSince <= 2 {
                    return HeadlineStory(
                        headline: "TENSIONS REMAIN HIGH FOLLOWING \(countryName.uppercased()) BORDER INCIDENT",
                        subheadline: "Border Guards Maintain Vigilant Watch",
                        body: "Frontier forces report continued alertness following the recent provocations by \(countryName). The Ministry of Defense assures citizens that our borders remain secure despite ongoing hostile actions by imperialist neighbors.",
                        category: .international
                    )
                } else {
                    return HeadlineStory(
                        headline: "\(countryName.uppercased()) BORDER SITUATION NORMALIZING",
                        subheadline: "Socialist Resolve Proves Effective",
                        body: "Following the firm response to \(countryName) provocations, tensions at the frontier have eased. Our principled stance demonstrates that aggression against the Socialist Republic will always fail.",
                        category: .international
                    )
                }
            }

        case .revolution, .coup:
            if turnsSince <= 3 {
                return HeadlineStory(
                    headline: "NEW \(countryName.uppercased()) GOVERNMENT CONSOLIDATES POWER",
                    subheadline: "Political Situation Remains Fluid",
                    body: "Following recent political upheaval in \(countryName), the new leadership is taking steps to establish control. The Foreign Ministry continues to monitor developments closely.",
                    category: .international
                )
            } else {
                return HeadlineStory(
                    headline: "\(countryName.uppercased()) SEEKS STABILITY AFTER UPHEAVAL",
                    subheadline: "International Community Watches Closely",
                    body: "The aftermath of the recent political changes in \(countryName) continues to unfold. The Socialist Republic remains prepared to engage with any government committed to peaceful relations.",
                    category: .international
                )
            }

        case .economicCrisis:
            if isHostile {
                return HeadlineStory(
                    headline: "\(countryName.uppercased()) ECONOMIC RECOVERY UNCERTAIN",
                    subheadline: "Capitalist System Fails Working Masses",
                    body: "Weeks after the onset of economic crisis, \(countryName) shows few signs of recovery. Unemployment continues to rise as the inherent contradictions of capitalism manifest themselves. Socialist economists note the superiority of planned economies.",
                    category: .economic
                )
            } else {
                return HeadlineStory(
                    headline: "FRATERNAL AID TO \(countryName.uppercased()) CONTINUES",
                    subheadline: "Socialist Solidarity in Action",
                    body: "The Socialist Republic continues to provide economic assistance to our brothers in \(countryName) as they overcome temporary difficulties. This is the true meaning of international solidarity.",
                    category: .economic
                )
            }

        case .treatyViolation:
            return HeadlineStory(
                headline: "CONSEQUENCES OF \(countryName.uppercased()) TREATY VIOLATION",
                subheadline: "International Law Must Be Respected",
                body: "The flagrant disregard for established agreements by \(countryName) continues to affect regional stability. The Socialist Republic demands accountability and respect for international norms.",
                category: .international
            )

        case .armsBuildUp:
            if isHostile {
                return HeadlineStory(
                    headline: "\(countryName.uppercased()) MILITARIZATION CONTINUES",
                    subheadline: "Peace-Loving Nations Express Concern",
                    body: "Despite international calls for restraint, \(countryName) continues its aggressive military expansion. The imperialist powers show their true intentions through ever-increasing defense spending.",
                    category: .military
                )
            }

        case .proxyConflict:
            return HeadlineStory(
                headline: "CONFLICT NEAR \(countryName.uppercased()) ENTERS NEW PHASE",
                subheadline: "Regional Stability Remains Fragile",
                body: "The ongoing conflict in the region surrounding \(countryName) continues to evolve. The Socialist Republic calls for peaceful resolution while supporting legitimate liberation movements.",
                category: .military
            )

        case .leadershipChange:
            return HeadlineStory(
                headline: "RELATIONS WITH \(countryName.uppercased()) UNDER NEW LEADERSHIP",
                subheadline: "Foreign Ministry Assesses New Direction",
                body: "Following the recent change in \(countryName) leadership, diplomatic channels are being recalibrated. The Socialist Republic remains committed to peaceful coexistence with all nations.",
                category: .international
            )

        case .defection:
            return HeadlineStory(
                headline: "DEFECTOR FROM \(countryName.uppercased()) REVEALS CONDITIONS",
                subheadline: "Testimonies Confirm Reports",
                body: "The individual who recently sought asylum from \(countryName) continues to provide valuable insights into conditions there. Their testimony confirms the superiority of socialist life.",
                category: .international
            )

        default:
            return nil
        }

        return nil
    }

    // MARK: - Player Diplomatic Action Headlines

    /// Generate a headline from recent player diplomatic actions recorded in game.flags
    private func generatePlayerDiplomacyHeadline(for game: Game) -> HeadlineStory? {
        let recentActions = recentDiplomaticActions(for: game, turnsBack: 1)
        guard let (actionType, countryId, _) = recentActions.last else { return nil }

        let country = game.foreignCountries.first { $0.countryId == countryId }
        let countryName = country?.name ?? "foreign nation"

        switch actionType {
        case .economicSanctions:
            return HeadlineStory(
                headline: "PSR SANCTIONS AGAINST \(countryName.uppercased()) SEND SHOCKWAVES",
                subheadline: "Economic Measures Demonstrate Socialist Resolve",
                body: "The government has imposed economic sanctions against \(countryName) in response to continued provocations. Trade restrictions are expected to pressure the \(countryName) regime into compliance with international norms. Workers across the Republic express full support for the decisive action.",
                category: .international
            )

        case .diplomaticProtest:
            return HeadlineStory(
                headline: "FOREIGN MINISTRY ISSUES STERN PROTEST TO \(countryName.uppercased())",
                subheadline: "Diplomatic Note Demands Immediate Rectification",
                body: "The Foreign Ministry has delivered a formal protest to the government of \(countryName), demanding an immediate end to hostile actions. The note, described as 'firm but measured,' reflects the Socialist Republic's commitment to principled diplomacy.",
                category: .international
            )

        case .recallAmbassador:
            return HeadlineStory(
                headline: "AMBASSADOR RECALLED FROM \(countryName.uppercased())",
                subheadline: "Diplomatic Relations Downgraded Amid Crisis",
                body: "In a dramatic escalation, the Socialist Republic has recalled its ambassador from \(countryName). The unprecedented step signals the gravity of the current dispute. The Foreign Ministry stated that normal relations cannot continue under present circumstances.",
                category: .international
            )

        case .militaryThreat:
            return HeadlineStory(
                headline: "DEFENSE FORCES ON HIGH ALERT NEAR \(countryName.uppercased()) BORDER",
                subheadline: "Military Readiness Demonstrates Socialist Strength",
                body: "The Ministry of Defense has ordered heightened alert along the frontier with \(countryName). Military exercises are underway to ensure the People's Armed Forces remain prepared to defend the motherland. The measure sends an unmistakable message to aggressors.",
                category: .military
            )

        case .tradeNegotiation:
            return HeadlineStory(
                headline: "HISTORIC TRADE AGREEMENT WITH \(countryName.uppercased())",
                subheadline: "Economic Cooperation Enters New Phase",
                body: "Negotiations with \(countryName) have produced a comprehensive trade agreement that will benefit workers in both nations. The deal strengthens economic ties and demonstrates the advantages of socialist economic planning on the world stage.",
                category: .economic
            )

        case .sendAid:
            return HeadlineStory(
                headline: "PSR EXTENDS FRATERNAL AID TO \(countryName.uppercased())",
                subheadline: "Socialist Solidarity in Action",
                body: "The Socialist Republic has dispatched economic assistance to \(countryName), fulfilling its duty of international solidarity. The aid package demonstrates the generosity and strength of the socialist system, standing in stark contrast to capitalist exploitation.",
                category: .international
            )

        case .culturalExchange:
            return HeadlineStory(
                headline: "CULTURAL TIES WITH \(countryName.uppercased()) FLOURISH",
                subheadline: "Delegations Strengthen People-to-People Bonds",
                body: "A major cultural exchange program with \(countryName) has been launched, featuring artists, scholars, and youth representatives. The initiative deepens mutual understanding between our peoples and showcases the achievements of socialist culture.",
                category: .international
            )

        case .militaryCooperation:
            return HeadlineStory(
                headline: "HISTORIC AGREEMENT: PSR SIGNS MILITARY PACT WITH \(countryName.uppercased())",
                subheadline: "Defense Cooperation Strengthens Socialist Camp",
                body: "A landmark military cooperation agreement with \(countryName) has been signed, enhancing collective defense capabilities. Joint exercises and equipment sharing will strengthen the fraternal alliance against imperialist aggression.",
                category: .military
            )

        case .sabotage:
            // Covert action -- reported obliquely to avoid revealing PSR involvement
            return HeadlineStory(
                headline: "INDUSTRIAL DIFFICULTIES REPORTED IN \(countryName.uppercased())",
                subheadline: "Economic Setbacks Plague Hostile Regime",
                body: "Reports from \(countryName) indicate significant disruptions to industrial and military infrastructure. Foreign analysts attribute the difficulties to systemic failures inherent in their political system.",
                category: .international
            )

        case .supportDissidents:
            // Covert action -- reported obliquely to avoid revealing PSR involvement
            return HeadlineStory(
                headline: "WORKERS IN \(countryName.uppercased()) DEMAND CHANGE",
                subheadline: "Opposition Voices Grow Louder",
                body: "Growing unrest among the working class in \(countryName) signals deepening crisis. Progressive forces within the country call for fundamental reforms. International observers note the inevitable march of history.",
                category: .international
            )

        case .plantAssets, .propaganda:
            // Covert actions -- generic headline to avoid revealing details
            return HeadlineStory(
                headline: "DIPLOMATIC DEVELOPMENTS WITH \(countryName.uppercased())",
                subheadline: "Foreign Ministry Reports on International Situation",
                body: "The Foreign Ministry has announced developments in relations with \(countryName). The diplomatic initiative reflects the Party's wise stewardship of international affairs and commitment to advancing socialist interests on the world stage.",
                category: .international
            )
        }
    }

    private func generateWorldTensionHeadline(tension: Int) -> HeadlineStory {
        let tensionLevel: String
        if tension > 85 {
            tensionLevel = "CRITICAL"
        } else if tension > 75 {
            tensionLevel = "DANGEROUS"
        } else {
            tensionLevel = "ELEVATED"
        }

        let headlines = [
            HeadlineStory(
                headline: "WORLD TENSION RISES TO \(tensionLevel) LEVELS",
                subheadline: "Imperialist Provocations Threaten Global Peace",
                body: "International tensions have reached \(tensionLevel.lowercased()) levels as aggressive posturing by Western powers threatens global stability. The Socialist Republic calls on all peace-loving nations to resist imperialist warmongering. The People's Armed Forces remain vigilant.",
                category: .international
            ),
            HeadlineStory(
                headline: "COLD WAR TENSIONS ESCALATE",
                subheadline: "Global Powers on Edge as Crisis Deepens",
                body: "The international situation has deteriorated significantly, with military readiness increasing across multiple nations. The Socialist Republic maintains its principled stance for peace while preparing to defend the achievements of socialism against any aggressor.",
                category: .international
            ),
            HeadlineStory(
                headline: "PARTY CALLS FOR VIGILANCE AS GLOBAL TENSIONS MOUNT",
                subheadline: "Central Committee Issues Statement on International Situation",
                body: "The Central Committee has issued a statement urging citizens to maintain revolutionary vigilance as international tensions intensify. Civil defense preparations continue while the Foreign Ministry pursues all diplomatic avenues for de-escalation.",
                category: .international
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    /// Format a world event for newspaper presentation (state propaganda spin)
    private func formatEventForNewspaper(
        event: WorldEvent,
        countryName: String,
        game: Game
    ) -> (headline: String, subheadline: String, body: String, category: HeadlineCategory) {
        let country = game.country(withId: event.countryId)
        let isHostile = country?.isEnemy ?? false
        _ = country?.isAlly ?? false  // Reserved for future ally-specific formatting

        switch event.eventType {
        case .borderIncident:
            if isHostile {
                return (
                    "\(countryName.uppercased()) PROVOCATION AT BORDER CONDEMNED",
                    "The People's Armed Forces Maintain Vigilant Defense",
                    "Aggressive actions by \(countryName) forces near our sovereign borders have been firmly repulsed. The Ministry of Defense assures citizens that our frontier remains secure. The Foreign Ministry has lodged a formal protest.",
                    .international
                )
            } else {
                return (
                    "BORDER INCIDENT WITH \(countryName.uppercased()) RESOLVED",
                    "Diplomatic Channels Prove Effective",
                    "A minor incident along the border with \(countryName) has been resolved through proper diplomatic channels. Both nations remain committed to peaceful relations.",
                    .international
                )
            }

        case .revolution, .coup:
            if isHostile {
                return (
                    "POLITICAL UPHEAVAL IN \(countryName.uppercased())",
                    "Contradictions of Bourgeois System Exposed",
                    "Reports from \(countryName) indicate significant political turmoil as the inherent instability of their system manifests. The Socialist Republic observes developments with measured interest.",
                    .international
                )
            } else {
                return (
                    "CONCERNING DEVELOPMENTS IN \(countryName.uppercased())",
                    "The Party Monitors Situation Closely",
                    "Political changes in \(countryName) are being carefully monitored by the Foreign Ministry. The Socialist Republic remains committed to fraternal relations with all progressive forces.",
                    .international
                )
            }

        case .economicCrisis:
            if isHostile {
                return (
                    "ECONOMIC CRISIS GRIPS \(countryName.uppercased())",
                    "Capitalist System Shows Its True Face",
                    "The working people of \(countryName) suffer as their economy collapses under the weight of bourgeois mismanagement. Unemployment and inflation demonstrate the superiority of socialist planning.",
                    .economic
                )
            } else {
                return (
                    "\(countryName.uppercased()) FACES ECONOMIC DIFFICULTIES",
                    "Socialist Solidarity Will Prevail",
                    "Our fraternal partners in \(countryName) are experiencing temporary economic challenges. The Socialist Republic stands ready to provide assistance as part of our commitment to international solidarity.",
                    .economic
                )
            }

        case .treatyProposal:
            return (
                "\(countryName.uppercased()) SEEKS CLOSER TIES",
                "Diplomatic Overtures Under Consideration",
                "The government of \(countryName) has indicated interest in improving bilateral relations. The Foreign Ministry is carefully evaluating this proposal in accordance with our principles of peaceful coexistence.",
                .international
            )

        case .treatyViolation:
            return (
                "\(countryName.uppercased()) VIOLATES INTERNATIONAL AGREEMENTS",
                "The Socialist Republic Demands Accountability",
                "Flagrant disregard for established agreements by \(countryName) has been met with firm diplomatic response. Such provocations will not undermine our commitment to principled international relations.",
                .international
            )

        case .leadershipChange:
            return (
                "NEW LEADERSHIP IN \(countryName.uppercased())",
                "Political Transition Underway",
                "Changes in the leadership of \(countryName) are being observed by our diplomatic services. The Foreign Ministry will establish appropriate contacts with the new administration.",
                .international
            )

        case .armsBuildUp:
            if isHostile {
                return (
                    "\(countryName.uppercased()) MILITARY BUILDUP CONDEMNED",
                    "Imperialist Aggression Threatens Peace",
                    "Intelligence reports confirm increased military activity in \(countryName). The Socialist Republic's armed forces remain prepared to defend our motherland against any aggression.",
                    .military
                )
            } else {
                return (
                    "\(countryName.uppercased()) STRENGTHENS DEFENSES",
                    "Fraternal Nations United Against Imperialism",
                    "Our allies in \(countryName) are taking prudent measures to ensure collective security. Socialist solidarity remains the foundation of peace.",
                    .military
                )
            }

        case .proxyConflict:
            return (
                "CONFLICT ERUPTS NEAR \(countryName.uppercased())",
                "Imperialist Meddling Destabilizes Region",
                "Fighting has broken out in the region surrounding \(countryName). The Socialist Republic calls for peaceful resolution while remaining vigilant against imperialist expansion.",
                .military
            )

        case .purge:
            return (
                "\(countryName.uppercased()): INTERNAL STRUGGLES REPORTED",
                "Political Realignment Underway",
                "Reports indicate significant personnel changes within the \(countryName) government. The Socialist Republic continues normal diplomatic relations while monitoring developments.",
                .political
            )

        default:
            // Generic international headline for other event types
            return (
                "DEVELOPMENTS IN \(countryName.uppercased())",
                "Foreign Ministry Monitors Situation",
                "The Foreign Ministry reports on recent developments in \(countryName). The Socialist Republic maintains its commitment to peaceful coexistence and principled foreign policy.",
                .international
            )
        }
    }

    private func selectHeadlineCategory(for game: Game) -> HeadlineCategory {
        // Weight categories based on game state
        var weights: [(HeadlineCategory, Int)] = []

        // Economic issues dominate when stats are low
        if game.industrialOutput < 40 || game.foodSupply < 40 {
            weights.append((.economic, 40))
        } else {
            weights.append((.economic, 20))
        }

        // Political when stability is fragile
        if game.stability < 50 {
            weights.append((.political, 35))
        } else {
            weights.append((.political, 20))
        }

        // Military when loyalty is low
        if game.militaryLoyalty < 50 {
            weights.append((.military, 25))
        } else {
            weights.append((.military, 15))
        }

        weights.append((.international, 15))
        weights.append((.domestic, 15))
        weights.append((.ideological, 10))

        return weightedRandomSelection(from: weights) ?? .domestic
    }

    // MARK: - Category-Specific Headlines

    private func generateEconomicHeadline(for game: Game) -> HeadlineStory {
        if game.industrialOutput >= 70 {
            return HeadlineStory(
                headline: "FIVE-YEAR PLAN QUOTAS EXCEEDED",
                subheadline: "Workers Demonstrate Socialist Spirit",
                body: "Industrial production has surpassed planned targets by \(Int.random(in: 8...15))%, demonstrating the superiority of socialist planning. Factory committees across the nation report unprecedented worker enthusiasm.",
                category: .economic
            )
        } else if game.industrialOutput < 40 {
            return HeadlineStory(
                headline: "CENTRAL COMMITTEE CALLS FOR INCREASED PRODUCTION",
                subheadline: "Temporary Shortfalls Attributed to Saboteurs",
                body: "The Central Committee has issued directives to address temporary production difficulties. Investigations continue into acts of economic sabotage by enemies of the people.",
                category: .economic
            )
        } else {
            let headlines = [
                HeadlineStory(
                    headline: "NEW TRACTOR FACTORY OPENS IN NORTHERN PROVINCE",
                    subheadline: "Thousands Attend Ceremony",
                    body: "The Karsten Tractor Works opened today, adding significant capacity to agricultural mechanization efforts. Party officials praised the dedication of construction brigades.",
                    category: .economic
                ),
                HeadlineStory(
                    headline: "HARVEST COLLECTION PROCEEDS ON SCHEDULE",
                    subheadline: "Collective Farms Report Strong Yields",
                    body: "Agricultural officials report satisfactory progress in this year's harvest collection. The application of scientific methods continues to improve yields across collective farms.",
                    category: .economic
                )
            ]
            return headlines.randomElement() ?? headlines[0]
        }
    }

    private func generatePoliticalHeadline(for game: Game) -> HeadlineStory {
        if game.stability >= 70 {
            return HeadlineStory(
                headline: "PARTY CONGRESS AFFIRMS UNITY",
                subheadline: "Delegates Reaffirm Commitment to Socialist Path",
                body: "The recent Party Congress concluded with unanimous approval of the Central Committee's report. Delegates expressed full confidence in Party leadership and the correctness of current policies.",
                category: .political
            )
        } else if game.stability < 40 {
            return HeadlineStory(
                headline: "VIGILANCE AGAINST ENEMIES INTENSIFIED",
                subheadline: "Party Calls for Renewed Ideological Struggle",
                body: "In response to provocations by hostile elements, the Central Committee has called for heightened vigilance. All Party members are reminded of their duty to report suspicious activities.",
                category: .political
            )
        } else {
            let headlines = [
                HeadlineStory(
                    headline: "PLENUM ADDRESSES ECONOMIC QUESTIONS",
                    subheadline: "New Measures to Strengthen Planning",
                    body: "The Central Committee Plenum has adopted resolutions to improve economic coordination. New guidelines emphasize socialist discipline and collective responsibility.",
                    category: .political
                ),
                HeadlineStory(
                    headline: "PARTY MEMBERSHIP GROWS",
                    subheadline: "Youth Organizations Show Particular Enthusiasm",
                    body: "Party membership continues to expand as workers and intellectuals seek to contribute to socialist construction. Young Pioneer organizations report record applications.",
                    category: .political
                )
            ]
            return headlines.randomElement() ?? headlines[0]
        }
    }

    private func generateMilitaryHeadline(for game: Game) -> HeadlineStory {
        let headlines = [
            HeadlineStory(
                headline: "ALLIANCE EXERCISES CONCLUDE SUCCESSFULLY",
                subheadline: "Socialist Defense Capabilities Demonstrated",
                body: "Joint military exercises with fraternal socialist nations have concluded, demonstrating the unshakeable unity of the socialist camp. Western observers noted the high readiness of participating forces.",
                category: .military
            ),
            HeadlineStory(
                headline: "NEW MISSILE SYSTEM ENHANCES DEFENSE",
                subheadline: "Technology of the Socialist Republic Leads World",
                body: "Defense scientists have announced successful tests of advanced missile systems, further strengthening the Socialist Republic's defensive capabilities against imperialist aggression.",
                category: .military
            ),
            HeadlineStory(
                headline: "MILITARY PARADE CELEBRATES REVOLUTIONARY HERITAGE",
                subheadline: "Modern Equipment on Display",
                body: "Crowds gathered in the Capital to witness the annual parade showcasing the strength of the People's Army. The display underscored the nation's commitment to defending socialist achievements.",
                category: .military
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    private func generateInternationalHeadline(for game: Game) -> HeadlineStory {
        let headlines = [
            HeadlineStory(
                headline: "WESTERN PROVOCATIONS CONDEMNED",
                subheadline: "The Socialist Republic Remains Committed to Peace",
                body: "The Foreign Ministry has issued a strong protest against recent provocative actions by imperialist forces near our borders. Despite Western aggression, the People's Socialist Republic maintains its peaceful foreign policy.",
                category: .international
            ),
            HeadlineStory(
                headline: "FRATERNAL SOCIALIST NATIONS STRENGTHEN TIES",
                subheadline: "Economic Cooperation Expands",
                body: "High-level meetings with delegations from fraternal socialist countries have produced new agreements for economic and cultural cooperation, demonstrating the vitality of international socialism.",
                category: .international
            ),
            HeadlineStory(
                headline: "THIRD WORLD LIBERATION MOVEMENTS ADVANCE",
                subheadline: "Colonial Powers Face Inevitable Defeat",
                body: "Reports from the Commonwealth colonies indicate continued progress in the struggle against colonialism. The Socialist Republic's solidarity with liberation movements remains unwavering.",
                category: .international
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    private func generateDomesticHeadline(for game: Game) -> HeadlineStory {
        if game.popularSupport >= 60 {
            return HeadlineStory(
                headline: "LIVING STANDARDS CONTINUE TO RISE",
                subheadline: "New Housing Complexes Open",
                body: "Thousands of families have moved into new apartment complexes this quarter, continuing the Party's commitment to improving living conditions. Consumer goods availability shows steady improvement.",
                category: .domestic
            )
        } else {
            let headlines = [
                HeadlineStory(
                    headline: "EDUCATION REFORMS SHOW RESULTS",
                    subheadline: "Technical Training Expanded",
                    body: "The Ministry of Education reports successful implementation of curriculum reforms emphasizing technical skills. New vocational programs prepare youth for socialist construction.",
                    category: .domestic
                ),
                HeadlineStory(
                    headline: "HEALTHCARE ACHIEVEMENTS RECOGNIZED",
                    subheadline: "Infant Mortality Rates Decline",
                    body: "The socialist healthcare system continues to demonstrate its superiority over capitalist medicine. New clinics in rural areas have significantly improved access to care.",
                    category: .domestic
                )
            ]
            return headlines.randomElement() ?? headlines[0]
        }
    }

    private func generateIdeologicalHeadline(for game: Game) -> HeadlineStory {
        let headlines = [
            HeadlineStory(
                headline: "REVOLUTIONARY DOCTRINE STUDY CIRCLES EXPAND",
                subheadline: "Workers Deepen Political Consciousness",
                body: "Party organizations report increased participation in revolutionary doctrine study groups. Workers express eagerness to understand the scientific basis of socialist construction.",
                category: .ideological
            ),
            HeadlineStory(
                headline: "REVISIONISM FIRMLY REJECTED",
                subheadline: "Party Maintains Ideological Purity",
                body: "The Central Committee has reaffirmed its commitment to orthodox revolutionary principles, rejecting attempts to introduce bourgeois ideology under the guise of 'reform.'",
                category: .ideological
            ),
            HeadlineStory(
                headline: "SOCIALIST REALISM IN THE ARTS FLOURISHES",
                subheadline: "New Works Celebrate Working Class Heroes",
                body: "The Writers' Union has announced the publication of new works depicting the heroism of socialist labor. Artists continue to draw inspiration from the achievements of the working class.",
                category: .ideological
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    // MARK: - Secondary Stories

    private func generateSecondaryStories(for game: Game, worldEvents: [WorldEvent], count: Int) -> [NewspaperStory] {
        var stories: [NewspaperStory] = []

        // First, add stories from minor/moderate world events (not the main headline)
        let secondaryEvents = worldEvents
            .filter { !$0.isClassified && $0.severity < .significant }

        for event in secondaryEvents.prefix(1) {
            if let countryName = game.country(withId: event.countryId)?.name {
                let story = formatEventAsSecondaryStory(event: event, countryName: countryName, game: game)
                stories.append(story)
            }
        }

        // Add international situation stories based on diplomatic state
        if stories.count < count {
            stories.append(contentsOf: generateInternationalSituationStories(for: game, limit: count - stories.count))
        }

        // Fill remaining slots with standard stories
        let standardStories = [
            NewspaperStory(
                headline: "Collective Farm Wins Production Banner",
                brief: "The Red October Collective has been awarded the Banner of Socialist Labor for exceeding grain quotas.",
                importance: 2
            ),
            NewspaperStory(
                headline: "New Metro Line Opens",
                brief: "Citizens celebrate the opening of the newest metro line, reducing commute times for thousands.",
                importance: 3
            ),
            NewspaperStory(
                headline: "Youth Festival Attracts Thousands",
                brief: "The International Youth Festival drew participants from across the socialist world.",
                importance: 2
            ),
            NewspaperStory(
                headline: "Scientific Conference Advances Knowledge",
                brief: "Scientists of the Socialist Republic presented breakthrough research at the Academy of Sciences.",
                importance: 3
            ),
            NewspaperStory(
                headline: "Worker-Hero Honored at People's Congress",
                brief: "Exemplary steel worker receives Order of Labor for production achievements.",
                importance: 2
            ),
            NewspaperStory(
                headline: "Cultural Exchange with Fraternal Nations",
                brief: "Delegation from \(game.alliedCountries.randomElement()?.name ?? "Germany") begins cultural tour of the Socialist Republic.",
                importance: 2
            ),
            NewspaperStory(
                headline: "Weather Conditions Favorable for Harvest",
                brief: "Meteorological service reports conditions supporting agricultural success.",
                importance: 1
            ),
            NewspaperStory(
                headline: "Sports Team Triumphs",
                brief: "National hockey team defeats \(game.hostileCountries.randomElement()?.name ?? "capitalist") opponents in international competition.",
                importance: 2
            )
        ]

        let remainingCount = count - stories.count
        if remainingCount > 0 {
            stories.append(contentsOf: standardStories.shuffled().prefix(remainingCount))
        }

        return Array(stories.prefix(count))
    }

    /// Format a world event as a brief secondary story
    private func formatEventAsSecondaryStory(event: WorldEvent, countryName: String, game: Game) -> NewspaperStory {
        let country = game.country(withId: event.countryId)
        let isHostile = country?.isEnemy ?? false

        switch event.eventType {
        case .tradeDispute:
            if isHostile {
                return NewspaperStory(
                    headline: "Trade Tensions with \(countryName)",
                    brief: "Economic disputes with \(countryName) highlight the contradictions of capitalist commerce.",
                    importance: 2
                )
            } else {
                return NewspaperStory(
                    headline: "Trade Negotiations with \(countryName)",
                    brief: "Discussions continue to resolve minor trade matters with fraternal \(countryName).",
                    importance: 2
                )
            }

        case .militaryExercise:
            if isHostile {
                return NewspaperStory(
                    headline: "\(countryName) Military Maneuvers Noted",
                    brief: "The Ministry of Defense monitors routine military exercises in \(countryName).",
                    importance: 2
                )
            } else {
                return NewspaperStory(
                    headline: "Joint Exercises with \(countryName)",
                    brief: "Fraternal military cooperation strengthens socialist defense capabilities.",
                    importance: 2
                )
            }

        case .summitAnnouncement:
            return NewspaperStory(
                headline: "Diplomatic Talks with \(countryName) Planned",
                brief: "High-level meetings to address matters of mutual interest are being arranged.",
                importance: 3
            )

        case .defection:
            return NewspaperStory(
                headline: "Individual Renounces \(countryName) Citizenship",
                brief: "Another soul seeks refuge from the oppression of the \(isHostile ? "bourgeois" : "troubled") system.",
                importance: 1
            )

        case .resourceDiscovery:
            return NewspaperStory(
                headline: "Resource Developments in \(countryName)",
                brief: "Economic developments in \(countryName) may affect regional commodity markets.",
                importance: 2
            )

        default:
            return NewspaperStory(
                headline: "Brief News from \(countryName)",
                brief: "The Foreign Ministry reports on developments in \(countryName).",
                importance: 1
            )
        }
    }

    // MARK: - International Situation Stories

    /// Generate secondary stories based on the current diplomatic world state
    private func generateInternationalSituationStories(for game: Game, limit: Int) -> [NewspaperStory] {
        var stories: [NewspaperStory] = []
        let worldTension = worldTensionValue(for: game)

        if worldTension > 60 {
            stories.append(NewspaperStory(
                headline: "Cold War Tensions Escalate",
                brief: "Global powers on edge as international tension index reaches \(worldTension). The Socialist Republic calls for peaceful resolution.",
                importance: 4
            ))
        }

        if let strongAlly = game.foreignCountries.first(where: { $0.isAlly && $0.relationshipScore > 80 }) {
            stories.append(NewspaperStory(
                headline: "Socialist Solidarity with \(strongAlly.name)",
                brief: "Strong fraternal ties with \(strongAlly.name) continue to deepen, exemplifying the unity of the socialist camp.",
                importance: 3
            ))
        }

        if let warCountry = game.foreignCountries.first(where: { $0.status == .atWar }) {
            stories.append(NewspaperStory(
                headline: "Conflict Report: \(warCountry.name)",
                brief: "The military situation involving \(warCountry.name) remains tense. The Foreign Ministry monitors developments closely.",
                importance: 4
            ))
        }

        let highTradeCountries = game.foreignCountries.filter { $0.tradeVolume > 60 }
        if highTradeCountries.count >= 2 {
            stories.append(NewspaperStory(
                headline: "Economic Ties Strengthen Across Bloc",
                brief: "Trade volumes with \(highTradeCountries.count) partner nations exceed targets, demonstrating the vitality of socialist economic cooperation.",
                importance: 3
            ))
        }

        // Ripple effect coverage -- reactions to player diplomatic actions from recent turns
        let pastActions = recentDiplomaticActions(for: game, turnsBack: 2)
            .filter { $0.turn < game.turnNumber }

        if !pastActions.isEmpty {
            let allies = game.alliedCountries
            let hostiles = game.hostileCountries
            let hasHostileAction = pastActions.contains { Self.hostileActionTypes.contains($0.action) }

            if hasHostileAction {
                if let ally = allies.randomElement() {
                    stories.append(NewspaperStory(
                        headline: "Bloc Responds to PSR Diplomatic Initiative",
                        brief: "\(ally.name) increases cooperation following the Socialist Republic's firm stance on the international stage.",
                        importance: 3
                    ))
                }

                if let hostile = hostiles.randomElement() {
                    stories.append(NewspaperStory(
                        headline: "Western Powers Condemn PSR Actions",
                        brief: "\(hostile.name) and allied nations issue predictable protests against the Socialist Republic's sovereign decisions.",
                        importance: 2
                    ))
                }
            } else {
                if let ally = allies.randomElement() {
                    stories.append(NewspaperStory(
                        headline: "Fraternal Nations Welcome PSR Diplomacy",
                        brief: "\(ally.name) praises the Socialist Republic's constructive engagement on the world stage.",
                        importance: 3
                    ))
                }
            }

            if worldTension > 40 {
                stories.append(NewspaperStory(
                    headline: "Military Readiness: Border Regions on Alert",
                    brief: "Frontier forces maintain heightened vigilance following recent diplomatic developments. The People's Army stands ready.",
                    importance: 3
                ))
            }
        }

        return Array(stories.sorted { $0.importance > $1.importance }.prefix(limit))
    }

    // MARK: - Character Fate Reports

    private func generateCharacterFateReport(for game: Game) -> CharacterFateReport? {
        // 30% chance of a character fate report
        guard Int.random(in: 1...100) <= 30 else { return nil }

        let fateTypes: [CharacterFateType] = [
            .promoted, .reassigned, .retired, .underInvestigation, .rehabilitated
        ]
        guard let fateType = fateTypes.randomElement() else { return nil }

        let names = [
            ("Deputy Minister Horvat", "Ministry of Heavy Industry"),
            ("Comrade Baltas", "Party Secretary, Northern District"),
            ("Colonel Richter", "Border Guards Command"),
            ("Professor Moravec", "Academy of Sciences"),
            ("Director Steinberg", "State Planning Commission")
        ]

        guard let (name, title) = names.randomElement() else { return nil }

        let report: String
        let euphemism: String
        let isRehabilitation: Bool

        switch fateType {
        case .promoted:
            euphemism = "elevated to increased responsibilities"
            report = "\(name) has been appointed to a position of greater responsibility, in recognition of dedicated service to the Party and state."
            isRehabilitation = false
        case .reassigned:
            euphemism = "transferred to other important work"
            report = "\(name) has been reassigned to contribute expertise to critical work in another sector. The Party thanks \(name) for past service."
            isRehabilitation = false
        case .retired:
            euphemism = "released from duties for health reasons"
            report = "Due to health considerations, \(name) has been released from current responsibilities. The Central Committee wishes a speedy recovery."
            isRehabilitation = false
        case .underInvestigation:
            euphemism = "assisting Party organs with inquiries"
            report = "\(name) is currently cooperating with Party control organs regarding certain procedural matters. Further details will be provided as appropriate."
            isRehabilitation = false
        case .rehabilitated:
            euphemism = "errors in previous judgment corrected"
            report = "Following careful review, previous allegations against \(name) have been found to be without merit. \(name) has been fully rehabilitated and restored to good standing."
            isRehabilitation = true
        default:
            return nil
        }

        return CharacterFateReport(
            characterName: name,
            characterTitle: title,
            fateType: fateType,
            euphemism: euphemism,
            fullReport: report,
            isRehabilitating: isRehabilitation
        )
    }

    // MARK: - International News

    private func generateInternationalNews(for game: Game, worldEvents: [WorldEvent]) -> String? {
        guard Int.random(in: 1...100) <= 70 else { return nil }  // Increased chance if we have events

        // First, try to use actual world events for international news
        let internationalEvents = worldEvents
            .filter { !$0.isClassified && $0.severity >= .moderate }
            .filter { event in
                // Skip events already used in main headline
                event.severity < .significant
            }

        if let event = internationalEvents.first,
           let country = game.country(withId: event.countryId) {
            return formatEventAsInternationalNews(event: event, country: country, game: game)
        }

        // Check for diplomatic-state-driven international news
        if let diplomaticNews = generateDiplomaticInternationalNews(for: game) {
            return diplomaticNews
        }

        // Fall back to dynamic news using actual country names
        let hostileCountries = game.hostileCountries
        let hostileName1 = hostileCountries.first?.name ?? "United Kingdom"
        let hostileName2 = hostileCountries.dropFirst().first?.name ?? "Canada"

        let news = [
            "The imperialist blockade of socialist nations continues to fail as they demonstrate the resilience of revolutionary construction.",
            "Workers in \(hostileName1) and \(hostileName2) face increasing unemployment as the contradictions of the bourgeois system deepen.",
            "Liberation forces in the Commonwealth colonies report significant advances against colonial oppressors.",
            "Economic crisis grips \(hostileName1) as inflation erodes working-class living standards.",
            "Peace advocates across the world call for an end to the imperialist arms race.",
            "Newly liberated territories look to the Socialist Republic's model for development guidance."
        ]

        return news.randomElement()
    }

    /// Generate international news driven by the current diplomatic landscape
    private func generateDiplomaticInternationalNews(for game: Game) -> String? {
        var candidates: [String] = []
        let worldTension = worldTensionValue(for: game)

        let strainedCountries = game.foreignCountries.filter {
            $0.status == .strained || $0.status == .hostile
        }
        if let strained = strainedCountries.randomElement() {
            candidates.append("Diplomatic relations with \(strained.name) remain strained. The Foreign Ministry continues efforts to resolve outstanding disputes through principled negotiation.")
        }

        let allies = game.alliedCountries
        if allies.count >= 3 {
            let allyNames = allies.prefix(3).map { $0.name }.joined(separator: ", ")
            candidates.append("The socialist bloc stands united: \(allyNames) and other fraternal nations reaffirm their commitment to collective defense and economic cooperation.")
        }

        if let tensionCountry = game.foreignCountries.first(where: { $0.diplomaticTension > 70 }) {
            candidates.append("Tensions with \(tensionCountry.name) have reached concerning levels. Military observers report increased activity along shared borders.")
        }

        if worldTension > 80 {
            candidates.append("Global tensions approach crisis levels. Civil defense authorities urge citizens to familiarize themselves with emergency procedures. The Party assures the people that socialism will prevail.")
        }

        if let adversary = game.foreignCountries.first(where: { $0.relationshipScore < -75 }) {
            candidates.append("Relations with \(adversary.name) have deteriorated sharply. The aggressive posture of the \(adversary.name) regime necessitates heightened vigilance on all fronts.")
        }

        return candidates.randomElement()
    }

    /// Format a world event as brief international news
    private func formatEventAsInternationalNews(event: WorldEvent, country: ForeignCountry, game: Game) -> String {
        let isHostile = country.isEnemy

        switch event.eventType {
        case .economicCrisis:
            if isHostile {
                return "Economic turmoil continues in \(country.name) as the contradictions of capitalism manifest in rising unemployment and inflation."
            } else {
                return "Our fraternal partners in \(country.name) are working to overcome temporary economic difficulties with socialist determination."
            }

        case .borderIncident:
            if isHostile {
                return "Provocative actions by \(country.name) at the border have been met with firm resolve by our frontier forces."
            } else {
                return "A minor border incident with \(country.name) has been resolved through diplomatic channels."
            }

        case .leadershipChange:
            return "Political transitions in \(country.name) are being closely monitored by the Foreign Ministry."

        case .armsBuildUp:
            if isHostile {
                return "Military buildup in \(country.name) demonstrates the aggressive nature of imperialist powers."
            } else {
                return "Defense modernization in \(country.name) strengthens the socialist bloc's collective security."
            }

        case .treatyProposal:
            return "Diplomatic overtures from \(country.name) are under consideration by the Foreign Ministry."

        case .tradeDispute:
            return "Trade discussions with \(country.name) continue as both sides seek mutually acceptable terms."

        default:
            return "The Foreign Ministry reports on developments in \(country.name) affecting regional stability."
        }
    }

    // MARK: - Propaganda Piece

    private func generatePropaganda(for game: Game) -> String? {
        guard Int.random(in: 1...100) <= 50 else { return nil }

        let pieces = [
            "\"The Party is the mind, honor, and conscience of our epoch.\" — The Founder",
            "\"Forward to the Victory of Communism!\" Workers unite to build the bright future.",
            "Every citizen a soldier in the army of socialist construction!",
            "Vigilance is the weapon of the revolution. Report enemies of the people.",
            "Labor is honor, labor is glory, labor is valor and heroism!",
            "The future belongs to the working class. Capitalism is doomed to the dustbin of history."
        ]

        return pieces.randomElement()
    }

    // MARK: - People's Congress Headlines

    /// Generate headlines for People's Congress sessions
    func generateCongressHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        switch session.currentStatus {
        case .convening:
            return generateCongressConveningHeadline(session: session, game: game)
        case .deliberating:
            return generateCongressDeliberatingHeadline(session: session, game: game)
        case .voting:
            return generateCongressVotingHeadline(session: session, game: game)
        case .concluded:
            return generateCongressConclusionHeadline(session: session, game: game)
        case .scheduled:
            return generateCongressScheduledHeadline(session: session, game: game)
        case .cancelled:
            return HeadlineStory(
                headline: "CONGRESS SESSION POSTPONED",
                subheadline: "Delegates to Reconvene at Later Date",
                body: "Due to circumstances requiring the attention of Party leadership, the scheduled session of the People's Congress has been postponed. Delegates have been notified and will be recalled when conditions permit.",
                category: .political
            )
        }
    }

    private func generateCongressConveningHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        let delegateCount = session.delegatesPresent
        let sessionOrdinal = ordinalNumber(session.sessionNumber)

        // Different headlines based on session type
        switch session.currentType {
        case .annual:
            let headlines = [
                HeadlineStory(
                    headline: "PEOPLE'S CONGRESS OPENS \(sessionOrdinal.uppercased()) SESSION",
                    subheadline: "\(delegateCount) Delegates Gather in Great Hall",
                    body: "Amid scenes of revolutionary enthusiasm, the \(sessionOrdinal) session of the People's Congress opened today in the Great Hall of the People. Delegates representing workers, peasants, soldiers, and intellectuals from every province assembled to conduct the people's business. The session will hear reports from the Central Committee and approve the state budget.",
                    category: .political
                ),
                HeadlineStory(
                    headline: "GREAT HALL WELCOMES PEOPLE'S REPRESENTATIVES",
                    subheadline: "Congress Session Begins with Stirring Ceremony",
                    body: "The People's Congress convened this morning with the singing of the Internationale and a moment of remembrance for revolutionary martyrs. General Secretary's opening remarks called for unity in the face of challenges. \(delegateCount) delegates stand ready to fulfill their constitutional duty.",
                    category: .political
                ),
                HeadlineStory(
                    headline: "SOCIALIST DEMOCRACY IN ACTION",
                    subheadline: "People's Congress Demonstrates System's Vitality",
                    body: "The convening of the People's Congress reminds the world of the superiority of socialist democracy. Unlike bourgeois parliaments where money decides elections, our delegates are genuine representatives of the laboring masses, selected for their dedication to the people's cause.",
                    category: .political
                )
            ]
            return headlines.randomElement() ?? headlines[0]

        case .emergency:
            return HeadlineStory(
                headline: "EMERGENCY CONGRESS SESSION CALLED",
                subheadline: "Leadership Summons Delegates for Urgent Deliberations",
                body: "In response to matters of national importance, the Standing Committee has convened an emergency session of the People's Congress. Delegates arrived through the night from distant provinces, demonstrating their commitment to the nation. The gravity of the situation demands unified action.",
                category: .political
            )

        case .constitutional:
            return HeadlineStory(
                headline: "CONGRESS ASSEMBLES FOR HISTORIC CONSTITUTIONAL SESSION",
                subheadline: "Delegates to Consider Fundamental Reforms",
                body: "In a session that will shape the future of the socialist state, delegates have gathered to consider constitutional amendments. The proposed changes reflect the Party's deepening understanding of the requirements of socialist construction in the current era.",
                category: .political
            )

        case .succession:
            return HeadlineStory(
                headline: "CONGRESS CONVENES FOR LEADERSHIP TRANSITION",
                subheadline: "Nation Watches as New Era Begins",
                body: "The People's Congress has assembled under extraordinary circumstances to confirm new leadership for the Party and state. In this moment of transition, delegates carry the hopes of the entire nation. The smooth transfer of power demonstrates the maturity of socialist institutions.",
                category: .political
            )
        }
    }

    private func generateCongressDeliberatingHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        // Pick a random focus area based on agenda
        let agendaItems = session.agendaItems

        if agendaItems.contains(where: { $0.category == .fiveYearPlan || $0.category == .budgetApproval }) {
            let headlines = [
                HeadlineStory(
                    headline: "DELEGATES DEBATE ECONOMIC DIRECTION",
                    subheadline: "Five-Year Plan Receives Enthusiastic Discussion",
                    body: "Floor debate on the economic plan continues with delegates from industrial regions reporting on fulfillment of previous targets. Agricultural representatives praised collectivization achievements. The Minister of Planning assured delegates that socialist construction proceeds on schedule despite temporary difficulties.",
                    category: .political
                ),
                HeadlineStory(
                    headline: "CONGRESS EXAMINES BUDGET PRIORITIES",
                    subheadline: "Investment in Heavy Industry Emphasized",
                    body: "Delegates engaged in constructive discussion of budget allocations, with particular attention to capital investment in strategic industries. Defense spending maintains its necessary level. Social expenditure on education and healthcare continues the Party's commitment to the working masses.",
                    category: .political
                )
            ]
            return headlines.randomElement() ?? headlines[0]
        }

        let generalHeadlines = [
            HeadlineStory(
                headline: "LIVELY DEBATE MARKS CONGRESS SESSION",
                subheadline: "Delegates Voice United Support with Local Concerns",
                body: "The People's Congress witnessed spirited exchanges as delegates balanced expressions of full support for Party policy with voicing concerns from their constituencies. A delegate from the agricultural provinces called for additional tractors. Another requested expanded educational facilities. All spoke within the framework of socialist construction.",
                category: .political
            ),
            HeadlineStory(
                headline: "WORKERS' VOICES HEARD IN GREAT HALL",
                subheadline: "Delegate Speeches Reflect Laboring Masses",
                body: "Moving speeches from worker-delegates highlighted the Congress session today. A steel worker from the Donbass region described improvements in working conditions. A textile worker praised new factory canteens. Each testimony demonstrated the Party's close connection to the masses it serves.",
                category: .political
            ),
            HeadlineStory(
                headline: "DELEGATES REAFFIRM REVOLUTIONARY COMMITMENT",
                subheadline: "Session Marked by Expressions of Unity",
                body: "Today's Congress proceedings featured powerful affirmations of socialist principles. Delegates from minority nationalities praised the Party's nationality policy. Youth representatives pledged to carry forward the revolutionary banner. The session demonstrated the unbreakable bond between Party and people.",
                category: .political
            ),
            HeadlineStory(
                headline: "CENTRAL COMMITTEE REPORT DRAWS PROLONGED APPLAUSE",
                subheadline: "Delegates Endorse Party's Correct Line",
                body: "The General Secretary's report on the Central Committee's work received extended standing ovation. Delegates rose repeatedly to applaud key passages addressing socialist construction and international solidarity. Discussion confirmed universal support for the Party's wise policies.",
                category: .political
            )
        ]
        return generalHeadlines.randomElement() ?? generalHeadlines[0]
    }

    private func generateCongressVotingHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        let delegateCount = session.delegatesPresent

        let headlines = [
            HeadlineStory(
                headline: "CONGRESS PROCEEDS TO FINAL VOTES",
                subheadline: "Delegates Prepare to Ratify Historic Decisions",
                body: "As the People's Congress enters its concluding phase, delegates have begun casting votes on the measures debated during the session. The atmosphere in the Great Hall reflects the solemnity of the moment. Each raised hand represents millions of citizens whose will the delegates embody.",
                category: .political
            ),
            HeadlineStory(
                headline: "VOTING UNDERWAY IN PEOPLE'S CONGRESS",
                subheadline: "\(delegateCount) Delegates Exercise Constitutional Power",
                body: "The constitutional process of voting has commenced in the Great Hall. Delegates vote by raising hands or, for certain measures, by written ballot. Tellers count with meticulous care, though the overwhelming support for Party policies is already evident from floor speeches.",
                category: .political
            ),
            HeadlineStory(
                headline: "DELEGATES CAST BALLOTS ON STATE BUDGET",
                subheadline: "Economic Plan Set for Formal Adoption",
                body: "In the most significant vote of the session, delegates are casting ballots on the state budget and economic development plan. The vote represents the formal expression of the people's will, channeled through their elected representatives in this supreme organ of state power.",
                category: .political
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    private func generateCongressConclusionHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        // Congress is a ceremonial broadcast — no vote tallies, no "unanimous"
        // counts. Surface a small rotation of propaganda-press conclusions
        // varied by session number.
        let headlines: [HeadlineStory] = [
            HeadlineStory(
                headline: session.conclusionHeadline,
                subheadline: "Delegates Depart in Spirit of Revolutionary Unity",
                body: "The \(session.sessionNumber.ordinalString) session of the People's Congress has concluded. The Report of the Central Committee was read into the record and received with sustained applause. Delegates return to their provinces to carry word of the session.",
                category: .political
            ),
            HeadlineStory(
                headline: "PEOPLE'S CONGRESS ADJOURNS",
                subheadline: "Proceedings Filed Into the Politburo Archives",
                body: "The People's Congress has adjourned its ceremonial session. The proceedings were broadcast in full and have been entered into the Politburo archives. The Chairman's closing address was interrupted repeatedly by ovations.",
                category: .political
            ),
            HeadlineStory(
                headline: "GREAT HALL DARKENS AS CONGRESS CLOSES",
                subheadline: "Delegates Carry the Party Line to the Provinces",
                body: "The Great Hall of the People stands empty tonight after the close of the \(session.sessionNumber.ordinalString) Congress. The orchestra played the anthem. The newsreel cameras stopped. Delegates board trains for their provinces, the Party line in their luggage.",
                category: .political
            )
        ]
        return headlines[session.sessionNumber % headlines.count]
    }

    private func generateCongressScheduledHeadline(session: CongressSession, game: Game) -> HeadlineStory {
        let headlines = [
            HeadlineStory(
                headline: "PEOPLE'S CONGRESS SESSION ANNOUNCED",
                subheadline: "Delegates Selected from All Provinces",
                body: "The Standing Committee has announced that the People's Congress will convene in the coming period. Delegate selection has concluded in all provinces and autonomous regions. The session will address important questions of state including the national budget and economic planning.",
                category: .political
            ),
            HeadlineStory(
                headline: "PREPARATIONS UNDERWAY FOR CONGRESS",
                subheadline: "Great Hall Readied for Historic Gathering",
                body: "Workers are preparing the Great Hall of the People for the upcoming Congress session. Accommodation has been arranged for delegates from distant provinces. The Political Bureau has approved the draft agenda, which includes reports on socialist construction progress.",
                category: .political
            ),
            HeadlineStory(
                headline: "DELEGATES PREPARE FOR CONGRESS DUTIES",
                subheadline: "Representatives Study Session Materials",
                body: "Across the nation, People's Congress delegates are reviewing the materials prepared for the upcoming session. Many have convened meetings in their constituencies to gather the views of workers and peasants. The delegates carry with them the hopes and concerns of the masses.",
                category: .political
            )
        ]
        return headlines.randomElement() ?? headlines[0]
    }

    /// Helper to generate ordinal numbers
    private func ordinalNumber(_ n: Int) -> String {
        return n.ordinalString
    }

    // MARK: - Show Trial Headlines

    /// Generate headlines for show trials
    func generateTrialHeadline(trial: ShowTrial, game: Game) -> HeadlineStory {
        let defendant = game.characters.first { $0.id == trial.defendantId }
        let defendantName = defendant?.name ?? trial.defendantName
        let defendantTitle = defendant?.title ?? trial.defendantTitle ?? "former official"

        switch trial.phase {
        case .accusation:
            return HeadlineStory(
                headline: "ENEMY OF THE PEOPLE ARRESTED",
                subheadline: "\(defendantName) Charged with Crimes Against the State",
                body: "\(defendantName), \(defendantTitle), has been arrested on serious charges including counter-revolutionary activity, wrecking, and conspiracy with foreign powers. State Security sources indicate overwhelming evidence of treasonous conduct. A public trial will demonstrate the vigilance of socialist justice.",
                category: .political
            )

        case .confessionExtraction:
            return HeadlineStory(
                headline: "INVESTIGATIONS CONTINUE",
                subheadline: "Further Evidence of Conspiracy Uncovered",
                body: "Ongoing investigations into the criminal activities of \(defendantName) have revealed a wider network of saboteurs and wreckers. Authorities report that the defendant is cooperating with investigators. Additional arrests are expected.",
                category: .political
            )

        case .publicTrial:
            return HeadlineStory(
                headline: "PUBLIC TRIAL OF \(defendantName.uppercased()) BEGINS",
                subheadline: "Defendant Confesses to Monstrous Crimes",
                body: "In a packed courtroom, the trial of \(defendantName) has commenced. The defendant has confessed to sabotaging industrial production, passing secrets to foreign powers, and plotting to overthrow socialist order. Workers across the nation demand the maximum penalty.",
                category: .political
            )

        case .sentencing:
            let sentenceText = trial.sentence?.displayName ?? "severe punishment"
            return HeadlineStory(
                headline: "JUSTICE SERVED: \(defendantName.uppercased()) SENTENCED",
                subheadline: "\(sentenceText) for Counter-Revolutionary Crimes",
                body: "The People's Court has delivered its verdict in the case of \(defendantName). The defendant has been sentenced to \(sentenceText) for crimes against the state. Workers across the nation express satisfaction that socialist justice has prevailed.",
                category: .political
            )

        case .completed:
            return HeadlineStory(
                headline: "VIGILANCE AGAINST ENEMIES VINDICATED",
                subheadline: "Trial Concludes with Lessons for All",
                body: "The conclusion of the \(defendantName) trial demonstrates the Party's eternal vigilance against enemies of the people. All citizens are reminded that betrayal of socialist principles will not be tolerated. The Revolution protects its own.",
                category: .political
            )
        }
    }

    // MARK: - Corruption Investigation Headlines

    /// Generate headlines for corruption investigations
    func generateCorruptionHeadline(targetName: String, phase: String, game: Game) -> HeadlineStory {
        switch phase {
        case "initiated":
            return HeadlineStory(
                headline: "ANTI-CORRUPTION CAMPAIGN INTENSIFIES",
                subheadline: "Party Discipline Commission Launches Investigation",
                body: "The Central Discipline Inspectorate has initiated inquiries into reports of economic irregularities within certain ministries. The Party reaffirms its commitment to maintaining socialist morality among cadres at all levels.",
                category: .political
            )
        case "detention":
            return HeadlineStory(
                headline: "OFFICIAL ASSISTS WITH INQUIRIES",
                subheadline: "\(targetName) Cooperates with Party Organs",
                body: "\(targetName) is currently assisting Party control organs with inquiries into administrative matters. The investigation reflects the Party's unwavering commitment to clean governance and socialist ethics.",
                category: .political
            )
        case "outcome_cleared":
            return HeadlineStory(
                headline: "INVESTIGATION CONCLUDES",
                subheadline: "\(targetName) Returns to Duties",
                body: "Following thorough investigation, \(targetName) has been cleared of suspicion and restored to responsibilities. The Party's careful examination of all matters demonstrates its commitment to fairness and socialist legality.",
                category: .political
            )
        case "outcome_expelled":
            return HeadlineStory(
                headline: "CORRUPTION EXPOSED AND PUNISHED",
                subheadline: "\(targetName) Expelled from Party",
                body: "The Central Discipline Inspectorate has announced the expulsion of \(targetName) following confirmation of serious disciplinary violations. The decisive action demonstrates the Party's zero tolerance for corruption.",
                category: .political
            )
        default:
            return HeadlineStory(
                headline: "PARTY DISCIPLINE STRENGTHENED",
                subheadline: "Anti-Corruption Efforts Continue",
                body: "The Party's ongoing campaign against corruption and bureaucratism continues to yield results. Officials at all levels are reminded of their duty to maintain revolutionary purity.",
                category: .political
            )
        }
    }

    // MARK: - Assassination/Death Headlines

    /// Generate headlines for significant deaths
    func generateDeathHeadline(character: GameCharacter, cause: DeathCause, game: Game) -> HeadlineStory {
        let name = character.name
        let title = character.title ?? "official"

        switch cause {
        case .naturalCauses, .illness:
            return HeadlineStory(
                headline: "THE PARTY MOURNS \(name.uppercased())",
                subheadline: "Comrade \(name) Succumbs to Illness",
                body: "It is with profound sorrow that we announce the passing of \(name), beloved \(title), after a long struggle with illness. Memorial services will be held at the Palace of Culture. The Party extends condolences to the family.",
                category: .political
            )
        case .executed, .executionByMilitary:
            return HeadlineStory(
                headline: "JUSTICE CARRIED OUT",
                subheadline: "Sentence Against \(name) Executed",
                body: "The sentence against the criminal \(name), former \(title), has been carried out. The execution of this enemy of the people closes a shameful chapter. Let all enemies of socialism take note.",
                category: .political
            )
        case .executionByPurge, .purged:
            return HeadlineStory(
                headline: "ENEMY ELIMINATED",
                subheadline: "Justice for \(name)'s Crimes",
                body: "The criminal career of \(name), unmasked as an enemy of the people, has been brought to its deserved end. Let this serve as a warning to all who would betray the Revolution.",
                category: .political
            )
        case .disappeared:
            return HeadlineStory(
                headline: "NOTICE: \(name.uppercased())",
                subheadline: "Former Official No Longer in Position",
                body: "\(name), former \(title), is no longer employed by the ministry. Inquiries regarding this matter should be directed to the appropriate authorities.",
                category: .political
            )
        case .arrested:
            return HeadlineStory(
                headline: "OFFICIAL DETAINED",
                subheadline: "\(name) Assisting with Inquiries",
                body: "\(name), \(title), has been detained pending investigation into certain matters. The Party's commitment to discipline and accountability remains absolute.",
                category: .political
            )
        case .exiled:
            return HeadlineStory(
                headline: "COUNTER-REVOLUTIONARY EXILED",
                subheadline: "\(name) Banished for Crimes",
                body: "Following trial, \(name) has been sentenced to internal exile for crimes against the socialist state. The lenient sentence reflects the Party's faith in rehabilitation through labor.",
                category: .political
            )
        case .accident, .carAccident:
            return HeadlineStory(
                headline: "TRAGIC ACCIDENT",
                subheadline: "\(name) Dies in Mishap",
                body: "We regret to announce the accidental death of \(name), \(title), in a vehicular accident. The Party extends condolences and has ordered a safety review.",
                category: .political
            )
        case .planeAccident:
            return HeadlineStory(
                headline: "AVIATION TRAGEDY",
                subheadline: "\(name) Perishes in Air Crash",
                body: "We mourn the loss of \(name), \(title), who died when their aircraft went down. An investigation has been ordered.",
                category: .political
            )
        case .heartAttack:
            return HeadlineStory(
                headline: "SUDDEN PASSING",
                subheadline: "\(name) Suffers Fatal Cardiac Event",
                body: "The Party mourns the sudden death of \(name), \(title), who suffered a heart attack. Our thoughts are with the family.",
                category: .political
            )
        case .suicide:
            return HeadlineStory(
                headline: "TRAGIC END",
                subheadline: "\(name) Found Dead",
                body: "Authorities report that \(name), \(title), has been found dead. The investigation has concluded. No foul play is suspected.",
                category: .political
            )
        case .fallingAccident:
            return HeadlineStory(
                headline: "FATAL ACCIDENT",
                subheadline: "\(name) Dies in Fall",
                body: "\(name), \(title), has died following an accidental fall. The incident is under investigation.",
                category: .political
            )
        case .resistingArrest:
            return HeadlineStory(
                headline: "CRIMINAL DIES RESISTING ARREST",
                subheadline: "\(name) Shot During Detention",
                body: "Security forces report that \(name), under investigation for crimes against the state, was shot while resisting lawful arrest. The use of force has been deemed justified.",
                category: .political
            )
        }
    }

    // MARK: - NPC Diplomatic Action Headlines

    /// Generate headlines for NPC diplomatic decisions (Foreign Affairs track officials)
    func generateDiplomaticActionHeadline(
        character: GameCharacter,
        actionType: NPCDiplomaticActionType,
        targetCountry: ForeignCountry?,
        game: Game
    ) -> HeadlineStory {
        let officialName = character.name
        let officialTitle = character.title ?? "Foreign Affairs Official"
        let countryName = targetCountry?.name ?? "foreign nation"

        switch actionType {
        case .proposedTreaty:
            return HeadlineStory(
                headline: "TREATY NEGOTIATIONS ADVANCE",
                subheadline: "\(officialTitle) \(officialName) Leads Diplomatic Efforts",
                body: "Under the direction of \(officialName), the Foreign Ministry has initiated formal treaty discussions with \(countryName). The negotiations reflect the Party's commitment to peaceful coexistence and international socialist solidarity.",
                category: .international
            )

        case .conductedNegotiations:
            return HeadlineStory(
                headline: "DIPLOMATIC TALKS WITH \(countryName.uppercased()) CONTINUE",
                subheadline: "Foreign Ministry Reports Progress",
                body: "\(officialName), \(officialTitle), reports productive discussions with \(countryName) representatives. The talks addressed matters of mutual interest in accordance with socialist principles of international relations.",
                category: .international
            )

        case .strengthenedAlliance:
            return HeadlineStory(
                headline: "SOCIALIST BLOC UNITY STRENGTHENED",
                subheadline: "\(officialName) Leads Fraternal Consultations",
                body: "Consultations led by \(officialName) have resulted in strengthened ties with \(countryName). The deepening cooperation demonstrates the unbreakable bonds between socialist nations in the face of imperialist pressure.",
                category: .international
            )

        case .counteredWesternInfluence:
            return HeadlineStory(
                headline: "IMPERIALIST PLOTS THWARTED",
                subheadline: "Foreign Ministry Vigilance Protects National Interests",
                body: "Through decisive action by \(officialName) and the Foreign Ministry, attempts by Western powers to extend influence in \(countryName) have been successfully countered. Socialist diplomacy proves superior to bourgeois intrigue.",
                category: .international
            )

        case .expandedTrade:
            return HeadlineStory(
                headline: "TRADE RELATIONS WITH \(countryName.uppercased()) EXPAND",
                subheadline: "Economic Cooperation Strengthens",
                body: "New trade arrangements negotiated by \(officialName) will enhance economic cooperation with \(countryName). The agreement demonstrates the advantages of socialist economic planning.",
                category: .economic
            )

        case .defusedCrisis:
            return HeadlineStory(
                headline: "DIPLOMATIC CRISIS AVERTED",
                subheadline: "\(officialName) Leads Successful De-escalation",
                body: "Through skillful diplomacy, \(officialName) has successfully defused tensions with \(countryName). The peaceful resolution demonstrates the effectiveness of socialist foreign policy in contrast to imperialist warmongering.",
                category: .international
            )

        case .conductedEspionage:
            // Espionage successes are classified - generic headline
            return HeadlineStory(
                headline: "FOREIGN MINISTRY ACTIVITIES",
                subheadline: "Normal Diplomatic Operations Continue",
                body: "The Foreign Ministry reports normal operations in all diplomatic missions. The dedication of our foreign service cadres ensures the protection of national interests abroad.",
                category: .international
            )

        case .proposedPolicyChange:
            return HeadlineStory(
                headline: "FOREIGN POLICY DISCUSSIONS",
                subheadline: "Standing Committee Considers New Approaches",
                body: "\(officialName), \(officialTitle), has submitted recommendations for consideration by Party leadership. The proposal reflects ongoing efforts to optimize socialist foreign policy in the current international situation.",
                category: .political
            )

        case .respondedToCrisis:
            return HeadlineStory(
                headline: "FIRM RESPONSE TO INTERNATIONAL INCIDENT",
                subheadline: "Foreign Ministry Issues Strong Statement",
                body: "In response to recent provocations, \(officialName) has directed an appropriate response through diplomatic channels. The Socialist Republic will not be intimidated by aggressive actions from hostile powers.",
                category: .international
            )
        }
    }

    /// Generate secondary stories from NPC diplomatic activities
    func generateDiplomaticSecondaryStory(
        character: GameCharacter,
        actionType: NPCDiplomaticActionType,
        targetCountry: ForeignCountry?,
        game: Game
    ) -> NewspaperStory {
        let officialName = character.name
        let countryName = targetCountry?.name ?? "various nations"

        switch actionType {
        case .proposedTreaty, .conductedNegotiations:
            return NewspaperStory(
                headline: "Foreign Ministry Delegation Returns",
                brief: "\(officialName) returns from \(countryName) following diplomatic discussions.",
                importance: 2
            )

        case .strengthenedAlliance:
            return NewspaperStory(
                headline: "Socialist Solidarity Affirmed",
                brief: "Meetings with \(countryName) representatives strengthen fraternal bonds.",
                importance: 2
            )

        case .expandedTrade:
            return NewspaperStory(
                headline: "Trade Delegation Success",
                brief: "Economic negotiations with \(countryName) yield positive results.",
                importance: 2
            )

        case .defusedCrisis, .respondedToCrisis:
            return NewspaperStory(
                headline: "Diplomatic Resolution Achieved",
                brief: "Tensions with \(countryName) addressed through proper channels.",
                importance: 3
            )

        default:
            return NewspaperStory(
                headline: "Foreign Affairs Activity",
                brief: "The Foreign Ministry reports normal diplomatic operations.",
                importance: 1
            )
        }
    }

    // MARK: - Helpers

    private func formatDate(for turnNumber: Int) -> String {
        RevolutionaryCalendar.formatTurnFull(turnNumber)
    }

    /// Live world tension stat (0-100, clamped by Game.applyStat)
    private func worldTensionValue(for game: Game) -> Int {
        game.worldTension
    }

    /// Parse recent diplomatic action flags into structured tuples.
    /// Flag format: `diplomatic_action_{actionType}_{countryId}_{turnNumber}`
    private func recentDiplomaticActions(
        for game: Game,
        turnsBack: Int
    ) -> [(action: DiplomaticActionType, countryId: String, turn: Int)] {
        let minTurn = game.turnNumber - turnsBack
        return game.flags.compactMap { flag in
            guard flag.hasPrefix("diplomatic_action_") else { return nil }
            let stripped = String(flag.dropFirst("diplomatic_action_".count))
            let parts = stripped.split(separator: "_")
            guard parts.count >= 3,
                  let turn = Int(String(parts.last!)),
                  turn >= minTurn else { return nil }

            // First segment is actionType (camelCase, no underscores); rest minus last is countryId
            let actionRaw = String(parts.first!)
            let countryId = parts.dropFirst().dropLast().joined(separator: "_")
            guard let action = DiplomaticActionType(rawValue: actionRaw) else { return nil }
            return (action, countryId, turn)
        }
    }

    private static let hostileActionTypes: Set<DiplomaticActionType> = [
        .economicSanctions, .militaryThreat, .recallAmbassador,
        .diplomaticProtest, .sabotage, .supportDissidents
    ]

    /// Returns a weighted random selection from `items`, or nil if the input is empty
    /// or has zero/negative total weight. Content-generation code must never crash
    /// the app — callers are expected to nil-coalesce to a sensible default.
    private func weightedRandomSelection<T>(from items: [(T, Int)]) -> T? {
        guard let fallback = items.first?.0 else {
            #if DEBUG
            print("[NewspaperGenerator] WARNING: weightedRandomSelection called with empty items array")
            #endif
            return nil
        }
        let totalWeight = items.reduce(0) { $0 + $1.1 }
        guard totalWeight > 0 else {
            #if DEBUG
            print("[NewspaperGenerator] WARNING: weightedRandomSelection called with zero total weight; returning first item")
            #endif
            return fallback
        }
        var random = Int.random(in: 0..<totalWeight)

        for (item, weight) in items {
            random -= weight
            if random < 0 {
                return item
            }
        }

        return fallback
    }
}

// MARK: - Int Extension for Ordinal Numbers

extension Int {
    var ordinalString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)th"
    }
}
