//
//  SpriteKitMapScene.swift
//  Nomenklatura
//
//  Vintage-style world map with the PSR as an Atlantic island nation
//  Uses image-based rendering with invisible tap regions for interactivity
//

import SpriteKit
import SwiftUI

// MARK: - Vintage Map Scene

class WorldMapScene: SKScene {

    // Callback for nation selection
    var onNationSelected: ((String) -> Void)?

    // Map data - simplified tap regions
    private var tapRegions: [TapRegion] = []
    private var selectedRegionId: String?
    private var selectionIndicator: SKShapeNode?

    // Camera for pan/zoom
    private var cameraNode: SKCameraNode!

    // MARK: - Tap Region Definition

    struct TapRegion {
        let id: String
        let displayName: String
        let center: CGPoint      // Normalized 0-1 coordinates
        let radius: CGFloat      // Normalized radius for circular tap zone
        let alignment: MapRegion.PoliticalAlignment
        let labelOffset: CGPoint // Offset for label positioning
    }

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0, y: 0)

        setupTapRegions()
        setupVintageMapBackground()
        setupMapOverlays()
        setupDecorations()
        setupCamera()

        isUserInteractionEnabled = true
    }

    // MARK: - Tap Region Setup

    private func setupTapRegions() {
        // Define interactive tap regions for major nations
        // Coordinates are normalized (0-1) where (0,0) is bottom-left
        // Y is flipped for display: 0 = bottom of map, 1 = top

        tapRegions = [
            // PSR - Main Island (Atlantic, northwest of Azores)
            TapRegion(id: "psr", displayName: "PEOPLE'S SOCIALIST REPUBLIC",
                     center: CGPoint(x: 0.38, y: 0.62), radius: 0.045,
                     alignment: .homeland, labelOffset: .zero),

            // PSR Island Cluster
            TapRegion(id: "psr_krasny", displayName: "Krasny Island",
                     center: CGPoint(x: 0.42, y: 0.58), radius: 0.012,
                     alignment: .homeland, labelOffset: CGPoint(x: 0, y: -15)),
            TapRegion(id: "psr_svoboda", displayName: "Svoboda Island",
                     center: CGPoint(x: 0.43, y: 0.61), radius: 0.010,
                     alignment: .homeland, labelOffset: CGPoint(x: 0, y: -12)),
            TapRegion(id: "psr_trudovaya", displayName: "Trudovaya Island",
                     center: CGPoint(x: 0.44, y: 0.59), radius: 0.008,
                     alignment: .homeland, labelOffset: CGPoint(x: 0, y: -10)),
            TapRegion(id: "psr_dalny", displayName: "Dalny Island",
                     center: CGPoint(x: 0.45, y: 0.60), radius: 0.006,
                     alignment: .homeland, labelOffset: CGPoint(x: 0, y: -8)),

            // Socialist Allies
            TapRegion(id: "ussr", displayName: "SOVIET UNION",
                     center: CGPoint(x: 0.65, y: 0.72), radius: 0.08,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "china", displayName: "PEOPLE'S REPUBLIC OF CHINA",
                     center: CGPoint(x: 0.78, y: 0.58), radius: 0.06,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "poland", displayName: "POLAND",
                     center: CGPoint(x: 0.545, y: 0.67), radius: 0.018,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "czechoslovakia", displayName: "CZECHOSLOVAKIA",
                     center: CGPoint(x: 0.54, y: 0.64), radius: 0.015,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "hungary", displayName: "HUNGARY",
                     center: CGPoint(x: 0.545, y: 0.615), radius: 0.012,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "romania", displayName: "ROMANIA",
                     center: CGPoint(x: 0.565, y: 0.60), radius: 0.015,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "bulgaria", displayName: "BULGARIA",
                     center: CGPoint(x: 0.565, y: 0.575), radius: 0.012,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "east_germany", displayName: "EAST GERMANY",
                     center: CGPoint(x: 0.535, y: 0.675), radius: 0.012,
                     alignment: .socialistAlly, labelOffset: .zero),
            TapRegion(id: "north_korea", displayName: "NORTH KOREA",
                     center: CGPoint(x: 0.855, y: 0.60), radius: 0.012,
                     alignment: .socialistAlly, labelOffset: .zero),

            // Capitalist Powers
            TapRegion(id: "usa", displayName: "UNITED STATES",
                     center: CGPoint(x: 0.18, y: 0.58), radius: 0.06,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "uk", displayName: "UNITED KINGDOM",
                     center: CGPoint(x: 0.485, y: 0.69), radius: 0.015,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "france", displayName: "FRANCE",
                     center: CGPoint(x: 0.495, y: 0.625), radius: 0.02,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "west_germany", displayName: "WEST GERMANY",
                     center: CGPoint(x: 0.52, y: 0.66), radius: 0.015,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "italy", displayName: "ITALY",
                     center: CGPoint(x: 0.525, y: 0.58), radius: 0.018,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "japan", displayName: "JAPAN",
                     center: CGPoint(x: 0.875, y: 0.58), radius: 0.015,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "canada", displayName: "CANADA",
                     center: CGPoint(x: 0.18, y: 0.75), radius: 0.05,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "australia", displayName: "AUSTRALIA",
                     center: CGPoint(x: 0.85, y: 0.25), radius: 0.04,
                     alignment: .capitalist, labelOffset: .zero),
            TapRegion(id: "south_korea", displayName: "SOUTH KOREA",
                     center: CGPoint(x: 0.855, y: 0.575), radius: 0.010,
                     alignment: .capitalist, labelOffset: .zero),

            // Non-Aligned Nations
            TapRegion(id: "india", displayName: "INDIA",
                     center: CGPoint(x: 0.72, y: 0.48), radius: 0.035,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "egypt", displayName: "EGYPT",
                     center: CGPoint(x: 0.565, y: 0.50), radius: 0.02,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "indonesia", displayName: "INDONESIA",
                     center: CGPoint(x: 0.80, y: 0.36), radius: 0.03,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "yugoslavia", displayName: "YUGOSLAVIA",
                     center: CGPoint(x: 0.545, y: 0.59), radius: 0.015,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "brazil", displayName: "BRAZIL",
                     center: CGPoint(x: 0.28, y: 0.35), radius: 0.04,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "argentina", displayName: "ARGENTINA",
                     center: CGPoint(x: 0.24, y: 0.20), radius: 0.025,
                     alignment: .nonAligned, labelOffset: .zero),
            TapRegion(id: "mexico", displayName: "MEXICO",
                     center: CGPoint(x: 0.14, y: 0.48), radius: 0.025,
                     alignment: .nonAligned, labelOffset: .zero),

            // Neutral
            TapRegion(id: "switzerland", displayName: "SWITZERLAND",
                     center: CGPoint(x: 0.51, y: 0.635), radius: 0.008,
                     alignment: .neutral, labelOffset: .zero),
            TapRegion(id: "sweden", displayName: "SWEDEN",
                     center: CGPoint(x: 0.535, y: 0.75), radius: 0.015,
                     alignment: .neutral, labelOffset: .zero),
            TapRegion(id: "finland", displayName: "FINLAND",
                     center: CGPoint(x: 0.56, y: 0.78), radius: 0.015,
                     alignment: .neutral, labelOffset: .zero),
            TapRegion(id: "austria", displayName: "AUSTRIA",
                     center: CGPoint(x: 0.53, y: 0.63), radius: 0.010,
                     alignment: .neutral, labelOffset: .zero),
            TapRegion(id: "ireland", displayName: "IRELAND",
                     center: CGPoint(x: 0.465, y: 0.69), radius: 0.012,
                     alignment: .neutral, labelOffset: .zero)
        ]
    }

    // MARK: - Vintage Map Background

    private func setupVintageMapBackground() {
        // Try to load vintage map image asset
        // Check if the image exists in the bundle
        if let _ = UIImage(named: "vintage_world_map") {
            let mapTexture = SKTexture(imageNamed: "vintage_world_map")
            let mapSprite = SKSpriteNode(texture: mapTexture)
            mapSprite.size = size
            mapSprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
            mapSprite.zPosition = -10
            addChild(mapSprite)
        } else {
            // Fallback: Create procedural vintage-style map
            createProceduralVintageMap()
        }
    }

    private func createProceduralVintageMap() {
        // Aged parchment background
        let background = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.fillColor = SKColor(red: 0.93, green: 0.89, blue: 0.80, alpha: 1.0) // Aged paper
        background.strokeColor = .clear
        background.zPosition = -20
        addChild(background)

        // Vintage ocean color
        let ocean = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        ocean.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ocean.fillColor = SKColor(red: 0.75, green: 0.83, blue: 0.85, alpha: 1.0) // Muted teal
        ocean.strokeColor = .clear
        ocean.zPosition = -15
        addChild(ocean)

        // Add latitude/longitude grid (subtle)
        addVintageGrid()

        // Add stylized landmasses
        addStylizedLandmasses()

        // Add paper texture overlay (aged look)
        addAgedPaperEffect()
    }

    private func addVintageGrid() {
        let gridColor = SKColor(red: 0.6, green: 0.55, blue: 0.45, alpha: 0.2)

        // Major latitude lines
        for i in 1...5 {
            let y = CGFloat(i) * size.height / 6
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.zPosition = -12
            addChild(line)
        }

        // Major longitude lines
        for i in 1...8 {
            let x = CGFloat(i) * size.width / 9
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.zPosition = -12
            addChild(line)
        }
    }

    private func addStylizedLandmasses() {
        // Draw simplified landmass shapes in vintage style
        let landColor = SKColor(red: 0.88, green: 0.82, blue: 0.70, alpha: 1.0) // Beige land
        let borderColor = SKColor(red: 0.45, green: 0.38, blue: 0.28, alpha: 0.8) // Brown borders

        // North America (simplified oval)
        addLandmass(
            center: CGPoint(x: 0.18, y: 0.65),
            size: CGSize(width: 0.18, height: 0.25),
            landColor: landColor,
            borderColor: borderColor
        )

        // South America
        addLandmass(
            center: CGPoint(x: 0.25, y: 0.30),
            size: CGSize(width: 0.10, height: 0.22),
            landColor: landColor,
            borderColor: borderColor
        )

        // Europe
        addLandmass(
            center: CGPoint(x: 0.52, y: 0.68),
            size: CGSize(width: 0.10, height: 0.12),
            landColor: landColor,
            borderColor: borderColor
        )

        // Africa
        addLandmass(
            center: CGPoint(x: 0.54, y: 0.42),
            size: CGSize(width: 0.14, height: 0.22),
            landColor: landColor,
            borderColor: borderColor
        )

        // Asia (large)
        addLandmass(
            center: CGPoint(x: 0.72, y: 0.62),
            size: CGSize(width: 0.30, height: 0.28),
            landColor: landColor,
            borderColor: borderColor
        )

        // Australia
        addLandmass(
            center: CGPoint(x: 0.85, y: 0.28),
            size: CGSize(width: 0.10, height: 0.08),
            landColor: landColor,
            borderColor: borderColor
        )

        // PSR Main Island - Special treatment with red tint
        addPSRIsland(center: CGPoint(x: 0.38, y: 0.62), size: CGSize(width: 0.06, height: 0.08))

        // PSR Island Cluster
        addIslandCluster()
    }

    private func addLandmass(center: CGPoint, size landSize: CGSize, landColor: SKColor, borderColor: SKColor) {
        let sceneCenter = CGPoint(x: center.x * size.width, y: center.y * size.height)
        let sceneSize = CGSize(width: landSize.width * size.width, height: landSize.height * size.height)

        let path = CGMutablePath()
        path.addEllipse(in: CGRect(
            x: sceneCenter.x - sceneSize.width / 2,
            y: sceneCenter.y - sceneSize.height / 2,
            width: sceneSize.width,
            height: sceneSize.height
        ))

        let land = SKShapeNode(path: path)
        land.fillColor = landColor
        land.strokeColor = borderColor
        land.lineWidth = 1.5
        land.zPosition = -8
        addChild(land)
    }

    private func addPSRIsland(center: CGPoint, size islandSize: CGSize) {
        let sceneCenter = CGPoint(x: center.x * size.width, y: center.y * size.height)
        let sceneSize = CGSize(width: islandSize.width * size.width, height: islandSize.height * size.height)

        // Create irregular island shape (not a perfect ellipse)
        let path = CGMutablePath()
        let points = [
            CGPoint(x: sceneCenter.x - sceneSize.width * 0.4, y: sceneCenter.y + sceneSize.height * 0.3),
            CGPoint(x: sceneCenter.x - sceneSize.width * 0.2, y: sceneCenter.y + sceneSize.height * 0.45),
            CGPoint(x: sceneCenter.x + sceneSize.width * 0.1, y: sceneCenter.y + sceneSize.height * 0.4),
            CGPoint(x: sceneCenter.x + sceneSize.width * 0.4, y: sceneCenter.y + sceneSize.height * 0.2),
            CGPoint(x: sceneCenter.x + sceneSize.width * 0.45, y: sceneCenter.y - sceneSize.height * 0.1),
            CGPoint(x: sceneCenter.x + sceneSize.width * 0.3, y: sceneCenter.y - sceneSize.height * 0.4),
            CGPoint(x: sceneCenter.x - sceneSize.width * 0.1, y: sceneCenter.y - sceneSize.height * 0.45),
            CGPoint(x: sceneCenter.x - sceneSize.width * 0.4, y: sceneCenter.y - sceneSize.height * 0.2),
            CGPoint(x: sceneCenter.x - sceneSize.width * 0.45, y: sceneCenter.y + sceneSize.height * 0.1)
        ]

        path.move(to: points[0])
        for i in 1..<points.count {
            let control = CGPoint(
                x: (points[i - 1].x + points[i].x) / 2 + CGFloat.random(in: -5...5),
                y: (points[i - 1].y + points[i].y) / 2 + CGFloat.random(in: -5...5)
            )
            path.addQuadCurve(to: points[i], control: control)
        }
        path.closeSubpath()

        // PSR island with distinctive coloring
        let island = SKShapeNode(path: path)
        island.fillColor = SKColor(red: 0.75, green: 0.55, blue: 0.50, alpha: 1.0) // Reddish tint
        island.strokeColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0) // Dark red border
        island.lineWidth = 2.5
        island.zPosition = -5
        island.name = "psr_main"
        addChild(island)

        // Gold highlight glow
        let glow = SKShapeNode(path: path)
        glow.fillColor = .clear
        glow.strokeColor = SKColor(red: 0.85, green: 0.70, blue: 0.0, alpha: 0.5)
        glow.lineWidth = 5
        glow.zPosition = -6
        addChild(glow)

        // Label for PSR
        let label = createVintageLabel("P.S.R.", at: sceneCenter, fontSize: 12, isBold: true)
        label.fontColor = SKColor(red: 0.45, green: 0.0, blue: 0.0, alpha: 1.0)
        addChild(label)
    }

    private func addIslandCluster() {
        // Small islands east of main PSR island
        let clusterData: [(CGPoint, CGFloat, String)] = [
            (CGPoint(x: 0.42, y: 0.58), 0.012, "K"),  // Krasny
            (CGPoint(x: 0.43, y: 0.61), 0.010, "S"),  // Svoboda
            (CGPoint(x: 0.44, y: 0.59), 0.008, "T"),  // Trudovaya
            (CGPoint(x: 0.45, y: 0.60), 0.006, "D")   // Dalny
        ]

        for (center, radius, initial) in clusterData {
            let sceneCenter = CGPoint(x: center.x * size.width, y: center.y * size.height)
            let sceneRadius = radius * size.width

            let island = SKShapeNode(circleOfRadius: sceneRadius)
            island.position = sceneCenter
            island.fillColor = SKColor(red: 0.80, green: 0.60, blue: 0.55, alpha: 1.0)
            island.strokeColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 0.8)
            island.lineWidth = 1.5
            island.zPosition = -4
            addChild(island)

            // Tiny label
            let label = SKLabelNode(text: initial)
            label.fontName = "Times-Italic"
            label.fontSize = 8
            label.fontColor = SKColor(red: 0.4, green: 0.0, blue: 0.0, alpha: 1.0)
            label.position = CGPoint(x: sceneCenter.x, y: sceneCenter.y - sceneRadius - 8)
            label.zPosition = 5
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
    }

    private func addAgedPaperEffect() {
        // Subtle vignette effect
        let vignetteSize = CGSize(width: size.width * 1.2, height: size.height * 1.2)
        let vignette = SKShapeNode(rectOf: vignetteSize, cornerRadius: 50)
        vignette.position = CGPoint(x: size.width / 2, y: size.height / 2)
        vignette.fillColor = .clear
        vignette.strokeColor = SKColor(red: 0.3, green: 0.25, blue: 0.15, alpha: 0.15)
        vignette.lineWidth = 80
        vignette.zPosition = 15
        addChild(vignette)
    }

    // MARK: - Map Overlays (Political Colors)

    private func setupMapOverlays() {
        // Add political bloc indicators on tap regions
        for region in tapRegions {
            addPoliticalIndicator(for: region)
        }
    }

    private func addPoliticalIndicator(for region: TapRegion) {
        // Skip PSR islands (they're drawn specially)
        guard !region.id.hasPrefix("psr") else { return }

        let center = CGPoint(x: region.center.x * size.width, y: region.center.y * size.height)
        let indicatorSize: CGFloat = 8

        // Small colored dot for political alignment
        let indicator = SKShapeNode(circleOfRadius: indicatorSize)
        indicator.position = center
        indicator.fillColor = indicatorColor(for: region.alignment).withAlphaComponent(0.7)
        indicator.strokeColor = indicatorColor(for: region.alignment)
        indicator.lineWidth = 1.5
        indicator.zPosition = 3
        indicator.name = "indicator_\(region.id)"
        addChild(indicator)

        // Country label (small, vintage style)
        let labelText = abbreviateName(region.displayName)
        let label = createVintageLabel(labelText, at: CGPoint(x: center.x, y: center.y - 12), fontSize: 7, isBold: false)
        addChild(label)
    }

    private func indicatorColor(for alignment: MapRegion.PoliticalAlignment) -> SKColor {
        switch alignment {
        case .homeland:
            return SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)
        case .socialistAlly:
            return SKColor(red: 0.80, green: 0.25, blue: 0.25, alpha: 1.0)
        case .capitalist:
            return SKColor(red: 0.20, green: 0.35, blue: 0.70, alpha: 1.0)
        case .nonAligned:
            return SKColor(red: 0.20, green: 0.50, blue: 0.20, alpha: 1.0)
        case .neutral:
            return SKColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0)
        case .ocean, .unclaimed:
            return .clear
        }
    }

    private func abbreviateName(_ name: String) -> String {
        // Create short abbreviations for map labels
        let abbreviations: [String: String] = [
            "PEOPLE'S SOCIALIST REPUBLIC": "P.S.R.",
            "SOVIET UNION": "USSR",
            "PEOPLE'S REPUBLIC OF CHINA": "CHINA",
            "UNITED STATES": "U.S.A.",
            "UNITED KINGDOM": "U.K.",
            "WEST GERMANY": "W.GER.",
            "EAST GERMANY": "E.GER.",
            "NORTH KOREA": "N.KOR.",
            "SOUTH KOREA": "S.KOR.",
            "CZECHOSLOVAKIA": "CZECH.",
            "SWITZERLAND": "SWITZ.",
            "YUGOSLAVIA": "YUGO."
        ]
        return abbreviations[name] ?? name.prefix(6).uppercased() + "."
    }

    private func createVintageLabel(_ text: String, at position: CGPoint, fontSize: CGFloat, isBold: Bool) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = isBold ? "Times-Bold" : "Times-Roman"
        label.fontSize = fontSize
        label.fontColor = SKColor(red: 0.25, green: 0.20, blue: 0.15, alpha: 0.9)
        label.position = position
        label.zPosition = 6
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        return label
    }

    // MARK: - Decorations

    private func setupDecorations() {
        setupTitleCartouche()
        setupCompassRose()
        setupLegend()
        setupClassificationStamp()
    }

    private func setupTitleCartouche() {
        // Ornate title box
        let cartoucheWidth: CGFloat = 220
        let cartoucheHeight: CGFloat = 55
        let cartouche = SKShapeNode(rectOf: CGSize(width: cartoucheWidth, height: cartoucheHeight), cornerRadius: 6)
        cartouche.position = CGPoint(x: size.width / 2, y: size.height - 38)
        cartouche.fillColor = SKColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 0.95)
        cartouche.strokeColor = SKColor(red: 0.45, green: 0.35, blue: 0.20, alpha: 1.0)
        cartouche.lineWidth = 2
        cartouche.zPosition = 20
        addChild(cartouche)

        // Inner border
        let innerBorder = SKShapeNode(rectOf: CGSize(width: cartoucheWidth - 8, height: cartoucheHeight - 8), cornerRadius: 4)
        innerBorder.position = cartouche.position
        innerBorder.fillColor = .clear
        innerBorder.strokeColor = SKColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 0.6)
        innerBorder.lineWidth = 1
        innerBorder.zPosition = 20.5
        addChild(innerBorder)

        // Title
        let title = SKLabelNode(text: "WORLD STRATEGIC MAP")
        title.fontName = "Times-Bold"
        title.fontSize = 15
        title.fontColor = SKColor(red: 0.20, green: 0.15, blue: 0.10, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height - 30)
        title.zPosition = 21
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "People's Socialist Republic · Strategic Command")
        subtitle.fontName = "Times-Italic"
        subtitle.fontSize = 9
        subtitle.fontColor = SKColor(red: 0.40, green: 0.35, blue: 0.25, alpha: 1.0)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 48)
        subtitle.zPosition = 21
        addChild(subtitle)
    }

    private func setupCompassRose() {
        let compassCenter = CGPoint(x: 45, y: 50)

        // Compass background
        let compassBg = SKShapeNode(circleOfRadius: 28)
        compassBg.position = compassCenter
        compassBg.fillColor = SKColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 0.95)
        compassBg.strokeColor = SKColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 1.0)
        compassBg.lineWidth = 1.5
        compassBg.zPosition = 20
        addChild(compassBg)

        // Inner ring
        let innerRing = SKShapeNode(circleOfRadius: 22)
        innerRing.position = compassCenter
        innerRing.fillColor = .clear
        innerRing.strokeColor = SKColor(red: 0.65, green: 0.55, blue: 0.40, alpha: 0.8)
        innerRing.lineWidth = 1
        innerRing.zPosition = 20.5
        addChild(innerRing)

        // N/S/E/W markers
        let directions = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
        for (letter, angle) in directions {
            let radians = CGFloat(angle - 90) * .pi / 180
            let radius: CGFloat = 18
            let pos = CGPoint(
                x: compassCenter.x + cos(radians) * radius,
                y: compassCenter.y - sin(radians) * radius
            )

            let label = SKLabelNode(text: letter)
            label.fontName = letter == "N" ? "Times-Bold" : "Times-Roman"
            label.fontSize = letter == "N" ? 11 : 9
            label.fontColor = letter == "N" ?
                SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0) :
                SKColor(red: 0.35, green: 0.30, blue: 0.20, alpha: 1.0)
            label.position = pos
            label.zPosition = 21
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }

        // Center star point
        let star = SKShapeNode(circleOfRadius: 3)
        star.position = compassCenter
        star.fillColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)
        star.strokeColor = .clear
        star.zPosition = 21
        addChild(star)
    }

    private func setupLegend() {
        let legendX: CGFloat = 50
        let legendY: CGFloat = size.height - 90

        // Legend background
        let legendBg = SKShapeNode(rectOf: CGSize(width: 85, height: 95), cornerRadius: 4)
        legendBg.position = CGPoint(x: legendX, y: legendY - 35)
        legendBg.fillColor = SKColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 0.95)
        legendBg.strokeColor = SKColor(red: 0.55, green: 0.45, blue: 0.30, alpha: 1.0)
        legendBg.lineWidth = 1
        legendBg.zPosition = 20
        addChild(legendBg)

        // Legend title
        let title = SKLabelNode(text: "LEGEND")
        title.fontName = "Times-Bold"
        title.fontSize = 8
        title.fontColor = SKColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0)
        title.position = CGPoint(x: legendX, y: legendY + 5)
        title.zPosition = 21
        addChild(title)

        // Legend items
        let items: [(String, SKColor)] = [
            ("P.S.R.", SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)),
            ("Socialist", SKColor(red: 0.80, green: 0.25, blue: 0.25, alpha: 1.0)),
            ("Capitalist", SKColor(red: 0.20, green: 0.35, blue: 0.70, alpha: 1.0)),
            ("Non-Aligned", SKColor(red: 0.20, green: 0.50, blue: 0.20, alpha: 1.0)),
            ("Neutral", SKColor(red: 0.50, green: 0.50, blue: 0.50, alpha: 1.0))
        ]

        for (index, item) in items.enumerated() {
            let yPos = legendY - 12 - CGFloat(index) * 14

            // Color swatch
            let swatch = SKShapeNode(circleOfRadius: 5)
            swatch.position = CGPoint(x: legendX - 28, y: yPos)
            swatch.fillColor = item.1.withAlphaComponent(0.8)
            swatch.strokeColor = item.1
            swatch.lineWidth = 1
            swatch.zPosition = 21
            addChild(swatch)

            // Label
            let label = SKLabelNode(text: item.0)
            label.fontName = "Times-Roman"
            label.fontSize = 8
            label.fontColor = SKColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 1.0)
            label.position = CGPoint(x: legendX - 15, y: yPos - 3)
            label.zPosition = 21
            label.horizontalAlignmentMode = .left
            addChild(label)
        }
    }

    private func setupClassificationStamp() {
        // Red classification stamp
        let stamp = SKLabelNode(text: "CLASSIFIED · STRATEGIC COMMAND")
        stamp.fontName = "Helvetica-Bold"
        stamp.fontSize = 9
        stamp.fontColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 0.6)
        stamp.position = CGPoint(x: size.width - 100, y: size.height - 18)
        stamp.zPosition = 21
        stamp.zRotation = -0.08 // Slight angle for stamp effect
        addChild(stamp)

        // Border around stamp
        let stampBorder = SKShapeNode(rectOf: CGSize(width: 180, height: 16), cornerRadius: 2)
        stampBorder.position = CGPoint(x: size.width - 100, y: size.height - 18)
        stampBorder.fillColor = .clear
        stampBorder.strokeColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 0.4)
        stampBorder.lineWidth = 1.5
        stampBorder.zPosition = 20.5
        stampBorder.zRotation = -0.08
        addChild(stampBorder)
    }

    // MARK: - Camera

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleTap(at: location)
    }

    #if os(macOS)
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleTap(at: location)
    }
    #endif

    private func handleTap(at location: CGPoint) {
        // Convert to normalized coordinates
        let normalizedX = location.x / size.width
        let normalizedY = location.y / size.height

        // Find tapped region
        for region in tapRegions {
            let dx = normalizedX - region.center.x
            let dy = normalizedY - region.center.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance <= region.radius {
                selectRegion(region)
                return
            }
        }

        // Deselect if tapped elsewhere
        deselectCurrentRegion()
    }

    private func selectRegion(_ region: TapRegion) {
        // Deselect previous
        deselectCurrentRegion()

        selectedRegionId = region.id

        // Create selection indicator
        let center = CGPoint(x: region.center.x * size.width, y: region.center.y * size.height)
        let indicator = SKShapeNode(circleOfRadius: region.radius * size.width + 5)
        indicator.position = center
        indicator.fillColor = .clear
        indicator.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 0.9)
        indicator.lineWidth = 3
        indicator.glowWidth = 5
        indicator.zPosition = 10
        indicator.name = "selection_indicator"
        addChild(indicator)
        selectionIndicator = indicator

        // Pulse animation
        let scaleUp = SKAction.scale(to: 1.1, duration: 0.2)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        indicator.run(SKAction.repeatForever(SKAction.sequence([scaleUp, scaleDown])))

        // Notify callback
        onNationSelected?(region.id)
    }

    private func deselectCurrentRegion() {
        selectionIndicator?.removeFromParent()
        selectionIndicator = nil
        selectedRegionId = nil
    }

    // MARK: - Gestures

    func handlePinch(scale: CGFloat) {
        let newScale = max(0.5, min(2.5, cameraNode.xScale / scale))
        cameraNode.setScale(newScale)
    }

    func handlePan(translation: CGSize) {
        let newX = cameraNode.position.x - translation.width / cameraNode.xScale
        let newY = cameraNode.position.y + translation.height / cameraNode.yScale

        let clampedX = max(size.width * 0.2, min(size.width * 0.8, newX))
        let clampedY = max(size.height * 0.2, min(size.height * 0.8, newY))

        cameraNode.position = CGPoint(x: clampedX, y: clampedY)
    }
}
