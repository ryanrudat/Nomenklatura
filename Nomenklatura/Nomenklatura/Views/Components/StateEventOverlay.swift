//
//  StateEventOverlay.swift
//  Nomenklatura
//
//  Full-screen Constructivist treatment for dramatic state beats — coup
//  night, conspiracy resolutions, and any future moment that deserves more
//  than a journal line. Services stage one via game.pendingStateEvent
//  (JSON in variables, no schema change); GameView presents it at the root,
//  above every tab, and the player ACKNOWLEDGEs to dismiss.
//

import SwiftUI

struct StateEventPayload: Codable, Identifiable, Equatable {
    enum Accent: String, Codable {
        case red    // wounds, emergencies, the knock at the door
        case gold   // the Chairman prevails
    }

    var id: String
    var stampText: String     // EXECUTED / STATE OF EMERGENCY / CLASSIFIED
    var title: String
    var body: String
    var accent: Accent = .red
}

extension Game {
    /// Cheap existence check for per-body visibility conditions — avoids
    /// decoding the JSON payload on every root body evaluation. Decode via
    /// `pendingStateEvent` only where the overlay is actually constructed.
    var hasPendingStateEvent: Bool { variables["pending_state_event"] != nil }

    /// One pending dramatic overlay, staged by services during end-of-turn
    /// processing and consumed by GameView at the root of the tab stack.
    var pendingStateEvent: StateEventPayload? {
        get {
            guard let raw = variables["pending_state_event"],
                  let data = raw.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(StateEventPayload.self, from: data)
        }
        set {
            if let newValue,
               let data = try? JSONEncoder().encode(newValue),
               let raw = String(data: data, encoding: .utf8) {
                variables["pending_state_event"] = raw
            } else {
                variables["pending_state_event"] = nil
            }
        }
    }
}

struct StateEventOverlay: View {
    let payload: StateEventPayload
    let onAcknowledge: () -> Void
    @Environment(\.theme) var theme
    @State private var stampVisible = false
    @State private var bodyVisible = false

    private var accentColor: Color {
        payload.accent == .gold ? theme.accentGold : theme.sovietRed
    }

    var body: some View {
        ZStack {
            Color(hex: "141414").ignoresSafeArea()

            // Constructivist diagonal slab behind the stamp
            Rectangle()
                .fill(accentColor.opacity(0.20))
                .frame(height: 230)
                .rotationEffect(.degrees(-8))
                .offset(y: -190)
                .ignoresSafeArea()

            VStack(spacing: 26) {
                Spacer()

                // Rotated rubber stamp, slamming in
                Text(payload.stampText)
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .overlay(Rectangle().stroke(accentColor, lineWidth: 3))
                    .rotationEffect(.degrees(-7))
                    .scaleEffect(stampVisible ? 1.0 : 2.2)
                    .opacity(stampVisible ? 1 : 0)

                Text(payload.title)
                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(Color(hex: "F5F0E1"))
                    .multilineTextAlignment(.center)
                    .opacity(bodyVisible ? 1 : 0)

                Rectangle()
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 60, height: 2)
                    .opacity(bodyVisible ? 1 : 0)

                Text(payload.body)
                    .font(.custom("AmericanTypewriter", size: 14))
                    .foregroundColor(Color(hex: "F5F0E1").opacity(0.85))
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
                    .opacity(bodyVisible ? 1 : 0)

                Spacer()

                Button(action: onAcknowledge) {
                    Text("ACKNOWLEDGE")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(Color(hex: "141414"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Rectangle().fill(accentColor))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                // Generous clearance so the floating BottomNavBar can never cover it
                .padding(.bottom, 110)
                .opacity(bodyVisible ? 1 : 0)
            }
        }
        .classifiedWatermark(text: "STATE EVENT", opacity: 0.05)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { stampVisible = true }
            withAnimation(.easeIn(duration: 0.4).delay(0.45)) { bodyVisible = true }
        }
    }
}

#Preview {
    StateEventOverlay(
        payload: StateEventPayload(
            id: "preview",
            stampText: "STATE OF EMERGENCY",
            title: "THE 3 A.M. PLOT",
            body: "They moved at 3 a.m. and found every door already held against them. Three conspirators in custody by sunrise.",
            accent: .red
        ),
        onAcknowledge: {}
    )
    .environment(\.theme, ColdWarTheme())
}
