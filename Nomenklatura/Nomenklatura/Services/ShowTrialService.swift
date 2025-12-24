//
//  ShowTrialService.swift
//  Nomenklatura
//
//  Manages show trial mechanics - from accusation to sentencing
//  Handles the theatrical nature of Soviet political justice
//

import Foundation

final class ShowTrialService {
    static let shared = ShowTrialService()

    private init() {}

    // MARK: - Trial Initiation

    /// Initiate a show trial against a character
    func initiateTrial(
        against character: GameCharacter,
        charges: [TrialCharge],
        game: Game
    ) -> ShowTrial {
        var trial = ShowTrial(
            defendantId: character.id,
            defendantName: character.name,
            defendantTitle: character.title,
            charges: charges,
            turnInitiated: game.turnNumber
        )

        // Record initial effects
        trial.internationalCondemnation = calculateInternationalCondemnation(for: character, charges: charges)

        // Update character status
        character.status = CharacterStatus.underInvestigation.rawValue
        character.statusChangedTurn = game.turnNumber
        character.fateNarrative = "Arrested on charges of \(formatCharges(charges))."

        // Store the trial
        game.initiateShowTrial(trial)

        return trial
    }

    // MARK: - Phase Advancement

    /// Advance a trial to the next phase
    func advanceTrialPhase(trial: inout ShowTrial, game: Game) -> DynamicEvent? {
        switch trial.phase {
        case .accusation:
            trial.phase = .confessionExtraction
            return generateConfessionExtractionEvent(trial: trial, game: game)

        case .confessionExtraction:
            // Determine if confession was obtained based on character traits
            let defendant = game.characters.first { $0.id == trial.defendantId }
            let confessionResult = determineConfessionOutcome(for: defendant, trial: trial)
            trial.confessionObtained = confessionResult.obtained
            trial.confessionType = confessionResult.type
            trial.phase = .publicTrial
            return generatePublicTrialEvent(trial: trial, confessionResult: confessionResult, game: game)

        case .publicTrial:
            trial.phase = .sentencing
            return generateSentencingEvent(trial: trial, game: game)

        case .sentencing:
            // Determine and apply sentence
            trial.sentence = determineSentence(for: trial, game: game)
            trial.phase = .completed
            applyTrialOutcome(trial: trial, game: game)
            return generateTrialConclusionEvent(trial: trial, game: game)

        case .completed:
            return nil
        }
    }

    /// Check if any trials need phase advancement this turn
    func checkTrialsForAdvancement(game: Game) -> [DynamicEvent] {
        var events: [DynamicEvent] = []
        var updatedTrials = game.activeShowTrials

        for (index, trial) in updatedTrials.enumerated() {
            // Trials advance every 1-2 turns depending on phase
            let turnsInPhase = game.turnNumber - trial.turnInitiated
            let shouldAdvance: Bool

            switch trial.phase {
            case .accusation:
                shouldAdvance = turnsInPhase >= 1
            case .confessionExtraction:
                shouldAdvance = turnsInPhase >= 2  // Takes longer for "questioning"
            case .publicTrial:
                shouldAdvance = turnsInPhase >= 1
            case .sentencing:
                shouldAdvance = true  // Sentences delivered immediately
            case .completed:
                shouldAdvance = false
            }

            if shouldAdvance {
                var mutableTrial = trial
                if let event = advanceTrialPhase(trial: &mutableTrial, game: game) {
                    events.append(event)
                    updatedTrials[index] = mutableTrial
                }
            }
        }

        game.activeShowTrials = updatedTrials
        return events
    }

    // MARK: - Confession Determination

    private struct ConfessionResult {
        let obtained: Bool
        let type: ConfessionType?
        let narrativeDetails: String
    }

    private func determineConfessionOutcome(
        for defendant: GameCharacter?,
        trial: ShowTrial
    ) -> ConfessionResult {
        guard let defendant = defendant else {
            return ConfessionResult(
                obtained: true,
                type: .scripted,
                narrativeDetails: "The defendant has confessed to all charges."
            )
        }

        // Calculate resistance based on personality
        let resistance = calculateResistance(for: defendant)
        let roll = Int.random(in: 1...100)

        if roll > resistance {
            // Confession obtained
            let confessionType = determineConfessionType(for: defendant, roll: roll, resistance: resistance)
            return ConfessionResult(
                obtained: true,
                type: confessionType,
                narrativeDetails: generateConfessionNarrative(defendant: defendant, type: confessionType)
            )
        } else {
            // Defendant resisted
            return ConfessionResult(
                obtained: false,
                type: .resisted,
                narrativeDetails: generateResistanceNarrative(defendant: defendant)
            )
        }
    }

    private func calculateResistance(for character: GameCharacter) -> Int {
        // High loyalty + low paranoid + moderate competence = more likely to resist
        var resistance = 30  // Base resistance

        // Loyal characters resist betraying principles
        resistance += character.personalityLoyal / 3

        // Less paranoid = less likely to break under pressure
        resistance += (100 - character.personalityParanoid) / 4

        // Competent characters may calculate odds better
        if character.personalityCompetent > 70 {
            resistance -= 10  // Smart enough to know resistance is futile
        }

        // Ruthless characters look out for themselves
        if character.personalityRuthless > 60 {
            resistance -= 15  // More likely to implicate others
        }

        return max(10, min(90, resistance))
    }

    private func determineConfessionType(for character: GameCharacter, roll: Int, resistance: Int) -> ConfessionType {
        let margin = roll - resistance

        // Large margin = full cooperation
        if margin > 40 && character.personalityRuthless > 50 {
            return .implicatedOthers  // Named others to save themselves
        } else if margin > 20 {
            return .scripted  // Read prepared confession
        } else if margin > 0 && roll < 80 {
            return .recanted  // Confessed but later tried to withdraw
        }

        return .scripted  // Default
    }

    // MARK: - Sentencing

    private func determineSentence(for trial: ShowTrial, game: Game) -> TrialSentence {
        var severityScore = 0

        // Sum charge severity
        for charge in trial.charges {
            severityScore += charge.severity
        }

        // Confession modifiers
        if let confessionType = trial.confessionType {
            let effects = confessionType.effects
            severityScore += effects.sentence
        }

        // Determine sentence based on total severity
        switch severityScore {
        case ...5:
            return .demotion
        case 6...10:
            return .exile
        case 11...15:
            return .imprisonment10
        case 16...20:
            return .imprisonment15
        case 21...25:
            return .imprisonment25
        default:
            return .execution
        }
    }

    // MARK: - Trial Outcome Application

    private func applyTrialOutcome(trial: ShowTrial, game: Game) {
        guard let defendant = game.characters.first(where: { $0.id == trial.defendantId }) else { return }

        // Apply sentence to character
        switch trial.sentence {
        case .execution:
            defendant.status = CharacterStatus.executed.rawValue
            defendant.fateNarrative = "Executed by firing squad following conviction for \(formatCharges(trial.charges))."

        case .imprisonment25, .imprisonment15, .imprisonment10:
            defendant.status = CharacterStatus.imprisoned.rawValue
            let years = trial.sentence == .imprisonment25 ? 25 : (trial.sentence == .imprisonment15 ? 15 : 10)
            defendant.fateNarrative = "Sentenced to \(years) years in labor camp for \(formatCharges(trial.charges))."
            defendant.canReturnFlag = trial.sentence == .imprisonment10  // Only 10-year sentences might return
            defendant.returnProbability = trial.sentence == .imprisonment10 ? 20 : 0

        case .exile:
            defendant.status = CharacterStatus.exiled.rawValue
            defendant.fateNarrative = "Exiled to remote region following conviction for \(formatCharges(trial.charges))."
            defendant.canReturnFlag = true
            defendant.returnProbability = 30

        case .demotion:
            defendant.status = CharacterStatus.active.rawValue
            defendant.positionIndex = max(0, (defendant.positionIndex ?? 1) - 2)
            defendant.fateNarrative = "Demoted and publicly reprimanded for \(formatCharges(trial.charges))."

        case .none:
            break
        }

        defendant.statusChangedTurn = game.turnNumber

        // Apply effects to game stats
        var trialCopy = trial

        // Intimidation from trial
        trialCopy.intimidationGained = calculateIntimidation(trial: trial)
        game.eliteLoyalty += trialCopy.intimidationGained / 10  // Fear breeds compliance

        // Martyr effect
        if trial.confessionType == .resisted || trial.confessionType == .recanted {
            trialCopy.martyrCreated = true
            game.popularSupport -= 5  // Some sympathy for the defiant
        }

        // International condemnation
        game.internationalStanding -= trialCopy.internationalCondemnation

        // Update stored trial
        game.updateShowTrial(trialCopy)

        // Mark trial as completed
        game.completeShowTrial(id: trial.id)
    }

    // MARK: - Event Generation

    private func generateConfessionExtractionEvent(trial: ShowTrial, game: Game) -> DynamicEvent {
        let defendant = game.characters.first { $0.id == trial.defendantId }
        let name = defendant?.name ?? trial.defendantName

        return DynamicEvent(
            eventType: .ambientTension,
            priority: .elevated,
            title: "Interrogation Proceeds",
            briefText: "\(name) is being questioned by State Security investigators. Methods of persuasion are being applied to obtain a full confession.",
            detailedText: """
            The interrogation of \(name) continues in the basement of the Lubyanka. \
            Investigators report that the subject has been cooperative following the application \
            of appropriate measures. A full confession is expected within days.

            The charges include \(formatCharges(trial.charges)). \
            State Security has indicated that additional co-conspirators may be named \
            during the questioning process.
            """,
            flavorText: "The wheels of socialist justice turn inexorably.",
            initiatingCharacterId: nil,
            relatedCharacterIds: [trial.defendantId],
            turnGenerated: game.turnNumber,
            expiresOnTurn: nil,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "press_harder",
                    text: "Demand investigators press harder for names of accomplices.",
                    shortText: "Press Harder",
                    effects: ["network": 5, "reputationRuthless": 5],
                    riskLevel: .medium,
                    followUpHint: "Additional targets may be identified."
                ),
                EventResponse(
                    id: "standard_methods",
                    text: "Allow the investigation to proceed at its normal pace.",
                    shortText: "Standard Methods",
                    effects: [:],
                    riskLevel: .low,
                    followUpHint: "The confession will come in time."
                ),
                EventResponse(
                    id: "observe_legality",
                    text: "Remind investigators to observe socialist legality.",
                    shortText: "Observe Legality",
                    effects: ["internationalStanding": 3, "reputationRuthless": -5],
                    riskLevel: .low,
                    followUpHint: "Foreign observers may note the proper procedures."
                )
            ]
        )
    }

    private func generatePublicTrialEvent(
        trial: ShowTrial,
        confessionResult: ConfessionResult,
        game: Game
    ) -> DynamicEvent {
        let defendant = game.characters.first { $0.id == trial.defendantId }
        let name = defendant?.name ?? trial.defendantName
        let title = defendant?.title ?? trial.defendantTitle ?? "former official"

        let confessionNarrative: String
        if confessionResult.obtained {
            confessionNarrative = """
            In a packed courtroom, \(name) confessed to monstrous crimes against the socialist state. \
            \(confessionResult.narrativeDetails)

            Workers attending the trial demanded the harshest possible punishment. \
            The Prosecutor cited irrefutable evidence of \(formatCharges(trial.charges)).
            """
        } else {
            confessionNarrative = """
            Despite intensive questioning, \(name) has refused to confess. \
            \(confessionResult.narrativeDetails)

            The Prosecutor has presented documentary evidence proving guilt beyond doubt. \
            The court will proceed to judgment based on the overwhelming material evidence.
            """
        }

        return DynamicEvent(
            eventType: .urgentInterruption,
            priority: .urgent,
            title: "Public Trial of \(name)",
            briefText: "The trial of \(name), \(title), has begun in the Hall of Columns. The world watches as socialist justice unfolds.",
            detailedText: confessionNarrative,
            flavorText: "\"The People's Court is in session.\"",
            initiatingCharacterId: nil,
            relatedCharacterIds: [trial.defendantId],
            turnGenerated: game.turnNumber,
            expiresOnTurn: nil,
            isUrgent: true,
            responseOptions: [
                EventResponse(
                    id: "demand_death",
                    text: "Publicly demand the ultimate penalty - death to enemies of the people!",
                    shortText: "Demand Death",
                    effects: ["reputationRuthless": 10, "internationalStanding": -5],
                    riskLevel: .medium,
                    followUpHint: "Your ruthlessness will be remembered."
                ),
                EventResponse(
                    id: "let_court_decide",
                    text: "Allow the court to determine the appropriate sentence.",
                    shortText: "Trust the Court",
                    effects: [:],
                    riskLevel: .low,
                    followUpHint: "Socialist legality will be observed."
                ),
                EventResponse(
                    id: "show_mercy",
                    text: "Privately suggest the court consider a lighter sentence.",
                    shortText: "Suggest Leniency",
                    effects: ["reputationLoyal": 5, "reputationRuthless": -10],
                    riskLevel: .high,
                    followUpHint: "Mercy can be mistaken for weakness."
                )
            ]
        )
    }

    private func generateSentencingEvent(trial: ShowTrial, game: Game) -> DynamicEvent {
        let defendant = game.characters.first { $0.id == trial.defendantId }
        let name = defendant?.name ?? trial.defendantName

        // Calculate preliminary sentence for the event
        let preliminarySentence = determineSentence(for: trial, game: game)

        return DynamicEvent(
            eventType: .ambientTension,
            priority: .elevated,
            title: "Verdict Delivered",
            briefText: "The People's Court has delivered its verdict against \(name).",
            detailedText: """
            After deliberation lasting \(Int.random(in: 15...45)) minutes, the People's Court \
            has reached its verdict. The defendant was found guilty on all counts.

            Sentence: \(preliminarySentence.displayName)

            The prosecutor praised the vigilance of State Security in uncovering this nest of traitors. \
            Workers' delegations attending the trial expressed satisfaction that socialist justice has prevailed.
            """,
            flavorText: "\"The Revolution defends itself.\"",
            initiatingCharacterId: nil,
            relatedCharacterIds: [trial.defendantId],
            turnGenerated: game.turnNumber,
            expiresOnTurn: nil,
            isUrgent: false,
            responseOptions: [
                EventResponse(
                    id: "acknowledge_justice",
                    text: "Express satisfaction that enemies have been brought to justice.",
                    shortText: "Justice Served",
                    effects: ["eliteLoyalty": 3],
                    riskLevel: .low,
                    followUpHint: nil
                ),
                EventResponse(
                    id: "remain_silent",
                    text: "Make no public comment on the verdict.",
                    shortText: "No Comment",
                    effects: [:],
                    riskLevel: .low,
                    followUpHint: nil
                )
            ]
        )
    }

    private func generateTrialConclusionEvent(trial: ShowTrial, game: Game) -> DynamicEvent {
        let defendant = game.characters.first { $0.id == trial.defendantId }
        let name = defendant?.name ?? trial.defendantName
        let sentence = trial.sentence ?? .imprisonment10

        var conclusionText: String
        switch sentence {
        case .execution:
            conclusionText = """
            The sentence against \(name) has been carried out. At dawn, in the courtyard of \
            the Lubyanka, the traitor faced the consequences of betraying the socialist motherland.

            State media reports that \(name)'s final words were incoherent pleas for mercy. \
            The Revolution has defended itself against another enemy.
            """
        case .imprisonment25, .imprisonment15, .imprisonment10:
            let years = sentence == .imprisonment25 ? 25 : (sentence == .imprisonment15 ? 15 : 10)
            conclusionText = """
            \(name) has been transferred to a labor camp in the northern territories to serve \
            a sentence of \(years) years. The former official will contribute to socialist construction \
            through honest labor - something they failed to do in their previous position.
            """
        case .exile:
            conclusionText = """
            \(name) has been exiled to a remote collective farm in Kazakhstan. Stripped of all \
            honors and privileges, the former official will live out their days far from the centers of power.
            """
        case .demotion:
            conclusionText = """
            In an unusual display of socialist mercy, \(name) has been given the opportunity for \
            rehabilitation through honest work. Demoted and publicly reprimanded, the official \
            must prove their worthiness to serve the people.
            """
        }

        return DynamicEvent(
            eventType: .worldNews,
            priority: .normal,
            title: "Case Concluded",
            briefText: "The case of \(name) has reached its conclusion.",
            detailedText: conclusionText,
            flavorText: "\"Let this serve as a warning to all enemies of the people.\"",
            initiatingCharacterId: nil,
            relatedCharacterIds: [trial.defendantId],
            turnGenerated: game.turnNumber,
            expiresOnTurn: nil,
            isUrgent: false,
            responseOptions: []
        )
    }

    // MARK: - Helpers

    private func formatCharges(_ charges: [TrialCharge]) -> String {
        if charges.count == 1 {
            return charges[0].displayName.lowercased()
        } else if charges.count == 2 {
            return "\(charges[0].displayName.lowercased()) and \(charges[1].displayName.lowercased())"
        } else {
            let allButLast = charges.dropLast().map { $0.displayName.lowercased() }.joined(separator: ", ")
            return "\(allButLast), and \(charges.last!.displayName.lowercased())"
        }
    }

    private func calculateInternationalCondemnation(for character: GameCharacter, charges: [TrialCharge]) -> Int {
        var condemnation = 0

        // Higher position = more international attention
        condemnation += (character.positionIndex ?? 0) * 2

        // Execution-worthy charges draw more scrutiny
        for charge in charges {
            if charge.severity >= 8 {
                condemnation += 3
            }
        }

        return min(20, condemnation)
    }

    private func calculateIntimidation(trial: ShowTrial) -> Int {
        var intimidation = 0

        // Sentence severity
        switch trial.sentence {
        case .execution:
            intimidation += 30
        case .imprisonment25:
            intimidation += 20
        case .imprisonment15:
            intimidation += 15
        case .imprisonment10:
            intimidation += 10
        case .exile:
            intimidation += 5
        case .demotion:
            intimidation += 2
        case .none:
            break
        }

        // Confession type affects message
        if trial.confessionObtained {
            intimidation += 10  // Shows the system works
        }
        if trial.confessionType == .implicatedOthers {
            intimidation += 15  // Everyone is watching their backs
        }

        return intimidation
    }

    private func generateConfessionNarrative(defendant: GameCharacter, type: ConfessionType) -> String {
        let name = defendant.name

        switch type {
        case .scripted:
            return """
            With head bowed, \(name) read from a prepared statement, confessing to the crimes \
            in detail. The confession was complete and unreserved.
            """
        case .implicatedOthers:
            return """
            In a desperate bid for leniency, \(name) not only confessed but named additional \
            co-conspirators. State Security is following up on these leads. The defendant \
            pleaded for the court's mercy in exchange for this cooperation.
            """
        case .recanted:
            return """
            \(name) initially confessed during questioning but attempted to recant the confession \
            in open court, claiming it was coerced. The court noted this as evidence of continuing \
            counter-revolutionary attitudes and lack of genuine repentance.
            """
        case .resisted:
            return """
            Despite all efforts, \(name) refused to confess, maintaining innocence throughout. \
            This defiance was noted by the court as evidence of hardened counter-revolutionary \
            character.
            """
        }
    }

    private func generateResistanceNarrative(defendant: GameCharacter) -> String {
        let name = defendant.name

        let narratives = [
            """
            \(name) maintained an attitude of defiance throughout interrogation, refusing to \
            sign any confession despite intensive questioning. The investigators noted a \
            disturbing commitment to counter-revolutionary principles.
            """,
            """
            Throughout the questioning, \(name) remained silent or gave only name and title. \
            Such resistance, while ultimately futile against the weight of evidence, was noted \
            as evidence of the defendant's hardened criminal character.
            """,
            """
            \(name) attempted to turn the interrogation into a political debate, spouting \
            counter-revolutionary slogans and refusing to acknowledge the legitimacy of the \
            charges. This only deepened the severity of the case against them.
            """
        ]

        return narratives.randomElement()!
    }
}
