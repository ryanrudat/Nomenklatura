//
//  SeededRNG.swift
//  Nomenklatura
//
//  Deterministic RandomNumberGenerator backing the turn pipeline so player
//  bug reports become reproducible given the save's seed and tests can assert
//  exact stat outcomes rather than just "no exception thrown."
//
//  Implementation: SplitMix64 — a small, fast, statistically well-known PRNG
//  with simple seedable state (one UInt64). See:
//  https://prng.di.unimi.it/splitmix64.c
//
//  Use via `Game.rng` accessor:
//  ```
//  var rng = game.rng
//  let roll = Int.random(in: 1...100, using: &rng)
//  game.rng = rng  // persist mutated state back through `variables`
//  ```
//

import Foundation

/// Deterministic seedable RNG conforming to `RandomNumberGenerator`.
///
/// SplitMix64 has period 2^64 and passes standard PRNG quality tests.
/// State is a single UInt64 — easy to persist into `Game.variables` as a
/// decimal string so saves remain reproducible across launches.
struct SeededRNG: RandomNumberGenerator {
    /// Current internal state. Exposed read-only so callers can persist it.
    private(set) var currentState: UInt64

    init(seed: UInt64) {
        self.currentState = seed
    }

    mutating func next() -> UInt64 {
        currentState &+= 0x9E3779B97F4A7C15
        var z = currentState
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        return z ^ (z &>> 31)
    }
}
