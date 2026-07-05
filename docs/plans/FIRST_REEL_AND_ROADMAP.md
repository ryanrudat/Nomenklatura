# First Reel Design + Standing Roadmap (2026-07-04)

Status: DESIGN ONLY — approved for documentation, not yet built.
Context: market research (2026-07-03) concluded the viable iOS model is
free-first-act + single unlock IAP ($9.99–14.99), the model Suzerain
converged on. Under that model **turns 1–10/15 are the product demo** —
what every prospective buyer plays before deciding to pay.

## 1. The First Reel — turns 1–12 as the demo that sells the game

### The problem
The trial window is currently the *calmest* stretch of the game — exactly
backwards:
- Onboarding window suppresses high-chaos scenario categories for ~8 turns
- Conspiracies cannot form until after turn 8
- First Five-Year-Plan verdict lands ~turn 12
- Rival threat builds slowly; first dramatic rival move typically post-trial
- No tutorial of any kind
So a trial player never sees a plot, purge, coup whisper, or crisis — the
systems that would make them pay all live on the paid side of the fence.

### The design (build items 1–5 as ONE increment; they are also the onboarding)
1. **Scripted contained near-crisis, turn 2–3.** A leak or minor plot the
   security chief catches; resolved by a real player choice. A taste of the
   purge machinery with training-wheel stakes.
2. **The rival moves by turn 4–5.** Turn 1 now promises a named antagonist
   "counting allies" — pay that off inside the trial with an actual
   RivalMove + counter decision, not at turn 15.
3. **One beat from every pillar inside the trial**: first SC vote (turn 4,
   exists), one advisor-guided economy moment (sector shortfall or credit
   dial), one Codex thread, and the player's own decision appearing in the
   morning paper (press wiring already does this).
4. **Paywall lands on a cliffhanger, not a fade-out** — ideally the turn the
   conspiracy whisper arrives: "Your network reports voices in a locked
   room. Names withheld — for now." Pay to learn who.
5. **Onboarding rides the advisor layer** (built 2026-07-04, default ON):
   Sasha's first-turn walkthrough of the phase loop + one-time contextual
   callouts (AP, directive points, decree charges, consolidation tier) the
   first time each surface appears; "your first Committee session" framing
   at turn 4.
6. **Paywall plumbing (StoreKit, turn gate, restore) — defer to pre-launch
   pass.** Trivial to add once the arc exists; pointless before.

## 2. Standing suggestions (agreed gaps, not yet built)

Ranked by recommended order:
1. ~~Turn-pipeline interruption safety~~ ✅ DONE 2026-07-04 (stage counter +
   sentinel + launch recovery; see GameEngine "Turn-pipeline interruption
   safety" section).
2. **Telemetry + crash reporting before any release**: crash reporter +
   ~10 anonymous funnel events (turn reached, tabs opened, run ended and
   why). One day of work; determines whether every post-launch decision is
   informed or blind.
3. **Accessibility pass**: all fonts are hardcoded 9–14pt — Dynamic Type
   does nothing; VoiceOver untested (redacted text, stamps). Strategic, not
   just ethical: the iOS revenue path runs through Apple editorial
   featuring, which favors accessible apps. Text-heavy games are the
   best-case genre for VoiceOver.
4. **Design the losing experience**: 6+ live loss conditions but defeat is
   a game-over screen + wipe. Add a "History's Judgment" epilogue (AI writes
   the verdict on your era; what your successor undoes), fast restart with
   meaningful variation. The genre sells on retellable defeats.
5. **Save growth policy**: events accumulate ~10+/turn forever; variables
   dictionary keeps gaining per-region keys. Prune/archive events below
   importance 5 after ~20 turns. Trivial now, painful after players have
   80-turn campaigns.
6. **Economy layout restructure (Option A, approved direction)**: 4 tabs —
   PLAN (sectors/focuses/supply chain/FYP) · PROVINCES (returns+audits,
   pilot zone, governors) · BANK (credit, treasury, indicators, forecast) ·
   WORKS (actions/projects), with document-card language inside each tab.
   Coherence rules: header names the Economic Constitution rung (tap-through
   to the law in Congress); one "AS REPORTED" visual language for
   self-reported numbers; one "DIRECTIVE IN EFFECT — revisable in N turns"
   chip for standing settings; numbers always live next to their levers.
7. **Reform system remaining increments**:
   - R3-minimal: Military Rule + Personalist Rule as deliberate power-gated
     choices (military rule needs very high military loyalty — cheap to
     enter, costly to leave; personalist rule via patronage + wealth). One
     involuntary branch: a coup that *succeeds* while the player survives →
     Military Rule instead of hard game-over. A *defeated* coup imposes
     nothing — the player reimposes power (user decision 2026-07-04).
   - R4: real elections under electoral democracy — structural win (hold the
     order + survive a real election via the People's Congress chassis) and
     the new way to lose; replaces the snapshot Reformer win.
8. **Advisor layer expansion** beyond economy: bureaus, committee,
   dossier operations — same AdvisorNote component + pre-commit pattern.
9. **Open design decisions awaiting user**: turn-40 Survival ending
   pre-empting long play; "Robert Kennedy" cast member + "Tammany Hall"
   backstory (real-world names); real-country world roster vs full
   fictionalization; "Politburo" retained as game-internal term (decided:
   keep); economic-action AP costs now 1 (tune with playtests).
10. **Playtest-driven tuning pass**: crisis rebalance, grain thin-surplus
    (+2/turn), base-state-revenue (−1/turn start), credit crash odds, pilot
    zone thresholds, tournament padding rates — all tuned on paper, none on
    device.

## 3. What is verified (2026-07-04, EconomyVerificationTests — keep green)
- Credit dial → GDP/inflation/overheating/elite loyalty; crash + forced
  rectification.
- Pilot zone lifecycle incl. the real −10 power discount on liberalization.
- Growth tournament padding, audit, cooldown.
- Food → popular support death-chain (15 vs 80 food → support 0 vs 40 in 6
  turns).
- Economic Constitution rung genuinely changes economy behavior.
- Known masked channel: loose-credit inflation is suppressed by the default
  full price controls (realistic; Sasha explains it; revisit when price
  policy liberalizes).
