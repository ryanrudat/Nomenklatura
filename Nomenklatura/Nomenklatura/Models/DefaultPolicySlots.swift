//
//  DefaultPolicySlots.swift
//  Nomenklatura
//
//  Default policy slots for all 8 institutions
//  27 total policy slots with 3-4 options each
//

import Foundation

extension PolicySlot {

    // MARK: - Create All Default Policy Slots

    static func createDefaultPolicySlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // Add slots from each institution
        slots.append(contentsOf: createPresidiumSlots())
        slots.append(contentsOf: createCongressSlots())
        slots.append(contentsOf: createMilitarySlots())
        slots.append(contentsOf: createSecuritySlots())
        slots.append(contentsOf: createEconomySlots())
        slots.append(contentsOf: createRegionalSlots())
        slots.append(contentsOf: createPropagandaSlots())
        slots.append(contentsOf: createForeignSlots())

        return slots
    }

    // MARK: - 1. THE PRESIDIUM (4 Slots)

    static func createPresidiumSlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Leadership Selection
        let leadershipOptions = [
            PolicyOption(
                id: "leadership_collective_vote",
                name: "Collective Vote",
                description: "The Presidium votes collectively on major decisions. No single member can dominate.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 10,
                    factionModifiers: ["youth_league": 5, "reformists": 5]
                ),
                beneficiaries: ["youth_league", "reformists"],
                losers: ["old_guard"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "leadership_gs_decides",
                name: "General Secretary Decides",
                description: "The General Secretary has final authority on all major decisions. The Presidium advises but does not constrain.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    eliteLoyaltyModifier: -15,
                    factionModifiers: ["old_guard": 10, "princelings": 5],
                    enablesDecrees: true
                ),
                beneficiaries: ["old_guard"],
                losers: ["youth_league", "reformists"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 40,
                delayedConsequenceSeverity: 4
            ),
            PolicyOption(
                id: "leadership_factional_rotation",
                name: "Factional Rotation",
                description: "Leadership of key committees rotates between faction representatives to maintain balance.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    eliteLoyaltyModifier: 5,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional", "reformists"],
                losers: ["princelings"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "leadership_elders_veto",
                name: "Elder's Veto",
                description: "Senior members of the Presidium can veto any decision. Protects the old guard's interests.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 15,
                    factionModifiers: ["old_guard": 15, "princelings": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["youth_league"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            )
        ]

        let leadershipSlot = PolicySlot(
            slotId: "presidium_leadership_selection",
            name: "Leadership Selection",
            description: "How decisions are made within the Presidium and who has final authority.",
            institution: .presidium,
            category: .institutional,
            options: leadershipOptions,
            defaultOptionId: "leadership_collective_vote"
        )
        slots.append(leadershipSlot)

        // SLOT 2: Term Limits
        let termLimitOptions = [
            PolicyOption(
                id: "term_limits_two_terms",
                name: "Two Terms (8 Years)",
                description: "The General Secretary serves a maximum of two four-year terms, ensuring regular succession.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    internationalStandingModifier: 5,
                    factionModifiers: ["youth_league": 10]
                ),
                beneficiaries: ["youth_league", "reformists"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "term_limits_life_tenure",
                name: "Life Tenure",
                description: "The General Secretary serves until death, incapacity, or voluntary retirement. No term limits.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    eliteLoyaltyModifier: -20,
                    internationalStandingModifier: -15,
                    factionModifiers: ["old_guard": 5],
                    preventsSuccession: true
                ),
                beneficiaries: [],
                losers: ["youth_league", "reformists", "regional"],
                isExtreme: true,
                minimumPowerRequired: 90,
                minimumPositionIndex: 8,
                requiredFactionSupport: ["princelings": 60],
                immediateConsequenceChance: 60,
                delayedConsequenceSeverity: 5
            ),
            PolicyOption(
                id: "term_limits_age_limit",
                name: "Age Limit (70)",
                description: "Leaders must retire at age 70, ensuring generational renewal in leadership.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: -10,
                    factionModifiers: ["youth_league": 15]
                ),
                beneficiaries: ["youth_league"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "term_limits_single_term",
                name: "Single Term (4 Years)",
                description: "The General Secretary serves only one four-year term, maximizing turnover.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    eliteLoyaltyModifier: -5,
                    factionModifiers: ["youth_league": 20, "regional": 10]
                ),
                beneficiaries: ["youth_league", "regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 70,
                minimumPositionIndex: 7
            )
        ]

        let termLimitSlot = PolicySlot(
            slotId: "presidium_term_limits",
            name: "Term Limits",
            description: "How long the General Secretary can serve and succession timing.",
            institution: .presidium,
            category: .institutional,
            options: termLimitOptions,
            defaultOptionId: "term_limits_two_terms"
        )
        slots.append(termLimitSlot)

        // SLOT 3: Emergency Powers
        let emergencyOptions = [
            PolicyOption(
                id: "emergency_presidium_approval",
                name: "Presidium Approval Required",
                description: "Emergency powers require approval from the full Presidium before activation.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 10
                ),
                beneficiaries: ["youth_league", "reformists"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "emergency_gs_unilateral",
                name: "GS Unilateral Action",
                description: "The General Secretary can declare emergencies and act without Presidium approval.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    eliteLoyaltyModifier: -15,
                    enablesDecrees: true,
                    enablesPurges: true
                ),
                beneficiaries: ["old_guard"],
                losers: ["youth_league", "reformists", "regional"],
                isExtreme: true,
                minimumPowerRequired: 80,
                minimumPositionIndex: 8,
                immediateConsequenceChance: 50,
                delayedConsequenceSeverity: 4
            ),
            PolicyOption(
                id: "emergency_military_approval",
                name: "Military Approval",
                description: "Emergency powers require endorsement from the Defense Council.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    militaryLoyaltyModifier: 15,
                    factionModifiers: ["princelings": 10]
                ),
                beneficiaries: ["princelings"],
                losers: ["reformists"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "emergency_no_powers",
                name: "No Emergency Powers",
                description: "The state has no special emergency provisions. All actions must follow normal procedures.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            )
        ]

        let emergencySlot = PolicySlot(
            slotId: "presidium_emergency_powers",
            name: "Emergency Powers",
            description: "What authority exists during crises and who controls it.",
            institution: .presidium,
            category: .institutional,
            options: emergencyOptions,
            defaultOptionId: "emergency_presidium_approval"
        )
        slots.append(emergencySlot)

        // SLOT 4: Succession Rules
        let successionOptions = [
            PolicyOption(
                id: "succession_deputy_succeeds",
                name: "Deputy Succeeds",
                description: "The Deputy General Secretary automatically becomes acting leader upon vacancy.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    eliteLoyaltyModifier: 5
                ),
                beneficiaries: ["princelings"],
                losers: ["regional"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "succession_presidium_election",
                name: "Presidium Election",
                description: "The Presidium elects a new General Secretary from among its members.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 10,
                    factionModifiers: ["youth_league": 5]
                ),
                beneficiaries: ["youth_league", "reformists"],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "succession_congress_vote",
                name: "Party Congress Vote",
                description: "The full Party Congress elects the General Secretary, giving regional delegates more influence.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    eliteLoyaltyModifier: -5,
                    factionModifiers: ["regional": 20]
                ),
                beneficiaries: ["regional", "youth_league"],
                losers: ["princelings", "old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "succession_gs_designates",
                name: "GS Designates Successor",
                description: "The sitting General Secretary names their own successor, who is then confirmed by the Presidium.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: -10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["youth_league", "reformists"],
                minimumPowerRequired: 70,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            )
        ]

        let successionSlot = PolicySlot(
            slotId: "presidium_succession_rules",
            name: "Succession Rules",
            description: "How power transfers when the General Secretary position becomes vacant.",
            institution: .presidium,
            category: .institutional,
            options: successionOptions,
            defaultOptionId: "succession_deputy_succeeds"
        )
        slots.append(successionSlot)

        return slots
    }

    // MARK: - 2. PEOPLE'S CONGRESS (3 Slots)

    static func createCongressSlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Session Frequency
        let sessionOptions = [
            PolicyOption(
                id: "session_annual",
                name: "Annual Sessions",
                description: "The People's Congress meets once per year in regular session.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5
                ),
                beneficiaries: ["youth_league"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "session_biannual",
                name: "Biannual Sessions",
                description: "The Congress meets twice per year, increasing legislative activity.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 10,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional", "reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "session_gs_calls",
                name: "Called by GS Only",
                description: "The Congress meets only when convened by the General Secretary.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: -10,
                    eliteLoyaltyModifier: 5
                ),
                beneficiaries: ["old_guard"],
                losers: ["regional", "reformists"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "session_permanent",
                name: "Permanent Session",
                description: "The Congress remains in continuous session, meeting regularly throughout the year.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    factionModifiers: ["reformists": 15, "regional": 10]
                ),
                beneficiaries: ["reformists", "regional"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6
            )
        ]

        let sessionSlot = PolicySlot(
            slotId: "congress_session_frequency",
            name: "Session Frequency",
            description: "How often the People's Congress convenes in formal session.",
            institution: .congress,
            category: .political,
            options: sessionOptions,
            defaultOptionId: "session_annual"
        )
        slots.append(sessionSlot)

        // SLOT 2: Delegate Selection
        let delegateOptions = [
            PolicyOption(
                id: "delegates_local_councils",
                name: "Elected by Local Councils",
                description: "Delegates are chosen by lower-level councils through indirect election.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "delegates_party_appointed",
                name: "Appointed by Party",
                description: "Delegates are appointed directly by Party committees at each level.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -10,
                    eliteLoyaltyModifier: 10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["regional", "reformists"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "delegates_mixed",
                name: "Mixed System",
                description: "Half of delegates are elected, half are appointed to ensure balance.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 0
                ),
                beneficiaries: [],
                losers: [],
                minimumPowerRequired: 45,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "delegates_regional_quotas",
                name: "Regional Quotas",
                description: "Each region receives a fixed number of delegate seats based on population.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 10,
                    regionalControlModifier: -10,
                    factionModifiers: ["regional": 20]
                ),
                beneficiaries: ["regional"],
                losers: ["princelings"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            )
        ]

        let delegateSlot = PolicySlot(
            slotId: "congress_delegate_selection",
            name: "Delegate Selection",
            description: "How delegates to the People's Congress are chosen.",
            institution: .congress,
            category: .political,
            options: delegateOptions,
            defaultOptionId: "delegates_local_councils"
        )
        slots.append(delegateSlot)

        // SLOT 3: Legislative Power
        let powerOptions = [
            PolicyOption(
                id: "congress_rubber_stamp",
                name: "Rubber Stamp",
                description: "The Congress approves all proposals from the Presidium without substantive debate.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -5,
                    eliteLoyaltyModifier: 10
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "congress_limited_debate",
                name: "Limited Debate",
                description: "Delegates may discuss proposals but amendments require Presidium approval.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5,
                    factionModifiers: ["youth_league": 5]
                ),
                beneficiaries: ["youth_league", "reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "congress_genuine_input",
                name: "Genuine Input",
                description: "The Congress can propose amendments and send legislation back to committee.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    eliteLoyaltyModifier: -10,
                    factionModifiers: ["reformists": 15, "regional": 10]
                ),
                beneficiaries: ["reformists", "regional"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "congress_constitutional",
                name: "Constitutional Authority",
                description: "The Congress is the supreme legislative body with power to override the Presidium.",
                effects: PolicyEffects(
                    stabilityModifier: -15,
                    popularSupportModifier: 20,
                    eliteLoyaltyModifier: -20,
                    factionModifiers: ["reformists": 20],
                    triggersUnrest: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings", "youth_league"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 50,
                delayedConsequenceSeverity: 4
            )
        ]

        let powerSlot = PolicySlot(
            slotId: "congress_legislative_power",
            name: "Legislative Power",
            description: "The actual authority of the People's Congress in lawmaking.",
            institution: .congress,
            category: .political,
            options: powerOptions,
            defaultOptionId: "congress_rubber_stamp"
        )
        slots.append(powerSlot)

        return slots
    }

    // MARK: - 3. THE MILITARY (4 Slots)

    static func createMilitarySlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Political Commissars
        let commissarOptions = [
            PolicyOption(
                id: "commissar_required_all",
                name: "Required in All Units",
                description: "Political commissars serve in all military units to ensure ideological correctness.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: -10,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["princelings"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "commissar_advisory",
                name: "Advisory Role Only",
                description: "Commissars advise commanders but cannot override military decisions.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    militaryLoyaltyModifier: 10,
                    factionModifiers: ["princelings": 10]
                ),
                beneficiaries: ["princelings"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "commissar_abolished",
                name: "Abolished",
                description: "Political commissars are eliminated. Military operates independently.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    eliteLoyaltyModifier: -15,
                    militaryLoyaltyModifier: 20,
                    factionModifiers: ["princelings": 20]
                ),
                beneficiaries: ["princelings"],
                losers: ["old_guard", "youth_league"],
                isExtreme: true,
                minimumPowerRequired: 70,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 40,
                delayedConsequenceSeverity: 4
            ),
            PolicyOption(
                id: "commissar_senior_only",
                name: "Only Senior Commands",
                description: "Commissars only serve at division level and above.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: 5
                ),
                beneficiaries: [],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            )
        ]

        let commissarSlot = PolicySlot(
            slotId: "military_commissars",
            name: "Political Commissars",
            description: "The role of political officers in the armed forces.",
            institution: .military,
            category: .political,
            options: commissarOptions,
            defaultOptionId: "commissar_required_all"
        )
        slots.append(commissarSlot)

        // SLOT 2: Defense Budget Control
        let budgetOptions = [
            PolicyOption(
                id: "budget_party_controlled",
                name: "Party Controlled",
                description: "The defense budget is set by the Presidium. Military requests but doesn't decide.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: -5,
                    factionModifiers: ["old_guard": 5]
                ),
                beneficiaries: ["old_guard", "youth_league"],
                losers: ["princelings"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "budget_military_staff",
                name: "Military General Staff",
                description: "The General Staff determines military spending priorities.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    economicOutputModifier: -10,
                    militaryLoyaltyModifier: 15,
                    factionModifiers: ["princelings": 15]
                ),
                beneficiaries: ["princelings"],
                losers: ["reformists", "youth_league"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "budget_shared_oversight",
                name: "Shared Oversight",
                description: "A joint civilian-military commission sets defense spending.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: 5
                ),
                beneficiaries: [],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "budget_gs_personal",
                name: "GS Personal Control",
                description: "The General Secretary personally controls military spending decisions.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    eliteLoyaltyModifier: -10,
                    militaryLoyaltyModifier: -10
                ),
                beneficiaries: [],
                losers: ["princelings", "youth_league"],
                minimumPowerRequired: 75,
                minimumPositionIndex: 8
            )
        ]

        let budgetSlot = PolicySlot(
            slotId: "military_budget_control",
            name: "Defense Budget Control",
            description: "Who controls military spending and procurement decisions.",
            institution: .military,
            category: .economic,
            options: budgetOptions,
            defaultOptionId: "budget_party_controlled"
        )
        slots.append(budgetSlot)

        // SLOT 3: Officer Promotion
        let promotionOptions = [
            PolicyOption(
                id: "promotion_political_loyalty",
                name: "Political Loyalty Primary",
                description: "Officers advance based primarily on ideological reliability and Party standing.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: -5,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["princelings"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "promotion_merit_based",
                name: "Merit-Based",
                description: "Officers advance based on military competence and battlefield performance.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    militaryLoyaltyModifier: 15,
                    factionModifiers: ["princelings": 10, "youth_league": 5]
                ),
                beneficiaries: ["princelings", "youth_league"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "promotion_seniority",
                name: "Seniority",
                description: "Officers advance based on time in service. Predictable but slow.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    militaryLoyaltyModifier: 0
                ),
                beneficiaries: ["old_guard"],
                losers: ["youth_league"],
                minimumPowerRequired: 45,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "promotion_factional_balance",
                name: "Factional Balance",
                description: "Promotions maintain representation across different factional groups.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: 5,
                    factionModifiers: ["regional": 5]
                ),
                beneficiaries: ["regional"],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            )
        ]

        let promotionSlot = PolicySlot(
            slotId: "military_officer_promotion",
            name: "Officer Promotion",
            description: "How military officers advance through the ranks.",
            institution: .military,
            category: .political,
            options: promotionOptions,
            defaultOptionId: "promotion_political_loyalty"
        )
        slots.append(promotionSlot)

        // SLOT 4: Nuclear Authority
        let nuclearOptions = [
            PolicyOption(
                id: "nuclear_gs_sole",
                name: "GS Sole Authority",
                description: "Only the General Secretary can authorize nuclear weapons use.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    militaryLoyaltyModifier: -5,
                    internationalStandingModifier: -5
                ),
                beneficiaries: ["old_guard"],
                losers: ["princelings"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "nuclear_presidium_consensus",
                name: "Presidium Consensus",
                description: "Nuclear use requires unanimous agreement of the Presidium.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    internationalStandingModifier: 5,
                    factionModifiers: ["reformists": 5]
                ),
                beneficiaries: ["reformists", "youth_league"],
                losers: [],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "nuclear_military_chain",
                name: "Military Chain of Command",
                description: "Nuclear authority follows standard military command structure.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    militaryLoyaltyModifier: 15,
                    internationalStandingModifier: -15,
                    factionModifiers: ["princelings": 15]
                ),
                beneficiaries: ["princelings"],
                losers: ["old_guard", "reformists"],
                isExtreme: true,
                minimumPowerRequired: 70,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 40,
                delayedConsequenceSeverity: 4
            ),
            PolicyOption(
                id: "nuclear_dual_key",
                name: "Dual Key System",
                description: "Both the GS and Defense Minister must agree for nuclear authorization.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    militaryLoyaltyModifier: 5,
                    internationalStandingModifier: 10
                ),
                beneficiaries: ["reformists"],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            )
        ]

        let nuclearSlot = PolicySlot(
            slotId: "military_nuclear_authority",
            name: "Nuclear Authority",
            description: "Who can authorize the use of nuclear weapons.",
            institution: .military,
            category: .institutional,
            options: nuclearOptions,
            defaultOptionId: "nuclear_gs_sole"
        )
        slots.append(nuclearSlot)

        return slots
    }

    // MARK: - 4. SECURITY SERVICES (3 Slots)

    static func createSecuritySlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Surveillance Scope
        let surveillanceOptions = [
            PolicyOption(
                id: "surveillance_universal",
                name: "Universal Monitoring",
                description: "The BPS monitors all citizens through informant networks and electronic surveillance.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -15,
                    securityEffectiveness: 20,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "surveillance_targeted",
                name: "Targeted Suspects",
                description: "Surveillance focuses on known dissidents and suspicious individuals.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 0,
                    securityEffectiveness: 10
                ),
                beneficiaries: [],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "surveillance_elite_focus",
                name: "Elite Focus Only",
                description: "The BPS primarily monitors Party members and officials for loyalty.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 5,
                    eliteLoyaltyModifier: -15,
                    securityEffectiveness: 5
                ),
                beneficiaries: [],
                losers: ["old_guard", "princelings", "youth_league"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "surveillance_minimal",
                name: "Minimal (Foreign Only)",
                description: "Domestic surveillance is minimized. Focus is on foreign intelligence.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: 15,
                    internationalStandingModifier: 10,
                    securityEffectiveness: -10,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            )
        ]

        let surveillanceSlot = PolicySlot(
            slotId: "security_surveillance_scope",
            name: "Surveillance Scope",
            description: "The extent of state surveillance over citizens and officials.",
            institution: .security,
            category: .political,
            options: surveillanceOptions,
            defaultOptionId: "surveillance_universal"
        )
        slots.append(surveillanceSlot)

        // SLOT 2: Arrest Authority
        let arrestOptions = [
            PolicyOption(
                id: "arrest_extrajudicial",
                name: "Extrajudicial",
                description: "The BPS can arrest and detain citizens without judicial oversight.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -20,
                    factionModifiers: ["old_guard": 10],
                    enablesPurges: true
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists", "regional"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "arrest_warrant_required",
                name: "Court Warrant Required",
                description: "Arrests require a warrant from the People's Courts.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "arrest_presidium_approval",
                name: "Presidium Approval",
                description: "Arrest of officials requires Politburo approval. Citizens still subject to BPS authority.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 10
                ),
                beneficiaries: ["princelings", "youth_league"],
                losers: [],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "arrest_military_tribunal",
                name: "Military Tribunal",
                description: "Political arrests handled by military tribunals rather than civilian BPS.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: -10,
                    militaryLoyaltyModifier: 10,
                    factionModifiers: ["princelings": 10]
                ),
                beneficiaries: ["princelings"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6
            )
        ]

        let arrestSlot = PolicySlot(
            slotId: "security_arrest_authority",
            name: "Arrest Authority",
            description: "What authority is required for the BPS to arrest citizens.",
            institution: .security,
            category: .political,
            options: arrestOptions,
            defaultOptionId: "arrest_extrajudicial"
        )
        slots.append(arrestSlot)

        // SLOT 3: Internal Investigations
        let investigationOptions = [
            PolicyOption(
                id: "investigation_bps_self",
                name: "BPS Self-Policing",
                description: "The BPS investigates its own misconduct. No external oversight.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: -10,
                    factionModifiers: ["old_guard": 5]
                ),
                beneficiaries: ["old_guard"],
                losers: ["youth_league"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "investigation_party_commission",
                name: "Party Commission",
                description: "A Party commission oversees BPS conduct and investigates complaints.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: 5,
                    factionModifiers: ["youth_league": 10]
                ),
                beneficiaries: ["youth_league"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "investigation_independent",
                name: "Independent Prosecutor",
                description: "An independent prosecutor can investigate any state organ, including the BPS.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: 10,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 20]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                isExtreme: true,
                minimumPowerRequired: 70,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 40,
                delayedConsequenceSeverity: 4
            ),
            PolicyOption(
                id: "investigation_gs_office",
                name: "GS Personal Office",
                description: "The General Secretary's personal office handles all sensitive investigations.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    eliteLoyaltyModifier: -15
                ),
                beneficiaries: [],
                losers: ["princelings", "youth_league"],
                minimumPowerRequired: 75,
                minimumPositionIndex: 8
            )
        ]

        let investigationSlot = PolicySlot(
            slotId: "security_internal_investigations",
            name: "Internal Investigations",
            description: "Who investigates misconduct by the security services.",
            institution: .security,
            category: .political,
            options: investigationOptions,
            defaultOptionId: "investigation_bps_self"
        )
        slots.append(investigationSlot)

        return slots
    }

    // MARK: - 5. ECONOMIC PLANNING (4 Slots)

    static func createEconomySlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Enterprise Management
        let enterpriseOptions = [
            PolicyOption(
                id: "enterprise_central_quotas",
                name: "Central Quotas",
                description: "All production quotas set by central planners. Managers execute the plan.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    economicOutputModifier: -5,
                    factionModifiers: ["old_guard": 5]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "enterprise_regional_flexibility",
                name: "Regional Flexibility",
                description: "Regional planners can adjust quotas based on local conditions.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    economicOutputModifier: 5,
                    regionalControlModifier: -5,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "enterprise_manager_autonomy",
                name: "Manager Autonomy",
                description: "Enterprise managers have authority to make production decisions.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    economicOutputModifier: 15,
                    factionModifiers: ["reformists": 15],
                    enablesReforms: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "enterprise_worker_councils",
                name: "Worker Councils",
                description: "Worker councils participate in enterprise management decisions.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: 15,
                    economicOutputModifier: -5,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists", "regional"],
                losers: ["princelings"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            )
        ]

        let enterpriseSlot = PolicySlot(
            slotId: "economy_enterprise_management",
            name: "Enterprise Management",
            description: "How state enterprises are managed and who makes production decisions.",
            institution: .economy,
            category: .economic,
            options: enterpriseOptions,
            defaultOptionId: "enterprise_central_quotas"
        )
        slots.append(enterpriseSlot)

        // SLOT 2: Private Enterprise
        let privateOptions = [
            PolicyOption(
                id: "private_prohibited",
                name: "Prohibited",
                description: "All private enterprise is illegal. Everything belongs to the state.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: -10,
                    economicOutputModifier: -10,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "private_small_plots",
                name: "Small Plots Allowed",
                description: "Citizens may cultivate small private plots for personal use and local markets.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 10,
                    economicOutputModifier: 5
                ),
                beneficiaries: ["regional"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "private_licensed_businesses",
                name: "Licensed Businesses",
                description: "Small businesses can operate with state licenses in service sectors.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    economicOutputModifier: 15,
                    factionModifiers: ["reformists": 20],
                    enablesReforms: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "private_limited_markets",
                name: "Limited Markets",
                description: "Market mechanisms allowed in consumer goods. Strategic sectors remain state-controlled.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: 20,
                    economicOutputModifier: 20,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 25],
                    enablesReforms: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                isExtreme: true,
                minimumPowerRequired: 70,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 40,
                delayedConsequenceSeverity: 4
            )
        ]

        let privateSlot = PolicySlot(
            slotId: "economy_private_enterprise",
            name: "Private Enterprise",
            description: "The extent to which private economic activity is permitted.",
            institution: .economy,
            category: .economic,
            options: privateOptions,
            defaultOptionId: "private_small_plots"
        )
        slots.append(privateSlot)

        // SLOT 3: Foreign Trade
        let tradeOptions = [
            PolicyOption(
                id: "trade_state_monopoly",
                name: "State Monopoly",
                description: "All foreign trade conducted through state trading organizations.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    economicOutputModifier: -5,
                    internationalStandingModifier: -5,
                    factionModifiers: ["old_guard": 5]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "trade_licensed_companies",
                name: "Licensed Companies",
                description: "Select state enterprises can trade directly with foreign partners.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    economicOutputModifier: 10,
                    internationalStandingModifier: 5,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "trade_joint_ventures",
                name: "Joint Ventures",
                description: "Foreign companies can partner with state enterprises in special zones.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    economicOutputModifier: 20,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 15],
                    enablesReforms: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 25,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "trade_open_zones",
                name: "Open Trade Zones",
                description: "Special economic zones allow nearly free trade and foreign investment.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    economicOutputModifier: 25,
                    internationalStandingModifier: 20,
                    factionModifiers: ["reformists": 20],
                    enablesReforms: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 35,
                delayedConsequenceSeverity: 4
            )
        ]

        let tradeSlot = PolicySlot(
            slotId: "economy_foreign_trade",
            name: "Foreign Trade",
            description: "How international trade is conducted and controlled.",
            institution: .economy,
            category: .economic,
            options: tradeOptions,
            defaultOptionId: "trade_state_monopoly"
        )
        slots.append(tradeSlot)

        // SLOT 4: Price Controls
        let priceOptions = [
            PolicyOption(
                id: "price_full_control",
                name: "Full State Control",
                description: "All prices set by state planners. No market pricing allowed.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5,
                    economicOutputModifier: -10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "price_strategic_only",
                name: "Strategic Goods Only",
                description: "State controls prices on essential goods. Other prices float.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 0,
                    economicOutputModifier: 10,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "price_consumer_choice",
                name: "Consumer Choice",
                description: "Prices respond to supply and demand in consumer markets.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: -10,
                    economicOutputModifier: 20,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 15],
                    triggersUnrest: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "price_market_signals",
                name: "Market Signals",
                description: "Prices primarily determined by market forces across most sectors.",
                effects: PolicyEffects(
                    stabilityModifier: -15,
                    popularSupportModifier: -15,
                    economicOutputModifier: 30,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 20],
                    enablesReforms: true,
                    triggersUnrest: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 45,
                delayedConsequenceSeverity: 4
            )
        ]

        let priceSlot = PolicySlot(
            slotId: "economy_price_controls",
            name: "Price Controls",
            description: "How prices are set in the economy.",
            institution: .economy,
            category: .economic,
            options: priceOptions,
            defaultOptionId: "price_full_control"
        )
        slots.append(priceSlot)

        return slots
    }

    // MARK: - 6. REGIONAL GOVERNANCE (3 Slots)

    static func createRegionalSlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Governor Appointment
        let governorOptions = [
            PolicyOption(
                id: "governor_central_appointment",
                name: "Central Appointment",
                description: "Governors appointed directly by the Presidium from the capital.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    regionalControlModifier: 15,
                    factionModifiers: ["old_guard": 10, "princelings": 5]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["regional"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "governor_regional_election",
                name: "Regional Election",
                description: "Regional councils elect their own governors from approved candidates.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 10,
                    regionalControlModifier: -15,
                    factionModifiers: ["regional": 20],
                    enablesAutonomy: true
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 25,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "governor_party_congress",
                name: "Party Congress",
                description: "Regional Party congresses nominate governors, confirmed by Presidium.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    eliteLoyaltyModifier: 5,
                    factionModifiers: ["youth_league": 10]
                ),
                beneficiaries: ["youth_league"],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "governor_local_council",
                name: "Local Council Nomination",
                description: "Local councils nominate candidates, Presidium chooses from list.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5,
                    regionalControlModifier: -5,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional"],
                losers: ["princelings"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 5
            )
        ]

        let governorSlot = PolicySlot(
            slotId: "regions_governor_appointment",
            name: "Governor Appointment",
            description: "How regional governors are selected and appointed.",
            institution: .regions,
            category: .political,
            options: governorOptions,
            defaultOptionId: "governor_central_appointment"
        )
        slots.append(governorSlot)

        // SLOT 2: Regional Autonomy
        let autonomyOptions = [
            PolicyOption(
                id: "autonomy_centralized",
                name: "Centralized Control",
                description: "All significant decisions made in the capital. Regions execute orders.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: -10,
                    regionalControlModifier: 20,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["regional"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "autonomy_cultural",
                name: "Cultural Autonomy",
                description: "Regions can manage local culture, language, and education.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 10,
                    regionalControlModifier: -5,
                    factionModifiers: ["regional": 15],
                    enablesAutonomy: true
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "autonomy_economic",
                name: "Economic Autonomy",
                description: "Regions have authority over local economic planning and development.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    economicOutputModifier: 10,
                    regionalControlModifier: -15,
                    factionModifiers: ["regional": 20, "reformists": 10],
                    enablesAutonomy: true
                ),
                beneficiaries: ["regional", "reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "autonomy_federal",
                name: "Federal System",
                description: "Regions function as semi-autonomous republics with broad self-governance.",
                effects: PolicyEffects(
                    stabilityModifier: -15,
                    popularSupportModifier: 20,
                    regionalControlModifier: -25,
                    factionModifiers: ["regional": 30],
                    enablesAutonomy: true
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard", "princelings", "youth_league"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 50,
                delayedConsequenceSeverity: 5
            )
        ]

        let autonomySlot = PolicySlot(
            slotId: "regions_autonomy_level",
            name: "Regional Autonomy",
            description: "How much self-governance regions are permitted.",
            institution: .regions,
            category: .political,
            options: autonomyOptions,
            defaultOptionId: "autonomy_centralized"
        )
        slots.append(autonomySlot)

        // SLOT 3: Resource Revenue
        let revenueOptions = [
            PolicyOption(
                id: "revenue_all_to_center",
                name: "All to Center",
                description: "All resource revenue goes to the central government for redistribution.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    economicOutputModifier: -5,
                    regionalControlModifier: 10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["regional"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "revenue_sharing",
                name: "Revenue Sharing",
                description: "Resource revenue split between central and regional governments.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    economicOutputModifier: 5,
                    regionalControlModifier: -5,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional"],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "revenue_regional_retention",
                name: "Regional Retention",
                description: "Regions keep most resource revenue, paying only taxes to center.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    economicOutputModifier: 15,
                    regionalControlModifier: -20,
                    factionModifiers: ["regional": 20]
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "revenue_negotiated",
                name: "Negotiated Compact",
                description: "Each region negotiates its own revenue arrangement with the center.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    economicOutputModifier: 10,
                    regionalControlModifier: -15,
                    factionModifiers: ["regional": 15]
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            )
        ]

        let revenueSlot = PolicySlot(
            slotId: "regions_resource_revenue",
            name: "Resource Revenue",
            description: "How natural resource revenue is distributed between center and regions.",
            institution: .regions,
            category: .economic,
            options: revenueOptions,
            defaultOptionId: "revenue_all_to_center"
        )
        slots.append(revenueSlot)

        return slots
    }

    // MARK: - 7. PROPAGANDA & MEDIA (3 Slots)

    static func createPropagandaSlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Press Control
        let pressOptions = [
            PolicyOption(
                id: "press_total_control",
                name: "Total State Control",
                description: "All media is state-owned and controlled by the Propaganda Department.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -5,
                    internationalStandingModifier: -10,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "press_licensed",
                name: "Licensed Publications",
                description: "Private publications can exist with state licenses and oversight.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 10,
                    internationalStandingModifier: 5,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "press_self_censorship",
                name: "Self-Censorship Guidelines",
                description: "Media follows guidelines but operates with editorial independence.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "press_limited_freedom",
                name: "Limited Freedom",
                description: "Press operates freely except on matters of state security.",
                effects: PolicyEffects(
                    stabilityModifier: -15,
                    popularSupportModifier: 25,
                    internationalStandingModifier: 20,
                    factionModifiers: ["reformists": 25],
                    triggersUnrest: true
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                isExtreme: true,
                minimumPowerRequired: 75,
                minimumPositionIndex: 7,
                immediateConsequenceChance: 50,
                delayedConsequenceSeverity: 4
            )
        ]

        let pressSlot = PolicySlot(
            slotId: "propaganda_press_control",
            name: "Press Control",
            description: "The degree of state control over media and publications.",
            institution: .propaganda,
            category: .social,
            options: pressOptions,
            defaultOptionId: "press_total_control"
        )
        slots.append(pressSlot)

        // SLOT 2: Cultural Policy
        let cultureOptions = [
            PolicyOption(
                id: "culture_socialist_realism",
                name: "Socialist Realism Only",
                description: "All art must serve socialist ideals. Abstract or bourgeois art is banned.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: -10,
                    internationalStandingModifier: -5,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "culture_approved_diversity",
                name: "Approved Diversity",
                description: "Diverse artistic expression permitted within ideological guidelines.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 10,
                    internationalStandingModifier: 5
                ),
                beneficiaries: ["youth_league"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "culture_creative_freedom",
                name: "Creative Freedom",
                description: "Artists enjoy broad creative freedom. Political content still restricted.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "culture_western_banned",
                name: "Western Influences Banned",
                description: "Foreign cultural products prohibited. Strict cultural isolation enforced.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -15,
                    internationalStandingModifier: -15,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists", "youth_league"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            )
        ]

        let cultureSlot = PolicySlot(
            slotId: "propaganda_cultural_policy",
            name: "Cultural Policy",
            description: "State policy toward art, literature, and cultural expression.",
            institution: .propaganda,
            category: .social,
            options: cultureOptions,
            defaultOptionId: "culture_socialist_realism"
        )
        slots.append(cultureSlot)

        // SLOT 3: Religious Policy
        let religionOptions = [
            PolicyOption(
                id: "religion_active_suppression",
                name: "Active Suppression",
                description: "Religious practice is discouraged. Churches closed, clergy monitored.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: -15,
                    internationalStandingModifier: -10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["regional"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "religion_controlled_tolerance",
                name: "Controlled Tolerance",
                description: "Limited worship permitted in registered venues under state oversight.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5
                ),
                beneficiaries: [],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "religion_state_church",
                name: "State Church",
                description: "Approved religious institutions operate under Party supervision.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: 10,
                    factionModifiers: ["regional": 10]
                ),
                beneficiaries: ["regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "religion_separation",
                name: "Separation",
                description: "Religion is a private matter. State neither promotes nor restricts faith.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    popularSupportModifier: 15,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists", "regional"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 25,
                delayedConsequenceSeverity: 3
            )
        ]

        let religionSlot = PolicySlot(
            slotId: "propaganda_religious_policy",
            name: "Religious Policy",
            description: "State policy toward religious practice and institutions.",
            institution: .propaganda,
            category: .social,
            options: religionOptions,
            defaultOptionId: "religion_controlled_tolerance"
        )
        slots.append(religionSlot)

        return slots
    }

    // MARK: - 8. FOREIGN AFFAIRS (3 Slots)

    static func createForeignSlots() -> [PolicySlot] {
        var slots: [PolicySlot] = []

        // SLOT 1: Alliance Policy
        let allianceOptions = [
            PolicyOption(
                id: "alliance_bloc_leadership",
                name: "Bloc Leadership",
                description: "Lead the socialist bloc. Allies follow our direction in international affairs.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    economicOutputModifier: -5,
                    internationalStandingModifier: 10,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "alliance_equal_partnership",
                name: "Equal Partnership",
                description: "Treat socialist allies as equal partners rather than subordinates.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "alliance_non_alignment",
                name: "Non-Alignment",
                description: "Pursue independent foreign policy without bloc commitments.",
                effects: PolicyEffects(
                    stabilityModifier: -5,
                    militaryLoyaltyModifier: -10,
                    internationalStandingModifier: 5,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard", "princelings"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 30,
                delayedConsequenceSeverity: 3
            ),
            PolicyOption(
                id: "alliance_pragmatic",
                name: "Pragmatic Relations",
                description: "Engage with all nations based on practical interests rather than ideology.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    economicOutputModifier: 15,
                    internationalStandingModifier: 20,
                    factionModifiers: ["reformists": 20]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 70,
                minimumPositionIndex: 7
            )
        ]

        let allianceSlot = PolicySlot(
            slotId: "foreign_alliance_policy",
            name: "Alliance Policy",
            description: "How we relate to our allies and the international socialist movement.",
            institution: .foreign,
            category: .political,
            options: allianceOptions,
            defaultOptionId: "alliance_bloc_leadership"
        )
        slots.append(allianceSlot)

        // SLOT 2: Border Policy
        let borderOptions = [
            PolicyOption(
                id: "border_closed",
                name: "Closed Borders",
                description: "Strict border controls. Citizens cannot leave without special permission.",
                effects: PolicyEffects(
                    stabilityModifier: 10,
                    popularSupportModifier: -15,
                    internationalStandingModifier: -15,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "border_controlled_entry",
                name: "Controlled Entry",
                description: "Visitors and emigrants processed through official channels.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    popularSupportModifier: 5,
                    internationalStandingModifier: 5
                ),
                beneficiaries: [],
                losers: [],
                minimumPowerRequired: 50,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "border_open_allies",
                name: "Open to Allies",
                description: "Free movement within the socialist bloc. Restrictions on capitalist countries.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    popularSupportModifier: 10,
                    internationalStandingModifier: 10,
                    factionModifiers: ["reformists": 10]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6
            ),
            PolicyOption(
                id: "border_selective",
                name: "Selective Opening",
                description: "Borders open based on economic and diplomatic considerations.",
                effects: PolicyEffects(
                    stabilityModifier: -10,
                    popularSupportModifier: 15,
                    economicOutputModifier: 10,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 15]
                ),
                beneficiaries: ["reformists"],
                losers: ["old_guard"],
                minimumPowerRequired: 65,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 25,
                delayedConsequenceSeverity: 3
            )
        ]

        let borderSlot = PolicySlot(
            slotId: "foreign_border_policy",
            name: "Border Policy",
            description: "How the state controls movement across borders.",
            institution: .foreign,
            category: .political,
            options: borderOptions,
            defaultOptionId: "border_closed"
        )
        slots.append(borderSlot)

        // SLOT 3: International Organizations
        let internationalOptions = [
            PolicyOption(
                id: "international_active",
                name: "Active Participation",
                description: "Participate fully in international organizations to spread influence.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    internationalStandingModifier: 15,
                    factionModifiers: ["reformists": 5]
                ),
                beneficiaries: ["reformists"],
                losers: [],
                isDefault: true,
                minimumPowerRequired: 40,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "international_selective",
                name: "Selective Engagement",
                description: "Participate only where it serves our interests. Boycott hostile forums.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    internationalStandingModifier: 0,
                    factionModifiers: ["old_guard": 5]
                ),
                beneficiaries: ["old_guard"],
                losers: [],
                minimumPowerRequired: 45,
                minimumPositionIndex: 5
            ),
            PolicyOption(
                id: "international_boycott",
                name: "Boycott",
                description: "Withdraw from capitalist-dominated international organizations.",
                effects: PolicyEffects(
                    stabilityModifier: 5,
                    internationalStandingModifier: -20,
                    factionModifiers: ["old_guard": 15]
                ),
                beneficiaries: ["old_guard"],
                losers: ["reformists"],
                minimumPowerRequired: 55,
                minimumPositionIndex: 6,
                immediateConsequenceChance: 20,
                delayedConsequenceSeverity: 2
            ),
            PolicyOption(
                id: "international_parallel",
                name: "Parallel Institutions",
                description: "Create alternative socialist international organizations to rival Western ones.",
                effects: PolicyEffects(
                    stabilityModifier: 0,
                    economicOutputModifier: -10,
                    internationalStandingModifier: -5,
                    factionModifiers: ["old_guard": 10]
                ),
                beneficiaries: ["old_guard", "princelings"],
                losers: ["reformists"],
                minimumPowerRequired: 60,
                minimumPositionIndex: 6
            )
        ]

        let internationalSlot = PolicySlot(
            slotId: "foreign_international_orgs",
            name: "International Organizations",
            description: "How we engage with international institutions and forums.",
            institution: .foreign,
            category: .political,
            options: internationalOptions,
            defaultOptionId: "international_active"
        )
        slots.append(internationalSlot)

        return slots
    }
}
