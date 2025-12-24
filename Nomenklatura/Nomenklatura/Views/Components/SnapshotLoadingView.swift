//
//  SnapshotLoadingView.swift
//  Nomenklatura
//
//  Loading screen with document on manila folder that slowly reveals
//

import SwiftUI
import Combine

// MARK: - Snapshot Loading View

struct SnapshotLoadingView: View {
    let turnNumber: Int
    let loadingMessage: String
    let onComplete: () -> Void

    @Environment(\.theme) var theme

    @State private var hasCompleted: Bool = false
    @State private var showContent: Bool = false
    @State private var dotCount: Int = 0
    @State private var currentImageIndex: Int = 0
    @State private var imageBrightness: Double = -0.4  // Start dark
    @State private var imageOpacity: Double = 1.0

    // Timer for animated dots
    let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    // Image names from Assets.xcassets
    private let imageNames: [String] = [
        "snapshot_1",
        "snapshot_2",
        "snapshot_3",
        "snapshot_4",
        "snapshot_5",
        "snapshot_6"
    ]

    // Duration for each image cycle (dark -> bright -> next)
    private let imageCycleDuration: Double = 6.0
    // How long the brightness animation takes
    private let brightenDuration: Double = 4.5

    // Minimum time before allowing completion
    private let minimumDisplayTime: Double = 5.0

    var body: some View {
        ZStack {
            // Desk/table surface underneath - warm wood tone
            LinearGradient(
                colors: [
                    Color(red: 0.32, green: 0.26, blue: 0.20),
                    Color(red: 0.25, green: 0.20, blue: 0.15)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle wood grain texture
            GeometryReader { geometry in
                Canvas { context, size in
                    for i in 0..<30 {
                        let y = CGFloat(i) * (size.height / 30) + CGFloat.random(in: -2...2)
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y + CGFloat.random(in: -5...5)))
                        context.stroke(path, with: .color(Color.black.opacity(Double.random(in: 0.03...0.08))), lineWidth: CGFloat.random(in: 0.5...1.5))
                    }
                }
            }
            .ignoresSafeArea()

            // Manila folder
            manilaFolder

            // Document on folder
            GeometryReader { geometry in
                let folderWidth = min(geometry.size.width - 32, 380)
                let folderHeight = folderWidth * 1.3

                VStack {
                    Spacer()
                        .frame(height: geometry.size.height * 0.10)

                    // Document laying on the folder
                    if !imageNames.isEmpty {
                        let imageName = imageNames[currentImageIndex % imageNames.count]

                        ZStack {
                            // Photo backing/border
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(white: 0.95))
                                .frame(width: folderWidth * 0.78 + 16, height: folderHeight * 0.55 + 20)
                                .shadow(color: .black.opacity(0.3), radius: 6, x: 2, y: 4)

                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: folderWidth * 0.78, height: folderHeight * 0.55)
                                .clipped()
                                .brightness(imageBrightness)
                                .contrast(1.05)
                                .saturation(0.8)
                                .opacity(imageOpacity)
                        }
                        .rotationEffect(.degrees(-1.2))
                        .offset(y: 15)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            // Loading info overlay at bottom
            VStack {
                Spacer()

                VStack(spacing: 14) {
                    // Turn indicator
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(theme.sovietRed.opacity(0.85), lineWidth: 2)
                            .frame(width: 130, height: 32)
                            .rotationEffect(.degrees(-1.5))

                        Text("TURN \(turnNumber)")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(theme.sovietRed)
                    }
                    .opacity(showContent ? 1 : 0)

                    // Loading message
                    Text(loadingMessage + String(repeating: ".", count: dotCount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(white: 0.6))
                        .frame(minWidth: 200)
                        .opacity(showContent ? 1 : 0)
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            startLoading()
            startImageCycle()
        }
        .onReceive(dotTimer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }

    // MARK: - Manila Folder

    private var manilaFolder: some View {
        GeometryReader { geometry in
            let folderWidth = min(geometry.size.width - 32, 380)
            let folderHeight = folderWidth * 1.3

            ZStack {
                // Back panel (slightly visible behind)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.82, green: 0.75, blue: 0.62))
                    .frame(width: folderWidth - 4, height: folderHeight + 8)
                    .offset(y: -6)

                // Main folder body
                ZStack {
                    // Base folder color with paper texture gradient
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.90, green: 0.83, blue: 0.68),
                                    Color(red: 0.87, green: 0.80, blue: 0.65),
                                    Color(red: 0.85, green: 0.78, blue: 0.62)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: folderWidth, height: folderHeight)

                    // Paper fiber texture
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.clear)
                        .frame(width: folderWidth, height: folderHeight)
                        .overlay(
                            Canvas { context, size in
                                // Horizontal paper fibers
                                for _ in 0..<100 {
                                    let x = CGFloat.random(in: 0...size.width)
                                    let y = CGFloat.random(in: 0...size.height)
                                    let length = CGFloat.random(in: 8...25)
                                    var path = Path()
                                    path.move(to: CGPoint(x: x, y: y))
                                    path.addLine(to: CGPoint(x: x + length, y: y + CGFloat.random(in: -1...1)))
                                    context.stroke(path, with: .color(Color(red: 0.75, green: 0.68, blue: 0.55).opacity(0.3)), lineWidth: 0.5)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        )

                    // Subtle fold line down the middle (file folder crease)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.05),
                                    Color.black.opacity(0.02),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 3, height: folderHeight * 0.9)

                    // Edge shadows for depth
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.clear,
                                    Color.black.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: folderWidth, height: folderHeight)

                    // Wear marks on edges
                    VStack {
                        Spacer()
                        HStack {
                            // Bottom left corner wear
                            Circle()
                                .fill(Color(red: 0.80, green: 0.73, blue: 0.58).opacity(0.6))
                                .frame(width: 20, height: 20)
                                .blur(radius: 8)
                                .offset(x: -5, y: 5)
                            Spacer()
                            // Bottom right corner wear
                            Circle()
                                .fill(Color(red: 0.80, green: 0.73, blue: 0.58).opacity(0.5))
                                .frame(width: 15, height: 15)
                                .blur(radius: 6)
                                .offset(x: 5, y: 5)
                        }
                    }
                    .frame(width: folderWidth, height: folderHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .frame(width: folderWidth, height: folderHeight)
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)

                // CLASSIFIED rubber stamp
                classifiedStamp
                    .offset(y: folderHeight * 0.35)

                // Tab at top
                folderTab(folderWidth: folderWidth, folderHeight: folderHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Folder Tab

    private func folderTab(folderWidth: CGFloat, folderHeight: CGFloat) -> some View {
        VStack {
            HStack {
                Spacer()

                // Tab shape - positioned to look like it's part of the back panel
                ZStack(alignment: .bottom) {
                    // Tab shadow
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 85, height: 22)
                    .offset(x: 2, y: 2)

                    // Tab background
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.85, green: 0.78, blue: 0.64),
                                Color(red: 0.80, green: 0.73, blue: 0.59)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 80, height: 20)

                    // Tab highlight
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 80, height: 20)
                }
                .offset(y: -folderHeight / 2 - 10)

                Spacer()
                    .frame(width: folderWidth * 0.18)
            }

            Spacer()
        }
        .frame(width: folderWidth, height: folderHeight)
    }

    // MARK: - Classified Stamp

    private var classifiedStamp: some View {
        let stampRed = Color(red: 0.72, green: 0.12, blue: 0.10)

        return ZStack {
            // Outer border with slight irregularity
            RoundedRectangle(cornerRadius: 2)
                .stroke(stampRed.opacity(0.85), lineWidth: 3)
                .frame(width: 200, height: 44)

            // Inner border
            RoundedRectangle(cornerRadius: 1)
                .stroke(stampRed.opacity(0.8), lineWidth: 1.5)
                .frame(width: 186, height: 34)

            // Main text
            Text("CLASSIFIED")
                .font(.system(size: 22, weight: .black, design: .serif))
                .tracking(2)
                .foregroundColor(stampRed.opacity(0.9))
        }
        .compositingGroup()
        .overlay(
            // Ink bleed/texture effect
            Canvas { context, size in
                for _ in 0..<25 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let w = CGFloat.random(in: 2...8)
                    let h = CGFloat.random(in: 1...4)

                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: w, height: h)),
                        with: .color(Color(red: 0.87, green: 0.80, blue: 0.65).opacity(0.5))
                    )
                }
            }
            .frame(width: 200, height: 44)
            .blendMode(.sourceAtop)
        )
        .rotationEffect(.degrees(-6))
    }

    // MARK: - Loading Animation

    private func startLoading() {
        // Show loading text
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }

        // Allow completion after minimum display time
        DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
            guard !hasCompleted else { return }
            hasCompleted = true
            onComplete()
        }
    }

    private func startImageCycle() {
        // Initial brighten animation for first image
        animateBrighten()

        // Schedule recurring image changes
        scheduleNextImageChange()
    }

    private func animateBrighten() {
        // Reset to dark
        imageBrightness = -0.4
        imageOpacity = 1.0

        // Slowly brighten
        withAnimation(.easeInOut(duration: brightenDuration)) {
            imageBrightness = 0.0
        }
    }

    private func scheduleNextImageChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + imageCycleDuration) {
            // Fade out current image
            withAnimation(.easeOut(duration: 0.4)) {
                imageOpacity = 0.0
            }

            // After fade out, change image and start new cycle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                currentImageIndex = (currentImageIndex + 1) % imageNames.count

                // Reset and brighten new image
                animateBrighten()

                // Schedule next change
                scheduleNextImageChange()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SnapshotLoadingView(
        turnNumber: 3,
        loadingMessage: "Preparing briefing"
    ) {
        print("Loading complete")
    }
    .environment(\.theme, ColdWarTheme())
}
