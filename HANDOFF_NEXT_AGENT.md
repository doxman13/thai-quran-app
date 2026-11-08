# Handoff Guide for Next Agent (`thai-quran-web` → `thai-quran-app` Alignment)

**Last Updated**: 2026-11-08  
**Master Blueprint**: [`NOV2026_WEB_ALIGNMENT_PLAN.md`](file:///Users/admin/Documents/gits/thai-quran-app/NOV2026_WEB_ALIGNMENT_PLAN.md)  
**Canonical Web Repo**: `/Users/admin/Documents/gits/thai-quran-web` (`main`, commit `f9d9669`)  
**Target App Repo**: `/Users/admin/Documents/gits/thai-quran-app` (`main`)  
**Current Static Analysis Status**: `flutter analyze lib` passes with **0 errors and 0 warnings** (14 info-only items).

---

## ✅ 1. Completed Workstreams (100% VERIFIED & ANALYZED)

### ✅ Workstream 1: Global Design System, Tajweed Palette & Thai Terminology (100% DONE)
- **[`lib/theme/app_theme.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/theme/app_theme.dart)**:
  - Standardized `AppTheme.radius = 12.0` (`rounded-xl`), `AppTheme.radiusSm = 8.0` (`rounded-lg`), and `AppTheme.radiusLg = 16.0` (`rounded-2xl`).
  - Aligned Light Mode (`#FBF9F5` parchment, `#FFFFFF` surface, `#F7F5EE` muted, `#E8E3D7` borderSoft, `#1C2520` textStrong, `#42524A` foreground, `#708078` textMuted, `#0E5A4A` primary jade, `#8A6530` mushafGold) and Dark Mode (`#131210` background, `#1C1B18` surface, `#24231F` muted, `#2E2C27` borderSoft, `#FAF6EE` textStrong, `#4A9E89` primary, `#CCA252` mushafGold).
  - Added `1px solid borderSoft` borders to `CardThemeData` and `InputDecorationTheme`.
  - Added canonical `TajweedPalette.getColor(className, isDark:)` matching Web's 6-hue editorial palette (`src/lib/tajweedService.ts`).
- **Tajweed Text & Guide**: Unified all renderers to use `TajweedPalette.getColor(...)`.
- **Thai Terminology**: Cleaned up `มุศหัฟ`, `ซูเราะฮฺ`, `อายะฮฺ`, `ญุซอ์`, `ตดับบุร`, and eliminated all `FontWeight.w800`/`w900` on Thai text.
- **Verification**: `flutter analyze lib/theme/app_theme.dart` -> 0 errors, 0 warnings.

---

### ✅ Workstream 5: Meaning Reader & Verse Card System (100% DONE)
- **[`lib/widgets/verse_card.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/widgets/verse_card.dart)**:
  - Strict Anti-AI Editorial Manuscript standard: `colors.surface`, hairline 1px `colors.borderSoft`, `AppTheme.radius = 12.0`, zero fuzzy box-shadows, zero gradients.
  - Active Verse Border: `#0E5A4A` primary jade border with `#0E5A4A` left indicator accent.
  - Gold Bookmark Badge: Classic Gold `#8A6530` pill badge (`#F6EFE3` light / `#2A2418` dark).
  - Academic Errata / Restored Ayat Comparison Box: Renders standard comparison banner showing Thai text alongside Restored Manuscript text.
  - Inline Word-by-Word View: Directly embedded when `settings.showWordByWord` is active.
  - Docked Footnotes: Expandable docked footnotes box.
  - Image Sharing Watermark: Appends `Thai Quran • quran-th.com`.
  - Verification: `flutter analyze lib/widgets/verse_card.dart` -> 0 errors, 0 warnings.
- **[`lib/providers/settings_provider.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/providers/settings_provider.dart)**:
  - Added `meaningModeContinuous = 'continuous'` and `meaningModeSingle = 'single'`.
  - Added `_meaningDisplayMode = meaningModeContinuous`, getter `meaningDisplayMode`, setter `setMeaningDisplayMode(value)` with SharedPreferences persistence.
- **[`lib/screens/reading_screen.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/screens/reading_screen.dart)**:
  - Top Bar Segmented Mode Switcher: `โหมดอ่านต่อเนื่อง` (`ต่อเนื่อง`) ↔ `โหมดทีละอายะฮฺ` (`ทีละอายะฮฺ`).
  - Continuous Scroll Mode: `ScrollablePositionedList` with dynamic Surah Master Header Card (`nameAr` in Arabic Uthmani font, metadata badges, dual actions `"ฟังเสียงอ่านทั้งซูเราะฮฺ"` and `"อ่านฉบับมุศหัฟมะดีนะฮฺ"`), theme headers, completion card, and next/prev Surah navigation row.
  - Single-Verse Focus Mode: `PageView` with RTL Floating Bottom Dock (`← อายะฮฺถัดไป` on left, Ayah jump picker in center, `ก่อนหน้า →` on right).
  - Floating Action Menu: Clean editorial styling with 1px hairline border, radius 12.0, solid surface.
  - Verification: `flutter analyze lib/screens/reading_screen.dart` -> 0 errors, 0 warnings.

---

### ✅ Workstream 6: Medina Mushaf Reader (100% DONE)
- **[`lib/screens/mushaf_reader_screen.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/screens/mushaf_reader_screen.dart)**:
  - Canvas & Paper Palette: `#1E1E1E` neutral dark paper on `#121212` canvas in dark mode; `#FFFDF9` on `#F7F4EC` canvas in light mode.
  - Physical Book Spread Wrapper: Hairline 1px border (`#2E2E2E` dark / `#E8DFC8` light), 16px radius, subtle spine gradient on the binding edge for even/odd pages across `_QcfPackagePageView` and `MushafPageView`.
  - **`_MushafVerseDetailSheet`**: Full-featured bottom sheet upon tapping any verse in Mushaf view:
    - Surah & Verse badge with Arabic calligraphy `nameAr`.
    - Uthmani Arabic scripture box (RTL, 24px, `#0E5A4A`).
    - Thai translation box.
    - *Al-Mukhtasar* Short Tafsir box with amber badge.
    - Quick actions: Play audio (`ฟังเสียง`), Bookmark (`คั่นอายะฮฺ`), Tadabbur (`บันทึก`).
    - Primary CTA: `"เปิดอ่านในฉบับความหมาย (Meaning Reader)"` navigating directly to `ReadingScreen`.
  - **`_MushafNavigatorSheet`**: 4-Tab comprehensive navigation sheet:
    - Tab 1 `ซูเราะฮฺ`: Search bar, 114 Surahs with `nameAr`, Makki/Madani badge, verse count, and start page.
    - Tab 2 `อายะฮฺ`: Surah picker + Ayah numeric grid; calculates Medina Mushaf page and jumps with verse highlight.
    - Tab 3 `ญุซอ์`: 30 Juz cards with starting page numbers and current Juz indicator.
    - Tab 4 `หน้า`: Direct numeric page jump (1–604) + Quick Milestones chips (p. 1, 2, 50, 106, 282, 293, 440, 582, 604).
  - Verification: `flutter analyze lib/screens/mushaf_reader_screen.dart` -> 0 errors, 0 warnings.

---

### ✅ Workstream 7: Hifz Memorization Suite & Tilawa AI (100% DONE)
- **[`lib/widgets/voice_recitation_banner.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/widgets/voice_recitation_banner.dart)**:
  - Added 1-Click Retry Button (`ล้าง/ลองใหม่` / `Icons.refresh_rounded`) that flushes the speech buffer and resets the engine state without stopping the microphone.
- **[`lib/screens/hifz_memorize_screen.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/screens/hifz_memorize_screen.dart)**:
  - Audio Guide Feedback Protection: Automatically pauses `RecitationTrackerProvider` whenever model recitation audio starts playing to prevent speaker feedback.
  - Clean Verse Peek Toggle: Tapping a hidden/peeked verse in both Mushaf view and Review Mushaf view cleanly toggles `provider.toggleVisibilityOverride()`.
  - Verification: `flutter analyze lib/screens/hifz_memorize_screen.dart lib/widgets/voice_recitation_banner.dart` -> 0 errors, 0 warnings.
- **Hifz Setup & Landing**:
  - `_inProgressCount` mastery calculation bug fixed.
  - `ยังไม่เริ่ม (Not Started)` filter chip added.
  - Surah, verse, and page cross-tab synchronization and persistence (`_syncActiveSurah` + `SharedPreferences`) implemented.

---

### ✅ Workstream 8: Unified Settings Architecture (100% DONE)
- Device-local Dark Mode strictly decoupled from cloud sync.
- 4 Pillars Settings UI: Reading Display Mode, Word-by-Word 3-Language Selector, Live Bismillah Preview, System & Reset with confirmation dialog.
- Verification: `flutter analyze lib/screens/settings_screen.dart lib/providers/settings_provider.dart` -> 0 errors, 0 warnings.

---

### ✅ Workstream 10: Cloud Sync Hardening (100% DONE)
- Monotonic merge forward progress (`math.max`) on both Mushaf pages and Reading indices.
- Idempotent `.upsert()` with Postgres conflict targets and error fallbacks.
- Unsynced guest bookmarks merge and push prior to sync.
- `saved_verses` cap raised to 9,999.
- Verification: `flutter analyze lib/providers/mushaf_reading_provider.dart lib/providers/local_reading_provider.dart` -> 0 errors, 0 warnings.

---

## 📋 2. Remaining Polish & Enhancements for Next Agent

### Workstream 2 (`lib/screens/home_screen.dart`)
- Add Quick Dark/Light Mode Toggle and Voice Search button to top AppBar.
- Add Contextual Time/Day Recommendation Pill inside Hero Card (Friday → Al-Kahf 18, Night → Al-Mulk 67, Morning → Ya-Sin 36, Afternoon → An-Naba 78) and dual entry buttons (`อ่านแบบความหมาย` + `เปิดมุศหัฟ`).
- Upgrade Quick Access cards to render `offlineSurahNamesAr` Uthmani calligraphy.

### Workstream 3 (`lib/screens/goals_screen.dart`)
- Add the 4 KPI Overview Cards (`114 Surahs Completion`, `Cumulative Verses Read / 6,236`, `Active Goals Count`, `Reading Streak`).
- Add Unified `ContinueReadingCard` at the top.
- Refactor active goal cards to single-column card with divider-separated `GoalRow` items.
- Add 5-second Undo `SnackBar` on goal archive.
- Add Khatam Pacing & Planning Calculator and 114-Surah Completion Matrix.

### Workstream 4 (`lib/screens/browse_screen.dart`, `topics_tab_view.dart`, `topic_verses_screen.dart`, `root_verses_screen.dart`, `voice_search_sheet.dart`)
- Add `offlineSurahNamesAr` Uthmani calligraphy, English meaning subtitle, starting page, and dual `ความหมาย` + `เปิดมุศหัฟ` buttons on Surah/Juz cards.
- Group 604-Page grid by Juz with Juz filter bar.
- Add 3rd top-level discovery tab `รากศัพท์ (Roots)` in Browse screen.

### Workstream 9 (`lib/screens/bookmarks_screen.dart`, `tadabbur_private_screen.dart`, `tadabbur_community_screen.dart`, `profile_screen.dart`)
- `bookmarks_screen.dart`: Item count badges on tabs, Mode Filter Chips, instant search bar, remove 6-item cap, render `nameAr` + translation snippet, 6 Favorite Surah Shortcuts grid.
- `tadabbur_private_screen.dart` & `tadabbur_community_screen.dart`: Unified Sub-Module Switcher (`🔒 บันทึกส่วนตัว` ↔ `🌍 ชุมชนตดับบุร`), Polite Guest Auth Card with local notes from `NotesProvider`, Full Quran Verse Quote Box.
- `profile_screen.dart`: Purge legacy color checks, add Resume Reading Banner, inline Recent Reading list, My Reflections breakdown.

---

## 🔍 3. Verification Protocol
Run after every change:
```bash
cd thai-quran-app
flutter analyze lib/
```
Ensure **0 errors and 0 warnings** are maintained at all times.
