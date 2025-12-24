# Living World Integration Plan

## Current State Analysis

### What Exists (All Bureaus Have Engines)

| Bureau | Action Service | Lines | Actions | Multi-Turn | NPC AI |
|--------|---------------|-------|---------|------------|--------|
| **Economic** | `EconomicActionService.swift` | ~700 | 25+ | Projects | 20%/turn |
| **Security** | `SecurityActionService.swift` | ~900 | 29 | Shuanggui | 25%/turn |
| **Military** | `MilitaryActionService.swift` | ~830 | 25 | Campaigns | 20%/turn |
| **Party** | `PartyActionService.swift` | ~840 | 20+ | Campaigns | 20%/turn |
| **State Ministry** | `StateMinistryActionService.swift` | ~840 | 20+ | Projects | 15%/turn |

### NPC Systems (Highly Sophisticated)

- **46 goal types** across 9 categories
- **Memory system** with grudges, gratitude, fear, trust (RDR2-inspired)
- **6 psychological needs** (Security, Power, Loyalty, Recognition, Stability, Ideology)
- **NPC-to-NPC relationships** - independent from player
- **3 decision systems**: Standard, Goal-Driven, Memory-Influenced
- **Ambient activities** for "living world" feel
- **Espionage system** with foreign agents

---

## GAPS IDENTIFIED

### Critical: Services NOT Wired to Turn Processing

| Service | Method | Purpose | Status |
|---------|--------|---------|--------|
| `InternationalEventService` | `processTurn()` | Relationship drift, treaties, espionage, world tension | **NOT CALLED** |
| `RegionSecessionService` | `processTurn()` | Regional stability, secession, cascade effects | **NOT CALLED** |

### Current Turn Processing Flow (GameEngine.endTurnUpdates)

```
1. applyStatDrift()                    ✓
2. simulateNPCActions()                ✓
3. applyRandomEvents()                 ✓
4. simulateWorldEvents()               ✓ (WorldSimulationService)
5. processNPCBehaviorSystem()          ✓ (CharacterAgency, Memory, Ambient)
6. processPoliticalAI()                ✓ (PoliticalAIService)
7. processPositionOffers()             ✓ (PositionOfferService)
8. processEconomicSystem()             ✓ (EconomyService - NEW)

MISSING:
9. processInternationalDynamics()      ❌ InternationalEventService
10. processRegionalDynamics()          ❌ RegionSecessionService
```

---

## Impact of Gaps

### International Dynamics Not Processing
Without `InternationalEventService.processTurn()`:
- Foreign country relationships do NOT drift based on bloc alignment
- Treaty effects (trade bonuses, mutual defense) NOT applied each turn
- Espionage activities NOT processed (no spy discoveries)
- World tension NOT updated based on hostile countries
- Proxy war opportunities NOT checked
- Diplomatic crises NOT triggered
- Alliance strains NOT detected

### Regional Dynamics Not Processing
Without `RegionSecessionService.processTurn()`:
- Regions do NOT update secession progress each turn
- Governor effects NOT applied
- Regional status transitions NOT happening (stable → unrest → crisis → rebellion)
- Cascade effects NOT processed (crisis in one region spreading)
- Territorial integrity checks NOT running
- Game-over conditions from secession NOT checked

---

## Integration Plan

### Phase 1: Wire Missing Services (Immediate)

**File: `GameEngine.swift`**

Add to `endTurnUpdates()`:

```swift
// International dynamics - foreign relations, treaties, espionage
processInternationalDynamics(game: game)

// Regional dynamics - stability, secession, territorial integrity
processRegionalDynamics(game: game)
```

Implementation:

```swift
/// Process international dynamics each turn
private func processInternationalDynamics(game: Game) {
    gameLogger.info("Processing international dynamics for turn \(game.turnNumber)")
    InternationalEventService.shared.processTurn(game: game)
}

/// Process regional dynamics each turn
private func processRegionalDynamics(game: Game) {
    gameLogger.info("Processing regional dynamics for turn \(game.turnNumber)")
    RegionSecessionService.shared.processTurn(game: game)
}
```

### Phase 2: Cross-System Effects

Economy should affect other systems:

| Economic State | Effect On |
|----------------|-----------|
| GDP decline >10% | Regional loyalty -5, Stability -3 |
| Inflation >30% | Popular support -5/turn, Strike chance +20% |
| Unemployment >15% | Regional unrest +10, Labor strike events |
| Trade balance <-20 | Treasury drain, Foreign dependency |

International should affect economy:

| International State | Effect On |
|---------------------|-----------|
| Trade treaty | Treasury +2/turn, GDP +1% |
| Embargo | GDP -5%, Sector disruption |
| World tension >80 | Military spending +10, Consumer goods -5 |

### Phase 3: Event Generation Integration

Generate DynamicEvents from all systems:

```swift
// In endTurnUpdates, after processing:

// Generate international crisis events
let internationalEvents = InternationalEventService.shared
    .generateInternationalEvents(for: game)
for crisis in internationalEvents {
    if let country = game.country(withId: crisis.countryId) {
        let event = InternationalEventService.shared
            .createDynamicEvent(from: crisis, country: country, currentTurn: game.turnNumber)
        game.queueDynamicEvent(event)
    }
}

// Generate regional crisis events
let regionalEvents = RegionSecessionService.shared
    .generateRegionalEvents(for: game)
for crisis in regionalEvents {
    if let region = game.regions.first(where: { $0.regionId == crisis.regionId }) {
        let event = RegionSecessionService.shared
            .createDynamicEvent(from: crisis, region: region, currentTurn: game.turnNumber)
        game.queueDynamicEvent(event)
    }
}
```

### Phase 4: Verify Complete Integration Order

Optimal turn processing order:

```
1. applyStatDrift()                    - Natural equilibrium
2. simulateNPCActions()                - Rival/patron behavior
3. applyRandomEvents()                 - Small fluctuations
4. simulateWorldEvents()               - Global events generation
5. processNPCBehaviorSystem()          - Goals, memories, activities
6. processPoliticalAI()                - Policy proposals, votes
7. processInternationalDynamics()      - Treaties, relations, espionage (NEW)
8. processRegionalDynamics()           - Stability, secession (NEW)
9. processPositionOffers()             - Career opportunities
10. processEconomicSystem()            - GDP, inflation, unemployment
11. generateCrisisEvents()             - Queue events from all systems (NEW)
```

---

## Verification Checklist

After integration, verify each turn:

- [ ] Foreign country relationships drift based on bloc
- [ ] Active treaties provide bonuses (trade +2 treasury/turn)
- [ ] Espionage activities can discover spies
- [ ] World tension updates based on hostile countries
- [ ] Region stability scores update based on conditions
- [ ] Governor effects apply (competence, loyalty)
- [ ] Secession progress advances for at-risk regions
- [ ] Cascade effects spread instability
- [ ] GDP changes affect regional loyalty
- [ ] International crises generate DynamicEvents
- [ ] Regional crises generate DynamicEvents

---

## Files to Modify

| File | Changes |
|------|---------|
| `GameEngine.swift` | Add processInternationalDynamics(), processRegionalDynamics() |
| `EconomyService.swift` | Add cross-system effects (economy → regions, economy → international) |
| `InternationalEventService.swift` | Minor: ensure processTurn() ready for integration |
| `RegionSecessionService.swift` | Minor: ensure processTurn() ready for integration |

---

## Success Criteria

1. **Living World**: All systems update every turn without player intervention
2. **Cross-Effects**: Economic collapse triggers regional unrest
3. **NPC Autonomy**: Foreign countries drift, regions evolve, NPCs scheme
4. **Event Generation**: Crises from all systems create meaningful choices
5. **Coherent Narrative**: Economic, international, and regional events interconnect

---

## Implementation Priority

1. **Immediate**: Wire InternationalEventService.processTurn() into GameEngine
2. **Immediate**: Wire RegionSecessionService.processTurn() into GameEngine
3. **Short-term**: Add event generation for international/regional crises
4. **Medium-term**: Implement cross-system effects (economy → regions)
5. **Polish**: Balance testing, logging, debugging
