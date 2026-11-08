## Git Synchronization (Mandatory)
- **Source of Truth**: The remote repository on GitHub (origin) is ALWAYS the authoritative source of truth.
- **Pre-Action Requirement**: Before starting ANY task, analysis, script run, or code edits, ALWAYS run git pull first to synchronize with the latest remote state.
- Never make changes or base decisions on stale local code.

# Thai Islamic Terminology Standard
When generating or modifying Thai UI strings, navigation, labels, tooltips, or i18n entries, always follow the standard transliteration:
- `ซูเราะฮฺ` (not ซูเราะห์ / สูเราะห์ / ซูเราะฮ์ / สูเราะฮฺ)
- `อายะฮฺ` (not อายะห์ / อายะฮ์ / โองการ)
- `ญุซอ์` (not ยุซ / ยุซอ์ / ญุซ)
- `ฮิซบฺ` (not ฮิซบ / ฮิสบ์ / ฮิซบ์)
- `ซัจญ์ดะฮฺ` (not ซัจดะห์ / ซัจดะฮฺ / ซัจญ์ดะฮ์)
- `มักกียะฮฺ` (not มักกีย์ / มักกียะฮ์)
- `มะดะนียะฮฺ` (not มะดะนีย์ / มะดะนียะฮ์)
- `บิสมิลลาฮฺ` (not บิสมิลลาห์ / บิสมิลลาฮ์)
- `มุศหัฟ` (not มุสฮัฟ / มุศฮัฟ / มุสฮะฟ)
- `ตดับบุร` (not ตะดับบุร)

# Anti-AI Editorial Manuscript Design System & Theme Standards (STRICT MANDATORY)
Whenever creating, modifying, redesigning, or refining UI components, screens, or styling, you **MUST ALWAYS** strictly follow the Anti-AI Editorial Manuscript design system aligned 1:1 with `thai-quran-web/docs/DESIGN_STANDARDS.md`:

## 1. Color Palette System (`AppThemeColors` via `context.appColors`)
- **Primary Brand (Meaning Mode)**: Deep Manuscript Jade `#0E5A4A` (Hover: `#0A4437`, Soft: `#EAF2EE`, Border: `#B7D4C7`; Dark Primary: `#4A9E89`)
- **Secondary / Mushaf Gold**: Classic Manuscript Gold `#8A6530` (Hover: `#735424`, Soft: `#F6EFE3`, Border: `#D7C299`; Dark Gold: `#CCA252`)
- **Canvas Background**: Warm Parchment `#FBF9F5` (Dark: `#131210`)
- **Card Surface**: Pure White `#FFFFFF` (Dark: `#1C1B18`)
- **Surface Muted**: `#F7F5EE` (Dark: `#24231F`)
- **Border Soft**: `#E8E3D7` (Dark: `#2E2C27`)
- **Text Strong**: `#1C2520` (Dark: `#FAF6EE`)
- **Text Body (`foreground`)**: `#42524A` (Dark: `#D8D4CD`)
- **Text Muted**: `#708078` (Dark: `#96928A`)
- **Danger / Errata**: Muted Brick `#A34C43` (Soft: `#FAF0EE`; Dark: `#D97777`)

## 2. Forbidden AI-Style Clichés (DO NOT USE)
- **NO foreign or saturated hues**: Never use Material/Tailwind `Colors.blue`, `Colors.blueGrey`, `Colors.indigo`, `Colors.purple`, `Colors.cyan`, `Colors.teal`, `Colors.orange`, or radioactive neon greens (`#15803D`, `Colors.green`).
- **NO decorative AI artifacts**: Never add multi-stop `LinearGradient` hero cards, blurred glow blobs, dot-grid overlays, pulsing glow rings, or colored drop shadows (`BoxShadow`).
- **NO puffy `BorderRadius.circular(20)` / `24` / `28` containers**: Standardize cards and modals on `AppTheme.radius` (`12.0`, equivalent to `rounded-xl`) and badges/chips on `AppTheme.radiusSm` (`8.0`, equivalent to `rounded-lg`), with `1px solid context.appColors.borderSoft` hairline borders.
- **NO `FontWeight.w900` or `FontWeight.w800` on Thai text**: Thai headings use `FontWeight.w700` (`bold`) and labels/buttons use `FontWeight.w600` (`semibold`). Heavy weights (`w800`/`w900`) cause Thai upper/lower vowel and tone marks to collide.

## 3. Execution Workflow
- Before rewriting a file, output a quick 3-bullet visual plan explaining how you will structure the UI blocks.
- Run `flutter analyze` and `flutter test` to verify changes.
