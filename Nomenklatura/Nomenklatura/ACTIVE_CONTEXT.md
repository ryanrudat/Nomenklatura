# Nomenklatura Active Context

Last updated: 2026-02-06
Workspace: `/Users/ryanrudat/Desktop/Nomenklatura/Nomenklatura/Nomenklatura`

## Purpose
This file is a living engineering context for the app. Read this first in future sessions to recover architecture, invariants, and current problem areas before patching.

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
