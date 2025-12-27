//
//  CareerTimelineView.swift
//  Nomenklatura
//
//  Interactive horizontal timeline showing career milestones
//  with vintage graph paper aesthetic and stat sparklines.
//

import SwiftUI

// MARK: - Career Timeline View

/// Horizontal scrolling timeline of career events with vintage styling
struct CareerTimelineView: View {
    let events: [CareerEvent]
    let standingHistory: [Int]
    let currentTurn: Int
    var onEventTap: ((CareerEvent) -> Void)? = nil

    // Filter state
    @State private var selectedFilter: EventFilter = .all
    @State private var selectedEvent: CareerEvent? = nil
    @State private var showEventDetail = false

    enum EventFilter: String, CaseIterable {
        case all = "ALL"
        case promotions = "RANK"
        case crises = "CRISIS"
        case characters = "PEOPLE"

        var matchingTypes: [CareerEventType] {
            switch self {
            case .all: return CareerEventType.allCases
            case .promotions: return [.joined, .promotion, .demotion, .achievement]
            case .crises: return [.crisis, .purge, .policyChange, .internationalEvent]
            case .characters: return [.patronChange, .rivalChange, .characterDeath]
            }
        }
    }

    private var filteredEvents: [CareerEvent] {
        events.filter { selectedFilter.matchingTypes.contains($0.type) }
            .sorted { $0.turn < $1.turn }
    }

    private var timelineWidth: CGFloat {
        max(CGFloat(currentTurn + 5) * 60, 400)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FiftiesColors.cardstock)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(FiftiesColors.leatherBrown.opacity(0.2))
                        .frame(height: 1)
                }

            // Timeline content
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .leading) {
                    // Graph paper background
                    GraphPaperBackground(
                        cellSize: 20,
                        lineColor: Color(hex: "D4C5A9").opacity(0.3),
                        backgroundColor: FiftiesColors.agedPaper
                    )
                    .frame(width: timelineWidth, height: 180)

                    // Standing sparkline at bottom
                    if !standingHistory.isEmpty {
                        TimelineSparkline(data: standingHistory, maxTurns: currentTurn)
                            .frame(width: timelineWidth - 40, height: 40)
                            .offset(x: 20, y: 130)
                    }

                    // Timeline axis
                    timelineAxis
                        .offset(y: 70)

                    // Event markers
                    ForEach(filteredEvents) { event in
                        TimelineEventMarker(
                            event: event,
                            isSelected: selectedEvent?.id == event.id
                        )
                        .position(
                            x: CGFloat(event.turn) * 60 + 30,
                            y: 50
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedEvent?.id == event.id {
                                    selectedEvent = nil
                                } else {
                                    selectedEvent = event
                                    onEventTap?(event)
                                }
                            }
                        }
                    }

                    // NOW marker
                    VStack(spacing: 2) {
                        Text("NOW")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.stampRed)

                        Rectangle()
                            .fill(FiftiesColors.stampRed)
                            .frame(width: 2, height: 100)
                    }
                    .position(x: CGFloat(currentTurn) * 60 + 30, y: 80)
                }
                .frame(width: timelineWidth, height: 180)
            }

            // Selected event detail
            if let event = selectedEvent {
                eventDetailCard(event: event)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(FiftiesColors.freshPaper)
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Text("TIMELINE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(FiftiesColors.leatherBrown)

            Spacer()

            ForEach(EventFilter.allCases, id: \.self) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 9, weight: selectedFilter == filter ? .bold : .medium, design: .monospaced))
                        .foregroundColor(selectedFilter == filter ? .white : FiftiesColors.fadedInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(selectedFilter == filter ? FiftiesColors.leatherBrown : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(FiftiesColors.leatherBrown.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Timeline Axis

    private var timelineAxis: some View {
        ZStack(alignment: .leading) {
            // Main axis line
            Rectangle()
                .fill(FiftiesColors.typewriterInk)
                .frame(width: timelineWidth, height: 2)

            // Turn markers
            ForEach(0...currentTurn, id: \.self) { turn in
                VStack(spacing: 2) {
                    // Tick mark
                    Rectangle()
                        .fill(FiftiesColors.typewriterInk)
                        .frame(width: turn % 5 == 0 ? 2 : 1, height: turn % 5 == 0 ? 12 : 6)

                    // Label for every 5 turns
                    if turn % 5 == 0 && turn > 0 {
                        Text("T\(turn)")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(FiftiesColors.fadedInk)
                    }
                }
                .offset(x: CGFloat(turn) * 60 + 28)
            }
        }
    }

    // MARK: - Event Detail Card

    private func eventDetailCard(event: CareerEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Event type icon
                Image(systemName: event.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(event.type.color))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)

                    Text(event.turnLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(FiftiesColors.fadedInk)
                }

                Spacer()

                // Close button
                Button {
                    withAnimation {
                        selectedEvent = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(FiftiesColors.fadedInk)
                }
                .buttonStyle(.plain)
            }

            Text(event.description)
                .font(.system(size: 12, design: .serif))
                .foregroundColor(FiftiesColors.fadedInk)
                .lineLimit(3)

            // Stat snapshot
            if !event.statSnapshot.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Array(event.statSnapshot.keys.sorted().prefix(4)), id: \.self) { key in
                        if let value = event.statSnapshot[key] {
                            VStack(spacing: 1) {
                                Text("\(value)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(FiftiesColors.typewriterInk)
                                Text(key.uppercased().prefix(4))
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(FiftiesColors.fadedInk)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(FiftiesColors.cardstock)
        .overlay(
            Rectangle()
                .stroke(FiftiesColors.leatherBrown.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Timeline Event Marker

struct TimelineEventMarker: View {
    let event: CareerEvent
    var isSelected: Bool = false

    private var markerSize: CGFloat {
        isSelected ? 28 : 20
    }

    var body: some View {
        ZStack {
            // Shadow/glow for selected
            if isSelected {
                Circle()
                    .fill(Color(event.type.color).opacity(0.3))
                    .frame(width: markerSize + 8, height: markerSize + 8)
            }

            // Marker shape
            markerShape
                .frame(width: markerSize, height: markerSize)
        }
        .animation(.spring(response: 0.3), value: isSelected)
    }

    @ViewBuilder
    private var markerShape: some View {
        switch event.type.markerShape {
        case .circle:
            ZStack {
                Circle()
                    .fill(Color(event.type.color))
                Circle()
                    .stroke(FiftiesColors.typewriterInk, lineWidth: 1.5)
                Image(systemName: event.type.icon)
                    .font(.system(size: markerSize * 0.4))
                    .foregroundColor(.white)
            }

        case .diamond:
            ZStack {
                Rectangle()
                    .fill(Color(event.type.color))
                    .rotationEffect(.degrees(45))
                    .frame(width: markerSize * 0.7, height: markerSize * 0.7)
                Rectangle()
                    .stroke(FiftiesColors.typewriterInk, lineWidth: 1.5)
                    .rotationEffect(.degrees(45))
                    .frame(width: markerSize * 0.7, height: markerSize * 0.7)
                Image(systemName: event.type.icon)
                    .font(.system(size: markerSize * 0.35))
                    .foregroundColor(.white)
            }

        case .square:
            ZStack {
                Rectangle()
                    .fill(Color(event.type.color))
                Rectangle()
                    .stroke(FiftiesColors.typewriterInk, lineWidth: 1.5)
                Image(systemName: event.type.icon)
                    .font(.system(size: markerSize * 0.4))
                    .foregroundColor(.white)
            }

        case .cross:
            ZStack {
                Image(systemName: "cross.fill")
                    .font(.system(size: markerSize))
                    .foregroundColor(Color(event.type.color))
                Image(systemName: "cross")
                    .font(.system(size: markerSize))
                    .foregroundColor(FiftiesColors.typewriterInk)
            }

        case .star:
            ZStack {
                Image(systemName: "star.fill")
                    .font(.system(size: markerSize))
                    .foregroundColor(Color(event.type.color))
                Image(systemName: "star")
                    .font(.system(size: markerSize))
                    .foregroundColor(FiftiesColors.typewriterInk)
            }
        }
    }
}

// MARK: - Timeline Sparkline

struct TimelineSparkline: View {
    let data: [Int]
    let maxTurns: Int

    var body: some View {
        GeometryReader { geometry in
            // Scale data to fit the timeline width
            let pointSpacing = geometry.size.width / CGFloat(max(1, maxTurns - 1))

            ZStack(alignment: .leading) {
                // Baseline at 50
                Path { path in
                    let y = geometry.size.height * 0.5
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                .foregroundColor(FiftiesColors.fadedInk.opacity(0.5))

                // Sparkline path
                if data.count >= 2 {
                    Path { path in
                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * pointSpacing
                            let y = geometry.size.height * (1 - CGFloat(value) / 100.0)

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(FiftiesColors.typewriterInk, style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        lineJoin: .round
                    ))
                    .shadow(color: FiftiesColors.typewriterInk.opacity(0.2), radius: 1)
                }
            }
        }
    }
}

// MARK: - Full Career Timeline Sheet

/// Full-screen sheet showing the complete career timeline
struct CareerTimelineSheet: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("CAREER DOSSIER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(FiftiesColors.fadedInk)

                    Text("Turn \(game.turnNumber) • \(game.currentPositionName)")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(FiftiesColors.typewriterInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(FiftiesColors.cardstock)

                // Timeline
                CareerTimelineView(
                    events: game.careerEvents,
                    standingHistory: game.standingHistory,
                    currentTurn: game.turnNumber
                )

                // Career summary stats
                careerSummary
            }
            .background(FiftiesColors.freshPaper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                }
            }
        }
    }

    private var careerSummary: some View {
        HStack(spacing: 20) {
            summaryBox(label: "TURNS", value: "\(game.turnNumber)")
            summaryBox(label: "PROMOTIONS", value: "\(countEvents(of: .promotion))")
            summaryBox(label: "CRISES", value: "\(countEvents(of: .crisis))")
            summaryBox(label: "PURGES", value: "\(countEvents(of: .purge))")
        }
        .padding()
        .background(FiftiesColors.cardstock)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(FiftiesColors.leatherBrown.opacity(0.2))
                .frame(height: 1)
        }
    }

    private func summaryBox(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(FiftiesColors.typewriterInk)
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(FiftiesColors.fadedInk)
        }
        .frame(maxWidth: .infinity)
    }

    private func countEvents(of type: CareerEventType) -> Int {
        game.careerEvents.filter { $0.type == type }.count
    }
}

// MARK: - Compact Timeline Widget

/// Smaller timeline widget for embedding in other views
struct CompactTimelineWidget: View {
    let events: [CareerEvent]
    let currentTurn: Int
    var onTap: (() -> Void)? = nil

    private var recentEvents: [CareerEvent] {
        Array(events.sorted { $0.turn > $1.turn }.prefix(5))
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CAREER TIMELINE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(FiftiesColors.fadedInk)

                    Spacer()

                    HStack(spacing: 2) {
                        Text("VIEW ALL")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(FiftiesColors.leatherBrown)
                }

                // Mini event row
                if recentEvents.isEmpty {
                    Text("Your career story begins...")
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .foregroundColor(FiftiesColors.fadedInk)
                } else {
                    HStack(spacing: 4) {
                        ForEach(recentEvents.reversed()) { event in
                            ZStack {
                                Circle()
                                    .fill(Color(event.type.color).opacity(0.2))
                                    .frame(width: 24, height: 24)
                                Image(systemName: event.type.icon)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(event.type.color))
                            }
                        }

                        Spacer()

                        Text("T-\(currentTurn)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.typewriterInk)
                    }
                }
            }
            .padding(12)
            .background(FiftiesColors.agedPaper)
            .overlay(
                Rectangle()
                    .stroke(FiftiesColors.leatherBrown.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Timeline") {
    CareerTimelineView(
        events: [
            CareerEvent(turn: 1, type: .joined, title: "Joined the Party", description: "Your career begins", statSnapshot: ["standing": 50]),
            CareerEvent(turn: 5, type: .promotion, title: "Promoted to Department Head", description: "Advanced in rank", statSnapshot: ["standing": 65]),
            CareerEvent(turn: 8, type: .patronChange, title: "Gained Patron", description: "Wallace has taken you under his protection", statSnapshot: ["standing": 70], characterName: "Gen. Wallace"),
            CareerEvent(turn: 12, type: .crisis, title: "Industrial Crisis", description: "Production targets missed", statSnapshot: ["standing": 62]),
            CareerEvent(turn: 15, type: .purge, title: "Survived Purge", description: "Close call with State Security", statSnapshot: ["standing": 58])
        ],
        standingHistory: [50, 52, 55, 58, 65, 68, 70, 72, 68, 65, 62, 60, 58, 55, 58],
        currentTurn: 15
    )
}

#Preview("Compact Widget") {
    CompactTimelineWidget(
        events: [
            CareerEvent(turn: 1, type: .joined, title: "Joined", description: "Started", statSnapshot: [:]),
            CareerEvent(turn: 5, type: .promotion, title: "Promoted", description: "Advanced", statSnapshot: [:]),
            CareerEvent(turn: 8, type: .crisis, title: "Crisis", description: "Trouble", statSnapshot: [:])
        ],
        currentTurn: 10
    )
    .padding()
    .background(Color(hex: "241F1C"))
}
