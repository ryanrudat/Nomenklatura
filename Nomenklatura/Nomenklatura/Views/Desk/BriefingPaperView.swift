//
//  BriefingPaperView.swift
//  Nomenklatura
//
//  The document-style briefing paper component
//

import SwiftUI

struct BriefingPaperView: View {
    let scenario: Scenario
    let turnNumber: Int
    var game: Game? = nil  // Optional for atmosphere generation
    @Environment(\.theme) var theme

    // MARK: - Cached Random Values (generated once on appear, not every render)
    // This prevents content "flickering" when SwiftUI re-renders the view

    @State private var cachedDate: String = ""
    @State private var cachedAtmosphere: String? = nil
    @State private var cachedEntrance: String = ""
    @State private var hasInitialized: Bool = false

    /// Generate formatted date using Revolutionary Calendar
    /// Each turn = 2 weeks, date is consistent for the turn
    private func generateFormattedDate() -> String {
        return RevolutionaryCalendar.formatTurnFull(turnNumber)
    }

    /// Category-based stamp text (deterministic, no caching needed)
    private var stampText: String? {
        switch scenario.category {
        case .introduction:
            return "NEW ASSIGNMENT"
        case .crisis:
            return "URGENT"
        case .routine:
            return "MEMO"
        case .opportunity:
            return "NOTICE"
        case .character:
            return "PRIVATE"
        // Non-decision events don't need stamps
        case .routineDay:
            return nil
        case .newspaper:
            return nil
        case .characterMoment:
            return nil
        case .tensionBuilder:
            return nil
        }
    }

    /// Generate atmospheric introduction (called once on appear)
    private func generateAtmosphereIntro() -> String? {
        guard let game = game else { return nil }
        return NarrativeGenerator.shared.generateAtmosphere(for: .briefing, game: game)
    }

    /// Portrait image name (if asset exists)
    private var portraitImageName: String? {
        // Map character names to asset names
        // Returns nil if no custom portrait exists (will use initials fallback)
        let nameToAsset: [String: String] = [
            "Director Wallace": "WallacePortrait",
            "Secretary Kennedy": "KennedyPortrait",
            "General Anderson": "AndersonPortrait",
            "Comrade Peterson": "PetersonPortrait",
            "Sasha": "SashaPortrait",
            // Add more as portraits are created
        ]
        return nameToAsset[scenario.presenterName]
    }

    /// Generate character entrance description (called once on appear)
    private func generateEntranceDescription() -> String {
        // Default entrance descriptions that hint at character personality
        let entrances: [String: [String]] = [
            "Director Wallace": [
                "enters without knocking, his boots echoing on the floor",
                "appears at your door, expression unreadable",
                "materializes silently, as if he'd been waiting outside"
            ],
            "Secretary Kennedy": [
                "arrives with a diplomatic smile that doesn't reach his eyes",
                "enters, glancing at the window before speaking",
                "appears, papers clutched carefully to his chest"
            ],
            "General Anderson": [
                "strides in, medals clinking softly",
                "enters with military precision",
                "appears, back straight as a parade ground flagpole"
            ],
            "Comrade Peterson": [
                "shuffles in, avoiding your gaze",
                "enters hesitantly, clearing his throat",
                "appears with the look of a man bearing bad news"
            ]
        ]

        if let characterEntrances = entrances[scenario.presenterName] {
            return characterEntrances.randomElement() ?? "enters"
        }

        // Generic fallbacks based on category
        switch scenario.category {
        case .introduction:
            return "straightens papers on your desk"
        case .crisis:
            return "enters urgently, face taut with concern"
        case .routine:
            return "enters with practiced formality"
        case .opportunity:
            return "enters with a knowing look"
        case .character:
            return "enters and closes the door carefully behind them"
        // Non-decision events have quieter entrances
        case .routineDay:
            return "is already present, sorting through papers"
        case .newspaper:
            return "" // Newspapers don't have presenters entering
        case .characterMoment:
            return "passes by briefly"
        case .tensionBuilder:
            return "delivers a message and departs"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1950s Official Memo Header
            HStack(alignment: .top) {
                // Red classification stripe
                Rectangle()
                    .fill(scenario.requiresDecision ? FiftiesColors.urgentRed : FiftiesColors.leatherBrown)
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    // Document type
                    Text("OFFICIAL MEMORANDUM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(FiftiesColors.fadedInk)

                    // Date line
                    Text("DATE: \(cachedDate.uppercased())")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                }

                Spacer()

                // Rubber stamp
                if let stamp = stampText {
                    RubberStamp(
                        text: stamp,
                        stampType: scenario.category == .crisis ? .urgent : .classified,
                        rotation: -8,
                        size: .medium
                    )
                }
            }
            .padding(.bottom, 12)

            // Typewriter divider
            Text(String(repeating: "=", count: 45))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.3))
                .padding(.bottom, 12)

            // Atmosphere intro (if game context available)
            if let atmosphere = cachedAtmosphere {
                Text(atmosphere)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundColor(FiftiesColors.fadedInk)
                    .lineSpacing(4)
                    .padding(.bottom, 14)
            }

            // Advisor attribution with portrait - dossier style
            HStack(alignment: .top, spacing: 14) {
                // Character portrait with photo corners
                if !scenario.presenterName.isEmpty {
                    FiftiesDossierPhoto(
                        name: scenario.presenterName,
                        imageName: portraitImageName,
                        title: nil,
                        size: 55,
                        showStaple: false
                    )
                }

                VStack(alignment: .leading, spacing: 3) {
                    // FROM: line
                    HStack(spacing: 6) {
                        Text("FROM:")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)

                        // Character name (tappable if game available)
                        if let game = game {
                            TappableName(name: scenario.presenterName, game: game)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        } else {
                            Text(scenario.presenterName.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                        }
                    }

                    // Title below name
                    if let title = scenario.presenterTitle {
                        Text(title.uppercased())
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)
                    }

                    // Entrance description as narrative text
                    if !cachedEntrance.isEmpty {
                        Text("...\(cachedEntrance).")
                            .font(.system(size: 11, design: .serif))
                            .italic()
                            .foregroundColor(FiftiesColors.fadedInk)
                            .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding(.bottom, 14)

            // Divider
            Text(String(repeating: "-", count: 50))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.3))
                .padding(.bottom, 12)

            // Briefing text - typewriter style with clickable character names
            if let game = game {
                ClickableNarrativeText(
                    text: scenario.briefing,
                    game: game,
                    font: .system(size: 13, design: .serif),
                    color: FiftiesColors.typewriterInk,
                    lineSpacing: 6
                )
            } else {
                Text(scenario.briefing)
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(FiftiesColors.typewriterInk)
                    .lineSpacing(6)
            }
        }
        .padding(18)
        .background(
            ZStack {
                FiftiesColors.agedPaper

                // Paper texture
                Canvas { context, size in
                    for _ in 0..<40 {
                        let x = CGFloat.random(in: 0...size.width)
                        let y = CGFloat.random(in: 0...size.height)
                        let length = CGFloat.random(in: 4...12)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        context.stroke(path, with: .color(FiftiesColors.typewriterInk.opacity(0.025)), lineWidth: 0.5)
                    }
                }

                // Aging gradient
                LinearGradient(
                    colors: [FiftiesColors.leatherBrown.opacity(0.06), Color.clear, FiftiesColors.leatherBrown.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .overlay(
            Rectangle()
                .stroke(FiftiesColors.leatherBrown.opacity(0.2), lineWidth: 1)
        )
        .modifier(CharacterSheetOverlayModifier(game: game))
        // Paper clip on urgent documents
        .overlay(alignment: .topTrailing) {
            if scenario.category == .crisis {
                Image(systemName: "paperclip")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "6A6A6A").opacity(0.7))
                    .rotationEffect(.degrees(-25))
                    .offset(x: -12, y: 12)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 4, x: 2, y: 3)
        // Initialize cached values ONCE when view appears
        // This prevents content flickering on re-renders
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            cachedDate = generateFormattedDate()
            cachedAtmosphere = generateAtmosphereIntro()
            cachedEntrance = generateEntranceDescription()
        }
    }
}

#Preview {
    let scenario = Scenario(
        templateId: "test",
        briefing: "\"Comrade, we have a situation. The workers at the Pittsburgh steel plant have stopped production. They claim the new quotas are impossible. Already the local party secretary is blaming 'counter-revolutionary elements.' If we don't act, this spreads.\"",
        presenterName: "Director Wallace",
        presenterTitle: "Head of State Security",
        options: []
    )

    return BriefingPaperView(scenario: scenario, turnNumber: 14)
        .padding()
        .background(Color(hex: "F4F1E8"))
        .environment(\.theme, ColdWarTheme())
}
