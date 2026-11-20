# thai-quran-app — Homepage Design & UX Review

**Scope:** Home tab (`HomeScreen` → `_buildCleanHomeShowcase`) in [home_screen.dart](../lib/screens/home_screen.dart)
**Method:** static code review plus counts from grepping the file. The app was **not** run on a device or simulator, so there are no screenshots. Items about visual density, tap comfort and Thai text-scale behaviour should be confirmed on a real phone (small screen, text scale 1.3) before they are scheduled.
**Date:** 2026-11-20
**Status:** Option 1 + Phase 1 + Phase 2 + `lib/widgets/home/` modularization implemented (`flutter test` passing 180/180); remaining device visual check pending real-phone run.

---

## 1. What the page is today

Top to bottom, the home tab is a single `ListView` of 7 blocks (about 3+ screens of scroll):

| # | Block | Builder (line) |
|---|-------|----------------|
| 0 | AppBar: "อัสสลามุอะลัยกุม" + search + dark-mode toggle | `_buildAppBarTitleForTab` (1518) |
| 1 | Greeting (name) + streak chip + 7-day dots | `_buildGreetingAndStreakCard` (1563) |
| 2 | "Continue reading" hero card | `_buildUnifiedContinueHeroCard` (1708) |
| 3 | "Study Hubs" 2×2 coloured tiles (Meaning / Mushaf / Hifz / Recent) | `_buildMetroHubGrid` (2134) |
| 4 | Reading Goals (up to 2 meaning + 2 mushaf rows) | `_buildActiveGoalsSnapshot` (2489) |
| 5 | Quick Surahs horizontal carousel | `_buildQuickAccessSection` (2788) |
| 6 | Tadabbur Community carousel | `_buildCommunityReflectionsSection` (3429) |
| 7 | "Powered by quran-th.com" footer | `_buildQuranThFooter` (1453) |

**What already works well (keep):**
- One clear primary action in the hero ("Continue where you left off").
- Time-aware recommendation (Friday → Al-Kahf, night → Al-Mulk, etc.).
- Goal rows with a progress bar and %.
- Pull-to-refresh also triggers cloud sync.
- Guest-safe; Thai and English strings; dark mode.

---

## 2. Findings

Severity: **P1** = hurts clarity or ease of use, **P2** = polish or consistency, **P3** = maintainability.

### A. Clarity / information architecture

| ID | Sev | Finding | Evidence |
|----|-----|---------|----------|
| A1 | P1 | **"Continue" is shown in 3–4 places.** The hero, the *Meaning* tile, the *Mushaf* tile and the goal rows all surface the same last-read data (`_latestVerseLastRead` / `_latestMushafLastRead`). The user has to work out which one to press. | 1715–1716, 2154, 2209 |
| A2 | P1 | **Hero card is crowded.** Mode badge, a *second* pill (the recommendation, which looks like a badge but is actually a button), a "History →" link, title, subtitle, primary CTA and a "Switch mode" link. Three different pill styles sit in the top row. | 1817–1944, 2071–2123 |
| A3 | P1 | **Hifz tile is static.** It always says "ทดสอบ & ทบทวน / Tilawa & Review". It does not show an active paused session, even though the app now supports midway resume and cross-device sync. "Tilawa" is also unclear to users. | 2322–2339 |
| A4 | P1 | **"Recent Reads" tile lands on the Bookmarks tab** (`_navIndex = 2`). Label and destination do not match, and the tile duplicates the hero's "History →" link. | 2342–2352, 1914–1944 |
| A5 | P2 | **Meaning / Mushaf tiles open a bottom sheet first**, so the tile costs an extra tap compared with the hero button. What a tile does versus what the hero does is not obvious. | 2295, 2310, 3038–3093 |
| A6 | P2 | **Greeting is split in two places.** The AppBar says "Assalamu Alaikum" and the card below says the user's name. Guests see only a placeholder name ("Reader"/guest name) with no sign-in nudge. | 1520, 1599–1608, `supabase_provider.dart` 78–101 |
| A7 | P2 | **Streak card is the first thing on screen but the least actionable.** It pushes the hero (the main task) down. | 1563–1705 |
| A8 | P2 | **Goals are silently truncated.** `take(2)` for meaning plus `take(2)` for mushaf gives at most 4 rows with no "+N more" and no "X ayahs left". Goals also sit *below* the 2×2 grid, although for goal users they are the primary path. | 2610, 2646 |
| A9 | P2 | **Quick Surahs naming is wrong.** The header says "ทางลัดซูเราะฮฺยอดนิยม" (*popular* surahs), but the items are user-pinned plus locked defaults. The English button says "Pin", the Thai says "เพิ่มทางลัด". | 2807, 2823 |
| A10 | P3 | **Community block ends the page with 3 controls** (Shuffle, View All, carousel swipe) on content that is lowest priority. Preview text is cut by character count (`substring(0, 60/75)`), not by lines, which is risky for Thai (no spaces, combining marks). | 3460–3502, 3597–3607 |
| A11 | P2 | **Search icon only switches tabs** (`_navIndex = 1`); it does not focus the field or open voice search (a `voice_search_sheet.dart` exists). Two taps to start typing. | 1255–1261 |
| A12 | P3 | **Dark-mode toggle takes prime AppBar space** on every launch but is a set-once control; it already exists in Profile/Settings. | 1262–1277 |
| A13 | P3 | **Hifz and Goals are not top-level destinations** (bottom nav is Home / Surah / Bookmarks / Profile), so Home is the only discovery path for them, which raises the stakes on A1–A4. | 1281–1311 |

### B. Touch targets, legibility, accessibility

| ID | Sev | Finding | Evidence |
|----|-----|---------|----------|
| B1 | P1 | **Quick-Surah card has 4 tap zones in 148×86 px**: card, "Meaning" link, "Mushaf" link, and a 13 px close icon. The links are 9.5 px text with ~1 px vertical padding, far below the 48 dp guideline. High mis-tap risk, and the close icon sits next to the Arabic name. | 2855–3010 |
| B2 | P1 | **Very small text.** `fontSize` of 9.5 (5×), 10 (6×) and 10.5 (6×) in the home screen. Thai tone marks become hard to read at this size, and there are several of them in tiles and badges. | grep: 17 occurrences ≤ 10.5 |
| B3 | P2 | **Little semantic support.** Only 3 `Semantics` / `semanticLabel` / `tooltip` usages in 4,806 lines. Tiles, pills and the streak dots are not announced meaningfully. "🎯" is embedded in badge strings, so it is read aloud. | grep; 2183, 2237, 4344 |
| B4 | P2 | **White-on-gold and white-at-0.7-opacity text** on coloured tiles (source labels, "Switch mode" at `white70`, 11.5 px) is likely below WCAG AA. Needs a contrast check. | 2463–2477, 2112–2116 |

### C. Visual consistency vs. our Anti-AI Editorial design system (`AGENTS.md`)

| ID | Sev | Finding | Evidence |
|----|-----|---------|----------|
| C1 | P1 | **`FontWeight.w800` / `w900` on Thai AppBar titles** (explicitly forbidden: tone/vowel marks collide). | 1524 (w900), 1534, 1544, 1554 (w800) |
| C2 | P2 | **Puffy radii.** 19 uses of `BorderRadius.circular(14/16/18/20…)` instead of `AppTheme.radius` (12) / `radiusSm` (8). | grep count 19 |
| C3 | P2 | **`BoxShadow` on cards** (forbidden) in Quick Surahs and Community cards. | 2871, 3537, 3628 |
| C4 | P2 | **Off-palette colours hard-coded** rather than read from `context.appColors`: `#15803D` (the forbidden "radioactive green", used 3× in the streak strip), `#264653` + `#1F3A44` (blue-slate "Recent" tile), `#2D6A4F` + `#1E4E38` (a third green for Hifz), `#0E5B59` (near-duplicate of brand jade `#0E5A4A`), `#FDE68A` / `#F3D28A` (yellow tints), `#F3F7F4` / `#1B2621` (card bg). | grep of hex literals |
| C5 | P2 | **Four differently coloured solid tiles** (jade / gold / green / slate) read as "Windows Phone Metro", not the quiet editorial manuscript look used on web. The metro grid is also the heaviest visual block on the page. | 2143–2151, comment 2133 |
| C6 | P3 | **Mixed card styles**: hero (solid jade + watermark), tiles (solid colours), goals/quick/community (soft surface cards with different radii 14/16/18). The page lacks one card language. | various |

### D. Engineering / maintainability

| ID | Sev | Finding |
|----|-----|---------|
| D1 | P3 | `home_screen.dart` is **4,806 lines** with one state class; every section is a method, so none can be tested or previewed alone. Time-of-day recommendation logic lives inside a `build` method (1722–1745). |
| D2 | P3 | `context.watch` of 4 providers at the top of `build` rebuilds the entire page on any change. `IndexedStack` also builds all 4 tabs at start-up. |
| D3 | P3 | Plain `CircularProgressIndicator` while `!_isInit` (1221); `mushaf_page_skeleton.dart` shows we already have a skeleton pattern. |

---

## 3. Recommendations

### 3.1 Target layout (proposal)

```
┌ AppBar:  อัสสลามุอะลัยกุม, {ชื่อ}   🔥 12   [🔍]  [🎤]   ← streak = flame + count only; no dark-mode toggle (lives in Settings → Appearance)
├ 1. Continue hero                                          ← ONE primary CTA; mode switch = proper small button, not a text link
│     "อัลมุลก์ • อายะฮฺที่ 12"   ▓▓▓▓░░ 40%  · 2 ชม. ที่แล้ว
│     (no recommendation pill; Friday → Al-Kahf only as an optional Quick Surahs chip)
├ 2. [conditional] Hifz resume banner                       ← reuses ActiveSessionSnapshot + formatActiveSessionSubtitle
│     "ท่องต่อ: อัลมุลก์ 1–5 • อายะฮฺที่ 2 (7/54) • 3/10"   [ท่องต่อ]
├ 3. Reading goals (max 2 rows total, "+N เป้าหมาย" link)
├ 4. Modes (4 quiet surface cards, jade/gold accents only: Meaning · Mushaf · Hifz · Tadabbur) — no last-read duplicate
├ 5. Quick surahs: compact chips (number + name); tap = open in last-used mode; long-press = choose mode / remove
├ 6. One featured community reflection  [View all ›]        ← no shuffle button
└ footer
```

### 3.2 Phased plan

**Phase 1 — Quick wins (≈1 day, low risk, mostly visual):**
1. C1: change app bar title weights to `w700` (Thai) — 4 lines.
2. C2/C3/C4: replace radii with `AppTheme.radius`/`radiusSm`, remove 3 `BoxShadow`s, map hard-coded hex to `context.appColors` (streak "read" colour → brand jade `#0E5A4A`; Hifz/Recent tiles → jade/gold family).
3. B2: raise minimum text size to 11 sp (prefer 12 sp for body labels); remove the emoji from badges (use an `Icon`).
4. A4: rename tile to match destination ("ที่คั่น & บันทึก") or route it to the real history list.
5. A9: fix header copy ("ซูเราะฮฺที่ปักหมุด / Pinned Surahs") and unify the Pin label.
6. A11: search icon focuses the search field (and/or offers voice search).

**Phase 2 — UX clean-up (≈2–3 days):**
1. A3: **Hifz resume banner** on Home (and live subtitle on the Hifz tile). Data is already there: `HifzRepository.loadActiveSession()` + `formatActiveSessionSubtitle` in `lib/utils/hifz_mastery_utils.dart`.
2. A1/A5: remove last-read text from the Meaning/Mushaf tiles (the hero owns "continue"); make the tiles plain entry points.
3. A2: move the recommendation pill out of the hero into its own row; drop the "History →" link or turn it into an icon button.
4. A7/A6: merge greeting + streak into the AppBar area; keep the 7-day dots on the Goals/Progress screen. Add a soft "Sign in to sync" prompt for guests.
5. A8: show at most 2 goal rows, add "+N more" and "N ayahs left".
6. B1: simplify Quick Surah chips to a single tap target; move the mode choice to long-press.

**Phase 3 — Structure (≈3–5 days, optional):**
1. D1: split into `lib/widgets/home/` (`HomeHeader`, `ContinueHero`, `HifzResumeBanner`, `GoalsSnapshot`, `ModeGrid`, `QuickSurahs`, `CommunityPreview`) and unit-test the recommendation logic.
2. D2: scope rebuilds with `Selector`/`Consumer` per section.
3. D3: skeleton loader for first launch.
4. B3/B4: semantic labels for tiles, streak dots and hero; run a contrast audit.

### 3.3 Success checks
- Taps from app open to "reading the last position" stays at **1**; to "resuming Hifz" drops from ~3 to **1**.
- No home-screen text below 11 sp; no `w800/w900`; no `BoxShadow`; no hex literals outside `AppThemeColors`.
- Home fits "continue + goals" above the fold on a 360×640 device at text scale 1.0.
- `flutter analyze` and `flutter test` stay green; add widget tests for the Hifz resume banner and the goals "+N" state.

### 3.4 Decisions (2026-11-20)
| # | Question | Decision |
|---|----------|----------|
| 1 | Hifz as its own bottom-nav tab? | **No.** Keep 4 tabs (a 5th would be cramped). Hifz stays reachable from the Home mode card and the conditional **Hifz resume banner**. |
| 2 | Keep the time-of-day recommendation pill? | **Remove it from the hero** (too small, not obviously tappable). Optional: keep only a **Friday → Al-Kahf** chip inside Quick Surahs. The same reasoning applies to the hero's tiny "History →" and "Switch mode" links: make them real buttons or remove them. |
| 3 | 7-day dots vs streak count? | **Streak count only** (flame + number) in the header. Show a filled vs outline flame for "read today / not yet today". Weekly dots are removed from Home. |
| 4 | Dark-mode toggle on the AppBar? | **Remove it from Home.** Settings → Appearance already has the picker. Add a third **"Follow system"** option (see §3.5). |

### 3.5 Reference: what other apps do
Based on web search summaries (secondary sources, not verified against each app, so treat as directional):
- **Dark mode:** none of the apps found (Muslim Pro, Tarteel, Quran.com) put the toggle on the home screen. Muslim Pro keeps it in the reader's display settings, Tarteel under Settings → Themes, and Quran.com in the reader/settings menu. Material Design guidance recommends a three-state setting (System / Light / Dark), defaulting to System.
- **Streaks:** Duolingo-style apps show a flame plus a big number for glanceability. Weekly dots are more forgiving after a missed day but cost more space and are slower to read.
- **Our current state:** theme is binary (`ThemeMode.dark : ThemeMode.light` in `main.dart:204`), defaults to light and ignores the OS setting. `StatsProvider` exposes `streakCount` and `hasReadOn(date)` but no "best streak".

### 3.6 Hero sizing & image assets audit
- **Hero card size:** once the 7-day streak card, recommendation pill and tiny links are removed, the hero rises ~120 px to the top of the screen. Keep its height moderate (~160–185 px) with cleaner internal breathing room rather than making it taller — a tall banner pushes Goals and Hifz below the fold on small phones.
- **`assets/images/` audit (40 MB unused in app bundle):** `- assets/images/` in `pubspec.yaml:20` bundles 40 MB of files with **0 references in `lib/`**:
  - `feature_graphic_big.psd` (33 MB) plus Play Store/marketing assets (`feature_graphic_big.png`, `feature_graphic_1024x500*.png`, `Gemini_Generated_Image_29oo8x29oo8x29oo.jpeg`, `ip-ss1.png`) — should be moved out of the app asset bundle.
  - `image_slider1`–`6` (`_x.webp` / `_2x.webp`) — portrait 2:3 atmospheric scenes (open Quran on *rehal*, mosques, Ka'bah, silhouette reader). Poor fit as a Home hero background (busy bright areas fight white UI text/CTA), though well suited if you later add **share-ayah quote cards** or onboarding slides.
- **Better photo option if desired:** match web's separation (`HomeHeroBanner.tsx` is solid `#0E5A4A` with no photo; `HomeShortcutsGallery.tsx` uses lightweight photos from `public/images/shortcuts/*.jpg` like `mulk.jpg` and `cave.jpg`). Either keep mobile text-first/manuscript (removing `assets/images/` saves ~40 MB) or copy only lightweight shortcut thumbnails for the **Pinned Surahs** strip as single-tap ~120×92 photo cards.
