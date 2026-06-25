# LocalPaste 🗂️

[![CI](https://github.com/huyikai/local-paste/actions/workflows/release.yml/badge.svg)](https://github.com/huyikai/local-paste/actions/workflows/release.yml)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-orange)](https://github.com/huyikai/local-paste)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

English | [中文](README_zh.md)

A lightweight, local-only clipboard history manager for macOS.

Monitor and search your clipboard history — all data stays on your machine. No subscriptions, no cloud, no App Store.

## Screenshots

<!-- TODO: add screenshots / GIF -->
<!-- ![screenshot](screenshots/panel.png) -->

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

### Homebrew (recommended)

```bash
brew tap huyikai/local-paste
brew install --cask localpaste
```

If you prefer not to add a tap, you can install directly:

```bash
brew install --cask huyikai/local-paste/localpaste
```

#### Update

```bash
brew update
brew upgrade --cask localpaste
```

#### Uninstall

```bash
brew uninstall --cask localpaste
brew untap huyikai/local-paste   # optional: remove the tap
```

### Manual download

Download `LocalPaste.dmg` from the [latest release](https://github.com/huyikai/local-paste/releases/latest), open it, and drag **LocalPaste** to **Applications**.

> If macOS shows "unidentified developer", right-click the app → **Open** to bypass Gatekeeper.

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

## Why LocalPaste?

| | LocalPaste | Cloud-based alternatives |
|---|---|---|
| Internet required | ❌ No | ✅ Often |
| Account needed | ❌ No | ✅ Usually |
| Data on your machine | ✅ Yes | ❌ On their servers |
| Subscription | ❌ Free forever | 💰 Monthly fee |
| Open source | ✅ MIT | ❌ Mostly closed |
| Resource usage | ~30 MB RAM | 100–500 MB (Electron) |

## Build from source

```bash
make build           # Native arch release build
make build-universal # Universal binary (arm64 + x86_64)
make app             # .app bundle
make dmg             # .app → DMG installer
make install         # .app → /Applications
make run             # Run from command line
```

## Releasing

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions will build a universal DMG and create a release automatically.
The Homebrew cask always points to the latest release — users just run `brew upgrade --cask localpaste`.

## FAQ

<details>
<summary><strong>"Unidentified developer" warning?</strong></summary>

This happens because the app is ad-hoc signed (not notarized by Apple).
Right-click the app in Finder → <strong>Open</strong> to bypass, or run:

<pre>sudo xattr -d com.apple.quarantine /Applications/LocalPaste.app</pre>
</details>

<details>
<summary><strong>Auto-paste doesn't work?</strong></summary>

Make sure LocalPaste is enabled under<br>
<strong>System Settings → Privacy & Security → Accessibility</strong>.<br>
Restart the app after granting permission.
</details>

<details>
<summary><strong>Where is the data stored?</strong></summary>

<code>~/Library/Application Support/LocalPaste/</code> — a single JSON file.
You can back it up, delete it to reset history, or symlink it to a cloud folder.
</details>

## License

[MIT](LICENSE)
