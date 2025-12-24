//
//  CharacterCardView.swift
//  Nomenklatura
//
//  Character card component for the dossier
//

import SwiftUI

struct CharacterCardView: View {
    let character: GameCharacter
    var game: Game?
    @State private var showingDetail = false
    @Environment(\.theme) var theme

    /// Portrait image name (if asset exists)
    private var portraitImageName: String? {
        // Map character template IDs or names to asset names
        let idToAsset: [String: String] = [
            "wallace": "WallacePortrait",
            "kennedy": "KennedyPortrait",
            "anderson": "AndersonPortrait",
            "peterson": "PetersonPortrait",
            // Add more as portraits are created
        ]
        return idToAsset[character.templateId]
    }

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Character portrait with fallback to initials
                CharacterPortrait(
                    name: character.name,
                    imageName: portraitImageName,
                    size: 50,
                    showFrame: true
                )

                // Character info
                VStack(alignment: .leading, spacing: 3) {
                    Text(character.name)
                        .font(theme.labelFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.inkBlack)

                    if let title = character.title {
                        Text(title)
                            .font(theme.tagFont)
                            .foregroundColor(theme.inkGray)
                    }

                    // Tags (Living Character System: only show traits if personality revealed)
                    HStack(spacing: 5) {
                        ForEach(character.stanceTags, id: \.self) { stance in
                            StanceTagView(stance: stance)
                        }

                        // Only show personality traits if revealed
                        if character.isFullyRevealed {
                            ForEach(character.traitTags.prefix(2), id: \.self) { trait in
                                TraitTagView(trait: trait)
                            }
                        } else if character.wasDiscoveredDynamically {
                            // Show mystery indicator for discovered characters
                            Text("?")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(theme.inkLight)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.borderTan.opacity(0.5))
                        }
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkLight)
            }
            .padding(12)
            .background(theme.parchmentDark)
            .overlay(
                Rectangle()
                    .stroke(theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            CharacterDetailView(character: character, game: game)
        }
    }
}

// MARK: - Character Detail View (Hybrid Dossier Style)

struct CharacterDetailView: View {
    let character: GameCharacter
    var game: Game?
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss
    @State private var showingInteractionResult = false
    @State private var lastInteractionResult: InteractionResult?
    @State private var lastLeaderResult: LeaderActionResult?
    @State private var selectedTab: DossierTab = .bio
    @State private var dragOffset: CGFloat = 0

    // Denounce system state
    @State private var showingDenounceOptions = false
    @State private var showingDenounceResult = false
    @State private var lastDenounceResult: DenounceResult?
    @State private var availableDenounceOptions: [CharacterInteraction] = []

    // Classified Operation Card state (for BPS operations)
    @State private var showingClassifiedOperation = false
    @State private var pendingDenounceOperation: CharacterInteraction?
    @State private var pendingInvestigateOperation: CharacterInteraction?
    @State private var pendingCultivateOperation: CharacterInteraction?
    @State private var classifiedOperationType: ClassifiedOpType = .denounce

    enum ClassifiedOpType {
        case denounce
        case investigate
        case cultivate
    }

    // Investigate system state
    @State private var showingInvestigateOptions = false
    @State private var showingInvestigateResult = false
    @State private var lastInvestigateResult: InvestigateResult?
    @State private var availableInvestigateOptions: [CharacterInteraction] = []

    // Cultivate system state
    @State private var showingCultivateOptions = false
    @State private var showingCultivateResult = false
    @State private var lastCultivateResult: CultivateResult?
    @State private var availableCultivateOptions: [CharacterInteraction] = []

    enum DossierTab: String, CaseIterable {
        case bio = "BIO"
        case intel = "INTEL"
        case relations = "RELATIONS"
        case assets = "ASSETS"
    }

    /// Portrait image name (if asset exists)
    private var portraitImageName: String? {
        let idToAsset: [String: String] = [
            "wallace": "WallacePortrait",
            "kennedy": "KennedyPortrait",
            "anderson": "AndersonPortrait",
            "peterson": "PetersonPortrait",
        ]
        return idToAsset[character.templateId]
    }

    private var fileNumber: String {
        String(format: "#%03d-%@", character.introducedTurn, character.templateId.prefix(1).uppercased())
    }

    var body: some View {
        ZStack {
            // Light gray dotted background
            DossierBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Navigation header
                dossierNavigationBar

                // Main dossier content
                ScrollView {
                    VStack(spacing: 0) {
                        // Character card content
                        dossierContent
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                    }
                }

                // Fixed bottom action buttons
                if let game = game, character.isActive {
                    dossierActionBar(game: game)
                }
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 120 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        // Sheet modifiers must be at consistent level - not inside conditional views
        .sheet(isPresented: $showingInvestigateOptions) {
            if let game = game {
                investigateOptionsSheet(game: game)
            }
        }
        .sheet(isPresented: $showingDenounceOptions) {
            if let game = game {
                denounceOptionsSheet(game: game)
            }
        }
        .sheet(isPresented: $showingCultivateOptions) {
            if let game = game {
                cultivateOptionsSheet(game: game)
            }
        }
        .fullScreenCover(isPresented: $showingClassifiedOperation) {
            if let game = game {
                switch classifiedOperationType {
                case .denounce:
                    if let operation = pendingDenounceOperation {
                        classifiedOperationOverlay(operation: operation, game: game, opType: .denounce)
                    }
                case .investigate:
                    if let operation = pendingInvestigateOperation {
                        classifiedOperationOverlay(operation: operation, game: game, opType: .investigate)
                    }
                case .cultivate:
                    if let operation = pendingCultivateOperation {
                        classifiedOperationOverlay(operation: operation, game: game, opType: .cultivate)
                    }
                }
            }
        }
    }

    // MARK: - Navigation Bar

    private var dossierNavigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.inkBlack)
            }

            Spacer()

            VStack(spacing: 4) {
                Text("FILE \(fileNumber)")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(theme.inkBlack)

                // Classification stamp
                Text("CONFIDENTIAL")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(theme.stampRed)
            }

            Spacer()

            Button {
                // More options
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(theme.inkBlack)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }

    // MARK: - Dossier Content

    private var dossierContent: some View {
        VStack(spacing: 16) {
            // Character header card
            characterHeaderCard

            // Circular stat gauges
            statGaugesRow

            // Tab bar
            dossierTabBar

            // Tab content
            tabContent
        }
    }

    // MARK: - Character Header Card

    private var characterHeaderCard: some View {
        HStack(alignment: .top, spacing: 16) {
            // Portrait with message icon
            ZStack(alignment: .bottomTrailing) {
                // Portrait
                CharacterPortrait(
                    name: character.name,
                    imageName: portraitImageName,
                    size: 90,
                    showFrame: false
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "E0E0E0"), lineWidth: 1)
                )
                .grayscale(0.8)
                .contrast(1.1)

                // Message/chat icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "4A4A4A"))
                        .frame(width: 28, height: 28)

                    Image(systemName: "message.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .offset(x: 6, y: 6)
            }

            // Character info
            VStack(alignment: .leading, spacing: 6) {
                // Name
                Text(character.name.uppercased())
                    .font(.system(size: 20, weight: .black))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                // Current Assignment label
                Text("CURRENT ASSIGNMENT")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                // Title
                if let title = character.title {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundColor(theme.inkBlack)
                }

                // Faction badge
                if let factionId = character.factionId {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)
                        Text("FACTION: \(factionDisplayName(factionId))")
                            .font(.system(size: 11, weight: .medium))
                            .tracking(0.5)
                            .foregroundColor(theme.inkBlack)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            // Level badge
            levelBadge
                .offset(x: -16, y: 6),
            alignment: .bottomLeading
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var levelBadge: some View {
        Group {
            if let level = levelBadgeValue {
                Text("LEVEL \(level)")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(theme.stampRed)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    private func factionDisplayName(_ factionId: String) -> String {
        switch factionId.lowercased() {
        case "hardliner", "hardliners": return "HARDLINER"
        case "reformist", "reformists": return "REFORMIST"
        case "technocrat", "technocrats": return "TECHNOCRAT"
        case "nationalist", "nationalists": return "NATIONALIST"
        case "military": return "MILITARY"
        case "bps", "state_protection", "spb": return "PEOPLE'S SECURITY"
        default: return factionId.uppercased()
        }
    }

    // MARK: - Stat Gauges Row

    private var statGaugesRow: some View {
        HStack(spacing: 12) {
            CircularStatGauge(
                label: "LOYALTY",
                value: max(0, character.disposition),
                maxValue: 100
            )

            CircularStatGauge(
                label: "AMBITION",
                value: character.personalityAmbitious,
                maxValue: 100,
                showDanger: true
            )

            CircularStatGauge(
                label: "SKILL",
                value: character.personalityCompetent,
                maxValue: 100
            )
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Dossier Header

    private var dossierHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            // Photo with paper clip effect
            ZStack(alignment: .topTrailing) {
                // Photo backing
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 90, height: 110)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 2)

                // Portrait
                VStack {
                    CharacterPortrait(
                        name: character.name,
                        imageName: portraitImageName,
                        size: 80,
                        showFrame: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .overlay(
                        // Halftone effect
                        Canvas { context, size in
                            for row in stride(from: 0, to: size.height, by: 3) {
                                for col in stride(from: 0, to: size.width, by: 3) {
                                    context.fill(
                                        Path(ellipseIn: CGRect(x: col, y: row, width: 1.5, height: 1.5)),
                                        with: .color(Color.black.opacity(0.08))
                                    )
                                }
                            }
                        }
                    )
                }
                .padding(5)

                // Level badge
                if let level = levelBadgeValue {
                    Text("LEVEL \(level)")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(theme.stampRed)
                        .offset(x: 4, y: 94)
                }

                // Paper clip
                Image(systemName: "paperclip")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "8B8B8B"))
                    .rotationEffect(.degrees(30))
                    .offset(x: 8, y: -8)
            }

            // Character info
            VStack(alignment: .leading, spacing: 8) {
                // Name
                Text(character.name.uppercased())
                    .font(.system(size: 18, weight: .black))
                    .tracking(0.5)
                    .foregroundColor(theme.inkBlack)

                // Divider
                Rectangle()
                    .fill(theme.inkBlack.opacity(0.2))
                    .frame(height: 1)

                // Assignment
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT ASSIGNMENT")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkGray)

                    if let title = character.title {
                        Text(title)
                            .font(.system(size: 13))
                            .foregroundColor(theme.inkBlack)
                    }
                }

                // Faction
                if let factionId = character.factionId {
                    HStack(spacing: 6) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 10))
                            .foregroundColor(theme.inkGray)
                        Text("FACTION: \(factionId.uppercased())")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundColor(theme.inkBlack)
                    }
                }
            }
        }
    }

    // MARK: - Tab Bar

    private var dossierTabBar: some View {
        HStack(spacing: 0) {
            ForEach(DossierTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            .tracking(0.5)
                            .foregroundColor(selectedTab == tab ? theme.inkBlack : theme.inkGray)

                        Rectangle()
                            .fill(selectedTab == tab ? theme.inkBlack : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .bio:
            bioTabContent
        case .intel:
            intelTabContent
        case .relations:
            relationsTabContent
        case .assets:
            assetsTabContent
        }
    }

    // MARK: - BIO Tab

    private var bioTabContent: some View {
        VStack(spacing: 16) {
            // Service Record
            serviceRecordSection

            // Surveillance Notes
            surveillanceNotesSection

            // Key Relations
            keyRelationsSection
        }
    }

    private var serviceRecordSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                Text("SERVICE RECORD")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
            }

            // Service record text with redactions
            Text(serviceRecordText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(theme.inkBlack)
                .lineSpacing(5)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var serviceRecordText: AttributedString {
        var text = AttributedString("Subject has shown exemplary service records during the '\(character.introducedTurn > 10 ? "56" : "48") uprising. ")

        // Add redacted portion
        var redacted = AttributedString("REDACTED")
        redacted.backgroundColor = theme.inkBlack
        redacted.foregroundColor = theme.inkBlack

        text.append(redacted)

        let rest = AttributedString(" previous affiliations with the western trade union have been purged from public records. Currently overseeing internal security protocols for Sector \(character.introducedTurn % 6 + 1).")
        text.append(rest)

        return text
    }

    private var surveillanceNotesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                Text("SURVEILLANCE NOTES")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
            }

            // Surveillance note with red left border
            HStack(spacing: 0) {
                Rectangle()
                    .fill(theme.stampRed.opacity(0.6))
                    .frame(width: 3)

                Text(surveillanceNote)
                    .font(.system(size: 13, design: .serif))
                    .italic()
                    .foregroundColor(theme.inkGray)
                    .lineSpacing(4)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var surveillanceNote: String {
        "\"Subject was observed visiting \u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2588} Jazz Club on three separate occasions. Suspected drop point for \u{2588}\u{2588}\u{2588}\u{2588}.\""
    }

    // MARK: - Key Relations Section

    private var keyRelationsSection: some View {
        let relations = getRelatedCharacters(game: game)

        return VStack(alignment: .leading, spacing: 12) {
            // Header with count
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                Text("KEY RELATIONS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                if !relations.isEmpty {
                    Text("(\(relations.count))")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }

            // Relations grid - flexible layout
            if relations.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 14))
                        .foregroundColor(theme.inkLight)
                    Text("No significant relationships identified")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkLight)
                        .italic()
                }
                .padding(.vertical, 8)
            } else {
                // Use LazyVGrid for better layout with varying counts
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 10)
                ], alignment: .leading, spacing: 10) {
                    ForEach(relations, id: \.id) { relation in
                        relationBadge(relation: relation)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func relationBadge(relation: CharacterRelation) -> some View {
        HStack(spacing: 8) {
            // Mini portrait
            CharacterPortrait(
                name: relation.name,
                imageName: nil,
                size: 32,
                showFrame: false
            )
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(relation.shortName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.inkBlack)

                Text(relation.relationshipLabel)
                    .font(.system(size: 10))
                    .foregroundColor(relation.isPositive ? Color.green.opacity(0.8) : theme.stampRed)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(hex: "F5F5F5"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func getRelatedCharacters(game: Game?) -> [CharacterRelation] {
        guard let game = game else { return [] }

        // This character's data
        let thisCharId = character.id.uuidString
        let thisFaction = character.factionId
        let thisTrack = character.positionTrack
        let thisPosition = character.positionIndex ?? 3
        let thisAmbition = character.personalityAmbitious
        let thisLoyalty = character.personalityLoyal
        let thisRuthless = character.personalityRuthless

        var relations: [CharacterRelation] = []
        var addedIds: Set<String> = []

        // Helper to add relation if not already present
        func addRelation(_ relation: CharacterRelation) {
            if !addedIds.contains(relation.id) {
                relations.append(relation)
                addedIds.insert(relation.id)
            }
        }

        // Get all other active characters
        let otherChars = game.characters.filter {
            $0.id != character.id &&
            $0.status == CharacterStatus.active.rawValue
        }

        // 1. PATRON - This character's protector (most important relationship)
        if let patronId = character.protectorId,
           let patron = otherChars.first(where: { $0.templateId == patronId || $0.id.uuidString == patronId }) {
            addRelation(CharacterRelation(
                id: patron.id.uuidString,
                name: patron.name,
                shortName: patron.name.components(separatedBy: " ").last ?? patron.name,
                relationshipLabel: "Patron",
                disposition: 70,
                isPositive: true
            ))
        }

        // 2. PROTÉGÉS - Characters this person protects
        let proteges = otherChars.filter { $0.protectorId == character.templateId || $0.protectorId == thisCharId }
        for protege in proteges.prefix(2) {
            addRelation(CharacterRelation(
                id: protege.id.uuidString,
                name: protege.name,
                shortName: protege.name.components(separatedBy: " ").last ?? protege.name,
                relationshipLabel: "Protégé",
                disposition: 65,
                isPositive: true
            ))
        }

        // 3. FACTION ALLIES - Same faction, high faction loyalty
        if let faction = thisFaction, !faction.isEmpty {
            let factionAllies = otherChars.filter { other in
                other.factionId == faction &&
                other.factionLoyalty >= 60 &&
                character.factionLoyalty >= 50 &&
                !addedIds.contains(other.id.uuidString)
            }
            // Personality compatibility: loyal characters bond better
            let sortedAllies = factionAllies.sorted { a, b in
                let aScore = a.personalityLoyal + (100 - abs(a.personalityAmbitious - thisAmbition))
                let bScore = b.personalityLoyal + (100 - abs(b.personalityAmbitious - thisAmbition))
                return aScore > bScore
            }
            for ally in sortedAllies.prefix(2) {
                let bondStrength = min(ally.factionLoyalty, character.factionLoyalty)
                addRelation(CharacterRelation(
                    id: ally.id.uuidString,
                    name: ally.name,
                    shortName: ally.name.components(separatedBy: " ").last ?? ally.name,
                    relationshipLabel: bondStrength >= 80 ? "Close Ally" : "Faction Ally",
                    disposition: 50 + bondStrength / 5,
                    isPositive: true
                ))
            }
        }

        // 4. POSITION RIVALS - Same track, competing for advancement
        if let track = thisTrack, !track.isEmpty {
            let trackRivals = otherChars.filter { other in
                other.positionTrack == track &&
                other.personalityAmbitious >= 60 &&
                thisAmbition >= 50 &&
                abs((other.positionIndex ?? 3) - thisPosition) <= 2 &&
                !addedIds.contains(other.id.uuidString)
            }
            // Most ambitious competitors first
            let sortedRivals = trackRivals.sorted { $0.personalityAmbitious > $1.personalityAmbitious }
            for rival in sortedRivals.prefix(1) {
                let intensity = (rival.personalityAmbitious + thisAmbition) / 2
                addRelation(CharacterRelation(
                    id: rival.id.uuidString,
                    name: rival.name,
                    shortName: rival.name.components(separatedBy: " ").last ?? rival.name,
                    relationshipLabel: intensity >= 80 ? "Bitter Rival" : "Competitor",
                    disposition: 30 - intensity / 5,
                    isPositive: false
                ))
            }
        }

        // 5. FACTION RIVALS - Opposing factions, both ambitious
        if let faction = thisFaction, !faction.isEmpty {
            let opposingFactions = getOpposingFactions(faction)
            let factionRivals = otherChars.filter { other in
                guard let otherFaction = other.factionId else { return false }
                return opposingFactions.contains(otherFaction) &&
                       other.personalityAmbitious >= 55 &&
                       (other.positionIndex ?? 3) >= thisPosition - 1 &&
                       !addedIds.contains(other.id.uuidString)
            }
            let sortedFactionRivals = factionRivals.sorted {
                ($0.positionIndex ?? 0) > ($1.positionIndex ?? 0)
            }
            for rival in sortedFactionRivals.prefix(1) {
                addRelation(CharacterRelation(
                    id: rival.id.uuidString,
                    name: rival.name,
                    shortName: rival.name.components(separatedBy: " ").last ?? rival.name,
                    relationshipLabel: "Faction Rival",
                    disposition: 20,
                    isPositive: false
                ))
            }
        }

        // 6. PERSONALITY-BASED BONDS - Loyal characters trust each other
        if thisLoyalty >= 70 {
            let loyalBonds = otherChars.filter { other in
                other.personalityLoyal >= 70 &&
                other.personalityRuthless < 60 &&
                !addedIds.contains(other.id.uuidString)
            }
            for bond in loyalBonds.prefix(1) {
                addRelation(CharacterRelation(
                    id: bond.id.uuidString,
                    name: bond.name,
                    shortName: bond.name.components(separatedBy: " ").last ?? bond.name,
                    relationshipLabel: "Trusted Friend",
                    disposition: 60,
                    isPositive: true
                ))
            }
        }

        // 7. ANTAGONISTS - Ruthless characters vs. this character (if they've clashed)
        if thisRuthless < 40 {
            let antagonists = otherChars.filter { other in
                other.personalityRuthless >= 75 &&
                other.personalityAmbitious >= 65 &&
                (other.positionIndex ?? 3) >= thisPosition &&
                !addedIds.contains(other.id.uuidString)
            }
            for antagonist in antagonists.prefix(1) {
                addRelation(CharacterRelation(
                    id: antagonist.id.uuidString,
                    name: antagonist.name,
                    shortName: antagonist.name.components(separatedBy: " ").last ?? antagonist.name,
                    relationshipLabel: "Threat",
                    disposition: 15,
                    isPositive: false
                ))
            }
        }

        // Shuffle slightly for variety but keep patron/protégé first
        let importantRelations = relations.prefix(while: {
            $0.relationshipLabel == "Patron" || $0.relationshipLabel == "Protégé"
        })
        var otherRelations = Array(relations.dropFirst(importantRelations.count))
        if otherRelations.count > 2 {
            otherRelations.shuffle()
        }

        return Array(importantRelations) + otherRelations
    }

    // Faction opposition mapping
    private func getOpposingFactions(_ factionId: String) -> [String] {
        switch factionId {
        case "reformists":
            return ["old_guard", "princelings"]
        case "old_guard":
            return ["reformists", "youth_league"]
        case "youth_league":
            return ["old_guard", "princelings"]
        case "princelings":
            return ["reformists", "youth_league"]
        case "regional":
            return ["princelings"]  // Regional vs. central elites
        default:
            return []
        }
    }

    struct CharacterRelation: Identifiable {
        let id: String
        let name: String
        let shortName: String
        let relationshipLabel: String
        let disposition: Int
        let isPositive: Bool
    }

    // MARK: - INTEL Tab

    private var intelTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Personality assessment
            personalityAssessment

            // Risk assessment
            riskAssessmentSection

            // History if available
            if let game = game {
                characterHistorySection(game: game)
            }
        }
    }

    private var personalityAssessment: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PERSONALITY PROFILE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                if character.isFullyRevealed {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("VERIFIED")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(Color.green.opacity(0.8))
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 10))
                        Text("UNVERIFIED")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundColor(theme.inkLight)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                PersonalityTraitRow(trait: "Ambitious", value: character.personalityAmbitious)
                PersonalityTraitRow(trait: "Paranoid", value: character.personalityParanoid)
                PersonalityTraitRow(trait: "Ruthless", value: character.personalityRuthless)
                PersonalityTraitRow(trait: "Competent", value: character.personalityCompetent)
                PersonalityTraitRow(trait: "Loyal", value: character.personalityLoyal)
                PersonalityTraitRow(trait: "Corrupt", value: character.personalityCorrupt)
            }
        }
    }

    private var riskAssessmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THREAT ASSESSMENT")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            HStack {
                Text("Risk Level:")
                    .font(.system(size: 11))
                    .foregroundColor(theme.inkGray)

                Spacer()

                // Risk bar
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Rectangle()
                            .fill(index < riskLevel ? riskColor : theme.inkLight.opacity(0.2))
                            .frame(width: 20, height: 8)
                    }
                }

                Text(riskLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(riskColor)
                    .padding(.leading, 8)
            }
            .padding(12)
            .background(riskColor.opacity(0.05))
            .overlay(
                Rectangle()
                    .stroke(riskColor.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private var riskLevel: Int {
        if character.isRival { return 4 }
        if character.disposition < 20 { return 4 }
        if character.disposition < 40 { return 3 }
        if character.disposition < 60 { return 2 }
        return 1
    }

    private var riskLabel: String {
        switch riskLevel {
        case 4...: return "HIGH"
        case 3: return "ELEVATED"
        case 2: return "MODERATE"
        default: return "LOW"
        }
    }

    private var riskColor: Color {
        switch riskLevel {
        case 4...: return theme.stampRed
        case 3: return Color(hex: "FF9800")
        case 2: return Color(hex: "FFC107")
        default: return Color.green.opacity(0.8)
        }
    }

    // MARK: - RELATIONS Tab

    private var relationsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Key relations
            keyRelationsSection

            // Your relationship
            relationshipSection
        }
    }

    // MARK: - ASSETS Tab

    private var assetsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("KNOWN ASSETS")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            Text("Intelligence gathering on subject's assets is ongoing. Check back after additional surveillance operations.")
                .font(.system(size: 11, design: .serif))
                .italic()
                .foregroundColor(theme.inkLight)
                .padding(12)
                .background(Color.white.opacity(0.3))
        }
    }

    // MARK: - Action Bar (Fixed Bottom)

    private func dossierActionBar(game: Game) -> some View {
        VStack(spacing: 0) {
            // Results appear above the action bar
            if showingInvestigateResult, let result = lastInvestigateResult {
                investigateResultCard(result: result)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if showingCultivateResult, let result = lastCultivateResult {
                cultivateResultCard(result: result)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            if showingDenounceResult, let result = lastDenounceResult {
                denounceResultCard(result: result)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }

            // Action buttons
            HStack(spacing: 16) {
                // INVESTIGATE
                actionButton(
                    icon: "magnifyingglass",
                    label: "INVESTIGATE",
                    color: theme.inkGray
                ) {
                    availableInvestigateOptions = CharacterInteractionSystem.shared.getInvestigateInteractions(
                        for: character,
                        game: game
                    )
                    showingInvestigateOptions = true
                }

                // CULTIVATE
                actionButton(
                    icon: "heart.fill",
                    label: "CULTIVATE",
                    color: theme.inkGray
                ) {
                    availableCultivateOptions = CharacterInteractionSystem.shared.getCultivateInteractions(
                        for: character,
                        game: game
                    )
                    showingCultivateOptions = true
                }

                // DENOUNCE
                actionButton(
                    icon: "hand.raised.fill",
                    label: "DENOUNCE",
                    color: theme.stampRed
                ) {
                    availableDenounceOptions = CharacterInteractionSystem.shared.getDenounceInteractions(
                        for: character,
                        game: game
                    )
                    if !availableDenounceOptions.isEmpty {
                        showingDenounceOptions = true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -4)
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color == theme.stampRed ? theme.stampRed.opacity(0.1) : Color(hex: "F5F5F5"))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.5)
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Old Action Buttons (kept for compatibility)

    private func dossierActionButtons(game: Game) -> some View {
        VStack(spacing: 12) {
            Rectangle()
                .fill(theme.inkBlack.opacity(0.1))
                .frame(height: 1)

            HStack(spacing: 12) {
                actionStampButton(
                    icon: "magnifyingglass",
                    label: "INVESTIGATE",
                    color: theme.inkGray,
                    badge: nil
                ) {
                    // Load available investigate options
                    availableInvestigateOptions = CharacterInteractionSystem.shared.getInvestigateInteractions(
                        for: character,
                        game: game
                    )
                    showingInvestigateOptions = true
                }

                actionStampButton(
                    icon: "heart.fill",
                    label: "CULTIVATE",
                    color: theme.accentGold,
                    badge: character.disposition >= 60 ? "♥" : nil
                ) {
                    // Load available cultivate options
                    availableCultivateOptions = CharacterInteractionSystem.shared.getCultivateInteractions(
                        for: character,
                        game: game
                    )
                    showingCultivateOptions = true
                }

                actionStampButton(
                    icon: "exclamationmark.triangle.fill",
                    label: "DENOUNCE",
                    color: theme.stampRed,
                    badge: character.evidenceLevel >= 30 ? "!" : nil
                ) {
                    // Load available denounce options
                    availableDenounceOptions = CharacterInteractionSystem.shared.getDenounceInteractions(
                        for: character,
                        game: game
                    )
                    if !availableDenounceOptions.isEmpty {
                        showingDenounceOptions = true
                    }
                }
            }

            // Show investigate result if available
            if showingInvestigateResult, let result = lastInvestigateResult {
                investigateResultCard(result: result)
            }

            // Show cultivate result if available
            if showingCultivateResult, let result = lastCultivateResult {
                cultivateResultCard(result: result)
            }

            // Show denounce result if available
            if showingDenounceResult, let result = lastDenounceResult {
                denounceResultCard(result: result)
            }
        }
    }

    private func actionStampButton(icon: String, label: String, color: Color, badge: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)

                    Text(label)
                        .font(.system(size: 9, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )

                // Evidence indicator badge
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(color)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Investigate Options Sheet

    private func investigateOptionsSheet(game: Game) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(theme.inkGray)

                    Text("INVESTIGATE \(character.name.uppercased())")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    // Current evidence level
                    HStack(spacing: 8) {
                        Text("Current Evidence:")
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)

                        evidenceBar

                        Text("\(character.evidenceLevel)%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(evidenceLevelColor)
                    }
                    .padding(.top, 4)

                    // Personality status
                    HStack(spacing: 6) {
                        Image(systemName: character.isFullyRevealed ? "brain.head.profile" : "questionmark.circle")
                            .font(.system(size: 12))
                        Text(character.isFullyRevealed ? "Personality Profile: KNOWN" : "Personality Profile: UNKNOWN")
                            .font(.system(size: 11))
                    }
                    .foregroundColor(character.isFullyRevealed ? Color.green.opacity(0.8) : theme.inkLight)
                    .padding(.top, 2)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(theme.parchmentDark)

                Divider()

                // Options list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableInvestigateOptions) { option in
                            investigateOptionCard(option: option, game: game)
                        }

                        if availableInvestigateOptions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(theme.inkLight)

                                Text("No investigation methods available")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.inkGray)

                                Text("Increase your position or network to unlock more options.")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.inkLight)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
                    }
                    .padding(16)
                }
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingInvestigateOptions = false
                    }
                    .foregroundColor(theme.inkGray)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func investigateOptionCard(option: CharacterInteraction, game: Game) -> some View {
        Button {
            // Show classified operation card for confirmation
            pendingInvestigateOperation = option
            classifiedOperationType = .investigate
            showingInvestigateOptions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingClassifiedOperation = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Icon based on investigation type
                    Image(systemName: investigateIcon(for: option.id))
                        .font(.system(size: 14))
                        .foregroundColor(theme.inkGray)
                        .frame(width: 20)

                    Text(option.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    // Risk indicator
                    riskBadge(for: option.riskLevel)
                }

                Text(option.description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.leading)

                if let flavor = option.flavorText {
                    Text(flavor)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(theme.inkLight)
                        .padding(.top, 4)
                }

                // Cost and potential yield
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("\(option.costAP) AP")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.accentGold)

                    Spacer()

                    // Evidence yield hint
                    HStack(spacing: 4) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 10))
                        Text(evidenceYieldHint(for: option.id))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.inkLight)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.inkGray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func investigateIcon(for id: String) -> String {
        if id.contains("observe") { return "eye" }
        if id.contains("informant") { return "person.wave.2" }
        if id.contains("surveillance") { return "antenna.radiowaves.left.and.right" }
        if id.contains("archives") { return "archivebox" }
        if id.contains("full") { return "doc.text.magnifyingglass" }
        if id.contains("personality") { return "brain.head.profile" }
        return "magnifyingglass"
    }

    private func evidenceYieldHint(for id: String) -> String {
        if id.contains("full") { return "+25-40% evidence" }
        if id.contains("surveillance") || id.contains("archives") { return "+15-25% evidence" }
        if id.contains("informant") { return "+10-20% evidence" }
        if id.contains("personality") { return "Reveals personality" }
        return "+5-15% evidence"
    }

    private func executeInvestigate(option: CharacterInteraction, game: Game) {
        // Execute the investigation
        let result = CharacterInteractionSystem.shared.executeInvestigation(
            option,
            target: character,
            game: game
        )

        // Store result and show it
        lastInvestigateResult = result
        showingInvestigateOptions = false

        // Slight delay before showing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingInvestigateResult = true
        }
    }

    private func investigateResultCard(result: InvestigateResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.outcomeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(result.success ? Color.green.opacity(0.8) : theme.stampRed)

                Text(result.success ? "INVESTIGATION SUCCESSFUL" : "INVESTIGATION FAILED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(result.success ? Color.green.opacity(0.8) : theme.stampRed)

                Spacer()

                Button {
                    withAnimation {
                        showingInvestigateResult = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkGray)
                }
            }

            if let game = game {
                ClickableNarrativeText(
                    text: result.narrative,
                    game: game,
                    font: .system(size: 12, design: .serif),
                    color: theme.inkBlack
                )
                .italic()
            } else {
                Text(result.narrative)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(theme.inkBlack)
                    .italic()
            }

            // Evidence gained
            if result.success && result.evidenceGained > 0 {
                HStack(spacing: 8) {
                    Text("Evidence gathered:")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)

                    Text("+\(result.evidenceGained)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color.green.opacity(0.8))

                    Text("(Total: \(result.totalEvidence)%)")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }

            // Secrets revealed
            if !result.secretsRevealed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 10))
                        Text("SECRETS UNCOVERED:")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(theme.accentGold)

                    ForEach(result.secretsRevealed, id: \.self) { secret in
                        HStack(alignment: .top, spacing: 6) {
                            Text("•")
                                .font(.system(size: 10))
                            Text(secret)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(theme.inkBlack)
                    }
                }
                .padding(.top, 4)
            }

            // Personality revealed
            if result.personalityRevealed {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12))
                    Text("\(result.targetName)'s true personality has been revealed!")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 4)
            }

            // Alert warning
            if result.alertedTarget {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                    Text("\(result.targetName) may have been alerted to your investigation")
                        .font(.system(size: 11))
                }
                .foregroundColor(theme.stampRed)
                .padding(.top, 4)
            }

            Text(result.summaryText)
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)
                .padding(.top, 4)
        }
        .padding(12)
        .background(result.success ? Color.green.opacity(0.05) : theme.stampRed.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(result.success ? Color.green.opacity(0.3) : theme.stampRed.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Cultivate Options Sheet

    private func cultivateOptionsSheet(game: Game) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 32))
                        .foregroundColor(theme.accentGold)

                    Text("CULTIVATE \(character.name.uppercased())")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    // Current disposition indicator
                    HStack(spacing: 8) {
                        Text("Current Relationship:")
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)

                        dispositionBar

                        Text(dispositionLevelText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(dispositionLevelColor)
                    }
                    .padding(.top, 4)

                    // Relationship status hints
                    if character.isPatron {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 12))
                            Text("This is your patron")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(theme.accentGold)
                        .padding(.top, 4)
                    } else if character.isRival {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text("This is your rival - cultivation is harder")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(theme.stampRed)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(theme.parchmentDark)

                Divider()

                // Options list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(availableCultivateOptions) { option in
                            cultivateOptionCard(option: option, game: game)
                        }

                        if availableCultivateOptions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "heart.slash")
                                    .font(.system(size: 32))
                                    .foregroundColor(theme.inkLight)

                                Text("No cultivation methods available")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.inkGray)

                                Text("This character cannot be cultivated at this time.")
                                    .font(.system(size: 12))
                                    .foregroundColor(theme.inkLight)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                        }
                    }
                    .padding(16)
                }
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingCultivateOptions = false
                    }
                    .foregroundColor(theme.inkGray)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func cultivateOptionCard(option: CharacterInteraction, game: Game) -> some View {
        Button {
            // Show classified operation card for confirmation
            pendingCultivateOperation = option
            classifiedOperationType = .cultivate
            showingCultivateOptions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingClassifiedOperation = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Icon based on cultivation type
                    Image(systemName: cultivateIcon(for: option.id))
                        .font(.system(size: 14))
                        .foregroundColor(theme.accentGold)
                        .frame(width: 20)

                    Text(option.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    // Risk indicator
                    riskBadge(for: option.riskLevel)
                }

                Text(option.description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.leading)

                if let flavor = option.flavorText {
                    Text(flavor)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(theme.inkLight)
                        .padding(.top, 4)
                }

                // Cost and potential effect
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                        Text("\(option.costAP) AP")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.accentGold)

                    Spacer()

                    // Relationship hint
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                        Text(cultivateEffectHint(for: option.id))
                            .font(.system(size: 10))
                    }
                    .foregroundColor(theme.inkLight)
                }
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.accentGold.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cultivateIcon(for id: String) -> String {
        if id.contains("casual") { return "bubble.left.and.bubble.right" }
        if id.contains("drink") { return "wineglass" }
        if id.contains("gift") { return "gift" }
        if id.contains("favor") { return "hand.thumbsup" }
        if id.contains("intel") { return "doc.text" }
        if id.contains("patronage") { return "crown" }
        if id.contains("alliance") { return "person.2" }
        if id.contains("recruit") { return "person.badge.plus" }
        if id.contains("reconcile") { return "hand.wave" }
        if id.contains("patron") { return "star.fill" }
        return "heart"
    }

    private func cultivateEffectHint(for id: String) -> String {
        if id.contains("patronage") { return "Major trust gain" }
        if id.contains("alliance") { return "Formal alliance" }
        if id.contains("recruit") { return "Become asset" }
        if id.contains("reconcile") { return "End rivalry" }
        if id.contains("favor") || id.contains("gift") { return "Good trust gain" }
        if id.contains("intel") { return "Moderate trust gain" }
        return "Small trust gain"
    }

    private func executeCultivate(option: CharacterInteraction, game: Game) {
        // Execute the cultivation
        let result = CharacterInteractionSystem.shared.executeCultivation(
            option,
            target: character,
            game: game
        )

        // Apply stat effects
        for (key, value) in result.effects {
            game.applyStat(key, change: value)
        }

        // Store result and show it
        lastCultivateResult = result
        showingCultivateOptions = false

        // Slight delay before showing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingCultivateResult = true
        }
    }

    private func cultivateResultCard(result: CultivateResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.outcomeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(result.success ? theme.accentGold : theme.stampRed)

                Text(result.success ? "CULTIVATION SUCCESSFUL" : "CULTIVATION FAILED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(result.success ? theme.accentGold : theme.stampRed)

                Spacer()

                Button {
                    withAnimation {
                        showingCultivateResult = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkGray)
                }
            }

            if let game = game {
                ClickableNarrativeText(
                    text: result.narrative,
                    game: game,
                    font: .system(size: 12, design: .serif),
                    color: theme.inkBlack
                )
                .italic()
            } else {
                Text(result.narrative)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(theme.inkBlack)
                    .italic()
            }

            // Disposition change
            if result.dispositionGain != 0 {
                HStack(spacing: 8) {
                    Text("Relationship:")
                        .font(.system(size: 11))
                        .foregroundColor(theme.inkGray)

                    Text(result.dispositionGain > 0 ? "+\(result.dispositionGain)" : "\(result.dispositionGain)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(result.dispositionGain > 0 ? Color.green.opacity(0.8) : theme.stampRed)

                    Text("(Now: \(result.newDisposition))")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }

            // Trust level if increased
            if result.success && result.trustLevel > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10))
                    Text("Trust level: \(result.trustLevelText)")
                        .font(.system(size: 11))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 2)
            }

            // Special outcomes
            if result.becameAlly {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                    Text("\(result.targetName) is now your formal ally!")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 4)
            }

            if result.rivalryEnded {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 12))
                    Text("Your rivalry with \(result.targetName) has ended")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color.green.opacity(0.8))
                .padding(.top, 4)
            }

            if result.becameProtege {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                    Text("\(result.targetName) is now under your patronage")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 4)
            }

            if result.becameAsset {
                HStack(spacing: 6) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 12))
                    Text("\(result.targetName) has been recruited as an asset")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 4)
            }

            // Show effects
            if !result.effects.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(result.effects.keys.prefix(3)), id: \.self) { key in
                        if let value = result.effects[key], value != 0 {
                            HStack(spacing: 2) {
                                Text(statDisplayName(key))
                                    .font(.system(size: 9))
                                    .foregroundColor(theme.inkGray)
                                Text(value > 0 ? "+\(value)" : "\(value)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(value > 0 ? Color.green.opacity(0.8) : theme.stampRed)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }

            Text(result.summaryText)
                .font(.system(size: 10))
                .foregroundColor(theme.inkLight)
                .padding(.top, 4)
        }
        .padding(12)
        .background(result.success ? theme.accentGold.opacity(0.05) : theme.stampRed.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(result.success ? theme.accentGold.opacity(0.3) : theme.stampRed.opacity(0.3), lineWidth: 1)
        )
    }

    // Disposition display helpers
    private var dispositionBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index < dispositionBarFill ? dispositionLevelColor : theme.inkLight.opacity(0.2))
                    .frame(width: 16, height: 6)
            }
        }
    }

    private var dispositionBarFill: Int {
        switch character.disposition {
        case ..<20: return 1
        case 20..<40: return 2
        case 40..<60: return 3
        case 60..<80: return 4
        default: return 5
        }
    }

    private var dispositionLevelText: String {
        switch character.disposition {
        case ..<20: return "HOSTILE"
        case 20..<40: return "COLD"
        case 40..<60: return "NEUTRAL"
        case 60..<80: return "WARM"
        default: return "LOYAL"
        }
    }

    private var dispositionLevelColor: Color {
        switch character.disposition {
        case ..<30: return theme.stampRed
        case 30..<50: return Color(hex: "FF9800")
        case 50..<70: return theme.inkGray
        default: return Color.green.opacity(0.8)
        }
    }

    // MARK: - Denounce Options Sheet

    private func denounceOptionsSheet(game: Game) -> some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(theme.stampRed)

                    Text("DENOUNCE \(character.name.uppercased())")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(1)
                        .foregroundColor(theme.inkBlack)

                    // Evidence indicator
                    HStack(spacing: 8) {
                        Text("Evidence Level:")
                            .font(.system(size: 11))
                            .foregroundColor(theme.inkGray)

                        evidenceBar

                        Text(evidenceLevelText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(evidenceLevelColor)
                    }
                    .padding(.top, 4)

                    // Warning
                    if character.hasProtection || isProtectedByPatron {
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 12))
                            Text("This target has powerful protection")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "FF9800"))
                        .padding(.top, 4)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(theme.parchmentDark)

                Divider()

                // Options list
                ScrollView {
                    VStack(spacing: 12) {
                        if availableDenounceOptions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "clock")
                                    .font(.system(size: 32))
                                    .foregroundColor(theme.inkLight)

                                Text("No denouncement options available")
                                    .font(.system(size: 14))
                                    .foregroundColor(theme.inkGray)

                                if let lastDenounced = character.lastDenouncedTurn, game.turnNumber - lastDenounced < 3 {
                                    Text("Recently denounced. Wait \(3 - (game.turnNumber - lastDenounced)) more turns.")
                                        .font(.system(size: 12))
                                        .foregroundColor(theme.inkLight)
                                }
                            }
                            .padding(40)
                        } else {
                            ForEach(availableDenounceOptions) { option in
                                denounceOptionCard(option: option, game: game)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showingDenounceOptions = false
                    }
                    .foregroundColor(theme.inkGray)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func denounceOptionCard(option: CharacterInteraction, game: Game) -> some View {
        Button {
            // Show classified operation card for confirmation
            pendingDenounceOperation = option
            classifiedOperationType = .denounce
            showingDenounceOptions = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingClassifiedOperation = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(option.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.inkBlack)

                    Spacer()

                    // Risk indicator
                    riskBadge(for: option.riskLevel)
                }

                Text(option.description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.inkGray)
                    .multilineTextAlignment(.leading)

                if let flavor = option.flavorText {
                    Text(flavor)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(theme.inkLight)
                        .padding(.top, 4)
                }

                // Cost indicator
                HStack {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("\(option.costAP) Action Point")
                        .font(.system(size: 10))
                }
                .foregroundColor(theme.accentGold)
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(theme.stampRed.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func riskBadge(for risk: RiskLevel) -> some View {
        let (color, text) = riskInfo(for: risk)
        return Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color)
            .clipShape(Capsule())
    }

    private func riskInfo(for risk: RiskLevel) -> (Color, String) {
        switch risk {
        case .low: return (Color.green.opacity(0.8), "LOW RISK")
        case .medium: return (Color(hex: "FF9800"), "MEDIUM RISK")
        case .high: return (theme.stampRed, "HIGH RISK")
        }
    }

    private func executeDenounce(option: CharacterInteraction, game: Game) {
        // Execute the denouncement
        let result = CharacterInteractionSystem.shared.executeDenouncement(
            option,
            target: character,
            game: game
        )

        // Apply stat effects
        for (key, value) in result.repercussions {
            game.applyStat(key, change: value)
        }

        // Update target status if changed
        if let newStatus = result.newTargetStatus {
            character.status = newStatus.rawValue
        }

        // Store result and show it
        lastDenounceResult = result
        showingDenounceOptions = false

        // Slight delay before showing result
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingDenounceResult = true
        }
    }

    private func denounceResultCard(result: DenounceResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.outcomeIcon)
                    .font(.system(size: 16))
                    .foregroundColor(result.success ? Color.green.opacity(0.8) : theme.stampRed)

                Text(result.success ? "DENUNCIATION SUCCEEDED" : "DENUNCIATION FAILED")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1)
                    .foregroundColor(result.success ? Color.green.opacity(0.8) : theme.stampRed)

                Spacer()

                Button {
                    withAnimation {
                        showingDenounceResult = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(theme.inkGray)
                }
            }

            if let game = game {
                ClickableNarrativeText(
                    text: result.narrative,
                    game: game,
                    font: .system(size: 12, design: .serif),
                    color: theme.inkBlack
                )
                .italic()
            } else {
                Text(result.narrative)
                    .font(.system(size: 12, design: .serif))
                    .foregroundColor(theme.inkBlack)
                    .italic()
            }

            Text(result.summaryText)
                .font(.system(size: 11))
                .foregroundColor(theme.inkGray)

            // Show consequences
            if !result.repercussions.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(result.repercussions.keys.prefix(3)), id: \.self) { key in
                        if let value = result.repercussions[key], value != 0 {
                            HStack(spacing: 2) {
                                Text(statDisplayName(key))
                                    .font(.system(size: 9))
                                    .foregroundColor(theme.inkGray)
                                Text(value > 0 ? "+\(value)" : "\(value)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(value > 0 ? Color.green.opacity(0.8) : theme.stampRed)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(result.success ? Color.green.opacity(0.05) : theme.stampRed.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(result.success ? Color.green.opacity(0.3) : theme.stampRed.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Classified Operation Overlay (BPS Operations)

    private func classifiedOperationOverlay(operation: CharacterInteraction, game: Game, opType: ClassifiedOpType) -> some View {
        ZStack {
            // Dark background
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            // Classified Operation Card
            ClassifiedOperationCard(
                operation: convertToClassifiedOperation(operation, game: game, opType: opType),
                game: game,
                onDismiss: {
                    showingClassifiedOperation = false
                    pendingDenounceOperation = nil
                    pendingInvestigateOperation = nil
                    pendingCultivateOperation = nil
                },
                onExecute: {
                    showingClassifiedOperation = false
                    // Execute based on operation type
                    switch opType {
                    case .denounce:
                        if let op = pendingDenounceOperation {
                            executeDenounce(option: op, game: game)
                        }
                        pendingDenounceOperation = nil
                    case .investigate:
                        if let op = pendingInvestigateOperation {
                            executeInvestigate(option: op, game: game)
                        }
                        pendingInvestigateOperation = nil
                    case .cultivate:
                        if let op = pendingCultivateOperation {
                            executeCultivate(option: op, game: game)
                        }
                        pendingCultivateOperation = nil
                    }
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 40)
        }
    }

    private func convertToClassifiedOperation(_ interaction: CharacterInteraction, game: Game, opType: ClassifiedOpType = .denounce) -> ClassifiedOperation {
        // Generate a decision number based on turn and random
        let decisionNumber = "#\(game.turnNumber)\(Int.random(in: 100...999))"

        // Map interaction risk level to operation risk level
        let riskLevel: OperationRiskLevel = {
            switch interaction.riskLevel {
            case .low: return .low
            case .medium: return .moderate
            case .high: return .high
            }
        }()

        // Calculate failure probability based on risk and evidence
        let failureProbability: Int = {
            switch interaction.riskLevel {
            case .low: return Int.random(in: 15...35)
            case .medium: return Int.random(in: 35...55)
            case .high: return Int.random(in: 55...85)
            }
        }()

        // Build projected outcomes from effects
        var outcomes: [OperationOutcome] = []
        for (key, value) in interaction.effects {
            let statName = statDisplayName(key).uppercased()
            let isPositive = (key == "standing" || key == "network" || key == "patronFavor") ? value > 0 : value < 0
            outcomes.append(OperationOutcome(stat: statName, change: value, isPositive: isPositive))
        }

        // Add default outcomes based on operation type
        if outcomes.isEmpty {
            switch opType {
            case .denounce:
                outcomes = [
                    OperationOutcome(stat: "FEAR", change: 10, isPositive: true),
                    OperationOutcome(stat: "STANDING", change: -5, isPositive: false)
                ]
            case .investigate:
                outcomes = [
                    OperationOutcome(stat: "INTEL", change: 15, isPositive: true),
                    OperationOutcome(stat: "NETWORK", change: 5, isPositive: true)
                ]
            case .cultivate:
                outcomes = [
                    OperationOutcome(stat: "TRUST", change: 10, isPositive: true),
                    OperationOutcome(stat: "DISPOSITION", change: 15, isPositive: true)
                ]
            }
        }

        // Create operation name from interaction title
        let operationName = generateOperationName(for: interaction.title, opType: opType)

        // Build briefing text
        let briefingText = interaction.description + (interaction.flavorText.map { "\n\n\($0)" } ?? "")

        // Customize based on operation type
        let ministry: String
        let operationType: OperationType
        let imagePrefix: String

        switch opType {
        case .denounce:
            ministry = "BUREAU OF PEOPLE'S SECURITY"
            operationType = .bpsOperation
            imagePrefix = "BPS_OPS"
        case .investigate:
            ministry = "INTELLIGENCE DIRECTORATE"
            operationType = .bpsOperation
            imagePrefix = "INT_SUR"
        case .cultivate:
            ministry = "DIPLOMATIC LIAISON OFFICE"
            operationType = .foreignOperation
            imagePrefix = "DIP_OPS"
        }

        return ClassifiedOperation(
            decisionNumber: decisionNumber,
            ministry: ministry,
            operationName: operationName,
            imageRef: "\(imagePrefix)_\(game.turnNumber).\(Int.random(in: 10...99))",
            briefingText: "TARGET: \(character.name)\n\n\(briefingText)",
            projectedOutcomes: outcomes,
            cost: interaction.costAP * 25, // Convert AP to political capital
            riskLevel: riskLevel,
            failureProbability: failureProbability,
            securityLevel: max(3, game.currentPositionIndex),
            operationType: operationType
        )
    }

    private func generateOperationName(for title: String, opType: ClassifiedOpType = .denounce) -> String {
        // Generate a dramatic operation name based on operation type
        let prefix: String
        let suffix: String

        switch opType {
        case .denounce:
            let prefixes = ["IRON", "SILENT", "RED", "WINTER", "STEEL", "CRIMSON", "MIDNIGHT", "BLACK"]
            let suffixes = ["FALL", "THUNDER", "HAMMER", "CURTAIN", "GUARD", "PURGE", "JUDGMENT", "STORM"]
            prefix = prefixes.randomElement() ?? "IRON"
            suffix = suffixes.randomElement() ?? "FALL"
        case .investigate:
            let prefixes = ["SHADOW", "GHOST", "NIGHT", "SILENT", "DEEP", "COLD", "HIDDEN", "DARK"]
            let suffixes = ["WATCH", "EYE", "LENS", "MIRROR", "VEIL", "PROBE", "SEARCH", "TRAIL"]
            prefix = prefixes.randomElement() ?? "SHADOW"
            suffix = suffixes.randomElement() ?? "WATCH"
        case .cultivate:
            let prefixes = ["GOLDEN", "VELVET", "SILVER", "WARM", "OPEN", "TRUSTED", "FRIENDLY", "SUBTLE"]
            let suffixes = ["BRIDGE", "HAND", "DOOR", "PATH", "ACCORD", "BOND", "CHANNEL", "EMBRACE"]
            prefix = prefixes.randomElement() ?? "GOLDEN"
            suffix = suffixes.randomElement() ?? "BRIDGE"
        }

        return "\(prefix) \(suffix)"
    }

    private func statDisplayName(_ key: String) -> String {
        switch key {
        case "standing": return "Standing"
        case "network": return "Network"
        case "rivalThreat": return "Rival Threat"
        case "patronFavor": return "Patron Favor"
        case "reputationCunning": return "Cunning"
        case "reputationLoyal": return "Loyalty Rep"
        default: return key.capitalized
        }
    }

    // Evidence display helpers
    private var evidenceBar: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(index < evidenceBarFill ? evidenceLevelColor : theme.inkLight.opacity(0.2))
                    .frame(width: 16, height: 6)
            }
        }
    }

    private var evidenceBarFill: Int {
        switch character.evidenceLevel {
        case 0..<20: return 1
        case 20..<40: return 2
        case 40..<60: return 3
        case 60..<80: return 4
        default: return 5
        }
    }

    private var evidenceLevelText: String {
        switch character.evidenceLevel {
        case 0..<20: return "NONE"
        case 20..<40: return "WEAK"
        case 40..<60: return "MODERATE"
        case 60..<80: return "STRONG"
        default: return "OVERWHELMING"
        }
    }

    private var evidenceLevelColor: Color {
        switch character.evidenceLevel {
        case 0..<30: return theme.stampRed
        case 30..<60: return Color(hex: "FF9800")
        default: return Color.green.opacity(0.8)
        }
    }

    private var isProtectedByPatron: Bool {
        guard let game = game,
              let patron = game.characters.first(where: { $0.isPatron }) else { return false }

        if let charFaction = character.factionId,
           let patronFaction = patron.factionId,
           charFaction == patronFaction {
            return true
        }
        return false
    }

    private var levelBadgeValue: Int? {
        // Assign level based on character importance
        if character.isPatron { return 4 }
        if character.isRival { return 3 }
        return nil
    }

    // MARK: - Relationship Section

    private var relationshipSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RELATIONSHIP")
                .font(theme.tagFont)
                .tracking(1)
                .foregroundColor(theme.inkGray)

            VStack(alignment: .leading, spacing: 8) {
                if character.isPatron {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundColor(.statHigh)
                        Text("This is your PATRON")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }
                    Text("Your political protector. Keep them satisfied to maintain your position.")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                }

                if character.isRival {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.statLow)
                        Text("This is your RIVAL")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }
                    Text("They seek to undermine you at every opportunity. Watch your back.")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                }

                if !character.isPatron && !character.isRival {
                    HStack(spacing: 8) {
                        Image(systemName: "person.fill")
                            .foregroundColor(theme.inkGray)
                        Text("Role: \(character.currentRole.rawValue.capitalized)")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Status Section

    private func statusSection(_ details: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(Color(hex: "FF9800"))
                Text("CURRENT STATUS")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(Color(hex: "FF9800"))
            }

            Text(details)
                .font(theme.bodyFont)
                .foregroundColor(theme.inkBlack)
        }
        .padding(16)
        .background(Color(hex: "FF9800").opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(Color(hex: "FF9800"), lineWidth: 1)
        )
    }

    // MARK: - Character History Section

    private func characterHistorySection(game: Game) -> some View {
        // Get all events involving this character
        let characterEvents = game.events.filter { event in
            // Check if event involves this character
            if event.details["characterId"] == character.id.uuidString {
                return true
            }
            if event.details["characterName"] == character.name {
                return true
            }
            // Check summary for character name
            if event.summary.contains(character.name) {
                return true
            }
            return false
        }.sorted { $0.turnNumber > $1.turnNumber } // Most recent first

        // Get NPC-to-NPC interaction history
        let npcInteractions = character.interactionHistory.sorted { $0.turnNumber > $1.turnNumber }

        let totalItems = characterEvents.count + npcInteractions.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(theme.inkGray)
                Text("HISTORY")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                if totalItems > 0 {
                    Text("\(totalItems) events")
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkLight)
                }
            }

            if totalItems == 0 {
                HStack(spacing: 8) {
                    Text("Introduced Turn \(character.introducedTurn)")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkGray)
                    Text("•")
                        .foregroundColor(theme.inkLight)
                    Text("No significant interactions yet")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkLight)
                        .italic()
                }
            } else {
                // Show NPC-to-NPC interactions (political maneuvering)
                if !npcInteractions.isEmpty {
                    ForEach(npcInteractions.prefix(5), id: \.turnNumber) { interaction in
                        NPCInteractionRow(interaction: interaction)
                    }
                }

                // Show game events involving this character
                ForEach(characterEvents.prefix(max(0, 5 - npcInteractions.count)), id: \.id) { event in
                    CharacterHistoryEventRow(event: event, game: game)
                }

                if totalItems > 5 {
                    Text("+ \(totalItems - 5) more events...")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkLight)
                        .italic()
                        .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - NPC Interaction Row

    private struct NPCInteractionRow: View {
        let interaction: CharacterInteractionRecord
        @Environment(\.theme) var theme

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                // Turn number badge
                Text("T\(interaction.turnNumber)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.inkLight)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    // What happened
                    Text(interaction.outcomeEffect)
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkBlack)

                    // Context
                    Text(interaction.scenarioSummary)
                        .font(.system(size: 10))
                        .foregroundColor(theme.inkGray)
                        .italic()
                }

                Spacer()

                // Disposition change indicator
                if interaction.dispositionChange != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: interaction.dispositionChange > 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8))
                        Text("\(abs(interaction.dispositionChange))")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(interaction.dispositionChange > 0 ? Color.green : theme.sovietRed)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Interactions Section

    private func interactionsSection(game: Game) -> some View {
        let interactions = CharacterInteractionSystem.shared.getAvailableInteractions(for: character, game: game)
        let canInteract = game.canInteractWithCharacters
        let remaining = game.remainingInteractionsThisTurn

        return VStack(alignment: .leading, spacing: 12) {
            // Header with interaction limit indicator
            HStack {
                Text("AVAILABLE ACTIONS")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(theme.inkGray)

                Spacer()

                // Interaction limit indicator
                HStack(spacing: 4) {
                    ForEach(0..<Game.maxInteractionsPerTurn, id: \.self) { index in
                        Circle()
                            .fill(index < remaining ? theme.accentGold : theme.inkLight.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                    Text("\(remaining) left")
                        .font(.system(size: 10))
                        .foregroundColor(remaining > 0 ? theme.inkGray : theme.stampRed)
                }
            }

            if !canInteract {
                // No more interactions this turn
                VStack(spacing: 4) {
                    Text("You've used all your interactions this turn.")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.stampRed)

                    Text("End your turn to interact with characters again.")
                        .font(theme.bodyFontSmall)
                        .foregroundColor(theme.inkLight)
                        .italic()
                }
                .padding(.vertical, 8)
            } else if interactions.isEmpty {
                Text("No actions available for this character at your current rank.")
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkLight)
                    .italic()
            } else {
                ForEach(interactions) { interaction in
                    InteractionButton(
                        interaction: interaction,
                        character: character,
                        game: game,
                        onResult: { result in
                            lastInteractionResult = result
                            lastLeaderResult = nil
                            withAnimation {
                                showingInteractionResult = true
                            }
                        },
                        onLeaderResult: { result in
                            lastLeaderResult = result
                            lastInteractionResult = nil
                            withAnimation {
                                showingInteractionResult = true
                            }
                        }
                    )
                }
            }
        }
        .padding(16)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Interaction Result Card

    private func interactionResultCard(_ result: InteractionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.success ? .statHigh : .statLow)
                Text(result.success ? "SUCCESS" : "FAILED")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(result.success ? .statHigh : .statLow)
                Spacer()
                Button {
                    withAnimation {
                        showingInteractionResult = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.inkGray)
                }
            }

            if let game = game {
                ClickableNarrativeText(
                    text: result.narrative,
                    game: game,
                    font: theme.bodyFont,
                    color: theme.inkBlack
                )
            } else {
                Text(result.narrative)
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkBlack)
            }

            // Effects
            if !result.effects.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(result.effects.keys), id: \.self) { key in
                        if let value = result.effects[key], value != 0 {
                            StatChangeTag(key: key, value: value)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(result.success ? Color.statHigh.opacity(0.1) : Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(result.success ? Color.statHigh : Color.statLow, lineWidth: 1)
        )
    }

    // MARK: - Leader Result Card

    private func leaderResultCard(_ result: LeaderActionResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.success ? "crown.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(result.success ? theme.accentGold : .statLow)
                Text(result.success ? "ORDER EXECUTED" : "ORDER FAILED")
                    .font(theme.tagFont)
                    .tracking(1)
                    .foregroundColor(result.success ? theme.accentGold : .statLow)
                Spacer()
                Button {
                    withAnimation {
                        showingInteractionResult = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(theme.inkGray)
                }
            }

            if let game = game {
                ClickableNarrativeText(
                    text: result.narrative,
                    game: game,
                    font: theme.bodyFont,
                    color: theme.inkBlack
                )
            } else {
                Text(result.narrative)
                    .font(theme.bodyFont)
                    .foregroundColor(theme.inkBlack)
            }

            // New status if any
            if let newStatus = result.newStatus {
                HStack {
                    Text("Status changed to:")
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                    Text(newStatus.displayText.uppercased())
                        .font(theme.tagFont)
                        .fontWeight(.bold)
                        .foregroundColor(theme.stampRed)
                }
            }

            // Repercussions
            if !result.repercussions.isEmpty {
                Text("REPERCUSSIONS:")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    ForEach(Array(result.repercussions.keys), id: \.self) { key in
                        if let value = result.repercussions[key], value != 0 {
                            StatChangeTag(key: key, value: value)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(result.success ? theme.accentGold.opacity(0.1) : Color.statLow.opacity(0.1))
        .overlay(
            Rectangle()
                .stroke(result.success ? theme.accentGold : Color.statLow, lineWidth: 1)
        )
    }
}

// MARK: - Interaction Button

private struct InteractionButton: View {
    let interaction: CharacterInteraction
    let character: GameCharacter
    let game: Game
    let onResult: (InteractionResult) -> Void
    let onLeaderResult: (LeaderActionResult) -> Void
    @Environment(\.theme) var theme

    private var isLeaderPower: Bool {
        interaction.id.hasPrefix("leader_")
    }

    private var riskColor: Color {
        switch interaction.riskLevel {
        case .low: return .statHigh
        case .medium: return .statMedium
        case .high: return .statLow
        }
    }

    var body: some View {
        Button {
            executeInteraction()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: interaction.category.icon)
                        .foregroundColor(isLeaderPower ? theme.accentGold : theme.inkGray)
                    Text(interaction.title)
                        .font(theme.labelFont)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.inkBlack)
                    Spacer()
                    // Risk indicator
                    HStack(spacing: 2) {
                        Circle()
                            .fill(riskColor)
                            .frame(width: 6, height: 6)
                        Text(interaction.riskLevel.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(riskColor)
                    }
                }

                ClickableNarrativeText(
                    text: interaction.description,
                    game: game,
                    font: theme.bodyFontSmall,
                    color: theme.inkGray
                )
                .multilineTextAlignment(.leading)

                if let flavor = interaction.flavorText {
                    Text(flavor)
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(theme.inkLight)
                }
            }
            .padding(12)
            .background(isLeaderPower ? theme.accentGold.opacity(0.05) : theme.parchment)
            .overlay(
                Rectangle()
                    .stroke(isLeaderPower ? theme.accentGold.opacity(0.5) : theme.borderTan, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func executeInteraction() {
        // Track the interaction usage
        game.useCharacterInteraction()

        // Log the interaction as a game event for history tracking
        let event = GameEvent(
            turnNumber: game.turnNumber,
            eventType: .personalAction,
            summary: "\(interaction.title) with \(character.name)"
        )
        event.details["characterId"] = character.id.uuidString
        event.details["characterName"] = character.name
        event.details["interactionId"] = interaction.id
        event.details["interactionType"] = interaction.category.rawValue
        event.importance = 4
        game.events.append(event)

        if isLeaderPower {
            let result = CharacterInteractionSystem.shared.executeLeaderAction(interaction, target: character, game: game)
            // Apply repercussions to game
            for (key, value) in result.repercussions {
                game.applyStat(key, change: value)
            }
            // Update character status if action succeeded
            if result.success, let newStatus = result.newStatus {
                character.status = newStatus.rawValue
                character.statusChangedTurn = game.turnNumber
                character.statusDetails = result.narrative

                // Notify player of character fate change
                NotificationService.shared.notifyCharacterFate(
                    name: character.name,
                    fate: newStatus.displayText,
                    turn: game.turnNumber
                )
            }
            // Update event with result
            event.details["success"] = result.success ? "true" : "false"
            event.details["narrative"] = result.narrative
            if let newStatus = result.newStatus {
                event.details["newStatus"] = newStatus.rawValue
            }
            onLeaderResult(result)
        } else {
            let result = CharacterInteractionSystem.shared.executeInteraction(interaction, with: character, game: game)
            // Apply effects to game
            for (key, value) in result.effects {
                game.applyStat(key, change: value)
            }
            // Update character disposition
            character.disposition = max(-100, min(100, character.disposition + result.dispositionChange))
            // Update event with result
            event.details["success"] = result.success ? "true" : "false"
            event.details["narrative"] = result.narrative
            onResult(result)
        }
    }
}

// MARK: - Personality Trait Row

private struct PersonalityTraitRow: View {
    let trait: String
    let value: Int
    @Environment(\.theme) var theme

    private var level: String {
        switch value {
        case 70...: return "High"
        case 40..<70: return "Moderate"
        default: return "Low"
        }
    }

    private var color: Color {
        switch value {
        case 70...: return theme.inkBlack
        case 40..<70: return theme.inkGray
        default: return theme.inkLight
        }
    }

    var body: some View {
        HStack {
            Text(trait)
                .font(theme.bodyFontSmall)
                .foregroundColor(theme.inkGray)
            Spacer()
            Text(level)
                .font(theme.tagFont)
                .foregroundColor(color)
        }
        .padding(8)
        .background(theme.parchment.opacity(0.5))
    }
}

// MARK: - Character History Event Row

private struct CharacterHistoryEventRow: View {
    let event: GameEvent
    let game: Game
    @Environment(\.theme) var theme

    private var eventIcon: String {
        switch event.currentEventType {
        case .personalAction: return "person.crop.circle"
        case .death: return "xmark.circle.fill"
        case .crisis: return "exclamationmark.triangle.fill"
        case .decision: return "doc.text.fill"
        case .promotion: return "arrow.up.circle.fill"
        case .demotion: return "arrow.down.circle.fill"
        default: return "circle.fill"
        }
    }

    private var eventColor: Color {
        // Check for success/failure in details
        if let success = event.details["success"] {
            return success == "true" ? .statHigh : .statLow
        }
        switch event.currentEventType {
        case .death: return .statLow
        case .promotion: return .statHigh
        case .demotion: return .statLow
        default: return theme.inkGray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Turn indicator
            VStack {
                Text("T\(event.turnNumber)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(theme.inkLight)
            }
            .frame(width: 28)

            // Event icon
            Image(systemName: eventIcon)
                .font(.system(size: 12))
                .foregroundColor(eventColor)
                .frame(width: 16)

            // Event content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.summary)
                    .font(theme.bodyFontSmall)
                    .foregroundColor(theme.inkBlack)
                    .lineLimit(2)

                // Show narrative if available
                if let narrative = event.details["narrative"], !narrative.isEmpty {
                    ClickableNarrativeText(
                        text: narrative,
                        game: game,
                        font: .system(size: 10),
                        color: theme.inkGray
                    )
                    .lineLimit(2)
                    .italic()
                }

                // Show outcome badge if interaction
                if let success = event.details["success"] {
                    Text(success == "true" ? "SUCCESS" : "FAILED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(success == "true" ? .statHigh : .statLow)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background((success == "true" ? Color.statHigh : Color.statLow).opacity(0.15))
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(theme.parchment.opacity(0.5))
    }
}

// MARK: - Character Template Card (for initial setup)

struct CharacterTemplateCardView: View {
    let template: CharacterTemplate
    @Environment(\.theme) var theme

    /// Portrait image name (if asset exists)
    private var portraitImageName: String? {
        let idToAsset: [String: String] = [
            "wallace": "WallacePortrait",
            "kennedy": "KennedyPortrait",
            "anderson": "AndersonPortrait",
            "peterson": "PetersonPortrait",
        ]
        return idToAsset[template.id]
    }

    private var stanceTags: [StanceTag] {
        var tags: [StanceTag] = []
        if template.isPatron { tags.append(.patron) }
        if template.isRival { tags.append(.rival) }
        if !template.isPatron && !template.isRival && template.startingDisposition >= 60 {
            tags.append(.ally)
        }
        return tags
    }

    var body: some View {
        HStack(spacing: 12) {
            // Character portrait
            CharacterPortrait(
                name: template.name,
                imageName: portraitImageName,
                size: 50,
                showFrame: true
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(template.name)
                    .font(theme.labelFont)
                    .fontWeight(.bold)
                    .foregroundColor(theme.inkBlack)

                Text(template.title)
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)

                HStack(spacing: 5) {
                    ForEach(stanceTags, id: \.self) { stance in
                        StanceTagView(stance: stance)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(12)
        .background(theme.parchmentDark)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }
}

// MARK: - Dossier Background

struct DossierBackground: View {
    var body: some View {
        ZStack {
            // Base gray color
            Color(hex: "E8E8E8")

            // Dotted pattern
            Canvas { context, size in
                let dotSpacing: CGFloat = 20
                let dotSize: CGFloat = 2

                for row in stride(from: 0, to: size.height, by: dotSpacing) {
                    for col in stride(from: 0, to: size.width, by: dotSpacing) {
                        context.fill(
                            Path(ellipseIn: CGRect(
                                x: col + dotSpacing/2 - dotSize/2,
                                y: row + dotSpacing/2 - dotSize/2,
                                width: dotSize,
                                height: dotSize
                            )),
                            with: .color(Color(hex: "D0D0D0"))
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    let character = GameCharacter(templateId: "wallace", name: "Director Wallace", title: "Head of State Security", role: .patron)
    character.isPatron = true
    character.isRival = false
    character.personalityParanoid = 80
    character.personalityRuthless = 90

    return VStack(spacing: 10) {
        CharacterCardView(character: character)
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
    .environment(\.theme, ColdWarTheme())
}
