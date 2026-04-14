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

### Phase 6: Economics & World Systems
- [x] Economic engine overhaul (policy slot ID fix, rebalancing)
- [x] Economy-politics feedback loop (treasury/food/unemployment → loyalty/support/stability)
- [x] Dynamic world economy (trade proposals, sanctions, foreign reform events)
- [x] Economy tab (Gosplan) replacing Ladder tab
- [x] EconomicHubView unified dashboard (Command Center, Sectors, Trade, Regions, Budget, Planning)
- [x] Sector specialization (32 focus options across 8 sectors)
- [x] Trade negotiation (tariff levels, embargoes, compatibility-weighted bonuses)
- [x] Budget allocation (per-sector, must sum to 100%)
- [x] Foreign loan system (3 sources, max 3 concurrent, default consequences)
- [x] Seeded economic data at game start (varied sectors, sparkline history, starter trade agreements)
- [x] Track affinity wiring (directives +3, personal actions +2)
- [x] Security bureau character selection overlay
- [x] General Secretary display fix, rebellion rate-limiting, redacted content improvements

### Phase 7: Testing & Release
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
│   ├── Directive/             # Bureau directive phase
│   ├── PersonalAction/        # Personal action phase
│   ├── Dossier/               # Character info
│   ├── Embassy/               # Foreign affairs portal
│   ├── Economy/               # Gosplan economics hub
│   │   ├── EconomicHubView.swift          # Unified dashboard (932 lines)
│   │   ├── SectorDetailView.swift         # Sector focus specialization
│   │   ├── TradeManagementView.swift       # Trade partners & agreements
│   │   ├── TradeProposalSheet.swift        # Interactive deal builder
│   │   ├── RegionalEconomicsManagementView.swift  # 7 regions
│   │   ├── BudgetManagementView.swift      # Income/expense/allocation
│   │   └── LoanProposalSheet.swift         # Foreign loan applications
│   ├── Ledger/                # Statistics & bureau operations
│   ├── Ladder/                # Career progress (removed from nav, still exists)
│   └── Components/            # Shared UI components
├── Utilities/
│   ├── Theme.swift            # Visual styling
│   ├── NarrativeGenerator.swift # Atmospheric text
│   ├── UrgencyAdvisor.swift   # Crisis detection & action triage
│   └── RevolutionaryCalendar.swift # In-game calendar
└── Config/
    └── BalanceConfig.swift    # Tunable game constants
```

---

## Bureau Directive System

The player (General Secretary) issues orders to 6 government bureaus during the Directive Phase:

| Bureau | Actions | Target Types | Service |
|--------|---------|-------------|---------|
| Security Services | 30 | Character (overlay picker), faction | SecurityActionService |
| Economic Planning | 31 | Sector, region | EconomicActionService |
| Party Apparatus | 25 | Organ, cadre | PartyActionService |
| Military-Political | 24 | Officer, unit, theater | MilitaryActionService |
| Foreign Affairs | 24 | Country, bloc, treaty | DiplomaticActionService |
| State Ministry | 22 | Ministry, official, policy | StateMinistryActionService |

### Personal Actions (51 total across 8 categories)
- Build Network, Undermine Rivals, Purge Enemies, Control Information
- Secure Position, Consolidate Power, Cultivate Successor, Make Your Play

### Crisis Triage (UrgencyAdvisor)
Detects 9 crisis conditions and flags relevant actions/bureaus with visual urgency markers.

---

## Economics System (Gosplan Tab)

The economy is a fully interactive system accessible via the "Gosplan" bottom nav tab (replaced the Ladder tab on 2026-04-14).

### EconomicHubView Dashboard
6 sections with position-gated tabs and propaganda/reality data toggle:
- **Command Center** — GDP, growth, treasury, trade balance overview
- **Sectors** — 8 sectors with tappable detail views for specialization
- **Trade** — Active agreements, partner cards with compatibility scores
- **Regions** — 7 region cards with invest/boost-quota actions
- **Budget** — Income/expense breakdown, per-sector priority allocation
- **Planning** — Five-Year Plan progress, economic reports

### Sector Specialization
32 production focus options (4 per sector). Each focus has trade-offs:
- Heavy Industry: tanks, tractors, steel, machinery
- Agriculture: collectives, private plots, export crops, mixed
- Effects wired into `EconomyService.processSectorPerformance()`

### Trade System
- Per-country compatibility scores via `economicCompatibility()` on ForeignCountry
- TariffLevel enum: none/low/standard/high/prohibitive with volume/revenue multipliers
- Per-country embargo system
- TradeProposalSheet: interactive deal builder with type, favorability slider, duration, projected effects

### Budget & Loans
- Per-sector budget allocation (8 sectors, must sum to 100%), stored in `game.budgetPriorities`
- ForeignLoan struct: principal, interest rate, duration, per-turn payments
- 3 loan sources: socialist bloc (2-3%), Western (4-5%), international (5-8%)
- Max 3 concurrent loans; default consequences (relationship damage, stability penalty)
- Loan payments processed in `processEconomy()` each turn

### Economy-Politics Feedback (applyEconomicPoliticalFeedback)
| Condition | Effect |
|-----------|--------|
| Low treasury | Elite loyalty drop |
| Food shortage | Popular support drop |
| High unemployment | Stability drop |
| High inflation | Stability drop |
| Strong economy | Support boost |

### Turn Processing Order
`processEconomicSystem()` runs BEFORE `processPoliticalAI()` so economic conditions feed into AI political decisions.

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
