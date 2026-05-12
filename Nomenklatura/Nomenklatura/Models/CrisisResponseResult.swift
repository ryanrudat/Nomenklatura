//
//  CrisisResponseResult.swift
//  Nomenklatura
//
//  Return value from CrisisResponseService.executeOption(_:in:). Carries
//  enough information for the Crisis Response Panel to render an outcome
//  card without having to reach back into Game state.
//

import Foundation

struct CrisisResponseResult {
    /// True if costs were paid AND the success roll passed. False covers
    /// both "ineligible" (no AP, no charge, stat threshold missed) and
    /// "rolled and failed" — the UI distinguishes via `narrative`.
    let success: Bool

    /// Which crisis this response addressed. Lets the panel know whether
    /// to dismiss the corresponding crisis card or keep it.
    let crisisType: CrisisType

    /// Stable option key, e.g. "crackdown", that ran.
    let optionId: String

    /// Outcome narrative — either `option.narrativeSuccess` or
    /// `option.narrativeFailure`. For ineligible attempts this is a short
    /// "shortage" explainer.
    let narrative: String

    /// Stat deltas applied. Mirrors the option's onSuccess / onFailure
    /// dict and is suitable for animating numeric pips in the UI.
    /// Empty for ineligible attempts.
    let statChanges: [String: Int]
}
