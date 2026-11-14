# Live Architecture & Upgrade Guide: `thai-quran-web` & `thai-quran-app`

> [!IMPORTANT]
> **LIVING SOURCE OF TRUTH MANDATE (READ BEFORE ANY UPGRADE)**
> This document (`LIVE_ARCHITECTURE_AND_UPGRADE_GUIDE.md`) is the **Live Source of Truth** for how `thai-quran-web` (Website), `thai-quran-app` (iOS & Android App), `thai-quran-master-data` (Canonical Data Hub), and Supabase work together.
> **Mandatory Rule for All AI Agents & Developers**: Any time you upgrade, add, remove, or modify a font, translation, data pipeline, storage key, API endpoint, audio source, or Supabase table/sync rule in either repository, you **MUST** update this file in the same commit/session.

---

## 1. System Topology & Repositories

| Repository / Service | Local Path | Stack & Runtime | Production Target | Role |
| :--- | :--- | :--- | :--- | :--- |
| **`thai-quran-master-data`** | `/Users/admin/Documents/gits/thai-quran-master-data` | SQLite (`sqlite/thai_quran_master.db`), JSON, CSV, Python build scripts | GitHub (`doxman13/thai-quran-master-data`) | **Single Canonical Source of Truth** for all Quran Arabic text, Thai translations (`thai_v3`), WBW glosses, footnotes, Al-Mukhtasar tafsir, ayah themes, topics, and mutashabihat. |
| **`thai-quran-web`** | `/Users/admin/Documents/gits/thai-quran-web` | Next.js `16.2.9` (App Router), React `19.2.4`, TypeScript `5`, Tailwind v4 | Vercel (`https://quran-th.com`) | Public web reader, Mushaf reader, Hifz studio, search, and admin moderation portals. |
| **`voice-search-api`** | `/Users/admin/Documents/gits/thai-quran-web/services/voice-search-api` | Fastify (Node.js) + `@tilawa/core` + `onnxruntime-node` | Fly.io (`https://thai-quran-voice-api.fly.dev`, `sin`) | Server-side Quranic Arabic voice search fallback. |
| **`thai-quran-app`** | `/Users/admin/Documents/gits/thai-quran-app` | Flutter (`^3.12.0`), Provider, `sqflite` (SQLite), `just_audio`, `onnxruntime_v2` | iOS App Store & Google Play (`com.abuzayd.iqra`) | 100% offline-capable native mobile reader, Mushaf, Hifz AI recitation tracker, and BLE smart-ring counter. |
| **Supabase** | Shared Cloud Backend | PostgreSQL + Supabase Auth + Realtime + Storage (`app-content`) | `https://atouicznofujiwqavxer.supabase.co` | Cross-device authentication, reading goals, bookmarks, Tadabbur reflections, Hifz logs, and mobile OTA content delivery. |

---

## 2. Where Quran Fonts Are Loaded From

### 2.1 Website (`thai-quran-web`)
1. **Static Base Fonts (`src/app/layout.tsx:12-22`, `src/app/globals.css:1, 86-117`)**:
   - **`UthmanicHafs` (Default Meaning-Mode & WBW Arabic Script)**:
     - Preloaded via `next/font/local` from [`public/fonts/UthmanicHafs.ttf`](file:///Users/admin/Documents/gits/thai-quran-web/public/fonts/UthmanicHafs.ttf) (`--font-uthmanic-hafs`).
     - Fallback `@font-face` in `globals.css:86-93` points to `/fonts/UthmanicHafs.ttf` and remote WOFF2 `https://verses.quran.foundation/fonts/quran/hafs/uthmanic_hafs/UthmanicHafs1Ver18.woff2`.
   - **`Tajweed` (DigitalKhatt Color/Tajweed Script)**:
     - Loaded via `next/font/local` and `@font-face` from [`public/fonts/DigitalKhattQuranicV1.otf`](file:///Users/admin/Documents/gits/thai-quran-web/public/fonts/DigitalKhattQuranicV1.otf) (`--font-tajweed`).
   - **`QcfSurahName` (Surah Header Calligraphy Ligatures)**:
     - Loaded via `@font-face` in `globals.css:103-109` from [`public/fonts/qcf_quran/surah-name-v2.woff`](file:///Users/admin/Documents/gits/thai-quran-web/public/fonts/qcf_quran/surah-name-v2.woff) (renders ligatures `surah001`..`surah114`).
   - **UI & Thai Fonts**:
     - Loaded via Google Fonts in `globals.css:1`: `Noto Sans Thai`, `Inter`, `Amiri Quran`, and `Scheherazade New`.
2. **Dynamic Per-Page Mushaf Fonts (`src/lib/quranFoundationClient.ts:69-167`)**:
   - Uses the browser `FontFace` API (`document.fonts.add(fontFace)`) with in-memory deduplication (`loadedFontKeys` / `loadingFontPromises`) and **adjacent-page prefetching (`page N`, `N+1`, `N-1`)**:
     - **Mushaf ID `2` (Madinah 1405H) & ID `20` (Madinah 1421H)**: Dynamically loads `qcf_v1_p${pageNumber}` from local static files `public/fonts/qcf_v1/p1.ttf` .. `p604.ttf` (`/fonts/qcf_v1/p${pageNumber}.ttf`, cached immutable 1 year).
     - **Mushaf ID `21` (Tajweed QUL)**: Renders words using `Tajweed` (`/fonts/DigitalKhattQuranicV1.otf`) with color rule spans, and simultaneously loads `qcf_v1_p${pageNumber}` (`/fonts/qcf_v1/p${pageNumber}.ttf`) so end-of-ayah markers (`charTypeName === 'end'`) use authentic Medina page glyphs.
     - **Mushaf ID `19` (Hidden COLRv1 V4 Tajweed)**: Loads `p${pageNumber}-v4` from `https://verses.quran.foundation/fonts/quran/hafs/v4/colrv1/ttf/p${pageNumber}.ttf`.

### 2.2 Mobile App (`thai-quran-app`)
1. **Static Bundled Fonts (`pubspec.yaml:88-97`)**:
   - `UthmanicHafs`: [`assets/fonts/UthmanicHafs.ttf`](file:///Users/admin/Documents/gits/thai-quran-app/assets/fonts/UthmanicHafs.ttf) — Meaning Mode, WBW, and general Arabic text.
   - `Tajweed`: [`assets/Tajweed/DigitalKhattQuranicV1.otf`](file:///Users/admin/Documents/gits/thai-quran-app/assets/Tajweed/DigitalKhattQuranicV1.otf) — Tajweed Mushaf (`id = 21`) and Tajweed verse rendering.
   - `QcfSurahName`: [`assets/fonts/surah-name-v2.ttf`](file:///Users/admin/Documents/gits/thai-quran-app/assets/fonts/surah-name-v2.ttf) — Surah calligraphy headers.
   - Thai & Latin UI fonts (`Sarabun`, `Prompt`, `NotoSansThai`, `IBM Plex Sans Thai`, `Amiri`, `ScheherazadeNew`, `Lateef`) are resolved via `google_fonts` and prewarmed in [`lib/theme/app_theme.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/theme/app_theme.dart).
2. **Dynamic Per-Page Mushaf Fonts (`lib/data/quran_foundation_repository.dart:1330-1425`)**:
   - **Bundled 604 QCF V1 Fonts (`assets/qcf_v1_fonts/p1.ttf` .. `p604.ttf`)**:
     - `DynamicFontLoader._loadLocalAssetFont()` (`lines 1369-1382`) loads `assets/qcf_v1_fonts/p$page.ttf` into Flutter's engine at runtime via `FontLoader('QCF_V1_P$page')` with zero network requests.
   - **Remote Font Fallback**:
     - For non-bundled Mushaf variants, `DynamicFontLoader` downloads the font from `https://verses.quran.foundation/fonts/quran/hafs/...` and caches it permanently in `${getApplicationSupportDirectory()}/fonts/$fontFamily.$ext`.

---

## 3. Where Quran Text, Translations, WBW, Tafsir, Themes & Audio Are Loaded From

### 3.1 Master Comparison Table (Web vs. App)

| Content Domain | Canonical Master Source (`thai-quran-master-data`) | Website (`thai-quran-web`) Source & Loader | Mobile App (`thai-quran-app`) Source & Loader |
| :--- | :--- | :--- | :--- |
| **Arabic Verse Text (Uthmani)** | `sqlite/thai_quran_master.db` -> `quran_verses.text_uthmani` | `/public/quran_arabic.json` fetched & sanitized in [`src/lib/quranArabic.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/quranArabic.ts) | `assets/quran_offline.db` (`verses.text_uthmani`) via [`OfflineQuranDatabaseService`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/offline_quran_database_service.dart) |
| **604 Mushaf Pages & Glyph Lines** | QCF V1 1405H 15-line layout | `/public/mushaf/qcf_v1_pages/page_1.json`..`page_604.json` via [`src/lib/quranFoundationClient.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/quranFoundationClient.ts) | `assets/qcf_v1_pages/page_1.json`..`page_604.json` via [`QuranFoundationRepository`](file:///Users/admin/Documents/gits/thai-quran-app/lib/data/quran_foundation_repository.dart) |
| **Tajweed Color Rules** | QUL Hafs Tajweed markup | `/public/data/Tajweed/qul-hafs-tajweed.json` parsed by [`src/lib/tajweedService.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/tajweedService.ts) | `assets/Tajweed/qul-hafs-tajweed.json` + `verses.text_tajweed` parsed by [`lib/services/tajweed_service.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/tajweed_service.dart) |
| **Default Thai Translation (`thai_v3`)** | `quran_verses.translation_th_clean` & `json/thai_v3.json` | `src/data/thai_v3.json` via [`src/lib/translations/resolveVerseTranslation.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/translations/resolveVerseTranslation.ts) | `assets/quran_offline.db` (`verses.translation_th`) + `assets/thai_v3.json` + OTA via [`RemoteContentService`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/remote_content_service.dart) |
| **Other Built-in Translations** | `en_saheeh`, `en_hilali_khan`, `en_bridges`, `en_usmani`, `en_abdelhaleem`, `ms_basmeih` | `src/data/*.json` via [`resolveVerseTranslation.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/translations/resolveVerseTranslation.ts) | `assets/quran_offline.db` (`translation_en`, `translation_ms`) + `assets/en_*.json`, `assets/ms_basmeih.json` in [`QuranRepository`](file:///Users/admin/Documents/gits/thai-quran-app/lib/data/quran_repository.dart) |
| **Downloadable Extra Translations** | Quran.com v4 API (`api.quran.com/api/v4`) | Proxied via `/api/quran-foundation/translation` and stored in **IndexedDB** (`thai-quran-translations`, [`downloadStore.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/translations/downloadStore.ts)) | Downloaded per chapter from `api.quran.com` via [`TranslationDownloader`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/translation_downloader.dart) into SQLite **`translations.db`** |
| **Footnotes (`thai_footnotes`, etc.)** | `thai_footnotes` table & `json/thai_footnotes.json` | `src/data/thai_footnotes.json` & `en_*_footnotes.json` via [`src/lib/thaiFootnotes.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/thaiFootnotes.ts) | `assets/footnotes/*.json` loaded by [`FootnoteService`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/footnote_service.dart) + live API for downloaded translations |
| **Short Tafsir (Al-Mukhtasar)** | `tafsir_mukhtasar` table & `json/tafsir_thai_mokhtasar.json` | `src/data/tafsir_thai_mokhtasar.json`, `tafsir_eng_mokhtasar.json`, `indonesian-mokhtasar.json` via [`src/lib/shortTafsir.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/shortTafsir.ts) | `assets/quran_offline.db` (`verses.tafsir_th`) + `assets/tafsir_*_mokhtasar.json` + OTA key `mokhtasar_short_tafsir` |
| **Word-by-Word (WBW) (83,665 words)** | `wbw_words` table (`th`, `en`, `ms`, `root_arabic`, `transliteration`) | `/public/data/wbw/1.json`..`114.json` fetched per surah in [`src/lib/useWordByWord.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/useWordByWord.ts) | `assets/quran_offline.db` (`words` table) queried by `OfflineQuranDatabaseService.getVerseWords()` |
| **Ayah Themes & Topics** | `ayah_themes` & `quran_topics` tables | `src/data/reconciled_thai_quran_themes.json`, `qul_ayah_themes.json`, `topics.json` | `assets/quran_offline.db` (`qul_ayah_themes`, `topics`, `topic_verses`) + `assets/reconciled_thai_quran_themes.json` (OTA `quran_themes`) |
| **Triliteral Roots & Mutashabihat** | `wbw_words.root_arabic` & `mutashabihat` table | `src/data/roots_index.json`, `/public/data/root_forms.json`, `src/data/mutashabihat.json` | `assets/quran_offline.db` (`words.root_arabic`, `mutashabihat` table) |
| **Verse Audio Recitations (5 Reciters)** | Quran Foundation API + EveryAyah CDN | `/api/quran-foundation/audio` -> [`src/lib/useVerseAudio.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/useVerseAudio.ts) | `QuranFoundationRepository` + EveryAyah fallback -> [`MushafAudioProvider`](file:///Users/admin/Documents/gits/thai-quran-app/lib/providers/mushaf_audio_provider.dart) |
| **WBW Word Tap Audio** | QuranCDN WBW Audio | `https://audio.qurancdn.com/wbw/${sPad}_${vPad}_${wPad}.mp3` | `https://audio.qurancdn.com/$audioPath` (`lib/widgets/word_by_word_strip.dart:124-179`) |
| **AI Recitation / Voice Search Model** | Tilawa / FastConformer ONNX | `/public/tilawa/model_int8.onnx` (66MB Zipformer) in `CacheStorage` + Fly.io `thai-quran-voice-api` | `assets/models/fastconformer_full_mixed.onnx` extracted to `${supportDir}/fastconformer_full_mixed.onnx` (`lib/services/recitation_engine.dart`) |

---

## 4. How the Website (`thai-quran-web`) Works

### 4.1 App Router & Core Screens
- **`src/app/layout.tsx`**: Loads `UthmanicHafs` and `Tajweed` fonts, wraps the app in `<AppProvider>` (`src/context/AppContext.tsx`), and renders global navigation and audio player bars.
- **`src/app/page.tsx` (`HomeLaunchpad` / `SurahList`)**: Displays Continue Reading cards (Verse Goals & Mushaf Goals), Quick Links (system + custom user-pinned surahs), Streak & Daily Stats, and the 114 Surah / 30 Juz index.
- **`src/app/surah/[id]/page.tsx` (`SurahReader.tsx`)**: Meaning Mode reader. Supports Verse-by-Verse and Reading/Continuous display modes, up to 2 simultaneous translations (`primaryTranslationId`, `secondaryTranslationId`), interactive Word-by-Word (`useWordByWord.ts`), inline clickable footnotes (`thaiFootnotes.ts`), Al-Mukhtasar short tafsir drawer (`shortTafsir.ts`), Ayah themes, Mutashabihat (similar verses) indicators, and Tadabbur personal/public reflections.
- **`src/app/mushaf/[profileId]/page.tsx`**: 604-page Mushaf reader supporting Medina 1405H (`mushafId = 2`) and Tajweed QUL (`mushafId = 21`), page-range goals, page bookmarks, and verse bookmarks.
- **`src/app/hifz/page.tsx`**: Takrar Memorization & Review studio (`src/lib/hifz/hifzEngine.ts`) with hands-free Tilawa AI microphone tracking (`src/lib/tilawaRecitation.ts`).

### 4.2 State Management & Multi-User Local Storage Scoping
- `AppContext.tsx` is the central state container.
- All browser `localStorage` keys are scoped per user via [`src/lib/shared/userScope.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/shared/userScope.ts) (`<baseKey>:<userId>` when logged in, `<baseKey>:local` when guest) so multiple accounts on the same browser never overwrite or leak into one another.

---

## 5. How the Mobile App (`thai-quran-app`) Works

### 5.1 Bootstrap & Provider Architecture
- **Startup (`lib/main.dart:45-63`)**:
  1. `FootnoteService().init()` loads bundled footnote JSONs.
  2. `RemoteContentService.instance.cleanOnAppUpgrade()` clears stale OTA JSON files when `package_info_plus` detects an app version bump.
  3. `Firebase.initializeApp()` and `Supabase.initialize()` initialize cloud clients.
  4. `JustAudioBackground.init()` sets up lock-screen media playback notifications.
  5. `initializeDownloadService()` configures background translation downloads.
- **SQLite Versioned Offline Database (`lib/services/offline_quran_database_service.dart`)**:
  - `assets/quran_offline.db` is copied into the device database directory on first run or whenever `SharedPreferences` `offline_quran_db_version < _targetDbVersion` (currently **`41`**, `line 10`).
  - **CRITICAL UPGRADE RULE**: Whenever you rebuild `assets/quran_offline.db` with updated verses, WBW, topics, or themes, you **MUST increment `_targetDbVersion`** in `lib/services/offline_quran_database_service.dart:10` so existing users' devices overwrite their cached SQLite file on upgrade!

### 5.2 OTA Remote Content Updates (`lib/services/remote_content_service.dart`)
- Every 24 hours (`_checkCooldown = Duration(hours: 24)`), `WelcomeScreen` triggers `RemoteContentService.instance.updateAllIfDue()`.
- It queries Supabase table `public.app_content_versions` for active keys (`thai_v3`, `quran_themes`, `mokhtasar_short_tafsir`).
- If `remote.version > localVersion`, it downloads the JSON file from Supabase Storage bucket `app-content` into `${supportDir}/remote_content/` and, for `thai_v3`, runs `OfflineQuranDatabaseService.updateThaiTranslation()` to batch-update `verses.translation_th` inside `quran_offline.db`.
- *(Note: On `thai-quran-web`, OTA downloads from Supabase Storage are intentionally bypassed in `src/lib/supabase/remoteContent.ts:46-50` so web traffic serves static Vercel assets without consuming Supabase Storage bandwidth.)*

---

## 6. Cross-Device Database Sync Architecture (`Supabase`)

Both `thai-quran-web` and `thai-quran-app` connect to Supabase project `atouicznofujiwqavxer` (`https://atouicznofujiwqavxer.supabase.co`).

| Domain | Supabase Table(s) | Web Module | App Provider / Repo | Conflict Resolution Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Free Read (Meaning)** | `user_reading_state`, `reading_profiles` (`slug='free_read'`) | `src/lib/supabase/userReadingState.ts` | `LocalReadingProvider` | `furthest_unread_index = max(local, remote)`; `last_viewed_index` uses newer `updated_at` (clamped if >5m in future). |
| **Verse Reading Goals** | `reading_profiles`, `user_reading_profiles` (linked via `web_profile_id`) | `src/lib/supabase/readingProfiles.ts` | `LocalReadingProvider` | Matched by `id` / `web_profile_id` / `slug`. `furthest_unread_index = max(local, remote)`. Soft-delete tombstone `deleted_at` always wins and purges after 30 days. |
| **Meaning Recent Readings** | `recent_readings` | `src/lib/supabase/recentReadings.ts` | `LocalReadingProvider` | Keyed by `(user_id, surah_id, profile_id)`. Newer `read_at`/`updated_at` wins; top 20 retained. |
| **Mushaf Goals & Free Read** | `mushaf_profiles` | `src/lib/supabase/mushaf.ts` | `MushafReadingProvider` | Matched by `(mushaf_id, slug)`. `furthest_unread_page = max(local, remote)`, `last_viewed_page` by newer `updated_at`, `deleted_at` tombstone always wins. |
| **Mushaf Recent Readings** | `mushaf_recent_readings` | `src/lib/supabase/mushaf.ts` | `MushafReadingProvider` | Keyed by `(user_id, mushaf_id, recent_key)` where `recent_key` is `free:surah:<id>` or `profile:<uuid>`. Newer `read_at` wins. |
| **Verse Bookmarks** | `bookmark_categories`, `bookmarks` | `src/lib/supabase/bookmarks.ts` | `LocalReadingProvider` | Keyed by `(user_id, category_id, surah_id, verse_id)`. Deletion tombstones flushed before union merge. |
| **Mushaf Bookmarks** | `mushaf_page_bookmarks`, `mushaf_verse_bookmarks` | `src/lib/supabase/mushaf.ts` | `MushafReadingProvider` | Page bookmarks keyed by `(user_id, mushaf_id, page_number)`; verse bookmarks by `(user_id, mushaf_id, page_number, verse_key)`. |
| **Tadabbur Notes & Likes** | `tadabbur_notes`, `tadabbur_likes` + RPC `toggle_tadabbur_like` | `src/lib/supabase/tadabbur.ts` | `NotesProvider` / `TadabburRepository` | Keyed by `(user_id, surah_id, verse_id)`. Timestamp LWW (`updated_at`) + deletion tombstones (`deleted_note_keys_v1` / `quran_deleted_notes_meta`). |
| **Tadabbur UGC Moderation** | `tadabbur_reports`, `user_blocks` | `src/lib/supabase/tadabbur.ts` | `TadabburRepository` | Reports upserted on `(note_id, reporter_user_id)`; blocked user IDs synced via `user_blocks` + local storage fallback. |
| **Daily Streaks & History** | `user_reading_history` | `src/lib/supabase/readingHistory.ts` | `StatsProvider` | Additive union on `(user_id, read_date, verse_key)`. |
| **Completed Surahs** | `user_completed_surahs` | `src/lib/supabase/completedSurahs.ts` | `LocalReadingProvider` | Keyed by `(user_id, mode, surah_id)` with deletion tombstones (`_deletedCompletedReadSurahs`). |
| **Pinned Quick Links** | `custom_quick_links` | `src/lib/supabase/customQuickLinks.ts` | `HomeScreen` | LWW on `updated_at` + deletion tombstones. |
| **Hifz Progress & Logs** | `hifz_progress`, `hifz_history` | `src/lib/hifz/hifzRepository.ts` | `HifzRepository` | `new_verses_completed = local \|\| remote`, `review_count = max(local, remote)`, history deletion tombstones (`hifz_deleted_history_ids`), synced on login & app resume. |
| **User Settings** | `user_settings` | `src/lib/supabase/userSettings.ts` | `SettingsProvider` | LWW comparing local `settings_updated_at` vs remote `updated_at` (includes fonts, dark mode, translation slots, WBW toggle/lang, footnotes, Tajweed colors, reciter ID). |
| **Account Deletion** | RPC `public.delete_own_account()` | `src/context/AppContext.tsx` (`/profile`) | `SupabaseProvider.deleteAccount()` (`SettingsScreen`) | `SECURITY DEFINER` RPC deletes all user rows across every table (including public/anonymous Tadabbur notes) + `auth.users` record, followed by local storage/SQLite wipe. |

---

## 7. Step-by-Step Playbooks for Future Upgrades

### Playbook A: Updating Thai Translation (`thai_v3`), Footnotes, WBW, or Tafsir
Whenever a scholarly correction or typo fix is made to Quranic text, Thai translation, WBW, footnotes, or Al-Mukhtasar tafsir:
1. **Update Canonical Source (`thai-quran-master-data`)**:
   - Edit or run the compilation script in `/Users/admin/Documents/gits/thai-quran-master-data`:
     ```bash
     cd /Users/admin/Documents/gits/thai-quran-master-data
     python3 scripts/build_master_datasets.py
     python3 scripts/verify_master_datasets.py
     python3 scripts/export_db_for_web.py
     ```
2. **Propagate to `thai-quran-web`**:
   - Ensure updated JSON files are written to `thai-quran-web/src/data/` (`thai_v3.json`, `thai_footnotes.json`, `tafsir_thai_mokhtasar.json`, `reconciled_thai_quran_themes.json`) and `thai-quran-web/public/data/wbw/1.json`..`114.json`.
3. **Propagate to `thai-quran-app`**:
   - Copy updated JSONs to `thai-quran-app/assets/` (`thai_v3.json`, `assets/footnotes/thai_footnotes.json`, `tafsir_thai_mokhtasar.json`, `reconciled_thai_quran_themes.json`).
   - Rebuild `thai-quran-app/assets/quran_offline.db` and **increment `_targetDbVersion`** (e.g., from `41` to `42`) in [`lib/services/offline_quran_database_service.dart:10`](file:///Users/admin/Documents/gits/thai-quran-app/lib/services/offline_quran_database_service.dart#L10).
   - *(Optional Instant OTA for Mobile Users)*: Upload the updated JSON (`thai_v3.json`, `reconciled_thai_quran_themes.json`, or `tafsir_thai_mokhtasar.json`) to Supabase Storage bucket `app-content`, update `version` and `sha256` in `public.app_content_versions`, and mobile devices will pull it within 24 hours without an App Store / Play Store update.

### Playbook B: Adding or Updating a Downloadable Translation
1. **Web (`thai-quran-web`)**:
   - Add the translation metadata and Quran.com `resourceId` to [`src/lib/translations/hierarchy.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/translations/hierarchy.ts) and [`src/lib/translationLabels.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/translationLabels.ts).
   - Verify `/api/quran-foundation/translation?translationId=<resourceId>` returns all 6,236 verses and caches in IndexedDB (`src/lib/translations/downloadStore.ts`).
2. **App (`thai-quran-app`)**:
   - Add the translation entry to [`lib/shared/translation_hierarchy.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/shared/translation_hierarchy.dart) and [`lib/providers/settings_provider.dart`](file:///Users/admin/Documents/gits/thai-quran-app/lib/providers/settings_provider.dart).
   - `TranslationDownloader` (`lib/services/translation_downloader.dart`) will automatically support downloading it into `translations.db`.

### Playbook C: Adding or Modifying a Cross-Device Synced Feature
1. Write a new SQL migration in `thai-quran-web/supabase/migrations/<timestamp>_<name>.sql` with `ENABLE ROW LEVEL SECURITY` and explicit `auth.uid() = user_id` policies.
2. Mirror the schema documentation in `docs/SHARED_DATABASE_SCHEMA.sql` in both `thai-quran-web` and `thai-quran-app`.
3. On Web: Scope any new `localStorage` keys using `scopedStorageKey(baseKey, userId)` in [`src/lib/shared/userScope.ts`](file:///Users/admin/Documents/gits/thai-quran-web/src/lib/shared/userScope.ts) and wire sync into `syncAllWithSupabaseInternal` in `src/context/AppContext.tsx`.
4. On App: Wire sync into `_syncExternalProvidersWithAuth` and `_resumeSync` in [`lib/main.dart:144-220`](file:///Users/admin/Documents/gits/thai-quran-app/lib/main.dart#L144-L220), and ensure `delete_own_account` cleans up the new table.
5. Update **Section 6** of this `LIVE_ARCHITECTURE_AND_UPGRADE_GUIDE.md` file.

---

## 8. Upgrade Changelog (Living Log)

| Date | Author / Agent | Platform(s) | Summary of Upgrade |
| :--- | :--- | :--- | :--- |
| `2026-11-14` | Antigravity AI | Web + App + Master Data | Initialized `LIVE_ARCHITECTURE_AND_UPGRADE_GUIDE.md` as the central living architecture & upgrade reference alongside `LAUNCH_AND_AUDIT_PLAN.md`. |
| `2026-11-14` | Antigravity AI | Web + App + Supabase | Completed Phase 1–3 Launch & Sync Audit upgrades: added `delete_own_account()` RPC & UI (`SYNC-01`), fixed Web Mushaf bookmark sync & tombstones (`SYNC-02`), added App `user_completed_surahs` sync (`SYNC-03`), removed fake `1:1` rows from `user_reading_history` (`SYNC-04`), fixed App `NotesProvider` server UUID & tombstones (`SYNC-05`), unified Web/App `user_settings` & Hifz sync (`SYNC-06..08`), fixed Mushaf verse counts & `/profile` reports (`BUG-WEB-01..02`), added iOS `PrivacyInfo.xcprivacy` + `DEVELOPMENT_TEAM = Q79G7KWMQG` (`IOS-01..02`), configured Android release signing + `proguard-rules.pro` + optional BLE (`AND-01..03`), and added Tadabbur UGC moderation (`tadabbur_reports`, `user_blocks`), IAP policy compliance, and Privacy Policy links (`POL-01..03`). |
| `2026-11-14` | Antigravity AI (Flash) | App (`thai-quran-app`) | Removed duplicate legacy Mushaf floating translation card (`_TranslationPanel`) in `lib/screens/mushaf_reader_screen.dart` so long-pressing a verse exclusively opens the modern `_MushafVerseDetailSheet` meaning & tafsir modal. |
| `2026-11-14` | Antigravity AI (Flash) | Web (`thai-quran-web`) | Removed mobile-app-only settings from `src/app/settings/page.tsx`: "Keep Screen Awake / เปิดหน้าจอตลอดขณะอ่าน" (`keepAwake`) and "Offline Content / เนื้อหาออฟไลน์" (`showOfflineModal`). |
| `2026-11-14` | Antigravity AI (Flash) | App (`thai-quran-app`) | Removed web-only / dead settings and dead code: removed `webHostUrl` / `web_host_url`, `meaningDisplayMode` from `SettingsProvider` and `localization.dart`, and removed duplicate ~340-line `_AuthBottomSheetContent` widget in `lib/screens/settings_screen.dart` delegating directly to canonical `AuthBottomSheet`. |
