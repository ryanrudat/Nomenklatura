# Promotion System Implementation Plan

## Status: ✅ COMPLETE (as of December 2024)

All core promotion system features have been implemented and wired into the game loop.

---

## Implementation Summary

### What's Implemented (100% Core Features)

1. **Position Ladder** (`CampaignConfig.swift`) - 8 tiers, 6 tracks with requirements
2. **Position Offers** (`PositionOffer.swift`) - Model with 8 offer types
3. **Offer Service** (`PositionOfferService.swift`) - Generation and acceptance logic
4. **History Tracking** (`PositionHistoryService.swift`) - Records all changes
5. **Track Affinity** (`Game.swift`) - Specialization scoring
6. **Turn Processing** - `PositionOfferService.processTurn()` called in `GameEngine.endTurnUpdates()`
7. **Event Generation** - `createOfferEvent()` queues offers as `DynamicEvent`
8. **Vacancy Tracking** - `CharacterFateService.markPositionVacant()` when NPCs removed
9. **UI Gating** - All 5 portal views have `hasTrackAuthority` checks with `NoTrackAuthorityView`

---

## Wiring Verification

### GameEngine.swift (lines 564-673)

```swift
// Position offers - check expirations and generate new offers
processPositionOffers(game: game)

private func processPositionOffers(game: Game) {
    PositionOfferService.shared.processTurn(game: game)

    // Check for pending offers that need to be presented as events
    let pendingOffers = game.positionOffers.filter { $0.status == .pending && !$0.hasBeenPresented }
    for offer in pendingOffers {
        let event = PositionOfferService.shared.createOfferEvent(for: offer, currentTurn: game.turnNumber)
        game.queueDynamicEvent(event)
        offer.hasBeenPresented = true
    }
}
```

### CharacterFateService.swift - Vacancy Tracking

```swift
private func markPositionVacant(position: Int, track: String, game: Game) {
    game.variables["vacancy_\(track)_\(position)"] = "true"
    game.variables["vacancy_turn_\(track)_\(position)"] = "\(game.turnNumber)"
}

func getVacantPositions(for game: Game) -> [(track: String, position: Int, sinceTurn: Int)]
func clearVacancy(position: Int, track: String, game: Game)
```

Called when characters are:
- Executed
- Purged
- Died
- Removed with any fate status

### Portal Views - Track Authority Gating

All 5 bureau portals implement:

```swift
private var hasTrackAuthority: Bool {
    let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
    let isInTrack = playerTrack == .[relevantTrack]
    let isTopLeadership = game.currentPositionIndex >= 7
    return isInTrack || isTopLeadership
}

// In view body:
if !hasTrackAuthority {
    NoTrackAuthorityView(bureauName: "...", playerTrack: game.currentExpandedTrack)
}
```

**Implemented in:**
- `SecurityPortalView.swift` (lines 980-1018)
- `EconomicPortalView.swift` (lines 751-789)
- `MilitaryPortalView.swift` (lines 775-813)
- `PartyPortalView.swift` (lines 669-697)
- `StateMinistryPortalView.swift` (lines 700-728)

---

## Promotion Logic (GameEngine.swift)

### Eligibility Check
- Minimum turns in position (default 6 turns = ~3 months)
- Standing requirement
- Patron favor requirement (if applicable)
- Network requirement (if applicable)
- Faction support requirements
- Vacancy availability
- Rival threat check (blocks if >= 80)

### Execution
- Records in `PositionHistoryService`
- Updates track and position
- Adds track affinity
- Commits to track if specialized
- Logs event with importance 10

---

## Future Enhancements (Optional)

These were planned but are not required for core functionality:

1. **Organization Department Approval** - Weighted approval formula based on political climate
2. **Age-Based Succession** - Party Congress evaluations every 5 turns
3. **Two-Level-Up Constraints** - Limit rapid advancement

---

## Success Criteria - All Met ✅

1. ✅ **Bug Fixed**: Player cannot execute actions in bureaus they don't belong to
2. ✅ **Offers Generated**: Position offers appear after meeting requirements
3. ✅ **Offers Processed**: Accept/decline choices update game state
4. ✅ **Vacancies Filled**: Purged NPC positions become available
5. ✅ **Authentic Feel**: Promotions feel like CCP system (patron-driven, factional, political)
