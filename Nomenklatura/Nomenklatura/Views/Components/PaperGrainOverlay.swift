//
//  PaperGrainOverlay.swift
//  Nomenklatura
//
//  Phase 2.6: subtle aged-paper texture modifier. Apply to any card
//  surface for the brutalist-bureaucratic-theater look. Uses a
//  procedural noise gradient so no asset import is needed; designers
//  can swap to a real grain image in a single place if desired.
//

import SwiftUI

struct PaperGrainModifier: ViewModifier {
    var intensity: Double = 0.08
    @Environment(\.theme) var theme

    func body(content: Content) -> some View {
        content.overlay(
            grainLayer
                .blendMode(.multiply)
                .allowsHitTesting(false)
        )
    }

    /// Subtle warm grain — overlapping radial gradients in slightly
    /// different ink tones produce a textured paper feel without an
    /// asset. Multiply blend keeps existing colors visible underneath.
    private var grainLayer: some View {
        ZStack {
            RadialGradient(
                colors: [theme.inkBlack.opacity(intensity), .clear],
                center: UnitPoint(x: 0.2, y: 0.3),
                startRadius: 0, endRadius: 200
            )
            RadialGradient(
                colors: [theme.leatherBrown.opacity(intensity * 0.5), .clear],
                center: UnitPoint(x: 0.8, y: 0.7),
                startRadius: 0, endRadius: 250
            )
            RadialGradient(
                colors: [theme.inkGray.opacity(intensity * 0.4), .clear],
                center: UnitPoint(x: 0.5, y: 0.5),
                startRadius: 0, endRadius: 300
            )
        }
    }
}

extension View {
    /// Add subtle aged-paper grain overlay. Default intensity reads
    /// at-a-glance as "this card is paper" without obscuring content.
    func paperGrain(intensity: Double = 0.08) -> some View {
        modifier(PaperGrainModifier(intensity: intensity))
    }
}
