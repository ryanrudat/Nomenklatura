# Redesign Initiative — Remaining Phases

**Created:** 2026-04-17 (end of session 029)
**Initiative origin:** Session 029 6-agent audit (see `docs/changelog/2026-04-17_session-029.md`)
**Status:** Phase 0 + 1 + 2 + 3 ✅ COMPLETE. Phase 2.5 color migration ✅ COMPLETE (session 031, 2026-04-21) — only BureauColors helpers remain. Phase 4 + 5 remain.

This document captures the unfinished work from the redesign initiative so it can be resumed cleanly in a future session.

---

## Phase 4 — Politics Interactivity (NOT STARTED)

**Estimated effort:** 4-5 days across ~10 sub-batches
**Goal:** Player at Position 8 (Chairman) feels supremely powerful. Currently the politics layer is "passive observation" — Standing Committee voting happens at you, not by you. After Phase 4, Standing Committee members are individually addressable, bureau chiefs can be fired, factions can be negotiated/bribed/threatened, etc.

### Phase 4.1 — Standing Committee Per-Member Lobbying ⭐ HIGHEST PRIORITY
The audit's #1 political fix. Tap a Standing Committee member → see disposition + faction → choose Pressure / Bribe / Threaten / Promise. Success = member votes your way on the next agenda item.

**Files to touch:** `Views/Congress/StandingCommitteeView.swift` (around line 194-234, member display); new `LobbyMemberSheet.swift`; new `MemberLobbyService.swift` that adds vote modifiers to `StandingCommittee.swift:838-970` voting simulation.

**Mechanic:** Cost 1 AP + Network 30+ check. Lobbied member's next 1-2 votes shift +20-30 in player's favor.

### Phase 4.2 — Direct Bureau Chief Appointment/Removal
Currently can only influence bureau chiefs through Standing Committee agenda. After Phase 4.2, the Chairman can fire/appoint Security Chief, Economic Minister, Party Secretary directly (subject to faction support requirements).

**Files to touch:** New "Consolidate Power" personal actions for each of 3 bureaus. Tie to `StandingCommitteeService.fillVacancy()` and direct `character.positionIndex` updates.

**Gating:** Position 8, minStanding 65+, minNetwork 45+, minFactionSupport 40+ for the bureau's faction. Forced appointments (without faction support) trigger a faction backlash event.

### Phase 4.3 — Emergency Decree Power
Bypass Standing Committee for one law per turn during stability crises (`stability < 35` or "Emergency Powers" law passed). 3-turn window; SC can override if reaches supermajority opposition.

**Files to touch:** New action in Consolidate Power category. Check `game.stability < 40 OR game.flags["emergency_active"]`. Add `game.activeDecrees: [Decree]` array tracking unratified decrees.

**Gating:** Position 8, minStanding 70, minPowerConsolidation 60, minEliteLoyalty 30.

### Phase 4.4 — Faction Diplomatic Actions
Three actions per faction (5 factions × 3 actions = 15 total): Negotiate, Bribe, Threaten. Currently factions are tracked but not interactive.

**Mechanic per action:**
- **Negotiate**: trade support for policy concessions ("get youth league to vote for law X" in exchange for "youth league policy win Y")
- **Bribe**: spend 5-10 treasury → +5-10 faction standing
- **Threaten**: purge 1 faction member (-3 elite loyalty, +faction fear modifier that affects votes for 5 turns)

**Files to touch:** `GameFaction.swift`, new `FactionDiplomacyView.swift` accessible from Standing Committee Faction Balance card.

### Phase 4.5 — Personality Cult Intensity System
Slider with cascading propaganda unlocks (None / Modest / Intense / Totalitarian). Affects show trial confession success rates, popular support per turn, elite loyalty cost, propaganda action availability.

**Files to touch:** Add `Game.personalityCultIntensity: Int` (0-3). New propaganda actions gated by intensity level. ShowTrialService confession logic reads cult intensity.

### Phase 4.6 — Public Address / Speech Action
Major dialogue with stat-gated outcomes. Hardliner speech (Ruthless 50+) → boost military loyalty + elite loyalty. Reformist speech (Competent 60+) → boost popular support + international standing. Failed speech → -morale.

**Files to touch:** New personal action category or Consolidate Power sub-action. Generate narrative event with outcome checks.

### Phase 4.7 — Regional Governor Appointments
Assign characters to govern specific regions. Governor reports to player; can be tasked with economic/security missions. Loss of governor's loyalty → regional instability.

**Files to touch:** `Region.appointedGovernorId: String?`. New character pool query "available governors". RegionDetailView gains "Appoint Governor" action.

**Gating:** Position 8, minNetwork 40+, minEliteLoyalty 40+. Cost 1 AP per appointment.

### Phase 4.8 — Military Command Reshuffle
Replace Marshal(s) and General(s). Forced replacement (without military loyalty 50+) risks coup attempt, desertion, or military resistance event.

**Files to touch:** New action in Consolidate Power. Reference `militaryLoyalty` stat. Generate crisis event if forced replacement fails.

### Phase 4.9 — Wartime Emergency Powers
External crisis triggers (military threat event, border conflict) OR `stability < 25` allows declaring wartime emergency. Bypasses Standing Committee voting for 5 turns. Unlocks war-only actions: conscription, requisition, propaganda blitz. Auto-expiry unless war continues.

**Files to touch:** `Game.flags["wartime_active"] = true`. New "Wartime" action set. UI emergency menu.

### Phase 4.10 — International Summit / State Visit
Host summit or conduct state visit. Boosts international standing; unlocks foreign faction intel (host) or trade/diplomacy bonuses (visit). Risk: scandal/humiliation abroad.

**Files to touch:** Tie to existing `internationalStanding` stat. Generate world news event. New diplomatic action with location/partner selection.

### Implementation Notes For Phase 4
- All these actions slot into the existing personal action / consolidate-power flow.
- Each adds a new SectorRecipe-style data model + a service method + UI.
- Reuse Phase 0's `ActionAvailability.evaluate(...)` helper for gating.
- Reuse Phase 3's `ActiveSheet?` modal pattern from ContentView for new sheets.
- Reuse Phase 2's `LockToast` for failed gating attempts.

---

## Phase 5 — Polish + Tutorial (NOT STARTED)

**Estimated effort:** 2-3 days
**Goal:** First-time players can pick up the game and understand it. Final cohesion check.

### Phase 5.1 — First-Turn Tutorial Flow
Currently `GamePreparationView` shows "Preparing your first day in office..." with a loading bar but no tutorial. Players land on Desk and have to figure out the loop themselves.

**Tutorial sequence (7-step guided overlay, dismissible):**
1. "You are General Secretary. Each turn, you make decisions, issue directives, and maneuver politically."
2. Highlight first scenario document: "Click to read."
3. After first option click: explain stat deltas
4. Show phase progression: "Standing Committee → Directives → Personal Action"
5. Walk through Directive Phase: "You have 2 points to allocate to bureaus."
6. Walk through Personal Action: "Spend AP on actions sorted by urgency."
7. Walk through end-turn: "End turn applies all your decisions."

**Files to touch:** New `TutorialOverlayView.swift`. Persistent flag `Game.hasCompletedTutorial`. Dismiss button on each step.

### Phase 5.2 — Contextual Tooltips
Add tap-to-explain tooltips for non-obvious mechanics: budget priority effects, directive point allocation rules, action point math, stat color thresholds, lock indicators on actions.

### Phase 5.3 — Final Visual Cohesion Pass
Walk every screen, confirm phase badge present (where applicable), confirm theme tokens used everywhere, confirm copy voice (no "advancement" / "climbing"). Catch anything that slipped past Phase 1's sweep.

**Chairman bypass audit** (locked-in pattern from late session 029): walk every clearance / access / lock check in views and services. Whenever the failure case is "player lacks permission to see X" or "player can't access Y," confirm there's a `position >= 8` short-circuit so the Chairman never trips the gate. Two were caught in session 029 (HistoricalSession redaction + AffinityGainCard bureau access); future feature work in Phase 4 will likely add more.

### Phase 5.4 — Performance Pass
Profile turn processing. Check for new O(n²) introductions from Phase 3-4. Verify LazyVStack still applied to long lists. Check Five-Year Plan completion logic for hot loops.

### Phase 5.5 — Accessibility Pass
Tap targets ≥ 44pt verification. Dynamic Type support check. Color contrast for status indicators (especially the new color-coded `PersistentStatBar`).

### Phase 5.6 — Final Bug Sweep
Anything caught during Phase 1-4 that wasn't surface-level. Including:
- Loop tester: cold-launch a new game, play 10 turns, no broken flows
- 27 `try! ModelContainer` cleanup (preview-only paths from Phase 0 deferral)
- Replay variation regression test: play 3 fresh games for 5 turns each, verify newspapers/briefings/Codex don't repeat verbatim

---

## Phase 2.5 Color Call-Site Migration — ✅ COMPLETE (session 031)

**Status as of 2026-04-21:** `FiftiesColors` + `StitchColors` call-site migration is DONE. Build has zero deprecation warnings.

### What landed (session 031)
- ~420 `FiftiesColors.X` / `StitchColors.X` references rewritten across 30 files.
- Rule applied per call site: `theme.X` if the enclosing struct declares `@Environment(\.theme)`, otherwise `ColdWarTheme.shared.X`. In `#Preview` blocks: always `ColdWarTheme.shared.X`.
- Renames applied where the wrapper aliased to a differently-named property:
  - `FiftiesColors.stampRed` → `.sovietRed` (NOT `.stampRed`)
  - `FiftiesColors.brassGold` → `.bronzeGold`
  - `FiftiesColors.deniedRed` → `.stampRedDark`
  - `FiftiesColors.typewriterInk` → `.inkBlack`
  - `FiftiesColors.fadedInk` → `.inkGray`
  - `StitchColors.paper` / `.paperWarm` / `.paperDark` → `.parchment` / `.parchmentDark` / `.paperGray`
  - `StitchColors.gold` → `.accentGold`

### Still to do (NOT done in session 031)
- **`BureauColors` migration target doesn't exist yet.** Its deprecation message reads "Use ColdWarTheme.shared bureau helpers (coming in a later sub-batch)" but no `ColdWarTheme.bureauPrimary(for:)` / `.bureauAccent(for:)` / `.bureauBackground(for:)` helpers have been added. ~10 call sites remain.
- **Dead wrapper cleanup.** `struct FiftiesColors` in `FiftiesStyleComponents.swift` and `enum StitchColors` in `StitchDesignComponents.swift` are now unused. A future session can delete them after a final grep confirms no indirect references.

### Phase 2.5 completion checklist
1. [x] Migrate every `FiftiesColors.X` call site — done session 031
2. [x] Migrate every `StitchColors.X` call site — done session 031
3. [x] Confirm deprecation warnings drop to zero — done (was ~200, now 0)
4. [ ] Add bureau helpers to `CampaignTheme` protocol + `ColdWarTheme` struct (`bureauPrimary(for:)`, `bureauAccent(for:)`, `bureauBackground(for:)`)
5. [ ] Migrate ~10 `BureauColors.X` call sites using the new helpers
6. [ ] Delete `struct FiftiesColors` + `enum StitchColors` wrapper types
7. [ ] Delete `struct BureauColors` wrapper (or keep and mark with final deprecated message)

---

## Phase 3 Tuning (Post-Playtest)

After playtesting Phase 3, the recipe numbers and region endowments will need balance adjustments. Capturing initial guesses for reference:

### Likely Tuning Targets
- **Region endowments may be too generous**: industrial=6 coal+4 iron etc. might oversupply early game. Reduce by 25-30% if economy feels too easy.
- **Recipe input ratios**: heavy industry consumes 8 iron per 6 steel. Iron mining produces 8 per turn. Margin is 0 — first crisis event drops region status and steel chain breaks immediately. May want 1.5-2x buffer.
- **Tech era unlock pacing**: 1 Stakhanovite (4/4 targets) for atomic era might be too slow OR too fast depending on default plan target difficulty. Watch for either "atomic never reached" or "atomic by turn 20" extremes.
- **Emergency decree availability thresholds**: grain ≤ 5 might be too generous (always available). Tighten to ≤ 0 or ≤ 2.
- **Cross-system feedback magnitudes**: stat changes are small (-1 to -2 per issue) but compound across multiple deficits. Watch for "popularSupport tanks 8 points in a single turn" cascade scenarios.

### Files To Touch For Tuning
- `Models/SectorRecipe.swift` — recipe input/output values
- `Models/StrategicResource.swift` — `minimumTechEra` per resource
- `Models/TechEra.swift` — `era(forCompletedPlans:stakhanovitePlans:)` thresholds
- `Models/Region.swift` — `RegionType.defaultEndowments`
- `Models/EmergencyDecree.swift` — `isAvailable(in:)` thresholds + `treasuryCost`/`statEffects`/`resourceEffects`
- `Services/GameEngine.swift` — `applyStrategicResourceFeedback` magnitudes
