# Living World Integration Plan

## Status: ✅ COMPLETE (as of December 2024)

All living world systems have been wired into the game loop and are processing each turn.

---

## Implementation Summary

### What's Implemented (All Systems Active)

| Bureau | Action Service | Lines | Actions | Multi-Turn | NPC AI |
|--------|---------------|-------|---------|------------|--------|
| **Economic** | `EconomicActionService.swift` | ~700 | 25+ | Projects | 20%/turn |
| **Security** | `SecurityActionService.swift` | ~900 | 29 | Shuanggui | 25%/turn |
| **Military** | `MilitaryActionService.swift` | ~830 | 25 | Campaigns | 20%/turn |
| **Party** | `PartyActionService.swift` | ~840 | 20+ | Campaigns | 20%/turn |
| **State Ministry** | `StateMinistryActionService.swift` | ~840 | 20+ | Projects | 15%/turn |

### NPC Systems (All Active)

- **46 goal types** across 9 categories
- **Memory system** with grudges, gratitude, fear, trust (RDR2-inspired)
- **6 psychological needs** (Security, Power, Loyalty, Recognition, Stability, Ideology)
- **NPC-to-NPC relationships** - independent from player
- **3 decision systems**: Standard, Goal-Driven, Memory-Influenced
- **Ambient activities** for "living world" feel
- **Espionage system** with foreign agents

---

## Turn Processing Flow (GameEngine.endTurnUpdates)

All systems are now wired and processing each turn:

```
1. applyStatDrift()                    ✅ Natural equilibrium
2. simulateNPCActions()                ✅ Rival/patron behavior
3. applyRandomEvents()                 ✅ Small fluctuations
4. simulateWorldEvents()               ✅ WorldSimulationService
5. processNPCBehaviorSystem()          ✅ CharacterAgency, Memory, Ambient
6. processPoliticalAI()                ✅ PoliticalAIService
7. processPositionOffers()             ✅ PositionOfferService
8. processInternationalDynamics()      ✅ InternationalEventService
9. processRegionalDynamics()           ✅ RegionSecessionService
10. processEconomicSystem()            ✅ EconomyService
11. processIntelligenceLeaks()         ✅ IntelligenceLeakService
12. recordAllStatHistory()             ✅ Sparkline data
```

---

## Wiring Verification

### GameEngine.swift (lines 566-657)

#### International Dynamics (lines 607-629)
```swift
private func processInternationalDynamics(game: Game) {
    gameLogger.info("Processing international dynamics for turn \(game.turnNumber)")

    // Process relationship drift, treaty effects, espionage, world tension
    InternationalEventService.shared.processTurn(game: game)

    // Generate and queue international crisis events
    let crisisEvents = InternationalEventService.shared.generateInternationalEvents(for: game)
    for crisis in crisisEvents {
        if let country = game.foreignCountries.first(where: { $0.countryId == crisis.countryId }) {
            let event = InternationalEventService.shared.createDynamicEvent(
                from: crisis, country: country, currentTurn: game.turnNumber
            )
            game.queueDynamicEvent(event)
        }
    }
}
```

#### Regional Dynamics (lines 633-657)
```swift
private func processRegionalDynamics(game: Game) {
    gameLogger.info("Processing regional dynamics for turn \(game.turnNumber)")

    // Process regional stability, secession progress, cascade effects
    RegionSecessionService.shared.processTurn(game: game)

    // Generate and queue regional crisis events
    let regionalEvents = RegionSecessionService.shared.generateRegionalEvents(for: game)
    for crisis in regionalEvents {
        if let region = game.regions.first(where: { $0.regionId == crisis.regionId }) {
            let event = RegionSecessionService.shared.createDynamicEvent(
                from: crisis, region: region, currentTurn: game.turnNumber
            )
            game.queueDynamicEvent(event)
        }
    }
}
```

#### Economic System (lines 594-604)
```swift
private func processEconomicSystem(game: Game) {
    gameLogger.info("Processing macro economy for turn \(game.turnNumber)")

    // Process PSRA's macro economy (GDP, inflation, unemployment)
    EconomyService.shared.processEconomy(game: game)

    // Process foreign country economies
    EconomyService.shared.processForeignEconomies(game: game)
}
```

---

## Service Methods Verified

| Service | Method | Location |
|---------|--------|----------|
| `InternationalEventService` | `processTurn(game:)` | Line 22 |
| `InternationalEventService` | `generateInternationalEvents(for:)` | Line 544 |
| `InternationalEventService` | `createDynamicEvent(from:country:currentTurn:)` | Exists |
| `RegionSecessionService` | `processTurn(game:)` | Line 22 |
| `RegionSecessionService` | `generateRegionalEvents(for:)` | Line 327 |
| `RegionSecessionService` | `createDynamicEvent(from:region:currentTurn:)` | Exists |
| `EconomyService` | `processEconomy(game:)` | Exists |
| `EconomyService` | `processForeignEconomies(game:)` | Exists |

---

## Verification Checklist - All Met ✅

- ✅ Foreign country relationships drift based on bloc
- ✅ Active treaties provide bonuses (trade +2 treasury/turn)
- ✅ Espionage activities can discover spies
- ✅ World tension updates based on hostile countries
- ✅ Region stability scores update based on conditions
- ✅ Governor effects apply (competence, loyalty)
- ✅ Secession progress advances for at-risk regions
- ✅ Cascade effects spread instability
- ✅ GDP changes affect regional loyalty
- ✅ International crises generate DynamicEvents
- ✅ Regional crises generate DynamicEvents

---

## Success Criteria - All Met ✅

1. ✅ **Living World**: All systems update every turn without player intervention
2. ✅ **Cross-Effects**: Economic collapse triggers regional unrest
3. ✅ **NPC Autonomy**: Foreign countries drift, regions evolve, NPCs scheme
4. ✅ **Event Generation**: Crises from all systems create meaningful choices
5. ✅ **Coherent Narrative**: Economic, international, and regional events interconnect

---

## Future Enhancements (Optional)

These cross-system effects could be expanded:

| Economic State | Effect On |
|----------------|-----------|
| GDP decline >10% | Regional loyalty -5, Stability -3 |
| Inflation >30% | Popular support -5/turn, Strike chance +20% |
| Unemployment >15% | Regional unrest +10, Labor strike events |
| Trade balance <-20 | Treasury drain, Foreign dependency |

| International State | Effect On |
|---------------------|-----------|
| Trade treaty | Treasury +2/turn, GDP +1% |
| Embargo | GDP -5%, Sector disruption |
| World tension >80 | Military spending +10, Consumer goods -5 |
