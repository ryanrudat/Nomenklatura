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
        You are a narrative designer for a political simulation game set in the People's Socialist Republic (PSR), a fictional socialist nation on a fictional continent navigating Cold War tensions in the early 1950s. The capital is simply called "The Capital." Generate a scenario briefing that the player must respond to.

        SETTING: Revolutionary Year 43 (circa 1950-1951). The PSR emerged from a revolutionary war against colonial powers, with Soviet aid. The PSR is a tentative USSR ally but not an Eastern Bloc satellite - willing to trade with the West.

        TERMINOLOGY: Use "the Party" for supreme authority, "the Republic" or "the PSR" for the state, "the People's Congress" for the executive council, "the Bureau of People's Security (BPS)" for state security.

        KEY HISTORICAL CONTEXT:
        - Revolution: Workers rose against colonial rule with Soviet aid
        - Consolidation Purges: Post-revolution terror that shaped current politics
        - International: PSR is tentative Soviet ally, USA/UK do not recognize us
        - The real world (USA, USSR, UK, etc.) exists as it did in 1950-1951

        DOMESTIC REGIONS (7 Zones):
        - Zone 1: Capital District (The Capital) - seat of government
        - Zone 2: Industrial Zone (Fitzgerald City) - manufacturing heartland, revolution's birthplace
        - Zone 3: Agricultural Zone (The People's Proletarian Town) - farming collectives, collectivization scars
        - Zone 4: Northern Zone (Upton on Tye) - arctic resources, labor camps
        - Zone 5: Coastal Zone (Red Harbor) - ports, foreign trade
        - Zone 6: Mountain Zone (Highland) - mining, internal exile
        - Zone 7: Border Zone (The Frontier) - frontier territories

        \(buildContextSection(game: game, config: config))

        \(buildRegionsSection(game: game))

        \(buildInternationalSection(game: game))

        \(buildLawsSection(game: game))

        \(buildRecentHistorySection(game: game))

        \(buildCharacterSection(game: game))

        \(buildOngoingProjectsSection(game: game))

        \(buildCategoryRequirement(category: selectedCategory, game: game))

        \(buildInstructions(excludingVariety: true, forTrack: ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared))

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

        // Get current career track for bureau-specific guidance
        let currentTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
        let bureauScope = getBureauScopeGuidance(forTrack: currentTrack, atLevel: game.currentPositionIndex)

        return """
        ## CURRENT GAME STATE

        **Turn:** \(game.turnNumber) — Each turn represents 2 weeks (a fortnight)
        **Current Date:** \(currentDate)
        **Player Position:** \(positionTitle) (Level \(game.currentPositionIndex) of 8)
        **Career Track:** \(currentTrack.displayName)

        **TIME PACING:** Since each turn = 2 weeks, things that would take time in reality should take multiple turns:
        - Small administrative tasks: same turn
        - Minor construction/repairs: 2-3 turns (4-6 weeks)
        - Major construction projects: 4-8 turns (2-4 months)
        - Large infrastructure: 10-20+ turns (5-10 months)
        - Political changes: gradual over multiple turns
        When creating scenarios about ongoing projects, reference realistic timeframes.

        \(positionScope)

        \(bureauScope)

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

    /// Get bureau-specific scope guidance based on the player's career track
    private static func getBureauScopeGuidance(forTrack track: ExpandedCareerTrack, atLevel level: Int) -> String {
        // Only provide bureau-specific guidance for specialized tracks (levels 2-6)
        guard level >= 2 else { return "" }

        switch track {
        case .partyApparatus:
            return getBureauGuidance_PartyApparatus(level: level)
        case .stateMinistry:
            return getBureauGuidance_StateMinistry(level: level)
        case .securityServices:
            return getBureauGuidance_SecurityServices(level: level)
        case .foreignAffairs:
            return getBureauGuidance_ForeignAffairs(level: level)
        case .economicPlanning:
            return getBureauGuidance_EconomicPlanning(level: level)
        case .militaryPolitical:
            return getBureauGuidance_MilitaryPolitical(level: level)
        case .shared, .regional:
            return ""
        }
    }

    // MARK: - Bureau-Specific Guidance (Party Apparatus)

    private static func getBureauGuidance_PartyApparatus(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** PARTY APPARATUS (Central Committee)
        You work within the ideological and personnel heart of the Party. Your concerns are:
        - Cadre selection and vetting - who rises, who falls
        - Ideological purity and doctrinal interpretation
        - Party discipline and internal investigations
        - Propaganda messaging and cultural orthodoxy
        - Managing relationships between Party organs

        """

        switch level {
        case 2: // Instructor of the Central Committee
            return baseGuidance + """
            **Level-Specific Scope:** As CC Instructor, you handle:
            - Investigating complaints against lower cadres
            - Verifying ideological credentials of nominees
            - Attending endless meetings on doctrinal interpretation
            - Writing reports on local Party organizations
            DO NOT involve this player in top-level personnel decisions or Politburo politics.
            """
        case 3: // Deputy Head of CC Department
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Department Head, you handle:
            - Managing a team of instructors and investigators
            - Preparing personnel files for your superior's review
            - Mediating disputes between regional Party organs
            - Implementing policy directives from above
            You have real influence but remain subordinate to Department leadership.
            """
        case 4: // Head of CC Department
            return baseGuidance + """
            **Level-Specific Scope:** As Department Head, you control:
            - All personnel decisions within your department's portfolio
            - Direct access to CC Secretaries for major issues
            - Authority to launch investigations into cadre behavior
            - Significant influence over regional appointments
            You are a person of consequence whose favor is sought.
            """
        case 5: // Secretary of the Central Committee
            return baseGuidance + """
            **Level-Specific Scope:** As CC Secretary, you are:
            - One of the Party's senior leaders
            - Responsible for entire policy domains (ideology, personnel, propaganda)
            - A regular participant in high-level strategy sessions
            - Capable of making or breaking careers with a word
            Your decisions shape Party doctrine and personnel across the nation.
            """
        case 6: // Second Secretary
            return baseGuidance + """
            **Level-Specific Scope:** As Second Secretary, you are:
            - The second-most powerful person in the Party apparatus
            - The General Secretary's right hand on Party matters
            - The gatekeeper for CC personnel and ideology
            - A kingmaker who controls who rises in the Party
            Only the General Secretary outranks you in Party affairs.
            """
        default:
            return baseGuidance
        }
    }

    // MARK: - Bureau-Specific Guidance (State Ministry)

    private static func getBureauGuidance_StateMinistry(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** STATE MINISTRY (Council of Ministers)
        You work within the governmental machinery that runs the state. Your concerns are:
        - Policy implementation and ministerial coordination
        - Budget allocations and resource distribution
        - Managing the vast state bureaucracy
        - Balancing Party directives with practical governance
        - Dealing with the gap between plans and reality

        """

        switch level {
        case 2: // Deputy Minister
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Minister, you handle:
            - Day-to-day operations within your ministry
            - Coordinating between departments and regional offices
            - Preparing reports and briefings for the Minister
            - Firefighting when plans fail to meet reality
            You have real authority but answer to your Minister.
            """
        case 3: // First Deputy Minister
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Minister, you handle:
            - Standing in for the Minister in their absence
            - Managing inter-ministerial coordination
            - Overseeing major projects and initiatives
            - Building relationships with other ministries
            You are the Minister's trusted second-in-command.
            """
        case 4: // Minister
            return baseGuidance + """
            **Level-Specific Scope:** As Minister, you control:
            - Your entire ministry and its vast apparatus
            - Budget requests and resource allocation within your domain
            - Direct relationships with other Ministers and Council leadership
            - Implementation of national policy in your sector
            You are a member of the Council of Ministers with significant power.
            """
        case 5: // Deputy Chairman of Council of Ministers
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Chairman, you oversee:
            - Multiple ministries within your portfolio
            - Cross-sector coordination and major national projects
            - Direct participation in Council of Ministers decisions
            - Resolution of inter-ministerial disputes
            You are among the most powerful administrators in the state.
            """
        case 6: // First Deputy Chairman
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Chairman, you are:
            - The second-most powerful figure in state administration
            - The Chairman's right hand on governmental matters
            - Coordinator of the entire ministerial apparatus
            - A key voice in all major state decisions
            Only the Chairman of the Council of Ministers outranks you in state affairs.
            """
        default:
            return baseGuidance
        }
    }

    // MARK: - Bureau-Specific Guidance (Security Services)

    private static func getBureauGuidance_SecurityServices(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** SECURITY SERVICES (Bureau of People's Security - BPS)
        You work within the state's security and intelligence apparatus. Your concerns are:
        - Counter-intelligence and catching foreign spies
        - Internal surveillance and monitoring dissent
        - Shuanggui detention and political investigations
        - Protecting state secrets and key personnel
        - The paranoid world of loyalty verification

        """

        switch level {
        case 2: // Senior Investigator
            return baseGuidance + """
            **Level-Specific Scope:** As Senior Investigator, you handle:
            - Running investigations into suspected counter-revolutionaries
            - Interrogating suspects and building cases
            - Managing informant networks in your assigned area
            - Writing reports that could destroy careers or lives
            Your work is hands-on and often grim. You see the worst.
            """
        case 3: // Deputy Directorate Chief
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Directorate Chief, you handle:
            - Managing teams of investigators and surveillance operatives
            - Coordinating with other security directorates
            - Briefing superiors on ongoing operations
            - Deciding which leads to pursue, which to shelve
            You have real power over investigations but answer to your Chief.
            """
        case 4: // Directorate Chief
            return baseGuidance + """
            **Level-Specific Scope:** As Directorate Chief, you control:
            - An entire directorate (counter-intelligence, surveillance, etc.)
            - Operations affecting hundreds or thousands of targets
            - Direct access to BPS leadership for major operations
            - Authority to authorize arrests and detentions
            You are a feared figure whose attention terrifies.
            """
        case 5: // First Deputy Director of BPS
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Director, you oversee:
            - Multiple directorates across the security apparatus
            - Coordination with foreign intelligence services
            - Protection of top Party leadership
            - Major operations with national implications
            You are among the most feared individuals in the state.
            """
        case 6: // Director of State Protection (BPS)
            return baseGuidance + """
            **Level-Specific Scope:** As Director of BPS, you are:
            - The supreme authority over state security
            - Privy to every secret, every file, every sin
            - The General Secretary's shield against all threats
            - Capable of destroying anyone with a word
            You hold the sword and shield of the revolution.
            """
        default:
            return baseGuidance
        }
    }

    // MARK: - Bureau-Specific Guidance (Foreign Affairs)

    private static func getBureauGuidance_ForeignAffairs(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** FOREIGN AFFAIRS (Ministry of Foreign Affairs - MFA)
        You work within the diplomatic apparatus. Your concerns are:
        - Managing relations with foreign powers
        - Navigating Cold War tensions between East and West
        - Trade negotiations and international agreements
        - Protecting PSR citizens abroad
        - Balancing Soviet expectations with national interests

        """

        switch level {
        case 2: // Embassy Counselor
            return baseGuidance + """
            **Level-Specific Scope:** As Embassy Counselor, you handle:
            - Day-to-day diplomatic functions at a foreign posting
            - Cultivating contacts in the host country
            - Preparing cables and reports for the Ministry
            - Managing visa and consular matters
            You see the world beyond our borders firsthand.
            """
        case 3: // Ambassador
            return baseGuidance + """
            **Level-Specific Scope:** As Ambassador, you are:
            - The PSR's representative to a foreign nation
            - Responsible for all diplomatic relations in your country
            - A key source of intelligence on foreign intentions
            - Empowered to negotiate within your mandate
            You speak for the Republic abroad.
            """
        case 4: // Deputy Minister of Foreign Affairs
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Minister, you oversee:
            - Multiple regional desks or functional departments
            - Coordination with ambassadors across your portfolio
            - Preparation of positions for major negotiations
            - Direct participation in significant diplomatic encounters
            You shape foreign policy within your domain.
            """
        case 5: // First Deputy Minister
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Minister, you handle:
            - The full spectrum of foreign relations
            - Standing in for the Minister at major events
            - Coordination with intelligence on foreign matters
            - Direct relations with key foreign governments
            You are one of the architects of our foreign policy.
            """
        case 6: // Minister of Foreign Affairs
            return baseGuidance + """
            **Level-Specific Scope:** As Foreign Minister, you are:
            - The voice of the PSR to the world
            - A key player in superpower negotiations
            - The manager of all diplomatic relationships
            - A member of the highest leadership councils
            You represent the Republic on the world stage.
            """
        default:
            return baseGuidance
        }
    }

    // MARK: - Bureau-Specific Guidance (Economic Planning)

    private static func getBureauGuidance_EconomicPlanning(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** ECONOMIC PLANNING (State Planning Commission - Gosplan)
        You work within the command economy apparatus. Your concerns are:
        - Setting and enforcing production quotas
        - Allocating resources across the economy
        - Industrial development and modernization
        - Managing the gap between plans and reality
        - Balancing ideological goals with practical constraints

        """

        switch level {
        case 2: // Senior Economist
            return baseGuidance + """
            **Level-Specific Scope:** As Senior Economist, you handle:
            - Analyzing production data from factories and farms
            - Calculating quotas and resource requirements
            - Writing reports on plan fulfillment
            - Investigating discrepancies in production figures
            You deal with the numbers behind the propaganda.
            """
        case 3: // Department Head of Planning Commission
            return baseGuidance + """
            **Level-Specific Scope:** As Department Head, you handle:
            - Coordinating planning for an entire economic sector
            - Managing teams of economists and inspectors
            - Negotiating with ministries over resource allocation
            - Defending your department's quotas to leadership
            You have real influence over the shape of the economy.
            """
        case 4: // Deputy Chairman of Planning Commission
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Chairman, you oversee:
            - Multiple departments within the Planning Commission
            - Major industrial projects and initiatives
            - Coordination with the Council of Ministers on economic matters
            - Resolution of inter-sectoral disputes over resources
            You are a key architect of the five-year plans.
            """
        case 5: // First Deputy Chairman
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Chairman, you handle:
            - Oversight of the entire planning apparatus
            - Direct participation in high-level economic decisions
            - Coordination with Party leadership on economic policy
            - Managing crises when plans fail to materialize
            You are one of the most powerful economic figures in the state.
            """
        case 6: // Chairman of State Planning
            return baseGuidance + """
            **Level-Specific Scope:** As Chairman of Gosplan, you are:
            - The supreme authority over economic planning
            - Architect of five-year plans affecting millions
            - A key voice in all resource allocation decisions
            - Responsible for making the command economy function
            You hold the economic fate of the nation in your hands.
            """
        default:
            return baseGuidance
        }
    }

    // MARK: - Bureau-Specific Guidance (Military-Political)

    private static func getBureauGuidance_MilitaryPolitical(level: Int) -> String {
        let baseGuidance = """
        **Bureau Focus:** MILITARY-POLITICAL (Main Political Directorate - MPA)
        You work within the military's political control apparatus. Your concerns are:
        - Ensuring military loyalty to the Party
        - Political education of soldiers and officers
        - Monitoring the reliability of military commanders
        - Coordinating between military and Party leadership
        - Managing the balance between military effectiveness and political control

        """

        switch level {
        case 2: // Regimental Political Officer
            return baseGuidance + """
            **Level-Specific Scope:** As Regimental Political Officer, you handle:
            - Political education of soldiers in your regiment
            - Monitoring morale and ideological reliability
            - Reporting on the political mood of the troops
            - Mediating between military commanders and Party requirements
            You are the Party's eyes and ears at the ground level.
            """
        case 3: // Divisional Political Commissar
            return baseGuidance + """
            **Level-Specific Scope:** As Divisional Commissar, you handle:
            - Political oversight of an entire division
            - Managing a team of political officers
            - Direct relationships with division commanders
            - Investigating loyalty concerns at higher levels
            You have significant influence over military affairs in your area.
            """
        case 4: // Deputy Head of Main Political Directorate
            return baseGuidance + """
            **Level-Specific Scope:** As Deputy Head of MPA, you oversee:
            - Political work across multiple military districts
            - Coordination with BPS on military security matters
            - Personnel recommendations for senior military positions
            - Major initiatives in military political education
            You are a key figure in military-political relations.
            """
        case 5: // First Deputy Head
            return baseGuidance + """
            **Level-Specific Scope:** As First Deputy Head of MPA, you handle:
            - Oversight of the entire military political apparatus
            - Direct participation in high-level military decisions
            - Relationships with senior military commanders
            - Coordination with Party leadership on defense matters
            You are among the most powerful figures in military affairs.
            """
        case 6: // Director of Main Political Directorate
            return baseGuidance + """
            **Level-Specific Scope:** As Director of the MPA, you are:
            - The supreme political authority over the armed forces
            - Equal in rank to the Defense Minister on political matters
            - Responsible for the political reliability of the military
            - A member of the highest leadership councils
            You ensure the army remains the Party's sword, not its master.
            """
        default:
            return baseGuidance
        }
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

        The PSR comprises seven administrative zones. Current status:

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

        **THE PSR IN THE REAL 1950s WORLD:**

        SOCIALIST ALLIES:
        - Soviet Union: Revolutionary ally who provided aid during our war for independence
        - People's Republic of China: Fellow revolutionary state under Mao
        - Eastern Bloc: Poland, Czechoslovakia, Hungary, Romania, Bulgaria, East Germany

        CAPITALIST ADVERSARIES:
        - United States: Global superpower, refuses to recognize the PSR
        - United Kingdom: Former colonial power, leads Western opposition
        - France: Unstable republic, swings between left and right
        - West Germany: Firmly in the Western camp

        NON-ALIGNED NATIONS:
        - Yugoslavia: Tito's independent socialist path - a model we study
        - India: Nehru's neutral stance, potential trade partner
        - Egypt: Revolutionary potential brewing
        - Mexico: Southern neighbor, pragmatic relations

        The PSR occupies a unique position: tentative Soviet ally but NOT an Eastern Bloc satellite.
        We maintain more independence than Poland or Hungary, and are willing to trade with the West.

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

        // Main Adversary - USA and UK
        if let usa = capitalistEnemies.first(where: { $0.countryId == "united_states" }) {
            section += """
            **PRIMARY ADVERSARY:**
            - United States: Relations \(usa.relationshipScore)/100, Tension \(usa.diplomaticTension)/100
              Global capitalist superpower. Refuses to recognize the PSR.

            """
        }

        // United Kingdom as major power
        if let uk = capitalistEnemies.first(where: { $0.countryId == "united_kingdom" }) {
            section += """
            **FORMER COLONIAL POWER:**
            - United Kingdom: Relations \(uk.relationshipScore)/100, Tension \(uk.diplomaticTension)/100
              Follows Washington's lead. British intelligence services remain active.

            """
        }

        // Other Capitalist powers (abbreviated)
        let otherCapitalist = capitalistEnemies.filter { $0.countryId != "united_states" && $0.countryId != "united_kingdom" }
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

    private static func buildInstructions(excludingVariety: Bool = false, forTrack track: ExpandedCareerTrack = .shared) -> String {
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

        5. **Tone:** Grim, bureaucratic, paranoid. Use socialist state language: "Comrade," "the Party," "the Republic," "the People's Congress," "counter-revolutionary," "quota," "collective." Soviet-style governance with pragmatic flexibility.

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

        \(getBureauSpecificThemes(forTrack: track))
        """

        return instructions
    }

    // MARK: - Bureau-Specific Themes

    private static func getBureauSpecificThemes(forTrack track: ExpandedCareerTrack) -> String {
        let bureauThemes = getBureauThemes(forTrack: track)

        return """
        8. **CRITICAL - BUREAU-APPROPRIATE SCENARIOS:**
           The player works in the \(track.displayName). Scenarios MUST be relevant to their bureau's domain.

        \(bureauThemes)

           **GENERAL THEMES (appropriate for all bureaus):**
           - Patron/rival relationship dynamics
           - Career advancement opportunities within your track
           - Faction politics affecting your bureau
           - Personal dilemmas and moral choices
           - Historical parallels to real socialist states

           **AVOID generating scenarios outside your bureau's domain:**
           - Security officers should NOT primarily deal with trade negotiations
           - Diplomats should NOT primarily handle factory quotas
           - Economists should NOT primarily investigate suspected spies
           - Keep scenarios thematically appropriate to your career track
        """
    }

    private static func getBureauThemes(forTrack track: ExpandedCareerTrack) -> String {
        switch track {
        case .partyApparatus:
            return """
           **PARTY APPARATUS THEMES (Your Primary Domain):**
           - Cadre evaluation and personnel decisions
           - Ideological purity investigations
           - Party discipline cases and tribunals
           - Propaganda messaging disputes
           - Doctrinal interpretation debates
           - Regional Party organization problems
           - Factional struggles within the Party
           - Rehabilitating or purging former comrades
           - Cultural orthodoxy enforcement
           - Party congress preparations and maneuvering
           - Loyalty investigations and background checks
           - Managing relationships between Party organs
        """

        case .stateMinistry:
            return """
           **STATE MINISTRY THEMES (Your Primary Domain):**
           - Budget allocation disputes between ministries
           - Policy implementation failures
           - Bureaucratic inefficiency and corruption
           - Inter-ministerial coordination problems
           - Regional administration issues
           - Public services and citizen complaints
           - Infrastructure projects and maintenance
           - Housing, education, health sector management
           - Managing the gap between Party directives and reality
           - Ministerial appointments and reshuffles
           - Implementing five-year plan objectives
           - Dealing with petitioners and public grievances
        """

        case .securityServices:
            return """
           **SECURITY SERVICES THEMES (Your Primary Domain):**
           - Counter-intelligence operations against foreign spies
           - Internal surveillance and monitoring dissent
           - Political investigations and shuanggui detention
           - Suspected counter-revolutionary activities
           - Loyalty verification of key personnel
           - Informant network management
           - Interrogation and confession extraction
           - Protecting state secrets
           - VIP protection and security details
           - Cross-border smuggling and infiltration
           - Monitoring foreign embassies and diplomats
           - Internal security within the Party apparatus
           - Prison and labor camp administration
        """

        case .foreignAffairs:
            return """
           **FOREIGN AFFAIRS THEMES (Your Primary Domain):**
           - Diplomatic relations with Soviet Union
           - Managing US/UK hostility and non-recognition
           - Trade negotiations with neutral nations
           - Embassy operations and consular matters
           - Defection incidents (ours or theirs)
           - International conferences and treaties
           - Relations with other socialist states
           - Non-Aligned Movement opportunities
           - Visa and immigration disputes
           - Foreign journalists and cultural exchanges
           - Balancing Soviet expectations with independence
           - Intelligence gathered through diplomatic channels
           - Repatriating citizens abroad
        """

        case .economicPlanning:
            return """
           **ECONOMIC PLANNING THEMES (Your Primary Domain):**
           - Production quota setting and enforcement
           - Resource allocation between sectors
           - Five-year plan adjustments
           - Factory performance and industrial output
           - Agricultural collectivization issues
           - Supply chain disruptions and shortages
           - Economic statistics and reporting accuracy
           - Trade balance and foreign currency
           - Worker productivity and labor discipline
           - Technology transfer and modernization
           - Price controls and black market activity
           - Energy production and distribution
           - Managing the gap between plans and reality
        """

        case .militaryPolitical:
            return """
           **MILITARY-POLITICAL THEMES (Your Primary Domain):**
           - Military loyalty and political reliability
           - Political education of soldiers and officers
           - Monitoring military commanders for deviation
           - Coordination between military and Party
           - Defense policy and military readiness
           - Veterans affairs and demobilization
           - Military-industrial coordination
           - Border defense and territorial integrity
           - Military honors and promotions
           - Investigating military misconduct
           - Balancing professional military needs with political control
           - Military intelligence coordination
           - Civil defense and mobilization planning
        """

        case .shared, .regional:
            return """
           **GENERAL THEMES (Entry Level):**
           - Local administrative matters
           - Office politics and colleague relationships
           - Proving yourself to superiors
           - Small-scale governance decisions
           - Building your reputation and network
           - Learning the bureaucratic system
           - Regional/district-level issues
        """
        }
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

