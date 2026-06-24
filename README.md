# LocalPaste 🗂️

A lightweight, local-only clipboard history manager for macOS.

Monitor and search your clipboard history — all data stays on your machine. No subscriptions, no cloud, no App Store.

## Features

- **Full format support** — text, rich text (RTF/RTFD), HTML, images, PDF, file URLs, colors, and any custom pasteboard type
- **Menu bar app** — click the clipboard icon or press `⌥⌘V` to open the floating history panel
- **Keyboard navigation** — `↑↓` to move, `Enter` to paste, `Space` to preview, `Esc` to close
- **Type-to-search** — just start typing to filter history (no need to click the search field)
- **Rich preview** — renders HTML/RTF with formatting; code blocks, tables, headings all styled
- **Pin items** — keep important clips at the top
- **Multi-select** — `⌘`-click to select multiple items for batch delete
- **Drag-to-reorder** — drag items to rearrange history
- **Paste as plain text** — `⌘⇧V` or right-click → Paste as Plain Text
- **Persistent history** — survives app restarts (JSON file in `~/Library/Application Support/LocalPaste/`)
- **Configurable** — set max history count (50–2000), launch at login
- **100% offline** — no internet access, no data collection, no account

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Quick start

```bash
git clone https://github.com/huyikai/local-paste
cd local-paste
make install        # Build, sign, and install to /Applications
```

Then open `/Applications/LocalPaste.app`. The clipboard icon appears in your menu bar.

### Manual

```bash
make run            # Build and run in foreground
make run-background # Build and run in background
make kill           # Stop the background process
```

## Usage

| Action | How |
|---|---|
| Open history | Click menu bar icon, or `⌥⌘V` |
| Navigate items | `↑` `↓` |
| Paste selected | `Enter` |
| Quick Look preview | `Space` (toggle on/off) |
| Search | Just start typing |
| Exit search | `Esc` |
| Close panel | `Esc` or click outside |
| Pin / Unpin | Click pin icon or right-click |
| Select multiple | `⌘`-click items |
| Delete selected | Right-click → Delete, or batch delete in footer |
| Paste as plain text | `⌘⇧V` or right-click → Paste as Plain Text |
| Drag to reorder | Drag any item |
| Settings | Right-click menu bar icon → Settings, or `⌘,` in panel |

### Auto-paste (⌘V after Enter)

To have `Enter` automatically paste into the active application, grant Accessibility permission:

1. Press `Enter` on any item → dialog appears
2. Click **"Open System Settings"**
3. Enable **LocalPaste** under Privacy & Security → Accessibility
4. Restart LocalPaste

Without this permission, `Enter` copies to clipboard and you press `⌘V` manually.

## How it works

The app polls `NSPasteboard.changeCount` every 0.5 seconds (the standard approach, since NSPasteboard has no callback API). When a change is detected, it reads **all** available pasteboard types and stores them as raw `[UTI: Data]` pairs, preserving the original type order. When you paste an item back, all formats are restored in the richest-first order — the receiving app gets the best available representation.

## Project structure

```
local-paste/
├── Package.swift                    # Swift PM manifest
├── Makefile                         # Build/run/install commands
├── Info.plist                       # App bundle configuration
├── Scripts/
│   └── gen-icon.swift              # App icon generator
├── Sources/LocalPaste/
│   ├── App.swift                    # @main + AppDelegate (status bar)
│   ├── AppState.swift               # Shared state + service orchestration
│   ├── Models/
│   │   └── ClipboardItem.swift      # Data model
│   ├── Services/
│   │   ├── PasteboardManager.swift   # NSPasteboard read/write
│   │   ├── PasteboardMonitor.swift   # Polling timer
│   │   ├── HistoryStore.swift        # JSON persistence
│   │   └── HotKeyManager.swift       # Global hotkey (Carbon)
│   ├── Views/
│   │   ├── FloatingHistoryPanel.swift # Main panel + preview
│   │   ├── ItemRowView.swift          # History list row
│   │   ├── SearchBarView.swift        # Search field
│   │   └── SettingsView.swift         # Preferences
│   └── Extensions/
│       └── NSPasteboard+Types.swift   # UTI constants + helpers
└── Tests/
    └── LocalPasteTests/
        └── LocalPasteTests.swift      # 25 unit tests
```

## Build from source

```bash
make build    # Release build
make app      # Build, sign, and create .app bundle
make install  # Build, sign, and install to /Applications
```

The release binary is at `.build/release/LocalPaste`. The app bundle is ad-hoc signed for a stable identity (required for Accessibility permission to persist across rebuilds).

## License

MIT — free to use, modify, and distribute.
