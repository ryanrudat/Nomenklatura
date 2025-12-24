//
//  SpriteKitMapView.swift
//  Nomenklatura
//
//  SwiftUI wrapper for the SpriteKit-based world map
//

import SwiftUI
import SpriteKit
import SwiftData

struct SpriteKitMapView: View {
    @Bindable var game: Game
    @Environment(\.theme) var theme
    @State private var selectedNationId: String?
    @State private var showNationDetail = false
    @State private var scene: WorldMapScene?

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // SpriteKit Scene
                SpriteKitContainer(
                    size: geometry.size,
                    onNationSelected: { nationId in
                        selectedNationId = nationId
                        showNationDetail = true
                    }
                )
                .ignoresSafeArea()

                // Legend overlay
                VStack {
                    Spacer()
                    SpriteKitMapLegend()
                        .padding(.horizontal, 15)
                        .padding(.bottom, 10)
                }
            }
        }
        .sheet(isPresented: $showNationDetail) {
            if let nationId = selectedNationId {
                SpriteKitNationDetailSheet(
                    nationId: nationId,
                    game: game
                )
            }
        }
    }
}

// MARK: - SpriteKit Container

struct SpriteKitContainer: UIViewRepresentable {
    let size: CGSize
    let onNationSelected: (String) -> Void

    // Use a fixed scene size for consistent layout
    private let sceneSize = CGSize(width: 400, height: 700)

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.preferredFramesPerSecond = 60
        view.showsFPS = false
        view.showsNodeCount = false
        view.ignoresSiblingOrder = true
        view.backgroundColor = UIColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 1.0)

        // Create scene immediately with fixed size
        let scene = WorldMapScene(size: sceneSize)
        scene.scaleMode = .aspectFit
        scene.onNationSelected = onNationSelected
        context.coordinator.scene = scene
        view.presentScene(scene)

        // Add gesture recognizers
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        view.addGestureRecognizer(pinchGesture)

        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.minimumNumberOfTouches = 2
        view.addGestureRecognizer(panGesture)

        return view
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        // Scene is created in makeUIView with fixed size, no update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var scene: WorldMapScene?

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            if gesture.state == .changed {
                scene?.handlePinch(scale: gesture.scale)
                gesture.scale = 1.0
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .changed {
                let translation = gesture.translation(in: gesture.view)
                scene?.handlePan(translation: CGSize(width: translation.x, height: translation.y))
                gesture.setTranslation(.zero, in: gesture.view)
            }
        }
    }
}

// MARK: - Legend

struct SpriteKitMapLegend: View {
    @Environment(\.theme) var theme

    var body: some View {
        HStack(spacing: 15) {
            LegendDot(color: Color(hex: "8B0000"), label: "Homeland")
            LegendDot(color: Color(hex: "CD5C5C"), label: "Allied")
            LegendDot(color: Color(hex: "808080"), label: "Neutral")
            LegendDot(color: Color(hex: "4169E1"), label: "Hostile")
            LegendDot(color: Color(hex: "FF8C00"), label: "Rival")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(theme.parchmentDark.opacity(0.9))
        .cornerRadius(6)
    }
}

struct LegendDot: View {
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

struct SpriteKitNationDetailSheet: View {
    let nationId: String
    @Bindable var game: Game
    @Environment(\.dismiss) var dismiss
    @Environment(\.theme) var theme

    private var accessLevel: AccessLevel {
        AccessLevel(game: game)
    }

    private var nationInfo: NationInfo {
        NationInfo.forId(nationId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(nationInfo.color)
                                .frame(width: 16, height: 16)

                            Text(nationInfo.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(theme.inkBlack)
                        }

                        Text(nationInfo.relationshipDescription)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkGray)
                    }

                    Divider()
                        .background(theme.borderTan)

                    // Basic info
                    NationInfoSection(title: "STATUS") {
                        Text("Relationship: \(nationInfo.relationshipDescription)")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }

                    // Government type
                    NationInfoSection(title: "GOVERNMENT") {
                        Text(nationInfo.governmentType)
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkBlack)
                    }

                    // Detailed info (requires access)
                    if accessLevel.hasAccess(requiredLevel: 4, category: .diplomatic) {
                        NationInfoSection(title: "INTELLIGENCE ASSESSMENT") {
                            Text(nationInfo.intelligenceBrief)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.inkBlack)
                        }
                    } else {
                        NationInfoSection(title: "INTELLIGENCE") {
                            HStack {
                                Image(systemName: "lock.fill")
                                Text("Requires higher security clearance")
                            }
                            .font(theme.bodyFont)
                            .foregroundColor(theme.inkGray)
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
}

struct NationInfoSection<Content: View>: View {
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

// MARK: - Nation Info Data

struct NationInfo {
    let name: String
    let color: Color
    let relationshipDescription: String
    let governmentType: String
    let intelligenceBrief: String

    static func forId(_ id: String) -> NationInfo {
        switch id {
        case "psra":
            return NationInfo(
                name: "P.S.R.A.",
                color: Color(hex: "8B0000"),
                relationshipDescription: "The Homeland",
                governmentType: "People's Socialist Republic",
                intelligenceBrief: "The People's Socialist Republic of America leads the socialist world toward inevitable victory."
            )
        case "soviet_union":
            return NationInfo(
                name: "SOVIET UNION",
                color: Color(hex: "CD5C5C"),
                relationshipDescription: "Revolutionary Ally",
                governmentType: "Union of Soviet Socialist Republics",
                intelligenceBrief: "The USSR provided crucial aid during our Revolution and received part of Alaska in return. Relations are complicated by Moscow's expectations of ideological conformity."
            )
        case "germany":
            return NationInfo(
                name: "GERMANY",
                color: Color(hex: "CD5C5C"),
                relationshipDescription: "Socialist Ally",
                governmentType: "German Socialist Republic",
                intelligenceBrief: "In this timeline, the Nazis never rose to power. Social Democrats and Communists united, proving socialism need not mean Soviet domination."
            )
        case "cuba":
            return NationInfo(
                name: "CUBA",
                color: Color(hex: "8B0000"),
                relationshipDescription: "Government-in-Exile",
                governmentType: "Republic (Hosts US Federal Government)",
                intelligenceBrief: "The old Federal Government fled here after the Revolution. President-in-Exile claims to lead the 'legitimate' United States. Cuban intelligence operations threaten PSRA security."
            )
        case "canada":
            return NationInfo(
                name: "CANADA",
                color: Color(hex: "4169E1"),
                relationshipDescription: "Hostile Neighbor",
                governmentType: "Dominion (British Commonwealth)",
                intelligenceBrief: "Lost British Columbia and Alberta to the PSRA during the Intervention War. Canadian politics are consumed by revanchism—'the Lost Provinces' dominate every election."
            )
        case "united_kingdom":
            return NationInfo(
                name: "UNITED KINGDOM",
                color: Color(hex: "4169E1"),
                relationshipDescription: "Imperial Adversary",
                governmentType: "Constitutional Monarchy",
                intelligenceBrief: "Without World War II to drain their resources, Britain retains much of its colonial empire. They tried to crush the Revolution and failed."
            )
        case "france":
            return NationInfo(
                name: "FRANCE",
                color: Color(hex: "4169E1"),
                relationshipDescription: "Unstable Power",
                governmentType: "Republic (Volatile)",
                intelligenceBrief: "The most unpredictable power in Europe. French politics swing between left and right. A large Communist Party provides both opportunity and concern."
            )
        case "japan":
            return NationInfo(
                name: "JAPAN",
                color: Color(hex: "8B0000"),
                relationshipDescription: "Pacific Occupier",
                governmentType: "Empire",
                intelligenceBrief: "Seized Hawaii during the chaos of our civil war. The Empire controls Korea, Manchuria, parts of China, and American Hawaii. Liberating Hawaii is a national priority."
            )
        case "hawaii":
            return NationInfo(
                name: "HAWAII",
                color: Color(hex: "8B0000"),
                relationshipDescription: "Occupied Territory",
                governmentType: "Japanese Military Administration",
                intelligenceBrief: "American territory under Japanese occupation since 1941. Our citizens live under foreign rule. Liberation remains a core PSRA objective."
            )
        case "mexico":
            return NationInfo(
                name: "MEXICO",
                color: Color(hex: "808080"),
                relationshipDescription: "Neutral Neighbor",
                governmentType: "One-Party Republic",
                intelligenceBrief: "Neither socialist nor fully capitalist. Soviet weapons flowed through Mexican ports during the civil war. Keeping Mexico neutral is a strategic priority."
            )
        default:
            return NationInfo(
                name: "UNKNOWN",
                color: Color(hex: "2F4F4F"),
                relationshipDescription: "Unknown Territory",
                governmentType: "Unknown",
                intelligenceBrief: "Intelligence gathering ongoing."
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Game.self, configurations: config)
    let game = Game(campaignId: "cold_war")

    SpriteKitMapView(game: game)
        .modelContainer(container)
        .environment(\.theme, ColdWarTheme())
}
