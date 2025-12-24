//
//  ImmersiveComponents.swift
//  Nomenklatura
//
//  Immersive UI components: portraits, textures, animations, atmospheric details
//

import SwiftUI

// MARK: - Character Portrait System

/// Displays character portraits with fallback to generated initials
struct CharacterPortrait: View {
    let name: String
    let imageName: String?
    let size: CGFloat
    var borderColor: Color = Color(hex: "8B7355")
    var showFrame: Bool = true

    @Environment(\.theme) var theme

    var body: some View {
        ZStack {
            // Portrait frame background
            if showFrame {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "2C2418"))
                    .frame(width: size + 8, height: size + 8)

                RoundedRectangle(cornerRadius: 3)
                    .fill(borderColor.opacity(0.3))
                    .frame(width: size + 4, height: size + 4)
            }

            // Portrait content
            Group {
                if let imageName = imageName, UIImage(named: imageName) != nil {
                    // Use actual image if available
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback to stylized initials
                    InitialsPortrait(name: name, size: size)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            // Vintage photo overlay
            if showFrame {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.1),
                                Color.clear,
                                Color.black.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }
        }
    }
}

/// Stylized initials for characters without portraits
struct InitialsPortrait: View {
    let name: String
    let size: CGFloat

    private var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))"
        }
        return String(name.prefix(2)).uppercased()
    }

    private var backgroundColor: Color {
        // Generate consistent color from name
        let hash = abs(name.hashValue)
        let colors: [Color] = [
            Color(hex: "4A4A4A"), // Concrete gray
            Color(hex: "5D4E37"), // Brown
            Color(hex: "3D4F5F"), // Steel blue-gray
            Color(hex: "5C4033"), // Dark brown
            Color(hex: "4F4F4F"), // Charcoal
        ]
        return colors[hash % colors.count]
    }

    var body: some View {
        ZStack {
            // Background with subtle gradient
            LinearGradient(
                colors: [backgroundColor, backgroundColor.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Initials
            Text(initials)
                .font(.system(size: size * 0.4, weight: .bold, design: .serif))
                .foregroundColor(Color(hex: "D4D0C4"))

            // Subtle texture overlay
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            Color.black.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
}

// MARK: - Background Textures

/// Paper/parchment texture background
struct ParchmentBackground: View {
    var opacity: Double = 1.0
    var showWaterStain: Bool = false
    var showFoldLines: Bool = false

    var body: some View {
        ZStack {
            // Base parchment color
            Color(hex: "F4F1E8")

            // Paper grain texture (simulated with gradients)
            GeometryReader { geometry in
                // Horizontal grain lines
                ForEach(0..<Int(geometry.size.height / 3), id: \.self) { i in
                    Rectangle()
                        .fill(Color(hex: "E8E4D9").opacity(Double.random(in: 0.1...0.3)))
                        .frame(height: CGFloat.random(in: 0.5...1.5))
                        .offset(y: CGFloat(i) * 3)
                }
            }
            .opacity(0.5)

            // Edge darkening (vignette effect)
            RadialGradient(
                colors: [
                    Color.clear,
                    Color(hex: "D4D0C4").opacity(0.3)
                ],
                center: .center,
                startRadius: 100,
                endRadius: 400
            )

            // Optional water/coffee stain
            if showWaterStain {
                CoffeeStain()
                    .offset(x: 80, y: -120)
            }

            // Optional fold lines
            if showFoldLines {
                FoldLines()
            }
        }
        .opacity(opacity)
    }
}

/// Wooden desk texture background
struct DeskBackground: View {
    var body: some View {
        ZStack {
            // Base wood color
            Color(hex: "4A3728")

            // Wood grain pattern
            GeometryReader { geometry in
                ForEach(0..<20, id: \.self) { i in
                    WoodGrainLine()
                        .offset(y: CGFloat(i) * (geometry.size.height / 20))
                }
            }

            // Subtle sheen
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.white.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Edge shadow
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.black.opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 20)
                Spacer()
            }
        }
    }
}

/// Single wood grain line
struct WoodGrainLine: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))

                // Create wavy line
                var x: CGFloat = 0
                while x < geometry.size.width {
                    let y = geometry.size.height / 2 + CGFloat.random(in: -2...2)
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += CGFloat.random(in: 5...15)
                }
            }
            .stroke(
                Color(hex: "3D2A1E").opacity(Double.random(in: 0.2...0.5)),
                lineWidth: CGFloat.random(in: 0.5...2)
            )
        }
        .frame(height: 10)
    }
}

/// Brutalist concrete texture
struct ConcreteBackground: View {
    var body: some View {
        ZStack {
            // Base concrete color
            Color(hex: "6B6B6B")

            // Concrete texture noise (simulated)
            GeometryReader { geometry in
                ForEach(0..<50, id: \.self) { _ in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.02...0.08)))
                        .frame(width: CGFloat.random(in: 2...8))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }

                ForEach(0..<30, id: \.self) { _ in
                    Circle()
                        .fill(Color.black.opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 1...5))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }

            // Subtle gradient for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(0.05),
                    Color.clear,
                    Color.black.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Atmospheric Details

/// Coffee/tea stain effect
struct CoffeeStain: View {
    var size: CGFloat = 60
    var opacity: Double = 0.15

    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color(hex: "8B6914").opacity(opacity), lineWidth: 2)
                .frame(width: size, height: size)

            // Inner stain
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: "8B6914").opacity(opacity * 0.5),
                            Color(hex: "8B6914").opacity(opacity * 0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size * 0.8, height: size * 0.6)
                .offset(x: 5, y: 3)
        }
        .rotationEffect(.degrees(Double.random(in: -15...15)))
    }
}

/// Paper fold lines
struct FoldLines: View {
    var body: some View {
        GeometryReader { geometry in
            // Horizontal fold
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "C4C0B4").opacity(0.5),
                            Color(hex: "D8D4C8").opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

            // Vertical fold
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color(hex: "C4C0B4").opacity(0.4),
                            Color(hex: "D8D4C8").opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

/// Paper clip decoration
struct PaperClip: View {
    var rotation: Double = -15
    var color: Color = Color(hex: "A0A0A0")

    var body: some View {
        ZStack {
            // Paper clip shape
            RoundedRectangle(cornerRadius: 3)
                .stroke(color, lineWidth: 2)
                .frame(width: 12, height: 35)

            // Inner curve
            RoundedRectangle(cornerRadius: 2)
                .stroke(color, lineWidth: 2)
                .frame(width: 8, height: 25)
                .offset(y: -3)
        }
        .rotationEffect(.degrees(rotation))
        .shadow(color: Color.black.opacity(0.2), radius: 1, x: 1, y: 1)
    }
}

/// Red "stamp" overlay effect
struct StampOverlay: View {
    let text: String
    var rotation: Double = -12
    var color: Color = Color(hex: "8B0000")

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .black, design: .serif))
            .tracking(2)
            .foregroundColor(color.opacity(0.7))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .stroke(color.opacity(0.7), lineWidth: 2)
            )
            .rotationEffect(.degrees(rotation))
            // Stamp texture effect
            .overlay(
                GeometryReader { geo in
                    ForEach(0..<10, id: \.self) { _ in
                        Circle()
                            .fill(Color(hex: "F4F1E8"))
                            .frame(width: CGFloat.random(in: 1...3))
                            .position(
                                x: CGFloat.random(in: 0...geo.size.width),
                                y: CGFloat.random(in: 0...geo.size.height)
                            )
                    }
                }
            )
    }
}

/// Document aging effect overlay
struct AgingOverlay: View {
    var intensity: Double = 0.3

    var body: some View {
        ZStack {
            // Yellow aging tint
            Color(hex: "D4A574").opacity(intensity * 0.1)

            // Edge darkening
            GeometryReader { geometry in
                // Top edge
                LinearGradient(
                    colors: [Color(hex: "8B7355").opacity(intensity * 0.3), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)

                // Bottom edge
                LinearGradient(
                    colors: [Color.clear, Color(hex: "8B7355").opacity(intensity * 0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 20)
                .position(x: geometry.size.width / 2, y: geometry.size.height - 10)

                // Corner wear
                ForEach(0..<4, id: \.self) { corner in
                    Circle()
                        .fill(Color(hex: "C4B8A0").opacity(intensity * 0.4))
                        .frame(width: 40, height: 40)
                        .blur(radius: 15)
                        .position(cornerPosition(corner, in: geometry.size))
                }
            }

            // Random spots/foxing
            GeometryReader { geometry in
                ForEach(0..<Int(intensity * 20), id: \.self) { _ in
                    Circle()
                        .fill(Color(hex: "8B7355").opacity(Double.random(in: 0.05...0.15)))
                        .frame(width: CGFloat.random(in: 2...6))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func cornerPosition(_ corner: Int, in size: CGSize) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: 20, y: 20)
        case 1: return CGPoint(x: size.width - 20, y: 20)
        case 2: return CGPoint(x: 20, y: size.height - 20)
        default: return CGPoint(x: size.width - 20, y: size.height - 20)
        }
    }
}

// MARK: - Animated Transitions

/// Typewriter text reveal animation
struct TypewriterText: View {
    let fullText: String
    let speed: Double // characters per second

    @State private var displayedText = ""
    @State private var currentIndex = 0

    var body: some View {
        Text(displayedText)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        displayedText = ""
        currentIndex = 0

        Timer.scheduledTimer(withTimeInterval: 1.0 / speed, repeats: true) { timer in
            if currentIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
                displayedText += String(fullText[index])
                currentIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

/// Paper slide-in animation modifier
struct PaperSlideIn: ViewModifier {
    let isPresented: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: isPresented ? 0 : 50)
            .opacity(isPresented ? 1 : 0)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.8)
                .delay(delay),
                value: isPresented
            )
    }
}

/// Stamp slam animation
struct StampSlam: ViewModifier {
    let isStamped: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isStamped ? 1.0 : 2.0)
            .opacity(isStamped ? 1.0 : 0.0)
            .rotationEffect(.degrees(isStamped ? -12 : -30))
            .animation(
                .spring(response: 0.3, dampingFraction: 0.5),
                value: isStamped
            )
    }
}

/// Document shuffle animation
struct DocumentShuffle: ViewModifier {
    let index: Int
    let isShuffling: Bool

    func body(content: Content) -> some View {
        content
            .offset(
                x: isShuffling ? CGFloat.random(in: -20...20) : 0,
                y: isShuffling ? CGFloat(index) * -5 : 0
            )
            .rotationEffect(.degrees(isShuffling ? Double.random(in: -5...5) : 0))
            .animation(
                .spring(response: 0.4, dampingFraction: 0.6)
                .delay(Double(index) * 0.1),
                value: isShuffling
            )
    }
}

// MARK: - View Extensions

extension View {
    func paperSlideIn(isPresented: Bool, delay: Double = 0) -> some View {
        modifier(PaperSlideIn(isPresented: isPresented, delay: delay))
    }

    func stampSlam(isStamped: Bool) -> some View {
        modifier(StampSlam(isStamped: isStamped))
    }

    func documentShuffle(index: Int, isShuffling: Bool) -> some View {
        modifier(DocumentShuffle(index: index, isShuffling: isShuffling))
    }

    /// Adds a subtle paper shadow
    func paperShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.15), radius: 4, x: 2, y: 3)
    }

    /// Adds document aging effect
    func aged(intensity: Double = 0.3) -> some View {
        self.overlay(AgingOverlay(intensity: intensity))
    }
}

// MARK: - Player Silhouette Portrait

/// A mysterious black silhouette for the player character
struct PlayerSilhouette: View {
    var size: CGFloat = 80
    var showFrame: Bool = true

    var body: some View {
        ZStack {
            // Portrait frame background
            if showFrame {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "2C2418"))
                    .frame(width: size + 8, height: size + 8)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: "8B7355").opacity(0.3))
                    .frame(width: size + 4, height: size + 4)
            }

            // Silhouette content
            ZStack {
                // Dark background
                LinearGradient(
                    colors: [Color(hex: "1A1A1A"), Color(hex: "0D0D0D")],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Head silhouette (simplified bust shape)
                VStack(spacing: 0) {
                    // Head
                    Ellipse()
                        .fill(Color(hex: "0A0A0A"))
                        .frame(width: size * 0.45, height: size * 0.5)
                        .offset(y: size * 0.08)

                    // Shoulders
                    Ellipse()
                        .fill(Color(hex: "0A0A0A"))
                        .frame(width: size * 0.9, height: size * 0.5)
                        .offset(y: -size * 0.05)
                }

                // Subtle highlight on edge (like backlit silhouette)
                VStack(spacing: 0) {
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "333333"), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                        .frame(width: size * 0.45, height: size * 0.5)
                        .offset(y: size * 0.08)

                    Spacer()
                }
                .frame(height: size)

                // Mystery overlay - question mark or redacted effect
                Text("?")
                    .font(.system(size: size * 0.25, weight: .bold, design: .serif))
                    .foregroundColor(Color(hex: "333333"))
                    .offset(y: -size * 0.05)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 2))

            // Vintage photo overlay
            if showFrame {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.03),
                                Color.clear,
                                Color.black.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
            }
        }
    }
}

// MARK: - Preview

#Preview("Character Portraits") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            CharacterPortrait(name: "Director Wallace", imageName: nil, size: 60)
            CharacterPortrait(name: "Secretary Kennedy", imageName: nil, size: 60)
            CharacterPortrait(name: "General Anderson", imageName: nil, size: 60)
        }

        CharacterPortrait(name: "General Secretary", imageName: nil, size: 100)
    }
    .padding()
    .background(Color(hex: "F4F1E8"))
}

#Preview("Backgrounds") {
    TabView {
        ParchmentBackground(showWaterStain: true, showFoldLines: true)
            .tabItem { Text("Parchment") }

        DeskBackground()
            .tabItem { Text("Desk") }

        ConcreteBackground()
            .tabItem { Text("Concrete") }
    }
}

#Preview("Atmospheric Details") {
    ZStack {
        ParchmentBackground()

        VStack {
            HStack {
                PaperClip(rotation: -20)
                Spacer()
            }
            .padding()

            Spacer()

            StampOverlay(text: "CLASSIFIED")

            Spacer()

            CoffeeStain(size: 80)
        }
    }
}
