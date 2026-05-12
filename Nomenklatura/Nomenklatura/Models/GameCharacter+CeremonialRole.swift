//
//  GameCharacter+CeremonialRole.swift
//  Nomenklatura
//
//  Tiny extension that surfaces the `ceremonial_role_*` flag set by the
//  Co-opt Rival "Promote Sideways" path (see CharacterInteractionSystem
//  around line 2291). The flag means the character has been kicked
//  upstairs into a prestigious-sounding but toothless ceremonial role —
//  a "velvet coffin". Downstream services use this to reduce the
//  character's effective political power: Standing Committee vote weight,
//  RivalMoveGenerator candidate filter, SCProposalGenerator proposal
//  chance, PoliticalAIService action chance.
//
//  Kept in its own file because GameCharacter.swift has been touched by
//  several agents recently and we don't want to add yet another diff
//  there.
//

import Foundation

extension GameCharacter {
    /// True if this character has been promoted to a ceremonial role
    /// via the Co-opt Rival "Promote Sideways" path. Reduces their
    /// effective political power across vote weighting, proposal
    /// generation, and AI activity.
    ///
    /// The matching flag is set in `CharacterInteractionSystem` using
    /// the character's `id.uuidString` — so the check here must use
    /// the same encoding. Do NOT use `templateId` here; it's a separate
    /// stable identifier and the flag wasn't written against it.
    func hasCeremonialRole(in game: Game) -> Bool {
        game.flags.contains("ceremonial_role_\(id.uuidString)")
    }
}
