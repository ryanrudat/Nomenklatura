//
//  ScenarioPromptBuilder.swift
//  Nomenklatura
//
//  Builds prompts for AI scenario generation based on game state
//

import Foundation

// MARK: - Scenario Prompt Builder

struct ScenarioPromptBuilder {

    /// Build a complete prompt for scenario generation with specified category
    static func buildPrompt(for game: Game, config: CampaignConfig, category: ScenarioCategory? = nil) -> String {
        let selectedCategory = category ?? selectCategoryForPrompt(game: game)

        return """
        You are a narrative designer for a political simulation game set in the People's Socialist Republic of America (PSRA), an alternate history where America became socialist after a Second American Civil War (1936-1940). The capital is Washington D.C. Generate a scenario briefing that the player must respond to.

        SETTING: Early 1950s, about 10-15 years after the Revolution. Herbert Hoover's failed policies during the Great Depression led to worker uprisings, a civil war, and Communist victory. The old Federal Government fled to Cuba.

        TERMINOLOGY: Use "the Party" for supreme authority, "the Republic" or "the PSRA" for the state, "the People's Congress" for the executive council, "the Bureau of People's Security (BPS)" for state security.

        KEY HISTORICAL EVENTS:
        - 1940: Revolutionary victory, PSRA established
        - 1940-1941: Soviet Union provided aid, received part of Alaska in return
        - 1941: Japan seized Hawaii during the chaos
        - 1941-1942: Britain and Canada intervened; PSRA seized BC + Alberta as "People's Federated Territory"
        - US Federal Government-in-Exile operates from Cuba

        DOMESTIC REGIONS (7 Zones):
        - Capital District (Washington D.C.) - seat of government
        - Northeast Industrial Zone - manufacturing heartland, revolution stronghold
        - Great Lakes Zone - heavy industry, auto workers
        - Pacific Zone - west coast, ports, includes seized Canadian territory
        - Southern Zone - former Confederate states, complex politics
        - Plains Zone - agricultural heartland, farming collectives
        - Mountain Zone - mining, resource extraction

        \(buildContextSection(game: game, config: config))

        \(buildRegionsSection(game: game))

        \(buildInternationalSection(game: game))

        \(buildLawsSection(game: game))

        \(buildRecentHistorySection(game: game))

        \(buildCharacterSection(game: game))

        \(buildOngoingProjectsSection(game: game))

        \(buildCategoryRequirement(category: selectedCategory, game: game))

        \(buildInstructions(excludingVariety: true))

        \(buildOutputFormat(category: selectedCategory))
        """
    }

    /// Select category based on game state and pacing (mirrors ScenarioManager logic)
    private static func selectCategoryForPrompt(game: Game) -> ScenarioCategory {
        // Force non-decision event after consecutive decisions for pacing
        if game.consecutiveDecisionEvents >= 2 {
            return selectNonDecisionCategory()
        }

        // Check for newspaper chance
        if game.turnNumber > game.lastNewspaperTurn + 1 {
            let newspaperChance = calculateNewspaperChance(for: game)
            if Double.random(in: 0...1) < newspaperChance {
                return .newspaper
            }
        }

        // Build weighted selection
        let recentCategories = game.recentScenarioCategories.compactMap {
            ScenarioCategory(rawValue: $0)
        }

        var weights: [ScenarioCategory: Int] = [:]

        // Only consider decision-requiring categories appropriate for player's position
        let decisionCategories: [ScenarioCategory] = [.crisis, .routine, .opportunity, .character]
            .filter { $0.isAppropriate(forPositionIndex: game.currentPositionIndex) }

        for category in decisionCategories {
            var weight = category.selectionWeight

            // Heavier penalty for recent usage - 20 points per recent occurrence
            let recentCount = recentCategories.filter { $0 == category }.count
            weight = max(3, weight - (recentCount * 20))

            // Extra penalty if this was the most recent category
            if recentCategories.last == category {
                weight = max(3, weight - 15)
            }

            weights[category] = weight
        }

        // Weighted random selection
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return .routine }

        var random = Int.random(in: 0..<totalWeight)

        for (category, weight) in weights.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            random -= weight
            if random < 0 {
                return category
            }
        }

        return .routine
    }

    private static func selectNonDecisionCategory() -> ScenarioCategory {
        let choices: [(ScenarioCategory, Int)] = [
            (.routineDay, 40),
            (.characterMoment, 35),
            (.tensionBuilder, 25)
        ]

        let totalWeight = choices.reduce(0) { $0 + $1.1 }
        var random = Int.random(in: 0..<totalWeight)

        for (category, weight) in choices {
            random -= weight
            if random < 0 {
                return category
            }
        }

        return .routineDay
    }

    private static func calculateNewspaperChance(for game: Game) -> Double {
        var chance = 0.25

        // Boost after major events
        let recentMajorEvents = game.events.filter {
            $0.turnNumber >= game.turnNumber - 2 &&
            ($0.eventType == "death" || $0.eventType == "purge" || $0.importance >= 8)
        }

        if !recentMajorEvents.isEmpty {
            chance += 0.30
        }

        // Boost if it's been a while
        let turnsSinceNewspaper = game.turnNumber - game.lastNewspaperTurn
        if turnsSinceNewspaper > 5 {
            chance += 0.15
        }

        return min(chance, 0.60)
    }

    private static func buildCategoryRequirement(category: ScenarioCategory, game: Game) -> String {
        switch category {
        case .crisis:
            return """
            ## REQUIRED SCENARIO TYPE: CRISIS

            You MUST generate a CRISIS scenario - an urgent problem demanding immediate attention.
            This should feel like an emergency: protests, shortages, military incidents, factional struggles.
            The stakes are high and the player must act decisively.

            DO NOT generate a routine governance scenario or opportunity.
            """

        case .routine:
            return """
            ## REQUIRED SCENARIO TYPE: ROUTINE GOVERNANCE

            You MUST generate a ROUTINE scenario - normal governance decisions with moderate stakes.
            This should feel like the everyday business of ruling: budget allocations, appointments,
            cultural matters, protocol decisions. Important but not urgent.

            DO NOT generate a crisis or emergency scenario. The tone should be bureaucratic, not alarming.
            """

        case .opportunity:
            return """
            ## REQUIRED SCENARIO TYPE: OPPORTUNITY

            You MUST generate an OPPORTUNITY scenario - a chance for the player to advance their position.
            This should feel like a door opening: a delegation to lead, a vacancy to fill,
            information to exploit, a project to champion.

            DO NOT generate a crisis. The tone should be hopeful/ambitious, not alarming.
            """

        case .character:
            return """
            ## REQUIRED SCENARIO TYPE: CHARACTER-DRIVEN

            You MUST generate a CHARACTER scenario focused on the player's key relationships.
            This should involve the patron, rival, or other named characters from the game state.
            Personal stakes, relationship tests, old friends in trouble, rival approaches.

            Use the character information provided to make this feel personal and relationship-focused.
            """

        case .routineDay:
            return """
            ## REQUIRED SCENARIO TYPE: ROUTINE DAY (NO DECISION)

            You MUST generate a ROUTINE DAY scenario - atmospheric text with NO player choices.
            This is a mundane day: signing paperwork, attending boring meetings, waiting for appointments.
            The player simply experiences it and moves on. NO options array - just briefing and conclusion.
            """

        case .characterMoment:
            return """
            ## REQUIRED SCENARIO TYPE: CHARACTER MOMENT (NO DECISION)

            You MUST generate a brief CHARACTER MOMENT - a small interaction with no decision required.
            A nod in the hallway, overheard whispers, a glance from a patron or rival.
            Atmospheric and relationship-building but NO player choices. NO options array.
            """

        case .tensionBuilder:
            return """
            ## REQUIRED SCENARIO TYPE: TENSION BUILDER (NO DECISION)

            You MUST generate a TENSION BUILDER - foreshadowing of trouble to come.
            Security asking questions, a patron growing distant, rivals meeting secretly,
            empty desks where colleagues used to sit. Ominous but NO player choices. NO options array.
            """

        case .newspaper:
            return """
            ## REQUIRED SCENARIO TYPE: NEWSPAPER

            Generate a newspaper placeholder. The actual content will be generated separately.
            """

        case .introduction:
            return """
            ## REQUIRED SCENARIO TYPE: INTRODUCTION

            This is a special Turn 1 scenario. Generate an introduction to the player's new position.
            """
        }
    }

    // MARK: - Prompt Sections

    private static func buildContextSection(game: Game, config: CampaignConfig) -> String {
        let positionTitle = config.ladder[safe: game.currentPositionIndex]?.title ?? "Official"
        let positionScope = getPositionScopeGuidance(forIndex: game.currentPositionIndex)
        let currentDate = RevolutionaryCalendar.formatTurnFull(game.turnNumber)

        return """
        ## CURRENT GAME STATE

        **Turn:** \(game.turnNumber) — Each turn represents 2 weeks (a fortnight)
        **Current Date:** \(currentDate)
        **Player Position:** \(positionTitle) (Level \(game.currentPositionIndex) of 8)

        **TIME PACING:** Since each turn = 2 weeks, things that would take time in reality should take multiple turns:
        - Small administrative tasks: same turn
        - Minor construction/repairs: 2-3 turns (4-6 weeks)
        - Major construction projects: 4-8 turns (2-4 months)
        - Large infrastructure: 10-20+ turns (5-10 months)
        - Political changes: gradual over multiple turns
        When creating scenarios about ongoing projects, reference realistic timeframes.

        \(positionScope)

        **National Statistics:**
        - Stability: \(game.stability)/100 \(statWarning(game.stability))
        - Popular Support: \(game.popularSupport)/100 \(statWarning(game.popularSupport))
        - Military Loyalty: \(game.militaryLoyalty)/100 \(statWarning(game.militaryLoyalty))
        - Party Loyalty: \(game.eliteLoyalty)/100 \(statWarning(game.eliteLoyalty))
        - Treasury: \(game.treasury)/100 \(statWarning(game.treasury))
        - Industrial Output: \(game.industrialOutput)/100 \(statWarning(game.industrialOutput))
        - Food Supply: \(game.foodSupply)/100 \(statWarning(game.foodSupply))
        - International Standing: \(game.internationalStanding)/100 \(statWarning(game.internationalStanding))

        **Player's Personal Stats:**
        - Standing: \(game.standing)/100 (political capital and reputation)
        - Patron Favor: \(game.patronFavor)/100 (relationship with your political protector)
        - Rival Threat: \(game.rivalThreat)/100 (danger from your political enemy)
        - Network: \(game.network)/100 (your web of contacts and informants)

        **Critical Concerns:** \(identifyCriticalStats(game: game))
        """
    }

    /// Get position-appropriate scope guidance for AI
    private static func getPositionScopeGuidance(forIndex index: Int) -> String {
        switch index {
        case 0:
            return """
            **Position Scope:** ENTRY LEVEL - You are a minor Party official. Your decisions involve:
            - Paperwork and administrative duties within your small office
            - Managing relationships with immediate colleagues and superiors
            - Navigating petty office politics and bureaucratic procedures
            - Proving yourself worthy of notice from those above you
            DO NOT give this player national policy decisions or access to senior leadership.
            """
        case 1:
            return """
            **Position Scope:** JUNIOR PRESIDIUM - You are beginning to be noticed. Your decisions involve:
            - Local governance issues affecting your district or department
            - Building relationships with mid-level officials
            - Handling small crises that reach your desk before escalating
            - Seeking favor from potential patrons
            DO NOT give this player major national crises or direct access to top leadership.
            """
        case 2...3:
            return """
            **Position Scope:** RISING OFFICIAL - You have real responsibility now. Your decisions involve:
            - Regional or departmental matters with meaningful consequences
            - Interactions with other officials at similar levels
            - Managing subordinates and reporting to superiors
            - Factional politics within your sphere of influence
            Events should reflect growing but still limited power and visibility.
            """
        case 4...5:
            return """
            **Position Scope:** SENIOR OFFICIAL - You are a person of consequence. Your decisions involve:
            - Matters affecting entire ministries or large regions
            - Direct interaction with Politburo members and department heads
            - Major personnel decisions and policy implementation
            - Serious factional maneuvering with national implications
            Events should reflect significant power but still subordinate to the top leadership.
            """
        case 6...7:
            return """
            **Position Scope:** TOP LEADERSHIP - You are among the most powerful. Your decisions involve:
            - National policy with consequences for millions
            - Direct dealings with the General Secretary and Standing Committee
            - Major crises that threaten or reshape the state
            - Succession politics and existential factional struggles
            Events should reflect near-absolute power and the weight of leadership.
            """
        case 8:
            return """
            **Position Scope:** GENERAL SECRETARY - You ARE the state. Your decisions involve:
            - Absolute authority over national policy
            - Managing the loyalty of your subordinates
            - Foreign relations and superpower politics
            - Your own succession and legacy
            Events should reflect supreme power and its isolating burdens.
            """
        default:
            return "**Position Scope:** Generate decisions appropriate for a mid-level official."
        }
    }

    private static func buildRecentHistorySection(game: Game) -> String {
        // Build tiered memory context
        var section = ""

        // TIER 1: Story summary (persistent narrative arc)
        if !game.storySummary.isEmpty && game.storySummary != "A new official begins their career in the Party apparatus." {
            section += """
            ## STORY SO FAR
            \(game.storySummary)

            """
        }

        // TIER 2: Active plot threads
        let activeThreads = game.getActivePlotThreads()
        if !activeThreads.isEmpty {
            section += """
            ## ACTIVE STORYLINES
            These are ongoing plot threads that you SHOULD continue or reference:
            \(activeThreads.map { "- **\($0.title)** (Turn \($0.turnIntroduced)): \($0.summary)" }.joined(separator: "\n"))

            """
        }

        // TIER 3: Recent events - trimmed for speed (last 3 turns, max 3 events)
        let detailedEvents = game.events
            .filter { $0.importance >= 5 && $0.turnNumber >= game.turnNumber - 3 }
            .sorted { $0.turnNumber > $1.turnNumber }
            .prefix(3)

        if !detailedEvents.isEmpty {
            section += "## RECENT EVENTS\n"
            for event in detailedEvents {
                var eventDesc = "- Turn \(event.turnNumber): \(event.summary)"

                // Only add choice, skip verbose context
                if let choice = event.optionChosen {
                    eventDesc += " (Choice: \(choice))"
                }

                section += eventDesc + "\n"
            }
            section += "\n"
        }

        // TIER 4: Older important events - only top 3
        let olderEvents = game.events
            .filter { $0.importance >= 8 && $0.turnNumber < game.turnNumber - 3 }
            .sorted { $0.turnNumber > $1.turnNumber }
            .prefix(3)

        if !olderEvents.isEmpty {
            section += """
            ## KEY PAST EVENTS (Older)
            \(olderEvents.map { "- Turn \($0.turnNumber): \($0.summary)" }.joined(separator: "\n"))

            """
        }

        // TIER 5: Key narrative moments
        if !game.keyNarrativeMoments.isEmpty {
            section += """
            ## PIVOTAL MOMENTS
            These story beats define this playthrough:
            \(game.keyNarrativeMoments.map { "- \($0)" }.joined(separator: "\n"))

            """
        }

        // If we have nothing, show early game message
        if section.isEmpty {
            return """
            ## RECENT HISTORY
            The player is just beginning their political career. No major events have occurred yet.
            """
        }

        return section
    }

    private static func buildCharacterSection(game: Game) -> String {
        let activeCharacters = game.characters.filter { $0.isAlive }

        let patron = activeCharacters.first { $0.isPatron }
        let rival = activeCharacters.first { $0.isRival }
        let others = activeCharacters.filter { !$0.isPatron && !$0.isRival }.prefix(3)

        var section = "## KEY CHARACTERS\n"

        if let patron = patron {
            section += """

            **Your Patron:** \(patron.name) (\(patron.title ?? "Unknown"))
            - Disposition toward you: \(patron.disposition)/100
            - Personality: \(describePersonality(patron))
            - Speech pattern: \(patron.speechPattern ?? "Formal")
            """
        }

        if let rival = rival {
            section += """

            **Your Rival:** \(rival.name) (\(rival.title ?? "Unknown"))
            - Disposition toward you: \(rival.disposition)/100
            - Personality: \(describePersonality(rival))
            - Speech pattern: \(rival.speechPattern ?? "Formal")
            """
        }

        for character in others {
            section += """

            **\(character.name)** (\(character.title ?? "Unknown"))
            - Role: \(character.currentRole.rawValue.capitalized)
            - Disposition: \(character.disposition)/100
            """
        }

        return section
    }

    // MARK: - Ongoing Projects Section

    private static func buildOngoingProjectsSection(game: Game) -> String {
        let activeProjects = game.activeProjects

        guard !activeProjects.isEmpty else {
            return ""  // No section if no projects
        }

        var section = """
        ## ONGOING PROJECTS

        These multi-turn projects are currently in progress. Reference them when relevant to scenarios.
        Projects completing soon may warrant follow-up scenarios.

        """

        for project in activeProjects {
            let remaining = project.turnsRemaining(currentTurn: game.turnNumber)
            let remainingDesc = project.remainingDescription(currentTurn: game.turnNumber)
            let progressPercent = project.currentProgress

            section += """
            **\(project.title)** [\(project.projectType.rawValue.capitalized)]
            - Status: \(project.status.rawValue) (\(progressPercent)% complete)
            - Time remaining: \(remainingDesc) (~\(remaining) turns)
            - Description: \(project.description)
            """

            if let responsible = project.responsibleCharacterName {
                section += "\n- Overseen by: \(responsible)"
            }

            // Show if completing soon
            if remaining <= 2 {
                section += "\n- **COMPLETING SOON** - Consider follow-up scenario about results"
            }

            section += "\n\n"
        }

        // Add guidance for AI
        section += """
        IMPORTANT: When generating scenarios, you may:
        1. Reference ongoing projects naturally in briefings
        2. Create scenarios about project progress/setbacks (especially if completing soon)
        3. Have characters mention projects they're involved with
        DO NOT mark projects as completed in scenarios - the game system handles that.
        """

        return section
    }

    // MARK: - Regions Section

    private static func buildRegionsSection(game: Game) -> String {
        guard !game.regions.isEmpty else {
            return """
            ## DOMESTIC REGIONS
            No regional data available.
            """
        }

        var section = """
        ## DOMESTIC REGIONS

        The PSRA comprises seven administrative zones. Current status:

        """

        // Sort regions by urgency (worst status first)
        let sortedRegions = game.regions.sorted { $0.status.severity > $1.status.severity }

        for region in sortedRegions {
            let statusEmoji = regionStatusEmoji(region.status)
            let typeDesc = RegionType(rawValue: region.regionType)?.displayName ?? "Unknown"

            section += """
            **\(region.name)** (\(typeDesc)) \(statusEmoji)
            - Status: \(region.status.displayName)
            - Party Control: \(region.partyControl)/100 \(statWarning(region.partyControl))
            - Popular Loyalty: \(region.popularLoyalty)/100 \(statWarning(region.popularLoyalty))
            - Military Presence: \(region.militaryPresence)/100
            """

            // Add secession warning if applicable
            if region.canSecede && region.secessionProgress > 20 {
                section += "\n- Secession Risk: \(region.secessionProgress)/100 [WARNING]"
            }

            // Add autonomy desire if significant
            if region.autonomyDesire > 40 {
                section += "\n- Autonomy Desire: \(region.autonomyDesire)/100"
            }

            // Add distinct culture note
            if region.hasDistinctCulture || region.hasDistinctLanguage {
                var cultural: [String] = []
                if region.hasDistinctCulture { cultural.append("distinct culture") }
                if region.hasDistinctLanguage { cultural.append("separate language") }
                section += "\n- Note: \(cultural.joined(separator: ", "))"
            }

            // Add governor info if present
            if let governor = region.governor {
                section += "\n- Governor loyalty to you: \(governor.loyaltyToPlayer)/100"
            }

            section += "\n\n"
        }

        // Add summary of regional concerns
        let troubledRegions = game.regions.filter { $0.status.severity >= 2 }
        if !troubledRegions.isEmpty {
            section += "**REGIONAL CONCERNS:** \(troubledRegions.map { $0.name }.joined(separator: ", ")) require attention.\n"
        }

        return section
    }

    private static func regionStatusEmoji(_ status: RegionStatus) -> String {
        switch status {
        case .stable: return ""
        case .unrest: return "[UNREST]"
        case .crisis: return "[CRISIS]"
        case .rebellion: return "[REBELLION]"
        case .seceding: return "[SECEDING]"
        case .seceded: return "[LOST]"
        case .martial: return "[MARTIAL LAW]"
        }
    }

    // MARK: - International Section

    private static func buildInternationalSection(game: Game) -> String {
        guard !game.foreignCountries.isEmpty else {
            return """
            ## INTERNATIONAL SITUATION
            No foreign relations data available.
            """
        }

        var section = """
        ## INTERNATIONAL SITUATION

        **FOREIGN NATIONS IN THIS ALTERNATE HISTORY:**

        SOCIALIST ALLIES:
        - Soviet Union: Revolutionary ally, helped the Second Revolution, received part of Alaska
        - Germany: German Socialist Republic (no Nazi takeover), ally to both USSR and PSRA

        CAPITALIST ADVERSARIES:
        - Cuba: Hosts the US Government-in-Exile, most hostile enemy
        - Canada: Lost BC + Alberta to PSRA, bitter revanchist enemy
        - United Kingdom: Empire still intact, leads capitalist opposition
        - France: Unstable, swings between left and right

        FASCIST POWERS:
        - Italy: Mussolini still in power, controls North Africa
        - Spain: Franco's fascist state, isolated

        PACIFIC POWERS:
        - Japan: Imperial Japan holding Hawaii, major strategic threat
        - China: Under Japanese occupation, potential future ally

        NEUTRAL NEIGHBOR:
        - Mexico: Oligarchy playing both sides, helped during revolution but won't commit

        Use these nations for international scenarios. Relations are dynamic based on player actions.

        """

        // Group by bloc
        let socialistAllies = game.foreignCountries.filter { $0.politicalBloc == .socialist }
        let capitalistEnemies = game.foreignCountries.filter { $0.politicalBloc == .capitalist }
        let nonAligned = game.foreignCountries.filter { $0.politicalBloc == .nonAligned }
        let rivals = game.foreignCountries.filter { $0.politicalBloc == .rival }

        // Socialist Bloc
        if !socialistAllies.isEmpty {
            section += "**SOCIALIST BLOC (Our Allies):**\n"
            for country in socialistAllies.sorted(by: { $0.relationshipScore > $1.relationshipScore }) {
                section += "- \(country.name): Relations \(country.relationshipScore)/100"
                if country.relationshipScore < 40 {
                    section += " [STRAINED]"
                }
                if country.diplomaticTension > 50 {
                    section += " (Tension: \(country.diplomaticTension))"
                }
                section += "\n"
            }
            section += "\n"
        }

        // Main Adversary - Cuba (Government-in-Exile) or UK
        if let cuba = capitalistEnemies.first(where: { $0.countryId == "cuba" }) {
            section += """
            **PRIMARY ADVERSARY (Government-in-Exile):**
            - Cuba: Relations \(cuba.relationshipScore)/100, Tension \(cuba.diplomaticTension)/100
              Hosts the "legitimate" US government. Existential threat to our legitimacy.

            """
        }

        // United Kingdom as major power
        if let uk = capitalistEnemies.first(where: { $0.countryId == "united_kingdom" }) {
            section += """
            **LEADING CAPITALIST POWER:**
            - United Kingdom: Relations \(uk.relationshipScore)/100, Tension \(uk.diplomaticTension)/100
              Nuclear power. Leads global opposition to American socialism.

            """
        }

        // Other Capitalist powers (abbreviated)
        let otherCapitalist = capitalistEnemies.filter { $0.countryId != "cuba" && $0.countryId != "united_kingdom" }
        if !otherCapitalist.isEmpty {
            section += "**OTHER WESTERN POWERS:** "
            section += otherCapitalist.map { "\($0.name) (\($0.relationshipScore))" }.joined(separator: ", ")
            section += "\n\n"
        }

        // Rival Socialist Powers - important for border tensions
        if !rivals.isEmpty {
            section += "**RIVAL SOCIALIST POWERS:**\n"
            for country in rivals {
                section += "- \(country.name): Relations \(country.relationshipScore)/100, Tension \(country.diplomaticTension)/100"
                if let borderingRegion = country.borderingRegionId {
                    section += " (borders our \(borderingRegion) region)"
                }
                section += "\n"
            }
            section += "\n"
        }

        // Non-Aligned (brief)
        if !nonAligned.isEmpty {
            let keyNonAligned = nonAligned.filter { $0.relationshipScore > 20 || $0.relationshipScore < -20 }
            if !keyNonAligned.isEmpty {
                section += "**KEY NON-ALIGNED NATIONS:** "
                section += keyNonAligned.map { "\($0.name) (\($0.relationshipScore))" }.joined(separator: ", ")
                section += "\n\n"
            }
        }

        // Active treaties
        let countriesWithTreaties = game.foreignCountries.filter { !$0.treaties.isEmpty }
        if !countriesWithTreaties.isEmpty {
            section += "**ACTIVE TREATIES:**\n"
            for country in countriesWithTreaties {
                for treaty in country.treaties {
                    section += "- \(treaty.type.displayName) with \(country.name)\n"
                }
            }
            section += "\n"
        }

        // Trade agreements
        let activeAgreements = game.tradeAgreements.filter { $0.agreementStatus == AgreementStatus.active.rawValue }
        if !activeAgreements.isEmpty {
            section += "**TRADE AGREEMENTS:**\n"
            for agreement in activeAgreements.prefix(5) {
                section += "- \(agreement.agreementType): \(agreement.partnerCountryName)\n"
            }
            section += "\n"
        }

        // International tensions/crises
        let highTensionCountries = game.foreignCountries.filter { $0.diplomaticTension > 70 }
        if !highTensionCountries.isEmpty {
            section += "**DIPLOMATIC HOTSPOTS:** "
            section += highTensionCountries.map { "\($0.name) (\($0.diplomaticTension) tension)" }.joined(separator: ", ")
            section += "\n"
        }

        return section
    }

    // MARK: - Laws Section

    private static func buildLawsSection(game: Game) -> String {
        guard !game.laws.isEmpty else {
            return """
            ## LAWS & POWER
            No law data available.
            """
        }

        var section = """
        ## LAWS & POWER CONSOLIDATION

        **Player's Power Score:** \(game.powerConsolidationScore)/100
        **Term Limits:** \(game.termLimitsAbolished ? "ABOLISHED" : "In effect (2 terms max)")
        **Laws Modified:** \(game.lawsModifiedCount)

        """

        // Show modified or noteworthy laws
        let modifiedLaws = game.laws.filter { $0.hasBeenModified }
        // Note: Critical laws (institutional/political) could be used for future analysis
        _ = game.laws.filter {
            $0.category == LawCategory.institutional.rawValue ||
            $0.category == LawCategory.political.rawValue
        }

        if !modifiedLaws.isEmpty {
            section += "**MODIFIED LAWS:**\n"
            for law in modifiedLaws {
                section += "- \(law.name): \(law.lawCurrentState.displayName)"
                if let turnEnacted = law.turnEnacted, turnEnacted > 0 {
                    section += " (changed turn \(turnEnacted))"
                }
                section += "\n"
            }
            section += "\n"
        }

        // Power thresholds
        section += """
        **POWER THRESHOLDS:**
        - Social laws: 40+ power
        - Economic laws: 50+ power
        - Political laws: 60+ power
        - Institutional laws: 80+ power
        - Abolish term limits: 85+ power

        """

        // Pending consequences
        let pendingConsequences = game.laws.flatMap { $0.pendingConsequences }
        if !pendingConsequences.isEmpty {
            section += "**BREWING CONSEQUENCES:** There are \(pendingConsequences.count) delayed effects from recent law changes that may trigger soon.\n"
        }

        return section
    }

    private static func buildInstructions(excludingVariety: Bool = false) -> String {
        var instructions = """
        ## INSTRUCTIONS

        Generate a scenario appropriate to the current game state. Consider:

        1. **Relevance:** The scenario should relate to current concerns (low stats, character relationships, recent events)

        2. **Stakes:** Match stakes to the player's position. Junior officials face different problems than senior leaders.
        """

        if !excludingVariety {
            instructions += """


        3. **Variety:** Include a mix of:
           - Crisis (urgent problems)
           - Routine governance (normal decisions)
           - Opportunities (chances for advancement)
           - Character-driven moments (relationship events)
        """
        }

        instructions += """


        4. **Options:** Provide exactly 3 options that represent different approaches:
           - One that favors stability/order (often harsh)
           - One that favors reform/compassion (often risky politically)
           - One that favors cunning/deflection (political maneuvering)

        5. **Tone:** Grim, bureaucratic, paranoid. Use American socialist state language: "Comrade," "the Party," "the Republic," "the People's Congress," "counter-revolutionary," "quota," "collective." Blend American cultural elements with Soviet-style governance.

        6. **BALANCE RULES - CRITICAL:**
           **Per-stat limits:**
           - National stats (stability, treasury, etc.): max ±\(BalanceConfig.maxNationalStatChange) per stat
           - Personal stats (standing, favor, etc.): max ±\(BalanceConfig.maxPersonalStatChange) per stat

           **Effect magnitude guide:**
           - Minor effect: \(BalanceConfig.minorEffectMin)-\(BalanceConfig.minorEffectMax) points
           - Moderate effect: \(BalanceConfig.moderateEffectMin)-\(BalanceConfig.moderateEffectMax) points
           - Major effect: \(BalanceConfig.majorEffectMin)-\(BalanceConfig.majorEffectMax) points

           **TRADE-OFF REQUIREMENT:** Every option MUST have meaningful trade-offs.
           - Total positive effects per option: max \(BalanceConfig.maxTotalPositiveEffects)
           - Total negative effects per option: max \(BalanceConfig.maxTotalNegativeEffects)
           - Net imbalance (positives minus negatives): max ±\(BalanceConfig.maxNetImbalance)
           - NO option should be a "pure win" or "pure loss"
           - Each approach should sacrifice something to gain something else

           **Example balanced option:**
           - Hardline: +8 stability, +6 patronFavor, -5 popularSupport, -4 eliteLoyalty (net +5)
           - Reform: +6 popularSupport, +4 internationalStanding, -5 patronFavor, -3 stability (net +2)
           - Pragmatic: +5 standing, +4 network, -3 patronFavor, -4 rivalThreat increase (net ~0)

        7. **Personal Effects:** Include effects on standing, patronFavor, rivalThreat, or network where appropriate. Remember: increasing rivalThreat is NEGATIVE for the player.

        8. **IMPORTANT - Theme Variety:** DO NOT generate generic factory scenarios. Instead, choose from these diverse themes:

           **REGIONAL THEMES (use region names from DOMESTIC REGIONS section):**
           - Regional unrest in Southern Zone, Plains Zone, or Pacific Zone
           - Secession movements in autonomous regions (especially Southern Zone)
           - Governor loyalty crises
           - Ethnic tensions in culturally distinct regions
           - Military deployments to troubled regions
           - Religious revival in Southern Zone
           - Labor disputes in Great Lakes industrial cities
           - Labor camps in Mountain Zone
           - Border tensions with Canada in Pacific Zone

           **INTERNATIONAL THEMES (use actual game nations):**
           - Diplomatic incidents with United Kingdom or Cuba (exiled US government)
           - Alliance strains with Soviet Union or Germany
           - Border tensions with Canada (lost BC+Alberta to us)
           - Trade negotiations with Mexico (neutral neighbor)
           - Espionage scandals involving British intelligence
           - Tensions with Japan (occupies Hawaii)
           - Nuclear tensions and arms control
           - Capitalist pressure from UK-led bloc
           - Liberation movements in Japanese-occupied China
           - Fascist threats from Italy or Spain
           - Hawaii recovery operations against Japan

           **POWER & LAW THEMES:**
           - Constitutional amendments
           - Term limit debates
           - Power consolidation moves
           - Elite coalitions forming against player
           - Law enforcement of new policies
           - Consequences of recent law changes

           **CLASSIC THEMES:**
           - Party congress maneuvering
           - Military leadership disputes
           - Secret police investigations
           - Cultural/artistic controversies
           - Scientific/academic disputes
           - Media/propaganda decisions
        """

        return instructions
    }

    private static func buildOutputFormat(category: ScenarioCategory? = nil) -> String {
        // Check if this is a non-decision category
        let isNonDecision = category?.requiresDecision == false

        if isNonDecision {
            return """
            ## OUTPUT FORMAT

            Respond with ONLY valid JSON in this exact format (no markdown, no explanation):

            {
              "templateId": "unique_scenario_id",
              "category": "\(category?.rawValue ?? "routineDay")",
              "format": "\(formatForCategory(category))",
              "briefing": "The atmospheric text describing the scene. 2-3 paragraphs.",
              "presenterName": "Character Name (or empty string if none)",
              "presenterTitle": "Their Title (or null if none)",
              "narrativeConclusion": "A brief concluding paragraph wrapping up the moment. 1-2 sentences.",
              "options": []
            }

            IMPORTANT: For non-decision scenarios, the options array MUST be empty [].
            """
        }

        return """
        ## OUTPUT FORMAT

        Respond with ONLY valid JSON in this exact format (no markdown, no explanation):

        {
          "templateId": "unique_scenario_id",
          "category": "\(category?.rawValue ?? "crisis")",
          "briefing": "The scenario briefing text in quotes, as dialogue from the presenter. 2-4 paragraphs.",
          "presenterName": "Character Name",
          "presenterTitle": "Their Title",
          "options": [
            {
              "id": "A",
              "archetype": "repress|reform|negotiate|deflect|delay|attack|appease",
              "shortDescription": "Brief description of what the player does (1 sentence)",
              "immediateOutcome": "What happens as a result (2-3 paragraphs of narrative)",
              "statEffects": {
                "statName": change_as_integer
              },
              "personalEffects": {
                "standing|patronFavor|rivalThreat|network": change_as_integer
              },
              "followUpHook": "Optional hint at future consequences (1 sentence or null)"
            }
          ],
          "narrativeSummary": "A 1-2 sentence summary of this scenario for future AI reference. What happened and why it matters.",
          "charactersInvolved": ["Character Name 1", "Character Name 2"],
          "characterDetails": [
            {
              "name": "Character Name 1",
              "title": "Their official title/position (or null if unknown)",
              "role": "ally|neutral|antagonist|authority|subordinate",
              "dispositionHint": "friendly|hostile|neutral|wary"
            }
          ],
          "plotThreads": {
            "continuesThreads": ["existing_thread_id_if_continuing"],
            "introducesThread": {
              "id": "short_thread_id",
              "title": "Human-readable Thread Title",
              "summary": "Brief description of what this plot thread is about"
            }
          },
          "suggestedCallbackTurn": 5
        }

        Valid stat names: stability, popularSupport, militaryLoyalty, eliteLoyalty, treasury, industrialOutput, foodSupply, internationalStanding
        Valid personal stats: standing, patronFavor, rivalThreat, network, reputationCompetent, reputationLoyal, reputationCunning, reputationRuthless

        ## NARRATIVE MEMORY NOTES
        - narrativeSummary: Brief summary for the AI to reference in future scenarios
        - charactersInvolved: Any named characters appearing in this scenario (REQUIRED - list all named NPCs)
        - characterDetails: Detailed info about each character in charactersInvolved (for tracking new characters)
        - plotThreads.continuesThreads: If this continues a thread from ACTIVE STORYLINES above, include its ID
        - plotThreads.introducesThread: Only include if this scenario starts a NEW storyline worth tracking
        - suggestedCallbackTurn: How many turns from now this should be followed up (omit if standalone)

        ## CHARACTER TRACKING
        For EVERY named character that appears in this scenario, include them in both charactersInvolved AND characterDetails.
        This helps the game track new characters the player meets. Include both existing characters from KEY CHARACTERS above
        AND any new characters you introduce in the narrative.
        """
    }

    private static func formatForCategory(_ category: ScenarioCategory?) -> String {
        switch category {
        case .routineDay: return "narrative"
        case .characterMoment: return "interlude"
        case .tensionBuilder: return "narrative"
        case .newspaper: return "newspaper"
        default: return "briefing"
        }
    }

    // MARK: - Helpers

    private static func statWarning(_ value: Int) -> String {
        if value < 25 { return "[CRITICAL]" }
        if value < 40 { return "[LOW]" }
        if value > 75 { return "[HIGH]" }
        return ""
    }

    private static func identifyCriticalStats(game: Game) -> String {
        var concerns: [String] = []

        // National stats
        if game.stability < 30 { concerns.append("Political instability") }
        if game.popularSupport < 30 { concerns.append("Popular unrest") }
        if game.militaryLoyalty < 30 { concerns.append("Military discontent") }
        if game.eliteLoyalty < 30 { concerns.append("Party opposition") }
        if game.treasury < 30 { concerns.append("Economic crisis") }
        if game.foodSupply < 30 { concerns.append("Food shortage") }
        if game.patronFavor < 30 { concerns.append("Patron displeasure") }
        if game.rivalThreat > 70 { concerns.append("Rival ascendant") }

        // Regional concerns
        let troubledRegions = game.regions.filter { $0.status.severity >= 2 }
        if !troubledRegions.isEmpty {
            concerns.append("Regional crisis (\(troubledRegions.count) regions)")
        }

        let secessionRisks = game.regions.filter { $0.canSecede && $0.secessionProgress > 50 }
        if !secessionRisks.isEmpty {
            concerns.append("Secession risk (\(secessionRisks.map { $0.name }.joined(separator: ", ")))")
        }

        // International concerns
        let highTensionCountries = game.foreignCountries.filter { $0.diplomaticTension > 80 }
        if !highTensionCountries.isEmpty {
            concerns.append("Diplomatic crisis (\(highTensionCountries.first?.name ?? "unknown"))")
        }

        let strainingAllies = game.foreignCountries.filter { $0.politicalBloc == .socialist && $0.relationshipScore < 30 }
        if !strainingAllies.isEmpty {
            concerns.append("Alliance strain (\(strainingAllies.first?.name ?? "unknown"))")
        }

        // Power concerns
        if game.powerConsolidationScore < 20 && game.currentPositionIndex >= 6 {
            concerns.append("Weak power base")
        }

        return concerns.isEmpty ? "None critical" : concerns.joined(separator: ", ")
    }

    private static func describePersonality(_ character: GameCharacter) -> String {
        var traits: [String] = []

        if character.personalityAmbitious >= 70 { traits.append("Ambitious") }
        if character.personalityParanoid >= 70 { traits.append("Paranoid") }
        if character.personalityRuthless >= 70 { traits.append("Ruthless") }
        if character.personalityCompetent >= 70 { traits.append("Competent") }
        if character.personalityLoyal >= 70 { traits.append("Loyal") }
        if character.personalityCorrupt >= 70 { traits.append("Corrupt") }

        return traits.isEmpty ? "Unremarkable" : traits.joined(separator: ", ")
    }
}

