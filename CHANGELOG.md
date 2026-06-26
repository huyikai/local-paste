# Changelog

## [1.0.8] — 2026-06-26

### 🐛 Fixes

- Fix crash on launch: CI was not copying `LocalPaste_LocalPaste.bundle` into .app, causing `Bundle.module` resource lookup to fail

## [1.0.7] — 2026-06-26

### ✨ New Features

- **Liquid Glass UI** — panel uses NSVisualEffectView frosted glass with rounded corners 16, hidden title bar, all components styled with material backgrounds
- **Three-tier keyboard navigation** — Search ↔ Group Filter ↔ List, freely switch focus between layers
- **Group filter keyboard control** — `←/→` to switch chip, `↑` to search, `↓` to list; list auto-scrolls to top on filter change
- **Item detail info** — each row shows metadata: text (chars/words/lines/size), color (HEX/RGB), image (resolution/format/size), files (name/count/size)
- **Update checker** — GitHub Releases API, auto-check on launch + every 24h, notification only on new version
- **About tab** — in Settings with dynamic version number from Bundle, GitHub link, and manual update check
- **History retention setting** — keep forever, or 1/7/30/90/365 days, auto-prune on insert
- **Storage size display** — shows current history.json file size in Settings
- **Create new group** — directly in Settings (previously only via pinning an item)
- **Rename group** — tap pencil icon next to group name in Settings
- **Delete group confirmation** — confirmation dialog before unpinning all items
- **Reorder groups** — up/down buttons in Settings for custom group order
- **Delete older than** — batch delete items older than N days

### 🔧 Improvements

- **Larger UI** — panel 420×580 → 480×640, icon 16×16 → 28×28, fonts increased, generous spacing throughout
- **Sharper app icons** — source icons rendered at 64×64 PNG (was 16×16 TIFF) with `.interpolation(.high)`
- **Selection style** — switched from fill to 5px accent border, color items display original color, uniform row height 64pt
- **Context menu paste** — fixed: now triggers full paste flow (copy + Cmd+V) instead of only copying
- **Paste target display** — panel footer shows which app the paste will go to
- **Search bar UX** — not focused on open, visual state always matches focus state, defocus on item/footer click
- **Settings panel** — grouped form style with SF Symbol section headers

### 🐛 Fixes

- Group filter focus ring clipping at edges
- Selection highlight persisting after leaving list
- Focus index mismatch when returning from list to group filter
- List not scrolling to top after group filter switch

---

## [1.0.6] and earlier

Initial release with core clipboard history features.
