//
//  SpriteKitMapScene.swift
//  Nomenklatura
//
//  SpriteKit-based interactive world map with custom nation shapes
//

import SpriteKit
import SwiftUI

// MARK: - Map Scene

class WorldMapScene: SKScene {

    // Callback for nation selection
    var onNationSelected: ((String) -> Void)?

    // Nation nodes for interaction
    private var nationNodes: [String: SKShapeNode] = [:]
    private var selectedNationId: String?

    // Camera for pan/zoom
    private var cameraNode: SKCameraNode!
    private var lastPanLocation: CGPoint?

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 1.0)
        anchorPoint = CGPoint(x: 0, y: 0)

        #if DEBUG
        // Debug: Print scene size
        print("Scene size: \(size)")
        #endif

        setupBackground()
        setupNations()
        setupDecorations()
        setupCamera()

        // Enable user interaction
        isUserInteractionEnabled = true
    }

    // MARK: - Setup

    private func setupCamera() {
        cameraNode = SKCameraNode()
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(cameraNode)
        camera = cameraNode
    }

    private func setupBackground() {
        // Aged parchment background
        let background = SKShapeNode(rectOf: CGSize(width: size.width * 2, height: size.height * 2))
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.fillColor = SKColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 1.0)
        background.strokeColor = .clear
        background.zPosition = -10
        addChild(background)

        // Grid lines
        addGridLines()

        // Ocean on the west
        let ocean = SKShapeNode(rectOf: CGSize(width: size.width * 0.12, height: size.height))
        ocean.position = CGPoint(x: size.width * 0.06, y: size.height / 2)
        ocean.fillColor = SKColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.3)
        ocean.strokeColor = .clear
        ocean.zPosition = -5
        addChild(ocean)
    }

    private func addGridLines() {
        let gridColor = SKColor(red: 0.72, green: 0.66, blue: 0.53, alpha: 0.3)

        // Horizontal lines
        for i in 0...10 {
            let y = CGFloat(i) * size.height / 10
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.zPosition = -8
            addChild(line)
        }

        // Vertical lines
        for i in 0...10 {
            let x = CGFloat(i) * size.width / 10
            let path = CGMutablePath()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))

            let line = SKShapeNode(path: path)
            line.strokeColor = gridColor
            line.lineWidth = 0.5
            line.zPosition = -8
            addChild(line)
        }
    }

    private func setupNations() {
        // PSRA - The homeland (center, largest)
        createNation(
            id: "psra",
            name: "P.S.R.A.",
            width: size.width * 0.28,
            height: size.height * 0.25,
            position: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
            fillColor: SKColor(red: 0.55, green: 0, blue: 0, alpha: 1.0),
            borderColor: SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1.0),
            isHomeland: true
        )

        // Canada - Hostile neighbor (north) - lost BC + Alberta
        createNation(
            id: "canada",
            name: "CANADA",
            width: size.width * 0.22,
            height: size.height * 0.12,
            position: CGPoint(x: size.width * 0.55, y: size.height * 0.78),
            fillColor: SKColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1.0),
            borderColor: SKColor(red: 0, green: 0, blue: 0.5, alpha: 1.0)
        )

        // Mexico - Neutral neighbor (south)
        createNation(
            id: "mexico",
            name: "MEXICO",
            width: size.width * 0.14,
            height: size.height * 0.09,
            position: CGPoint(x: size.width * 0.38, y: size.height * 0.25),
            fillColor: SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0),
            borderColor: SKColor(red: 0.41, green: 0.41, blue: 0.41, alpha: 1.0)
        )

        // Cuba - Government-in-Exile (southeast island)
        createNation(
            id: "cuba",
            name: "CUBA",
            width: size.width * 0.08,
            height: size.height * 0.04,
            position: CGPoint(x: size.width * 0.62, y: size.height * 0.22),
            fillColor: SKColor(red: 0.55, green: 0, blue: 0.27, alpha: 1.0),
            borderColor: SKColor(red: 0.4, green: 0, blue: 0.2, alpha: 1.0)
        )

        // Japan - Pacific occupier (far west, holds Hawaii)
        createNation(
            id: "japan",
            name: "JAPAN",
            width: size.width * 0.08,
            height: size.height * 0.12,
            position: CGPoint(x: size.width * 0.08, y: size.height * 0.55),
            fillColor: SKColor(red: 0.55, green: 0, blue: 0.27, alpha: 1.0),
            borderColor: SKColor(red: 0.4, green: 0, blue: 0.2, alpha: 1.0)
        )

        // Hawaii - Japanese occupied (Pacific)
        createNation(
            id: "hawaii",
            name: "HAWAII",
            width: size.width * 0.05,
            height: size.height * 0.03,
            position: CGPoint(x: size.width * 0.18, y: size.height * 0.38),
            fillColor: SKColor(red: 0.55, green: 0, blue: 0.27, alpha: 1.0),
            borderColor: SKColor(red: 0.4, green: 0, blue: 0.2, alpha: 1.0)
        )

        // Soviet Union - Socialist ally (far northeast)
        createNation(
            id: "soviet_union",
            name: "U.S.S.R.",
            width: size.width * 0.12,
            height: size.height * 0.15,
            position: CGPoint(x: size.width * 0.12, y: size.height * 0.78),
            fillColor: SKColor(red: 0.8, green: 0.36, blue: 0.36, alpha: 1.0),
            borderColor: SKColor(red: 0.55, green: 0, blue: 0, alpha: 1.0)
        )

        // United Kingdom - Imperial adversary (far east, across Atlantic)
        createNation(
            id: "united_kingdom",
            name: "U.K.",
            width: size.width * 0.06,
            height: size.height * 0.08,
            position: CGPoint(x: size.width * 0.88, y: size.height * 0.72),
            fillColor: SKColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1.0),
            borderColor: SKColor(red: 0, green: 0, blue: 0.5, alpha: 1.0)
        )

        // Germany - Socialist ally (east, Europe)
        createNation(
            id: "germany",
            name: "GERMANY",
            width: size.width * 0.08,
            height: size.height * 0.08,
            position: CGPoint(x: size.width * 0.88, y: size.height * 0.55),
            fillColor: SKColor(red: 0.8, green: 0.36, blue: 0.36, alpha: 1.0),
            borderColor: SKColor(red: 0.55, green: 0, blue: 0, alpha: 1.0)
        )

        // France - Unstable capitalist (east)
        createNation(
            id: "france",
            name: "FRANCE",
            width: size.width * 0.07,
            height: size.height * 0.07,
            position: CGPoint(x: size.width * 0.88, y: size.height * 0.40),
            fillColor: SKColor(red: 0.25, green: 0.41, blue: 0.88, alpha: 1.0),
            borderColor: SKColor(red: 0, green: 0, blue: 0.5, alpha: 1.0)
        )

        // Atlantic Ocean label area
        createNation(
            id: "atlantic",
            name: "ATLANTIC",
            width: size.width * 0.08,
            height: size.height * 0.20,
            position: CGPoint(x: size.width * 0.78, y: size.height * 0.55),
            fillColor: SKColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 0.3),
            borderColor: .clear,
            isUnknown: true
        )
    }

    private func createNation(
        id: String,
        name: String,
        width: CGFloat,
        height: CGFloat,
        position: CGPoint,
        fillColor: SKColor,
        borderColor: SKColor,
        isHomeland: Bool = false,
        isUnknown: Bool = false
    ) {
        let cornerRadius: CGFloat = isUnknown ? 0 : 12
        let nationSize = CGSize(width: width, height: height)

        // Use SKSpriteNode for the fill (more reliable than SKShapeNode fill)
        let nationFill = SKSpriteNode(color: fillColor, size: nationSize)
        nationFill.position = position
        nationFill.zPosition = isHomeland ? 2 : 1
        nationFill.name = id
        addChild(nationFill)

        // Add border using SKShapeNode
        let border = SKShapeNode(rectOf: nationSize, cornerRadius: cornerRadius)
        border.position = position
        border.fillColor = .clear
        border.strokeColor = borderColor
        border.lineWidth = isHomeland ? 3.0 : 2.0
        border.zPosition = isHomeland ? 2.5 : 1.5
        addChild(border)

        nationNodes[id] = border

        // Add shadow effect
        let shadow = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.25), size: nationSize)
        shadow.position = CGPoint(x: position.x + 4, y: position.y - 4)
        shadow.zPosition = 0
        addChild(shadow)

        #if DEBUG
        // Debug output
        print("Created nation \(id) at \(position) with size \(nationSize)")
        #endif

        // Add label
        let label = SKLabelNode(text: name)
        label.fontName = "Helvetica-Bold"
        label.fontSize = isHomeland ? 16 : (isUnknown ? 28 : 11)
        label.fontColor = .white
        label.position = position
        label.zPosition = 3
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center

        // Add shadow to label
        let labelShadow = SKLabelNode(text: name)
        labelShadow.fontName = "Helvetica-Bold"
        labelShadow.fontSize = isHomeland ? 16 : (isUnknown ? 28 : 11)
        labelShadow.fontColor = SKColor.black.withAlphaComponent(0.6)
        labelShadow.position = CGPoint(x: position.x + 1, y: position.y - 1)
        labelShadow.zPosition = 2.5
        labelShadow.verticalAlignmentMode = .center
        labelShadow.horizontalAlignmentMode = .center
        addChild(labelShadow)

        addChild(label)
    }

    // MARK: - Path Generation

    private func createPSRAPath() -> CGPath {
        let path = CGMutablePath()
        let w = size.width * 0.28
        let h = size.height * 0.32

        // Create an organic, roughly hexagonal shape for the homeland
        path.move(to: CGPoint(x: -w * 0.3, y: h * 0.45))
        path.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.5), control: CGPoint(x: -w * 0.1, y: h * 0.55))
        path.addQuadCurve(to: CGPoint(x: w * 0.45, y: h * 0.25), control: CGPoint(x: w * 0.35, y: h * 0.45))
        path.addQuadCurve(to: CGPoint(x: w * 0.4, y: -h * 0.15), control: CGPoint(x: w * 0.5, y: h * 0.05))
        path.addQuadCurve(to: CGPoint(x: w * 0.1, y: -h * 0.45), control: CGPoint(x: w * 0.3, y: -h * 0.35))
        path.addQuadCurve(to: CGPoint(x: -w * 0.25, y: -h * 0.4), control: CGPoint(x: -w * 0.1, y: -h * 0.5))
        path.addQuadCurve(to: CGPoint(x: -w * 0.45, y: -h * 0.1), control: CGPoint(x: -w * 0.4, y: -h * 0.3))
        path.addQuadCurve(to: CGPoint(x: -w * 0.35, y: h * 0.25), control: CGPoint(x: -w * 0.5, y: h * 0.1))
        path.addQuadCurve(to: CGPoint(x: -w * 0.3, y: h * 0.45), control: CGPoint(x: -w * 0.35, y: h * 0.4))
        path.closeSubpath()

        return path
    }

    private func createOrganicPath(width: CGFloat, height: CGFloat, seed: Int) -> CGPath {
        let path = CGMutablePath()
        let points = 8
        var vertices: [CGPoint] = []

        // Generate vertices around an ellipse with some randomness
        for i in 0..<points {
            let angle = (CGFloat(i) / CGFloat(points)) * 2 * .pi
            let radiusX = width / 2
            let radiusY = height / 2

            // Add some deterministic "randomness" based on seed
            let variation = 0.15 + 0.1 * sin(CGFloat(seed * 7 + i * 13))
            let adjustedRadiusX = radiusX * (1.0 - variation + variation * cos(CGFloat(seed + i)))
            let adjustedRadiusY = radiusY * (1.0 - variation + variation * sin(CGFloat(seed * 2 + i)))

            let x = cos(angle) * adjustedRadiusX
            let y = sin(angle) * adjustedRadiusY
            vertices.append(CGPoint(x: x, y: y))
        }

        // Create smooth path through vertices
        path.move(to: vertices[0])
        for i in 0..<points {
            let current = vertices[i]
            let next = vertices[(i + 1) % points]
            let controlX = (current.x + next.x) / 2
            let controlY = (current.y + next.y) / 2
            path.addQuadCurve(to: next, control: CGPoint(x: controlX * 1.1, y: controlY * 1.1))
        }
        path.closeSubpath()

        return path
    }

    private func createUnknownEastPath() -> CGPath {
        let path = CGMutablePath()
        let w = size.width * 0.15
        let h = size.height * 0.45

        // Jagged eastern edge suggesting unknown territory
        path.move(to: CGPoint(x: -w * 0.5, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.3, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.5, y: -h * 0.1))
        path.addLine(to: CGPoint(x: w * 0.3, y: -h * 0.25))
        path.addLine(to: CGPoint(x: w * 0.5, y: -h * 0.4))
        path.addLine(to: CGPoint(x: -w * 0.5, y: -h * 0.5))
        path.closeSubpath()

        return path
    }

    private func setupDecorations() {
        // Map title
        let titleBackground = SKShapeNode(rectOf: CGSize(width: 140, height: 40), cornerRadius: 4)
        titleBackground.position = CGPoint(x: size.width / 2, y: size.height - 30)
        titleBackground.fillColor = SKColor(red: 0.83, green: 0.77, blue: 0.66, alpha: 0.95)
        titleBackground.strokeColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        titleBackground.lineWidth = 1
        titleBackground.zPosition = 10
        addChild(titleBackground)

        let title = SKLabelNode(text: "STRATEGIC MAP")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 12
        title.fontColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        title.position = CGPoint(x: size.width / 2, y: size.height - 26)
        title.zPosition = 11
        addChild(title)

        let subtitle = SKLabelNode(text: "PEOPLE'S SOCIALIST REPUBLIC")
        subtitle.fontName = "Helvetica"
        subtitle.fontSize = 9
        subtitle.fontColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
        subtitle.position = CGPoint(x: size.width / 2, y: size.height - 40)
        subtitle.zPosition = 11
        addChild(subtitle)

        // Compass rose (simplified)
        let compass = SKLabelNode(text: "⬆︎ N")
        compass.fontName = "Helvetica-Bold"
        compass.fontSize = 16
        compass.fontColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 0.6)
        compass.position = CGPoint(x: 30, y: 30)
        compass.zPosition = 10
        addChild(compass)

        // Scale bar
        let scaleBar = SKShapeNode(rectOf: CGSize(width: 60, height: 4))
        scaleBar.position = CGPoint(x: size.width - 50, y: 25)
        scaleBar.fillColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 0.6)
        scaleBar.strokeColor = .clear
        scaleBar.zPosition = 10
        addChild(scaleBar)

        let scaleLabel = SKLabelNode(text: "500 km")
        scaleLabel.fontName = "Helvetica"
        scaleLabel.fontSize = 8
        scaleLabel.fontColor = SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 0.6)
        scaleLabel.position = CGPoint(x: size.width - 50, y: 12)
        scaleLabel.zPosition = 10
        addChild(scaleLabel)
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
        // Check if a nation was tapped
        for (id, node) in nationNodes {
            if id == "atlantic" { continue }  // Skip ocean areas

            // Check if tap is within the node's frame
            if node.frame.contains(location) {
                selectNation(id: id)
                return
            }
        }

        // Deselect if tapped elsewhere
        deselectCurrentNation()
    }

    private func selectNation(id: String) {
        // Deselect previous
        if let previousId = selectedNationId, let previousNode = nationNodes[previousId] {
            let originalColor = getOriginalBorderColor(for: previousId)
            previousNode.strokeColor = originalColor
            previousNode.lineWidth = previousId == "psra" ? 3.0 : 2.0

            // Remove glow
            previousNode.glowWidth = 0
        }

        // Select new
        selectedNationId = id
        if let node = nationNodes[id] {
            // Highlight effect
            node.strokeColor = SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1.0)
            node.lineWidth = 3.0
            node.glowWidth = 5.0

            // Animate selection
            let scaleUp = SKAction.scale(to: 1.05, duration: 0.1)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
            node.run(SKAction.sequence([scaleUp, scaleDown]))

            // Notify callback
            onNationSelected?(id)
        }
    }

    private func deselectCurrentNation() {
        if let previousId = selectedNationId, let previousNode = nationNodes[previousId] {
            let originalColor = getOriginalBorderColor(for: previousId)
            previousNode.strokeColor = originalColor
            previousNode.lineWidth = previousId == "psra" ? 3.0 : 2.0
            previousNode.glowWidth = 0
        }
        selectedNationId = nil
    }

    private func getOriginalBorderColor(for id: String) -> SKColor {
        switch id {
        case "psra": return SKColor(red: 1.0, green: 0.84, blue: 0, alpha: 1.0)
        case "soviet_union", "germany": return SKColor(red: 0.55, green: 0, blue: 0, alpha: 1.0)
        case "cuba", "japan", "hawaii": return SKColor(red: 0.4, green: 0, blue: 0.2, alpha: 1.0)
        case "canada", "united_kingdom", "france": return SKColor(red: 0, green: 0, blue: 0.5, alpha: 1.0)
        case "mexico": return SKColor(red: 0.41, green: 0.41, blue: 0.41, alpha: 1.0)
        default: return SKColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1.0)
        }
    }

    // MARK: - Pinch to Zoom

    func handlePinch(scale: CGFloat) {
        let newScale = max(0.5, min(2.5, cameraNode.xScale / scale))
        cameraNode.setScale(newScale)
    }

    func handlePan(translation: CGSize) {
        let newX = cameraNode.position.x - translation.width / cameraNode.xScale
        let newY = cameraNode.position.y + translation.height / cameraNode.yScale

        // Clamp to bounds
        let clampedX = max(size.width * 0.3, min(size.width * 0.7, newX))
        let clampedY = max(size.height * 0.3, min(size.height * 0.7, newY))

        cameraNode.position = CGPoint(x: clampedX, y: clampedY)
    }
}
