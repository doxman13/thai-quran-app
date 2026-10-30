# October 2026 Improvement Plan (`thai-quran-app` ↔ `thai-quran-web` Alignment)

**Branch**: `feat/ux-redesign-aligned`  
**Status**: ✅ Core UX Redesign, Web Alignment & Home Correctness Fixes Implemented (`flutter analyze` clean; 54/54 tests passing)  
**Commit**: `f395693` — fix(home,hifz): account-scoped quick links and Phase 9 surah selection polish  
**Last Updated**: 2026-10-30

---

## 1. Complete Ecosystem Inventory & Identified Problems

| Category | What Exists in the Codebase | Previous Problem | Status |
| :--- | :--- | :--- | :---: |
| **1. The 3 Core Modes** | • **Meaning Mode** ([`ReadingScreen`](file:///H:/gits/thai-quran-app/lib/screens/reading_screen.dart)): Verse-by-verse Thai translation, Word-by-Word (WBW), Footnotes, Short Tafsir (*Al-Mukhtasar*), Audio player, Auto-scroll.<br>• **Mushaf Mode** ([`MushafReaderScreen`](file:///H:/gits/thai-quran-app/lib/screens/mushaf_reader_screen.dart)): 604-page Madinah Mushaf, Tajweed color-coded Mushaf, Pinch-to-zoom, Page audio.<br>• **Hifz Mode** ([`HifzMemorizeScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_memorize_screen.dart)): Takrar `10x Visible + 5x Hidden`, Cumulative linking, `2x/2x` Muraja'ah review, Waqf chunking, Mutashabihat alerts. | Jumping into the 3 modes from Home/Goals/Browse was cluttered with duplicate mode capsules and stock-photo carousels. | ✅ Fixed |
| **2. Goals (Meaning & Mushaf)** | • **Meaning Goals** (`LocalReadingProfile`): By Juz, Surah, Ayah count, or Custom range.<br>• **Mushaf Goals** (`MushafProfile`): By Page range (1–604), Juz, or Surah.<br>• **Archived Goals**: Archive & Restore. | Creation dialogs were embedded inside [`HomeScreen`](file:///H:/gits/thai-quran-app/lib/screens/home_screen.dart), while Archived Goals were hidden inside [`ProfileScreen`](file:///H:/gits/thai-quran-app/lib/screens/profile_screen.dart) bottom sheets. | ✅ Fixed (Moved to [`GoalsScreen`](file:///H:/gits/thai-quran-app/lib/screens/goals_screen.dart)) |
| **3. Bookmarks, Recent Reads & Quick Links** | • **Bookmarks**: Unified Meaning verses + Mushaf pages + Mushaf verses ([`BookmarksScreen`](file:///H:/gits/thai-quran-app/lib/screens/bookmarks_screen.dart)).<br>• **Recent Reads**: Unified history of Meaning & Mushaf sessions.<br>• **Quick Links / Favourite Surahs**: Pinned Surahs (Al-Kahf 18, Yasin 36, Al-Mulk 67, Juz 30) + custom pinned Surahs. | Quick Links on Home had unlocalized English strings (`"Read every night"`, `"Add Quick Link"`), and `BookmarksScreen` could not be deep-linked to a specific tab. | ✅ Fixed (now account-scoped with deletion-safe sync) |
| **4. Tadabbur (Personal Notes & Community Feed)** | • **Private Notes** ([`TadabburPrivateScreen`](file:///H:/gits/thai-quran-app/lib/screens/tadabbur_private_screen.dart))<br>• **Community Feed** ([`TadabburCommunityScreen`](file:///H:/gits/thai-quran-app/lib/screens/tadabbur_community_screen.dart)): Public reflections, Likes.<br>• **Home Preview**: Community reflections preview card. | Community Tadabbur had no discovery entry point on Home. | ✅ Fixed |
| **5. Browse, Search & Discovery** | • **Surah (114)**, **Juz (30)**, **Mushaf Page (604)**, **Topics (`หัวข้อ`)** ([`BrowseScreen`](file:///H:/gits/thai-quran-app/lib/screens/browse_screen.dart)) | `HomeScreen` contained ~220 lines of dead search sliver code duplicating `BrowseScreen`. | ✅ Fixed |
| **6. Hifz Hub & Sub-Screens** | • [`HifzLandingScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_landing_screen.dart) (Dashboard)<br>• [`HifzWizardSetupScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_wizard_setup_screen.dart)<br>• [`HifzHistoryScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_history_screen.dart)<br>• [`HifzGuideScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_guide_screen.dart) | `HifzLandingScreen` had 5 redundant stacked banners/cards that all launched the same wizard, and hid the 114-Surah Mastery list on a separate screen. | ✅ Fixed |
| **7. Unified Settings** | • [`SettingsScreen`](file:///H:/gits/thai-quran-app/lib/screens/settings_screen.dart)<br>• [`HifzSettingsScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_settings_screen.dart) | `HifzSettingsScreen` (1,639 lines) duplicated Dark Mode, Language, Keep Screen Awake, Font Sizes, and Translations from `SettingsScreen`. | ✅ Fixed (Unified 4-Tab Settings) |
| **8. Profile, Library & Stats** | • [`ProfileScreen`](file:///H:/gits/thai-quran-app/lib/screens/profile_screen.dart)<br>• [`StatsProvider`](file:///H:/gits/thai-quran-app/lib/providers/stats_provider.dart) | Reading stats and library links were hidden when logged out (guest mode), and duplicated goal-management sheets. | ✅ Fixed |

---

## 2. Implementation Checklist (What Has Been Done)

### Phase 1: Git Branch & Provider Enhancements
- [x] Created and switched to branch `feat/ux-redesign-aligned` in `H:\gits\thai-quran-app`.
- [x] Added `restoreProfile(String profileId)` and `archivedCustomProfiles` getter to [`MushafReadingProvider`](file:///H:/gits/thai-quran-app/lib/providers/mushaf_reading_provider.dart) so archived Mushaf goals can be restored just like Meaning goals.

### Phase 2: Screen 1 — Clean Home Showcase ([`lib/screens/home_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/home_screen.dart))
- [x] **5-Tab Bottom Navigation Bar**:
  - `Tab 0`: **หน้าแรก (Home)** — Calm showcase dashboard
  - `Tab 1`: **เป้าหมาย (Goals)** — Dedicated [`GoalsScreen`](file:///H:/gits/thai-quran-app/lib/screens/goals_screen.dart)
  - `Tab 2`: **สำรวจ (Browse)** — [`BrowseScreen`](file:///H:/gits/thai-quran-app/lib/screens/browse_screen.dart) (Surah / Juz / Page / Topics)
  - `Tab 3`: **ท่องจำ (Hifz)** — [`HifzLandingScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_landing_screen.dart)
  - `Tab 4`: **โปรไฟล์ (Profile)** — [`ProfileScreen`](file:///H:/gits/thai-quran-app/lib/screens/profile_screen.dart)
- [x] **Top AppBar**: Brand `iQra` badge + Search icon (jumps to Browse/Search) + Bookmarks/Recent icon + Settings icon.
- [x] **Removed Home Clutter**: Removed all goal creation/edit dialogs, stock photo carousels, and dead search sliver code (~2,500 lines of clutter removed).
- [x] **6 Clean Showcase Sections on Home**:
  - [x] **1. Greeting & 7-Day Reading Streak Strip**: Clean emerald check circles + active streak pill.
  - [x] **2. Unified "Continue Reading" Hero Card**: Deep emerald (`#062C2B` → `#0E5A4A`) card with subtle gold `ٱقْرَأْ` calligraphy watermark, mode badge (Meaning or Mushaf), last-read details, `ประวัติอ่านล่าสุด →` link, and a 100% opaque gold CTA button (`อ่านต่อจากจุดเดิม`).
  - [x] **3. Active Goals Snapshot (Read-Only Display)**: Compact progress rows for active Meaning (`#0E5B59`) and Mushaf (`#8A6530`) goals with a `จัดการเป้าหมาย →` button that switches to the Goals tab.
  - [x] **4. Quick Surah Access Row**: Localized quick pills for *Al-Kahf (18)*, *Yasin (36)*, *Al-Mulk (67)*, *Juz 30 (78)*, plus custom pinned Surahs (`เพิ่มทางลัด`).
  - [x] **5. Daily Featured Verse & Short Tafsir (*Al-Mukhtasar*)**: Curated inspiring verses with Uthmanic Arabic, Thai/English translation, expandable *Al-Mukhtasar* short tafsir box, `[🔀]` shuffle button, and `อ่านในบริบทซูเราะฮฺ`.
  - [x] **6. Community Tadabbur Reflections Preview**: Displays recent public reflections from `TadabburRepository` with a `ดูทั้งหมด →` button opening [`TadabburCommunityScreen`](file:///H:/gits/thai-quran-app/lib/screens/tadabbur_community_screen.dart).

### Phase 3: Screen 2 — Dedicated Goals Page ([`lib/screens/goals_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/goals_screen.dart))
- [x] Created [`GoalsScreen`](file:///H:/gits/thai-quran-app/lib/screens/goals_screen.dart) aligned with `thai-quran-web`'s `ModernGoalsView.tsx`.
- [x] **8 Recommended 1-Click Presets**:
  1. `ramadan_khatam_meaning` (ค็อตม์เดือนรอมฎอน 30 ญุซอ์)
  2. `ramadan_khatam_mushaf` (ค็อตม์มุศหัฟ 604 หน้า)
  3. `full_khatam_meaning` (อ่านจบอัลกุรอานพร้อมความหมาย)
  4. `deep_study_baqarah` (ศึกษาซูเราะฮฺอัล-บะเกาะเราะฮฺ)
  5. `juz_amma_meaning` (ญุซอ์อัมมะ — ญุซอ์ที่ 30)
  6. `daily_habit_mulk` (อ่านซูเราะฮฺอัล-มุลก์ทุกคืน)
  7. `mushaf_habit_2pages` (อ่านมุศหัฟวันละ 2 หน้า — ญุซอ์ที่ 1)
  8. `mushaf_juz_amma` (อ่านมุศหัฟญุซอ์ที่ 30 — หน้า 582–604)
- [x] **Filter Tabs**: `ทั้งหมด (All)` / `ความหมาย (Meaning)` / `มุศหัฟ 604 หน้า (Mushaf)`.
- [x] **Goal Progress Cards**: Distinct Emerald (`#0E5B59`) for Meaning and Amber-Gold (`#8A6530`) for Mushaf, showing progress bar, *"อ่านค้างไว้ที่ล่าสุด (Currently Reading At)"* box, `แก้ไข (Edit)`, `จัดเก็บ (Archive)`, and `อ่านต่อ (Continue)` CTA.
- [x] **Archived Goals Drawer**: Collapsible section at the bottom to restore archived Meaning and Mushaf goals in 1 tap.
- [x] **Unified 4-Step Goal Creator Modal**: Mode selector (Meaning vs Mushaf) → 1-Click Presets → Goal Name → Range selector (by Juz, Surah, Ayah count, Custom range, or Mushaf Page range).

### Phase 4: Screen 3 — Streamlined Hifz Dashboard ([`lib/screens/hifz_landing_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/hifz_landing_screen.dart))
- [x] Replaced the redundant 5-banner stack with the clean 4-part layout matching `thai-quran-web`'s `HifzLanding.tsx`:
  - [x] **1. Active Session Resume Banner**: Amber card shown when an active session exists, with `ท่องต่อ (Resume)` and `ยกเลิก (Discard)`.
  - [x] **2. Deep Emerald Takrar Hero Card**: Direct `[ ▶ เริ่มท่องอายะฮฺใหม่ (New Verses) ]` and `[ 🔄 ทบทวนความจำ (Review Mode) ]` buttons + header actions for Guide, History, and Hifz Controls.
  - [x] **3. Three Interactive Stat & Control Pills**:
    - `จำขึ้นใจแล้ว (Mastered / 114)` — filters the grid below
    - `กำลังท่องจำ (In Progress / 114)` — filters the grid below
    - `วิธีเลื่อนอายะฮฺ (Input Mode ⚙)` — opens Settings directly on the `Hifz & Controls` tab
  - [x] **4. Embedded 114-Surah Mastery List**: Search bar + filter chips (`ทั้งหมด 114`, `กำลังท่อง`, `จำขึ้นใจแล้ว`, `ญุซอ์ 29 & 30`) + tappable Surah cards that open a clean action sheet (`Memorize New Verses` or `Review This Surah`).

### Phase 5: Screen 4 — Unified Categorized Settings ([`lib/screens/settings_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/settings_screen.dart) & [`lib/screens/hifz_settings_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/hifz_settings_screen.dart))
- [x] Rebuilt [`SettingsScreen`](file:///H:/gits/thai-quran-app/lib/screens/settings_screen.dart) into 4 categorized tabs matching `thai-quran-web`'s `src/app/settings/page.tsx`:
  - [x] **Tab 1 — `การแสดงผล (Appearance)`**: Dark Mode, Keep Screen Awake, and App Language (`ภาษาไทย` / `English`).
  - [x] **Tab 2 — `การอ่าน & ตัวอักษร (Quran Reader)`**: Live Bismillah Preview Card, Arabic & Translation Font Size sliders, Word-by-Word toggle + language, Footnotes toggle, and Tajweed Color Guide sheet.
  - [x] **Tab 3 — `บทแปล & ออฟไลน์ (Translations)`**: `TranslationManagerSection` + Remote Content update checker.
  - [x] **Tab 4 — `ฮิฟซ์ & รีโมท (Hifz & Controls)`**: Hifz Input Mode (`In-App Tally`, `Bluetooth Shutter`, `BLE Smart Ring` + `BleDeviceManagementUI`), Offline AI Voice Recitation Tracking + Adaptive Noise Filter, and Reciter Playback Volume slider.
- [x] Simplified [`HifzSettingsScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_settings_screen.dart) to delegate directly to `SettingsScreen(initialCategory: SettingsCategoryTab.hifz)`, removing ~1,280 lines of duplicated settings UI while keeping `BleDeviceManagementUI` intact.

### Phase 6: Screen 5 — Profile & Saved Library ([`lib/screens/profile_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/profile_screen.dart) & [`lib/screens/bookmarks_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/bookmarks_screen.dart))
- [x] Added `initialTab` support (`0: Recent`, `1: Bookmarks`, `2: Favourites & Notes`) to [`BookmarksScreen`](file:///H:/gits/thai-quran-app/lib/screens/bookmarks_screen.dart).
- [x] Added the **My Saved Library (`คลังส่วนตัวของฉัน`)** quick-launch bar and **6 Interactive Stat Pills** (`Reading Streak`, `Read Today`, `This Week`, `Bookmarks`, `Favourites & Notes`, `Active Goals / Problem Reports`) to the top of [`ProfileScreen`](file:///H:/gits/thai-quran-app/lib/screens/profile_screen.dart) for both guest and signed-in users.
- [x] Removed duplicate reading-goal bottom sheets from `ProfileScreen` (now routes cleanly to the dedicated Goals tab).

### Phase 7: Cross-Language Fuzzy Surah Search & Voice Search Stability
- [x] **Cross-Language & Phonetic Surah Text Search** ([`matchesSurahQuery`](file:///H:/gits/thai-quran-app/lib/data/offline_surah_names.dart#L437-L489)):
  - Searches across **Thai** (`offlineSurahNamesTh`), **English** (`offlineSurahNamesEn`), **Arabic** (`offlineSurahNamesAr`), and **Surah number** simultaneously regardless of whether the app UI language is set to Thai or English.
  - Supports normalized phonetic/transliterated matching (strips `Al-`/`An-`/`Ar-`/`Ash-`/`At-` prefixes, hyphens, apostrophes, spaces, silent trailing `-h`, and collapses repeated consonants/vowels so searching `"Jin"`, `"Jinn"`, `"Yaseen"`, `"Kahf"`, `"Mulk"`, `"Fatiha"`, or `"Baqara"` works even when the app is in Thai).
  - Applied across [`BrowseScreen`](file:///H:/gits/thai-quran-app/lib/screens/browse_screen.dart) (Surah & Juz search), [`HifzLandingScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_landing_screen.dart), [`SurahPickerSheet`](file:///H:/gits/thai-quran-app/lib/widgets/surah_picker_sheet.dart), [`HifzMushafRangePickerScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_mushaf_range_picker_screen.dart), and [`MushafReaderScreen`](file:///H:/gits/thai-quran-app/lib/screens/mushaf_reader_screen.dart).
- [x] **Voice / Mic Search Stability & Auto-Lock** ([`RecitationEngine`](file:///H:/gits/thai-quran-app/lib/services/recitation_engine.dart) & [`VoiceSearchSheet`](file:///H:/gits/thai-quran-app/lib/widgets/voice_search_sheet.dart)):
  - Added dedicated voice-search trailing silence window (`_searchSilenceFramesNeeded = 8`, ~500ms) so natural mid-recitation pauses don't prematurely split phrases.
  - Ignored short 1-token / `<3`-char ambient noise bursts during search inference.
  - Automatically stops the microphone (`stopListening()`) and locks the recognized Arabic text & verse results as soon as valid matches are returned, preventing background noise from resetting or overwriting results until the user explicitly taps the mic button again.

### Phase 8: Web Alignment, Voice Search Auto-Stop & Last-Word Matching Rule
- [x] **Web Search Normalization & Fuzzy Search** ([`src/data/surahNames.ts`](file:///H:/gits/thai-quran-web/src/data/surahNames.ts)):
  - Added `normalizeSurahLatin`, `normalizeSurahThai`, and `matchesSurahSearch` in `thai-quran-web`.
  - Searches Surahs across Thai, English transliteration (ignoring `Al-`, `An-`, repeated letters, punctuation), Arabic, and Surah ID simultaneously.
  - Aligned search across `BrowsePage.tsx`, `GlobalSearchModal.tsx`, `SurahReader.tsx`, `HifzMasteryGrid.tsx`, and `GuestLandingPage.tsx`.
- [x] **Web Voice Search Auto-Stop & Noise Gating** ([`src/components/VoiceSearchModal.tsx`](file:///H:/gits/thai-quran-web/src/components/VoiceSearchModal.tsx)):
  - Added speech energy tracking (`lastSpeechAtRef`), noise suppression after match, and automatic microphone auto-stop (`scheduleSettleAutoStop`) ~1.4s after recitation finishes.
- [x] **Last-Word Recitation Matching Gate in Hifz Mode** (Both Web & App):
  - **Web**: Enforced in [`src/lib/tilawaRecognition.worker.ts`](file:///H:/gits/thai-quran-web/src/lib/tilawaRecognition.worker.ts) (`hasRecitedLastWordOfAyah`), [`src/lib/tilawaRecitation.ts`](file:///H:/gits/thai-quran-web/src/lib/tilawaRecitation.ts), [`src/lib/hifz/useHifzVoiceRecitation.ts`](file:///H:/gits/thai-quran-web/src/lib/hifz/useHifzVoiceRecitation.ts), and [`src/components/hifz/HifzPlayer.tsx`](file:///H:/gits/thai-quran-web/src/components/hifz/HifzPlayer.tsx). Even if the similarity score exceeds the threshold, the Ayah does not complete unless the user recites the final word or its root token.
  - **App**: Tightened `_tokenSliceReachesTargetEnd` and `evaluateAyahMatch` in [`lib/services/ctc_matcher.dart`](file:///H:/gits/thai-quran-app/lib/services/ctc_matcher.dart).

### Phase 9: Surah Selection & Range Picker Clarity (Web & App Done)
- [x] **Web Searchable Surah Picker Component** ([`src/components/shared/SearchableSurahSelect.tsx`](file:///H:/gits/thai-quran-web/src/components/shared/SearchableSurahSelect.tsx)):
  - Replaced raw 114-item `<select>` with rich searchable dropdown.
  - Auto-scrolls the currently selected Surah into the center of the list on open.
  - Includes quick category filters (`ทั้งหมด`, `ญุซอ์ 30`, `ยอดนิยม`, `มักกียะฮฺ`, `มะดะนียะฮฺ`) and `←` / `→` stepper buttons.
  - Integrated into [`HifzWizardModal.tsx`](file:///H:/gits/thai-quran-web/src/components/hifz/HifzWizardModal.tsx), [`HifzMushafRangePickerModal.tsx`](file:///H:/gits/thai-quran-web/src/components/hifz/HifzMushafRangePickerModal.tsx), and [`ModernGoalsView.tsx`](file:///H:/gits/thai-quran-web/src/components/goals/ModernGoalsView.tsx).
- [x] **Web Visual Mushaf Range Picker ("Select from Page") 2-Step Clarity** ([`src/components/hifz/HifzMushafRangePickerModal.tsx`](file:///H:/gits/thai-quran-web/src/components/hifz/HifzMushafRangePickerModal.tsx)):
  - Added interactive 2-Step Mode Pill Bar (`[1. จุดเริ่มต้น (Start)]` and `[2. จุดสิ้นสุด (End)]`).
  - First tap on the page directly sets the new **Start** verse without requiring users to click Reset first!
  - Visually distinguishes the Start Ayah (emerald badge/border) from the End Ayah (amber badge/border).
- [x] **Web Drawer & Browse Auto-Scroll**:
  - Drawer auto-scrolls to the current Surah on opening in both `'verse'` and `'surah'` tabs in [`SurahReader.tsx`](file:///H:/gits/thai-quran-web/src/components/SurahReader.tsx) and [`src/app/mushaf/[profileId]/page.tsx`](file:///H:/gits/thai-quran-web/src/app/mushaf/[profileId]/page.tsx).
  - [`BrowsePage.tsx`](file:///H:/gits/thai-quran-web/src/components/redesign/BrowsePage.tsx) persists and auto-restores scroll position and adds Juz 30 / Popular chips.
- [x] **App Alignment (Done)**:
  - [x] [`SurahPickerSheet`](file:///H:/gits/thai-quran-app/lib/widgets/surah_picker_sheet.dart) now uses an `ItemScrollController` (`ScrollablePositionedList`) to center `widget.selectedSurah` on open.
  - [x] [`HifzMushafRangePickerScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_mushaf_range_picker_screen.dart) now has an interactive 2-step `_selectionStep` (0 = Start, 1 = End) with a tappable Start/End pill bar; the first tap sets a new Start without needing "Reset", and the local raw Surah list was replaced with `SurahPickerSheet`.
  - [x] Adjacent Surah stepper buttons (`←` / `→`) added to the Surah cards in [`HifzWizardSetupScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_wizard_setup_screen.dart), [`HifzNewVersesSetupScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_new_verses_setup_screen.dart), and [`HifzReviewSetupScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_review_setup_screen.dart) via the shared `SurahSelectorTile` / `SurahStepButton`.
  - [x] Switching Surah inside the visual picker clears the previous Surah's range/highlights (previously stale verse numbers were carried across Surahs).
  - [x] Range picker interaction notes: first tap sets `Start` (and a single-ayah range), second tap sets `End` with auto-sorting; `Reset` returns to step 0; the `End` pill stays disabled until a `Start` exists.

### Phase 10: Home Showcase Correctness & Data-Integrity Fixes ([`lib/screens/home_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/home_screen.dart))
- [x] **Per-Account Quick Links**: Custom Quick Links now use per-scope SharedPreferences keys (`custom_quick_links_v2_<userId>` / `_guest`) instead of one global key. Links can no longer leak between accounts on a shared device or stay visible after sign-out. The legacy unscoped key is migrated once for the guest scope and then removed.
- [x] **Deletion-Safe Two-Way Quick-Link Sync**: Deletes write a local tombstone before the remote delete; queued tombstones are retried on the next sync; a per-device `lastSyncedAt` watermark drops links already synced before that disappeared from the server (deleted on another device) instead of re-upserting them. Merged remote results are now applied to the UI and persisted, and in-flight loads no longer clobber a newer local edit or cross an account switch.
- [x] **Archived Goals Cannot Be Reopened from Home**: `_latestVerseLastRead`, `_openLastRead` and the post-reader fallback all skip archived profiles, so "Continue Reading" cannot silently reactivate an archived goal.
- [x] **Bounded Community Preview Query**: [`TadabburRepository.fetchCommunityNotes`](file:///H:/gits/thai-quran-app/lib/data/tadabbur_repository.dart) gained an optional `limit`; the Home preview now requests 2 rows instead of downloading the entire public feed with its likes on every load/refresh.
- [x] **Init Failure Recovery**: `_initApp()` catches `QuranRepository.init()` errors and shows a localized error message with a **Retry** button instead of an endless loading spinner (the 8s Welcome fallback path).
- [x] **Featured Verse Day Rollover**: Home observes `WidgetsBindingObserver` lifecycle events and advances/refetches the daily featured verse when the app resumes on a new day, while preserving a manual shuffle within the same day.
- [x] **Race Guards**: A quick-links revision counter plus current-user checks prevent an in-flight load from overwriting a just-added/deleted link or applying one account's list after an account switch.
- [x] **Verification**: `flutter analyze lib` reports no issues in any edited file; `flutter test` passes all 50 tests.

### Phase 11: Surah Name Language Consistency
- [x] **Root cause**: [`BrowseScreen`](file:///H:/gits/thai-quran-app/lib/screens/browse_screen.dart) used `QuranRepository.getSurahName()`, whose global `globalIsThaiName` flag was derived from `effectiveLanguageCode` (the *translation* language), while the Hifz screens used `settings.languageCode` (the *UI* language). With the UI set to Thai but an English/Malay primary translation, Browse rendered English names while Hifz rendered Thai names.
- [x] [`SettingsProvider._syncGlobalState`](file:///H:/gits/thai-quran-app/lib/providers/settings_provider.dart#L466-L470) now derives the flag from `_languageCode`, so every `getSurahName()` caller (Browse, Hifz mastery list, reader titles) follows the app language consistently.
- [x] **Single source of truth**: added pure `surahDisplayName(id, isThai:)` and `surahNamePair(id)` helpers to [`offline_surah_names.dart`](file:///H:/gits/thai-quran-app/lib/data/offline_surah_names.dart). Browse, the Hifz landing grid, the Hifz mastery list, `SurahPickerSheet`/`SurahSelectorTile`, the wizard calligraphy cards and the Home hero/quick links/featured/community cards now all resolve names through them. `QuranRepository.getSurahName()` is now a thin wrapper over the resolver; the legacy `globalIsThaiName` static remains only as the default for callers that cannot pass `isThai`.
- [x] [`SurahPickerSheet`](file:///H:/gits/thai-quran-app/lib/widgets/surah_picker_sheet.dart) and [`SurahSelectorTile`](file:///H:/gits/thai-quran-app/lib/widgets/surah_picker_sheet.dart#L362) now lead with the UI-language name (Thai in Thai UI, English in English UI) and show the other language as the secondary line; the Hifz wizard calligraphy cards and mastery action sheet follow the same rule.
- [x] Added [`test/surah_name_resolver_test.dart`](file:///H:/gits/thai-quran-app/test/surah_name_resolver_test.dart) covering language selection, the Thai/English pair, unknown-ID fallbacks and the `getSurahName` wrapper.
- [x] **Shared Hifz mastery card**: extracted [`SurahMasteryCard`](file:///H:/gits/thai-quran-app/lib/widgets/surah_mastery_card.dart), now used by both [`HifzLandingScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_landing_screen.dart) and [`HifzMasteryListScreen`](file:///H:/gits/thai-quran-app/lib/screens/hifz_mastery_list_screen.dart). Status semantics unified to **mastered = `newVersesCompleted && reviewCount >= 3`**; in-progress = not mastered but completed or reviewed. The mastery list's filters, stats pill and action-sheet badge now use the same `SurahMasteryCard.isMasteredRecord` / `isInProgressRecord` helpers, and the standalone screen is now bilingual (it previously used hard-coded English labels).

---

## 3. Architecture & Visual Blueprint Reference

```mermaid
flowchart TD
    subgraph Shell["Top Bar + 5 Bottom Tabs (HomeScreen)"]
        Top["Top AppBar: iQra Logo • Search 🔍 • Bookmarks 🔖 • Settings ⚙️"]
        B1["0. Home\n(Calm Showcase)"]
        B2["1. Goals\n(Meaning & Mushaf)"]
        B3["2. Browse\n(Surah • Juz • Page • Topics)"]
        B4["3. Hifz\n(Memorize & Review)"]
        B5["4. Profile\n(Library • Stats • Cloud Sync)"]
    end

    subgraph Readers["The 3 Core Experiences (Full-Screen)"]
        R1["Meaning Reader\n(ReadingScreen)"]
        R2["Mushaf Reader\n(MushafReaderScreen)"]
        R3["Hifz Player\n(HifzMemorizeScreen)"]
    end

    B1 -->|"Continue / Quick Surah / Daily Ayah"| R1 & R2
    B1 -->|"จัดการเป้าหมาย →"| B2
    B2 -->|"Continue Goal / 1-Click Preset"| R1 & R2
    B3 -->|"Pick Surah / Juz / Page / Topic"| R1 & R2 & R3
    B4 -->|"New Verses / Review / 114-Surah Grid"| R3
    Top -->|"Settings ⚙️"| UnifiedSettings["SettingsScreen (4 Tabs)\nAppearance • Reader • Translations • Hifz & Controls"]
    B4 -->|"Input Mode Pill ⚙"| UnifiedSettings
```

---

## 4. Optional Next Steps / Future Polish
- [ ] **Visual QA on Device / Emulator**: Test light and dark mode transitions across all 5 tabs and verify tablet/landscape responsiveness (especially the new 2-step range picker pill bar and Surah steppers on 360 dp screens).
- [ ] **Consolidate Legacy Notes Files**: Evaluate whether legacy [`lib/screens/notes_screen.dart`](file:///H:/gits/thai-quran-app/lib/screens/notes_screen.dart) is still needed anywhere or can be deprecated in favor of `BookmarksScreen(initialTab: 2)` and `TadabburCommunityScreen`.
- [x] **Git Commit**: Committed the verified changes on `feat/ux-redesign-aligned` as `f395693`.
- [ ] **Push to Origin**: Push `feat/ux-redesign-aligned` when ready.
