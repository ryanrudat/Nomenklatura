# NOMENKLATURA - Complete UI/UX Design Review
## For Google Stitch Implementation

**App Name:** Nomenklatura
**Platform:** iOS (SwiftUI + SwiftData)
**Genre:** Political Simulation / Strategy
**Setting:** Cold War-era Soviet-style bureaucracy
**Design Language:** 1950s Soviet Brutalist meets vintage typewriter aesthetic

---

## TABLE OF CONTENTS

1. [Design Philosophy](#1-design-philosophy)
2. [Color Palette & Typography](#2-color-palette--typography)
3. [App Flow Overview](#3-app-flow-overview)
4. [Pre-Game Screens](#4-pre-game-screens)
5. [Main Navigation Structure](#5-main-navigation-structure)
6. [Tab 1: The Desk](#6-tab-1-the-desk)
7. [Tab 2: The Ledger](#7-tab-2-the-ledger)
8. [Tab 3: The Dossier](#8-tab-3-the-dossier)
9. [Tab 4: The Codex](#9-tab-4-the-codex)
10. [Tab 5: The Ladder](#10-tab-5-the-ladder)
11. [Modal Portals](#11-modal-portals)
12. [Game Phase Screens](#12-game-phase-screens)
13. [Overlay & Toast System](#13-overlay--toast-system)
14. [Component Library](#14-component-library)
15. [Navigation Patterns](#15-navigation-patterns)
16. [Accessibility Notes](#16-accessibility-notes)

---

## 1. DESIGN PHILOSOPHY

### Theme: "The Weight of Power"
The app immerses players in the paranoid, bureaucratic world of a fictional Soviet-style regime. Every UI element reinforces:

- **Paper & Documents:** Parchment textures, typewriter fonts, official stamps
- **Surveillance State:** Dossiers, classified stamps, redacted text
- **Institutional Power:** Organizational charts, committees, official seals
- **Vintage Technology:** Rotary phones, teletype styling, Cold War maps

### Visual Metaphors
| Element | Real-World Analog |
|---------|------------------|
| Main screen | Bureaucrat's desk with stacked documents |
| Stats dashboard | Official state ledger/report |
| Character profiles | KGB-style intelligence dossiers |
| Encyclopedia | Party propaganda handbook |
| Career view | Organizational hierarchy chart |

### Interaction Philosophy
- **Deliberate Pacing:** Animations feel weighty, like turning pages
- **Immersive Reading:** Long-form narrative text encourages engagement
- **Consequential Choices:** Clear visual feedback for decisions
- **Information Density:** Dense but organized information architecture

---

## 2. COLOR PALETTE & TYPOGRAPHY

### Primary Colors (ColdWarTheme)
```
Soviet Red:        #8B0000 (Primary accent, danger states)
Accent Gold:       #C9A227 (Success, promotions, highlights)
Parchment:         #F4F1E8 (Primary background)
Parchment Dark:    #E8E4D9 (Secondary background)
Ink Black:         #1A1A1A (Primary text)
Ink Gray:          #4A4A4A (Secondary text)
Ink Light:         #7A7A7A (Tertiary text)
Border Tan:        #D4C5A9 (Borders, dividers)
Stamp Red:         #CC0000 (Stamps, badges)
Bronze Gold:       #B8860B (Decorative accents)
```

### Stat Colors
```
Stat High:         #2E7D32 (Green - values 70+)
Stat Medium:       #F9A825 (Amber - values 40-69)
Stat Low:          #C62828 (Red - values below 40)
```

### Typography Hierarchy
| Style | Usage | Font |
|-------|-------|------|
| Header | Section titles | System Bold, 18pt, tracking: 2 |
| Label | Field labels | System SemiBold, 12pt, tracking: 1 |
| Body | Main content | System Regular, 14pt |
| Body Small | Secondary content | System Regular, 12pt |
| Stat | Numerical values | System Bold, 16pt |
| Tag | Badges, chips | System Bold, 10pt, tracking: 0.5 |
| Typewriter | Narrative text | American Typewriter, 14pt |

---

## 3. APP FLOW OVERVIEW

```
┌─────────────────────────────────────────────────────────────────┐
│                        APP LAUNCH                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CAMPAIGN SELECT                               │
│  • Choose historical era/campaign                                │
│  • Currently: "The Apparatus" (Cold War)                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    FACTION SELECT                                │
│  • Choose player background/faction                              │
│  • 5 factions with unique bonuses/penalties                     │
│  • Swipeable card carousel                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      GAME VIEW                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    CONTENT AREA                          │   │
│  │  (Switches based on selected tab)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  DESK │ LEDGER │ DOSSIER │ CODEX │ LADDER │ ⚙️ MENU     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
            ┌─────────────────┴─────────────────┐
            ▼                                   ▼
┌───────────────────────┐           ┌───────────────────────┐
│     GAME OVER         │           │  MODAL SHEETS         │
│  • Victory/Defeat     │           │  • World Portal       │
│  • Career summary     │           │  • Congress Portal    │
│  • Restart options    │           │  • Bureau Portals     │
└───────────────────────┘           │  • Game Menu          │
                                    └───────────────────────┘
```

---

## 4. PRE-GAME SCREENS

### 4.1 Campaign Select Screen
**File:** `CampaignSelectView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    WELCOME, COMRADE                              │
│                    ─────────────────                             │
│                     The Party Awaits                             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ╔══════════════════════════════════════════════════╗   │   │
│  │  ║  ★ THE PRESIDIUM ★                               ║   │   │
│  │  ║  ───────────────────                             ║   │   │
│  │  ║  Cold War Era (1953-1991)                        ║   │   │
│  │  ║                                                   ║   │   │
│  │  ║  Navigate the treacherous politics of a          ║   │   │
│  │  ║  Soviet-style regime. Rise through the ranks     ║   │   │
│  │  ║  or fall victim to the purges.                   ║   │   │
│  │  ║                                                   ║   │   │
│  │  ║  Starting Role: Junior Politburo Member          ║   │   │
│  │  ║                                                   ║   │   │
│  │  ║              [ AVAILABLE ]                        ║   │   │
│  │  ╚══════════════════════════════════════════════════╝   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │           Future campaigns: Coming Soon...               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Design Notes:**
- Dark parchment background with subtle texture
- Campaign cards have gold border accent
- "AVAILABLE" badge in green, "COMING SOON" badge grayed
- Tap anywhere on card to select

---

### 4.2 Faction Select Screen
**File:** `FactionSelectView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│  ← Back                                                          │
│                                                                  │
│                 CHOOSE YOUR BACKGROUND                           │
│                 ──────────────────────                           │
│           Your past shapes your future in the Party             │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                                                          │   │
│  │              ★ YOUTH LEAGUE GRADUATE ★                   │   │
│  │              ─────────────────────────                   │   │
│  │                  True Believer                           │   │
│  │                                                          │   │
│  │  You rose through the Komsomol, demonstrating            │   │
│  │  ideological purity and organizational skill...          │   │
│  │                                                          │   │
│  │  ─────────────────────────────────────────────────────  │   │
│  │                                                          │   │
│  │  BENEFITS                                                │   │
│  │  ✓ +10 Starting Standing                                 │   │
│  │  ✓ +15 Elite Loyalty                                     │   │
│  │  ✓ Bonus: "Ideological Purity" (+5 to policy support)   │   │
│  │                                                          │   │
│  │  DRAWBACKS                                               │   │
│  │  ✗ -10 Network (limited connections)                     │   │
│  │  ✗ Vulnerability: Naivety (rivals exploit trust)        │   │
│  │                                                          │   │
│  │           ┌─────────────────────────┐                    │   │
│  │           │   CHOOSE THIS PATH      │                    │   │
│  │           └─────────────────────────┘                    │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│                        ● ○ ○ ○ ○                                │
│                         1 of 5                                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Design Notes:**
- Swipeable horizontal carousel (PageTabViewStyle)
- Each card shows faction name, subtitle, description
- Benefits in green with checkmarks
- Drawbacks in red with X marks
- Special ability highlighted in gold box
- Page indicator dots at bottom
- "Choose This Path" button triggers game creation

**Available Factions:**
1. Youth League Graduate (True Believer)
2. Regional Administrator (Provincial Climber)
3. Military-Political Officer (Uniformed Apparatchik)
4. Technical Specialist (Expert Administrator)
5. Old Guard Protégé (Connected Inheritor)

---

## 5. MAIN NAVIGATION STRUCTURE

### Bottom Navigation Bar
**File:** `BottomNavBar.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   ═══        ═══        ═══                    ═══              │
│   📄         📊         👤         📖         🪜        ⚙️      │
│  DESK      LEDGER    DOSSIER     CODEX      LADDER     MENU    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Design Notes:**
- Floating pill-shaped container with rounded corners (15pt)
- 20pt horizontal padding from screen edges
- 25pt bottom padding (safe area)
- Selected tab: Gold text + red accent bar above icon
- Unselected tabs: Gray (#666666)
- Notification dots appear on tabs with unread content
- Menu button (gear) opens settings sheet

### Tab Definitions
| Tab | Icon | Purpose |
|-----|------|---------|
| Desk | doc.text.fill | Main gameplay - decisions & documents |
| Ledger | chart.bar.fill | National statistics dashboard |
| Dossier | person.fill | Character profiles & intelligence |
| Codex | book.fill | Game lore encyclopedia |
| Ladder | arrow.up.right.circle.fill | Career progression & org chart |

---

## 6. TAB 1: THE DESK

**File:** `DeskView.swift` (1900+ lines)

### Overview
The Desk is the primary gameplay interface where players make decisions that shape the fate of their career and nation. It simulates a bureaucrat's desk covered with documents, reports, and newspapers.

### Screen Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  STATUS BAR                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Turn 15 │ March 1957 │ [🌍 World] [🏛️ Congress] [→ End] │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  PLAYER ID CARD                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  CLEARANCE: LEVEL 3          Position: Deputy Minister   │   │
│  │  Bureau: Economic Planning   Track: GOSPLAN              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  PERSONAL STATS ROW                                              │
│  ┌──────────┬──────────┬──────────┬──────────┐                 │
│  │ Standing │ Network  │  Patron  │  Rival   │                 │
│  │    47    │    31    │    62    │    55    │                 │
│  └──────────┴──────────┴──────────┴──────────┘                 │
│                                                                  │
│  ════════════════════════════════════════════════════════════   │
│                                                                  │
│  SCENARIO CARD / NEWSPAPER                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ╔═══════════════════════════════════════════════════╗  │   │
│  │  ║           CRISIS IN THE AGRICULTURAL              ║  │   │
│  │  ║                   SECTOR                          ║  │   │
│  │  ║  ─────────────────────────────────────────────── ║  │   │
│  │  ║  Reports from the collective farms indicate...   ║  │   │
│  │  ║                                                   ║  │   │
│  │  ║  The Standing Committee requires your input...   ║  │   │
│  │  ║                                                   ║  │   │
│  │  ║              [ TAP TO READ FULL BRIEFING ]       ║  │   │
│  │  ╚═══════════════════════════════════════════════════╝  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  DOCUMENT QUEUE                                                  │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐                  │
│  │ 📄 Urgent  │ │ 📋 Report  │ │ 📝 Request │                  │
│  │ Directive  │ │ Analysis   │ │ Approval   │                  │
│  └────────────┘ └────────────┘ └────────────┘                  │
│                                                                  │
│  ┌─────┐                                              ┌─────┐   │
│  │ 📌  │  MEMO TRAY (Slide-out panel)                │ 📰  │   │
│  └─────┘                                              └─────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Sub-Components

#### 6.1 Status Bar (StitchStatusBar)
```
┌─────────────────────────────────────────────────────────────────┐
│  TURN 15  │  MARCH 1957  │  [🌍]  [🏛️]  │  [END TURN →]        │
└─────────────────────────────────────────────────────────────────┘
```
- Turn number with Soviet star icon
- In-game date (month/year)
- World button → Opens World Portal sheet
- Congress button → Opens Congress Portal sheet
- End Turn button → Shows confirmation sheet

#### 6.2 Player ID Card
```
┌─────────────────────────────────────────────────────────────────┐
│  ┌─────────────────┐                                            │
│  │ CLEARANCE       │   DEPUTY MINISTER                          │
│  │ ═══════════════ │   Economic Planning Bureau                 │
│  │    LEVEL 3      │   ────────────────────────                 │
│  │ [TOP SECRET]    │   Track: GOSPLAN                           │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```
- Clearance level badge (1-8 based on position)
- Current position title
- Bureau affiliation
- Career track indicator

#### 6.3 Personal Stats Widget Row
```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│   STANDING   │   NETWORK    │    FAVOR     │    THREAT    │
│      47      │      31      │      62      │      55      │
│   [tap→]     │   [tap→]     │   [tap→]     │   [tap→]     │
└──────────────┴──────────────┴──────────────┴──────────────┘
```
- Each stat is tappable:
  - Standing → Navigate to Ladder tab
  - Network → Navigate to Dossier tab
  - Patron Favor → Open Patron character sheet
  - Rival Threat → Open Rival character sheet

#### 6.4 Scenario Card
**Displayed during Briefing/Decision phases**
```
╔═══════════════════════════════════════════════════════════════╗
║  ★ CLASSIFIED ★                              [URGENT]         ║
║  ═══════════════════════════════════════════════════════════  ║
║                                                                ║
║              THE GRAIN QUOTA CRISIS                            ║
║              ─────────────────────                             ║
║                                                                ║
║  Comrade Minister,                                             ║
║                                                                ║
║  Reports from Oblast 7 indicate severe shortfalls in          ║
║  grain production. The regional administrator claims          ║
║  sabotage by counter-revolutionary elements, but our          ║
║  sources suggest mismanagement...                             ║
║                                                                ║
║  The Standing Committee awaits your recommendation.           ║
║                                                                ║
║                    [ TAP TO EXPAND ]                          ║
╚═══════════════════════════════════════════════════════════════╝
```

#### 6.5 Newspaper Preview
**Alternative to scenario card (randomly displayed)**
```
┌─────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════╗ │
│  ║  ☆ PRAVDA ☆                           12 MARCH 1957       ║ │
│  ║  ═══════════════════════════════════════════════════════  ║ │
│  ║                                                            ║ │
│  ║       RECORD HARVESTS EXCEED FIVE-YEAR PLAN               ║ │
│  ║  ──────────────────────────────────────────────────────   ║ │
│  ║  Workers celebrate unprecedented agricultural success...  ║ │
│  ║                                                            ║ │
│  ║  ┌──────────────────┐  Industrial output rises for        ║ │
│  ║  │ [PHOTO: Workers] │  third consecutive quarter as       ║ │
│  ║  │                  │  new factories come online...       ║ │
│  ║  └──────────────────┘                                     ║ │
│  ╚═══════════════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────────────────┘
```

#### 6.6 Document Queue
```
┌────────────────┐  ┌────────────────┐  ┌────────────────┐
│ ⚠️ URGENT      │  │ 📋 REPORT      │  │ 📝 REQUEST     │
│ ────────────── │  │ ────────────── │  │ ────────────── │
│ Directive from │  │ Intelligence   │  │ Budget         │
│ the Chairman   │  │ Assessment     │  │ Approval       │
│                │  │                │  │                │
│ [UNREAD]       │  │ [PENDING]      │  │ [PENDING]      │
└────────────────┘  └────────────────┘  └────────────────┘
```
- Horizontal scroll if many documents
- Tap to open DocumentDetailView
- Unread badge on new documents
- Document types: Directive, Report, Request, Intelligence

#### 6.7 Memo Tray (Floating Action)
```
┌─────┐
│ 📌  │ ← Floating button (bottom-left)
└─────┘
   │
   ▼ (Opens slide-out panel)
┌─────────────────────────────────────────┐
│  SAVED NOTES                             │
│  ════════════════════════════════════   │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ Turn 12: Met with Deputy Volkov    │ │
│  │ Seems trustworthy, but watch him   │ │
│  └────────────────────────────────────┘ │
│                                          │
│  ┌────────────────────────────────────┐ │
│  │ Turn 8: Kozlov made threats        │ │
│  │ Consider pre-emptive action        │ │
│  └────────────────────────────────────┘ │
│                                          │
│        [ VIEW ALL IN DOSSIER ]          │
└─────────────────────────────────────────┘
```

---

## 7. TAB 2: THE LEDGER

**File:** `LedgerView.swift`

### Overview
The Ledger provides a comprehensive dashboard of national statistics, displaying the health of the state across multiple categories.

### Screen Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE LEDGER                                │
│                    State of the Nation                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [🌍 World]                              [🏛️ Congress]   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  STATE STATUS BANNER                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ⚠️ STATE STATUS: UNCERTAIN                               │   │
│  │    Tensions simmer beneath the surface                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ════════════════════════════════════════════════════════════   │
│                                                                  │
│  🛡️ STABILITY                                                   │
│     Order & Control                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🏛️ Political Stability    ████████████░░░░░  67  ℹ️    │   │
│  │  👥 Popular Support         ██████░░░░░░░░░░░  35  ℹ️    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ⭐ POWER CENTERS                                                │
│     Institutional Loyalty                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🛡️ Military Loyalty       █████████████░░░░  72  ℹ️    │   │
│  │  👔 Elite Loyalty          ██████████░░░░░░░  58  ℹ️    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  📦 RESOURCES                                                    │
│     Economic Foundation                                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  💰 Treasury               ███████░░░░░░░░░░  45  ℹ️    │   │
│  │  ⚙️ Industrial Output      ██████████░░░░░░░  55  ℹ️    │   │
│  │  🌾 Food Supply            █████░░░░░░░░░░░░  32  ℹ️    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  🌍 EXTERNAL                                                     │
│     Foreign Relations                                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🏳️ International Standing ██████████░░░░░░░  52  ℹ️    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  QUICK ACCESS CARDS                                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔒 SECURITY SERVICES          [STABLE]           →     │   │
│  │     Investigations: 2 │ Detentions: 1 │ Trials: 0       │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  📊 GOSPLAN                    [STABLE]           →     │   │
│  │     Industrial: 55% │ Food: 32% │ Projects: 2/3         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Components

#### 7.1 State Status Banner
Shows overall health calculated from critical stats:
- **STABLE** (green): Average ≥65, no critical stats
- **UNCERTAIN** (amber): Average 45-64
- **DANGER** (orange): 1 critical stat or average <45
- **CRISIS** (red): 2+ critical stats below 30

#### 7.2 Stat Category Cards
Each category groups related statistics:
- Colored accent bar on left edge
- Category icon and title
- "CRITICAL" badge if any stat <30
- Each stat row shows:
  - Icon
  - Label
  - Progress bar (color-coded)
  - Value
  - Info button (ℹ️) → Opens StatInfoSheet

#### 7.3 Stat Info Sheet (Modal)
**Triggered by tapping ℹ️ on any stat**
```
┌─────────────────────────────────────────────────────────────────┐
│                                                      [Done]     │
│                                                                  │
│  💰 TREASURY                                                     │
│     Current: 45                                                  │
│                                                                  │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  WHAT IT MEANS                                                   │
│  State financial resources. Money buys loyalty, funds           │
│  projects, and maintains the military.                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ⚠️ DANGER ZONE                                           │   │
│  │ Below 30: Unable to fund military operations, bribe      │   │
│  │ officials, or maintain infrastructure.                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ ✅ STRONG POSITION                                       │   │
│  │ Above 70: Can launch major initiatives, buy off rivals,  │   │
│  │ and weather any crisis with resources to spare.          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 💡 HOW TO IMPROVE                                        │   │
│  │ ★ Avoid expensive foreign adventures                     │   │
│  │ ★ Keep industrial output high                            │   │
│  │ ★ Extract resources from satellite states                │   │
│  │ ★ Cut waste in the bureaucracy                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### 7.4 Quick Access Cards
Tappable cards linking to Portal sheets:
- Security Services → SecurityPortalView
- Gosplan (Economic) → EconomicPortalView
- Political Work (Military) → MilitaryPortalView
- Party Apparatus → PartyPortalView
- State Ministry → StateMinistryPortalView

Each shows:
- Bureau name and icon
- Status rating badge
- Key metrics summary
- Chevron indicator (→)
- "YOUR BUREAU" badge if player's track

---

## 8. TAB 3: THE DOSSIER

**File:** `DossierView.swift` (1400+ lines)

### Overview
The Dossier is the intelligence hub containing character profiles, faction relationships, and the player's decision journal.

### Screen Layout with Sub-Tabs

```
┌─────────────────────────────────────────────────────────────────┐
│                       THE DOSSIER                                │
│                    Intelligence Files                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [🌍 World]                              [🏛️ Congress]   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────┬──────────┬──────────┬──────────┐                 │
│  │ PROFILE  │ FIGURES  │ FACTIONS │ JOURNAL  │                 │
│  └──────────┴──────────┴──────────┴──────────┘                 │
│                                                                  │
│  [Content changes based on selected sub-tab]                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.1 Profile Sub-Tab
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  YOUR DOSSIER                                                    │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Name: [Player Character Name]                           │   │
│  │  Position: Deputy Minister, Economic Planning            │   │
│  │  Faction: Youth League                                   │   │
│  │  Years in Service: 4                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  PERSONAL STATISTICS                                             │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Standing        ████████████░░░░░  67                   │   │
│  │  Patron Favor    ██████████████░░░  78                   │   │
│  │  Rival Threat    ████████░░░░░░░░░  45                   │   │
│  │  Network         ██████░░░░░░░░░░░  35                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  REPUTATION                                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Competent   ████████████░░░░░  65                       │   │
│  │  Loyal       ██████████████░░░  72                       │   │
│  │  Cunning     ████████░░░░░░░░░  42                       │   │
│  │  Ruthless    ██████░░░░░░░░░░░  33                       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.2 Figures Sub-Tab
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  FILTER: [All ▼] [Key Figures] [Allies] [Others]               │
│                                                                  │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  LIVING CHARACTERS                                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ★ PATRON ★                                              │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │  VIKTOR PETROV                                      │ │   │
│  │  │  General Secretary                                  │ │   │
│  │  │  ──────────────────────────────────────────────    │ │   │
│  │  │  Faction: Old Guard        Disposition: Friendly   │ │   │
│  │  │                                                     │ │   │
│  │  │  [🔍 Investigate] [📢 Denounce] [🤝 Cultivate]     │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ⚠️ RIVAL ⚠️                                             │   │
│  │  ┌────────────────────────────────────────────────────┐ │   │
│  │  │  DMITRI KOZLOV                                      │ │   │
│  │  │  Deputy Minister, Security                          │ │   │
│  │  │  ──────────────────────────────────────────────    │ │   │
│  │  │  Faction: Princelings      Disposition: Hostile    │ │   │
│  │  │  Threat Level: ████████░░  HIGH                    │ │   │
│  │  │                                                     │ │   │
│  │  │  [🔍 Investigate] [📢 Denounce] [🤝 Cultivate]     │ │   │
│  │  └────────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  [Additional character cards...]                                │
│                                                                  │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  FALLEN COMRADES                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  💀 Sergei Volkov - Purged (Turn 8)                     │   │
│  │  💀 Anna Mikhailova - Executed (Turn 12)                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

#### Character Card Actions
Each character card has action buttons:
- **Investigate** → Opens investigation options sheet
- **Denounce** → Opens denouncement options sheet
- **Cultivate** → Opens relationship building options sheet
- **Tap card** → Opens detailed character sheet

### 8.3 Factions Sub-Tab
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  FACTION STANDINGS                                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ★ YOUTH LEAGUE ★ (Your Faction)                        │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │  Power: ████████░░░░░░░  45%                            │   │
│  │  Your Standing: █████████████░░  72                     │   │
│  │                                                          │   │
│  │  Ideology: Reform-minded party loyalists who rose       │   │
│  │  through the Komsomol youth organization.               │   │
│  │                                                          │   │
│  │  Relations:                                              │   │
│  │    Old Guard: Neutral    Reformists: Friendly           │   │
│  │    Princelings: Hostile  Regional: Neutral              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  OLD GUARD                                               │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │  Power: ██████████████░  68%                            │   │
│  │  Your Standing: ████████░░░░░░░  42                     │   │
│  │  [Expand for details...]                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  [Additional faction cards...]                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 8.4 Journal Sub-Tab
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  SAVED NOTES                              [3 unread]            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Turn 15: The agricultural crisis deepens...             │   │
│  │  ────────────────────────────────────────────────────── │   │
│  │  Met with Comrade Volkov regarding the grain quotas.    │   │
│  │  He seemed nervous. Worth watching.                      │   │
│  │                                      [Character: Volkov] │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  YOUR RECORD                                                     │
│  Decision history organized by career phase                     │
│                                                                  │
│  RECENT DECISIONS (Turns 13-15)                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  [15] Grain Quota Crisis                                 │   │
│  │       Chose: Blame regional administrators               │   │
│  │       Result: Stability +5, Popular Support -3           │   │
│  │       Archetype: RUTHLESS                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  EARLIER DECISIONS (Turns 6-12)                                 │
│  [Collapsed section - tap to expand]                            │
│                                                                  │
│  FIRST DAYS (Turns 1-5)                                         │
│  [Collapsed section - tap to expand]                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. TAB 4: THE CODEX

**File:** `CodexView.swift`

### Overview
The Codex is an in-game encyclopedia containing lore, terminology, and background information about the game's fictional Soviet-style state.

### Screen Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                        THE CODEX                                 │
│                  Encyclopedia of the PSRA                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [🌍 World]                              [🏛️ Congress]   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐     │
│  │INSTITUTE │ POLITICS │ HISTORY  │ MILITARY │ INTERNAT │     │
│  └──────────┴──────────┴──────────┴──────────┴──────────┘     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ 🔍 Search entries...                                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ENTRIES                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  📖 THE POLITBURO                                        │   │
│  │     The supreme decision-making body of the Party...    │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  📖 THE STANDING COMMITTEE                               │   │
│  │     The inner circle of the Politburo, consisting of... │   │
│  └─────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  📖 THE NOMENKLATURA SYSTEM                              │   │
│  │     The system of patronage appointments that...        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  [Additional entries...]                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Category Tabs
| Category | Content |
|----------|---------|
| Institutions | Politburo, Standing Committee, Congress, Bureaus |
| Politics | Factions, ideology, patronage system |
| History | Timeline of the PSRA, key events |
| Military | Red Army structure, political officers |
| International | Foreign relations, satellite states, enemies |

### Entry Detail (Modal Sheet)
```
┌─────────────────────────────────────────────────────────────────┐
│                                                      [Done]     │
│                                                                  │
│  THE POLITBURO                                                   │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  The Politburo (Political Bureau) is the supreme decision-      │
│  making body of the Communist Party and, by extension, the      │
│  entire state. Officially elected by the Central Committee,     │
│  in practice its membership is determined by factional         │
│  maneuvering and the favor of the General Secretary.            │
│                                                                  │
│  COMPOSITION                                                     │
│  The Politburo typically consists of 15-25 full members and    │
│  5-10 candidate (non-voting) members. Full membership grants   │
│  voting rights on all major policy decisions.                   │
│                                                                  │
│  POWERS                                                          │
│  • Approve all major policy decisions                           │
│  • Appoint ministers and regional administrators                │
│  • Direct the security apparatus                                │
│  • Control foreign policy                                       │
│                                                                  │
│  RELATED ENTRIES                                                 │
│  [Standing Committee] [Central Committee] [General Secretary]   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 10. TAB 5: THE LADDER

**File:** `OrgChartView.swift`

### Overview
The Ladder displays the organizational hierarchy of the Party, showing all positions from entry-level to General Secretary, with the player's current position and career path highlighted.

### Screen Layout

```
┌─────────────────────────────────────────────────────────────────┐
│                     PARTY HIERARCHY                              │
│                  Organizational Structure                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ [🌍 World]                              [🏛️ Congress]   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  YOUR PROGRESS                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Standing: 67          Deputy Minister                   │   │
│  │  █████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░        │   │
│  │  Track: Economic Planning (GOSPLAN)                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ════════════════════════════════════════════════════════════   │
│                                                                  │
│                    ┌─────────────────┐                          │
│                    │ ★ GEN. SECY ★  │                          │
│                    │  Viktor Petrov  │                          │
│                    └────────┬────────┘                          │
│                             │                                    │
│                    ┌────────┴────────┐                          │
│                    │ DEPUTY GEN.SECY │                          │
│                    │  [Vacant]       │                          │
│                    └────────┬────────┘                          │
│                             │                                    │
│        ┌────────────────────┼────────────────────┐              │
│        │                    │                    │              │
│  ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐       │
│  │  SECURITY │        │  ECONOMIC │        │  MILITARY │       │
│  │  MINISTER │        │  MINISTER │        │  MINISTER │       │
│  └─────┬─────┘        └─────┬─────┘        └─────┬─────┘       │
│        │                    │                    │              │
│  ┌─────┴─────┐        ┌─────┴─────┐        ┌─────┴─────┐       │
│  │  DEPUTY   │        │ ★ DEPUTY ★│        │  DEPUTY   │       │
│  │  MINISTER │        │ (YOU)     │        │  MINISTER │       │
│  └─────┬─────┘        └─────┬─────┘        └─────┬─────┘       │
│        │                    │                    │              │
│        └────────────────────┼────────────────────┘              │
│                             │                                    │
│                    ┌────────┴────────┐                          │
│                    │ JUNIOR POLITBURO│                          │
│                    │    MEMBER       │                          │
│                    └────────┬────────┘                          │
│                             │                                    │
│                    ┌────────┴────────┐                          │
│                    │ PARTY OFFICIAL  │                          │
│                    │   (Entry)       │                          │
│                    └─────────────────┘                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Position Node Design
```
┌─────────────────────────────────────┐
│  ★ MINISTER OF ECONOMIC PLANNING ★ │  ← Gold border if player position
│  ─────────────────────────────────  │
│  Holder: Comrade Ivanov             │
│  Faction: Old Guard                 │
│                                     │
│  [TAP FOR DETAILS]                  │
└─────────────────────────────────────┘
```

### Visual Indicators
- **Gold border/highlight**: Player's current position
- **Dotted line**: Player's potential path
- **Star icon**: Key positions (Minister+)
- **Vacant badge**: Empty positions
- **Faction badge**: Current holder's faction

### Position Detail Sheet (Modal)
```
┌─────────────────────────────────────────────────────────────────┐
│                                                      [Done]     │
│                                                                  │
│  MINISTER OF ECONOMIC PLANNING                                   │
│  ═══════════════════════════════════════════════════════════    │
│                                                                  │
│  Bureau: GOSPLAN (Economic Planning)                            │
│  Level: 6 (Senior Leadership)                                   │
│                                                                  │
│  CURRENT HOLDER                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Comrade Ivanov                                          │   │
│  │  Faction: Old Guard                                      │   │
│  │  Tenure: 8 years                                         │   │
│  │  Disposition toward you: Neutral                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  REQUIREMENTS FOR PROMOTION                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ✓ Standing: 60+ (You: 67)                               │   │
│  │  ✓ Patron Favor: 50+ (You: 78)                           │   │
│  │  ✗ Network: 50+ (You: 35)                                │   │
│  │  ✓ Track: Economic Planning (Match!)                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  POWERS & RESPONSIBILITIES                                       │
│  • Direct the Five-Year Plan implementation                     │
│  • Allocate industrial resources                                │
│  • Approve major construction projects                          │
│  • Report to the Standing Committee                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 11. MODAL PORTALS

These are full-screen modal sheets accessible from multiple locations (header buttons, quick access cards).

### 11.1 World Portal
**File:** `WorldTabView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│  [← Close]              WORLD AFFAIRS                            │
│                                                                  │
│  ┌────────────┬────────────┬────────────┐                       │
│  │    MAP     │  EMBASSY   │  ECONOMICS │                       │
│  └────────────┴────────────┴────────────┘                       │
│                                                                  │
│  [SUB-TAB CONTENT]                                              │
│                                                                  │
│  MAP: Interactive SpriteKit map of world regions                │
│  EMBASSY: Diplomatic relations with foreign nations             │
│  ECONOMICS: Global economic dashboard                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.2 Congress Portal
**File:** `CongressTabView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│  [← Close]           PEOPLE'S CONGRESS                           │
│                                                                  │
│  ┌────────────┬────────────┬────────────┐                       │
│  │  POLICIES  │ COMMITTEE  │  SESSIONS  │                       │
│  └────────────┴────────────┴────────────┘                       │
│                                                                  │
│  POLICIES: Current policy slots by institution                  │
│  COMMITTEE: Standing Committee members & agenda                 │
│  SESSIONS: Legislative session history                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 11.3 Bureau Portals (5 variants)
**Files:** `SecurityPortalView.swift`, `EconomicPortalView.swift`, `MilitaryPortalView.swift`, `PartyPortalView.swift`, `StateMinistryPortalView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│  [← Close]        [BUREAU NAME] BUREAU                           │
│                                                                  │
│  ┌────────────┬────────────┬────────────┐                       │
│  │  OVERVIEW  │ [PROJECTS] │  ACTIONS   │                       │
│  └────────────┴────────────┴────────────┘                       │
│                                                                  │
│  OVERVIEW: Bureau statistics and status                         │
│  PROJECTS/CAMPAIGNS: Active operations                          │
│  ACTIONS: Available bureau-specific actions (if authorized)     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ⚠️ AUTHORITY REQUIRED                                   │   │
│  │  You must hold a position in this bureau to take        │   │
│  │  direct actions. Current track: Economic Planning       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 12. GAME PHASE SCREENS

### 12.1 Outcome View
**File:** `OutcomeView.swift`

Displayed after a decision is made, showing consequences.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                         OUTCOME                                  │
│                    ═══════════════                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    THE AFTERMATH                         │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │                                                          │   │
│  │  Your decision to blame the regional administrators     │   │
│  │  has sent shockwaves through the Party. Several         │   │
│  │  officials have been dismissed, and fear now grips      │   │
│  │  the agricultural sector...                             │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  CHARACTER REACTIONS                                     │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │                                                          │   │
│  │  Viktor Petrov (Patron):                                 │   │
│  │  "You handled that well. The Party needed someone       │   │
│  │  to take responsibility for the failures."              │   │
│  │  [Favor +5]                                              │   │
│  │                                                          │   │
│  │  Dmitri Kozlov (Rival):                                  │   │
│  │  "Ruthless, but effective. I'll remember this."         │   │
│  │  [Threat +3]                                             │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  CONSEQUENCES                                            │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │                                                          │   │
│  │  Stability      ████████████████░░  +5                  │   │
│  │  Popular Support ██████████░░░░░░░  -3                  │   │
│  │  Elite Loyalty   █████████████░░░░  +2                  │   │
│  │                                                          │   │
│  │  Mood: The apparatus is relieved but watchful.          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│              ┌─────────────────────────┐                        │
│              │       CONTINUE          │                        │
│              └─────────────────────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 12.2 Personal Action View
**File:** `PersonalActionView.swift`

Displayed after the outcome, allowing player to take personal actions.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                       YOUR MOVE                                  │
│                  Personal Action Phase                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ACTION POINTS: ●● (2 remaining)                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  THE ATMOSPHERE                                          │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │  The corridors of power feel tense tonight. Your       │   │
│  │  recent actions have drawn attention, for better       │   │
│  │  or worse. Now is the time to consolidate...           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ════════════════════════════════════════════════════════════   │
│  POLITICAL MANEUVERING                                           │
│  ════════════════════════════════════════════════════════════   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🤝 CULTIVATE RELATIONSHIP                              │   │
│  │  Build trust with a colleague                           │   │
│  │  Cost: 1 AP │ Effect: +5-15 Disposition                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔍 GATHER INTELLIGENCE                                  │   │
│  │  Investigate a character's activities                   │   │
│  │  Cost: 1 AP │ Effect: Reveal secrets                    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  🔒 LOCKED: DENOUNCE RIVAL                               │   │
│  │  Requires: Network 40+ (You: 35)                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  [Additional action categories...]                              │
│                                                                  │
│              ┌─────────────────────────┐                        │
│              │    COMPLETE TURN        │                        │
│              └─────────────────────────┘                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 12.3 Game Over View
**File:** `GameOverView.swift`

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ╔═══════════════════════════════════════════════════════════╗ │
│  ║                                                            ║ │
│  ║                      GAME OVER                             ║ │
│  ║                   ════════════════                         ║ │
│  ║                                                            ║ │
│  ║                   Your rule has ended                      ║ │
│  ║                                                            ║ │
│  ╚═══════════════════════════════════════════════════════════╝ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   THE FINAL CHAPTER                      │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │                                                          │   │
│  │  The purge came swiftly. Your rival Kozlov had been     │   │
│  │  building his case for months, and when the moment      │   │
│  │  came, even your patron could not save you.             │   │
│  │                                                          │   │
│  │  You were denounced at the plenum as an "enemy of       │   │
│  │  the people" and a "wrecker." The verdict was           │   │
│  │  predetermined. History will forget your name.          │   │
│  │                                                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  FINAL STATISTICS                                        │   │
│  │  ──────────────────────────────────────────────────────│   │
│  │  Turns Survived: 23                                      │   │
│  │  Highest Position: Deputy Minister                       │   │
│  │  Decisions Made: 45                                      │   │
│  │  Characters Purged: 3                                    │   │
│  │  Ending: Purged by Rival                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│         ┌─────────────────┐  ┌─────────────────┐               │
│         │  NEW CAMPAIGN   │  │   MAIN MENU     │               │
│         └─────────────────┘  └─────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Victory variant** uses gold accents instead of red, "VICTORY" header.

---

## 13. OVERLAY & TOAST SYSTEM

### 13.1 Promotion Notification
```
┌─────────────────────────────────────────────────────────────────┐
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░  ╔══════════════════════════════════════════════╗  ░░░░  │
│  ░░░░  ║  ════════════════════════════════════════    ║  ░░░░  │
│  ░░░░  ║                     ★                        ║  ░░░░  │
│  ░░░░  ║               PROMOTION                      ║  ░░░░  │
│  ░░░░  ║         ═══════════════════                  ║  ░░░░  │
│  ░░░░  ║                                              ║  ░░░░  │
│  ░░░░  ║     You have been appointed to the          ║  ░░░░  │
│  ░░░░  ║     position of:                            ║  ░░░░  │
│  ░░░░  ║                                              ║  ░░░░  │
│  ░░░░  ║        MINISTER OF ECONOMIC PLANNING        ║  ░░░░  │
│  ░░░░  ║                                              ║  ░░░░  │
│  ░░░░  ║     The Party trusts you with this          ║  ░░░░  │
│  ░░░░  ║     great responsibility.                   ║  ░░░░  │
│  ░░░░  ║                                              ║  ░░░░  │
│  ░░░░  ║        ┌────────────────────────┐           ║  ░░░░  │
│  ░░░░  ║        │   ACCEPT POSITION      │           ║  ░░░░  │
│  ░░░░  ║        └────────────────────────┘           ║  ░░░░  │
│  ░░░░  ║  ════════════════════════════════════════    ║  ░░░░  │
│  ░░░░  ╚══════════════════════════════════════════════╝  ░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  │
└─────────────────────────────────────────────────────────────────┘
```
- Dimmed background (tap to dismiss)
- Gold accent bars top and bottom
- Star icon
- Animated entrance (scale + opacity)

### 13.2 Journal Toast
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                                       ┌────────────────────┐    │
│                                       │ 📝 Note Saved      │    │
│                                       │ View in Dossier    │    │
│                                       └────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```
- Appears top-right
- Auto-dismisses after 3 seconds
- Tappable to navigate to Dossier

### 13.3 End Turn Confirmation Sheet
```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│                    END TURN CONFIRMATION                         │
│                    ═════════════════════                         │
│                                                                  │
│  ⚠️ You have pending documents that require decisions:          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  • Directive from Chairman (URGENT)                      │   │
│  │  • Budget Request from Ministry                          │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Ending the turn will auto-resolve these with default          │
│  outcomes, which may not be favorable.                          │
│                                                                  │
│         ┌─────────────────┐  ┌─────────────────┐               │
│         │     CANCEL      │  │   END TURN      │               │
│         └─────────────────┘  └─────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 14. COMPONENT LIBRARY

### Reusable Components

| Component | File | Usage |
|-----------|------|-------|
| ScreenHeader | `ScreenHeader.swift` | Consistent header across all tabs |
| BottomNavBar | `BottomNavBar.swift` | Main navigation |
| StatBarView | `StatBarView.swift` | Stat display with progress bar |
| StatInfoSheet | `StatInfoSheet.swift` | Stat explanation modal |
| FactionBadge | `FactionBadge.swift` | Faction indicator chip |
| StanceTagView | `StanceTagView.swift` | Opinion/disposition tags |
| EffectTagView | `EffectTagView.swift` | Stat change indicators |
| TappableName | `TappableName.swift` | Character name links |
| ClickableNarrativeText | `ClickableNarrativeText.swift` | Text with character links |
| ActionConfirmationSheet | `ActionConfirmationSheet.swift` | Action confirmation modal |
| MemoTrayView | `MemoTrayView.swift` | Note-taking sidebar |
| JournalToastView | `JournalToastView.swift` | Save notification toast |

### Design Tokens (StitchDesignComponents)

```swift
// Spacing
let spacingXS: CGFloat = 4
let spacingSM: CGFloat = 8
let spacingMD: CGFloat = 12
let spacingLG: CGFloat = 16
let spacingXL: CGFloat = 20
let spacingXXL: CGFloat = 32

// Corner Radius
let radiusSM: CGFloat = 4
let radiusMD: CGFloat = 8
let radiusLG: CGFloat = 12
let radiusXL: CGFloat = 16

// Shadows
let shadowSM = Shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
let shadowMD = Shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
let shadowLG = Shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
```

---

## 15. NAVIGATION PATTERNS

### Pattern 1: Tab Navigation
```
User taps tab → selectedTab state updates → View body recomputes → New tab content appears
```

### Pattern 2: Sheet Presentation
```
User taps trigger → @State var showSheet = true → .sheet(isPresented:) → Modal appears
User dismisses → showSheet = false → Modal disappears
```

### Pattern 3: Item-Based Sheet
```
User taps item → @State var selectedItem = item → .sheet(item:) → Modal with item data
User dismisses → selectedItem = nil → Modal disappears
```

### Pattern 4: Callback Forwarding
```
Parent (GameView) passes closure → Child stores closure → Child calls closure → Parent state updates
Example: onWorldTap: { showingWorldSheet = true }
```

### Pattern 5: Phase-Based Content
```
game.currentPhase changes → DeskView body recomputes → Different view rendered
Briefing → Scenario/Documents
Outcome → OutcomeView
PersonalAction → PersonalActionView
```

---

## 16. ACCESSIBILITY NOTES

### VoiceOver Support
- All buttons have accessibility labels
- Stat values read as "Stability: 67 out of 100"
- Document states announced ("Unread directive")
- Character relationships described

### Dynamic Type
- All text uses system fonts with dynamic scaling
- Minimum touch target: 44x44 points
- Scrollable content in all views

### Color Contrast
- All text meets WCAG AA standards
- Critical information not conveyed by color alone
- Status badges have text labels + icons

### Reduced Motion
- Animations respect `reduceMotion` preference
- Alternative static transitions available

---

## APPENDIX: FILE INVENTORY

### Views Directory Structure
```
Views/
├── CampaignSelect/
│   ├── CampaignSelectView.swift
│   └── FactionSelectView.swift
├── Codex/
│   └── CodexView.swift
├── Components/
│   ├── ActionConfirmationSheet.swift
│   ├── BottomNavBar.swift
│   ├── ClassifiedOperationCard.swift
│   ├── ClickableNarrativeText.swift
│   ├── EffectTagView.swift
│   ├── FactionBadge.swift
│   ├── FiftiesStyleComponents.swift
│   ├── ImmersiveComponents.swift
│   ├── JournalToastView.swift
│   ├── MemoTrayView.swift
│   ├── NoTrackAuthorityView.swift
│   ├── ScreenHeader.swift
│   ├── SnapshotLoadingView.swift
│   ├── StanceTagView.swift
│   ├── StatBarView.swift
│   ├── StatInfoSheet.swift
│   ├── StitchDesignComponents.swift
│   ├── TappableName.swift
│   └── TurnTransitionView.swift
├── Congress/
│   ├── CongressTabView.swift
│   ├── LawCard.swift
│   ├── LawProposalSheet.swift
│   ├── LawsView.swift
│   ├── PolicySlotsView.swift
│   ├── SessionsView.swift
│   └── StandingCommitteeView.swift
├── Desk/
│   ├── BriefingPaperView.swift
│   ├── DeskView.swift
│   ├── DocumentCardView.swift
│   ├── DocumentDetailView.swift
│   ├── DynamicEventView.swift
│   ├── MultiNewspaperView.swift
│   ├── NarrativeEventView.swift
│   ├── NewspaperView.swift
│   ├── OptionCardView.swift
│   ├── SamizdatView.swift
│   └── StitchDeskComponents.swift
├── Dossier/
│   ├── CharacterCardView.swift
│   ├── DossierView.swift
│   └── FallenCharactersView.swift
├── Economics/
│   ├── EconomicDashboardView.swift
│   └── EconomicPortalView.swift
├── Embassy/
│   └── EmbassyPortalView.swift
├── GameOver/
│   └── GameOverView.swift
├── Ladder/
│   ├── BureauCard.swift
│   ├── BureauGridView.swift
│   ├── CareerBranchView.swift
│   ├── OrgChartConnector.swift
│   ├── OrgChartNode.swift
│   ├── OrgChartView.swift
│   └── PositionHistoryView.swift
├── Ledger/
│   └── LedgerView.swift
├── Military/
│   └── MilitaryPortalView.swift
├── Ministry/
│   └── StateMinistryPortalView.swift
├── Outcome/
│   ├── OutcomeView.swift
│   └── ReactionsSection.swift
├── Party/
│   └── PartyPortalView.swift
├── PersonalAction/
│   ├── ActionCardView.swift
│   └── PersonalActionView.swift
├── Policy/
│   └── PolicyView.swift
├── Security/
│   └── SecurityPortalView.swift
└── World/
    ├── SpriteKitMapScene.swift
    ├── SpriteKitMapView.swift
    ├── WorldMapView.swift
    └── WorldTabView.swift
```

---

**Document Version:** 1.0
**Last Updated:** December 2024
**Author:** Claude Code Assistant
**For:** Google Stitch UI/UX Implementation
