# Nomenklatura Active Context

Last updated: 2026-04-17
Workspace: `/Users/ryanrudat/Desktop/Nomenklatura/Nomenklatura/Nomenklatura`

## Purpose
This file is a living engineering context for the app. Read this first in future sessions to recover architecture, invariants, and current problem areas before patching.

## Active Initiative — Comprehensive Redesign (Session 029, 2026-04-17)

A 6-agent audit at the start of session 029 drove a 6-phase redesign initiative. After session 029:
- **Phase 0** ✅ Foundation (bugs, design tokens, AI replayability cache, prompt caching, ValidationResult unification, position+law gating, RedactableText component)
- **Phase 1** ✅ Chairman framing (~24 player-facing copy fixes + complete Achievement system overhaul with 35 tier-based achievements)
- **Phase 2** ✅ Visual cohesion structurally complete (phase badges, themed empty states, lock toasts, modal manager refactor, collapsible sections, 3 legacy color systems wrapped + 4 high-traffic files migrated, SovietIcon system, persistent stat bar, stamp + paper grain modifiers)
- **Phase 3** ✅ Deep economy (12 strategic resources, 5 tech eras, supply chain engine, sector detail UI, focus forecasting, tech era unlocks via plan completion, commodity-level trade, cross-system political feedback, emergency decrees)
- **Phase 4** Politics interactivity — NOT STARTED
- **Phase 5** Polish + tutorial — NOT STARTED

Full session record: `docs/changelog/2026-04-17_session-029.md`
Remaining work plan: `docs/plans/REDESIGN_REMAINING_PHASES.md`

### Two Non-Negotiable Design Rules (locked in session 029)
1. **The Chairman Sees Everything**: any "[REDACTED]" / "CLASSIFIED" UI must be tappable to reveal. Use `RedactableText` / `RedactableSection` components from `Views/Components/`.
2. **AI Generates Narrative, Code Owns Mechanics**: newspapers, briefings, NPC dialogue are AI-generated for replayability (scenarios already done in session 029); action names, stats, UI labels stay coded.

### Aesthetic Direction
**Brutalist Bureaucratic Theater** for daily UI + **Constructivist propaganda accents** for dramatic moments. Game-internal Soviet-flavored terms (Politburo, Five-Year Plan, Stakhanovite) are OK; real-world Soviet figure names (Stalin/Lenin/Brezhnev) are never used.

## App Snapshot
- Platform: SwiftUI + SwiftData iOS/macOS game app.
- Genre: Political strategy simulation with turn-based progression.
- Entry points:
  - `NomenklaturaApp.swift`: App bootstrap and `ModelContainer` creation.
  - `ContentView.swift`: Setup flow and live game shell.
- Core persisted model:
  - `Models/Game.swift`: large canonical state container for turn, stats, flags, systems, and encoded subsystem data.

## Runtime Flow
1. `NomenklaturaApp` configures SwiftData schema and loads `ContentView`.
2. `ContentView` state machine:
   - `campaignSelect -> factionSelect -> preparing -> playing`
3. `startNewGame(...)` initializes:
   - player/faction/stats/characters/factions
   - laws, regions, countries, policies, standing committee
   - historical sessions, codex initialization, stat history seed
4. `GameView` phase cycle:
   - `briefing/decision -> outcome -> personalAction -> next turn`
5. End turn path:
   - `GameEngine.endTurnUpdatesWithContext(...)`
   - then `turnNumber += 1`, `phase = briefing`, `actionPoints = 2`, `usedActionsThisTurn = []`.

## High-Value Invariants
- `Game.phase` stores raw string values of `GamePhase`.
- `Game.currentExpandedTrack` gates bureau actions; top leadership (`position >= 7`) bypasses strict track lock in bureau services.
- Multi-turn systems depend on `turnNumber` and encoded payload keys in `game.variables`.
- Any operation service change must preserve key names and decode fallback behavior.

## Strategic Resource System (Phase 3, session 029)
A full deep-economy layer added in session 029. The Chairman now manages a real supply chain, not just abstract sliders.

- **Core models**:
  - `Models/StrategicResource.swift` — 12-resource enum (4 energy + 4 heavy materials + 4 consumables). `displayName`, SF Symbol icon, `isRaw` flag, `minimumTechEra` gate.
  - `Models/TechEra.swift` — 5-tier Comparable enum (industrial → mechanized → atomic → computerized → modern). `era(forCompletedPlans:stakhanovitePlans:)` static helper.
  - `Models/SectorRecipe.swift` — 32 recipes (one per existing SectorFocus) declaring per-turn inputs/outputs/`requiredTechEra`. `RegionType.defaultEndowments` gives baseline extraction capacities per region type.
  - `Models/SupplyChainResult.swift` — per-turn record with `extractedByRegion`, `producedBySector`, `consumedBySector`, `shortfallBySector`, `deficitResources`, `tradeImportsByPartner`, `tradeExportsByPartner`. Persisted on Game.
  - `Models/EmergencyDecree.swift` — 6 decree types, each gated to a specific crisis. Cost + statEffects + resourceEffects + `isAvailable(in:)` + `lockReason`.
  - `Models/FocusForecast.swift` — Identifiable preview struct with input/output deltas, reserve projection, cross-sector strain, stat changes.

- **Game model fields added (Phase 3.1+)**:
  - `completedPlanCount`, `stakhanovitePlanCount` — drive tech era unlock
  - `currentTechEraRaw` (Int) + `currentTechEra` (TechEra) computed accessor
  - `strategicReservesData` (Data?) + `strategicReserves` ([StrategicResource: Int]) computed accessor
  - `lastSupplyChainResultData` (Data?) + `lastSupplyChainResult` (SupplyChainResult?) computed accessor
  - `replaySeed` (String) — set on game creation, persists with save (cache key for AI scenario generation)
  - `canUse(_:)` helper for tech-gated resource checks

- **Region model fields added**:
  - `endowmentsData` (Data?) + `endowments` ([StrategicResource: Int]) computed accessor
  - `extractionRate(of:)`, `has(_:)`, `seedDefaultEndowmentsIfNeeded()` helpers

- **TradeAgreement fields added (Phase 3.6)**:
  - `commodityImportsData`, `commodityExportsData` — per-turn flows applied each turn
  - `commodityImports`, `commodityExports`, `hasCommodityFlows` accessors
  - 3 starter agreements (Soviet/Czech/Polish) seeded with commodity flows that match their existing flavor text

- **Engine wiring**:
  - `Services/EconomySupplyChainEngine.processSupplyChain(game:)` — extracts from regions (scaled by region status), applies trade flows, runs sector recipes (bottleneck-input ratio determines satisfaction), persists updated reserves + result. Hooks into `EconomyService.processEconomy` at step 7c (between loan payments and regional economies).
  - `Services/FocusForecastService.forecast(switching:from:to:in:)` — simulates one turn ahead for the focus-change preview sheet.
  - `Services/EmergencyDecreeService` — `decreesWithAvailability(in:)`, `apply(_:to:)`. Atomic stat + resource + treasury effects.
  - `Services/GameEngine.applyStrategicResourceFeedback(game:)` — runs after the existing `applyEconomicPoliticalFeedback`. Resource deficits drain political stats (grain → popularSupport, steel → militaryLoyalty/eliteLoyalty, etc.). Sector-capacity feedback for sub-50% satisfaction. Multi-deficit crisis (3+ resources) fires importance-9 GameEvent + alert.
  - `Game.completeFiveYearPlan()` — increments plan counts and advances `currentTechEraRaw` if thresholds met. Fires unlock notification.

- **UI**:
  - `Views/Economics/Sectors/SectorDetailView.swift` — supply chain section (inputs with source regions, outputs in green, "must import" alerts, last-turn satisfaction banner). EMERGENCY DECREES button surfaces when sector has shortfall AND any decree is available.
  - `Views/Economics/Sectors/FocusForecastSheet.swift` — brutalist preview before any focus change.
  - `Views/Economics/Sectors/EmergencyDecreeSheet.swift` — Constructivist decree selection.

## Bureau Operations System (Current)
- Unified ledger layer:
  - `Models/BureauTask.swift` defines actionable tasks.
  - `Models/BureauOperation.swift` defines normalized operation display model.
  - `Services/BureauOperationsService.swift` maps Security/Economic/Party services into one interface.
- Execution routing:
  - `BureauOperationsService.executeTask(...)` routes by `actionCategory` to specific services.
- Network cost rule:
  - Network should only be deducted when an operation actually initiates.

## Recent Focused Patch Set (2026-02-06)
- `Services/GameEngine.swift`
  - End-turn now explicitly processes bureau operations via `processBureauOperations(...)`.
- `Services/SecurityActionService.swift`
  - Added turn processing for pending multi-turn actions:
    - `processPendingActions(for:modelContext:)`
  - Added detention lifecycle progression and resolution:
    - `processActiveDetentions(for:modelContext:)`
  - Added `applyDetentionOutcome(...)` to keep character status transitions consistent.
- `Services/BureauOperationsService.swift`
  - Task execution now treats operation initiation explicitly and deducts network only on initiated operations.
  - Added deterministic auto-target selection for security/faction/economic routes.
- `Services/PartyActionService.swift`
  - Campaign start/advance behavior aligned with unified operation initiation checks.
- `Services/SecurityBriefingService.swift`
  - Detention storage read is now backward compatible across key variants.
- Ledger UI integration:
  - `Views/Ledger/ActionableTasksSection.swift`
  - `Views/Ledger/ActiveOperationsSection.swift`
  - `Views/Ledger/ActivityFeedSection.swift`
  - `Views/Ledger/BureauOperationsCenter.swift`
  - updated for the unified task/operation/result wiring.

## Known Active Issues
- Project build configuration issue exists outside this folder in the Xcode project:
  - duplicate build product/resource generation (including `GeneratedAssetSymbols` / `LogStoreManifest.plist`) has previously blocked full `xcodebuild`.
- `Models/BureauTask.swift` is currently modified in git and should be treated as in-flight user work.

## Risk Areas To Validate After Any Bureau Change
- Multi-turn completion timing:
  - actions/campaigns must complete exactly on or after `completionTurn`.
- Detention lifecycle:
  - no permanent limbo detentions; terminal outcomes must clear active list.
- Cooldowns:
  - ensure cooldown set points match intended action start/resolve timing.
- Ledger consistency:
  - `Active Operations`, `Actionable Tasks`, and `Activity Feed` must agree on status.
- Resource accounting:
  - no double subtraction of `network`.

## Quick Verification Checklist
- Parse-check touched files:
  - `swiftc -parse <file.swift>`
- Sanity play loop:
  - start game -> launch bureau task -> end turns -> confirm operation progresses/resolves -> verify feed entry.
- Regression checks:
  - ensure `actionPoints` and `usedActionsThisTurn` reset each turn.
  - ensure no crash when no valid target exists for targeted bureau action.

## Session Update Protocol
When making meaningful changes, append one short entry:
- Date
- Files changed
- Why changed
- What was verified
- Remaining known risk

Template:

```md
### YYYY-MM-DD
- Files: ...
- Change: ...
- Verified: ...
- Remaining risk: ...
```

### 2026-04-17 (Session 029 — Comprehensive Redesign Sweep)
- Files: 25 commits across 40 new files + many modified. Full record in `docs/changelog/2026-04-17_session-029.md`.
- Change: Phases 0 (foundation), 1 (Chairman framing), 2 (visual cohesion structural), 3 (deep economy) — all complete or structurally complete. Major new systems: StrategicResource + TechEra data layer, EconomySupplyChainEngine, SectorRecipe (32 recipes), commodity-level trade, FocusForecastSheet, EmergencyDecreeSheet, RedactableText components, SovietIcon system, PersistentStatBar, OfficialEmptyState, CollapsibleSection, LockToast, StampOverlay, PaperGrainOverlay, ActionValidationResult unification, LawGate + ActionAvailability gating infrastructure, AI replayability cache key fix + Anthropic prompt caching.
- Verified: `xcodebuild build` returns BUILD SUCCEEDED at every commit. SourceKit cross-file resolution warnings throughout (project-wide, not session-specific).
- Remaining risk: Phase 3 economy needs playtesting and balance tuning (recipe ratios, region endowments, tech era unlock pacing, decree availability thresholds — see `docs/plans/REDESIGN_REMAINING_PHASES.md` Phase 3 Tuning section). Phase 4 (politics interactivity) and Phase 5 (polish + tutorial) not started. ~45 files still use deprecated color wrappers (StitchColors / FiftiesColors / BureauColors) — wrappers forward to canonical `ColdWarTheme.shared` so functionality is identical, pure code hygiene migration tracked as ongoing tech debt.

### 2026-04-13
- Files: `Views/Ledger/ActionableTasksSection.swift`
- Change: Removed a stray leading `d` from the file header so the branch compiles past the first Swift syntax error.
- Verified: `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build` no longer fails on `ActionableTasksSection.swift`; the next blocker is asset catalog compilation for the iPhone/iPad target configuration in this environment.
- Remaining risk: Turn-flow issues and project platform/build configuration issues remain unresolved, so runtime validation is still blocked here.

### 2026-04-13
- Files: `Views/Desk/DeskView+TurnManagement.swift`
- Change: Routed the visible desk `END TURN` button through `processEndTurnWithConsequences()` so it uses the same canonical turn pipeline as the confirmation-sheet flow instead of bypassing into direct desk turn advancement.
- Verified: Re-ran `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build`; no new Swift source compile failure surfaced from the desk change, and the build still stops at the existing asset catalog/simulator-runtime blocker.
- Remaining risk: Quiet-turn paths (`continueFromNarrativeEvent` / `continueFromNewspaper`) still bypass the canonical end-turn pipeline.

### 2026-04-13
- Files: `Views/Desk/DeskView+ScenarioHandling.swift`
- Change: Stopped informational narrative/newspaper flows from incrementing `turnNumber` directly. They now clear the current content, keep the player on the same turn when desk documents remain, and only hand off to `processEndTurnWithConsequences()` when the desk is clear so non-decision turns rejoin the canonical flow.
- Verified: `swiftc -parse Views/Desk/DeskView+ScenarioHandling.swift`, `swiftc -parse Views/Desk/DeskView+TurnManagement.swift`, and `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build`; no new Swift syntax/source error surfaced, and the build still stops at the existing asset catalog/simulator-runtime blocker.
- Remaining risk: Scenario pre-generation still snapshots next-turn content before final turn state is settled, so stale-content issues remain possible.

### 2026-04-13
- Files: `Services/ScenarioManager.swift`
- Change: Disabled use of next-turn pre-generated content for now. `startBackgroundLoading(...)` no longer applies pre-generated cache entries, and `preGenerateForNextTurn(...)` now clears any pending pre-generation instead of snapshotting mid-turn state into stale next-turn content.
- Verified: `swiftc -parse Services/ScenarioManager.swift` and `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build`; no new Swift source failure surfaced, and the build still stops at the existing asset catalog/simulator-runtime blocker.
- Remaining risk: This favors correctness over instant next-turn loads; if pre-generation is reintroduced later, it should happen only after final end-of-turn state is authoritative.

### 2026-04-13
- Files: `Views/GameOver/GameOverView.swift`
- Change: Replaced the hardcoded endgame rank title list with a lookup against the active campaign ladder via `CampaignLoader`, so late-game positions like Deputy General Secretary and General Secretary render from real config data.
- Verified: `swiftc -parse Views/GameOver/GameOverView.swift`
- Remaining risk: The game over summary still reflects `currentPositionIndex`, so if you later want “highest position ever held” instead of final position, that will need a separate position-history based change.

### 2026-04-13
- Files: `Views/Desk/DeskView.swift`, `Views/Desk/DeskView+TurnManagement.swift`
- Change: Fixed the cleared-desk UI state so once turn content has resolved and no scenario/newspaper is active, the desk shows the end-turn section instead of falling back to the immersive loading placeholder.
- Verified: `swiftc -parse Views/Desk/DeskView.swift`, `swiftc -parse Views/Desk/DeskView+TurnManagement.swift`, and `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build`; no new Swift source failure surfaced, and the build still stops at the existing asset catalog/simulator-runtime blocker.
- Remaining risk: Promotion timing is still evaluated before the completed turn increments `turnsInCurrentPosition`, so promotion gates may remain off by one turn.

### 2026-04-13
- Files: `ContentView.swift`
- Change: Fixed promotion timing so `completePersonalAction()` counts the just-finished turn in `turnsInCurrentPosition` before checking promotion eligibility. This removes the off-by-one delay where the completed turn did not count toward promotion requirements.
- Verified: `swiftc -parse ContentView.swift` and `xcodebuild -project ../Nomenklatura.xcodeproj -scheme Nomenklatura -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/NomenklaturaDerivedData CODE_SIGNING_ALLOWED=NO build`; no new Swift source failure surfaced, and the build still stops at the existing asset catalog/simulator-runtime blocker.
- Remaining risk: The recorded “Turn X begins” event in `completePersonalAction()` is still emitted outside the async end-turn block, so its timing/turn number may still be slightly misleading even though progression state is now correct.

### 2026-04-13
- Files: `Services/CodexService.swift`, `Views/Desk/DeskView+TurnManagement.swift`
- Change: Replaced the remaining live gameplay direct stat writes with `game.applyStat(...)`. Codex reply effects now update `patronFavor`/`rivalThreat` through the canonical stat path, and expired-document penalties now apply all stat losses through the same API instead of mutating game fields directly.
- Verified: `swiftc -parse Services/CodexService.swift`, `swiftc -parse Views/Desk/DeskView+TurnManagement.swift`, plus a repo sweep for direct gameplay stat assignment. The remaining direct writes are limited to previews and test-scenario setup paths.
- Remaining risk: `applyStat("rivalThreat", ...)` still does not record a dedicated “last rival interaction” timestamp because the model currently only tracks patron contact explicitly. If rival-neglect pacing ever needs symmetry, that should be added at the model layer rather than reintroducing direct mutation.

### 2026-04-13
- Files: `ContentView.swift`
- Change: Moved the “Turn X begins” event logging into the finalized end-of-turn transition so it is created only after `turnNumber`, phase, and turn-reset state have been advanced, and tagged it as `.narrative` instead of `.crisis`. This prevents the journal from recording the next-turn marker against the previous turn while async end-turn work is still in flight and stops normal turn starts from being presented as crises.
- Verified: `swiftc -parse ContentView.swift`
- Remaining risk: Turn markers are still logged from `ContentView` rather than a fully centralized turn reducer, so if turn advancement is consolidated later this event creation should move with it.

### 2026-04-13
- Files: `Models/Game.swift`, `Models/GameOverCondition.swift`
- Change: Fixed heir-state consistency so designating/removing/consuming an heir keeps both `designated_heir_id` and `heir_is_family` in sync, and heir eligibility now prefers the canonical `currentHeirRelationship` model state instead of trusting the variable mirror alone.
- Verified: `swiftc -parse Models/Game.swift`, `swiftc -parse Models/GameOverCondition.swift`
- Remaining risk: The larger succession feature is still only partially wired. `GameEngine.checkLossConditions(...)` remains the live game-over path, while `GameOverCondition` / `GameContinuation` / `processSuccessionToHeir()` still are not integrated into that active flow.

### 2026-04-13
- Files: `Services/GameEngine.swift`, `Models/Game.swift`, `ContentView.swift`
- Change: Wired designated-heir succession into the live loss flow for personal defeats. Patron collapse, standing collapse, and rival takedown now mark themselves as succession-eligible; the game completes end-turn processing, transfers control to the heir, resets inherited tenure timing, advances to the next turn, and shows an in-game succession notification instead of hard-ending the run.
- Verified: `swiftc -parse Services/GameEngine.swift`, `swiftc -parse Models/Game.swift`, `swiftc -parse ContentView.swift`
- Remaining risk: This is a minimum viable integration for designated heirs in the active game loop. The broader dormant continuation system (`GameOverCondition`, `GameContinuation`, non-designated successor selection, imprisonment/rehabilitation transitions) is still not reconciled with the live `GameEngine` path.

### 2026-04-13
- Files: `Services/GameEngine.swift`, `ContentView.swift`
- Change: Expanded the live game-over path so it now honors previously dormant catastrophic and flagged failures. The active engine recognizes structured system-collapse losses from `GameOverChecker` for nuclear war, territorial disintegration, capital loss, and foreign invasion, and it also activates the unused death/corruption personal-failure flags in the live flow. Succession recovery now clears predecessor-only fatal flags (`player_death_imminent`, `corruption_exposed`, related variables) so an heir who saves the run does not immediately die to stale state on the next check.
- Verified: `swiftc -parse Services/GameEngine.swift`, `swiftc -parse ContentView.swift`
- Remaining risk: The live game still preserves its original simple balance rules for patron/standing/rival collapse, revolution, and military coup rather than fully replacing them with `GameOverChecker` semantics. That keeps current pacing stable, but it means end-condition logic is still only partially centralized.

### 2026-04-13
- Files: `Models/GameContinuation.swift`, `Services/GameEngine.swift`, `ContentView.swift`
- Change: Closed the non-designated succession gap. `getAvailableHeirs()` now returns real committee/election candidates instead of only cultivated proteges, the live recovery path resolves the best legal successor even when the player never formally designated one, and succession notifications now distinguish designated heirs from Standing Committee / Party-election continuity picks.
- Verified: `swiftc -parse Models/GameContinuation.swift`, `swiftc -parse Services/GameEngine.swift`, `swiftc -parse ContentView.swift`
- Remaining risk: This is still an automatic resolution path rather than a player-facing heir-selection screen. It makes the continuation rules actually work in live play, but the dormant multi-candidate selection UX is still not exposed.

### 2026-04-13 (Session 026 — Game Design Audit & Directive Fix)
- Files: `Views/Directive/DirectivePhaseView.swift`, `Views/Directive/BureauCommandCard.swift`, `Views/PersonalAction/ActionCardView.swift`, `Views/PersonalAction/PersonalActionView.swift`, `Utilities/UrgencyAdvisor.swift` (NEW)
- Change: Fixed critical bug where diplomatic/military/state ministry directives always passed `nil` targets, making "Request Country Briefing" and ~40 other targeted actions non-functional from the Directive Phase. Added 5 target selection overlays (country, officer, theater, ministry, official) with full selection UI. Added crisis-aware urgency triage system: `UrgencyAdvisor` detects 9 crisis types and flags relevant actions/bureaus with visual urgency markers. Personal action categories auto-sort by crisis relevance.
- Verified: `xcodebuild` BUILD SUCCEEDED, no compilation errors
- Remaining risk: Target selection overlays may need refinement for edge cases (empty officer lists, very long country lists). Urgency thresholds may need tuning after playtesting.

### 2026-04-13
- Files: `Models/GameOverCondition.swift`, `Models/GameContinuation.swift`
- Change: Aligned the richer dormant game-over checker with canonical game state. Military coup checks now read `game.militaryLoyalty`, corruption exposure reads `game.corruptionEvidence`, and heir viability now uses the same resolved-succession logic as the live continuation flow instead of separate variable-mirror heuristics.
- Verified: `swiftc -parse Models/GameOverCondition.swift`, `swiftc -parse Models/GameContinuation.swift`
- Remaining risk: `GameOverChecker` still is not the single authoritative end-condition engine for every loss type. The live game continues to use its legacy patron/standing/rival threshold losses and simplified revolution/coup path alongside the richer checker.

### 2026-04-13
- Files: `Services/DocumentQueueService.swift`, `Models/World/AccessLevel.swift`, `Models/Game.swift`
- Change: Reworked desk document generation so “awaiting action” prompts are tied to the player’s actual current office and authority, not just raw rank or stale committed-track history. Document categories are now hard-filtered by active office track, top leadership gets more cross-bureau strategic material and less routine clerical paperwork, template selection now prefers the top two tiers available at the player’s current authority level, and `AuthorityLanguage` now resolves real ladder titles/track-aware authority instead of using the outdated generic rank mapping.
- Verified: `swiftc -parse Services/DocumentQueueService.swift`, `swiftc -parse Models/World/AccessLevel.swift`, `swiftc -parse Models/Game.swift`
- Remaining risk: This fixes routing and tiering logic, but the underlying document template library is still uneven across bureaus. Once Xcode/device testing is available, the next pass should be qualitative: check whether each track has enough genuinely role-specific prompt variety, especially for Party, Regional, and top-leadership desks.

### 2026-04-15 (Session 028 — Six-Unit Systems Audit & Redesign, Batch Mode)
- Files: `Services/EconomyService.swift`, `Services/CodexService.swift`, `Services/EconomicActionService.swift`, `Services/GameEngine.swift`, `Services/FiveYearPlanService.swift` (NEW), `Models/Game.swift`, `Models/Region.swift`, `Models/EconomicAction.swift`, `Models/CodexMessage.swift`, `Models/StateBankLoan.swift` (NEW), `Models/FiveYearPlanTargets.swift` (NEW), `Views/Ledger/LedgerView.swift`, `Views/Ledger/BureauOperationsView.swift` (NEW), `Views/Economics/FiveYearPlanWheelView.swift`, `Views/Economics/EconomicHubView.swift`, `Views/Economics/BudgetManagementView.swift`, `Views/Economics/RegionalEconomicsManagementView.swift`, `Views/Economics/StateBankView.swift` (NEW), `Views/Economics/PlanTargetSetupView.swift` (NEW), `Views/Codex/CodexView.swift`, `Views/Codex/CodexThreadView.swift`, `ContentView.swift`
- Change: Six parallel workers landed on six separate branches (all builds SUCCEEDED). (1) **Treasury transparency**: `EconomicReport` now actually applies to treasury via `applyEconomicReport()`; GDP conversion halved and stored as `gdpAdjustment` line item so breakdown sum = real delta. Next-turn projection added. (2) **State Bank loans**: new `StateBankLoan` @Model with Gosbank/Socialist Bloc/Western sources, inflation side effects, obligation flags, early repayment; lives alongside legacy ForeignLoan via unified `totalDebtService`. (3) **Ledger redesigned as Political Situation Room**: 1,200 → 565 lines; removed economy stats and legacy bureau cards; added TrendBadge deltas and ThreatsSection with tab-switch nav; BureauOperationsCenter moved to its own sheet. (4) **Codex**: pacing tightened (patron 3, rival 5, check-in 7, 1/turn cap except during crisis); numeric effect chips on responses; trigger badges on messages; Terminal/Encyclopedia segmented control. (5) **Real Five-Year Plan**: `FiveYearPlanTargets` + `FiveYearPlanService` — six PlanSector goals per 20-turn cycle, preset difficulties, end-of-cycle consequences (Stakhanovite/Success/Mixed/Plan Failure); actions reduced 25→12+2 with `planSectorContributions` mapping; wheel shows real progress. (6) **Regions**: `Region.treasuryContribution` surfaced; 3 new actions (Deploy Cadres, Federal Aid, SEZ); dead governor/cultural data collapsed; cooldown map added.
- Verified: `xcodebuild build` SUCCEEDED on all 6 worktrees (iPhone 17 Pro / iOS 26.2). No interactive simulator runs possible inside sandbox — PLAYTEST REQUIRED before merging.
- Remaining risk: Units 1/2/5 all touch EconomyService.swift — manual merge conflict resolution required. Recommended merge order: 1 → 2 → 5, then 3, 4, 6. `EconomicDashboardView.PlanSector` was renamed to `LegacyDashboardSector` to disambiguate from new `PlanSector` enum — check downstream references. `CodexResponseEffects.calculate()` (UI side) must stay in sync with `CodexService.applyResponseEffects()` (service side) — effect map is duplicated. PR creation blocked by sandbox on all 6 workers; branches pushed, PRs need manual click at the URLs noted in session-028 changelog.

### 2026-04-14 (Session — Economics & Politics Overhaul)
- Files: `Services/EconomyService.swift`, `Services/PolicyService.swift`, `Services/PoliticalAIService.swift`, `Models/Game.swift`, `Services/GameEngine.swift`, `Models/World/ForeignCountry.swift`, `Models/World/EconomicSystemType.swift`, `Views/Directive/DirectivePhaseView.swift`, `Views/Directive/BureauCommandCard.swift`, `Views/PersonalAction/ActionCardView.swift`, `Views/PersonalAction/PersonalActionView.swift`, `Views/Economy/EconomicHubView.swift` (NEW), `Views/Economy/TradeManagementView.swift` (NEW), `Views/Economy/RegionalEconomicsManagementView.swift` (NEW), `Views/Economy/BudgetManagementView.swift` (NEW), `Views/Economy/SectorDetailView.swift` (NEW), `Views/Economy/TradeProposalSheet.swift` (NEW), `Views/Economy/LoanProposalSheet.swift` (NEW), `Services/DocumentQueueService.swift`, `Views/Navigation/BottomNavBar.swift`, `Views/World/WorldTabView.swift`
- Change: Massive economics and politics overhaul. (1) Fixed ALL 15 policy slot ID mismatches across 4 files — economy was silently non-functional. (2) Wired track affinity from directives (+3) and personal actions (+2). (3) Security bureau directives now show character selection overlay. (4) Economy-politics feedback loop: low treasury/food/unemployment/inflation affect loyalty/support/stability. (5) Dynamic world economy events. (6) Replaced Ladder tab with Economy (Gosplan) tab featuring EconomicHubView (932 lines). (7) Deep sector specialization (32 focus options), trade negotiation with tariffs/embargoes, budget allocation, foreign loan system. (8) Seeded economic data at game start. (9) Fixed General Secretary display, rebellion spam, redacted content. (10) Rebalanced economic penalties.
- Verified: Build status not re-verified in this session (changes span too many files for isolated parse checks).
- Remaining risk: The new economics UI is extensive (3,361+ new lines). Sector focus effects, loan payment processing, tariff/embargo trade impact, and budget allocation all need playtesting. The Ladder view still exists but is no longer in the bottom nav — it may need cleanup or reintegration as a sub-view elsewhere.
