# Nomenklatura Update - December 9, 2025

## Summary
Major UI/UX improvements, game flow enhancements, and bug fixes.

---

## 1. SwiftData Migration Fix

**Problem:** App crashed on launch with `SwiftDataError` after schema changes.

**Solution:** Updated `NomenklaturaApp.swift` to handle schema migration errors gracefully:
- Added `Policy.self` to the schema
- On migration failure, deletes existing store files and recreates fresh
- Prevents crash, though existing save data is lost on schema changes

**Files Changed:**
- `NomenklaturaApp.swift`

---

## 2. Career Ladder - Fixed Duplicate Paths

**Problem:** The ladder view showed duplicate positions because `ForEach` used `\.index` as identifier, but with branching careers (Moscow/Regional tracks), multiple positions share the same index.

**Solution:**
- Changed `ForEach` to use unique `\.id` (combines track + index)
- Added `visibleLadderPositions` computed property that filters positions based on player's current track
- Shared positions always visible; branched positions only show player's chosen track
- Before branching, both tracks shown as preview

**Files Changed:**
- `Views/Ladder/LadderView.swift`

---

## 3. Enhanced Ledger View

**Problem:** Stats display was basic and lacked visual hierarchy or context.

**Solution:** Complete redesign with:

### Overall Status Banner
- Shows state health: STABLE, UNCERTAIN, DANGER, or CRISIS
- Color-coded with icon and descriptive message
- Calculates based on critical stats and averages

### Category Cards
Stats grouped into styled cards with unique accent colors:
- **STABILITY** (Soviet Red) - Political Stability, Popular Support
- **POWER CENTERS** (Gold) - Military Loyalty, Party Elite Loyalty
- **RESOURCES** (Green) - Treasury, Industrial Output, Food Supply
- **EXTERNAL** (Blue) - International Standing

### Enhanced Stat Rows
- Icons for each stat
- Status badges (CRITICAL, LOW, STRONG)
- Danger zone marker at 30% on progress bars
- Info button to view full stat explanation

**Files Changed:**
- `Views/Ledger/LedgerView.swift` (complete rewrite)

---

## 4. Turn 1 Introduction Scenario

**Problem:** Every turn started with random scenarios, potentially throwing crises at new players before they understood the game.

**Solution:** Added special Turn 1 introduction scenario:

### New Category
- Added `introduction` case to `ScenarioCategory` enum
- Weight of 0 (not randomly selected)

### Introduction Scenario Content
Player arrives at their new office. Aide Sasha explains:
- Your patron (Minister Volkov) and his expectations
- Your rival (Deputy Director Sorokin) and the threat he poses
- Your predecessor's sudden departure

### Four Starting Options
- **A) Meet your patron** - Builds favor, establishes loyalty
- **B) Review predecessor's files** - Builds network and knowledge
- **C) Observe Politburo quietly** - Builds cunning reputation
- **D) Make a bold proposal** - Builds standing but creates rivals

### Implementation
- `ScenarioManager.getFallbackScenario()` checks for Turn 1
- Always returns introduction scenario on first turn
- Regular weighted selection for Turn 2+

**Files Changed:**
- `Models/Scenario.swift` - Added `introduction` category
- `Services/ScenarioManager.swift` - Turn 1 handling + introduction scenario
- `Views/Desk/BriefingPaperView.swift` - Added `introduction` cases to switches

---

## 5. Personal Actions - Once Per Turn Restriction

**Problem:** Players could perform the same personal action multiple times per turn.

**Solution:** Track used actions and prevent repeats:

### Game Model
- Added `usedActionsThisTurn: [String]` property to `Game`

### GameEngine
- Check if action already used before executing
- Append action ID to list after successful execution
- Return failure result if action already used

### PersonalActionView
- Check `usedActionsThisTurn` for each action
- Show "Already performed this turn" as lock reason
- Disable action card visually

### Turn Advancement
- Clear `usedActionsThisTurn` when turn advances

**Files Changed:**
- `Models/Game.swift` - Added `usedActionsThisTurn` property
- `Services/GameEngine.swift` - Added duplicate check in `executeAction()`
- `Views/PersonalAction/PersonalActionView.swift` - Added visual indication
- `ContentView.swift` - Clear list on turn advance

---

## Files Modified (Complete List)

### Models
- `Models/Game.swift`
- `Models/Scenario.swift`

### Views
- `Views/Ledger/LedgerView.swift`
- `Views/Ladder/LadderView.swift`
- `Views/PersonalAction/PersonalActionView.swift`
- `Views/Desk/BriefingPaperView.swift`

### Services
- `Services/ScenarioManager.swift`
- `Services/GameEngine.swift`

### App
- `NomenklaturaApp.swift`
- `ContentView.swift`

---

## Testing Notes

1. **SwiftData Migration:** First launch after update will reset save data
2. **Ladder View:** Test with characters at different positions and tracks
3. **Ledger:** Verify stat tooltips open correctly, check all health states
4. **Turn 1:** Start new game, verify introduction scenario appears
5. **Personal Actions:** Perform action, verify it's disabled for rest of turn, verify it resets next turn
