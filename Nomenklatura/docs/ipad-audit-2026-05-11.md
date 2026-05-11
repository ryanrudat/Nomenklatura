# iPad Layout Audit — 2026-05-11

## Test environment

- **Device**: iPad Pro 13-inch (M5) simulator
- **iOS**: 26.4
- **Native resolution**: 2064 x 2752 px (1032 x 1376 pt @2x)
- **Orientation**: Portrait (UI never rotated to landscape — see "Coverage gap" below)
- **App build**: Debug, iphonesimulator SDK, deployment target iOS 18.0
- **Build**: BUILD SUCCEEDED clean against the iPad destination
- **Date**: 2026-05-11

## Screenshots captured (NOT committed — for user review only)

| File | Screen | Notes |
| --- | --- | --- |
| `/tmp/ipad-desk.png` | Scenario selection ("WELCOME, COMRADE") | First-launch entry; only "The Apparatus" scenario card visible. |
| `/tmp/ipad-desk-landscape.png` | Background selection ("CHOOSE YOUR BACKGROUND") | Despite the filename, also portrait. Captured on the page-1-of-5 paginator step. |
| `/tmp/ipad-screen3.png` | Outcome screen ("APPROVED") | Mid-game state — reached during the screenshot sequence. Includes Reactions row, Effects table, Expertise Gained banner, Continue button. |

`/tmp/ipad-screen4.png` is a duplicate of `/tmp/ipad-screen3.png` (state did not advance between captures) and is omitted from analysis.

## Findings — obviously broken iPad layouts

### 1. Massive vertical empty space on every flow screen

All three screens show the same anti-pattern: content is laid out for iPhone width (a single fixed-width column, roughly 80% of the screen) and the bottom 50–60% of the iPad canvas is solid dark void. Specifically:

- **Scenario screen** (`ipad-desk.png`): The Apparatus card occupies y ~110 to y ~165. Everything below is black — about 2,200 px of empty space.
- **Background selection** (`ipad-desk-landscape.png`): The Youth League card extends to y ~470. The bottom CTA bar is glued to y ~610, leaving ~2,100 px between the card and the "1 of 5" paginator. The card itself never widens to use the iPad canvas.
- **Outcome screen** (`ipad-screen3.png`): Content fills more vertical space (Consequences, Reactions row, Effects, Expertise Gained, Continue CTA) but the layout is still a single iPhone-width column centered on the screen. The Reactions row could comfortably show 6–8 character cards instead of 4, and the Effects table has unused horizontal real estate at every row.

**Root cause guess**: Views likely use `.frame(maxWidth: 600)` or similar iPhone-sized clamps without any iPad-aware `regularSizeClass` branch. The codebase does NOT appear to use `NavigationSplitView` or any iPad sidebar pattern.

### 2. Top header padding inconsistent on iPad

The "WELCOME, COMRADE" and "CHOOSE YOUR BACKGROUND" titles sit very close to the iPad safe area — there is no extra top breathing room as you'd expect on a 13-inch canvas. The hammer/sickle action button in the top-right of the scenario screen is also small relative to the iPad surface (looks like an iPhone tap target floating in vast space).

### 3. Reactions row truncated on Outcome screen

The "REACTIONS" row on the Outcome screen shows 4 character cards (Director Wallace, Anthony Carpenter, Major Strickland, Worker David), but each card's text is truncated mid-sentence ("a measured approach. The Standing Committee tak…", "Economic rationality must guide our decisions…"). On iPad the cards could be wider OR display more cards per row, but the current layout keeps the iPhone density.

## Recommendations (deferred to a future wave)

1. **Audit `.frame(maxWidth:)` usage** — search for hardcoded iPhone widths (375, 393, 414, 600, etc.) and gate them behind `horizontalSizeClass == .regular` checks.
2. **Consider `NavigationSplitView`** for Desk + sidebar (Bureau / Codex pinned at left) on iPad — would put empty space to immediate use.
3. **Multi-column Reactions / character grids** — `LazyVGrid` with adaptive `minimum: 200` would let 6+ cards show on iPad.
4. **Scenario / Background selection** — these are paginated single-card screens; on iPad show 3-up grid OR center one card with bigger typography.
5. **Outcome screen** — let the Consequences narrative use a 2-column layout on iPad to balance the long Reactions row.

## Coverage gap

Interactive navigation past the entry splash was NOT possible from this audit because:

- The simulator host was under heavy load (load avg 91 during the test session — two parallel agents running) and the iPad Pro 13" sim repeatedly shut itself down. Required ~6 boot attempts before one stayed alive long enough to install + launch the app.
- No UI automation tooling is available locally (`idb`, `applesimutils` not installed; `osascript` keystroke injection is blocked by macOS Accessibility prompts).
- `xcrun simctl` does not expose a `tap` primitive.

As a result, the following screens were NOT captured:

- **Desk (gameplay)** — the actual landing screen after scenario + background + naming.
- **Economy tab** (Gosplan / EconomicHubView — 932 lines, 6 sections).
- **Ledger tab** (Political situation room).
- **Dossier / Codex tabs**.
- **All sheets** (Sector Detail, Budget, Trade, Loan Proposal, etc.).
- **Landscape orientation** — sim never rotated; all captures are portrait.

These need an interactive run by the user (or a future audit wave with UI automation installed) to evaluate properly. Based on what was observed at the entry screens, the dominant issue is almost certainly the same throughout: iPhone-width content centered in a large iPad canvas.
