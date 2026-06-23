# LocalPaste 🗂️

A lightweight, local-only clipboard history manager for macOS.

Monitor and search your clipboard history — all data stays on your machine. No subscriptions, no cloud, no App Store.

## Features

- **Full format support** — text, rich text (RTF/RTFD), HTML, images, PDF, file URLs, colors, and any custom pasteboard type
- **Menu bar app** — lives discreetly in your menu bar
- **Global hotkey** — press `⌥⌘V` to open the floating history overlay
- **Search** — filter through your clipboard history in real-time
- **Pin items** — keep important clips at the top
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
make run-background
```

The app launches in your menu bar as a clipboard icon.

### Install to Applications

```bash
make install
```

This builds the release binary, creates `LocalPaste.app`, and copies it to `/Applications`.

### Run manually

```bash
make run        # Build and run in foreground
make run-background  # Build and run in background
make kill       # Stop the background process
```

## Usage

1. **Copy anything** — the app automatically monitors your clipboard
2. **Open history** — click the clipboard icon in the menu bar, or press `⌥⌘V`
3. **Search** — type to filter through history
4. **Paste** — double-click any item to copy it back to the clipboard
5. **Pin** — click the pin icon or right-click → Pin to keep items at the top
6. **Delete** — right-click → Delete to remove individual items

## How it works

The app polls `NSPasteboard.changeCount` every 0.5 seconds (the standard approach, since NSPasteboard has no callback API). When a change is detected, it reads **all** available pasteboard types and stores them as raw `[UTI: Data]` pairs. When you paste an item back, all original formats are restored — the receiving app gets the richest representation.

## Project structure

```
local-paste/
├── Package.swift               # Swift PM manifest
├── Makefile                    # Build/run/install commands
├── Info.plist                  # App bundle configuration
├── Sources/LocalPaste/
│   ├── App.swift               # @main entry point (MenuBarExtra)
│   ├── AppState.swift          # Shared state + service orchestration
│   ├── Models/
│   │   └── ClipboardItem.swift # Data model for clipboard entries
│   ├── Services/
│   │   ├── PasteboardManager.swift  # Read/write NSPasteboard
│   │   ├── PasteboardMonitor.swift  # Polling timer
│   │   ├── HistoryStore.swift       # JSON persistence
│   │   └── HotKeyManager.swift      # Global hotkey (Carbon)
│   ├── Views/
│   │   ├── MenuBarView.swift        # Menu bar dropdown
│   │   ├── SearchBarView.swift      # Search text field
│   │   ├── HistoryListView.swift    # History list
│   │   ├── ItemRowView.swift        # Individual item row
│   │   ├── FloatingHistoryPanel.swift # ⌥⌘V overlay panel
│   │   └── SettingsView.swift       # Preferences window
│   └── Extensions/
│       └── NSPasteboard+Types.swift # UTI constants + helpers
└── README.md
```

## Build from source

```bash
make build    # Release build
make app      # Build and create .app bundle
```

The `release` build creates an optimized binary at `.build/release/LocalPaste`.

## License

MIT — free to use, modify, and distribute.
