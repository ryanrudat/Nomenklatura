//
//  SpriteKitMapScene.swift
//  Nomenklatura
//
//  SpriteKit-based interactive world map with geographic rendering
//

import SpriteKit
import SwiftUI

// MARK: - Map Scene

class WorldMapScene: SKScene {

    // Callback for nation selection
    var onNationSelected: ((String) -> Void)?

    // Map data
    private var mapRegions: [MapRegion] = []
    private var regionNodes: [String: SKShapeNode] = [:]
    private var selectedNationId: String?

    // Camera for pan/zoom
    private var cameraNode: SKCameraNode!

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.11, green: 0.24, blue: 0.35, alpha: 1.0) // Dark navy ocean
        anchorPoint = CGPoint(x: 0, y: 0)

        loadMapData()
        setupBackground()
        setupGrid()
        setupOceans()
        setupNations()
        setupDecorations()
        setupCamera()

        isUserInteractionEnabled = true
    }

    // MARK: - Data Loading

    private func loadMapData() {
        mapRegions = AlternateWorldMap.loadRegions()
    }

    // MARK: - Setup Methods

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupBackground() {
        // Dark navy background (ocean base)
        let background = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.fillColor = SKColor(red: 0.11, green: 0.24, blue: 0.35, alpha: 1.0)
        background.strokeColor = .clear
        background.zPosition = -20
        addChild(background)
    }

    private func setupGrid() {
        let gridColor = SKColor(red: 0.3, green: 0.4, blue: 0.5, alpha: 0.15)

        // Latitude lines (every 15 degrees visual)
        for i in 0...12 {
            let y = CGFloat(i) * size.height / 12
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = i % 3 == 0 ? 1.0 : 0.5
            line.zPosition = -15
            addChild(line)
        }

        // Longitude lines
        for i in 0...18 {
            let x = CGFloat(i) * size.width / 18
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = i % 3 == 0 ? 1.0 : 0.5
            line.zPosition = -15
            addChild(line)
        }
    }

    private func setupOceans() {
        // Ocean regions are handled by background color
        // Add ocean labels
        for region in mapRegions where region.politicalAlignment == .ocean {
            let label = SKLabelNode(text: region.displayName)
            label.fontName = "Helvetica-Oblique"
            label.fontSize = 14
            label.fontColor = SKColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 0.6)
            label.position = CGPoint(
                x: region.centroid.x * size.width,
                y: (1 - region.centroid.y) * size.height
            )
            label.zPosition = -5
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            addChild(label)
        }
    }

    private func setupNations() {
        for region in mapRegions where region.politicalAlignment != .ocean {
            createNationNode(from: region)
        }
    }

    private func createNationNode(from region: MapRegion) {
        let path = createPath(from: region.polygons)

        // Main fill node
        let fillNode = SKShapeNode(path: path)
        fillNode.fillColor = fillColor(for: region.politicalAlignment)
        fillNode.strokeColor = .clear
        fillNode.zPosition = zPosition(for: region.politicalAlignment)
        fillNode.name = region.id
        addChild(fillNode)

        // Border node
        let borderNode = SKShapeNode(path: path)
        borderNode.fillColor = .clear
        borderNode.strokeColor = borderColor(for: region.politicalAlignment)
        borderNode.lineWidth = region.politicalAlignment == .homeland ? 3.0 : 1.5
        borderNode.zPosition = zPosition(for: region.politicalAlignment) + 0.5
        borderNode.name = "\(region.id)_border"
        addChild(borderNode)

        regionNodes[region.id] = borderNode

        // Special gold glow for PSRA
        if region.politicalAlignment == .homeland {
            let glowNode = SKShapeNode(path: path)
            glowNode.fillColor = .clear
            glowNode.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 0.4)
            glowNode.lineWidth = 6.0
            glowNode.zPosition = zPosition(for: region.politicalAlignment) - 0.1
            addChild(glowNode)
        }

        // Shadow
        let shadowPath = createPath(from: region.polygons, offset: CGPoint(x: 3, y: -3))
        let shadowNode = SKShapeNode(path: shadowPath)
        shadowNode.fillColor = SKColor.black.withAlphaComponent(0.2)
        shadowNode.strokeColor = .clear
        shadowNode.zPosition = zPosition(for: region.politicalAlignment) - 0.5
        addChild(shadowNode)

        // Label
        addNationLabel(for: region)
    }

    private func createPath(from polygons: [MapPolygon], offset: CGPoint = .zero) -> CGPath {
        let path = CGMutablePath()

        for polygon in polygons {
            guard let first = polygon.points.first else { continue }

            // Convert normalized coordinates to scene coordinates
            let startPoint = CGPoint(
                x: first.x * size.width + offset.x,
                y: (1 - first.y) * size.height + offset.y  // Flip Y for SpriteKit
            )
            path.move(to: startPoint)

            for point in polygon.points.dropFirst() {
                let scenePoint = CGPoint(
                    x: point.x * size.width + offset.x,
                    y: (1 - point.y) * size.height + offset.y
                )
                path.addLine(to: scenePoint)
            }
            path.closeSubpath()
        }

        return path
    }

    private func addNationLabel(for region: MapRegion) {
        // Skip labels for ocean/unclaimed
        guard region.politicalAlignment != .ocean && region.politicalAlignment != .unclaimed else { return }

        let position = CGPoint(
            x: region.centroid.x * size.width,
            y: (1 - region.centroid.y) * size.height
        )

        // Label shadow
        let shadowLabel = SKLabelNode(text: region.displayName)
        shadowLabel.fontName = "Helvetica-Bold"
        shadowLabel.fontSize = region.politicalAlignment == .homeland ? 14 : 10
        shadowLabel.fontColor = SKColor.black.withAlphaComponent(0.6)
        shadowLabel.position = CGPoint(x: position.x + 1, y: position.y - 1)
        shadowLabel.zPosition = 8
        shadowLabel.verticalAlignmentMode = .center
        shadowLabel.horizontalAlignmentMode = .center
        addChild(shadowLabel)

        // Main label
        let label = SKLabelNode(text: region.displayName)
        label.fontName = "Helvetica-Bold"
        label.fontSize = region.politicalAlignment == .homeland ? 14 : 10
        label.fontColor = .white
        label.position = position
        label.zPosition = 9
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        addChild(label)

        // Add occupation indicator if applicable
        if region.isOccupied {
            let occupiedLabel = SKLabelNode(text: "(Occupied)")
            occupiedLabel.fontName = "Helvetica-Oblique"
            occupiedLabel.fontSize = 7
            occupiedLabel.fontColor = SKColor.white.withAlphaComponent(0.7)
            occupiedLabel.position = CGPoint(x: position.x, y: position.y - 12)
            occupiedLabel.zPosition = 9
            occupiedLabel.verticalAlignmentMode = .center
            occupiedLabel.horizontalAlignmentMode = .center
            addChild(occupiedLabel)
        }
    }

    // MARK: - Colors

    private func fillColor(for alignment: MapRegion.PoliticalAlignment) -> SKColor {
        switch alignment {
        case .homeland:
            return SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)  // Deep red
        case .socialistAlly:
            return SKColor(red: 0.80, green: 0.36, blue: 0.36, alpha: 1.0)  // Indian red
        case .capitalist:
            return SKColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1.0)  // Royal blue
        case .fascist:
            return SKColor(red: 0.36, green: 0.23, blue: 0.10, alpha: 1.0)  // Brown
        case .pacificHostile:
            return SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)  // Saddle brown
        case .neutral:
            return SKColor(red: 0.41, green: 0.41, blue: 0.41, alpha: 1.0)  // Dim gray
        case .occupied:
            return SKColor(red: 0.50, green: 0.0, blue: 0.0, alpha: 0.8)  // Maroon
        case .ocean:
            return SKColor(red: 0.11, green: 0.24, blue: 0.35, alpha: 1.0)  // Navy
        case .unclaimed:
            return SKColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 1.0)  // Parchment
        }
    }

    private func borderColor(for alignment: MapRegion.PoliticalAlignment) -> SKColor {
        switch alignment {
        case .homeland:
            return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)  // Gold
        case .socialistAlly:
            return SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)  // Dark red
        case .capitalist:
            return SKColor(red: 0.0, green: 0.0, blue: 0.5, alpha: 1.0)  // Navy
        case .fascist:
            return SKColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0)  // Dark brown
        case .pacificHostile:
            return SKColor(red: 0.4, green: 0.2, blue: 0.0, alpha: 1.0)  // Dark brown
        case .neutral:
            return SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)  // Dark gray
        case .occupied:
            return SKColor(red: 0.4, green: 0.0, blue: 0.0, alpha: 1.0)  // Dark maroon
        case .ocean:
            return .clear
        case .unclaimed:
            return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.5)  // Light gray
        }
    }

    private func zPosition(for alignment: MapRegion.PoliticalAlignment) -> CGFloat {
        switch alignment {
        case .homeland: return 5
        case .socialistAlly: return 3
        case .capitalist: return 3
        case .fascist: return 3
        case .pacificHostile: return 3
        case .neutral: return 2
        case .occupied: return 4
        case .ocean: return -10
        case .unclaimed: return 1
        }
    }

    // MARK: - Decorations (Military Briefing Style)

    private func setupDecorations() {
        setupTitleCartouche()
        setupCompassRose()
        setupScaleBar()
        setupClassificationStamp()
        setupLegend()
    }

    private func setupTitleCartouche() {
        // Title background
        let cartouche = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 4)
        cartouche.position = CGPoint(x: size.width / 2, y: size.height - 35)
        cartouche.fillColor = SKColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 0.95)
        cartouche.strokeColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        cartouche.lineWidth = 2
        cartouche.zPosition = 20
        addChild(cartouche)

        // Title
        let title = SKLabelNode(text: "STRATEGIC WORLD MAP")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 14
        title.fontColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height - 28)
        title.zPosition = 21
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "PEOPLE'S SOCIALIST REPUBLIC OF AMERICA")
        subtitle.fontName = "Helvetica"
        subtitle.fontSize = 9
        subtitle.fontColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 45)
        subtitle.zPosition = 21
        addChild(subtitle)
    }

    private func setupCompassRose() {
        // Simple compass rose
        let compassBg = SKShapeNode(circleOfRadius: 25)
        compassBg.position = CGPoint(x: 40, y: 45)
        compassBg.fillColor = SKColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 0.9)
        compassBg.strokeColor = SKColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1.0)
        compassBg.lineWidth = 1.5
        compassBg.zPosition = 20
        addChild(compassBg)

        // N arrow
        let nPath = CGMutablePath()
        nPath.move(to: CGPoint(x: 40, y: 55))
        nPath.addLine(to: CGPoint(x: 35, y: 40))
        nPath.addLine(to: CGPoint(x: 40, y: 45))
        nPath.addLine(to: CGPoint(x: 45, y: 40))
        nPath.closeSubpath()

        let nArrow = SKShapeNode(path: nPath)
        nArrow.fillColor = SKColor(red: 0.72, green: 0.53, blue: 0.04, alpha: 1.0)
        nArrow.strokeColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        nArrow.lineWidth = 1
        nArrow.zPosition = 21
        addChild(nArrow)

        let nLabel = SKLabelNode(text: "N")
        nLabel.fontName = "Helvetica-Bold"
        nLabel.fontSize = 10
        nLabel.fontColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        nLabel.position = CGPoint(x: 40, y: 62)
        nLabel.zPosition = 21
        nLabel.verticalAlignmentMode = .center
        nLabel.horizontalAlignmentMode = .center
        addChild(nLabel)
    }

    private func setupScaleBar() {
        let scaleBar = SKShapeNode(rectOf: CGSize(width: 80, height: 6))
        scaleBar.position = CGPoint(x: size.width - 60, y: 25)
        scaleBar.fillColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 0.8)
        scaleBar.strokeColor = SKColor(red: 0.35, green: 0.17, blue: 0.0, alpha: 1.0)
        scaleBar.lineWidth = 1
        scaleBar.zPosition = 20
        addChild(scaleBar)

        // Scale divisions
        for i in 0...4 {
            let divider = SKShapeNode(rectOf: CGSize(width: 1, height: 8))
            divider.position = CGPoint(x: size.width - 100 + CGFloat(i) * 20, y: 25)
            divider.fillColor = SKColor(red: 0.2, green: 0.1, blue: 0.0, alpha: 1.0)
            divider.zPosition = 21
            addChild(divider)
        }

        let scaleLabel = SKLabelNode(text: "1000 km")
        scaleLabel.fontName = "Helvetica"
        scaleLabel.fontSize = 9
        scaleLabel.fontColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 1.0)
        scaleLabel.position = CGPoint(x: size.width - 60, y: 10)
        scaleLabel.zPosition = 20
        addChild(scaleLabel)
    }

    private func setupClassificationStamp() {
        // Classification stamp in corner
        let stampBg = SKShapeNode(rectOf: CGSize(width: 120, height: 20), cornerRadius: 2)
        stampBg.position = CGPoint(x: size.width - 70, y: size.height - 20)
        stampBg.fillColor = .clear
        stampBg.strokeColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 0.7)
        stampBg.lineWidth = 2
        stampBg.zPosition = 20
        addChild(stampBg)

        let stamp = SKLabelNode(text: "STRATEGIC COMMAND")
        stamp.fontName = "Helvetica-Bold"
        stamp.fontSize = 9
        stamp.fontColor = SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 0.7)
        stamp.position = CGPoint(x: size.width - 70, y: size.height - 23)
        stamp.zPosition = 21
        stamp.verticalAlignmentMode = .center
        stamp.horizontalAlignmentMode = .center
        addChild(stamp)

        // Date stamp
        let dateStamp = SKLabelNode(text: "YEAR XIV OF THE REVOLUTION")
        dateStamp.fontName = "Helvetica"
        dateStamp.fontSize = 8
        dateStamp.fontColor = SKColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.8)
        dateStamp.position = CGPoint(x: size.width - 90, y: size.height - 40)
        dateStamp.zPosition = 20
        addChild(dateStamp)
    }

    private func setupLegend() {
        // Legend background
        let legendBg = SKShapeNode(rectOf: CGSize(width: 100, height: 120), cornerRadius: 4)
        legendBg.position = CGPoint(x: 65, y: size.height - 100)
        legendBg.fillColor = SKColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 0.9)
        legendBg.strokeColor = SKColor(red: 0.72, green: 0.66, blue: 0.53, alpha: 1.0)
        legendBg.lineWidth = 1
        legendBg.zPosition = 20
        addChild(legendBg)

        let legendTitle = SKLabelNode(text: "POLITICAL BLOCS")
        legendTitle.fontName = "Helvetica-Bold"
        legendTitle.fontSize = 8
        legendTitle.fontColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        legendTitle.position = CGPoint(x: 65, y: size.height - 55)
        legendTitle.zPosition = 21
        addChild(legendTitle)

        // Legend items
        let items: [(String, SKColor)] = [
            ("PSRA", SKColor(red: 0.55, green: 0.0, blue: 0.0, alpha: 1.0)),
            ("Socialist Ally", SKColor(red: 0.80, green: 0.36, blue: 0.36, alpha: 1.0)),
            ("Capitalist", SKColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1.0)),
            ("Fascist", SKColor(red: 0.36, green: 0.23, blue: 0.10, alpha: 1.0)),
            ("Neutral", SKColor(red: 0.41, green: 0.41, blue: 0.41, alpha: 1.0)),
            ("Occupied", SKColor(red: 0.50, green: 0.0, blue: 0.0, alpha: 0.8))
        ]

        for (index, item) in items.enumerated() {
            let yPos = size.height - 70 - CGFloat(index) * 15

            // Color swatch
            let swatch = SKShapeNode(rectOf: CGSize(width: 12, height: 10))
            swatch.position = CGPoint(x: 30, y: yPos)
            swatch.fillColor = item.1
            swatch.strokeColor = SKColor.black.withAlphaComponent(0.3)
            swatch.lineWidth = 0.5
            swatch.zPosition = 21
            addChild(swatch)

            // Label
            let label = SKLabelNode(text: item.0)
            label.fontName = "Helvetica"
            label.fontSize = 8
            label.fontColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            label.position = CGPoint(x: 45, y: yPos - 3)
            label.zPosition = 21
            label.horizontalAlignmentMode = .left
            addChild(label)
        }
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
        // Find which region was tapped
        for region in mapRegions {
            guard region.politicalAlignment != .ocean else { continue }

            // Convert tap to normalized coordinates
            let normalizedX = location.x / size.width
            let normalizedY = 1 - (location.y / size.height)

            // Check if point is within region bounds (rough check)
            if region.bounds.contains(CGPoint(x: normalizedX, y: normalizedY)) {
                // More precise polygon check
                if isPoint(CGPoint(x: normalizedX, y: normalizedY), inPolygons: region.polygons) {
                    selectNation(id: region.id)
                    return
                }
            }
        }

        // Deselect if tapped elsewhere
        deselectCurrentNation()
    }

    private func isPoint(_ point: CGPoint, inPolygons polygons: [MapPolygon]) -> Bool {
        for polygon in polygons {
            if isPoint(point, inPolygon: polygon.points) {
                return !polygon.isHole
            }
        }
        return false
    }

    private func isPoint(_ point: CGPoint, inPolygon vertices: [CGPoint]) -> Bool {
        // Ray casting algorithm
        guard vertices.count >= 3 else { return false }

        var inside = false
        var j = vertices.count - 1

        for i in 0..<vertices.count {
            let vi = vertices[i]
            let vj = vertices[j]

            if ((vi.y > point.y) != (vj.y > point.y)) &&
               (point.x < (vj.x - vi.x) * (point.y - vi.y) / (vj.y - vi.y) + vi.x) {
                inside = !inside
            }
            j = i
        }

        return inside
    }

    private func selectNation(id: String) {
        // Deselect previous
        if let previousId = selectedNationId, let previousNode = regionNodes[previousId] {
            let region = mapRegions.first { $0.id == previousId }
            previousNode.strokeColor = borderColor(for: region?.politicalAlignment ?? .neutral)
            previousNode.lineWidth = previousId == "psra" ? 3.0 : 1.5
            previousNode.glowWidth = 0
        }

        // Select new
        selectedNationId = id
        if let node = regionNodes[id] {
            node.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1.0)
            node.lineWidth = 3.0
            node.glowWidth = 5.0

            // Animate selection
            let scaleUp = SKAction.scale(to: 1.02, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            node.run(SKAction.sequence([scaleUp, scaleDown]))

            // Notify callback
            onNationSelected?(id)
        }
    }

    private func deselectCurrentNation() {
        if let previousId = selectedNationId, let previousNode = regionNodes[previousId] {
            let region = mapRegions.first { $0.id == previousId }
            previousNode.strokeColor = borderColor(for: region?.politicalAlignment ?? .neutral)
            previousNode.lineWidth = previousId == "psra" ? 3.0 : 1.5
            previousNode.glowWidth = 0
        }
        selectedNationId = nil
    }

    // MARK: - Gestures

    func handlePinch(scale: CGFloat) {
        let newScale = max(0.5, min(2.5, cameraNode.xScale / scale))
        cameraNode.setScale(newScale)
    }

    func handlePan(translation: CGSize) {
        let newX = cameraNode.position.x - translation.width / cameraNode.xScale
        let newY = cameraNode.position.y + translation.height / cameraNode.yScale

        // Clamp to bounds
        let clampedX = max(size.width * 0.2, min(size.width * 0.8, newX))
        let clampedY = max(size.height * 0.2, min(size.height * 0.8, newY))

        cameraNode.position = CGPoint(x: clampedX, y: clampedY)
    }
}
