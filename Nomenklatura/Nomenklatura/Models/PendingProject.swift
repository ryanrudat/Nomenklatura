//
//  PendingProject.swift
//  Nomenklatura
//
//  Tracks ongoing projects that span multiple turns (construction, reforms, etc.)
//  Each turn = 2 weeks, so projects take realistic time to complete
//

import Foundation

// MARK: - Project Type

enum ProjectType: String, Codable, CaseIterable {
    case construction       // Buildings, infrastructure (4-8 turns)
    case reform             // Policy reforms, institutional changes (3-5 turns)
    case investigation      // Ongoing investigations (2-4 turns)
    case militaryOperation  // Military campaigns, deployments (3-6 turns)
    case diplomaticProcess  // Negotiations, treaties (2-5 turns)
    case industrialProject  // Factory construction, modernization (4-8 turns)
    case culturalInitiative // Cultural programs, exhibitions (2-4 turns)
    case agricultureProgram // Agricultural reforms, collectivization (4-6 turns)

    /// Default duration range in turns
    var defaultDurationRange: ClosedRange<Int> {
        switch self {
        case .construction: return 4...8
        case .reform: return 3...5
        case .investigation: return 2...4
        case .militaryOperation: return 3...6
        case .diplomaticProcess: return 2...5
        case .industrialProject: return 4...8
        case .culturalInitiative: return 2...4
        case .agricultureProgram: return 4...6
        }
    }

    /// Human-readable description of what completion means
    var completionVerb: String {
        switch self {
        case .construction: return "completed"
        case .reform: return "implemented"
        case .investigation: return "concluded"
        case .militaryOperation: return "achieved its objectives"
        case .diplomaticProcess: return "finalized"
        case .industrialProject: return "operational"
        case .culturalInitiative: return "concluded"
        case .agricultureProgram: return "fully implemented"
        }
    }
}

// MARK: - Project Status

enum ProjectStatus: String, Codable {
    case inProgress     // Normal progression
    case delayed        // Something slowed it down
    case accelerated    // Got extra resources
    case completed      // Done!
    case failed         // Cancelled or failed
    case blocked        // Waiting for something
}

// MARK: - Pending Project Model

struct PendingProject: Codable, Identifiable {
    let id: UUID
    let projectType: ProjectType
    let title: String                    // "Sports Complex Construction"
    let description: String              // Brief description of the project
    let startTurn: Int                   // Turn when project began
    var targetCompletionTurn: Int        // When it should complete
    var currentProgress: Int             // 0-100 percentage
    var status: ProjectStatus

    // Context
    let initiatingScenarioId: String?    // Scenario that started this
    let responsibleCharacterName: String? // Who's in charge

    // Effects on completion
    var completionEffects: [String: Int] // Stat changes when done
    var completionNarrative: String?     // What happens when complete

    // Progress events (updates shown to player)
    var progressUpdates: [ProjectProgressUpdate]

    // Keywords for AI context
    var keywords: [String]               // ["construction", "sports", "youth"]

    init(
        projectType: ProjectType,
        title: String,
        description: String,
        startTurn: Int,
        durationTurns: Int? = nil,
        responsibleCharacterName: String? = nil,
        initiatingScenarioId: String? = nil,
        completionEffects: [String: Int] = [:],
        completionNarrative: String? = nil,
        keywords: [String] = []
    ) {
        self.id = UUID()
        self.projectType = projectType
        self.title = title
        self.description = description
        self.startTurn = startTurn

        // Calculate target completion turn
        let duration = durationTurns ?? Int.random(in: projectType.defaultDurationRange)
        self.targetCompletionTurn = startTurn + duration

        self.currentProgress = 0
        self.status = .inProgress
        self.responsibleCharacterName = responsibleCharacterName
        self.initiatingScenarioId = initiatingScenarioId
        self.completionEffects = completionEffects
        self.completionNarrative = completionNarrative
        self.progressUpdates = []
        self.keywords = keywords
    }

    // MARK: - Computed Properties

    /// Total duration in turns
    var totalDurationTurns: Int {
        targetCompletionTurn - startTurn
    }

    /// Turns remaining until completion
    func turnsRemaining(currentTurn: Int) -> Int {
        max(0, targetCompletionTurn - currentTurn)
    }

    /// Duration description using RevolutionaryCalendar
    var durationDescription: String {
        RevolutionaryCalendar.formatDuration(turns: totalDurationTurns)
    }

    /// Remaining time description
    func remainingDescription(currentTurn: Int) -> String {
        let remaining = turnsRemaining(currentTurn: currentTurn)
        if remaining == 0 {
            return "imminent"
        }
        return RevolutionaryCalendar.formatDuration(turns: remaining)
    }

    /// Check if project should complete this turn
    func shouldComplete(currentTurn: Int) -> Bool {
        currentTurn >= targetCompletionTurn && status == .inProgress
    }

    // MARK: - Progress Management

    /// Calculate expected progress for current turn
    mutating func updateProgress(currentTurn: Int) {
        guard status == .inProgress else { return }

        let turnsElapsed = currentTurn - startTurn
        let totalDuration = totalDurationTurns

        // Base progress (linear)
        let expectedProgress = min(100, (turnsElapsed * 100) / totalDuration)
        currentProgress = expectedProgress
    }

    /// Add a progress update event
    mutating func addProgressUpdate(turn: Int, message: String, progressChange: Int = 0) {
        let update = ProjectProgressUpdate(
            turn: turn,
            message: message,
            progressChange: progressChange
        )
        progressUpdates.append(update)

        // Apply progress change
        if progressChange != 0 {
            currentProgress = max(0, min(100, currentProgress + progressChange))
        }
    }

    /// Mark as completed
    mutating func markCompleted() {
        status = .completed
        currentProgress = 100
    }

    /// Mark as failed
    mutating func markFailed(reason: String, turn: Int) {
        status = .failed
        addProgressUpdate(turn: turn, message: reason)
    }
}

// MARK: - Progress Update

struct ProjectProgressUpdate: Codable {
    let turn: Int
    let message: String
    let progressChange: Int  // +/- percentage points
}

// MARK: - Project Creation Helpers

extension PendingProject {
    /// Create a construction project
    static func construction(
        title: String,
        description: String,
        startTurn: Int,
        completionEffects: [String: Int] = [:],
        keywords: [String] = []
    ) -> PendingProject {
        PendingProject(
            projectType: .construction,
            title: title,
            description: description,
            startTurn: startTurn,
            completionEffects: completionEffects,
            keywords: ["construction"] + keywords
        )
    }

    /// Create a reform project
    static func reform(
        title: String,
        description: String,
        startTurn: Int,
        completionEffects: [String: Int] = [:],
        keywords: [String] = []
    ) -> PendingProject {
        PendingProject(
            projectType: .reform,
            title: title,
            description: description,
            startTurn: startTurn,
            completionEffects: completionEffects,
            keywords: ["reform", "policy"] + keywords
        )
    }

    /// Create an investigation project
    static func investigation(
        title: String,
        description: String,
        startTurn: Int,
        targetName: String? = nil,
        keywords: [String] = []
    ) -> PendingProject {
        var allKeywords = ["investigation", "security"]
        if let target = targetName {
            allKeywords.append(target.lowercased())
        }
        allKeywords.append(contentsOf: keywords)

        return PendingProject(
            projectType: .investigation,
            title: title,
            description: description,
            startTurn: startTurn,
            keywords: allKeywords
        )
    }
}
