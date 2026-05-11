//
//  Game+RivalMoves.swift
//  Nomenklatura
//
//  Extension-only file (NO stored properties) that exposes
//  `Game.activeRivalMoves` via the existing `variables: [String: String]`
//  dictionary. Lives in its own file so this commit does not contend
//  with parallel work on Game.swift's stored property layout.
//
//  Storage key: "active_rival_moves" — JSON-encoded [RivalMove].
//

import Foundation

extension Game {

    /// Storage key inside `variables` for the JSON-encoded active rival
    /// moves list. Kept private to this extension so callers go through
    /// the typed accessor below.
    private static var activeRivalMovesVariableKey: String { "active_rival_moves" }

    /// Active rival moves the player still needs to respond to. Stored
    /// JSON-encoded under variables["active_rival_moves"] so this file
    /// does not contend with parallel work on Game.swift's stored
    /// property layout.
    ///
    /// - Encoding failure on `set` is logged in DEBUG builds and the
    ///   value is silently dropped (better than crashing during a turn
    ///   transition).
    /// - Decoding failure on `get` is logged in DEBUG builds and returns
    ///   an empty array (the user sees no active moves rather than a crash).
    var activeRivalMoves: [RivalMove] {
        get {
            guard let raw = variables[Self.activeRivalMovesVariableKey],
                  let data = raw.data(using: .utf8) else { return [] }
            do {
                return try JSONDecoder().decode([RivalMove].self, from: data)
            } catch {
                #if DEBUG
                print("[Game] WARNING: failed to decode active_rival_moves: \(error)")
                #endif
                return []
            }
        }
        set {
            do {
                let data = try JSONEncoder().encode(newValue)
                variables[Self.activeRivalMovesVariableKey] = String(data: data, encoding: .utf8)
            } catch {
                #if DEBUG
                print("[Game] WARNING: failed to encode active_rival_moves: \(error)")
                #endif
            }
        }
    }
}
