//
//  WorldMapView.swift
//  Nomenklatura
//
//  Propaganda-style map showing PSRA and neighboring nations
//

import SwiftUI
import SwiftData

struct WorldMapView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedNation: NationMapData?
    @State private var mapScale: CGFloat = 1.0
    @State private var mapOffset: CGSize = .zero

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Map background
                PropagandaMapCanvas(
                    nations: nationData,
                    selectedNation: $selectedNation,
                    accessLevel: accessLevel
                )
                .scaleEffect(mapScale)
                .offset(mapOffset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            mapScale = max(0.5, min(3.0, value))
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            mapOffset = value.translation
                        }
                )

                // Legend overlay
                VStack {
                    Spacer()
                    MapLegend()
                        .padding(.horizontal, 15)
                        .padding(.bottom, 10)
                }
            }
        }
        .sheet(item: $selectedNation) { nation in
            NationDetailSheet(nation: nation, game: game)
        }
    }

    // Map data for all nations based on PSRA alternate history
    private var nationData: [NationMapData] {
        [
            // PSRA (center)
            NationMapData(
                id: "psra",
                name: "P.S.R.A.",
                position: CGPoint(x: 0.5, y: 0.5),
                size: CGSize(width: 0.25, height: 0.3),
                relationshipType: .homeland,
                isPlayable: true
            ),

            // Socialist Allies
            NationMapData(
                id: "soviet_union",
                name: "U.S.S.R.",
                position: CGPoint(x: 0.15, y: 0.25),
                size: CGSize(width: 0.12, height: 0.15),
                relationshipType: .ally
            ),
            NationMapData(
                id: "germany",
                name: "GERMANY",
                position: CGPoint(x: 0.85, y: 0.45),
                size: CGSize(width: 0.1, height: 0.12),
                relationshipType: .ally
            ),

            // Hostile Nations
            NationMapData(
                id: "canada",
                name: "CANADA",
                position: CGPoint(x: 0.55, y: 0.2),
                size: CGSize(width: 0.2, height: 0.12),
                relationshipType: .hostile
            ),
            NationMapData(
                id: "cuba",
                name: "CUBA",
                position: CGPoint(x: 0.6, y: 0.75),
                size: CGSize(width: 0.08, height: 0.06),
                relationshipType: .rival
            ),
            NationMapData(
                id: "japan",
                name: "JAPAN",
                position: CGPoint(x: 0.1, y: 0.5),
                size: CGSize(width: 0.08, height: 0.12),
                relationshipType: .hostile
            ),
            NationMapData(
                id: "united_kingdom",
                name: "U.K.",
                position: CGPoint(x: 0.85, y: 0.25),
                size: CGSize(width: 0.08, height: 0.1),
                relationshipType: .hostile
            ),

            // Neutral / Other
            NationMapData(
                id: "mexico",
                name: "MEXICO",
                position: CGPoint(x: 0.4, y: 0.75),
                size: CGSize(width: 0.12, height: 0.1),
                relationshipType: .neutral
            ),
            NationMapData(
                id: "france",
                name: "FRANCE",
                position: CGPoint(x: 0.85, y: 0.55),
                size: CGSize(width: 0.08, height: 0.1),
                relationshipType: .hostile
            ),

            // Pacific (Hawaii under Japanese occupation)
            NationMapData(
                id: "hawaii",
                name: "HAWAII",
                position: CGPoint(x: 0.2, y: 0.6),
                size: CGSize(width: 0.06, height: 0.04),
                relationshipType: .hostile
            )
        ]
    }
}

// MARK: - Nation Map Data

struct NationMapData: Identifiable {
    let id: String
    let name: String
    let position: CGPoint      // Relative position (0-1)
    let size: CGSize           // Relative size (0-1)
    let relationshipType: RelationshipType
    var isPlayable: Bool = false

    enum RelationshipType {
        case homeland
        case ally
        case satellite
        case neutral
        case hostile
        case rival
        case unknown

        var color: Color {
            switch self {
            case .homeland: return Color(hex: "8B0000")   // Deep red
            case .ally: return Color(hex: "CD5C5C")       // Indian red
            case .satellite: return Color(hex: "DB7093")  // Pale violet red
            case .neutral: return Color(hex: "808080")    // Gray
            case .hostile: return Color(hex: "4169E1")    // Royal blue
            case .rival: return Color(hex: "FF8C00")      // Dark orange
            case .unknown: return Color(hex: "2F4F4F")    // Dark slate gray
            }
        }

        var borderColor: Color {
            switch self {
            case .homeland: return Color(hex: "FFD700")   // Gold border for homeland
            case .ally, .satellite: return Color(hex: "8B0000")
            case .neutral: return Color(hex: "696969")
            case .hostile: return Color(hex: "000080")
            case .rival: return Color(hex: "8B4513")
            case .unknown: return Color(hex: "1C1C1C")
            }
        }
    }
}

// MARK: - Propaganda Map Canvas

struct PropagandaMapCanvas: View {
    let nations: [NationMapData]
    @Binding var selectedNation: NationMapData?
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Aged paper background
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "D4C4A8"),
                                Color(hex: "C4B698"),
                                Color(hex: "D4C4A8")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Grid lines (propaganda style)
                mapGridLines(in: geometry.size)

                // Ocean areas
                oceanAreas(in: geometry.size)

                // Nations
                ForEach(nations) { nation in
                    NationShape(
                        nation: nation,
                        size: geometry.size,
                        isSelected: selectedNation?.id == nation.id,
                        accessLevel: accessLevel
                    )
                    .onTapGesture {
                        if nation.id != "unknown_east" {
                            selectedNation = nation
                        }
                    }
                }

                // Map decorations
                mapDecorations(in: geometry.size)

                // Title cartouche
                VStack {
                    mapTitle
                    Spacer()
                }
            }
        }
    }

    private func mapGridLines(in size: CGSize) -> some View {
        Canvas { context, size in
            let gridColor = Color(hex: "B8A888").opacity(0.3)

            // Horizontal lines
            for i in 0...10 {
                let y = CGFloat(i) * size.height / 10
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }

            // Vertical lines
            for i in 0...10 {
                let x = CGFloat(i) * size.width / 10
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
            }
        }
    }

    private func oceanAreas(in size: CGSize) -> some View {
        // Western ocean
        Rectangle()
            .fill(Color(hex: "87CEEB").opacity(0.3))
            .frame(width: size.width * 0.08, height: size.height)
            .position(x: size.width * 0.04, y: size.height / 2)
    }

    private func mapDecorations(in size: CGSize) -> some View {
        VStack {
            Spacer()
            HStack {
                // Compass rose
                Image(systemName: "location.north.fill")
                    .font(.system(size: 30))
                    .foregroundColor(Color(hex: "8B4513").opacity(0.6))
                    .rotationEffect(.degrees(-15))

                Spacer()

                // Scale indicator
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color(hex: "8B4513").opacity(0.6))
                        .frame(width: 60, height: 4)
                    Text("500 km")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(Color(hex: "8B4513").opacity(0.6))
                }
            }
            .padding(15)
        }
    }

    private var mapTitle: some View {
        VStack(spacing: 4) {
            Text("STRATEGIC MAP")
                .font(.system(size: 14, weight: .black))
                .tracking(3)

            Text("THE CONTINENT")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2)
        }
        .foregroundColor(Color(hex: "8B4513"))
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "D4C4A8"))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(hex: "8B4513"), lineWidth: 1)
        )
        .padding(.top, 10)
    }
}

// MARK: - Nation Shape

struct NationShape: View {
    let nation: NationMapData
    let size: CGSize
    let isSelected: Bool
    let accessLevel: AccessLevel
    @Environment(\.theme) var theme

    var body: some View {
        let rect = nationRect

        ZStack {
            // Nation territory
            RoundedRectangle(cornerRadius: nation.id == "unknown_east" ? 0 : 8)
                .fill(nation.relationshipType.color)
                .frame(width: rect.width, height: rect.height)
                .overlay(
                    RoundedRectangle(cornerRadius: nation.id == "unknown_east" ? 0 : 8)
                        .stroke(
                            isSelected ? theme.accentGold : nation.relationshipType.borderColor,
                            lineWidth: isSelected ? 3 : 1.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: isSelected ? 4 : 2)

            // Nation label
            if nation.id != "unknown_east" {
                VStack(spacing: 2) {
                    Text(nation.name)
                        .font(.system(size: fontSize, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1)

                    // Relationship indicator (if player has access)
                    if accessLevel.hasAccess(requiredLevel: 4, category: .diplomatic) {
                        relationshipIndicator
                    }
                }
            } else {
                // Unknown territory
                Text("?")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .position(x: size.width * nation.position.x, y: size.height * nation.position.y)
    }

    private var nationRect: CGRect {
        CGRect(
            x: 0,
            y: 0,
            width: size.width * nation.size.width,
            height: size.height * nation.size.height
        )
    }

    private var fontSize: CGFloat {
        nation.isPlayable ? 12 : 8
    }

    @ViewBuilder
    private var relationshipIndicator: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 6, height: 6)

            Text(relationshipLabel)
                .font(.system(size: 7, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var indicatorColor: Color {
        switch nation.relationshipType {
        case .ally, .satellite: return .green
        case .neutral: return .gray
        case .hostile, .rival: return .red
        default: return .clear
        }
    }

    private var relationshipLabel: String {
        switch nation.relationshipType {
        case .ally: return "ALLY"
        case .satellite: return "SAT"
        case .neutral: return "NEU"
        case .hostile: return "HOS"
        case .rival: return "RIV"
        default: return ""
        }
    }
}

// MARK: - Map Legend

struct MapLegend: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 15) {
            LegendItem(color: Color(hex: "8B0000"), label: "Homeland")
            LegendItem(color: Color(hex: "CD5C5C"), label: "Allied")
            LegendItem(color: Color(hex: "808080"), label: "Neutral")
            LegendItem(color: Color(hex: "4169E1"), label: "Hostile")
            LegendItem(color: Color(hex: "FF8C00"), label: "Rival")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.parchmentDark.opacity(0.9))
        .cornerRadius(6)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundColor(theme.inkGray)
        }
    }
}

// MARK: - Nation Detail Sheet

struct NationDetailSheet: View {
    let nation: NationMapData
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(nation.relationshipType.color)
                                .frame(width: 16, height: 16)

                            Text(nation.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(theme.inkBlack)
                        }

                        Text(relationshipDescription)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkGray)
                    }

                    Divider()
                        .background(theme.borderTan)

                    // Basic info (always visible)
                    InfoSection(title: "STATUS") {
                        Text("Relationship: \(relationshipDescription)")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }

                    // Relationship details (Position 4+)
                    AccessGatedView(
                        requirement: .relationshipData,
                        accessLevel: accessLevel
                    ) {
                        InfoSection(title: "RELATIONSHIP DETAILS") {
                            Text("Detailed relationship metrics would appear here.")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }

                    // Intelligence (Position 6+)
                    AccessGatedView(
                        requirement: .intelligenceReports,
                        accessLevel: accessLevel
                    ) {
                        InfoSection(title: "INTELLIGENCE ASSESSMENT") {
                            Text("Classified intelligence assessment would appear here.")
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    }
                }
                .padding(20)
            }
            .background(theme.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(theme.sovietRed)
                }
            }
        }
    }

    private var relationshipDescription: String {
        switch nation.relationshipType {
        case .homeland: return "The Motherland"
        case .ally: return "Loyal Socialist Ally"
        case .satellite: return "Restless Satellite State"
        case .neutral: return "Neutral Trading Partner"
        case .hostile: return "Capitalist Adversary"
        case .rival: return "Socialist Rival"
        case .unknown: return "Unknown Territory"
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    let content: () -> Content
    @Environment(\.theme) var theme

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1)
                .foregroundColor(theme.inkGray)

            content()
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    WorldMapView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
