# Thai Quran App Behavior Spec

Last updated: 2026-06-28

This document is the living contract for the Flutter app. It describes what the app is, what it can do today, and which behavior should eventually be brought over to `thai-quran-web`.

The goal is to keep polishing the app against one clear model before copying the flow into the web repo.

## Product Shape

Thai Quran is a mobile-first Quran reading app focused on Thai readers, with optional English support. The app should feel like a calm reading workspace, not a social feed or a heavy study dashboard.

The app currently supports:

- Reading Quran by surah and juz.
- Continuing from the current reading position.
- Free Read for open-ended browsing and reading.
- Created reading profiles for bounded goals.
- Bookmarks / saved verses.
- Private tadabbur notes and community tadabbur entry points.
- Reading display settings.
- Local guest use without sign-in.
- Supabase sign-in and sync for logged-in users.
- Local-first persistence through `SharedPreferences`.

The Mushaf page-by-page reader is visible as a future feature, but is not implemented yet.

## Main Navigation

The home screen has three primary areas:

- `Read Space`: the main workspace for continuing reading, profile actions, bookmarks, notes, and tadabbur.
- `Surah / Juz`: browse mode for opening a specific surah or juz.
- `Mushaf Read`: placeholder for a future traditional Mushaf view.

The profile button opens the reader profile/account area. The theme button toggles dark mode quickly.

## Reading Model

The app has two different reading ideas:

- **Free Read**: open-ended reading. It can point anywhere in the Quran.
- **Created profiles**: named reading plans with a start point and optional target point.

The reader decides which profile is used through `LocalReadingProvider`.

When the reading screen opens without a specific surah, it loads the active profile's current verse. If no usable local profile is available, it falls back to the older `ProgressProvider` state.

When a specific surah / verse is opened:

- If the read was opened from the browse flow, `saveToFreeReadOnly` is true and progress is attached to Free Read.
- Otherwise, the app checks whether the requested verse is inside the active profile.
- If the requested verse is outside the active bounded profile, the app switches to Free Read and saves that verse there.
- If the requested verse is inside the active bounded profile, the active profile remains active.

For bounded profiles, the reading screen only shows verses inside the profile range. Free Read and unbounded profiles show the whole surah.

## Free Read Rules

Free Read is the default open reading state.

Current rules:

- Each user context should have one Free Read profile.
- Guest users use the `local` user context.
- Logged-in users use their Supabase user id.
- Legacy `main_read` / `Main Read` values are normalized to Free Read.
- Duplicate Free Read profiles are deduplicated on local load, keeping the oldest one.
- Free Read is not editable, archivable, or deletable from the profile UI.
- Free Read has no target range.
- Free Read can store current progress anywhere in the Quran.

Current UI behavior:

- If there are active custom profiles, the active profile list hides Free Read.
- If there are no active custom profiles, Free Read appears as the available reading profile.
- Browse mode opens readings as Free Read so casual navigation does not accidentally move a bounded plan.

Design intent:

- Free Read should feel like the user's general reading lane.
- It should not feel like a hidden custom profile.
- Created profiles should be for intentional goals.

## Created Profile Rules

Created profiles are user-defined reading goals.

Current rules:

- A profile has a name, slug, start verse, current verse, and optional target verse.
- A profile may also keep plan metadata such as `planMode`, `startJuz`, and `targetJuz`.
- The app allows up to 5 active reading profiles.
- Archived profiles do not count as active reading profiles.
- Free Read is excluded from archived profile lists.
- Editing a profile resets its current verse to its start verse.
- Deleting, editing, and archiving are blocked for Free Read.
- If an active profile is deleted or archived, the app selects the latest read remaining profile when possible.
- If a loaded bounded profile has current progress outside its range, progress is reset to the profile start.

Plan modes currently recognized by the shared contract:

- `by_juz`
- `by_surah`
- `by_ayat`
- `custom`

Design intent:

- Profiles should be few, intentional, and easy to reason about.
- A profile should never silently track reading outside its target range.
- The active profile should represent the user's current goal, while Free Read handles exploration.

## Local Storage Rules

The app stores the local reading system under:

`thai_quran_local_reading_store_v1`

The local store contains:

- active profile id
- profiles
- bookmark categories
- bookmarks
- recent readings

Progress updates are disk-first:

- The app prepares the updated profile state.
- It writes the new reading timestamp and serialized local store to `SharedPreferences`.
- Only after the write succeeds does it update in-memory state and notify listeners.
- If local persistence fails, the app shows a storage failure message and avoids mutating in-memory progress.

This is important because reading progress should not appear saved unless it actually survives app restart.

## Supabase Rules

The app can be used without sign-in. Supabase adds account sync, not basic app access.

On sign-in:

- Supabase auth state is observed by providers.
- User defaults are bootstrapped.
- Local bookmarks and guest profiles are pushed to the signed-in account.
- Remote bookmarks, recent readings, profiles, settings, and reading state are fetched.
- Local and remote profile progress are reconciled using timestamps.
- Reading state sync chooses the remote state only if it is newer than local state.

On sign-out:

- Guest/local profiles are preserved.
- A guest default Free Read profile is ensured.
- The active profile is reset to a local guest profile.

Profile sync currently uses the legacy `user_reading_profiles` table shape:

- `profile_name`
- `current_surah`
- `current_ayah`
- `last_read_at`

The newer shared contract also defines richer `reading_profiles` rows with names, slugs, ranges, plan metadata, archived state, and sort order. The app is moving toward that cleaner model, but still carries compatibility behavior.

## Settings Rules

Settings are local-first and sync to Supabase when a user is signed in.

Current settings include:

- dark mode
- reading display mode
- Arabic font size
- translation font size
- theme color, currently normalized to blue
- web host URL for development
- primary translation slot
- optional secondary translation slot

Reading display modes:

- `quran_only`
- `translation_only`
- `quran_translation`

Translation slots:

- primary translation is required
- secondary translation is optional
- valid IDs are `thai_v3`, `thai_v2`, and `english`
- if the primary changes to match the secondary, the secondary is cleared
- if the secondary is set to the current primary, the change is rejected

Settings sync compares `updated_at` values. If local settings are newer than remote, local settings are pushed to Supabase. Otherwise, remote settings are applied locally.

## Bookmarks And Recent Readings

Bookmarks are stored locally and synced for signed-in users.

Current behavior:

- A default `Saved Verses` category is ensured.
- Legacy `manual_bookmarks` are migrated into the local store.
- Guest bookmarks are pushed to Supabase on sign-in.
- Remote bookmarks replace the signed-in user's bookmark list locally.

Recent readings:

- The app keeps recent readings locally.
- The default limit is 20.
- A recent reading may be tagged with a profile id only if the verse is inside that profile.
- Recent reading sync is debounced before writing to Supabase.

## Notes And Tadabbur

The app includes private and community tadabbur entry points.

Current contract-level behavior:

- Personal notes can be migrated from legacy verse-keyed local notes.
- Tadabbur notes have visibility values of `private` or `public`.
- Private and community tadabbur screens can open a verse in the reader.

This area still needs product polish, especially around how notes, reflections, favorites, and community behavior should be named and grouped.

## Design Principles

The current app direction should stay:

- Calm and reader-first.
- Profile behavior should be understandable from the UI.
- Free Read should be obvious enough to trust, but not noisy.
- Settings should expose useful reading controls, not old compatibility details.
- Local use should feel complete, not like a broken logged-out mode.
- Sync should be helpful and quiet.
- Web should copy the simplified mental model, not every mobile UI detail.

## Current Polish Targets

Before migrating the flow to web, the Flutter app should be polished in these areas:

- Make the Free Read and custom profile relationship visually clearer.
- Finish the profile creation/editing experience.
- Decide final labels for Read Space, Free Read, profiles, notes, favorites, and tadabbur.
- Confirm whether `reading_profiles` should replace the older `user_reading_profiles` path.
- Tighten account/profile sync behavior after sign-in and sign-out.
- Simplify settings UI around reading mode and translation slots.
- Finish or hide incomplete Mushaf behavior until it is ready.
- Review Thai/English copy and encoding issues in older screens.

## Web Migration Contract

When `thai-quran-web` is ready for the redesign, it should implement the app behavior in this order:

1. Shared Quran contract constants and verse refs.
2. Free Read as the default open reading lane.
3. Created profile rules and 5 active profile limit.
4. Profile range filtering in the reader.
5. Browse flow saving to Free Read instead of changing a bounded active profile.
6. Local-first reading state and recent readings.
7. Supabase account sync and timestamp reconciliation.
8. Settings model, especially reading display mode and translation slots.
9. Bookmarks and notes behavior.
10. Visual design inspired by the polished app, adapted for web layout.

The web repo should not copy mobile-specific navigation blindly. It should copy the rules first, then design a web-native layout around them.
