//
//  RevolutionaryCalendar.swift
//  Nomenklatura
//
//  Revolutionary Calendar system - The Party controls time itself
//  Years are counted from the founding of the Revolution (Year 1)
//

import Foundation

struct RevolutionaryCalendar {
    /// The current year when the game begins
    static let gameStartYear = 43

    /// The Revolution's founding year (Year 1)
    /// Internal reference only - never displayed to player
    private static let revolutionRealYear = 1915

    // MARK: - Date Formatting

    /// Standard format: "Year 43"
    static func format(_ year: Int) -> String {
        return "Year \(year)"
    }

    /// Long/formal format: "43rd Year of the Revolution"
    static func formatLong(_ year: Int) -> String {
        return "\(ordinal(year)) Year of the Revolution"
    }

    /// Short/compact format: "Y.43"
    static func formatShort(_ year: Int) -> String {
        return "Y.\(year)"
    }

    /// Range format: "Year 16-20"
    static func formatRange(_ startYear: Int, _ endYear: Int) -> String {
        return "Year \(startYear)-\(endYear)"
    }

    /// Disputed format: "Year 43 (disputed)"
    static func formatDisputed(_ year: Int) -> String {
        return "Year \(year) (disputed)"
    }

    /// Format with month: "Third Month, Year 43"
    static func formatWithMonth(_ year: Int, month: Int) -> String {
        let monthName = monthNames[safe: month - 1] ?? "Unknown Month"
        return "\(monthName), Year \(year)"
    }

    /// Full formal date: "15th day of the Third Month, 43rd Year of the Revolution"
    static func formatFull(day: Int, month: Int, year: Int) -> String {
        let monthName = monthNames[safe: month - 1] ?? "Unknown Month"
        return "\(ordinal(day)) day of the \(monthName), \(ordinal(year)) Year of the Revolution"
    }

    // MARK: - Revolutionary Month Names

    /// The Revolution renamed the months to remove bourgeois influence
    private static let monthNames = [
        "First Month",       // January
        "Second Month",      // February
        "Third Month",       // March
        "Fourth Month",      // April
        "Fifth Month",       // May
        "Sixth Month",       // June
        "Seventh Month",     // July
        "Eighth Month",      // August
        "Ninth Month",       // September
        "Tenth Month",       // October
        "Eleventh Month",    // November
        "Twelfth Month"      // December
    ]

    /// Standard month names for newspaper dates
    static let poeticMonthNames = [
        "January",
        "February",
        "March",
        "April",
        "May",
        "June",
        "July",
        "August",
        "September",
        "October",
        "November",
        "December"
    ]

    // MARK: - Turn to Date Conversion

    /// Days per turn - each turn represents 2 weeks (a fortnight)
    static let daysPerTurn = 14

    /// Starting month (1 = January/First Month)
    static let gameStartMonth = 1

    /// Starting day of the month
    static let gameStartDay = 1

    /// Days per month (approximate, using 30 for simplicity)
    private static let daysPerMonth = 30

    /// Days per year
    private static let daysPerYear = 365

    /// Convert a game turn to Revolutionary Year
    /// Each turn represents 2 weeks (14 days)
    static func yearFromTurn(_ turn: Int) -> Int {
        let totalDays = totalDaysElapsed(turn: turn)
        return gameStartYear + (totalDays / daysPerYear)
    }

    /// Get month (1-12) from turn
    /// Each turn = 2 weeks, so roughly 2 turns per month
    static func monthFromTurn(_ turn: Int) -> Int {
        let totalDays = totalDaysElapsed(turn: turn)
        let dayOfYear = totalDays % daysPerYear
        // Calculate month (each month ~30 days)
        let month = (dayOfYear / daysPerMonth) + gameStartMonth
        return ((month - 1) % 12) + 1  // Wrap around to 1-12
    }

    /// Get day of month from turn (1-28)
    /// Returns the approximate starting day of the 2-week period
    static func dayFromTurn(_ turn: Int) -> Int {
        let totalDays = totalDaysElapsed(turn: turn)
        let dayOfYear = totalDays % daysPerYear
        let dayOfMonth = (dayOfYear % daysPerMonth) + 1
        return min(28, max(1, dayOfMonth))  // Keep within 1-28 range
    }

    /// Calculate total days elapsed since game start
    private static func totalDaysElapsed(turn: Int) -> Int {
        // Turn 1 starts at day 0 (the first day)
        // Each subsequent turn adds 14 days
        return (turn - 1) * daysPerTurn
    }

    /// Get the full date components from a turn
    static func dateComponents(from turn: Int) -> (year: Int, month: Int, day: Int) {
        return (yearFromTurn(turn), monthFromTurn(turn), dayFromTurn(turn))
    }

    /// Format a turn as Revolutionary date
    static func formatTurn(_ turn: Int) -> String {
        let year = yearFromTurn(turn)
        return format(year)
    }

    /// Format a turn as short Revolutionary date
    static func formatTurnShort(_ turn: Int) -> String {
        let year = yearFromTurn(turn)
        return formatShort(year)
    }

    /// Format a turn with month
    static func formatTurnWithMonth(_ turn: Int) -> String {
        let year = yearFromTurn(turn)
        let month = monthFromTurn(turn)
        return formatWithMonth(year, month: month)
    }

    /// Format a turn with full date (day, month, year)
    static func formatTurnFull(_ turn: Int) -> String {
        let (year, month, day) = dateComponents(from: turn)
        let monthName = poeticMonthNames[safe: month - 1] ?? "Unknown"
        return "\(ordinal(day)) of \(monthName), \(format(year))"
    }

    /// Get a human-readable duration description
    /// e.g., "3 turns" = "6 weeks" or "approximately 1.5 months"
    static func formatDuration(turns: Int) -> String {
        let weeks = turns * 2
        if weeks < 4 {
            return "\(weeks) week\(weeks == 1 ? "" : "s")"
        } else {
            let months = Double(weeks) / 4.0
            if months == Double(Int(months)) {
                return "\(Int(months)) month\(Int(months) == 1 ? "" : "s")"
            } else {
                return String(format: "%.1f months", months)
            }
        }
    }

    // MARK: - Historical Eras

    enum HistoricalEra: String, CaseIterable {
        case revolutionaryFounding  // Year 1-5
        case firstFiveYearPlan      // Year 6-10
        case secondFiveYearPlan     // Year 11-15
        case greatPurge             // Year 16-20
        case preWarTension          // Year 21-25
        case greatPatrioticWar      // Year 26-30
        case postWarReconstruction  // Year 31-35
        case thawPeriod             // Year 36-43+

        var yearRange: ClosedRange<Int> {
            switch self {
            case .revolutionaryFounding: return 1...5
            case .firstFiveYearPlan: return 6...10
            case .secondFiveYearPlan: return 11...15
            case .greatPurge: return 16...20
            case .preWarTension: return 21...25
            case .greatPatrioticWar: return 26...30
            case .postWarReconstruction: return 31...35
            case .thawPeriod: return 36...100
            }
        }

        var displayName: String {
            switch self {
            case .revolutionaryFounding: return "Revolutionary Founding"
            case .firstFiveYearPlan: return "First Five-Year Plan"
            case .secondFiveYearPlan: return "Second Five-Year Plan"
            case .greatPurge: return "The Great Purge"
            case .preWarTension: return "Pre-War Tension"
            case .greatPatrioticWar: return "Great Patriotic War"
            case .postWarReconstruction: return "Post-War Reconstruction"
            case .thawPeriod: return "The Thaw"
            }
        }

        var description: String {
            switch self {
            case .revolutionaryFounding:
                return "The tumultuous years of civil war, consolidation of power, and the first purges of counter-revolutionary elements."
            case .firstFiveYearPlan:
                return "Rapid industrialization and collectivization transformed the nation. Millions died, but the foundations of socialism were laid."
            case .secondFiveYearPlan:
                return "Continued industrial expansion. The cult of personality around the Leader reached new heights."
            case .greatPurge:
                return "The Party turned upon itself. Show trials, mass arrests, and executions decimated the old revolutionary guard."
            case .preWarTension:
                return "Storm clouds gathered. The nation prepared for inevitable conflict while internal tensions simmered."
            case .greatPatrioticWar:
                return "The existential struggle against fascist invasion. Millions perished defending the motherland."
            case .postWarReconstruction:
                return "Recovery from the war's devastation. Ideological orthodoxy reasserted itself."
            case .thawPeriod:
                return "The Leader's death brought tentative reforms. Old certainties began to crack."
            }
        }

        var themes: [String] {
            switch self {
            case .revolutionaryFounding:
                return ["Civil war", "Land redistribution", "Counter-revolutionary suppression", "Party consolidation"]
            case .firstFiveYearPlan:
                return ["Industrialization", "Collectivization", "Worker mobilization", "Quota systems"]
            case .secondFiveYearPlan:
                return ["Heavy industry expansion", "Cult of personality", "Stakhanovite movement"]
            case .greatPurge:
                return ["Show trials", "Political terror", "Mass arrests", "Enemy hunting"]
            case .preWarTension:
                return ["Military buildup", "Foreign policy shifts", "Border tensions"]
            case .greatPatrioticWar:
                return ["Total mobilization", "Partisan resistance", "Victory", "Devastation"]
            case .postWarReconstruction:
                return ["Reconstruction", "Ideological campaigns", "Cold War beginnings"]
            case .thawPeriod:
                return ["De-Stalinization debates", "Reform vs orthodoxy", "Rehabilitation", "Cultural relaxation"]
            }
        }
    }

    /// Get the era for a given year
    static func era(for year: Int) -> HistoricalEra {
        for era in HistoricalEra.allCases {
            if era.yearRange.contains(year) {
                return era
            }
        }
        return .thawPeriod
    }

    // MARK: - Helper Functions

    /// Convert number to ordinal string
    static func ordinal(_ number: Int) -> String {
        let suffix: String
        let lastTwoDigits = number % 100
        let lastDigit = number % 10

        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            suffix = "th"
        } else {
            switch lastDigit {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }

        return "\(number)\(suffix)"
    }
}

