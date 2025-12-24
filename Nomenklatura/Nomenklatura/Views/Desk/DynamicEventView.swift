//
//  DynamicEventView.swift
//  Nomenklatura
//
//  UI for displaying dynamic events - character messages, summons,
//  consequence callbacks, and ambient tension
//

import SwiftUI

// MARK: - Dynamic Event View

struct DynamicEventView: View {
    let event: DynamicEvent
    let game: Game
    let onDismiss: (EventResponse?) -> Void

    @State private var showContent = false
    @State private var selectedResponse: EventResponse?
    @State private var showEventTypeHelp = false

    private let theme = ColdWarTheme()

    var body: some View {
        ZStack {
            // Background based on urgency
            backgroundView

            // Content
            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Character portrait if character-initiated
                        if event.initiatingCharacterId != nil {
                            characterHeader
                        }

                        // Event content
                        eventContent

                        // Response options
                        if let options = event.responseOptions {
                            responseOptions(options)
                        } else {
                            simpleAcknowledge
                        }
                    }
                    .padding(24)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 80) // Space for tab bar
                }
            }
            .background(theme.parchment)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Ensure space above tab bar
            .padding(.top, event.isUrgent ? 60 : 40)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
        .modifier(CharacterSheetOverlayModifier(game: game))
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundView: some View {
        if event.isUrgent || event.priority >= .urgent {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
        } else {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Tappable event type button
            Button {
                showEventTypeHelp = true
            } label: {
                HStack(spacing: 8) {
                    // Icon
                    Image(systemName: event.iconName ?? event.eventType.defaultIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(headerColor)

                    // Event type label
                    Text(event.eventType.displayName.uppercased())
                        .font(theme.tagFont)
                        .tracking(2)
                        .foregroundColor(headerColor)

                    // Help indicator
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(headerColor.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Urgency indicator
            if event.isUrgent {
                Text("URGENT")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(theme.stampRed)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(headerBackgroundColor)
        .sheet(isPresented: $showEventTypeHelp) {
            EventTypeHelpView(eventType: event.eventType)
        }
    }

    private var headerColor: Color {
        switch event.eventType {
        case .characterSummons, .urgentInterruption:
            return theme.stampRed
        case .patronDirective:
            return theme.accentGold
        case .rivalAction:
            return theme.sovietRed
        case .networkIntel:
            return theme.accentGold
        case .ambientTension:
            return theme.inkGray
        default:
            return theme.inkBlack
        }
    }

    private var headerBackgroundColor: Color {
        if event.isUrgent {
            return theme.parchment.opacity(0.95)
        }
        return theme.parchment
    }

    // MARK: - Character Header

    @ViewBuilder
    private var characterHeader: some View {
        if let characterName = event.initiatingCharacterName {
            HStack(spacing: 12) {
                // Character portrait placeholder
                ZStack {
                    Circle()
                        .fill(theme.parchmentDark)
                        .frame(width: 50, height: 50)

                    Text(String(characterName.prefix(1)))
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundColor(theme.inkGray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    TappableName(name: characterName, game: game)
                        .font(theme.headerFont)

                    Text(characterRoleText)
                        .font(theme.tagFont)
                        .foregroundColor(theme.inkGray)
                }

                Spacer()
            }
            .padding(.bottom, 8)
        }
    }

    private var characterRoleText: String {
        if let charId = event.initiatingCharacterId,
           let character = game.characters.first(where: { $0.id == charId }) {
            if character.isPatron {
                return "Your Patron"
            } else if character.isRival {
                return "Your Rival"
            } else if character.disposition > 65 {
                return "Ally"
            } else if character.role == CharacterRole.contact.rawValue {
                return "Network Contact"
            }
        }
        return "Official"
    }

    // MARK: - Event Content

    private var eventContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(event.title)
                .font(theme.headerFontLarge)
                .foregroundColor(theme.inkBlack)

            // Divider
            Rectangle()
                .fill(theme.borderTan)
                .frame(height: 1)

            // Main text with clickable character names
            ClickableNarrativeText(
                text: event.briefText,
                game: game,
                font: theme.narrativeFont,
                color: theme.inkBlack,
                lineSpacing: 6
            )
            .fixedSize(horizontal: false, vertical: true)

            // Detailed text if present with clickable character names
            if let detailed = event.detailedText {
                ClickableNarrativeText(
                    text: detailed,
                    game: game,
                    font: theme.bodyFont,
                    color: theme.inkGray,
                    lineSpacing: 4
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            // Flavor text
            if let flavor = event.flavorText {
                Text(flavor)
                    .font(theme.bodyFontSmall)
                    .italic()
                    .foregroundColor(theme.inkLight)
            }
        }
    }

    // MARK: - Response Options

    private func responseOptions(_ options: [EventResponse]) -> some View {
        VStack(spacing: 12) {
            // Section label
            Text("YOUR RESPONSE")
                .font(theme.tagFont)
                .tracking(2)
                .foregroundColor(theme.inkGray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            ForEach(options) { option in
                EventResponseButton(
                    option: option,
                    isSelected: selectedResponse?.id == option.id,
                    theme: theme
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedResponse = option
                    }

                    // Slight delay before dismissing
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showContent = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onDismiss(option)
                        }
                    }
                }
            }
        }
    }

    private var simpleAcknowledge: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                showContent = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss(nil)
            }
        } label: {
            Text("Continue")
                .font(theme.labelFont)
                .foregroundColor(theme.inkBlack)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.parchmentDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(theme.borderTan, lineWidth: 1)
                )
                .cornerRadius(8)
        }
        .padding(.top, 8)
    }
}

// MARK: - Event Response Button

struct EventResponseButton: View {
    let option: EventResponse
    let isSelected: Bool
    let theme: ColdWarTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Option text
                HStack {
                    Text(option.shortText ?? option.text)
                        .font(theme.labelFont)
                        .foregroundColor(isSelected ? .white : theme.inkBlack)

                    Spacer()

                    // Risk indicator
                    if let risk = option.riskLevel {
                        riskBadge(risk)
                    }
                }

                // Effects preview
                if !option.effects.isEmpty {
                    effectsPreview
                }

                // Follow-up hint
                if let hint = option.followUpHint {
                    Text(hint)
                        .font(theme.bodyFontSmall)
                        .italic()
                        .foregroundColor(isSelected ? .white.opacity(0.8) : theme.inkLight)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? theme.stampRed : theme.parchmentDark)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var borderColor: Color {
        if isSelected {
            return theme.stampRed
        }
        if let risk = option.riskLevel {
            switch risk {
            case .high: return theme.stampRed.opacity(0.5)
            case .medium: return theme.accentGold.opacity(0.5)
            case .low: return theme.borderTan
            }
        }
        return theme.borderTan
    }

    private func riskBadge(_ risk: EventResponse.RiskLevel) -> some View {
        Text(risk.rawValue.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundColor(riskColor(risk))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(riskColor(risk).opacity(0.15))
            .cornerRadius(4)
    }

    private func riskColor(_ risk: EventResponse.RiskLevel) -> Color {
        switch risk {
        case .high: return isSelected ? .white : theme.stampRed
        case .medium: return isSelected ? .white : theme.accentGold
        case .low: return isSelected ? .white : Color(hex: "4CAF50")
        }
    }

    private var effectsPreview: some View {
        HStack(spacing: 8) {
            ForEach(Array(option.effects.keys.sorted().prefix(3)), id: \.self) { key in
                if let value = option.effects[key] {
                    StatChangeTag(key: formatStatKey(key), value: value)
                }
            }
        }
    }

    private func formatStatKey(_ key: String) -> String {
        switch key {
        case "patronFavor": return "Favor"
        case "rivalThreat": return "Threat"
        case "reputationCunning": return "Cunning"
        case "reputationLoyal": return "Loyal"
        case "reputationRuthless": return "Ruthless"
        default: return key.capitalized
        }
    }
}

// MARK: - Ambient Tension View (Subtle variant)

struct AmbientTensionView: View {
    let event: DynamicEvent
    let game: Game
    let onDismiss: () -> Void

    @State private var expanded = false
    @State private var showContent = false

    private let theme = ColdWarTheme()

    var body: some View {
        VStack(spacing: 0) {
            if !expanded {
                // Collapsed state - subtle banner
                collapsedView
            } else {
                // Expanded - full text
                expandedView
            }
        }
        .background(theme.parchment.opacity(0.95))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .padding(.horizontal, 20)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }
        .modifier(CharacterSheetOverlayModifier(game: game))
    }

    private var collapsedView: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                expanded = true
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(theme.inkGray)

                Text(event.title)
                    .font(theme.tagFont)
                    .italic()
                    .foregroundColor(theme.inkGray)

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundColor(theme.inkLight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var expandedView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .font(.caption)
                    .foregroundColor(theme.inkGray)

                Text(event.title)
                    .font(theme.labelFont)
                    .foregroundColor(theme.inkBlack)

                Spacer()
            }

            // Content with clickable character names
            ClickableNarrativeText(
                text: event.briefText,
                game: game,
                font: theme.narrativeFont,
                color: theme.inkGray,
                lineSpacing: 4
            )

            // Dismiss
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    showContent = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            } label: {
                Text("Continue")
                    .font(theme.tagFont)
                    .foregroundColor(theme.inkGray)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(theme.parchmentDark)
                    .cornerRadius(6)
            }
        }
        .padding(16)
    }
}

// MARK: - Summons Overlay (Urgent variant)

struct SummonsOverlayView: View {
    let event: DynamicEvent
    let game: Game
    let onProceed: () -> Void

    @State private var showContent = false
    @State private var pulseAnimation = false

    private let theme = ColdWarTheme()

    var body: some View {
        ZStack {
            // Dark urgent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Warning icon with pulse
                ZStack {
                    Circle()
                        .fill(theme.stampRed.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .opacity(pulseAnimation ? 0.5 : 1.0)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(theme.stampRed)
                }

                // Title
                Text(event.title)
                    .font(theme.heroFont)
                    .foregroundColor(.white)
                    .tracking(4)
                    .multilineTextAlignment(.center)

                // Content with clickable character names
                ClickableNarrativeText(
                    text: event.briefText,
                    game: game,
                    font: theme.narrativeFont,
                    color: .white.opacity(0.9),
                    lineSpacing: 6
                )
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                // Proceed button
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showContent = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onProceed()
                    }
                } label: {
                    Text("PROCEED")
                        .font(theme.labelFont)
                        .tracking(2)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding(.vertical, 16)
                        .background(theme.stampRed)
                        .cornerRadius(8)
                }
                .padding(.top, 16)
            }
            .padding(32)
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.9)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                showContent = true
            }

            // Start pulse animation
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .modifier(CharacterSheetOverlayModifier(game: game))
    }
}

// MARK: - Event Type Help View

struct EventTypeHelpView: View {
    let eventType: DynamicEventType
    @Environment(\.dismiss) var dismiss

    private let theme = ColdWarTheme()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon and title
                    HStack(spacing: 16) {
                        Image(systemName: eventType.defaultIcon)
                            .font(.system(size: 36))
                            .foregroundColor(iconColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(eventType.displayName.uppercased())
                                .font(theme.headerFont)
                                .tracking(2)
                                .foregroundColor(theme.inkBlack)

                            Text("Event Type")
                                .font(theme.tagFont)
                                .foregroundColor(theme.inkGray)
                        }
                    }
                    .padding(.bottom, 10)

                    Divider()

                    // Description
                    Text(eventTypeDescription)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.inkBlack)
                        .lineSpacing(6)

                    // Gameplay tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GAMEPLAY TIPS")
                            .font(theme.tagFont)
                            .tracking(1)
                            .foregroundColor(theme.inkGray)

                        Text(eventTypeTips)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                            .lineSpacing(4)
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.inkBlack)
                }
            }
        }
    }

    private var iconColor: Color {
        switch eventType {
        case .characterSummons, .urgentInterruption: return theme.stampRed
        case .patronDirective: return theme.accentGold
        case .rivalAction: return theme.sovietRed
        case .networkIntel: return theme.accentGold
        case .ambientTension: return theme.inkGray
        default: return theme.inkBlack
        }
    }

    private var eventTypeDescription: String {
        switch eventType {
        case .characterMessage:
            return "A character in your network has reached out to you informally. This could be a warning, an offer of assistance, or simply a check-in. How you respond may affect your relationship with them."

        case .characterSummons:
            return "You have been summoned by someone with authority over you—or someone who believes they have that authority. Ignoring a summons from a superior can have serious consequences."

        case .consequenceCallback:
            return "A decision you made in the past has come back to affect you. In the Party, nothing is ever truly forgotten. Your choices echo through time, and now you must deal with the results."

        case .urgentInterruption:
            return "A crisis has broken out that demands your immediate attention. These events cannot be ignored and often have significant consequences regardless of how you respond."

        case .ambientTension:
            return "Whispers in the corridors, uneasy glances, a change in atmosphere. Something is brewing, but it's not yet clear what. Consider this a warning of things to come."

        case .rivalAction:
            return "One of your rivals has made a move against you. They may be undermining your position, spreading rumors, or actively working to destroy you. Your response will determine whether you survive this challenge."

        case .patronDirective:
            return "Your patron—the powerful figure who protects and advances your career—has contacted you with orders, advice, or a warning. Ignoring your patron's wishes is dangerous."

        case .networkIntel:
            return "Your network of contacts has gathered intelligence that may be useful to you. Information is power in the Party, and knowing what others don't can mean the difference between promotion and purge."

        case .allyRequest:
            return "An ally has asked for your help. Helping them may strengthen your relationship and earn their loyalty, but it may also cost you resources or put you in a difficult position."

        case .worldNews:
            return "Events in the wider world are affecting the political landscape. International crises, economic developments, or policy changes may create opportunities or dangers for you."
        }
    }

    private var eventTypeTips: String {
        switch eventType {
        case .characterMessage:
            return "Pay attention to who is reaching out and why. Building relationships with the right people can save your career—or your life."

        case .characterSummons:
            return "When summoned, consider your options carefully. Sometimes compliance is wise; other times, it may be a trap."

        case .consequenceCallback:
            return "Remember that every choice has consequences. Try to think ahead when making decisions, and be prepared to face the results of your past actions."

        case .urgentInterruption:
            return "In a crisis, staying calm is essential. Look for the response that best protects your position while minimizing damage."

        case .ambientTension:
            return "Use these warnings to prepare. Strengthen your alliances, build your network, and watch your rivals closely."

        case .rivalAction:
            return "When rivals attack, you must respond decisively. Showing weakness invites further aggression. But be careful—overreaction can make you look paranoid."

        case .patronDirective:
            return "Your patron's favor is your lifeline. Keep them happy, follow their guidance, and never forget that they expect loyalty."

        case .networkIntel:
            return "Information is only valuable if you act on it. Consider how you can use what you've learned to advance your position."

        case .allyRequest:
            return "Strong allies are essential for survival. Help them when you can, but don't let their problems drag you down."

        case .worldNews:
            return "External events can shift the balance of power. Watch for opportunities to position yourself advantageously as the political winds change."
        }
    }
}

// MARK: - Preview

#Preview {
    let mockEvent = DynamicEvent(
        eventType: .patronDirective,
        priority: .elevated,
        title: "A Word of Caution",
        briefText: "Director Wallace catches your eye across the ministry corridor and gestures subtly toward an empty office.\n\n\"Be careful,\" they say quietly. \"Your rivals are circling. I may not always be able to protect you.\"",
        initiatingCharacterId: UUID(),
        initiatingCharacterName: "Director Wallace",
        turnGenerated: 5,
        isUrgent: false,
        responseOptions: [
            EventResponse(id: "acknowledge", text: "Thank your patron for the warning", shortText: "Acknowledge", effects: [:]),
            EventResponse(id: "ask", text: "Ask what you should do", shortText: "Seek Guidance", effects: ["patronFavor": 3]),
            EventResponse(id: "dismiss", text: "Assure them you have everything under control", shortText: "Dismiss", effects: ["patronFavor": -5], riskLevel: .medium)
        ],
        iconName: "hand.raised.fill",
        accentColor: "accentGold"
    )

    return DynamicEventView(
        event: mockEvent,
        game: Game(campaignId: "coldwar"),
        onDismiss: { _ in }
    )
}
