# Nomenklatura

A political simulation game set in the People's Socialist Republic of America (PSRA)—an alternate history where America became a socialist state after the Second American Civil War (1936-1940). Players climb from low-ranking official to supreme power through cunning, compromise, and calculated ruthlessness.

## Overview

**Platform:** iOS / macOS (SwiftUI + SwiftData)
**Genre:** Political simulation / Interactive fiction
**Theme:** Alternate history Cold War bureaucratic intrigue
**Setting:** Early 1950s America, ~10-15 years after the Revolution

Players navigate the treacherous world of Party politics in socialist America, managing relationships with patrons, rivals, and subordinates while balancing state resources and their own ambitions. The old Federal Government fled to Cuba; Japan holds Hawaii; and the capitalist world watches with hostile intent.

---

## Development Phases

### Phase 1: Core Foundation
- [x] Project setup with SwiftUI and SwiftData
- [x] Basic data models (Game, GameCharacter, GameFaction)
- [x] Theme system with Soviet-inspired design
- [x] Navigation structure

### Phase 2: Game Mechanics
- [x] Scenario system with options and outcomes
- [x] Stat tracking (state metrics + personal metrics)
- [x] Turn-based gameplay loop
- [x] Decision consequence system

### Phase 3: User Interface
- [x] Desk view (main gameplay screen)
- [x] Briefing paper presentation
- [x] Option cards with stance indicators
- [x] Outcome display with stat effects
- [x] Dossier view (character relationships)
- [x] Ledger view (state statistics)
- [x] Ladder view (career progression)

### Phase 4: Content & Polish
- [x] Fallback scenario library (20+ scenarios)
- [x] Four scenario categories: Crisis, Routine, Opportunity, Character
- [x] Game over conditions and endings
- [x] Campaign configuration system

### Phase 5: AI Integration
- [x] Claude API client (ClaudeClient.swift)
- [x] Context-aware prompt building (ScenarioPromptBuilder.swift)
- [x] Response validation pipeline (ScenarioValidator.swift)
- [x] AI scenario generator with caching (AIScenarioGenerator.swift)
- [x] Hybrid fallback system (AI with local backup)
- [x] Circuit breaker pattern for resilience
- [x] Secure API key configuration

### Phase 6: Testing & Release
- [ ] End-to-end AI scenario testing
- [ ] Performance optimization
- [ ] Game balance tuning
- [ ] App Store preparation

---

## Architecture

```
Nomenklatura/
├── Config/
│   ├── Secrets.swift          # API key (git-ignored)
│   └── Secrets.example        # Template for API setup
├── Models/
│   ├── Game.swift             # Core game state
│   ├── Scenario.swift         # Decision scenarios
│   ├── GameCharacter.swift    # NPCs
│   └── GameFaction.swift      # Political factions
├── Services/
│   ├── GameEngine.swift       # Game logic
│   ├── ScenarioManager.swift  # Scenario selection
│   └── AI/
│       ├── ClaudeClient.swift           # API client
│       ├── AIScenarioGenerator.swift    # Orchestrator
│       ├── ScenarioPromptBuilder.swift  # Prompt construction
│       └── ScenarioValidator.swift      # Response parsing
├── Views/
│   ├── Desk/                  # Main gameplay
│   ├── Dossier/               # Character info
│   ├── Ledger/                # Statistics
│   └── Ladder/                # Career progress
└── Theme/
    └── Theme.swift            # Visual styling
```

---

## Game Mechanics

### State Metrics
- **Treasury** - Financial resources
- **Food Supply** - Agricultural output
- **Industrial Output** - Manufacturing capacity
- **Military Loyalty** - Armed forces support
- **Popular Support** - Public approval
- **Elite Loyalty** - Party establishment support
- **Stability** - Overall regime stability
- **International Standing** - Foreign relations

### Personal Metrics
- **Standing** - Political position
- **Network** - Connections and allies
- **Patron Favor** - Mentor relationship
- **Rival Threat** - Enemy danger level

### Reputation Traits
- Ruthless / Compassionate
- Cunning / Direct
- Loyal / Independent
- Competent / Lucky

---

## AI Integration

### How It Works
1. Game state is analyzed to build context-aware prompts
2. Claude generates unique scenarios matching the current situation
3. Responses are validated for proper JSON structure
4. Valid scenarios are cached for 5 minutes
5. Failed AI calls fall back to local scenario library

### Circuit Breaker
- After 3 consecutive API failures, AI is disabled for 60 seconds
- Prevents cascading failures and API spam
- Auto-resets and retries after timeout

### Prompt Context
AI receives:
- Current position and turn number
- All state metrics with trend indicators
- Character relationships and dynamics
- Recent decision history
- Available archetypes for options

---

## Setup

1. Copy `Config/Secrets.example` to `Config/Secrets.swift`
2. Add your Anthropic API key to `Secrets.swift`
3. Build and run in Xcode

**Note:** `Secrets.swift` is git-ignored to protect your API key.

---

## Credits

Developed with Claude AI assistance.

Model: claude-sonnet-4-20250514
