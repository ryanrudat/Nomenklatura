//
//  DeskView+DeskCards.swift
//  Nomenklatura
//
//  Document stack, loading section, newspaper card, scenario cards
//

import SwiftUI

extension DeskView {

    // MARK: - Document Stack Section

    @ViewBuilder
    func documentStackSection(documents: [DeskDocument]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Rectangle()
                    .fill(ColdWarTheme.shared.urgentRed)
                    .frame(width: 3, height: 14)

                Text("DOCUMENTS AWAITING ACTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(ColdWarTheme.shared.leatherBrown)

                Spacer()

                // Document count badge
                Text("\(documents.count)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(documents.contains { $0.urgencyEnum >= .urgent } ? ColdWarTheme.shared.urgentRed : ColdWarTheme.shared.leatherBrown)
                    )
            }

            // Document grid
            DocumentStackView(documents: documents) { document in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDocument = document
                    showDocumentDetail = true
                    document.markAsRead()
                }
            }
        }
        .padding(14)
        .background(
            ZStack {
                // Desk blotter area
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColdWarTheme.shared.leatherBrown.opacity(0.08))

                // Subtle border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(ColdWarTheme.shared.leatherBrown.opacity(0.15), lineWidth: 1)
            }
        )
    }

    // MARK: - Immersive Loading (1950s Dossier Style)

    @ViewBuilder
    var immersiveLoadingSection: some View {
        VStack(spacing: 0) {
            // Manila folder with cycling photographs
            ZStack {
                // Manila folder background
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColdWarTheme.shared.manillaFolder)
                    .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)

                // Paper texture overlay (using deterministic pattern to avoid re-rendering)
                Canvas { context, size in
                    var rng = SeededRandomNumberGenerator(seed: 12345)
                    for _ in 0..<60 {
                        let x = CGFloat.random(in: 0...size.width, using: &rng)
                        let y = CGFloat.random(in: 0...size.height, using: &rng)
                        let length = CGFloat.random(in: 8...25, using: &rng)
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + length, y: y))
                        context.stroke(path, with: .color(ColdWarTheme.shared.leatherBrown.opacity(0.1)), lineWidth: 0.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .drawingGroup() // Cache the rendered texture

                // Content: Photo + Info
                HStack(alignment: .top, spacing: 16) {
                    // Cycling photograph with dossier styling
                    ZStack(alignment: .topTrailing) {
                        // Photo stack shadow
                        Rectangle()
                            .fill(Color.black.opacity(0.15))
                            .frame(width: 105, height: 130)
                            .offset(x: 3, y: 4)

                        // Photo with photo corners
                        ZStack {
                            Rectangle()
                                .fill(Color(hex: "2A2A2A"))

                            Image(snapshotImages[currentSnapshotIndex])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 94, height: 119)
                                .clipped()
                                .grayscale(0.6)
                                .opacity(snapshotOpacity)
                        }
                        .frame(width: 100, height: 125)
                        .overlay {
                            // Photo corner mounts - as overlay to stay within bounds
                            ZStack {
                                // Top-left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 4, y: 4)

                                // Top-right
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 84, y: 4)

                                // Bottom-left
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 0))
                                    path.addLine(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 4, y: 109)

                                // Bottom-right
                                Path { path in
                                    path.move(to: CGPoint(x: 0, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 12))
                                    path.addLine(to: CGPoint(x: 12, y: 0))
                                }
                                .stroke(Color(hex: "4A4A4A"), lineWidth: 2)
                                .offset(x: 84, y: 109)
                            }
                        }
                        .rotationEffect(.degrees(-1.5))

                        // Paper clip - overlaps top-right corner of photo
                        Image(systemName: "paperclip")
                            .font(.system(size: 28, weight: .light))
                            .foregroundColor(Color(hex: "A0A0A0"))
                            .rotationEffect(.degrees(45))
                            .offset(x: 8, y: 0)
                    }

                    // Right side: Status + stamp
                    VStack(alignment: .leading, spacing: 10) {
                        // DOSSIER header - typewriter style
                        HStack(spacing: 6) {
                            Rectangle()
                                .fill(ColdWarTheme.shared.sovietRed)
                                .frame(width: 3, height: 12)

                            Text("DOSSIER")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .tracking(2)
                                .foregroundColor(ColdWarTheme.shared.leatherBrown)
                        }

                        // Loading status - typewriter style
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(ColdWarTheme.shared.leatherBrown)

                                Text(loadingState.loadingMessage.uppercased())
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .tracking(0.5)
                                    .foregroundColor(ColdWarTheme.shared.leatherBrown)
                                    .lineLimit(2)
                            }

                            if Secrets.isAIEnabled && loadingState.isLoading {
                                Text("AI-POWERED GENERATION")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundColor(ColdWarTheme.shared.inkGray)
                            }
                        }

                        Spacer()

                        // CLASSIFIED rubber stamp
                        RubberStamp(text: "CLASSIFIED", stampType: .classified, rotation: -5, size: .medium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(14)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: .infinity)
            .frame(height: 175)
            .onReceive(snapshotTimer) { _ in
                // Only cycle images when loading screen is actually visible
                guard isLoadingSectionVisible else { return }

                // Slow fade out
                withAnimation(.easeOut(duration: 1.2)) {
                    snapshotOpacity = 0.0
                }
                // Change image after fade out, then fade back in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    currentSnapshotIndex = (currentSnapshotIndex + 1) % snapshotImages.count
                    withAnimation(.easeIn(duration: 1.5)) {
                        snapshotOpacity = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Physical Newspaper Card (1950s Newsprint Style)

    @ViewBuilder
    func physicalNewspaperCard(newspaper: NewspaperEdition) -> some View {
        // Newspaper styled as physical folded paper on desk
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFullNewspaper = true
            }
        } label: {
            ZStack {
                // Paper shadow
                Rectangle()
                    .fill(Color.black.opacity(0.2))
                    .offset(x: 3, y: 4)

                // Newspaper paper
                VStack(alignment: .leading, spacing: 0) {
                    // Masthead - period newspaper style
                    HStack {
                        Text(newspaper.publicationName.uppercased())
                            .font(.system(size: 18, weight: .black, design: .serif))
                            .tracking(1)
                            .foregroundColor(ColdWarTheme.shared.inkBlack)

                        Spacer()

                        Text(formattedDate.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(ColdWarTheme.shared.inkGray)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)

                    // Decorative double line under masthead
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(ColdWarTheme.shared.inkBlack)
                            .frame(height: 2)
                        Rectangle()
                            .fill(ColdWarTheme.shared.inkBlack)
                            .frame(height: 0.5)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 6)

                    // Headline
                    Text(newspaper.headline.headline.uppercased())
                        .font(.system(size: 18, weight: .black, design: .serif))
                        .foregroundColor(ColdWarTheme.shared.inkBlack)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)

                    // Brief text
                    Text(String(newspaper.headline.body.prefix(100)) + "...")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                        .lineLimit(2)
                        .lineSpacing(2)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                        .padding(.bottom, 12)

                    // Fold line indicator
                    Rectangle()
                        .fill(ColdWarTheme.shared.inkBlack.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 6)

                    // Bottom padding
                    Spacer()
                        .frame(height: 8)
                }
                .background(
                    ZStack {
                        // Newsprint color - slightly yellowed
                        ColdWarTheme.shared.agedPaper

                        // Aged paper texture (using deterministic pattern to avoid re-rendering)
                        Canvas { context, size in
                            var rng = SeededRandomNumberGenerator(seed: 67890)
                            // Paper fibers
                            for _ in 0..<40 {
                                let x = CGFloat.random(in: 0...size.width, using: &rng)
                                let y = CGFloat.random(in: 0...size.height, using: &rng)
                                let length = CGFloat.random(in: 4...12, using: &rng)
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: y))
                                path.addLine(to: CGPoint(x: x + length, y: y))
                                context.stroke(path, with: .color(ColdWarTheme.shared.inkBlack.opacity(0.03)), lineWidth: 0.5)
                            }
                        }
                        .drawingGroup() // Cache the rendered texture

                        // Edge aging
                        LinearGradient(
                            colors: [ColdWarTheme.shared.leatherBrown.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    }
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(-0.8))
        }
        .buttonStyle(.plain)

        // Samizdat as hidden note tucked underneath
        if let samizdat = currentSamizdat {
            ZStack {
                // Shadow
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .offset(x: 2, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 9))
                        Text("SAMIZDAT")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(1.5)
                    }
                    .foregroundColor(ColdWarTheme.shared.inkGray)

                    Text(samizdat.headline.headline)
                        .font(.system(size: 11, weight: .semibold, design: .serif))
                        .foregroundColor(ColdWarTheme.shared.inkBlack)
                        .lineLimit(2)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    // Cheaper onionskin paper
                    Color(hex: "E8E4D8")
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(1.2))
            .offset(y: -8)
        }

        // Action buttons for newspaper
        HStack(spacing: 12) {
            // Read button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showFullNewspaper = true
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 12))
                    Text("READ")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(ColdWarTheme.shared.leatherBrown)
                )
            }
            .buttonStyle(.plain)

            // Skip/Put Aside button
            Button {
                continueFromNewspaper()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 12))
                    Text("PUT ASIDE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1)
                }
                .foregroundColor(ColdWarTheme.shared.leatherBrown)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(ColdWarTheme.shared.leatherBrown, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Physical Scenario Cards (1950s Official Memo Style)

    @ViewBuilder
    func physicalScenarioCards(scenario: Scenario) -> some View {
        // Briefing document styled as official memo on desk
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showFullScenario = true
            }
        } label: {
            ZStack {
                // Document shadow
                Rectangle()
                    .fill(Color.black.opacity(0.18))
                    .offset(x: 3, y: 4)

                // Main document
                VStack(alignment: .leading, spacing: 0) {
                    // Official header with red stripe
                    HStack(alignment: .top) {
                        Rectangle()
                            .fill(scenario.requiresDecision ? ColdWarTheme.shared.urgentRed : ColdWarTheme.shared.leatherBrown)
                            .frame(width: 4)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(scenario.requiresDecision ? "ACTION REQUIRED" : "FOR YOUR INFORMATION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                                .foregroundColor(scenario.requiresDecision ? ColdWarTheme.shared.urgentRed : ColdWarTheme.shared.leatherBrown)

                            Text(scenario.category.rawValue.uppercased())
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(ColdWarTheme.shared.inkGray)
                        }

                        Spacer()

                        // Rubber stamp
                        if scenario.requiresDecision {
                            RubberStamp(text: "URGENT", stampType: .urgent, rotation: -8, size: .small)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                    // Divider line - typewriter style
                    Text(String(repeating: "-", count: 50))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(ColdWarTheme.shared.inkGray.opacity(0.4))
                        .padding(.horizontal, 12)
                        .padding(.top, 6)

                    // Presenter info - memo format
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("FROM:")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(ColdWarTheme.shared.inkGray)
                                .frame(width: 40, alignment: .leading)

                            Text(scenario.presenterName.uppercased())
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(ColdWarTheme.shared.inkBlack)
                        }

                        if let title = scenario.presenterTitle {
                            HStack(spacing: 6) {
                                Text("")
                                    .frame(width: 40)
                                Text("(\(title))")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundColor(ColdWarTheme.shared.inkGray)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                    // Briefing content preview
                    Text(String(scenario.briefing.prefix(120)) + "...")
                        .font(.system(size: 11, design: .serif))
                        .foregroundColor(ColdWarTheme.shared.inkBlack)
                        .lineLimit(3)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    // Footer with action hint
                    HStack {
                        if scenario.requiresDecision {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                Text("\(scenario.options.count) OPTIONS REQUIRE DECISION")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                            }
                            .foregroundColor(ColdWarTheme.shared.urgentRed.opacity(0.8))
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("REVIEW")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                        }
                        .foregroundColor(ColdWarTheme.shared.inkGray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .background(
                    ZStack {
                        // Government memo paper
                        ColdWarTheme.shared.agedPaper

                        // Paper texture
                        Canvas { context, size in
                            var rng = SeededRandomNumberGenerator(seed: 11111)
                            for _ in 0..<25 {
                                let x = CGFloat.random(in: 0...size.width, using: &rng)
                                let y = CGFloat.random(in: 0...size.height, using: &rng)
                                let length = CGFloat.random(in: 3...10, using: &rng)
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: y))
                                path.addLine(to: CGPoint(x: x + length, y: y))
                                context.stroke(path, with: .color(ColdWarTheme.shared.inkBlack.opacity(0.02)), lineWidth: 0.5)
                            }
                        }
                        .drawingGroup()

                        // Coffee ring stain (subtle authenticity)
                        Circle()
                            .stroke(Color(hex: "8B6914").opacity(0.04), lineWidth: 2)
                            .frame(width: 35, height: 35)
                            .blur(radius: 1)
                            .offset(x: 90, y: -50)
                    }
                )
                .clipShape(Rectangle())
            }
            .rotationEffect(.degrees(0.5))
        }
        .buttonStyle(.plain)

        // Paper clip decoration (optional - suggests multiple pages)
        if scenario.requiresDecision && scenario.options.count > 2 {
            HStack {
                Spacer()
                Image(systemName: "paperclip")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "6A6A6A").opacity(0.6))
                    .rotationEffect(.degrees(25))
                    .offset(x: 25, y: -18)
            }
        }
    }
}
