# LocalPaste 🗂️

A lightweight, local-only clipboard history manager for macOS.

Monitor and search your clipboard history — all data stays on your machine. No subscriptions, no cloud, no App Store.

## Features

- **All pasteboard types** — text, rich text (RTF/RTFD), HTML, images, PDF, file URLs, colors
- **Menu bar app** — click the clipboard icon or press `⌥⌘V`
- **Keyboard navigation** — `↑↓` to move, `Enter` to paste, `Space` to preview, `Esc` to close
- **Type-to-search** — start typing to filter (no click needed)
- **Rich preview** — HTML/RTF rendered with formatting in history list and preview panel
- **Pin items** — keep important clips at the top
- **Paste as plain text** — `⌘⇧V` or right-click
- **Persistent history** — JSON file in `~/Library/Application Support/LocalPaste/`
- **Configurable limit** — 50–2000 items, launch at login
- **100% offline** — no internet, no tracking, no account

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

```bash
git clone https://github.com/huyikai/local-paste
cd local-paste
make install        # Build, sign, install to /Applications
```

Open `/Applications/LocalPaste.app` — clipboard icon appears in menu bar.

## Usage

| Action | Shortcut |
|---|---|
| Open / close panel | Click menu bar icon or `⌥⌘V` |
| Navigate items | `↑` `↓` |
| Paste selected | `Enter` |
| Preview item | `Space` (toggle) |
| Search history | Type any character |
| Exit search mode | `Esc` |
| Close panel | `Esc` or click outside |
| Pin / Unpin | Pin button or right-click |
| Paste without formatting | `⌘⇧V` or right-click |

### Auto-paste (`⌘V` after Enter)

`Enter` copies to clipboard. To auto-paste into the active app:

1. Press `Enter` on any item → follow the prompt
2. Enable **LocalPaste** in System Settings → Privacy & Security → Accessibility
3. Restart LocalPaste

## Build from source

```bash
make build    # Release build
make app      # .app bundle
make install  # .app → /Applications
make run      # Run from CLI
```

## License

MIT
