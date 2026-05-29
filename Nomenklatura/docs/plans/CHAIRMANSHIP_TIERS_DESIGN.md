# Chairmanship Tiers — Design Doc

Status: **DRAFT for review** (no code yet). Authored 2026-05-27.
Owner: design. Implementation gated on sign-off.

> **Naming guardrail:** No real-world figure names appear anywhere in this doc, in the game, or in the design. §2 abstracts external party-state history into eras and archetypes only (source URLs preserved for traceability).

## 1. One-line premise

The player's chairmanship sits on a **weak → strong spectrum** — from a figurehead the Standing Committee runs, to a personalist ruler who controls every lever — and the player's **standing on that spectrum is recomputed every turn from how well they govern and consolidate**. It is **bidirectional**: you climb by consolidating, and you fall by failing.

This is not a new stat. It is a **named, visible identity layer** on top of the existing `Game.powerConsolidationScore` (0–100), which already starts the player weak (score = 20) and already gates parts of the game — but only at scattered, invisible thresholds. The tier system unifies those thresholds into five legible bands with real consequences.

## 2. Research basis (one-party-state leadership history)

The cleanest real-world model for a weak→strong gradient is a party-state with a formal doctrine of it: the **"core leader"** — the one with *"ultimate decision-making authority… to pound the gavel and have the final say."* In the canonical case, only four of six successive top leaders ever earned that status; the two who didn't are exactly the weak ones.

| Era | Power level | Why | Mechanic it teaches us |
|---|---|---|---|
| Late-'70s anointed heir | Figurehead | Named successor, no independent base, propped by the deceased predecessor's doctrine, ousted in ~2 yrs | A compromise successor the committee tolerates, not obeys |
| 2000s consensus leader | First among equals | "Never a strongman"; "nine dragons taming the water" (committee members each rule a fief); constrained by a rival-packed committee | Collective leadership: must build coalitions; bureaus are autonomous |
| '90s faction-builder | Consolidating core | Built a faction, packed institutions, held the military commission | Authority earned by filling posts with clients |
| Late-'70s–'80s reformer | Paramount **without the title** | Ruled via seniority + military + reform agenda; abolished the supreme formal title and built term limits / retirement norms to prevent one-man rule | Informal dominance; and the institutional *cage* a system builds against strongmen |
| Founding chairman | Total / cult | Abandoned collective leadership; cult of personality; overrode the party | Personalist rule — and its catastrophic instability |
| Current-era core | Total / recentralized | "Core" status earned; abolished presidential term limits; heads 10+ leading groups; purges rivals via anti-corruption | Dismantling the cage: repeal limits, enshrine doctrine, purge under legal cover |

**Core design principle drawn from this:** strong is *not simply better.* Collective leadership was built precisely because earlier personalism had been catastrophic. So the spectrum is a **control-vs-stability tradeoff**, not a straight power ladder. Each tier must have a downside, or the system is just "number go up."

Sources (external history, for traceability — visible link text avoids real names; URLs unavoidably contain them): [paramount-leader concept](https://en.wikipedia.org/wiki/Paramount_leader) · [the "core leader" doctrine](https://en.wikipedia.org/wiki/Leadership_core) · [collective leadership](https://en.wikipedia.org/wiki/Collective_leadership) · [return to personalist rule (Journal of Democracy)](https://www.journalofdemocracy.org/articles/china-in-xis-new-era-the-return-to-personalistic-rule/) · [the anointed-heir interregnum (Wikipedia)](https://en.wikipedia.org/wiki/Two_Whatevers) · [the figurehead successor (Wikipedia)](https://en.wikipedia.org/wiki/Hua_Guofeng) · [the consensus-era leader (Wikipedia)](https://en.wikipedia.org/wiki/Hu_Jintao) · [abolition of presidential term limits (NPR)](https://www.npr.org/sections/thetwo-way/2018/03/11/592694991/china-removes-presidential-term-limits-enabling-xi-jinping-to-rule-indefinitely).

## 3. What already exists in the code (build on, don't reinvent)

- **`Game.powerConsolidationScore: Int` (0–100)** — `Models/Game.swift:151`. Inits to **20** ("new GS… far from absolute", `:418`). Recomputed every turn via `calculatePowerConsolidation()` (`:1906`, called `:1959`).
- **What drives the score** (`calculatePowerConsolidation()`): `standing/4` (≤25) + `eliteLoyalty/5` (≤20) + `network/5` (≤20) + position bonus (GS +20) + `lawsModifiedCount*3` + `patronFavor>70` (+5) + `militaryLoyalty>70` (+10) − `coalitionStrength/4` (opposition). → These map almost 1:1 onto the CCP factors: loyal appointments, **military backing** (the military-commission lever), legislative dominance, minus **factional opposition**.
- **Already-wired consumers (scattered thresholds the tiers will unify):**
  - Personal actions gated by `minPowerConsolidation` — `Models/PersonalAction.swift:90,186`.
  - Law proposals gated by `powerRequired` — `Views/Congress/LawProposalSheet.swift`, `LawCard.swift`.
  - SC vote weight: player gets +1 weight when score > 60 — `Services/StandingCommitteeMeetingService.swift:254` (and `:169` "influence weighted by powerConsolidationScore").
  - Rival opposition: ambitious GS rival opposes if score < 70 — `Services/PoliticalAIService.swift:437`.
  - NPC behavior keyed to `GameplayConstants.Power.dominantThreshold` — `Services/NPCDecisionProtocol.swift:216`.
  - Endgame effect at ≥ 90 — `Services/GameEngine.swift:992`; endgame scoring — `Views/GameOver/GameOverView.swift:161`.
  - Visual meter already exists: **`PowerConsolidationMeter`** (`Views/Congress/PowerConsolidationMeter.swift`, color band at 80) — the natural home for a tier badge.
- **Decree power** — `Game.decreeChargesRemaining` (init 3, `Models/Game.swift:260`), consumed by `requiresDecreeCharge` options (`CrisisResponseOption`, `SecurityPortalView`), shown via `DecreeChargesCounter`. Regenerates ~1 / 50 turns.
- **Committee engine** — `StandingCommitteeMeetingService` (vote pass/weight). **Bureau autonomy** — `BureauChiefAgencyService` (retaliates on neglect). **Purge tools** — `ProsecutionPipelineService`, `ShowTrialService`. **Succession** — `SuccessionRelationship`, `GameContinuation`, the "Appoint Successor" personal action.
- **Dormant richer model** — `PowerConsolidation` struct (`Models/HistoricalMechanics.swift:16`) already enumerates `loyalAppointments / successfulPurges / failedPolicies / economicCrises / factionalOpposition`. Currently unused; could feed tier nuance later.

**Takeaway:** the load-bearing number and most hooks already exist. The tier system is mostly *unification + surfacing + a few new levers*, not new infrastructure.

## 4. The five tiers

Fictional, game-internal names (per the locked design rule — no real figure names in-game). Score bands are starting proposals (tuning knob §7).

| # | Tier (working name) | Archetype | Score band | Standing Committee | Decree max | Bureaus | Signature unlock | Built-in downside |
|---|---|---|---|---|---|---|---|---|
| 1 | **Compromise Chairman** | Anointed figurehead | 0–24 *(start)* | Overrides you; can force its own votes through | 0 | Slow-walk / ignore directives | — | A designated rival is positioned to replace you |
| 2 | **First Among Equals** | Consensus broker | 25–44 | Blocks ~half unless you've built the coalition | 1 (costly) | Bargain; retaliate if neglected | Horse-trading; place clients in posts | Every big move needs a deal |
| 3 | **Paramount Chairman** | Paramount reformer | 45–64 | Usually defers; rarely overrides | 2 | Generally obey | "Pound the gavel"; pack institutions; pass laws freely | Norms still bind you (term limits, retirement) |
| 4 | **The Core** | Faction-building core | 65–84 | Rubber-stamps | 3–4 | Obey | Enshrine your doctrine; control the succession timeline | Rising **elite resentment** accrues |
| 5 | **Supreme Chairman** | Personalist strongman | 85–100 | Ceremonial | unlimited / free | Total | Cult of personality; **repeal term limits**; rule indefinitely | High-variance: overreach → coup/collapse risk scales with resentment |

Climbing one tier should *feel* like a regime change, not a +1. Dropping a tier (after a failed purge, lost confidence vote, economic crisis) should sting.

## 5. How the tier is computed

- **Primary input:** `powerConsolidationScore`, mapped to the bands above. Already recomputed each turn — no new pipeline.
- **Hysteresis (anti-flicker):** require the score to cross a band edge by a margin (e.g. ±3) *and* hold for 1–2 turns before the tier officially changes, so a one-turn wobble at 64↔65 doesn't thrash the UI or mechanics. Tier changes should be **announced** (a notification / journal entry: "The Committee now treats you as first among equals").
- **Optional secondary gate (recommend for tiers 4–5):** reaching The Core / Supreme should also require an *act*, not just a number — e.g. you cannot become **Supreme Chairman** on score alone; you must also have spent a **consolidation move** to abolish term limits (mirrors Xi 2018). This keeps the top tier a deliberate choice with a fingerprint, not a passive drift.

## 6. Consolidation moves (the levers to climb — and the content)

These are the high-cost, high-drama actions that let a player *push* up the ladder, each modeled on real history and each carrying backlash. They reuse existing systems:

| Move | Archetype | Effect | Cost / backlash | Reuses |
|---|---|---|---|---|
| **Pack the Committee** | Faction-builder | Replace a committee seat with a loyalist → raises score, lowers opposition | Spends network/standing; angers the displaced faction | Appointments, `SuccessionRelationship` |
| **Anti-corruption purge** | Strongman | Remove a rival "legally" → score up, fear up | Failed purge is catastrophic; raises elite resentment | `ProsecutionPipelineService`, `ShowTrialService` |
| **Enshrine your Doctrine** | Doctrinal cult | One-time: your ideology into the constitution → loyalty + permanent score floor | Huge cost; locks you ideologically | Law/policy system |
| **Abolish term limits** | Norm-breaker | Gate to Supreme Chairman; removes the succession clock | Massive elite-resentment spike; international standing hit | Law system; succession |
| **Refuse / name a successor** | Succession control | Naming one buys elite calm but creates a rival-in-waiting; refusing raises personal power but spikes instability | Either way a tradeoff | `SuccessionRelationship`, Appoint Successor action |

These moves are where most *new content* lives; the tiers themselves are mostly re-gating existing systems.

## 7. The control-vs-stability tradeoff (the balance heart)

To honor the research, **higher tiers are more powerful but less stable**:

- Introduce an **Elite Resentment** pressure (could reuse/extend existing elite-loyalty + a new "resentment" accumulator) that *grows* at tiers 4–5 and with each purge / norm-abolition.
- At **Supreme Chairman**, the player can do almost anything — but accumulated resentment feeds coup/collapse checks (hooks into existing loss conditions). This is the strongman's lesson: total power, total fragility.
- Conversely, **First Among Equals / Paramount** are *stable* but slow — you trade ceiling for safety. A cautious player can win the long game from tier 3 without ever risking tier 5.
- Net: there is no single "best" tier. The player chooses a governing style and lives with its risk profile.

## 8. UI surfacing

- Promote the existing **`PowerConsolidationMeter`** into a **Chairmanship badge**: current tier name + the meter, with "▲ N to **The Core**" and a tap-through to "what the next tier unlocks / what you'd lose."
- Tier-change **announcement** (notification + journal entry).
- **Feed the AI prompt the tier, not the raw number.** Currently `ScenarioPromptBuilder` injects `powerConsolidationScore/100`; replace with the tier descriptor (e.g. "The player is a **Compromise Chairman** — the Committee can override them") so generated briefings match the player's actual standing. (Also a small prompt-quality win.)
- Optional: a one-screen "Chairmanship" panel showing the ladder, your position, and available consolidation moves.

## 9. Implementation sketch (for the later build — not now)

Phased so each step is shippable and testable:

1. **Model + compute.** `ChairmanshipTier` enum (5 cases, band thresholds in `GameplayConstants.Power`), `Game.chairmanshipTier` computed from `powerConsolidationScore` with hysteresis. Pure read layer — zero behavior change yet.
2. **Surface it.** Tier badge in `PowerConsolidationMeter`; tier-change notification; feed tier into `ScenarioPromptBuilder`. Now it's *visible* with no balance risk.
3. **Wire one system (vertical slice).** Make `StandingCommitteeMeetingService` read the tier (pass/override probability per tier), replacing the lone `>60` check. Playtest the weak-vs-strong feel.
4. **Wire the rest.** Decree max from tier; `BureauChiefAgencyService` obedience from tier; personal-action/law gating reads tier instead of ad-hoc thresholds.
5. **Consolidation moves + tradeoff.** Add the §6 moves and the §7 Elite Resentment / instability loop. This is the largest content step.

Each step builds green and is independently playtestable.

## 10. Open questions / tuning knobs

- Band thresholds (§4) — pure guess right now; needs playtest.
- Pure-score tiers vs. score + secondary gates (§5) for tiers 4–5. Recommend gates for 4–5.
- Final fictional tier names (§4 are placeholders) — confirm tone (descriptive vs. more in-world PSR flavor).
- Does Elite Resentment reuse `eliteLoyalty` or warrant a new accumulator?
- How fast should tiers shift — should a single catastrophe (lost coup, famine) be able to drop you two tiers?
- Scope of the AI-content pass: should each tier get distinct briefing *tone* (a Compromise Chairman gets condescending memos; a Supreme Chairman gets sycophantic ones)?

## 11. Guardrails

- **No real-world figure names in-game.** Real party-state history is research inspiration only; the world stays the fictional PSR. Tier names and flavor are game-internal.
- The tier layer must not silently change current balance until §3-step is deliberately enabled — ship the read/surface layers first, gate the behavior changes behind playtests.
