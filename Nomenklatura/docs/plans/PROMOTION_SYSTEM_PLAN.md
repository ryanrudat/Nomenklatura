# Promotion System Implementation Plan

## Current State Analysis

### What Exists (70% Complete)
1. **Position Ladder** (`CampaignConfig.swift`) - 8 tiers, 6 tracks with requirements
2. **Position Offers** (`PositionOffer.swift`) - Model with 8 offer types
3. **Offer Service** (`PositionOfferService.swift`) - Generation and acceptance logic
4. **History Tracking** (`PositionHistoryService.swift`) - Records all changes
5. **Track Affinity** (`Game.swift`) - Specialization scoring

### What's Missing (Critical Gaps)
1. **Turn Processing Integration** - `processTurn()` never called
2. **Event Response Handler** - Accept/decline not processed
3. **Vacancy Tracking** - Purged NPC positions not marked available
4. **UI Gating** - Actions clickable when player lacks authority

---

## Phase 1: Fix Immediate Bugs

### 1.1 Disable Actions When Player Lacks Track Authority

**Problem**: Player can click actions in bureaus they don't belong to.

**Solution**: Update each portal's action section to check track before enabling actions.

**Files to modify**:
- `SecurityActionsSection` - check `securityServices` track
- `EconomicActionsSection` - check `economicPlanning` track
- `MilitaryActionsSection` - check `militaryPolitical` track
- `PartyActionsSection` - check `partyApparatus` track
- `StateMinistryActionsSection` - check `stateMinistry` track

**Logic**:
```swift
private var hasTrackAuthority: Bool {
    let playerTrack = ExpandedCareerTrack(rawValue: game.currentExpandedTrack) ?? .shared
    let isInTrack = playerTrack == .securityServices // (or relevant track)
    let isTopLeadership = game.currentPositionIndex >= 7
    return isInTrack || isTopLeadership
}
```

If `!hasTrackAuthority`:
- Show "No Authority" message instead of actions
- Or show actions grayed out with lock icon

---

## Phase 2: Connect Promotion System

### 2.1 Add Turn Processing to GameEngine

**File**: `GameEngine.swift` (or equivalent turn processor)

**Add to turn processing**:
```swift
// Process position offers
PositionOfferService.shared.processTurn(for: game, config: config, modelContext: modelContext)
```

This will:
- Check if new offers should be generated
- Expire old offers
- Apply consequences for expired offers

### 2.2 Create Position Offer Event Handler

**Problem**: Position offers are converted to `DynamicEvent` but responses aren't handled.

**Solution**: Create handler in event processing that routes responses:

```swift
// When player responds to position offer event
if event.type == .positionOffer {
    if response == "accept" {
        PositionOfferService.shared.acceptOffer(offer, game: game, config: config)
    } else if response == "decline" {
        PositionOfferService.shared.declineOffer(offer, game: game)
    } else if response == "consider" {
        PositionOfferService.shared.requestTimeForOffer(offer, game: game)
    }
}
```

### 2.3 Add Position Offer Trigger to Event System

**File**: `DynamicEventTriggerService.swift`

**Add trigger type**: When pending position offers exist, create events for them.

```swift
// Check for pending position offers that need player attention
let pendingOffers = game.getPendingPositionOffers()
for offer in pendingOffers where offer.status == .pending && !offer.hasBeenPresented {
    let event = PositionOfferService.shared.createOfferEvent(offer, game: game, config: config)
    queuedEvents.append(event)
    offer.hasBeenPresented = true
}
```

---

## Phase 3: Vacancy and Succession System

### 3.1 Track Position Vacancies

When NPCs are removed (purged, executed, retired, etc.), mark their position as vacant:

```swift
// In CharacterFateService or wherever NPCs are removed
func removeCharacter(_ character: GameCharacter, reason: PositionEndReason, game: Game) {
    if let positionIndex = character.positionIndex, let track = character.positionTrack {
        game.setVariable("vacancy_\(track)_\(positionIndex)", value: "true")
        game.setVariable("vacancy_turn_\(track)_\(positionIndex)", value: "\(game.turnNumber)")
    }
}
```

### 3.2 Generate Offers for Vacancies

Modify `PositionOfferService.generateOffers()` to prioritize vacant positions:

```swift
// Check for vacancies in player's track
let vacantPositions = findVacantPositionsInTrack(playerTrack, game: game, config: config)
for vacancy in vacantPositions {
    if playerMeetsRequirements(for: vacancy, game: game) {
        let offer = createOffer(for: vacancy, reason: .vacancyNeed, game: game)
        offers.append(offer)
    }
}
```

---

## Phase 4: CCP-Authentic Promotion Triggers

Based on research, promotions should be triggered by:

### 4.1 Patronage System (Primary Driver)

```swift
struct PatronagePromotion {
    // Patron favor >= 60 AND position available = high chance of offer
    // Patron favor >= 80 = almost guaranteed offer when position opens
    // Patron purged = all promotions blocked, possible demotion
}
```

### 4.2 Factional Support

```swift
struct FactionPromotion {
    // Strong faction alignment + faction controls Organization Dept = bonus
    // Opposing faction controls appointments = blocked
    // Faction leader purged = faction members vulnerable
}
```

### 4.3 Performance Metrics (Secondary)

```swift
struct PerformancePromotion {
    // High standing + high competence reputation = merit offer possible
    // But ONLY if political loyalty is also high
    // Under hardline leader: loyalty > competence
}
```

### 4.4 Age-Based Succession

```swift
struct AgeSuccession {
    // Every 5 turns (Party Congress): evaluate age limits
    // Position holders age 68+ must retire
    // Creates cascade of vacancies
    // Player can advance rapidly if well-positioned
}
```

### 4.5 Purge Opportunities

```swift
struct PurgePromotion {
    // When major purge occurs:
    // - Positions of purged officials become vacant
    // - Loyalists can be rapidly promoted to fill gaps
    // - Those who denounced purged = bonus standing
    // - Those who defended purged = at risk
}
```

---

## Phase 5: Organization Department Approval

Add approval step that weighs multiple factors:

```swift
struct OrganizationDepartmentEvaluation {
    let politicalQuality: Int      // 0-100, most important under Xi-style leader
    let patronSupport: Int         // Does a senior leader vouch for you?
    let factionAlignment: Int      // Does your faction control appointments?
    let performanceMetrics: Int    // Economic output, stability, etc.
    let ideologicalPurity: Int     // Self-criticism sessions, loyalty declarations
    let seniority: Int             // Time in current position

    func calculateApprovalChance() -> Int {
        // Weighted formula based on current political climate
        // Hardline era: political quality 40%, patron 30%, faction 20%, performance 10%
        // Reform era: performance 30%, patron 25%, faction 25%, political 20%
    }
}
```

---

## Implementation Priority

### Immediate (This Session)
1. [ ] Fix action UI gating for track authority
2. [ ] Add `processTurn()` call to game loop

### Short Term
3. [ ] Create position offer event handler
4. [ ] Add vacancy tracking when NPCs removed
5. [ ] Test offer generation and acceptance flow

### Medium Term
6. [ ] Implement patron-driven promotion logic
7. [ ] Add factional influence on appointments
8. [ ] Create age-based succession events

### Long Term
9. [ ] Organization Department approval mini-system
10. [ ] Purge-driven rapid advancement
11. [ ] Two-level-up appointment constraints

---

## Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `GameEngine.swift` | Modify | Add `processTurn()` call |
| `DynamicEventTriggerService.swift` | Modify | Add position offer triggers |
| `PositionOfferResponseHandler.swift` | Create | Handle accept/decline responses |
| `VacancyTrackingService.swift` | Create | Track open positions |
| `CharacterFateService.swift` | Modify | Mark vacancies when NPCs removed |
| `SecurityActionsSection` | Modify | Add track authority check |
| `EconomicActionsSection` | Modify | Add track authority check |
| `MilitaryActionsSection` | Modify | Add track authority check |
| `PartyActionsSection` | Modify | Add track authority check |
| `StateMinistryActionsSection` | Modify | Add track authority check |

---

## Success Criteria

1. **Bug Fixed**: Player cannot execute actions in bureaus they don't belong to
2. **Offers Generated**: Position offers appear after meeting requirements
3. **Offers Processed**: Accept/decline choices update game state
4. **Vacancies Filled**: Purged NPC positions become available
5. **Authentic Feel**: Promotions feel like CCP system (patron-driven, factional, political)
