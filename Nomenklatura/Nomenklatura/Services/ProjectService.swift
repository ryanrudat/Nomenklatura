//
//  ProjectService.swift
//  Nomenklatura
//
//  Manages multi-turn projects (construction, reforms, etc.)
//  Handles creation, progression, and completion of long-term initiatives
//

import Foundation

class ProjectService {
    static let shared = ProjectService()

    private init() {}

    // MARK: - Project Creation

    /// Create a project based on scenario choice
    /// Call this after a player makes a decision that initiates a long-term project
    func createProjectFromChoice(
        game: Game,
        scenarioId: String,
        choiceDescription: String,
        projectType: ProjectType,
        title: String,
        description: String,
        responsibleCharacter: String? = nil,
        completionEffects: [String: Int] = [:],
        keywords: [String] = []
    ) {
        let project = PendingProject(
            projectType: projectType,
            title: title,
            description: description,
            startTurn: game.turnNumber,
            responsibleCharacterName: responsibleCharacter,
            initiatingScenarioId: scenarioId,
            completionEffects: completionEffects,
            keywords: keywords
        )

        game.addProject(project)

        #if DEBUG
        print("[ProjectService] Created project: \(title) (completes turn \(project.targetCompletionTurn))")
        #endif
    }

    /// Detect if a choice description suggests a long-term project
    /// Returns project info if detected, nil otherwise
    func detectProjectFromChoice(_ choiceDescription: String) -> DetectedProject? {
        let lowercased = choiceDescription.lowercased()

        // Construction patterns
        let constructionPatterns = [
            "build", "construct", "erect", "establish", "create facility",
            "new factory", "new building", "sports complex", "housing project",
            "infrastructure", "railway", "road construction"
        ]

        if constructionPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .construction,
                suggestedDuration: Int.random(in: 4...8),
                keywords: ["construction", "building"]
            )
        }

        // Reform patterns
        let reformPatterns = [
            "reform", "reorganize", "restructure", "modernize",
            "policy change", "new regulation", "institutional change"
        ]

        if reformPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .reform,
                suggestedDuration: Int.random(in: 3...5),
                keywords: ["reform", "policy"]
            )
        }

        // Investigation patterns
        let investigationPatterns = [
            "investigate", "inquiry", "examine", "probe",
            "audit", "review thoroughly", "look into"
        ]

        if investigationPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .investigation,
                suggestedDuration: Int.random(in: 2...4),
                keywords: ["investigation", "security"]
            )
        }

        // Industrial patterns
        let industrialPatterns = [
            "factory", "industrial", "production line",
            "manufacturing", "steel mill", "power plant"
        ]

        if industrialPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .industrialProject,
                suggestedDuration: Int.random(in: 4...8),
                keywords: ["industrial", "production"]
            )
        }

        // Military patterns
        let militaryPatterns = [
            "military operation", "deploy", "campaign",
            "mobilize", "military exercise"
        ]

        if militaryPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .militaryOperation,
                suggestedDuration: Int.random(in: 3...6),
                keywords: ["military", "operation"]
            )
        }

        // Diplomatic patterns
        let diplomaticPatterns = [
            "negotiate", "treaty", "diplomatic",
            "agreement", "summit", "delegation"
        ]

        if diplomaticPatterns.contains(where: { lowercased.contains($0) }) {
            return DetectedProject(
                type: .diplomaticProcess,
                suggestedDuration: Int.random(in: 2...5),
                keywords: ["diplomatic", "foreign"]
            )
        }

        return nil
    }

    // MARK: - Project Progression

    /// Update all active projects for the current turn
    /// Call this at the start of each turn
    func updateProjectsForTurn(game: Game) {
        var projects = game.pendingProjects

        for index in projects.indices {
            var project = projects[index]

            guard project.status == .inProgress else { continue }

            // Update progress
            project.updateProgress(currentTurn: game.turnNumber)

            projects[index] = project
        }

        game.pendingProjects = projects
    }

    /// Get projects that completed this turn
    /// Call this to check for completions and generate events
    func checkProjectCompletions(game: Game) -> [ProjectCompletion] {
        var completions: [ProjectCompletion] = []
        var projects = game.pendingProjects

        for index in projects.indices {
            var project = projects[index]

            if project.shouldComplete(currentTurn: game.turnNumber) {
                project.markCompleted()
                projects[index] = project

                let completion = ProjectCompletion(
                    project: project,
                    completionTurn: game.turnNumber
                )
                completions.append(completion)

                #if DEBUG
                print("[ProjectService] Project completed: \(project.title)")
                #endif
            }
        }

        game.pendingProjects = projects
        return completions
    }

    /// Apply completion effects to game state
    func applyCompletionEffects(completion: ProjectCompletion, game: Game) {
        let effects = completion.project.completionEffects

        for (stat, change) in effects {
            applyStat(stat, change: change, game: game)
        }
    }

    private func applyStat(_ stat: String, change: Int, game: Game) {
        switch stat.lowercased() {
        case "stability": game.stability = clamp(game.stability + change)
        case "popularsupport": game.popularSupport = clamp(game.popularSupport + change)
        case "militaryloyalty": game.militaryLoyalty = clamp(game.militaryLoyalty + change)
        case "eliteloyalty": game.eliteLoyalty = clamp(game.eliteLoyalty + change)
        case "treasury": game.treasury = clamp(game.treasury + change)
        case "industrialoutput": game.industrialOutput = clamp(game.industrialOutput + change)
        case "foodsupply": game.foodSupply = clamp(game.foodSupply + change)
        case "internationalstanding": game.internationalStanding = clamp(game.internationalStanding + change)
        case "standing": game.standing = clamp(game.standing + change)
        case "patronfavor": game.patronFavor = clamp(game.patronFavor + change)
        case "network": game.network = clamp(game.network + change)
        default: break
        }
    }

    private func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }

    // MARK: - Dynamic Event Generation

    /// Generate a dynamic event for a project completion
    func generateCompletionEvent(completion: ProjectCompletion, game: Game) -> DynamicEvent? {
        let project = completion.project

        // Create completion narrative
        let narrativeOptions = generateCompletionNarratives(for: project)
        let narrative = narrativeOptions.randomElement() ?? "The \(project.title) has been \(project.projectType.completionVerb)."

        // Generate event
        var event = DynamicEvent(
            eventType: .consequenceCallback,
            priority: .elevated,
            title: "Project Complete: \(project.title)",
            briefText: narrative,
            turnGenerated: game.turnNumber,
            isUrgent: false
        )

        // Add character info if available
        event.initiatingCharacterName = project.responsibleCharacterName

        // Add response option
        event.responseOptions = [
            EventResponse(
                id: "acknowledge",
                text: "Note the completion",
                effects: [:]
            )
        ]

        return event
    }

    private func generateCompletionNarratives(for project: PendingProject) -> [String] {
        let duration = RevolutionaryCalendar.formatDuration(turns: project.totalDurationTurns)

        switch project.projectType {
        case .construction:
            return [
                "After \(duration) of construction, the \(project.title) stands complete. Workers have exceeded expectations.",
                "The ribbon-cutting ceremony for the \(project.title) draws Party officials from across the capital.",
                "Construction crews have finished the \(project.title) ahead of schedule. A small miracle of socialist planning."
            ]

        case .reform:
            return [
                "The \(project.title) reform has been fully implemented across all relevant departments.",
                "After \(duration) of careful preparation, the new policies are now in effect.",
                "The bureaucracy has finally absorbed the changes. The \(project.title) is operational."
            ]

        case .investigation:
            return [
                "The investigation has concluded. Your agents present their findings.",
                "After \(duration), the inquiry has produced a comprehensive report.",
                "The investigation team delivers their final assessment on the matter."
            ]

        case .militaryOperation:
            return [
                "Military reports confirm the operation has achieved its objectives.",
                "After \(duration) of deployment, the troops are returning home.",
                "The General Staff reports mission accomplished."
            ]

        case .diplomaticProcess:
            return [
                "The negotiations have concluded successfully. Documents await your signature.",
                "After \(duration) of talks, an agreement has been reached.",
                "The diplomatic mission has returned with favorable terms."
            ]

        case .industrialProject:
            return [
                "The factory is now operational. The first products roll off the line.",
                "After \(duration), the industrial facility begins production.",
                "Workers celebrate as the new plant opens its doors."
            ]

        case .culturalInitiative:
            return [
                "The cultural program has concluded to great acclaim.",
                "After \(duration), the initiative has achieved its cultural objectives.",
                "The Ministry of Culture reports the program's successful completion."
            ]

        case .agricultureProgram:
            return [
                "The agricultural reforms have taken root across the countryside.",
                "After \(duration), the program shows measurable improvements in production.",
                "Regional reports confirm the agricultural initiative's success."
            ]
        }
    }

    // MARK: - Utility

    /// Cancel a project
    func cancelProject(projectId: UUID, reason: String, game: Game) {
        var projects = game.pendingProjects
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].markFailed(reason: reason, turn: game.turnNumber)
            game.pendingProjects = projects
        }
    }

    /// Delay a project
    func delayProject(projectId: UUID, additionalTurns: Int, reason: String, game: Game) {
        var projects = game.pendingProjects
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].targetCompletionTurn += additionalTurns
            projects[index].status = .delayed
            projects[index].addProgressUpdate(turn: game.turnNumber, message: reason, progressChange: -10)
            game.pendingProjects = projects
        }
    }

    /// Accelerate a project
    func accelerateProject(projectId: UUID, turnsReduced: Int, reason: String, game: Game) {
        var projects = game.pendingProjects
        if let index = projects.firstIndex(where: { $0.id == projectId }) {
            projects[index].targetCompletionTurn = max(
                game.turnNumber + 1,
                projects[index].targetCompletionTurn - turnsReduced
            )
            projects[index].status = .accelerated
            projects[index].addProgressUpdate(turn: game.turnNumber, message: reason, progressChange: 15)
            game.pendingProjects = projects
        }
    }
}

// MARK: - Supporting Types

struct DetectedProject {
    let type: ProjectType
    let suggestedDuration: Int
    let keywords: [String]
}

struct ProjectCompletion {
    let project: PendingProject
    let completionTurn: Int
}
