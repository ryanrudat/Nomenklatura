//
//  StampOverlay.swift
//  Nomenklatura
//
//  Phase 2.6: reusable rotated rubber-stamp overlay. Apply via the
//  view modifier `.stamp(.classified)` on any card or document to
//  add the bureaucratic stamp aesthetic — the Soviet flavor that
//  marks state actions as official.
//

import SwiftUI

enum StampKind {
    case classified
    case approved
    case rejected
    case pending
    case decreed
    case revoked

    var text: String {
        switch self {
        case .classified: return "CLASSIFIED"
        case .approved:   return "APPROVED"
        case .rejected:   return "REJECTED"
        case .pending:    return "PENDING"
        case .decreed:    return "DECREED"
        case .revoked:    return "REVOKED"
        }
    }

    var rotation: Double {
        switch self {
        case .classified: return -8
        case .approved:   return -5
        case .rejected:   return  6
        case .pending:    return -3
        case .decreed:    return -7
        case .revoked:    return  5
        }
    }
}

struct StampOverlayModifier: ViewModifier {
    let kind: StampKind
    let alignment: Alignment
    @Environment(\.theme) var theme

    func body(content: Content) -> some View {
        content.overlay(
            stampLabel.padding(20),
            alignment: alignment
        )
    }

    private var stampLabel: some View {
        Text(kind.text)
            .font(.system(size: 14, weight: .black, design: .default))
            .tracking(2.5)
            .foregroundColor(stampColor.opacity(0.85))
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .overlay(
                Rectangle()
                    .stroke(stampColor.opacity(0.85), lineWidth: 2.5)
            )
            .rotationEffect(.degrees(kind.rotation))
            .opacity(0.9)
    }

    private var stampColor: Color {
        switch kind {
        case .classified, .rejected, .revoked, .pending: return theme.sovietRed
        case .approved, .decreed:                        return theme.successGreen
        }
    }
}

extension View {
    /// Add a rotated bureaucratic stamp overlay to any view.
    /// Default alignment is .topTrailing for "this card is X" semantics.
    func stamp(_ kind: StampKind, alignment: Alignment = .topTrailing) -> some View {
        modifier(StampOverlayModifier(kind: kind, alignment: alignment))
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach([StampKind.classified, .approved, .rejected, .pending, .decreed, .revoked], id: \.text) { kind in
            VStack(alignment: .leading, spacing: 6) {
                Text("Document Card")
                    .font(.system(size: 14, weight: .bold))
                Text("Body content goes here. The stamp sits over the top-right corner by default.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(hex: "F5F0E1"))
            .stamp(kind)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .environment(\.theme, ColdWarTheme())
}
