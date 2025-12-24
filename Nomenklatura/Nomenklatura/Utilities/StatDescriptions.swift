//
//  StatDescriptions.swift
//  Nomenklatura
//
//  Descriptions and explanations for all game stats
//

import Foundation

// MARK: - Stat Description Model

struct StatDescription {
    let key: String
    let name: String
    let icon: String
    let description: String
    let lowWarning: String
    let highBenefit: String
    let tips: [String]
    let isPersonal: Bool
}

// MARK: - Stat Descriptions Data

enum StatDescriptions {

    // MARK: - National Stats

    static let nationalStats: [StatDescription] = [
        StatDescription(
            key: "stability",
            name: "Stability",
            icon: "building.columns.fill",
            description: "The overall order and control of the state. Reflects public calm, institutional function, and absence of unrest.",
            lowWarning: "Below 30: Risk of demonstrations, strikes, or regional uprisings. Other factions may attempt to seize power.",
            highBenefit: "Above 70: Easier to push through policies, fewer crises emerge. The Party apparatus functions smoothly.",
            tips: [
                "Avoid sudden, drastic policy changes",
                "Suppress dissent before it spreads",
                "Maintain adequate food supply",
                "Keep the security apparatus strong"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "popularSupport",
            name: "Popular Support",
            icon: "person.3.fill",
            description: "The people's faith in the Party and its leadership. High support means compliance; low support breeds resistance.",
            lowWarning: "Below 30: Workers may strike, peasants may hoard grain, protests become harder to suppress without military action.",
            highBenefit: "Above 70: Production quotas are met willingly, propaganda is believed, denunciations come easily.",
            tips: [
                "Ensure food supply remains adequate",
                "Avoid harsh crackdowns on workers",
                "Celebrate victories (real or fabricated)",
                "Blame failures on saboteurs"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "militaryLoyalty",
            name: "Military Loyalty",
            icon: "shield.fill",
            description: "The Red Army's loyalty to the Party leadership. An disloyal military is the greatest threat to any regime.",
            lowWarning: "Below 40: Generals may refuse orders, or worse, may be approached by rivals plotting a coup.",
            highBenefit: "Above 70: The military will enforce any order without question. Coup attempts are reported immediately.",
            tips: [
                "Keep military budgets adequate",
                "Avoid purging too many officers",
                "Give the military foreign victories",
                "Place loyalists in key commands"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "eliteLoyalty",
            name: "Elite Loyalty",
            icon: "crown.fill",
            description: "The loyalty of the Party nomenklatura - the bureaucrats, managers, and officials who run the state.",
            lowWarning: "Below 40: Officials may sabotage your directives, leak damaging information, or join rival factions.",
            highBenefit: "Above 70: Your orders are carried out efficiently, information flows freely, promotions go to your allies.",
            tips: [
                "Distribute patronage strategically",
                "Avoid purging loyal supporters",
                "Protect those who protect you",
                "Punish betrayal swiftly"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "treasury",
            name: "Treasury",
            icon: "banknote.fill",
            description: "State financial resources. Money buys loyalty, funds projects, and maintains the military.",
            lowWarning: "Below 30: Unable to fund military operations, bribe officials, or maintain infrastructure. Vulnerable to pressure.",
            highBenefit: "Above 70: Can launch major initiatives, buy off rivals, and weather any crisis with resources to spare.",
            tips: [
                "Avoid expensive foreign adventures",
                "Keep industrial output high",
                "Extract resources from satellite states",
                "Cut waste in the bureaucracy"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "industrialOutput",
            name: "Industrial Output",
            icon: "gearshape.2.fill",
            description: "Factory production and economic productivity. The foundation of the Socialist Republic's power and prestige.",
            lowWarning: "Below 30: Quotas cannot be met, shortages spread, the economy enters crisis. Treasury depletes rapidly.",
            highBenefit: "Above 70: Excess production can be exported, military can be equipped, the people have consumer goods.",
            tips: [
                "Appoint competent managers",
                "Avoid disrupting production with purges",
                "Invest in new factories",
                "Set realistic quotas"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "foodSupply",
            name: "Food Supply",
            icon: "leaf.fill",
            description: "Agricultural production and food distribution. An hungry population is a dangerous population.",
            lowWarning: "Below 30: Famine conditions emerge. Popular support collapses. Unrest becomes inevitable.",
            highBenefit: "Above 70: People are fed and content. Food can even be exported for hard currency.",
            tips: [
                "Avoid aggressive collectivization",
                "Maintain distribution networks",
                "Import grain if necessary",
                "Blame shortages on kulaks"
            ],
            isPersonal: false
        ),
        StatDescription(
            key: "internationalStanding",
            name: "International Standing",
            icon: "globe",
            description: "The nation's reputation and influence abroad. Affects diplomacy, trade, and foreign pressure.",
            lowWarning: "Below 30: Isolation, sanctions, embargoes. Foreign powers may support internal opposition.",
            highBenefit: "Above 70: Favorable trade terms, diplomatic victories, influence over satellite states.",
            tips: [
                "Avoid publicized atrocities",
                "Support revolutionary movements abroad",
                "Win prestigious competitions",
                "Maintain a strong military posture"
            ],
            isPersonal: false
        )
    ]

    // MARK: - Personal Stats

    static let personalStats: [StatDescription] = [
        StatDescription(
            key: "standing",
            name: "Standing",
            icon: "person.fill.checkmark",
            description: "Your reputation and influence within the Party hierarchy. Determines promotion eligibility and political survival.",
            lowWarning: "Below 20: Vulnerable to purges, may be demoted or 'retired.' Others sense weakness.",
            highBenefit: "Above 70: Eligible for senior positions, your voice carries weight, rivals hesitate to move against you.",
            tips: [
                "Complete decisions successfully",
                "Build patron and faction relationships",
                "Avoid spectacular failures",
                "Take credit for successes"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "patronFavor",
            name: "Patron Favor",
            icon: "hand.thumbsup.fill",
            description: "Your relationship with your patron - the senior figure who protects and promotes you.",
            lowWarning: "Below 30: Your patron may abandon you, leaving you vulnerable. Promotion becomes impossible.",
            highBenefit: "Above 70: Your patron actively promotes you, protects you from rivals, shares intelligence.",
            tips: [
                "Support your patron publicly",
                "Deliver results they can claim credit for",
                "Never outshine them too obviously",
                "Warn them of threats"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "rivalThreat",
            name: "Rival Threat",
            icon: "exclamationmark.triangle.fill",
            description: "How dangerous your primary rival is to you. High threat means they're actively working to destroy you.",
            lowWarning: "Above 70: Your rival is close to striking. They have evidence, allies, and opportunity.",
            highBenefit: "Below 30: Your rival is weakened, distracted, or has given up. You can focus on advancement.",
            tips: [
                "Gather intelligence on rivals",
                "Build alliances against them",
                "Undermine their position quietly",
                "Strike when they show weakness"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "network",
            name: "Network",
            icon: "point.3.connected.trianglepath.dotted",
            description: "Your web of informants, allies, and contacts throughout the system. Information is power.",
            lowWarning: "Below 20: You're blind to threats and opportunities. Rivals can move against you unseen.",
            highBenefit: "Above 60: You hear of plots before they mature, learn secrets, and can coordinate complex schemes.",
            tips: [
                "Cultivate contacts in all departments",
                "Plant allies in rival organizations",
                "Trade favors for information",
                "Protect your informants"
            ],
            isPersonal: true
        )
    ]

    // MARK: - Reputation Stats

    static let reputationStats: [StatDescription] = [
        StatDescription(
            key: "reputationCompetent",
            name: "Reputation: Competent",
            icon: "star.fill",
            description: "Your reputation for getting things done. Competent officials are valued and protected.",
            lowWarning: "Below 30: Seen as a bungler. Failures are blamed on you, successes credited to others.",
            highBenefit: "Above 70: Trusted with important tasks. Your recommendations are followed.",
            tips: [
                "Deliver on promises",
                "Solve problems efficiently",
                "Avoid being associated with failures",
                "Document your successes"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "reputationLoyal",
            name: "Reputation: Loyal",
            icon: "heart.fill",
            description: "Your reputation for loyalty to superiors and the Party. Loyalty is valued, but can limit ambition.",
            lowWarning: "Below 30: Seen as unreliable, potentially treacherous. Patrons won't invest in you.",
            highBenefit: "Above 70: Trusted with sensitive tasks, but may be passed over as 'too useful where you are.'",
            tips: [
                "Support your patron publicly",
                "Never criticize superiors openly",
                "Report on disloyal colleagues",
                "Balance loyalty with ambition"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "reputationCunning",
            name: "Reputation: Cunning",
            icon: "eye.fill",
            description: "Your reputation for political skill and manipulation. The cunning survive but are also feared.",
            lowWarning: "Below 30: Seen as naive, easy to outmaneuver. Others will take advantage.",
            highBenefit: "Above 70: Feared and respected. Others hesitate to move against you openly.",
            tips: [
                "Play factions against each other",
                "Keep your true intentions hidden",
                "Build intelligence networks",
                "Strike at unexpected moments"
            ],
            isPersonal: true
        ),
        StatDescription(
            key: "reputationRuthless",
            name: "Reputation: Ruthless",
            icon: "bolt.fill",
            description: "Your reputation for doing whatever is necessary. Ruthlessness is effective but creates enemies.",
            lowWarning: "Below 30: Seen as soft, someone who can be pushed around. Others won't fear your retaliation.",
            highBenefit: "Above 70: Feared. Others won't cross you lightly, but will unite against you if given the chance.",
            tips: [
                "Punish betrayal visibly",
                "Don't hesitate when action is needed",
                "Make examples of enemies",
                "Balance with occasional mercy"
            ],
            isPersonal: true
        )
    ]

    // MARK: - Lookup

    static func description(for key: String) -> StatDescription? {
        if let stat = nationalStats.first(where: { $0.key == key }) {
            return stat
        }
        if let stat = personalStats.first(where: { $0.key == key }) {
            return stat
        }
        if let stat = reputationStats.first(where: { $0.key == key }) {
            return stat
        }
        return nil
    }

    static var allStats: [StatDescription] {
        nationalStats + personalStats + reputationStats
    }
}
