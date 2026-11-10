# Platform Services - Mobile Quick Reference

Last updated: 2026-11-10

The canonical cross-platform inventory is in the web repository:

**`thai-quran-web/docs/SERVICES.md`**

That document covers Supabase, Vercel, Fly.io, Quran Foundation, Firebase, Google/Apple sign-in, app-store billing, GitHub, and the shared operational/security rules.

This page is a short mobile-focused pointer so app contributors can find the same source of truth.

## App-specific services

| Service | Used for | Configuration |
|---|---|---|
| Supabase | Auth, database sync, RLS, OTA content storage | Supabase URL and public key in the app; service-role key must remain server-side |
| Firebase | Firebase Core initialization; Analytics dependency | `lib/firebase_options.dart`, project `iqra-quran-project` |
| Google Sign-In | Native Google authentication | `google_sign_in` plus Supabase OAuth |
| Apple sign-in | Apple authentication | Supabase `OAuthProvider.apple` |
| Quran Foundation | Quran pages, fonts, word-by-word data, audio metadata | `QURAN_FOUNDATION_*` build-time `--dart-define` values |
| Quran.com API | Quran text, translations, footnotes, search fallback | Direct HTTPS calls |
| Quran audio CDNs | Verse and word audio playback | `audio.qurancdn.com`, `everyayah.com`, `verses.quran.foundation` |
| Google Fonts | Thai/Arabic/Latin typography | `google_fonts` package |
| GitHub | Source, release assets, notification icon fallback | `raw.githubusercontent.com` |
| Apple App Store / Google Play | Distribution and in-app tips | StoreKit / Google Play Billing |

## Local runtime dependencies

- ONNX Runtime with the bundled Tilawa model for on-device recitation recognition
- SQLite `quran_offline.db` for offline Quran text and translations
- SharedPreferences for local settings, caches, and guest data
- Bluetooth LE for the optional physical remote control

## Security notes

- Quran Foundation credentials are supplied through build-time `--dart-define` values. The tracked `env/` JSON files must not remain the long-term source of truth; rotate those credentials and move them to CI secrets.
- Never place the Supabase service-role key, GitHub token, or admin session secret in the mobile app.
- For service ownership, environment variables, deploy steps, and known gaps, use the canonical document linked above.
