//
//  DiplomaticBriefingService.swift
//  Nomenklatura
//
//  Generates position-appropriate diplomatic briefings following CCP-style
//  information hierarchy. Lower ranks receive sanitized summaries while
//  senior officials see raw intelligence and operational details.
//

import Foundation

// MARK: - Diplomatic Briefing Service

@MainActor
class DiplomaticBriefingService {

    static let shared = DiplomaticBriefingService()

    // MARK: - Generate Daily Briefing

    /// Generate the daily diplomatic briefing for the current turn
    func generateDailyBriefing(for game: Game) -> DailyDiplomaticBriefing {
        var items: [DiplomaticBriefingItem] = []

        // Generate briefings from various sources
        items.append(contentsOf: generateRelationshipBriefings(game: game))
        items.append(contentsOf: generateTreatyBriefings(game: game))
        items.append(contentsOf: generateCrisisBriefings(game: game))
        items.append(contentsOf: generateIntelligenceBriefings(game: game))
        items.append(contentsOf: generateTradeBriefings(game: game))

        // Sort by urgency, then classification
        items.sort { item1, item2 in
            if item1.isUrgent != item2.isUrgent {
                return item1.isUrgent
            }
            return item1.classification > item2.classification
        }

        let dateString = formatGameDate(turn: game.turnNumber)

        return DailyDiplomaticBriefing(
            turnNumber: game.turnNumber,
            dateString: dateString,
            items: items
        )
    }

    // MARK: - Relationship Briefings

    private func generateRelationshipBriefings(game: Game) -> [DiplomaticBriefingItem] {
        var items: [DiplomaticBriefingItem] = []

        for country in game.foreignCountries {
            // Skip countries with stable, unremarkable relations
            let isRemarkable = abs(country.relationshipScore) > 40 ||
                              country.diplomaticTension > 50 ||
                              hasRecentChange(country: country, game: game)

            guard isRemarkable else { continue }

            let classification = classificationForRelationship(country)
            let bloc = PoliticalBloc(rawValue: country.bloc) ?? .nonAligned

            // Generate position-appropriate content
            let headline = generateRelationshipHeadline(country: country, bloc: bloc)
            let summary = generateRelationshipSummary(country: country)
            let fullDetails = generateRelationshipDetails(country: country, game: game)
            let rawIntel = generateRelationshipIntelligence(country: country, game: game)

            let item = DiplomaticBriefingItem(
                turnNumber: game.turnNumber,
                category: .bilateral,
                classification: classification,
                countryId: country.countryId,
                headline: headline,
                summary: summary,
                fullDetails: fullDetails,
                rawIntelligence: rawIntel,
                sensitiveData: [
                    "relationship": country.relationshipScore,
                    "tension": country.diplomaticTension,
                    "trade": country.tradeVolume
                ],
                isUrgent: country.diplomaticTension > 70,
                sourceAttribution: "Embassy \(country.name)",
                recommendedActions: generateRelationshipRecommendations(country: country)
            )

            items.append(item)
        }

        return items
    }

    private func generateRelationshipHeadline(country: ForeignCountry, bloc: PoliticalBloc) -> String {
        let status = DiplomaticStatus(rawValue: country.diplomaticStatus) ?? .neutral

        switch status {
        case .allied:
            return "\(country.name) remains a steadfast ally"
        case .friendly:
            return "Relations with \(country.name) continue positively"
        case .neutral:
            return "\(country.name) maintains neutral stance"
        case .strained:
            return "Tensions noted in \(country.name) relations"
        case .hostile:
            return "WARNING: \(country.name) relations deteriorating"
        case .atWar:
            return "URGENT: Active conflict with \(country.name)"
        case .noRelations:
            return "\(country.name) refuses diplomatic contact"
        }
    }

    private func generateRelationshipSummary(country: ForeignCountry) -> String {
        let status = DiplomaticStatus(rawValue: country.diplomaticStatus) ?? .neutral
        let bloc = PoliticalBloc(rawValue: country.bloc) ?? .nonAligned

        return """
        \(country.name) (\(bloc.displayName))
        Current Status: \(status.displayName)
        The Foreign Ministry reports that bilateral relations are \
        \(describeRelationshipTrend(score: country.relationshipScore)).
        """
    }

    private func generateRelationshipDetails(country: ForeignCountry, game: Game) -> String {
        let status = DiplomaticStatus(rawValue: country.diplomaticStatus) ?? .neutral

        var details = """
        BILATERAL ASSESSMENT: \(country.name.uppercased())

        Diplomatic Status: \(status.displayName)
        Relationship Index: \(country.relationshipScore)/100
        Tension Level: \(country.diplomaticTension)/100
        Trade Volume: \(country.tradeVolume) million rubles

        """

        // Add treaty information
        let treaties = country.treaties
        if !treaties.isEmpty {
            details += "Active Treaties: \(treaties.count)\n"
            for treaty in treaties {
                details += "  - \(treaty.type.displayName)\n"
            }
        } else {
            details += "Active Treaties: None\n"
        }

        details += "\nAssessment: \(assessRelationshipHealth(country: country))"

        return details
    }

    private func generateRelationshipIntelligence(country: ForeignCountry, game: Game) -> String {
        let govType = GovernmentType(rawValue: country.government) ?? .liberalDemocracy

        return """
        CLASSIFIED INTELLIGENCE REPORT: \(country.name.uppercased())

        Government Type: \(govType.displayName)
        Military Strength: \(country.militaryStrength)/100
        Economic Power: \(country.economicPower)/100
        Nuclear Capability: \(country.hasNuclearWeapons ? "CONFIRMED" : "None detected")

        ESPIONAGE ASSESSMENT:
        Their operations against us: \(country.espionageActivity)/100
        Our intelligence assets: \(country.ourIntelligenceAssets)/100
        Asset penetration: \(assessAssetPenetration(country: country))

        INTERNAL STABILITY:
        Government stability estimated at \(estimateStability(country: country))%.
        \(generateInternalAssessment(country: country))

        SOURCE: Intelligence Directorate, \(game.turnNumber)
        CLASSIFICATION: TOP SECRET
        """
    }

    private func generateRelationshipRecommendations(country: ForeignCountry) -> [String] {
        var recommendations: [String] = []

        if country.relationshipScore < -30 {
            recommendations.append("Consider diplomatic outreach to reduce tensions")
        }
        if country.diplomaticTension > 60 {
            recommendations.append("Increase intelligence monitoring")
        }
        if country.tradeVolume < 20 && country.relationshipScore > 0 {
            recommendations.append("Explore trade agreement opportunities")
        }
        if country.espionageActivity > 50 {
            recommendations.append("Recommend counterintelligence operations")
        }

        return recommendations
    }

    // MARK: - Treaty Briefings

    private func generateTreatyBriefings(game: Game) -> [DiplomaticBriefingItem] {
        var items: [DiplomaticBriefingItem] = []

        for country in game.foreignCountries {
            let treaties = country.treaties

            // Report on treaties expiring soon
            for treaty in treaties {
                if let expiration = treaty.expirationTurn,
                   expiration - game.turnNumber <= 5 {
                    let item = DiplomaticBriefingItem(
                        turnNumber: game.turnNumber,
                        category: .treaty,
                        classification: treaty.isSecret ? .secret : .confidential,
                        countryId: country.countryId,
                        headline: "\(treaty.type.displayName) with \(country.name) expires soon",
                        summary: "The \(treaty.type.displayName) with \(country.name) will expire in \(expiration - game.turnNumber) turns. Renewal negotiations should be considered.",
                        fullDetails: """
                        TREATY EXPIRATION NOTICE

                        Treaty: \(treaty.type.displayName)
                        Partner: \(country.name)
                        Signed: Turn \(treaty.signedTurn)
                        Expires: Turn \(expiration) (\(expiration - game.turnNumber) turns remaining)

                        Terms: \(treaty.terms)

                        Recommendation: Initiate renewal discussions or prepare for treaty lapse.
                        """,
                        isUrgent: expiration - game.turnNumber <= 2,
                        recommendedActions: ["Renew treaty", "Renegotiate terms", "Allow to expire"]
                    )
                    items.append(item)
                }
            }
        }

        return items
    }

    // MARK: - Crisis Briefings

    private func generateCrisisBriefings(game: Game) -> [DiplomaticBriefingItem] {
        var items: [DiplomaticBriefingItem] = []

        // Check for high-tension situations
        for country in game.foreignCountries {
            if country.diplomaticTension > 70 {
                let item = DiplomaticBriefingItem(
                    turnNumber: game.turnNumber,
                    category: .crisis,
                    classification: .secret,
                    countryId: country.countryId,
                    headline: "CRISIS ALERT: Elevated tensions with \(country.name)",
                    summary: "Diplomatic tensions with \(country.name) have reached dangerous levels. The situation requires immediate attention from senior leadership.",
                    fullDetails: """
                    CRISIS ASSESSMENT: \(country.name.uppercased())

                    Current Tension Level: \(country.diplomaticTension)/100
                    Risk of Escalation: \(country.diplomaticTension > 85 ? "CRITICAL" : "HIGH")

                    SITUATION:
                    Relations have deteriorated significantly. Without diplomatic intervention,
                    the situation may escalate to open confrontation.

                    MILITARY READINESS:
                    Their military strength: \(country.militaryStrength)/100
                    Nuclear capability: \(country.hasNuclearWeapons ? "YES - Exercise extreme caution" : "No")

                    RECOMMENDED RESPONSE OPTIONS:
                    1. Emergency diplomatic channel activation
                    2. Back-channel negotiations
                    3. Prepare contingency measures
                    """,
                    rawIntelligence: generateCrisisIntelligence(country: country),
                    sensitiveData: [
                        "tension": country.diplomaticTension,
                        "military": country.militaryStrength
                    ],
                    isUrgent: true,
                    sourceAttribution: "Crisis Monitoring Center",
                    recommendedActions: [
                        "Activate emergency diplomatic channel",
                        "Request Standing Committee review",
                        "Prepare military contingencies"
                    ]
                )
                items.append(item)
            }
        }

        return items
    }

    private func generateCrisisIntelligence(country: ForeignCountry) -> String {
        return """
        TOP SECRET - CRISIS INTELLIGENCE

        Subject: \(country.name) Threat Assessment

        MILITARY POSTURE:
        - Active duty forces: \(estimateMilitaryForces(strength: country.militaryStrength))
        - Naval positioning: \(assessNavalThreat(country: country))
        - Air force readiness: \(assessAirThreat(country: country))

        LEADERSHIP ANALYSIS:
        \(generateLeadershipAssessment(country: country))

        PROBABLE INTENTIONS:
        \(assessProbableIntentions(country: country))

        INTELLIGENCE CONFIDENCE: MODERATE
        Last Updated: This turn
        """
    }

    // MARK: - Intelligence Briefings

    private func generateIntelligenceBriefings(game: Game) -> [DiplomaticBriefingItem] {
        var items: [DiplomaticBriefingItem] = []

        for country in game.foreignCountries {
            // Only report significant espionage activity
            guard country.espionageActivity > 40 || country.ourIntelligenceAssets > 30 else { continue }

            let item = DiplomaticBriefingItem(
                turnNumber: game.turnNumber,
                category: .intelligence,
                classification: .topSecret,
                countryId: country.countryId,
                headline: "Intelligence activity report: \(country.name)",
                summary: "Significant intelligence activity detected involving \(country.name). Details restricted to authorized personnel.",
                fullDetails: """
                INTELLIGENCE OPERATIONS SUMMARY

                Target: \(country.name)

                THEIR OPERATIONS:
                Activity Level: \(country.espionageActivity)/100
                Assessment: \(assessTheirEspionage(activity: country.espionageActivity))

                OUR OPERATIONS:
                Asset Strength: \(country.ourIntelligenceAssets)/100
                Network Status: \(assessOurNetwork(assets: country.ourIntelligenceAssets))
                """,
                rawIntelligence: """
                EYES ONLY - INTELLIGENCE DIRECTORATE

                HUMINT Assets in \(country.name): \(country.ourIntelligenceAssets > 50 ? "Strong network" : "Limited penetration")
                Active Operations: \(country.ourIntelligenceAssets > 30 ? "Multiple ongoing" : "Minimal")

                COUNTERINTELLIGENCE:
                Known hostile agents: \(country.espionageActivity > 60 ? "Significant presence" : "Limited")
                Recommended action: \(country.espionageActivity > 70 ? "Immediate counterintelligence sweep" : "Continue monitoring")

                CLASSIFICATION: EYES ONLY
                """,
                sensitiveData: [
                    "their_ops": country.espionageActivity,
                    "our_assets": country.ourIntelligenceAssets
                ],
                isUrgent: country.espionageActivity > 80,
                sourceAttribution: "Intelligence Directorate"
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Trade Briefings

    private func generateTradeBriefings(game: Game) -> [DiplomaticBriefingItem] {
        var items: [DiplomaticBriefingItem] = []

        // Summarize major trading partners
        let majorPartners = game.foreignCountries.filter { $0.tradeVolume > 30 }

        if !majorPartners.isEmpty {
            let totalTrade = majorPartners.reduce(0) { $0 + $1.tradeVolume }

            let item = DiplomaticBriefingItem(
                turnNumber: game.turnNumber,
                category: .trade,
                classification: .restricted,
                headline: "Foreign trade summary",
                summary: """
                Total foreign trade volume: \(totalTrade) million rubles
                Major trading partners: \(majorPartners.count)
                Trade relations remain \(totalTrade > 100 ? "robust" : "modest").
                """,
                fullDetails: """
                FOREIGN TRADE ASSESSMENT

                Total Volume: \(totalTrade) million rubles

                MAJOR PARTNERS:
                \(majorPartners.map { "- \($0.name): \($0.tradeVolume) million" }.joined(separator: "\n"))

                TRADE BALANCE:
                Overall assessment: \(totalTrade > 150 ? "Strong" : totalTrade > 80 ? "Adequate" : "Needs improvement")

                Economic dependencies and vulnerabilities are detailed in the classified annex.
                """,
                sensitiveData: ["total_trade": totalTrade],
                recommendedActions: totalTrade < 80 ? ["Negotiate new trade agreements"] : nil
            )
            items.append(item)
        }

        return items
    }

    // MARK: - Situation Summary

    /// Generate a high-level diplomatic situation summary
    func generateSituationSummary(for game: Game) -> DiplomaticSituationSummary {
        let countries = game.foreignCountries

        let allies = countries.filter { $0.relationshipScore > 30 }
        let neutrals = countries.filter { $0.relationshipScore >= -30 && $0.relationshipScore <= 30 }
        let hostiles = countries.filter { $0.relationshipScore < -30 }

        let avgRelationship = countries.isEmpty ? 0 :
            countries.reduce(0) { $0 + $1.relationshipScore } / countries.count

        let maxTension = countries.map { $0.diplomaticTension }.max() ?? 0

        let activeTreaties = countries.flatMap { $0.treaties }.count

        let pendingCrises = countries.filter { $0.diplomaticTension > 70 }.count

        // Determine overall risk
        let risk: DiplomaticSituationSummary.DiplomaticRisk
        if maxTension > 85 || pendingCrises > 2 {
            risk = .critical
        } else if maxTension > 70 || pendingCrises > 0 {
            risk = .high
        } else if hostiles.count > allies.count {
            risk = .elevated
        } else if avgRelationship < 0 {
            risk = .moderate
        } else {
            risk = .low
        }

        // TODO: Track trends over multiple turns
        let relationshipTrend: DiplomaticSituationSummary.Trend = .stable
        let tensionTrend: DiplomaticSituationSummary.Trend = .stable

        return DiplomaticSituationSummary(
            turnNumber: game.turnNumber,
            allyCount: allies.count,
            neutralCount: neutrals.count,
            hostileCount: hostiles.count,
            averageRelationship: avgRelationship,
            maxTension: maxTension,
            activeTreaties: activeTreaties,
            pendingCrises: pendingCrises,
            overallRisk: risk,
            relationshipTrend: relationshipTrend,
            tensionTrend: tensionTrend
        )
    }

    // MARK: - Helper Methods

    private func classificationForRelationship(_ country: ForeignCountry) -> BriefingClassification {
        if country.diplomaticTension > 80 {
            return .topSecret
        } else if country.diplomaticTension > 60 {
            return .secret
        } else if abs(country.relationshipScore) > 50 {
            return .confidential
        } else {
            return .restricted
        }
    }

    private func hasRecentChange(country: ForeignCountry, game: Game) -> Bool {
        // TODO: Track relationship changes over turns
        return country.diplomaticTension > 40
    }

    private func describeRelationshipTrend(score: Int) -> String {
        if score > 60 { return "excellent and improving" }
        if score > 30 { return "positive and stable" }
        if score > -30 { return "neutral but require attention" }
        if score > -60 { return "strained and concerning" }
        return "hostile and deteriorating"
    }

    private func assessRelationshipHealth(country: ForeignCountry) -> String {
        let score = country.relationshipScore
        let tension = country.diplomaticTension

        if score > 50 && tension < 30 {
            return "Relations are healthy with strong foundations for continued cooperation."
        } else if score > 0 && tension < 50 {
            return "Relations are generally positive but require ongoing diplomatic maintenance."
        } else if score < 0 && tension > 50 {
            return "Relations are troubled. Recommend increased diplomatic engagement to prevent further deterioration."
        } else {
            return "Relations are unstable. Immediate attention required to prevent crisis."
        }
    }

    private func assessAssetPenetration(country: ForeignCountry) -> String {
        let assets = country.ourIntelligenceAssets
        if assets > 70 { return "Excellent - Deep penetration achieved" }
        if assets > 50 { return "Good - Solid network in place" }
        if assets > 30 { return "Moderate - Limited but functional" }
        return "Poor - Minimal presence, recommend expansion"
    }

    private func estimateStability(country: ForeignCountry) -> Int {
        // Simple estimate based on available data
        return max(20, min(90, 50 + country.economicPower / 5 - country.diplomaticTension / 4))
    }

    private func generateInternalAssessment(country: ForeignCountry) -> String {
        let stability = estimateStability(country: country)
        if stability > 70 {
            return "Government appears stable with strong popular support."
        } else if stability > 50 {
            return "Some internal pressures noted but regime remains secure."
        } else {
            return "Significant internal instability detected. Monitor for potential regime changes."
        }
    }

    private func assessTheirEspionage(activity: Int) -> String {
        if activity > 70 { return "CRITICAL - Active hostile operations detected" }
        if activity > 50 { return "HIGH - Significant intelligence gathering" }
        if activity > 30 { return "MODERATE - Standard diplomatic intelligence" }
        return "LOW - Minimal detected activity"
    }

    private func assessOurNetwork(assets: Int) -> String {
        if assets > 70 { return "STRONG - Extensive and reliable" }
        if assets > 50 { return "ADEQUATE - Functional coverage" }
        if assets > 30 { return "LIMITED - Gaps in coverage" }
        return "MINIMAL - Recommend expansion"
    }

    private func estimateMilitaryForces(strength: Int) -> String {
        if strength > 80 { return "Major power with global projection capability" }
        if strength > 60 { return "Regional power with significant forces" }
        if strength > 40 { return "Moderate conventional forces" }
        return "Limited military capability"
    }

    private func assessNavalThreat(country: ForeignCountry) -> String {
        if country.countryId == "uk" || country.countryId == "japan" {
            return "Significant naval presence in strategic waters"
        }
        return "Limited naval assets"
    }

    private func assessAirThreat(country: ForeignCountry) -> String {
        if country.militaryStrength > 70 {
            return "Modern air force with advanced capabilities"
        }
        return "Conventional air assets"
    }

    private func generateLeadershipAssessment(country: ForeignCountry) -> String {
        return """
        Current leadership maintains control. Decision-making appears
        \(country.diplomaticTension > 60 ? "increasingly aggressive" : "calculated and measured").
        """
    }

    private func assessProbableIntentions(country: ForeignCountry) -> String {
        if country.diplomaticTension > 80 {
            return "Hostile posture suggests preparation for confrontation. Recommend maximum vigilance."
        } else if country.diplomaticTension > 60 {
            return "Coercive diplomacy likely. Expect increased pressure but direct conflict not imminent."
        } else {
            return "Maintaining status quo. No immediate threat detected."
        }
    }

    private func formatGameDate(turn: Int) -> String {
        // Game starts in 1953, each turn is roughly 3 months
        let startYear = 1953
        let yearsElapsed = turn / 4
        let quarter = turn % 4

        let month = ["January", "April", "July", "October"][quarter]
        let year = startYear + yearsElapsed

        return "\(month) \(year)"
    }
}
