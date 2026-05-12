import Foundation

extension GameCharacter {
    /// Multiplier on success chance based on competence. 50 = 1.0 (neutral),
    /// 0 = 0.85x (clumsy), 100 = 1.15x (sharp). Linear interpolation. Caller
    /// should multiply this against their base success chance and clamp the
    /// result to [0.0, 1.0]. Returns 1.0 for nil edge cases so callers can
    /// safely default.
    var competenceSuccessModifier: Double {
        let centered = Double(personalityCompetent - 50)   // -50 ... +50
        return 1.0 + (centered * 0.003)                    // ±0.15 at edges
    }

    /// Multiplier on rival pending-effect damage. 50 = 1.0, 0 = 0.7x,
    /// 100 = 1.3x. Use as `magnitude * ruthlessDamageMultiplier`.
    var ruthlessDamageMultiplier: Double {
        let centered = Double(personalityRuthless - 50)    // -50 ... +50
        return 1.0 + (centered * 0.006)                    // ±0.30 at edges
    }

    /// Resistance multiplier on incoming pressure (interrogation,
    /// reconciliation, manipulation). 50 = 1.0 (normal resistance),
    /// 100 = 1.4x (hard to budge), 0 = 0.6x (easy to flip). Caller divides
    /// the base success chance by this to scale difficulty.
    var paranoidResistanceMultiplier: Double {
        let centered = Double(personalityParanoid - 50)
        return 1.0 + (centered * 0.008)                    // ±0.40 at edges
    }
}

/// Find the head of a bureau by track. Returns nil if no active character
/// is on that track. The "chief" is the highest-positioned active member.
/// Characters in ceremonial roles (co-opted via Promote Sideways) are
/// excluded — that path's whole point is to neutralize a rival's effective
/// power, and they shouldn't be applying their competence modifier to the
/// bureau's ops either.
func bureauChief(for track: String, in game: Game) -> GameCharacter? {
    return game.characters
        .filter {
            $0.currentStatus == .active
                && $0.positionTrack == track
                && !$0.hasCeremonialRole(in: game)
        }
        .max(by: { ($0.positionIndex ?? 0) < ($1.positionIndex ?? 0) })
}

extension GameCharacter {
    /// True if this character is currently locked in as a bound ally via
    /// the Co-opt Rival mechanic. Parses the `bound_ally_until_turn_<N>_target_<UUID>`
    /// flag and verifies the lock-in turn hasn't elapsed.
    ///
    /// Read by:
    ///   * `updateRelationshipStatus` — suppresses the disposition→rival auto-flip
    ///     so a co-opted character can't bounce back to .rival during lock-in.
    ///   * Future systems (vote favor, codex tone, faction politics) can read
    ///     this to give bound allies slightly favorable behavior.
    func isBoundAlly(in game: Game) -> Bool {
        let prefix = "bound_ally_until_turn_"
        let suffix = "_target_\(id.uuidString)"
        for flag in game.flags where flag.hasPrefix(prefix) && flag.hasSuffix(suffix) {
            let start = flag.index(flag.startIndex, offsetBy: prefix.count)
            if let end = flag.range(of: suffix)?.lowerBound,
               let turn = Int(flag[start..<end]),
               turn > game.turnNumber {
                return true
            }
        }
        return false
    }
}
